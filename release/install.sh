#!/usr/bin/env bash

set -euo pipefail

INSTALL_ROOT="${BROLIT_INSTALL_ROOT:-/opt/brolit-shell}"

die() { echo "brolit release install: $*" >&2; exit 1; }

INSTALL_LOCK_DIR=""

acquire_install_lock() {
    local root="${1}"
    INSTALL_LOCK_DIR="${root}/.install.lock"

    if [[ -L "${INSTALL_LOCK_DIR}" || ( -e "${INSTALL_LOCK_DIR}" && ! -d "${INSTALL_LOCK_DIR}" ) ]]; then
        die "install lock path is not a safe directory"
    fi

    if ! mkdir "${INSTALL_LOCK_DIR}" 2>/dev/null; then
        local owner=""
        if [[ -f "${INSTALL_LOCK_DIR}/pid" && ! -L "${INSTALL_LOCK_DIR}/pid" ]]; then
            owner="$(cat "${INSTALL_LOCK_DIR}/pid" 2>/dev/null || true)"
        fi
        if [[ "${owner}" =~ ^[0-9]+$ ]] && kill -0 "${owner}" 2>/dev/null; then
            die "another release operation is in progress"
        fi

        local stale_lock="${INSTALL_LOCK_DIR}.stale.$$"
        mv "${INSTALL_LOCK_DIR}" "${stale_lock}" 2>/dev/null || die "another release operation is in progress"
        rm -rf "${stale_lock}"
        mkdir "${INSTALL_LOCK_DIR}" 2>/dev/null || die "another release operation is in progress"
    fi

    chmod 700 "${INSTALL_LOCK_DIR}"
    printf '%s\n' "$$" > "${INSTALL_LOCK_DIR}/pid"
    chmod 600 "${INSTALL_LOCK_DIR}/pid"
}

release_install_lock() {
    if [[ -n "${INSTALL_LOCK_DIR}" && -d "${INSTALL_LOCK_DIR}" && ! -L "${INSTALL_LOCK_DIR}" ]]; then
        rm -rf "${INSTALL_LOCK_DIR}"
    fi
}

usage() {
    cat >&2 <<'EOF'
Usage:
  install.sh install <manifest.json> <runtime.tar.gz> [install-root]
  install.sh rollback <version>-<commit> [install-root]
EOF
    exit 2
}

safe_release_name() {
    [[ "${1}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9a-f]{40}$ ]] || die "invalid release name"
}

# Trust anchor resolution and detached-signature verification.
#
# Sets RELEASE_TRUST (pinned|tofu|unsigned-test) and RELEASE_PRINCIPAL.
# On first-contact trust, the bundled key is written to ${stage}/allowed_signers
# so it becomes the pinned anchor for future installs once staged.
verify_release_signature() {
    local manifest_file="${1}" artifact="${2}" root="${3}" stage="${4}"
    local sig_file="${manifest_file}.sig"
    RELEASE_TRUST=""
    RELEASE_PRINCIPAL=""

    local anchor=""
    if [[ -n "${BROLIT_RELEASE_ALLOWED_SIGNERS:-}" ]]; then
        anchor="${BROLIT_RELEASE_ALLOWED_SIGNERS}"
        [[ -f "${anchor}" && ! -L "${anchor}" ]] || die "configured release trust anchor not found"
    elif [[ -f "/etc/brolit/allowed_signers" && ! -L "/etc/brolit/allowed_signers" ]]; then
        anchor="/etc/brolit/allowed_signers"
    elif [[ -L "${root}/current" ]]; then
        local cur
        cur="$(readlink "${root}/current")"
        if [[ -f "${root}/${cur}/allowed_signers" && ! -L "${root}/${cur}/allowed_signers" ]]; then
            anchor="${root}/${cur}/allowed_signers"
        fi
    fi

    if [[ -f "${sig_file}" && ! -L "${sig_file}" ]]; then
        [[ -n "${anchor}" ]] || die "release is signed but no trust anchor is available"
        command -v ssh-keygen >/dev/null || die "ssh-keygen is required to verify the release signature"
        local principal ok="false"
        while IFS= read -r line || [[ -n "${line}" ]]; do
            case "${line}" in ''|\#*) continue ;; esac
            principal="${line%%[[:space:]]*}"
            [[ -n "${principal}" ]] || continue
            if ssh-keygen -Y verify -f "${anchor}" -I "${principal}" -n brolit-shell-release -s "${sig_file}" < "${manifest_file}" >/dev/null 2>&1; then
                ok="true"
                break
            fi
        done < "${anchor}"
        [[ "${ok}" == "true" ]] || die "release signature verification failed"
        RELEASE_TRUST="pinned"
        RELEASE_PRINCIPAL="${principal}"
        return 0
    fi

    # Unsigned manifest while an anchor exists is a downgrade: refuse.
    if [[ -n "${anchor}" ]]; then
        die "trust anchor is configured but the release is unsigned"
    fi

    # First-contact trust: accept the key bundled in the artifact, if any.
    # Archive paths were already validated; extract only the key file.
    local bundled
    bundled="$(tar -tzf "${artifact}" 2>/dev/null | grep -Ex '(\./)?release/allowed_signers' | head -1 || true)"
    if [[ -n "${bundled}" ]]; then
        tar -xzOf "${artifact}" "${bundled}" > "${stage}/allowed_signers" 2>/dev/null \
            || die "cannot extract bundled trust anchor"
        [[ -s "${stage}/allowed_signers" ]] || die "bundled trust anchor is empty"
        chmod 0644 "${stage}/allowed_signers"
        RELEASE_TRUST="tofu"
        RELEASE_PRINCIPAL="$(awk '!/^#/ && NF {print $1; exit}' "${stage}/allowed_signers")"
        return 0
    fi

    if [[ "${BROLIT_ALLOW_UNSIGNED_RELEASE:-0}" == "1" ]]; then
        RELEASE_TRUST="unsigned-test"
        return 0
    fi
    die "release is unsigned and no trust anchor is available"
}

# A release that bundles a different key than the pinned anchor is rejected:
# rotation must be explicit (operator anchor), never silent.
reject_silent_key_rotation() {
    local anchor="${1}" stage="${2}"
    local bundled_key=""
    if [[ -f "${stage}/release/allowed_signers" ]]; then
        bundled_key="${stage}/release/allowed_signers"
    else
        return 0
    fi
    local anchor_material bundled_material
    anchor_material="$(awk '!/^#/ && NF {print $2, $3}' "${anchor}" | sort)"
    bundled_material="$(awk '!/^#/ && NF {print $2, $3}' "${bundled_key}" | sort)"
    [[ "${bundled_material}" == "${anchor_material}" ]] \
        || die "release bundles a different signing key (rotate explicitly via /etc/brolit/allowed_signers or BROLIT_RELEASE_ALLOWED_SIGNERS)"
}

validate_archive_paths() {
    local artifact="${1}"
    tar -tzf "${artifact}" | awk '
      /^$/ { next }
      /^\// { exit 1 }
      /(^|\/)\.\.($|\/)/ { exit 1 }
    ' >/dev/null || die "archive contains an unsafe path"
}

install_release() {
    local manifest_file="${1:?manifest is required}"
    local artifact="${2:?artifact is required}"
    local root="${3:-${INSTALL_ROOT}}"
    command -v jq >/dev/null || die "jq is required"
    command -v sha256sum >/dev/null || die "sha256sum is required"
    [[ -f "${manifest_file}" && ! -L "${manifest_file}" && -f "${artifact}" && ! -L "${artifact}" ]] || die "manifest or artifact not found"

    local product protocol_version min_admin_protocol capabilities version commit expected actual release_name release_dir stage previous previous_target receipt receipt_tmp release_moved activated anchor_for_rotation
    product="$(jq -er '.product' "${manifest_file}")" || die "manifest product missing"
    [[ "${product}" == "brolit-shell" ]] || die "invalid manifest product"
    jq -e '(.protocol_version | type) == "number" and (.protocol_version == (.protocol_version | floor)) and (.min_admin_protocol | type) == "number" and (.min_admin_protocol == (.min_admin_protocol | floor))' "${manifest_file}" >/dev/null || die "manifest protocol fields must be integers"
    protocol_version="$(jq -er '.protocol_version' "${manifest_file}")" || die "manifest protocol missing"
    min_admin_protocol="$(jq -er '.min_admin_protocol' "${manifest_file}")" || die "manifest Admin protocol missing"
    capabilities="$(jq -e '.capabilities | arrays and all(.[]; type == "string")' "${manifest_file}")" || die "invalid manifest capabilities"
    [[ "${protocol_version}" == "1" ]] || die "unsupported manifest protocol"
    [[ "${min_admin_protocol}" =~ ^[0-9]+$ && "${min_admin_protocol}" -ge 1 && "${min_admin_protocol}" -le 1 ]] || die "unsupported manifest Admin protocol"
    version="$(jq -er '.version' "${manifest_file}")" || die "manifest version missing"
    commit="$(jq -er '.commit' "${manifest_file}")" || die "manifest commit missing"
    expected="$(jq -er '.sha256 // .artifact_sha256' "${manifest_file}")" || die "manifest checksum missing"
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid manifest version"
    [[ "${commit}" =~ ^[0-9a-f]{40}$ ]] || die "invalid manifest commit"
    [[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || die "invalid manifest checksum"

    validate_archive_paths "${artifact}"
    if tar -tvzf "${artifact}" | awk '$1 ~ /^[-d]/ { next } { found=1; exit } END { exit found }'; then
        :
    else
        die "runtime bundle contains unsupported special files"
    fi

    release_name="${version}-${commit}"
    release_dir="${root}/releases/${release_name}"
    [[ ! -L "${root}" ]] || die "install root must not be a symlink"
    [[ ! -e "${root}/releases" || ( -d "${root}/releases" && ! -L "${root}/releases" ) ]] || die "release directory is unsafe"
    mkdir -p "${root}/releases"
    if [[ "$(id -u)" -ne 0 && "${BROLIT_INSTALL_TEST_MODE:-0}" != "1" ]]; then
        die "release installation requires root"
    fi
    acquire_install_lock "${root}"
    stage=""
    release_moved="false"
    activated="false"
    cleanup_install() {
        [[ -z "${stage}" ]] || rm -rf "${stage}"
        rm -f "${root}/.current.new" "${root}/.install-receipt.new"
        if [[ "${activated}" != "true" && -L "${root}/current" && "$(readlink "${root}/current")" == "releases/${release_name}" ]]; then
            rm -f "${root}/.current.recovery"
            if [[ -n "${previous_target:-}" ]]; then
                ln -s "${previous_target}" "${root}/.current.recovery"
                mv -Tf "${root}/.current.recovery" "${root}/current"
            else
                rm -f "${root}/current"
            fi
        fi
        if [[ "${release_moved}" == "true" && "${activated}" != "true" ]]; then rm -rf "${release_dir}"; fi
        release_install_lock
    }
    trap cleanup_install EXIT
    stage="$(mktemp -d "${root}/.stage.XXXXXX")"

    # Verification order: checksum binds the manifest to the artifact first
    # (cheap, no ceremony); the OpenSSH signature is verified only when
    # enforcement is enabled via BROLIT_ENFORCE_RELEASE_SIGNATURE=1.
    actual="$(sha256sum "${artifact}" | awk '{print $1}')"
    [[ "${actual}" == "${expected}" ]] || die "artifact checksum mismatch"
    if [[ "${BROLIT_ENFORCE_RELEASE_SIGNATURE:-0}" == "1" ]]; then
        verify_release_signature "${manifest_file}" "${artifact}" "${root}" "${stage}"
    else
        RELEASE_TRUST="unsigned"
        RELEASE_PRINCIPAL=""
    fi

    tar --no-same-owner --no-same-permissions -xzf "${artifact}" -C "${stage}"
    [[ -f "${stage}/runner.sh" && -f "${stage}/brolit_lite.sh" ]] || die "runtime bundle is incomplete"
    if find "${stage}" -type l -print -quit | grep -q .; then
        die "runtime bundle must not contain symlinks"
    fi
    if [[ "${RELEASE_TRUST}" == "pinned" && "${BROLIT_ENFORCE_RELEASE_SIGNATURE:-0}" == "1" ]]; then
        anchor_for_rotation=""
        if [[ -n "${BROLIT_RELEASE_ALLOWED_SIGNERS:-}" ]]; then
            anchor_for_rotation="${BROLIT_RELEASE_ALLOWED_SIGNERS}"
        elif [[ -f "/etc/brolit/allowed_signers" && ! -L "/etc/brolit/allowed_signers" ]]; then
            anchor_for_rotation="/etc/brolit/allowed_signers"
        elif [[ -L "${root}/current" ]]; then
            anchor_for_rotation="${root}/$(readlink "${root}/current")/allowed_signers"
        fi
        [[ -n "${anchor_for_rotation}" ]] || die "pinned trust lost its anchor"
        reject_silent_key_rotation "${anchor_for_rotation}" "${stage}"
        # Carry the pin forward: without this, the next install would find no
        # anchor in the new current release and silently lose pinned trust.
        cp "${anchor_for_rotation}" "${stage}/allowed_signers"
        chmod 0644 "${stage}/allowed_signers"
    fi
    cp "${manifest_file}" "${stage}/manifest.json"
    if [[ "$(id -u)" -eq 0 ]]; then chown -R 0:0 "${stage}"; fi
    find "${stage}" -type d -exec chmod 0755 {} +
    find "${stage}" -type f -exec chmod 0644 {} +
    find "${stage}" -type f -name '*.sh' -exec chmod 0755 {} +
    while IFS= read -r -d '' script; do bash -n "${script}" || die "invalid shell syntax: ${script}"; done < <(find "${stage}" -type f -name '*.sh' -print0)

    if [[ -e "${release_dir}" ]]; then
        die "release already installed: ${release_name}"
    fi
    mv "${stage}" "${release_dir}"
    stage=""
    release_moved="true"

    previous=""
    previous_target=""
    if [[ -L "${root}/current" ]]; then
        previous_target="$(readlink "${root}/current")"
        previous="${previous_target##*/}"
        safe_release_name "${previous}"
        [[ "${previous_target}" == "releases/${previous}" ]] || die "current link points outside releases"
    fi
    receipt="${release_dir}/install-receipt.json"
    jq -n --arg previous "${previous}" --arg release "${release_name}" --arg checksum "${actual}" --arg manifest "${release_dir}/manifest.json" --arg trust "${RELEASE_TRUST}" --arg principal "${RELEASE_PRINCIPAL}" --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         '{previous_release:(if $previous == "" then null else $previous end),active_release:$release,artifact_sha256:$checksum,manifest:$manifest,trust:$trust,principal:(if $principal == "" then null else $principal end),validation:"passed",installed_at:$installed_at}' \
         > "${receipt}"
    receipt_tmp="${root}/.install-receipt.new"
    [[ ! -e "${receipt_tmp}" && ! -L "${receipt_tmp}" ]] || die "receipt staging path already exists"
    cp "${receipt}" "${receipt_tmp}"
    chmod 600 "${receipt_tmp}"
    [[ ! -e "${root}/current" || -L "${root}/current" ]] || die "refusing to replace non-symlink current path"
    rm -f "${root}/.current.new"
    ln -s "releases/${release_name}" "${root}/.current.new"
    mv -Tf "${root}/.current.new" "${root}/current"
    mv -Tf "${receipt_tmp}" "${root}/install-receipt.json"
    activated="true"
    trap - EXIT
    release_install_lock
    printf '%s\n' "${release_name}"
}

rollback_release() {
    local release="${1:?release is required}"
    local root="${2:-${INSTALL_ROOT}}"
    safe_release_name "${release}"
    [[ -d "${root}/releases/${release}" && ! -L "${root}/releases/${release}" ]] || die "release not installed or unsafe"
    mkdir -p "${root}"
    acquire_install_lock "${root}"
    local previous="" previous_target="" receipt_tmp="${root}/.install-receipt.new" activated="false"
    [[ ! -L "${root}" ]] || die "install root must not be a symlink"
    [[ ! -e "${root}/releases" || ( -d "${root}/releases" && ! -L "${root}/releases" ) ]] || die "release directory is unsafe"
    if [[ -L "${root}/current" ]]; then
        previous_target="$(readlink "${root}/current")"
        previous="${previous_target##*/}"
        safe_release_name "${previous}"
        [[ "${previous_target}" == "releases/${previous}" ]] || die "current link points outside releases"
    fi
    restore_rollback() {
        rm -f "${root}/.current.new" "${receipt_tmp}"
        if [[ "${activated}" != "true" && -L "${root}/current" && "$(readlink "${root}/current")" == "releases/${release}" ]]; then
            rm -f "${root}/.current.recovery"
            if [[ -n "${previous_target}" ]]; then
                ln -s "${previous_target}" "${root}/.current.recovery"
                mv -Tf "${root}/.current.recovery" "${root}/current"
            else
                rm -f "${root}/current"
            fi
        fi
        release_install_lock
    }
    trap restore_rollback EXIT
    [[ ! -e "${root}/current" || -L "${root}/current" ]] || die "refusing to replace non-symlink current path"
    rm -f "${root}/.current.new"
    ln -s "releases/${release}" "${root}/.current.new"
    mv -Tf "${root}/.current.new" "${root}/current"
    [[ ! -e "${receipt_tmp}" && ! -L "${receipt_tmp}" ]] || die "receipt staging path already exists"
    [[ -f "${root}/releases/${release}/manifest.json" && ! -L "${root}/releases/${release}/manifest.json" ]] || die "release manifest missing"
    # Carry the authenticity context from the restored release's own install
    # receipt so rollback records stay auditable under the same schema.
    local rollback_trust="" rollback_principal=""
    if [[ -f "${root}/releases/${release}/install-receipt.json" && ! -L "${root}/releases/${release}/install-receipt.json" ]]; then
        rollback_trust="$(jq -r '.trust // empty' "${root}/releases/${release}/install-receipt.json" 2>/dev/null || true)"
        rollback_principal="$(jq -r '.principal // empty' "${root}/releases/${release}/install-receipt.json" 2>/dev/null || true)"
    fi
    jq -n \
        --arg previous "${previous}" \
        --arg release "${release}" \
        --arg checksum "$(jq -er '.sha256 // .artifact_sha256' "${root}/releases/${release}/manifest.json")" \
        --arg manifest "${root}/releases/${release}/manifest.json" \
        --arg trust "${rollback_trust}" \
        --arg principal "${rollback_principal}" \
        --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{previous_release:(if $previous == "" then null else $previous end),active_release:$release,artifact_sha256:$checksum,manifest:$manifest,trust:(if $trust == "" then "unknown" else $trust end),principal:(if $principal == "" then null else $principal end),validation:"rollback",installed_at:$installed_at}' \
        > "${receipt_tmp}"
    chmod 600 "${receipt_tmp}"
    mv -Tf "${root}/.install-receipt.new" "${root}/install-receipt.json"
    activated="true"
    trap - EXIT
    release_install_lock
    printf '%s\n' "${release}"
}

case "${1:-}" in
    install) install_release "${2:-}" "${3:-}" "${4:-${INSTALL_ROOT}}" ;;
    rollback) rollback_release "${2:-}" "${3:-${INSTALL_ROOT}}" ;;
    *) usage ;;
esac

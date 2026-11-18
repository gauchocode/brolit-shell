#!/usr/bin/env bash
# Tests for project_compose_mount_coverage(): the evidence that decides whether
# a Compose project can be deleted without losing persistent mount data.
#
# No real Docker daemon is contacted: the gate resolves `docker` from a fake
# binary on PATH, driven by fixture files.

source "$(dirname "${BASH_SOURCE[0]}")/../libs/local/project_helper.sh"

function test_compose_mount_coverage() {
  local tmp project_dir failed=0 rc output case_name saved_path="${PATH}"

  tmp="$(mktemp -d)"
  project_dir="${tmp}/project"
  mkdir -p "${project_dir}" "${tmp}/bin"
  : > "${project_dir}/docker-compose.yml"

  FAKE_DOCKER_RECORD="${tmp}/record.json"
  FAKE_DOCKER_VOLUMES="${tmp}/volumes.txt"
  FAKE_DOCKER_LABELED_VOLUMES="${tmp}/labeled-volumes.txt"
  : > "${FAKE_DOCKER_RECORD}"
  : > "${FAKE_DOCKER_VOLUMES}"
  : > "${FAKE_DOCKER_LABELED_VOLUMES}"

  cat > "${tmp}/bin/docker" <<'FAKE'
#!/usr/bin/env bash
case "${1:-}" in
  ps)
    [[ -s "${FAKE_DOCKER_RECORD:-/dev/null}" ]] || exit 0
    printf '%s\n' "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    exit 0
    ;;
  inspect)
    if [[ "${FAKE_BROKEN_INSPECTION:-false}" == "true" ]]; then exit 1; fi
    cat "${FAKE_DOCKER_RECORD:-/dev/null}" 2>/dev/null || true
    exit 0
    ;;
  volume)
    filtered=false
    for arg in "$@"; do [[ "${arg}" == label=* ]] && filtered=true; done
    if [[ "${filtered}" == "true" ]]; then
      [[ -s "${FAKE_DOCKER_LABELED_VOLUMES:-/dev/null}" ]] && sed '/^$/d' "${FAKE_DOCKER_LABELED_VOLUMES}"
    else
      [[ -s "${FAKE_DOCKER_VOLUMES:-/dev/null}" ]] && sed '/^$/d' "${FAKE_DOCKER_VOLUMES}"
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
FAKE
  chmod +x "${tmp}/bin/docker"
  PATH="${tmp}/bin:${PATH}"
  export FAKE_DOCKER_RECORD FAKE_DOCKER_VOLUMES FAKE_DOCKER_LABELED_VOLUMES PATH

  # Run the gate and compare exit code plus an expected substring.
  function check_case() {
    local name="${1}" expected_rc="${2}" expected_text="${3}" actual_rc
    output="$(project_compose_mount_coverage "${project_dir}" 2>&1)"
    actual_rc=$?
    if [[ ${actual_rc} -ne ${expected_rc} ]]; then
      printf 'FAIL: %s: expected rc %s, got %s (%s)\n' "${name}" "${expected_rc}" "${actual_rc}" "${output}"
      failed=1
      return
    fi
    if [[ -n "${expected_text}" && "${output}" != *"${expected_text}"* ]]; then
      printf 'FAIL: %s: expected "%s" in output, got "%s"\n' "${name}" "${expected_text}" "${output}"
      failed=1
    fi
  }

  # No container references the project: nothing to lose beyond the directory.
  : > "${FAKE_DOCKER_RECORD}"
  : > "${FAKE_DOCKER_VOLUMES}"
  check_case "no containers" 0 ""

  # Bind mount inside the project directory: covered by the files backup.
  mkdir -p "${project_dir}/uploads"
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"bind\",\"Source\":\"${project_dir}/uploads\",\"Destination\":\"/var/www/uploads\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "bind inside project" 0 ""

  # A bind source that is a symlink to somewhere else is not covered by the
  # files tarball, which stores the link and not the target.
  ln -sfn "${tmp}/elsewhere" "${project_dir}/linked"
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"bind\",\"Source\":\"${project_dir}/linked\",\"Destination\":\"/var/www/linked\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "bind inside via symlink" 1 "UNCOVERED:bind"
  rm -f "${project_dir}/linked"

  # A bind inside the project whose source no longer exists holds no data.
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"bind\",\"Source\":\"${project_dir}/gone\",\"Destination\":\"/var/www/gone\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "bind inside, source missing" 0 ""

  # Named volume: not covered by a files backup nor by a database dump.
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"volume\",\"Name\":\"project_data\",\"Source\":\"/var/lib/docker/volumes/project_data/_data\",\"Destination\":\"/var/lib/postgresql/data\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "named volume" 1 "UNCOVERED:volume:project_data:/var/lib/postgresql/data"

  # Anonymous volume: same risk, no useful name.
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"volume\",\"Name\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"Source\":\"/var/lib/docker/volumes/anonymous/_data\",\"Destination\":\"/data\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "anonymous volume" 1 "UNCOVERED:volume:0123456789abcdef"

  # Bind mount outside the project directory: the files backup cannot cover it.
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"bind\",\"Source\":\"/srv/external\",\"Destination\":\"/data\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "bind outside project" 1 "UNCOVERED:bind:/srv/external:/data"

  # tmpfs dies with the container: nothing persistent to lose.
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"tmpfs\",\"Source\":\"tmpfs\",\"Destination\":\"/run\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "tmpfs" 0 ""

  # A container that only touches a sibling directory is not related.
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"other\",\"working_dir\":\"${tmp}/other\",\"mounts\":[]}" > "${FAKE_DOCKER_RECORD}"
  check_case "unrelated container" 0 ""

  # A container without the Compose working_dir label (docker run, old Compose)
  # is not related and must not turn the verdict into "cannot verify".
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":null,\"working_dir\":null,\"mounts\":[]}" > "${FAKE_DOCKER_RECORD}"
  check_case "container without compose labels" 0 ""

  # brolit writes COMPOSE_PROJECT_NAME="${project_name}_stack" in the .env, so
  # orphan volumes live under that namespace, not under the directory name.
  printf 'COMPOSE_PROJECT_NAME=myproj_stack\n' > "${project_dir}/.env"
  : > "${FAKE_DOCKER_RECORD}"
  printf '%s\n' "myproj_stack_data" > "${FAKE_DOCKER_VOLUMES}"
  check_case "compose name from .env" 1 "UNCOVERED:volume-namespace:myproj_stack_data"
  rm -f "${project_dir}/.env"
  : > "${FAKE_DOCKER_VOLUMES}"

  # Orphan volume in the project namespace, no container left.
  : > "${FAKE_DOCKER_RECORD}"
  printf '%s\n' "project_data" > "${FAKE_DOCKER_VOLUMES}"
  check_case "orphan volume by namespace" 1 "UNCOVERED:volume-namespace:project_data"

  # A sibling project whose name shares the prefix must not match.
  printf '%s\n' "project2_data" > "${FAKE_DOCKER_VOLUMES}"
  check_case "unrelated volume namespace" 0 ""
  : > "${FAKE_DOCKER_VOLUMES}"

  # A volume labelled as belonging to the Compose project always blocks, even
  # when its name does not follow the namespace.
  printf '%s\n' "unrelated_name" > "${FAKE_DOCKER_LABELED_VOLUMES}"
  check_case "compose labelled volume" 1 "UNCOVERED:volume-namespace:unrelated_name"
  : > "${FAKE_DOCKER_LABELED_VOLUMES}"

  # Ambiguous Compose context (container without a project label).
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":null,\"working_dir\":\"${project_dir}\",\"mounts\":[]}" > "${FAKE_DOCKER_RECORD}"
  check_case "missing project label" 2 ""
  : > "${FAKE_DOCKER_RECORD}"

  # Malformed inspection output is not evidence of anything.
  printf '%s\n' '{"id":"","mounts":[]}' > "${FAKE_DOCKER_RECORD}"
  check_case "malformed record" 2 ""
  : > "${FAKE_DOCKER_RECORD}"

  # Failed inspection blocks.
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[]}" > "${FAKE_DOCKER_RECORD}"
  FAKE_BROKEN_INSPECTION=true check_case "failed inspect" 2 ""
  : > "${FAKE_DOCKER_RECORD}"

  # unknown mount type blocks
  printf '%s\n' "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"project\":\"project\",\"working_dir\":\"${project_dir}\",\"mounts\":[{\"Type\":\"nfs\",\"Source\":\"10.0.0.1:/share\",\"Destination\":\"/data\"}]}" > "${FAKE_DOCKER_RECORD}"
  check_case "unknown mount type" 1 "UNCOVERED:nfs"
  : > "${FAKE_DOCKER_RECORD}"

  # An explicit COMPOSE_FILE makes the Compose context unknown.
  printf 'COMPOSE_FILE=custom.yml\n' > "${project_dir}/.env"
  check_case "COMPOSE_FILE declared" 2 ""
  rm -- "${project_dir}/.env"

  # A missing project directory is not evidence of coverage.
  output="$(project_compose_mount_coverage "${tmp}/missing" 2>&1)"
  if [[ $? -ne 2 ]]; then echo "FAIL: missing project directory accepted"; failed=1; fi

  # Without docker on PATH the gate cannot verify anything.
  mkdir -p "${tmp}/empty"
  output="$(PATH="${tmp}/empty" project_compose_mount_coverage "${project_dir}" 2>&1)"
  if [[ $? -ne 2 ]]; then echo "FAIL: missing docker accepted"; failed=1; fi

  # Without jq the gate cannot parse the inspection either.
  mkdir -p "${tmp}/docker-only"
  ln -sf "${tmp}/bin/docker" "${tmp}/docker-only/docker"
  output="$(PATH="${tmp}/docker-only" project_compose_mount_coverage "${project_dir}" 2>&1)"
  if [[ $? -ne 2 ]]; then echo "FAIL: missing jq accepted"; failed=1; fi

  # Sanitization keeps Compose's project naming rules.
  if [[ "$(project_compose_sanitize_name 'My.Project Name')" != "myprojectname" ]]; then
    echo "FAIL: project name sanitization"; failed=1
  fi
  if project_compose_sanitize_name '...' >/dev/null 2>&1; then
    echo "FAIL: empty sanitized name accepted"; failed=1
  fi

  rm -rf -- "${tmp}"
  # Never leak the fake docker into the caller's PATH (the suite runs every
  # test in the same shell).
  PATH="${saved_path}"
  return "${failed}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_compose_mount_coverage
fi

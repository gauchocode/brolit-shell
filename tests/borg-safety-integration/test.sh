#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.11
# Description: Real-tool Borg safety integration in a disposable offline container.
################################################################################
set -euo pipefail

mkdir --parents "${TMPDIR:-/tmp/opencode}" "${HOME}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp --directory "${TMPDIR:-/tmp/opencode}/borg-integration.XXXXXX")"
trap 'rm --recursive --force -- "${tmp}"' EXIT
# These logs contain only disposable fixtures, never operator configurations.
trap 'echo "FAIL: integration line ${LINENO}" >&2; tail --lines=30 "${tmp}/validate-output" "${tmp}/create-output" "${tmp}/events" >&2 2>/dev/null || true' ERR
export BORG_CACHE_DIR="${tmp}/cache" BORG_CONFIG_DIR="${tmp}/borg-config" BORG_SECURITY_DIR="${tmp}/security"
export BORG_PASSPHRASE=""

borg --version
borgmatic --version
yq --version
source "${root}/libs/local/borg_config_helper.sh"
source "${root}/libs/borg_storage_controller.sh"
# The existing controller exports trust defaults. This suite does not accept
# moved or unknown unencrypted repositories silently; init establishes trust.
export BORG_RELOCATED_REPO_ACCESS_IS_OK=no BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=no

################################################################################
# Capture fixed-class library logs in the isolated test directory.
# Arguments: standard log_event parameters. Outputs: 0.
################################################################################
function log_event() { printf '%s\n' "${2}" >> "${tmp}/events"; }
################################################################################
# Suppress interactive display during integration assertions.
# Arguments: display parameters. Outputs: 0.
################################################################################
function display() { :; }
################################################################################
# Suppress terminal clearing during integration assertions.
# Arguments: display parameters. Outputs: 0.
################################################################################
function clear_previous_lines() { :; }
################################################################################
# Select fixture install type without discovering real applications.
# Arguments: project path. Outputs: fixture type and 0.
################################################################################
function project_get_install_type() { printf '%s\n' "${fixture_type}"; }
################################################################################
# Select fixture database engine without contacting a database.
# Arguments: project/type. Outputs: fixture engine and 0.
################################################################################
function project_get_database_engine() { printf '%s\n' "${fixture_engine}"; }
################################################################################
# Supply a fixture database name; file-only templates must never call this.
# Arguments: project/type. Outputs: fixture name and 0.
################################################################################
function project_get_database_name() { touch "${tmp}/db-detected"; printf '%s\n' "${fixture_database}"; }

BROLIT_MAIN_DIR="${root}"
HOSTNAME=fixture-host
BACKUP_BORG_GROUP=fixture-group
BACKUP_BORG_USERS=(user1 user2)
BACKUP_BORG_SERVERS=(one.example two.example)
BACKUP_BORG_PORTS=(22 23)
fixture_type=docker-compose fixture_engine=mysql fixture_database='${UNRESOLVED_DATABASE}'
mkdir --parents "${tmp}/www/site.example"
printf '%s\n' fixture > "${tmp}/www/site.example/app"

for fixture_type in docker-compose unknown; do
    config_dir="${tmp}/generated-${fixture_type}"
    [[ "$(generate_borg_config site.example "${config_dir}" "${tmp}/www")" == created ]]
    profile="${config_dir}/site.example.yml"
    yq --exit-status '(.constants | has("database")) == false' "${profile}" >/dev/null
    yq --exit-status '(.repositories | length) == 2 and .constants.project == "site.example"' "${profile}" >/dev/null
    [[ ! -e "${tmp}/db-detected" ]]
    [[ "$(stat --format=%a "${profile}")" == 600 ]]
    borgmatic --config "${profile}" config validate > "${tmp}/validate-output" 2>&1
    cp -- "${profile}" "${tmp}/original"
    [[ "$(generate_borg_config site.example "${config_dir}" "${tmp}/www")" == exists ]]
    cmp -- "${profile}" "${tmp}/original"
done
echo 'PASS: real yq generation with actual Docker/default templates and preservation'

fixture_type=default
for fixture_engine in mysql postgres; do
    config_dir="${tmp}/generated-${fixture_engine}"
    fixture_database='${UNRESOLVED_DATABASE}'
    if generate_borg_config site.example "${config_dir}" "${tmp}/www" > "${tmp}/status"; then
        echo 'FAIL: unresolved required database accepted' >&2; exit 1
    fi
    [[ ! -e "${config_dir}/site.example.yml" ]]
    fixture_database=fixture_database
    [[ "$(generate_borg_config site.example "${config_dir}" "${tmp}/www")" == created ]]
    yq --exit-status '.constants.database == "fixture_database"' "${config_dir}/site.example.yml" >/dev/null
    borgmatic --config "${config_dir}/site.example.yml" config validate > "${tmp}/validate-output" 2>&1
done
echo 'PASS: actual MySQL/Postgres templates require concrete database constants'

# All archive operations below use a minimal profile, no generated template hooks.
mkdir --parents "${tmp}/source" "${tmp}/restore"
printf '%s\n' 'disposable integration payload' > "${tmp}/source/payload.txt"
SOURCE="${tmp}/source" REPO="${tmp}/repo-one" yq --null-input \
    '.source_directories = [strenv(SOURCE)] | .repositories = [{"path": strenv(REPO), "label": "local-one"}] | .archive_name_format = "fixture-{now:%Y-%m-%dT%H:%M:%S}"' > "${tmp}/local.yml"
initialize_repository "${tmp}/local.yml"
[[ -f "${tmp}/repo-one/config" ]]
initialize_repository "${tmp}/local.yml"
borgmatic --config "${tmp}/local.yml" create > "${tmp}/create-output" 2>&1
archive="$(borg list --short "${tmp}/repo-one")"
[[ -n "${archive}" ]]
(cd "${tmp}/restore" && borg extract "${tmp}/repo-one::${archive}")
cmp -- "${tmp}/source/payload.txt" "${tmp}/restore/${tmp#/}/source/payload.txt"
echo 'PASS: missing-only initialization, repeat preflight, create and verified file restore'

cp -- "${tmp}/local.yml" "${tmp}/multi.yml"
REPO="${tmp}/repo-two" yq -i '.repositories += [{"path": strenv(REPO), "label": "local-two"}]' "${tmp}/multi.yml"
initialize_repository "${tmp}/multi.yml"
[[ -f "${tmp}/repo-two/config" ]]
[[ -z "$(find "${tmp}" -maxdepth 1 -name '.brolit-init.*' -print)" ]]
echo 'PASS: real multi-repository YAML splitting and missing-only initialization'

cp --archive -- "${tmp}/repo-one" "${tmp}/relocated-repo"
cp -- "${tmp}/local.yml" "${tmp}/relocated.yml"
REPO="${tmp}/relocated-repo" yq -i '.repositories[0].path = strenv(REPO)' "${tmp}/relocated.yml"
if initialize_repository "${tmp}/relocated.yml"; then
    echo 'FAIL: repository relocation was accepted without approval' >&2; exit 1
fi
[[ "${BORG_INIT_FAILURE_REASON}" == relocation ]]
echo 'PASS: real relocation challenge remains blocked without automatic trust'

cp -- "${tmp}/local.yml" "${tmp}/invalid.yml"
REPO="${tmp}/must-not-exist" yq -i '.repositories[0].path = strenv(REPO) | .constants.unused = "${BROLIT_TEST_MISSING_ENV}"' "${tmp}/invalid.yml"
unset BROLIT_TEST_MISSING_ENV
if initialize_repository "${tmp}/invalid.yml"; then
    echo 'FAIL: runtime interpolation error accepted' >&2; exit 1
fi
[[ "${BORG_INIT_FAILURE_REASON}" == config && ! -e "${tmp}/must-not-exist" ]]
echo 'PASS: real Borgmatic environment interpolation error blocks initialization'

for test in test_borg_config_generation test_borg_init_safety test_borg_init_mismatch test_borgmatic_pause_hooks test_backup_project_resilience; do
    bash "${root}/tests/${test}.sh"
done
bash -c 'source "${1}/tests/test_borg_repository_recovery.sh"; test_borg_repository_recovery' _ "${root}"
/usr/bin/python3 "${root}/tests/backup_observation/test_borgmatic_profile.py"

echo 'PASS: real-tool integration complete (no production or SSH resources)'

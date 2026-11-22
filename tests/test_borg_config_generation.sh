#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.11
# Description: Offline atomic generation regressions; no cron/system loading.
################################################################################

################################################################################
# Run isolated generator fixtures with checked YAML-operation test doubles.
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_borg_config_generation() (
    set -e
    local root tmp config status i value
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    tmp="$(mktemp -d "${TMPDIR:-/tmp/opencode}/borg-generation.XXXXXX")"
    trap 'rm --recursive --force -- "${tmp}"' EXIT
    source "${root}/libs/local/borg_config_helper.sh"
    ################################################################################
    # Fixture type detector; arguments ignored; outputs fixture install type, 0.
    ################################################################################
    function project_get_install_type() { echo "${install_type}"; }
    ################################################################################
    # Fixture engine detector; arguments ignored; outputs fixture engine, 0.
    ################################################################################
    function project_get_database_engine() { echo "${engine}"; }
    ################################################################################
    # Fixture DB detector; arguments ignored; outputs name, records detection, 0.
    ################################################################################
    function project_get_database_name() { touch "${tmp}/db-detected"; echo "${database}"; }
    ################################################################################
    # Fixture logger; arguments: log parameters; outputs safe message, 0.
    ################################################################################
    function log_event() { echo "${2}"; }
    mkdir --parents "${tmp}/bin" "${tmp}/templates/config/borg" "${tmp}/www/site.example"
    touch "${tmp}/www/site.example/app"
    cp "${root}/tests/fixtures/borg_safety_yq.py" "${tmp}/bin/yq"
    chmod +x "${tmp}/bin/yq"
    export PATH="${tmp}/bin:${PATH}" FAKE_YQ_COUNT="${tmp}/yq-count"
    BROLIT_MAIN_DIR="${tmp}/templates"
    # JSON is a YAML subset: these test only the tool protocol, not YAML parsing.
    for value in docker default; do
        printf '%s\n' '{"constants":{"project":"project_domain","group":"group_server","hostname":"hostname_server"},"repositories":[],"source_directories":["/var/www/{project}"]}' > "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-${value}.yml"
        ! grep -qF '{database}' "${root}/config/borg/borgmatic.template-${value}.yml"
    done
    for value in mysql postgres; do
        printf '%s\n' '{"constants":{"project":"project_domain","group":"group_server","hostname":"hostname_server"},"repositories":[],"mysql_databases":[{"name":"{database}"}]}' > "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-${value}.yml"
        grep -qF '{database}' "${root}/config/borg/borgmatic.template-${value}.yml"
    done
    BACKUP_BORG_GROUP="fixture-group" HOSTNAME="fixture-host"
    local -a BACKUP_BORG_USERS=(user1 user2) BACKUP_BORG_SERVERS=(one.example two.example) BACKUP_BORG_PORTS=(22 23)
    local install_type="docker-compose" engine="mysql" database='${UNRESOLVED_DATABASE}'
    config="${tmp}/absent/configs"
    status="$(generate_borg_config site.example "${config}" "${tmp}/www")"
    [[ "${status}" == created && -f "${config}/site.example.yml" ]]
    [[ ! -f "${tmp}/db-detected" ]]
    [[ "$(stat --format=%a "${config}/site.example.yml")" == 600 ]]
    python3 - "${config}/site.example.yml" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert 'database' not in data['constants']
assert len(data['repositories']) == 2
assert data['repositories'][1]['path'] == 'ssh://{user_2}@{server_2}:{port_2}/home/applications/{group}/{hostname}/projects-online/site/{project}'
assert data['constants']['server_2'] == 'two.example'
assert data['constants']['project'] == 'site.example'
assert data['constants']['group'] == 'fixture-group'
assert data['constants']['hostname'] == 'fixture-host'
PY
    cp "${config}/site.example.yml" "${tmp}/original"
    # Existing custom profiles are preserved even for empty directories.
    rm -- "${tmp}/www/site.example/app"
    status="$(generate_borg_config site.example "${config}" "${tmp}/www")"
    [[ "${status}" == exists ]]
    cmp "${tmp}/original" "${config}/site.example.yml"
    rm -- "${config}/site.example.yml"
    [[ "$(generate_borg_config site.example "${config}" "${tmp}/www")" == skipped ]]
    touch "${tmp}/www/site.example/app"
    install_type="unknown"
    [[ "$(generate_borg_config site.example "${config}" "${tmp}/www")" == created ]]
    [[ ! -f "${tmp}/db-detected" ]]
    rm -- "${config}/site.example.yml"
    install_type="default"
    for value in '' '${DB}' '$DB' '{database}' '$(touch secret)' 'name with spaces'; do
        database="${value}"
        if status="$(generate_borg_config site.example "${config}" "${tmp}/www")"; then return 1; fi
        [[ "${status}" == failed && ! -e "${config}/site.example.yml" ]]
    done
    database="fixture_db"
    for engine in mysql postgres; do
        [[ "$(generate_borg_config site.example "${config}" "${tmp}/www")" == created ]]
        grep -q 'fixture_db' "${config}/site.example.yml"
        rm -- "${config}/site.example.yml"
    done
    # Every mutating operation and final validation must fail closed.
    for i in 1 2 3 4 5 6 7 8; do
        : > "${FAKE_YQ_COUNT}"
        export FAKE_YQ_FAIL_AT="${i}"
        if status="$(generate_borg_config site.example "${config}" "${tmp}/www" 2>"${tmp}/diagnostics")"; then return 1; fi
        [[ "${status}" == failed && ! -e "${config}/site.example.yml" ]]
        [[ -z "$(find "${config}" -name '.brolit-config.*' -print)" ]]
        ! grep -q SECRET_CANARY "${tmp}/diagnostics"
    done
    unset FAKE_YQ_FAIL_AT
    # A successful exit alone is not proof that required values were written.
    for i in 1 2 3 4; do
        : > "${FAKE_YQ_COUNT}"
        export FAKE_YQ_SKIP_AT="${i}"
        if status="$(generate_borg_config site.example "${config}" "${tmp}/www")"; then return 1; fi
        [[ "${status}" == failed && ! -e "${config}/site.example.yml" ]]
        [[ -z "$(find "${config}" -name '.brolit-config.*' -print)" ]]
    done
    unset FAKE_YQ_SKIP_AT
    # Real templates start with nonempty placeholders and no repositories:
    # skipping the FIRST mutation must fail for exact constants, not length.
    # Cover Docker and the fallback/default path, including missing/null/types.
    for install_type in docker-compose unknown; do
        if [[ "${install_type}" == docker-compose ]]; then value=docker; else value=default; fi
        cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-${value}.yml" "${tmp}/saved-template"
        for status in placeholder missing null number array object missing-project missing-group missing-hostname null-project null-group null-hostname; do
            python3 - "${tmp}/saved-template" "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-${value}.yml" "${status}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
state = sys.argv[3]
if state == 'missing':
    data['constants'] = {}
elif state.startswith(('missing-', 'null-')):
    data['constants'] = {'project': 'site.example', 'group': 'fixture-group', 'hostname': 'fixture-host'}
    kind, key = state.split('-', 1)
    if kind == 'missing':
        data['constants'].pop(key)
    else:
        data['constants'][key] = None
elif state != 'placeholder':
    value = {'null': None, 'number': 123, 'array': [], 'object': {}}[state]
    data['constants'] = dict.fromkeys(('project', 'group', 'hostname'), value)
json.dump(data, open(sys.argv[2], 'w'))
PY
            # Verify the double faithfully models null != "" (true), not the
            # former truthiness shortcut that masked the original defect.
            if [[ "${status}" == null ]]; then
                yq --exit-status '.constants.project != ""' "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-${value}.yml"
            fi
            : > "${FAKE_YQ_COUNT}"
            export FAKE_YQ_SKIP_AT=1
            if status="$(generate_borg_config site.example "${config}" "${tmp}/www")"; then return 1; fi
            [[ "${status}" == failed && ! -e "${config}/site.example.yml" ]]
            [[ -z "$(find "${config}" -name '.brolit-config.*' -print)" ]]
            unset FAKE_YQ_SKIP_AT
        done
        cp "${tmp}/saved-template" "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-${value}.yml"
        [[ "$(generate_borg_config site.example "${config}" "${tmp}/www")" == created ]]
        rm -- "${config}/site.example.yml"
    done
    install_type=default
    # Filesystem failures must leave no final profile or staging residue.
    mkdir "${tmp}/fail-bin"
    for value in find mkdir mktemp cp chmod ln; do
        printf '#!/usr/bin/env bash\nexit 1\n' > "${tmp}/fail-bin/${value}"
        chmod +x "${tmp}/fail-bin/${value}"
        if status="$(PATH="${tmp}/fail-bin:${PATH}" generate_borg_config site.example "${config}" "${tmp}/www")"; then return 1; fi
        [[ "${status}" == failed && ! -e "${config}/site.example.yml" ]]
        [[ -z "$(find "${config}" -name '.brolit-config.*' -print)" ]]
        rm -- "${tmp}/fail-bin/${value}"
    done
    # A concurrent creator must not be overwritten during publication.
    cat > "${tmp}/fail-bin/ln" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' 'custom-concurrent-profile' > "${@: -1}"
exit 1
FAKE
    chmod +x "${tmp}/fail-bin/ln"
    [[ "$(PATH="${tmp}/fail-bin:${PATH}" generate_borg_config site.example "${config}" "${tmp}/www")" == exists ]]
    [[ "$(cat "${config}/site.example.yml")" == custom-concurrent-profile ]]
    rm -- "${tmp}/fail-bin/ln" "${config}/site.example.yml"
    ln --symbolic "${tmp}/absent-target" "${config}/site.example.yml"
    [[ "$(generate_borg_config site.example "${config}" "${tmp}/www")" == exists ]]
    [[ -L "${config}/site.example.yml" ]]
    rm -- "${config}/site.example.yml"
    BACKUP_BORG_PORTS=(22)
    if generate_borg_config site.example "${config}" "${tmp}/www" >/dev/null; then return 1; fi
    BACKUP_BORG_PORTS=(22 '')
    if generate_borg_config site.example "${config}" "${tmp}/www" >/dev/null; then return 1; fi
    BACKUP_BORG_PORTS=(22 0)
    if generate_borg_config site.example "${config}" "${tmp}/www" >/dev/null; then return 1; fi
    BACKUP_BORG_PORTS=(22 23)
    BACKUP_BORG_SERVERS=(one.example '${UNRESOLVED_HOST}')
    if generate_borg_config site.example "${config}" "${tmp}/www" >/dev/null; then return 1; fi
    BACKUP_BORG_USERS=()
    BACKUP_BORG_SERVERS=()
    BACKUP_BORG_PORTS=()
    if generate_borg_config site.example "${config}" "${tmp}/www" >/dev/null; then return 1; fi
    [[ ! -e "${config}/site.example.yml" ]]
    # Exercise the actual name reader: no PHP/env evaluation or interactive
    # output; only supported literal definitions may become constants.
    source "${root}/libs/local/project_helper.sh"
    PROJECTS_PATH="${tmp}/www"
    printf '%s\n' "define( 'DB_NAME', 'wordpress_fixture' );" > "${tmp}/www/site.example/wp-config.php"
    [[ "$(project_get_database_name site.example default)" == wordpress_fixture ]]
    printf '%s\n' 'define("DB_NAME", "wordpress_double");' > "${tmp}/www/site.example/wp-config.php"
    [[ "$(project_get_database_name site.example default)" == wordpress_double ]]
    printf '%s\n' '/* Ordinary WordPress header' ' * without database definitions.' ' */' "define('DB_NAME', 'wordpress_active');" > "${tmp}/www/site.example/wp-config.php"
    [[ "$(project_get_database_name site.example default)" == wordpress_active ]]
    printf '%s\n' "define('DB_NAME', getenv('DB_NAME'));" > "${tmp}/www/site.example/wp-config.php"
    [[ -z "$(project_get_database_name site.example default)" ]]
    # No fallback to a stale .env for an ambiguous WordPress configuration.
    printf '%s\n' 'DB_DATABASE=stale_env_database' > "${tmp}/www/site.example/.env"
    mkdir "${tmp}/wp-cases"
    python3 - "${tmp}/wp-cases" <<'PY'
from pathlib import Path
import sys
literal = "define('DB_NAME', 'retired_db');"
active = "define('DB_NAME', getenv('DB_NAME'));"
cases = [
    '/*\n' + literal + '\n*/\n' + active,
    '/* ' + literal + ' */\n' + active,
    '/* Retired configuration\n' + literal + '\n*/',
    literal + ' /* inline comment */',
    '// ' + literal,
    '# ' + literal,
    literal + '\n' + literal,
    literal + '\n' + active,
    active,
    '/* mentions DB_NAME */\n' + literal,
    '/* unterminated\n' + literal,
]
for index, content in enumerate(cases):
    Path(sys.argv[1], str(index)).write_text(content + '\n')
PY
    for value in "${tmp}/wp-cases/"*; do
        cp "${value}" "${tmp}/www/site.example/wp-config.php"
        [[ -z "$(project_get_database_name site.example default)" ]]
    done
    rm -- "${tmp}/www/site.example/wp-config.php"
    printf '%s\n' 'DB_DATABASE=${UNRESOLVED_DATABASE}' > "${tmp}/www/site.example/.env"
    [[ "$(project_get_database_name site.example default)" == '${UNRESOLVED_DATABASE}' ]]
    printf '%s\n' 'DB_DATABASE=laravel_fixture' > "${tmp}/www/site.example/.env"
    [[ "$(project_get_database_name site.example default)" == laravel_fixture ]]
    echo 'PASS: generation (preservation, constants, destinations, all mutations, atomic cleanup)'
)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_borg_config_generation
fi

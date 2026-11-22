#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#
# Description: Database inventory of a server and the rules that say which project
# owns each database. It is read-only: it never changes the server.
#
# One row per database, tab separated:
#   kind  source  engine  container  database  owner  evidence  size_mb  writes  dormant
#
#   kind      compose | container | host
#   source    stable id: "<project>/<service>" | "<container>" | "host"
#   engine    mariadb | mysql | postgres
#   container container name, "-" for the host
#   owner     project that owns it by STRUCTURE, "-" when nothing says
#   evidence  structure | none
#   size_mb   size of the database
#   writes    writes since the engine started (server level for MySQL/MariaDB)
#   dormant   yes | no | unknown (no writes after at least BROLIT_DB_DORMANT_MIN_UPTIME s)
#
# bdb_resolve adds: state target reason pending
#   state     linked | standalone | ignored | held
#   target    project (linked) | standalone name | "-"
#   reason    structure | decision | file | pending-ambiguous | pending-unmatched |
#             pending-stale | held-dormant
#   pending   1 when a person still has to decide, 0 otherwise
#
# Ownership evidence, strongest first (see docs/plan in brolit-admin,
# 2026-11-borg-database-protection.md):
#   1 structure  compose working dir, or a data bind mount inside the project
#   2 a recorded decision
#   3 file references (.env, wp-config.php, compose): what a project CLAIMS, so it
#     links only when exactly one project references the name AND exactly one source
#     holds that name
#   4 liveness (writes, size): evidence for a person, never decides alone
################################################################################

BROLIT_DB_DORMANT_MIN_UPTIME="${BROLIT_DB_DORMANT_MIN_UPTIME:-14400}"
BROLIT_DB_HELD_MIN_MB="${BROLIT_DB_HELD_MIN_MB:-2048}"
BROLIT_DB_NAME_REGEX='^[A-Za-z0-9_][A-Za-z0-9_.$-]*$'

function bdb_projects_path() {
    echo "${PROJECTS_PATH:-/var/www}"
}

function bdb_exec_path() {
    echo "${BROLIT_DB_EXEC:-${BROLIT_MAIN_DIR}/utils/borg/db_exec.sh}"
}

function bdb_config_file() {
    echo "${BROLIT_CONFIG_FILE:-/root/.brolit_conf.json}"
}

################################################################################
# Run one SQL statement against a database server and print the rows.
# Containers go through db_exec.sh so the credential is resolved inside them.
#
# Arguments: ${1} kind (host|compose|container)  ${2} engine  ${3} container  ${4} sql
################################################################################
function bdb_query() {

    local kind="${1}" engine="${2}" container="${3}" sql="${4}"

    case "${engine}" in
    mariadb | mysql)
        if [[ "${kind}" == "host" ]]; then
            mysql -N -B -e "${sql}" 2>/dev/null
        else
            "$(bdb_exec_path)" client "${engine}" "${container}" -N -B -e "${sql}" 2>/dev/null
        fi
        ;;
    postgres)
        if [[ "${kind}" == "host" ]]; then
            runuser -u postgres -- psql -At -d postgres -c "${sql}" 2>/dev/null
        else
            "$(bdb_exec_path)" client postgres "${container}" -At -d postgres -c "${sql}" 2>/dev/null
        fi
        ;;
    esac

}

################################################################################
# Names of the user databases of one server, one per line. System schemas and
# names that cannot be handled safely (logged) are left out.
################################################################################
function bdb_list_databases() {

    local kind="${1}" engine="${2}" container="${3}"
    local sql name

    if [[ "${engine}" == "postgres" ]]; then
        sql="SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres' ORDER BY 1"
    else
        sql="SHOW DATABASES"
    fi

    while IFS= read -r name; do
        [[ -n "${name}" ]] || continue
        if [[ "${engine}" != "postgres" && "${name}" =~ ^(information_schema|performance_schema|mysql|sys)$ ]]; then
            continue
        fi
        if [[ ! "${name}" =~ ${BROLIT_DB_NAME_REGEX} ]]; then
            log_event "warning" "Database '${name}' on ${container} has a name this backup cannot handle safely; it is not listed" "false"
            continue
        fi
        echo "${name}"
    done < <(bdb_query "${kind}" "${engine}" "${container}" "${sql}")

}

################################################################################
# size_mb <TAB> writes <TAB> dormant for one database.
# MySQL/MariaDB count writes at server level since start (no cheap per-schema
# counter without performance_schema); PostgreSQL counts per database.
################################################################################
function bdb_stats() {

    local kind="${1}" engine="${2}" container="${3}" database="${4}"
    local size writes uptime dormant="unknown" status

    if [[ "${engine}" == "postgres" ]]; then
        size="$(bdb_query "${kind}" "${engine}" "${container}" "SELECT ROUND(pg_database_size('${database}')/1024/1024)")"
        writes="$(bdb_query "${kind}" "${engine}" "${container}" "SELECT COALESCE(tup_inserted+tup_updated+tup_deleted,0) FROM pg_stat_database WHERE datname='${database}'")"
        uptime="$(bdb_query "${kind}" "${engine}" "${container}" "SELECT FLOOR(EXTRACT(EPOCH FROM now()-pg_postmaster_start_time()))")"
    else
        size="$(bdb_query "${kind}" "${engine}" "${container}" "SELECT IFNULL(ROUND(SUM(data_length+index_length)/1024/1024),0) FROM information_schema.tables WHERE table_schema='${database}'")"
        status="$(bdb_query "${kind}" "${engine}" "${container}" "SHOW GLOBAL STATUS WHERE Variable_name IN ('Com_insert','Com_update','Com_delete','Com_replace','Uptime')")"
        writes="$(awk '$1 ~ /^Com_/ {s += $2} END {print s + 0}' <<<"${status}")"
        uptime="$(awk '$1 == "Uptime" {print $2}' <<<"${status}")"
        [[ -n "${status}" ]] || writes=""
    fi

    [[ "${size}" =~ ^[0-9]+$ ]] || size="-"
    [[ "${writes}" =~ ^[0-9]+$ ]] || writes="-"
    if [[ "${writes}" != "-" && "${uptime}" =~ ^[0-9]+$ ]]; then
        if [[ "${writes}" -eq 0 && "${uptime}" -ge "${BROLIT_DB_DORMANT_MIN_UPTIME}" ]]; then
            dormant="yes"
        elif [[ "${writes}" -gt 0 ]]; then
            dormant="no"
        fi
    fi

    printf '%s\t%s\t%s\n' "${size}" "${writes}" "${dormant}"

}

################################################################################
# Engine of a container from its image: mariadb | mysql | postgres | "".
################################################################################
function bdb_container_engine() {

    local container="${1}" image env

    image="$(docker inspect -f '{{.Config.Image}}' "${container}" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    image="${image##*/}"
    case "${image}" in
    mariadb*) echo "mariadb"; return 0 ;;
    mysql*) echo "mysql"; return 0 ;;
    postgres* | timescaledb*) echo "postgres"; return 0 ;;
    esac

    # An image referenced only by its id says nothing (seen on gaucho-dev04). Only
    # then use the container's own environment; doing it for named images would
    # mistake application containers that carry a MYSQL_DATABASE variable.
    if [[ "${image}" =~ ^(sha256:)?[0-9a-f]{12,64}$ ]]; then
        env="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "${container}" 2>/dev/null)"
        if grep -qE '^MARIADB_(ROOT_PASSWORD|DATABASE|RANDOM_ROOT_PASSWORD)=' <<<"${env}"; then
            echo "mariadb"
        elif grep -qE '^MYSQL_(ROOT_PASSWORD|DATABASE|RANDOM_ROOT_PASSWORD)=' <<<"${env}"; then
            echo "mysql"
        elif grep -qE '^POSTGRES_(PASSWORD|DB)=' <<<"${env}"; then
            echo "postgres"
        fi
    fi

}

# Project name (first path component below the projects path) of a path, or "".
function bdb_project_of_path() {

    local path="${1}" root
    root="$(bdb_projects_path)"
    root="${root%/}/"
    [[ "${path}" == "${root}"* ]] || return 0
    path="${path#"${root}"}"
    echo "${path%%/*}"

}

# Project that owns a container by structure: compose working dir, else a bind
# mount whose source is inside a project directory. Empty when nothing says.
function bdb_container_owner() {

    local container="${1}" workdir mount owner
    workdir="$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "${container}" 2>/dev/null)"
    owner="$(bdb_project_of_path "${workdir}")"
    if [[ -n "${owner}" ]]; then
        echo "${owner}"
        return 0
    fi
    while IFS= read -r mount; do
        owner="$(bdb_project_of_path "${mount}")"
        if [[ -n "${owner}" ]]; then
            echo "${owner}"
            return 0
        fi
    done < <(docker inspect -f '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' "${container}" 2>/dev/null)

}

# Emit the rows for the databases of one server.
function bdb_emit_server() {

    local kind="${1}" source="${2}" engine="${3}" container="${4}" owner="${5}"
    local database stats evidence="structure"
    [[ -n "${owner}" ]] || { owner="-"; evidence="none"; }

    while IFS= read -r database; do
        [[ -n "${database}" ]] || continue
        stats="$(bdb_stats "${kind}" "${engine}" "${container}" "${database}")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${kind}" "${source}" "${engine}" "${container}" "${database}" "${owner}" "${evidence}" "${stats}"
    done < <(bdb_list_databases "${kind}" "${engine}" "${container}")

}

################################################################################
# Collect the inventory (rows described in the header) on stdout.
# Sources: compose database services, other running database containers, and the
# engines installed on the host.
################################################################################
function bdb_collect() {

    local projects compose project service engine container seen=" "
    projects="$(bdb_projects_path)"

    # 1. Compose projects: every real database service of every compose file
    for compose in "${projects}"/*/docker-compose.yml "${projects}"/*/docker-compose.yaml; do
        [[ -f "${compose}" ]] || continue
        project="$(basename "$(dirname "${compose}")")"
        while IFS=$'\t' read -r service engine; do
            [[ -n "${service}" ]] || continue
            container="$(docker ps --filter "label=com.docker.compose.project.working_dir=$(dirname "${compose}")" --filter "label=com.docker.compose.service=${service}" --format '{{.Names}}' 2>/dev/null | head -1)"
            if [[ -z "${container}" ]]; then
                log_event "warning" "Database service '${service}' of ${project} is defined but not running; it cannot be listed" "false"
                continue
            fi
            [[ "${seen}" == *" ${container} "* ]] && continue
            seen="${seen}${container} "
            # docker_list_project_databases says "mysql" for both; the image tells MariaDB apart
            if [[ "${engine}" == "mysql" ]]; then
                engine="$(bdb_container_engine "${container}")"
                [[ -n "${engine}" ]] || engine="mysql"
            fi
            bdb_emit_server "compose" "${project}/${service}" "${engine}" "${container}" "${project}"
        done < <(docker_list_project_databases "${compose}" 2>/dev/null)
    done

    # 2. Other running database containers (started without Compose, or whose
    # service the compose detection did not recognise)
    while IFS= read -r container; do
        [[ -n "${container}" ]] || continue
        [[ "${seen}" == *" ${container} "* ]] && continue
        engine="$(bdb_container_engine "${container}")"
        [[ -n "${engine}" ]] || continue
        seen="${seen}${container} "
        bdb_emit_server "container" "${container}" "${engine}" "${container}" "$(bdb_container_owner "${container}")"
    done < <(docker ps --format '{{.Names}}' 2>/dev/null)

    # 3. Engines installed on the host
    if command -v mysql >/dev/null 2>&1 && mysqladmin ping >/dev/null 2>&1; then
        engine="mysql"
        mysql --version 2>/dev/null | grep -qi mariadb && engine="mariadb"
        bdb_emit_server "host" "host" "${engine}" "-" ""
    fi
    if command -v psql >/dev/null 2>&1 && command -v pg_isready >/dev/null 2>&1 && pg_isready -q 2>/dev/null; then
        bdb_emit_server "host" "host" "postgres" "-" ""
    fi


}

################################################################################
# Running containers of engines whose data this backup cannot dump yet. They are
# reported, never ignored. Redis/Valkey/Memcached are caches, MinIO is files.
# Output: container <TAB> image <TAB> owner
################################################################################
function bdb_collect_unsupported() {

    local container image
    while IFS=$'\t' read -r container image; do
        image="${image##*/}"
        case "${image%%[:@]*}" in
        clickhouse* | mongo | mongodb* | couchdb | cassandra | influxdb | neo4j | arangodb)
            printf '%s\t%s\t%s\n' "${container}" "${image}" "$(bdb_container_owner "${container}")"
            ;;
        esac
    done < <(docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null)

}

################################################################################
# Decisions recorded in the server configuration:
#   BACKUPS.config[0].databases[0].decisions[] = {source, database, decision, project}
# (every section of the configuration is an array of one object, databases included)
# Output: source <TAB> database <TAB> decision(ignore|standalone|link) <TAB> project
################################################################################
function bdb_decisions_tsv() {

    local file
    file="$(bdb_config_file)"
    [[ -r "${file}" ]] || return 0
    if ! jq -r '.BACKUPS.config[0].databases[0].decisions[]? | [.source, .database, .decision, (.project // "")] | @tsv' "${file}" 2>/dev/null; then
        log_event "warning" "Could not read the database decisions from ${file}; none is applied" "false"
    fi

}

# Candidate files that can name a database for a project (bounded, small files).
function bdb_reference_files() {

    local projects
    projects="$(bdb_projects_path)"
    find "${projects}" -maxdepth 3 \
        \( -name node_modules -o -name vendor -o -name .git -o -name 'mysql_data*' -o -name 'postgres_data*' -o -name storage -o -name data -o -name volumes \) -prune -o \
        -type f \( -name '.env' -o -name '.env.*' -o -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' -o -name 'wp-config.php' \) -size -256k -print 2>/dev/null

}

################################################################################
# Projects whose reference files name a database (whole word). One per line.
################################################################################
function bdb_file_refs() {

    local database="${1}" file_list="${2}" file
    while IFS= read -r file; do
        [[ -n "${file}" ]] || continue
        grep -qwFs -- "${database}" "${file}" 2>/dev/null && bdb_project_of_path "${file}"
    done <"${file_list}" | sort -u

}

################################################################################
# Resolve every row of the inventory (stdin) to a state. Output: the input
# columns followed by  state <TAB> target <TAB> reason <TAB> pending
#
# A pending database (ambiguous, unmatched, stale decision) is dumped as
# standalone. A large dormant one that rests on weak evidence (pending, or linked
# only by file references) is held until a person decides.
################################################################################
function bdb_resolve() {

    local -a rows=()
    local row kind source engine container database owner evidence size writes dormant
    local state target reason pending decided key decision_project
    local projects refs ref_count only_ref name_sources
    local -A name_count=() decisions=() decision_projects=()
    local file_list

    projects="$(bdb_projects_path)"
    while IFS= read -r row; do
        [[ -n "${row}" ]] || continue
        rows+=("${row}")
        IFS=$'\t' read -r _ _ _ _ database _ <<<"${row}"
        name_count["${database}"]=$((${name_count["${database}"]:-0} + 1))
    done

    while IFS=$'\t' read -r source database decided decision_project; do
        [[ -n "${source}" ]] || continue
        decisions["${source}|${database}"]="${decided}"
        decision_projects["${source}|${database}"]="${decision_project}"
    done < <(bdb_decisions_tsv)

    file_list="$(mktemp)"
    bdb_reference_files >"${file_list}"

    for row in "${rows[@]}"; do
        IFS=$'\t' read -r kind source engine container database owner evidence size writes dormant <<<"${row}"
        key="${source}|${database}"
        state=""
        target="-"
        reason=""
        pending=0

        if [[ -n "${decisions[${key}]:-}" ]]; then
            case "${decisions[${key}]}" in
            ignore)
                state="ignored"; reason="decision"
                ;;
            standalone)
                state="standalone"; reason="decision"
                ;;
            link)
                if [[ -n "${decision_projects[${key}]}" && -d "${projects}/${decision_projects[${key}]}" ]]; then
                    state="linked"; target="${decision_projects[${key}]}"; reason="decision"
                else
                    state="standalone"; reason="pending-stale"; pending=1
                fi
                ;;
            esac
        fi

        if [[ -z "${state}" && "${owner}" != "-" ]]; then
            state="linked"; target="${owner}"; reason="structure"
        fi

        if [[ -z "${state}" ]]; then
            refs="$(bdb_file_refs "${database}" "${file_list}")"
            ref_count=0
            [[ -n "${refs}" ]] && ref_count="$(grep -c . <<<"${refs}")"
            only_ref="${refs%%$'\n'*}"
            name_sources="${name_count[${database}]:-1}"
            if [[ "${ref_count}" -eq 1 && "${name_sources}" -eq 1 ]]; then
                state="linked"; target="${only_ref}"; reason="file"
            else
                state="standalone"; pending=1
                if [[ "${ref_count}" -ge 1 || "${name_sources}" -gt 1 ]]; then
                    reason="pending-ambiguous"
                else
                    reason="pending-unmatched"
                fi
            fi
        fi

        # Never a nightly of dormant gigabytes on weak evidence. Structure and an
        # explicit decision are trusted; a pending database or a link that rests only
        # on file references is held until a person decides (stellacast-vm: the host
        # copy "stellacast_prod" is named by the app's files, has 14 GB and no writes).
        if [[ "${reason}" != "structure" && "${reason}" != "decision" && "${dormant}" == "yes" && "${size}" =~ ^[0-9]+$ && "${size}" -ge "${BROLIT_DB_HELD_MIN_MB}" ]]; then
            state="held"; target="-"; reason="held-dormant"; pending=1
        fi

        if [[ "${state}" == "standalone" ]]; then
            target="$(bdb_standalone_name "${source}" "${database}")"
        fi

        printf '%s\t%s\t%s\t%s\t%s\n' "${row}" "${state}" "${target}" "${reason}" "${pending}"
    done

    rm -f "${file_list}"

}

# Stable, filesystem- and repository-safe name for a standalone database.
function bdb_standalone_name() {

    local source="${1}" database="${2}" name
    name="${source//\//-}-${database}"
    echo "standalone-${name//[^A-Za-z0-9_.-]/_}"

}

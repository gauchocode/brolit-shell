#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#
# Description: Runs a database client INSIDE a container on behalf of borgmatic.
#
# borgmatic's own "container" option connects over the network from the host and
# needs the dump client installed on the host, which Docker hosts do not have.
# The documented alternative is a custom dump command, which is this script:
#
#   mariadb_dump_command: /root/brolit-shell/utils/borg/db_exec.sh dump mariadb <container>
#   mariadb_command:      /root/brolit-shell/utils/borg/db_exec.sh client mariadb <container>
#   pg_dump_command:      /root/brolit-shell/utils/borg/db_exec.sh dump postgres <container>
#
# The superuser credential is read by the container from its own environment (or
# its *_FILE secret) and handed to the client through the client's environment
# inside the container. It never reaches the host: not argv, not a file, not a log.
#
# usage: db_exec.sh <dump|client|restore> <mariadb|mysql|postgres> <container> [args from borgmatic...]
#   dump     mariadb-dump / mysqldump / pg_dump; honours --result-file / --file
#   client   mariadb / mysql / psql (restore of a plain dump, database listing)
#   restore  pg_restore
#
# Connection flags borgmatic may pass (host, port, user, password, socket,
# protocol, defaults files) describe a connection from the host and are dropped:
# the client already runs next to the server.
################################################################################

set -uo pipefail

usage() {
    echo "usage: db_exec.sh <dump|client|restore> <mariadb|mysql|postgres> <container> [args...]" >&2
    exit 64
}

[[ $# -ge 3 ]] || usage
mode="${1}"
engine="${2}"
container="${3}"
shift 3

case "${mode}" in dump | client | restore) ;; *) usage ;; esac
case "${engine}" in mariadb | mysql | postgres) ;; *) usage ;; esac
[[ "${container}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || {
    echo "db_exec.sh: invalid container name" >&2
    exit 64
}
# Arguments borgmatic builds for a client that connects from the host. They are
# dropped because the client runs next to the server; --result-file / --file name
# the output (a named pipe) and are redirected here instead of inside the container.
args=()
result=""
skip_next=0
take_result=0
for arg in "$@"; do
    if [[ ${take_result} -eq 1 ]]; then
        result="${arg}"
        take_result=0
        continue
    fi
    if [[ ${skip_next} -eq 1 ]]; then
        skip_next=0
        continue
    fi
    case "${arg}" in
        --result-file | --file)
            take_result=1
            ;;
        --result-file=* | --file=*)
            result="${arg#*=}"
            ;;
        -f)
            # pg_dump short form of --file; pg_restore uses -f for something else
            if [[ "${mode}" == "dump" && "${engine}" == "postgres" ]]; then take_result=1; else args+=("${arg}"); fi
            ;;
        --host | --port | --protocol | --user | --username | --socket | --defaults-extra-file | --defaults-file)
            skip_next=1
            ;;
        --host=* | --port=* | --protocol=* | --user=* | --username=* | --socket=* | --defaults-extra-file=* | --defaults-file=* | --password=* | --no-password)
            ;;
        -h | -P | -u | -S | -U)
            skip_next=1
            ;;
        -p | -h?* | -P?* | -u?* | -S?* | -U?* | -p?*)
            # bare -p (password prompt) and the attached forms (-pSECRET, -hhost, ...)
            ;;
        *)
            args+=("${arg}")
            ;;
    esac
done

# Script run by the container's shell. $1 is the engine, $2 the mode; the rest are the
# client arguments. Credentials are resolved here, inside the container.
# shellcheck disable=SC2016
inner='
engine="$1"; mode="$2"; shift 2
secret() { # secret VAR [VAR...]: first non-empty value, or the content of VAR_FILE
    for v in "$@"; do
        eval "val=\${$v:-}"
        [ -n "$val" ] && { printf "%s" "$val"; return 0; }
        eval "f=\${${v}_FILE:-}"
        [ -n "$f" ] && [ -r "$f" ] && { cat "$f"; return 0; }
    done
    return 1
}
case "$engine" in
    mariadb|mysql)
        pw="$(secret MYSQL_ROOT_PASSWORD MARIADB_ROOT_PASSWORD)" && export MYSQL_PWD="$pw"
        if [ "$mode" = dump ]; then
            if [ "$engine" = mariadb ]; then bin="$(command -v mariadb-dump || command -v mysqldump)"; else bin="$(command -v mysqldump || command -v mariadb-dump)"; fi
        else
            if [ "$engine" = mariadb ]; then bin="$(command -v mariadb || command -v mysql)"; else bin="$(command -v mysql || command -v mariadb)"; fi
        fi
        [ -n "$bin" ] || { echo "db_exec.sh: no $engine client in the container" >&2; exit 127; }
        exec "$bin" -uroot "$@"
        ;;
    postgres)
        user="${POSTGRES_USER:-postgres}"
        pw="$(secret POSTGRES_PASSWORD)" && export PGPASSWORD="$pw"
        case "$mode" in
            dump) bin=pg_dump ;;
            restore) bin=pg_restore ;;
            *) bin=psql ;;
        esac
        command -v "$bin" >/dev/null 2>&1 || { echo "db_exec.sh: no $bin in the container" >&2; exit 127; }
        if [ "$mode" = restore ]; then
            # pg_restore --clean --dbname needs the database to exist, and on a server
            # being recovered it does not (a MariaDB dump carries its own CREATE
            # DATABASE; this one does not). Create it, only here and only when missing.
            prev=""; db=""
            for a in "$@"; do
                [ "$prev" = "--dbname" ] && db="$a"
                case "$a" in --dbname=*) db="${a#--dbname=}" ;; esac
                prev="$a"
            done
            case "$db" in
                ""|*[!A-Za-z0-9_.$-]*) ;;
                *)
                    psql -U "$user" -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '"'"'$db'"'"'" 2>/dev/null | grep -q 1 \
                        || createdb -U "$user" "$db" || exit 1
                    ;;
            esac
        fi
        exec "$bin" -U "$user" "$@"
        ;;
esac
'

if [[ -n "${result}" ]]; then
    exec docker exec -i "${container}" sh -c "${inner}" sh "${engine}" "${mode}" "${args[@]}" >"${result}"
fi
exec docker exec -i "${container}" sh -c "${inner}" sh "${engine}" "${mode}" "${args[@]}"

#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Database Controller: Controller for database functions.
#
################################################################################

################################################################################
# List databases
#
# Arguments:
#  ${1} - ${stage}              - Options: all, prod, dev, test, stage
#  ${2} - ${database_engine}    - Options: mysql, postgres
#  ${3} - ${database_container} - Optional
#
# Outputs:
#  ${databases}, 1 on error.
################################################################################

function database_list() {

    local stage="${1}"
    local database_engine="${2}"
    local database_container="${3}"

    case ${database_engine} in

    MYSQL | mysql | mariadb)

        mysql_list_databases "${stage}" "${database_container}"
        return $?
        ;;

    POSTGRESQL | postgres | postgresql)

        postgres_list_databases "${stage}" "${database_container}"
        return $?
        ;;

    *)
        # Log
        log "error" "Database engine not supported: ${database_engine}"
        return 1
        ;;

    esac

}

################################################################################
# Drop database
#
# Arguments:
#  ${1} = ${database_name}
#  ${2} = ${database_engine}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function database_drop() {

    local database_name="${1}"
    local database_engine="${2}"
    local database_container="${3}"

    case ${database_engine} in

    MYSQL | mysql | mariadb)

        mysql_database_drop "${database_name}" "${install_type}"
        return $?
        ;;

    POSTGRESQL | postgres | postgresql)

        postgres_database_drop "${database_name}" "${install_type}"
        return $?
        ;;

    *)
        # Log
        log "error" "Database engine not supported: ${database_engine}"
        return 1
        ;;

    esac

}

################################################################################
# Create database
#
# Arguments:
#  ${1} = ${database_name}
#  ${2} = ${database_engine}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function database_users_list() {
    
        local database_engine="${1}"
        local database_container="${2}"
    
        case ${database_engine} in
    
        MYSQL | mysql | mariadb)
    
            mysql_users_list "${database_container}"
            return $?
            ;;
    
        POSTGRESQL | postgres | postgresql)
    
            postgres_users_list "${database_container}"
            return $?
            ;;
    
        *)
            # Log
            log "error" "Database engine not supported: ${database_engine}"
            return 1
            ;;
    
        esac
    
}

################################################################################
# Drop database
#
# Arguments:
#  ${1} = ${database_user}
#  ${2} = ${database_user_scope}
#  ${3} = ${database_engine}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function database_user_delete() {

    local database_user="${1}"
    local database_user_scope="${2}"
    local database_engine="${3}"
    local database_container="${4}"

    case ${database_engine} in

    MYSQL | mysql | mariadb)

        mysql_user_delete "${database_user}" "${database_user_scope}"
        return $?
        ;;

    POSTGRESQL | postgres | postgresql)

        postgres_user_delete "${database_user}" "${database_user_scope}"
        return $?
        ;;

    *)
        # Log
        log "error" "Database engine not supported: ${database_engine}"
        return 1
        ;;

    esac

}

################################################################################
# Database import
#
# Arguments:
#  ${1} = ${db_engine} - Database engine (mysql, postgres)
#  ${2} = ${db_name} - Database name
#  ${3} = ${dump_file} - SQL dump file path
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function database_import() {
    local db_engine="${1}"
    local db_name="${2}"
    local dump_file="${3}"

    case ${db_engine} in
        MYSQL|mysql)
            mysql_database_import "${db_name}" "false" "${dump_file}"
            ;;
        POSTGRESQL|postgres)
            postgres_database_import "${db_name}" "${dump_file}"
            ;;
        *)
            log_event "error" "Database engine not supported: ${db_engine}" "false"
            return 1
            ;;
    esac
}

#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.3
################################################################################
#
# Database Controller: Controller for database functions.
#
################################################################################

################################################################################
# Drop database
#
# Arguments:
#  $1 = ${database_name}
#  $2 = ${database_engine}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function database_drop() {

    local database_name="${1}"
    local database_engine="${2}"

    case ${database_engine} in

    mysql)

        mysql_database_drop "${database_name}"
        return $?
        ;;

    postgres)

        postgres_database_drop "${database_name}"
        return $?
        ;;

    *)
        return 1
        ;;

    esac

}

################################################################################
# Drop database
#
# Arguments:
#  $1 = ${database_user}
#  $2 = ${database_user_scope}
#  $3 = ${database_engine}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function database_user_delete() {

    local database_user="${1}"
    local database_user_scope="${2}"
    local database_engine="${3}"

    case ${database_engine} in

    mysql)

        mysql_user_delete "${database_user}" "${database_user_scope}"
        return $?
        ;;

    postgres)

        postgres_user_delete "${database_user}" "${database_user_scope}"
        return $?
        ;;

    *)
        return 1
        ;;

    esac

}

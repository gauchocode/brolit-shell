#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.0-beta
################################################################################
#
# Database Controller: Controller for database functions.
#
################################################################################

################################################################################
# List databases
#
# Arguments:
#  ${1} - ${stage} - Options: all, prod, dev, test, stage
#  ${2} - ${database_engine}
#  ${3} - ${install_type}
#
# Outputs:
#  ${databases}, 1 on error.
################################################################################

function database_list_all() {

    local stage="${1}"
    local database_engine="${2}"
    local install_type="${3}"

    local mysql_containers
    local mysql_container=""

    # If install_type == docker
    if [[ ${install_type} == "docker"* ]]; then

        # List all running mysql containers
        mysql_containers="$(docker ps --filter "name=mariadb" --format "{{.Names}}")"

        # Ask wich mysql container to use
        mysql_container="$(whiptail --title "MySQL Container" --menu "Choose the MySQL container to use:" 20 78 10 ${mysql_containers} 3>&1 1>&2 2>&3)"

    fi

    case ${database_engine} in

    mysql)

        mysql_list_databases "${stage}" "${mysql_container}"
        return $?
        ;;

    postgres)

        postgres_list_databases "${stage}" "${mysql_container}"
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
#  ${1} = ${database_name}
#  ${2} = ${database_engine}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function database_drop() {

    local database_name="${1}"
    local database_engine="${2}"
    local install_type="${3}"

    case ${database_engine} in

    mysql)

        mysql_database_drop "${database_name}" "${install_type}"
        return $?
        ;;

    postgres)

        postgres_database_drop "${database_name}" "${install_type}"
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
    local install_type="${4}"

    case ${database_engine} in

    mysql)

        mysql_user_delete "${database_user}" "${database_user_scope}" "${install_type}"
        return $?
        ;;

    postgres)

        postgres_user_delete "${database_user}" "${database_user_scope}" "${install_type}"
        return $?
        ;;

    *)
        return 1
        ;;

    esac

}

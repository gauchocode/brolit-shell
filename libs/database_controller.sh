#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.5
################################################################################
#
# Database Controller: Controller for database functions.
#
################################################################################

################################################################################
# Docker exec function for database controller
#
# Arguments:
#  $1 = ${docker_env_file}
#
# Outputs:
#  ${mysql_docker_exec}
################################################################################

function database_docker_exec_mysql() {

    local docker_env_file="${1}"

    local project_name
    local container_name
    local mysql_user
    local mysql_user_passw

    declare -g MYSQL_DOCKER_EXEC

    # container_name: mariadb_${PROJECT_NAME}
    project_name="$(project_get_config_var "${docker_env_file}" "PROJECT_NAME")"

    container_name="${project_name}_mariadb"
    mysql_user="$(project_get_config_var "${docker_env_file}" "MYSQL_USER")"
    mysql_user_passw="$(project_get_config_var "${docker_env_file}" "MYSQL_PASSWORD")"

    MYSQL_DOCKER_EXEC="docker exec -i ${container_name} mysql -u${mysql_user} -p${mysql_user_passw}"

    #echo "${mysql_docker_exec}"
    export MYSQL_DOCKER_EXEC

}

################################################################################
# List databases
#
# Arguments:
#  $1 - ${stage} - Options: all, prod, dev, test, stage
#  $2 - ${database_engine}
#  $3 - ${install_type}
#
# Outputs:
#  ${databases}, 1 on error.
################################################################################

function database_list_all() {

    local stage="${1}"
    local database_engine="${2}"
    local install_type="${3}"

    case ${database_engine} in

    mysql)

        mysql_list_databases "${stage}" "${install_type}"
        return $?
        ;;

    postgres)

        postgres_list_databases "${stage}" "${install_type}"
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
#  $1 = ${database_name}
#  $2 = ${database_engine}
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

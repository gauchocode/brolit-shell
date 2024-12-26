#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.9
#############################################################################

################################################################################
# Docker WordPress install.
#
# Arguments:
#   ${1} = ${project_path}
#   ${2} = ${project_domain}
#   ${3} = ${project_name}
#   ${4} = ${project_stage}
#   ${5} = ${project_root_domain}         # Optional
#   ${6} = ${docker_compose_template}     # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: needs refactor

function test_docker_helper_functions() {

    # TODO: create a function that change WP_PORT (always assign a new port that is not in use)

    local project_port

    project_port=88

    network_port_is_use "${project_port}"
    [[ $? -eq 0 ]] && return 1

    # Ask project stage
    project_stage="$(project_ask_stage "prod")"
    [[ $? -eq 1 ]] && return 1

    # Project domain
    project_domain="$(project_ask_domain "")"
    [[ $? -eq 1 ]] && return 1

    root_domain="$(domain_get_root "${project_domain}")"

    project_name="$(project_get_name_from_domain "${project_domain}")"

    # Docker Wordpress Install
    #docker_wordpress_install "/var/www/${project_domain}" "${project_domain}" "${project_name}" "${project_stage}" "${root_domain}" "${project_port}" "default"

    # TODO: read .env to get mysql pass

    # Docker MySQL database import
    docker_mysql_database_import "mariadb_${project_name}" "${project_name}_user" "db_user_pass" "${project_name}_prod" "assets/dump.sql"

    # Docker MySQL database backup
    docker_mysql_database_export "mariadb_${project_name}" "${project_name}_user" "db_user_pass" "${project_name}_prod" "assets/dump.sql"

    # Docker list images
    #docker_list_images

    # Docker project files import
    # TODO: should only import wp-content? how about wp-config.php?
    # docker_project_files_import "/root/backup.tar.bz2" "/var/www/${project_domain}" "wordpress"

    # Create nginx proxy if nginx is installed
    ## TODO: read port from docker-compose .env file
    nginx_server_create "dockertest.gauchocode.net" "proxy" "single" "" "${project_port}"

    # TODO: run wp-cli commands?

    # TODO: generate certbot certificates and install it.

}

function test_docker_database_backup() {
    
#project_get_install_type "/var/www/wordpress39.broobe.net"
# Docker MySQL database backup
#mysql_database_export "wordpress39_prod" "wordpress39_mysql" "assets/dump.sql"
#backup_project_database "wordpress39_prod" "mysql" "wordpress39_mysql"
#backup_project "wordpress39.broobe.net" "databases" Este no funciona para docker!

  local project_domain="${1}"
  local backup_type="${2}"

  local got_error=0

  local db_stage
  local db_name
  local db_engine
  local backup_file
  local project_type

    # Backup files
    log_subsection "Backup Project Files"
    backup_file_size="$(backup_project_files "site" "${PROJECTS_PATH}" "${project_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Project Type
      project_type="$(project_get_type "${PROJECTS_PATH}/${project_domain}")"

      # Project install type
      project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")"

      # If ${project_install_type} == docker -> docker_mysql_database_backup ?
      # Should consider the case where a project is dockerized but uses an external database?
      if [[ ${project_install_type} == "docker"* && ${project_type} != "html" ]]; then

          backup_project_database "${db_name}" "${db_engine}" "${container_name}"

      fi

      log_break "false"

      # Delete local backup
      rm --recursive --force "${BROLIT_TMP_DIR}/${NOW}/${backup_type:?}"
      #log_event "info" "Deleting backup from server ..." "false"

      # Log
      log_break "false"
      log_event "info" "Project backup finished!" "false"
      display --indent 6 --text "- Project Backup" --result "DONE" --color GREEN

      return ${got_error}

    else

      # Log
      log_break "false"
      log_event "error" "Something went wrong making the files backup" "false"
      display --indent 6 --text "- Project Backup" --result "FAIL" --color RED
      display --indent 8 --text "Something went wrong making the files backup" --tcolor RED

      return 1

    fi
}
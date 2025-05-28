#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
################################################################################
#
# Backup/Restore Manager: Perform backup and restore actions.
#
################################################################################

################################################################################
# Backup Manager Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function backup_manager_menu() {

  local backup_options
  local chosen_backup_type

  backup_options=(
    "01)" "BACKUP ALL"
    "02)" "BACKUP DATABASES"
    "03)" "BACKUP FILES"
    "04)" "BACKUP PROJECT"
    "05)" "BACKUP DOCKER VOLUMES (BETA)"
  )

  chosen_backup_type="$(whiptail --title "SELECT BACKUP TYPE" --menu " " 20 78 10 "${backup_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # BACKUP ALL
    if [[ ${chosen_backup_type} == *"01"* ]]; then

      # BACKUP_ALL
      log_section "Backup All"

      # Preparing Mail Notifications Template
      mail_server_status_section

      # Databases Backup
      backup_all_databases

      # Files Backup
      backup_all_files

      # Configs Backup
      backup_all_files_with_borg

      # Footer
      mail_footer "${SCRIPT_V}"

      # Preparing Mail Notifications Template
      email_template="default"

      # New full email file
      email_html_file="${BROLIT_TMP_DIR}/full-email-${NOW}.mail"

      # Copy from template
      cp "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/main-tpl.html" "${email_html_file}"

      # Begin to replace
      sed -i '/{{server_info}}/r '"${BROLIT_TMP_DIR}/server_info-${NOW}.mail" "${email_html_file}"
      sed -i '/{{databases_backup_section}}/r '"${BROLIT_TMP_DIR}/databases-bk-${NOW}.mail" "${email_html_file}"
      sed -i '/{{configs_backup_section}}/r '"${BROLIT_TMP_DIR}/configuration-bk-${NOW}.mail" "${email_html_file}"
      sed -i '/{{files_backup_section}}/r '"${BROLIT_TMP_DIR}/files-bk-${NOW}.mail" "${email_html_file}"
      sed -i '/{{footer}}/r '"${BROLIT_TMP_DIR}/footer-${NOW}.mail" "${email_html_file}"

      # Delete vars not used anymore
      grep -v "{{packages_section}}" "${email_html_file}" >"${email_html_file}_tmp"
      mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{certificates_section}}" "${email_html_file}" >"${email_html_file}_tmp"
      mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
      mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{databases_backup_section}}" "${email_html_file}" >"${email_html_file}_tmp"
      mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{configs_backup_section}}" "${email_html_file}" >"${email_html_file}_tmp"
      mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{files_backup_section}}" "${email_html_file}" >"${email_html_file}_tmp"
      mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{footer}}" "${email_html_file}" >"${email_html_file}_tmp"
      mv "${email_html_file}_tmp" "${email_html_file}"

      # Send html to a var
      mail_html="$(cat "${email_html_file}")"

      # Checking result status for mail subject
      email_status="$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${OUTDATED_PACKAGES}")"

      email_subject="${email_status} [${NOWDISPLAY}] - Complete Backup on ${SERVER_NAME}"

      # Sending notifications
      mail_send_notification "${email_subject}" "${mail_html}"
      send_notification "${SERVER_NAME}" "Task: 'Backup All' completed." "success"

    fi
    
    # BACKUP DATABASES
    if [[ ${chosen_backup_type} == *"02"* ]]; then

      # DATABASE_BACKUP
      log_section "Databases Backup"

      # Preparing Mail Notifications Template
      mail_server_status_section

      # Databases Backup
      backup_all_databases

      DB_MAIL="${BROLIT_TMP_DIR}/databases-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      email_subject="${STATUS_ICON_D} [${NOWDISPLAY}] - Database Backup on ${SERVER_NAME}"
      email_content="${HTMLOPEN} ${BODY_SRV} ${DB_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending notifications
      mail_send_notification "${email_subject}" "${email_content}"
      send_notification "${SERVER_NAME}" "Task: 'Databases Backup' completed." "success"

    fi

    # BACKUP FILES
    if [[ ${chosen_backup_type} == *"03"* ]]; then

      # FILES_BACKUP

      log_section "Files Backup"

      # Preparing Mail Notifications Template
      mail_server_status_section

      # Files Backup
      backup_all_files

      CONFIG_MAIL_VAR=$(cat "${BROLIT_TMP_DIR}/configuration-bk-${NOW}.mail")

      FILE_MAIL_VAR=$(cat "${BROLIT_TMP_DIR}/files-bk-${NOW}.mail")

      email_subject="${STATUS_ICON_F} [${NOWDISPLAY}] - Files Backup on ${SERVER_NAME}"
      email_content="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending notifications
      mail_send_notification "${email_subject}" "${email_content}"
      send_notification "${SERVER_NAME}" "Task: 'Files Backup' completed." "success"

    fi

    # BACKUP PROJECT
    if [[ ${chosen_backup_type} == *"04"* ]]; then

      # PROJECT_BACKUP
      log_section "Project Backup"

      # Select project to work with
      directory_browser "Select a project to work with" "${PROJECTS_PATH}" #return $filename

      # Directory_broser returns: $filepath and $filename
      if [[ ${filename} != "" && ${filepath} != "" ]]; then

        DOMAIN="$(basename "${filepath}/${filename}")"

        INSTALL_TYPE=$(project_get_install_type "${filepath}/${filename}")

        if [[ ${INSTALL_TYPE} == "docker-compose" ]]; then

          backup_docker_project "${DOMAIN}" "all"

        else

          backup_project "${DOMAIN}" "all"

        fi

        backup_project_with_borg "${DOMAIN}"

        # Sending notifications
        #mail_send_notification "${email_subject}" "${email_content}"
        send_notification "${SERVER_NAME}" "Task: 'Project Backup' completed." "success"

      else

        display --indent 6 --text "- Project backup" --result "SKIPPED" --color YELLOW

      fi

    fi

    # BACKUP DOCKER VOLUMES
    if [[ ${chosen_backup_type} == *"05"* ]]; then

      # DOCKER_VOLUMES_BACKUP
      log_section "Docker Volumes Backup"

      # Docker Volumes Backup
      catch_error="$(backup_all_docker_volumes)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 1 ]]; then

        # Log
        log_event "error" "Docker Volumes Backup failed: ${catch_error}" "false"
        display --indent 6 --text "- Docker Volumes Backup" --result "FAILED" --color RED

        # Send notification
        send_notification "${SERVER_NAME} " "Docker Volumes Backup failed." "alert"

        return 1

      fi

      # Send notification
      send_notification "${SERVER_NAME} " "Task: 'Docker Volumes Backup' completed." "success"

    fi

  fi

  menu_main_options

}

################################################################################
# Backup All Docker Volumes
#
# Arguments:
#
# Outputs:
#   nothing
################################################################################

function backup_all_docker_volumes() {

  local remote_path
  local volumes_to_backup

  local exitstatus=0
  local error_msg=""
  local error_type=""

  # Remote Path
  remote_path="${SERVER_NAME}/projects-online/docker-volume"

  # Get a list of all Docker volumes
  volumes_to_backup="$(docker volume ls --format "{{.Name}}")"

  # If there are no volumes to backup, exit
  if [[ -z "${volumes_to_backup}" ]]; then

    # Log
    display --indent 6 --text "- Docker volumes backup" --result "SKIPPED" --color YELLOW
    display --indent 8 --text "- No Docker volumes to backup" --tcolor YELLOW
    log_event "info" "No Docker volumes to backup" "false"

    return 0

  fi

  # Create remote path directory
  storage_create_dir "${remote_path}"

  # Loop through volumes
  while IFS= read -r volume; do

    # Log
    display --indent 6 --text "- Creating backup for ${volume}"

    # Create backup file
    ## Runs a temporary Docker container that has access to the volume and the backup directory, and uses tar to create a backup file of the volume.
    "$(docker run --rm -v "${volume}:/volume" -v "${BROLIT_TMP_DIR}:/backup" alpine tar -cjf "/backup/${volume}-${NOW}.tar.bz2" -C /volume ./)"

    # Check if backup file was created
    if [[ -f "${BROLIT_TMP_DIR}/${volume}-${NOW}.tar.bz2" ]]; then

      # Log
      clear_previous_lines "2"
      display --indent 6 --text "- Creating backup for ${volume}" --result "OK" --color GREEN

      # Create remote path directory
      storage_create_dir "${remote_path}/${volume}"

      # Upload backup file to Dropbox
      storage_upload_backup "${BROLIT_TMP_DIR}/${volume}-${NOW}.tar.bz2" "${remote_path}/${volume}" ""

    else

      # Log
      display --indent 6 --text "- Creating backup for ${volume}" --result "FAILED" --color RED
      display --indent 8 --text "Please read the log file" --tcolor YELLOW
      log_event "debug" "Command executed: docker run --rm -v ${volume}:/volume -v ${BROLIT_TMP_DIR}:/backup alpine tar -cjf /backup/${volume}-${NOW}.tar.bz2 -C /volume ./" "false"
      log_event "error" "Docker volume backup failed for ${volume}" "false"

      exitstatus=1
      error_msg="${volume},${error_msg}"
      error_type="docker_volume_backup"

    fi
  
  done <<<"${volumes_to_backup}"

  # Clean ${error_msg}
  error_msg="${error_msg//, /,}"

  # Return
  echo "${error_type};${error_msg}" && return ${exitstatus}

}

################################################################################
# Restore Docker Volume
#
# Arguments:
#   ${1} = ${volume}
#
# Outputs:
#   nothing
################################################################################

function restore_docker_volume() {
  
    local backup_to_restore="${1}"
    local docker_volume="${2}"
  
    # Check if backup file was downloaded
    if [[ -f "${BROLIT_TMP_DIR}/${backup_to_restore}" ]]; then

      # Log
      display --indent 6 --text "- Docker volume restore"
      log_event "debug" "Command executed: docker run --rm -v ${docker_volume}:/volume -v ${BROLIT_TMP_DIR}:/backup alpine tar -xjf /backup/${backup_to_restore} -C /volume" "false"
  
      # Restore backup file
      ## Runs a temporary Docker container that has access to the volume and the backup directory, and uses tar to create a backup file of the volume.
      docker run --rm -v "${docker_volume}:/volume" -v "${BROLIT_TMP_DIR}:/backup" alpine tar -xjf "/backup/${backup_to_restore}" -C /volume
  
      # Log
      clear_previous_lines "2"
      display --indent 6 --text "- Docker volume restore" --result "DONE" --color GREEN
      log_event "info" "Docker volume restore completed for ${docker_volume}" "false"
      
      # Send notification
      send_notification "${SERVER_NAME} " "Docker volume restore completed for ${docker_volume}." "success"
  
      return 0
      
    else
  
      # Log
      log_event "debug" "Command executed: docker run --rm -v ${docker_volume}:/volume -v ${BROLIT_TMP_DIR}:/backup alpine tar -xjf /backup/${backup_to_restore} -C /volume" "false"
      log_event "error" "Docker volume restore failed for ${docker_volume}" "false"
      display --indent 6 --text "- Docker volume restore" --result "FAILED" --color RED
  
      # Send notification
      send_notification "${SERVER_NAME} " "Docker volume restore failed for ${docker_volume}." "alert"
  
      return 1

    fi

}

################################################################################
# Restore Manager Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function restore_manager_menu() {

  local restore_options        # whiptail array options
  local chosen_restore_options # whiptail var

  log_event "info" "Selecting backup restore type ..." "false"

  restore_options=(
    "01)" "FROM DROPBOX"
    "02)" "FROM PUBLIC LINK (BETA)"
    "03)" "FROM LOCAL FILE (BETA)"
    "04)" "FROM FTP (BETA)"
    "05)" "FROM BORG (BETA)"
  )

  chosen_restore_options="$(whiptail --title "RESTORE BACKUP" --menu " " 20 78 10 "${restore_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_restore_options} == *"01"* ]]; then
      restore_backup_from_storage ""

    fi
    if [[ ${chosen_restore_options} == *"02"* ]]; then

      restore_backup_from_public_url

    fi
    if [[ ${chosen_restore_options} == *"03"* ]]; then

      restore_backup_from_local

    fi
    if [[ ${chosen_restore_options} == *"04"* ]]; then

      restore_backup_from_ftp

    fi
    if [[ ${chosen_restore_options} == *"05"* ]]; then
      restore_backup_with_borg 
    fi

  else

    log_event "debug" "Restore type selection skipped" "false"

  fi

  menu_main_options

}

################################################################################
# Backup Sub-Tasks handler
#
# Arguments:
#   ${1} = ${subtask}
#
# Outputs:
#   nothing
################################################################################

function subtasks_backup_handler() {

  local subtask="${1}"

  local backup_project_database_output

  case ${subtask} in

  all)

    backup_all_server_configs
    backup_all_projects_files

    exit
    ;;

  files)

    backup_all_projects_files

    exit
    ;;

  server-config)

    backup_all_server_configs

    exit
    ;;

  databases)

    # TODO: postgres support
    backup_project_database_output="$(backup_project_database "${DBNAME}" "mysql")"

    # TODO: error handling

    exit
    ;;

  project)

    project_type="$(project_get_brolit_config_var "${PROJECTS_PATH}/${DOMAIN}" "project_type")"

    backup_project "${DOMAIN}" "${project_type}"

    exit
    ;;

  *)
    log_event "error" "INVALID SUBTASK: ${subtask}" "true"

    exit
    ;;

  esac

}

################################################################################
# Restore Sub-Tasks handler
#
# Arguments:
#   ${1} = ${subtask}
#
# Outputs:
#   nothing
################################################################################

function subtasks_restore_handler() {

  local subtask="${1}"

  case ${subtask} in

  project)

    log_event "debug" "TODO: restore project backup" "true"
    #make_databases_backup
    #backup_all_server_configs
    #backup_all_projects_files

    exit
    ;;

  files)

    log_event "debug" "TODO: restore files backup" "true"
    #backup_all_projects_files

    exit
    ;;

  server-config)

    log_event "debug" "TODO: restore config backup" "true"
    #backup_all_server_configs

    exit
    ;;

  databases)

    log_event "warning" "TODO: restore database backup" "true"
    #log_event "debug" "Running: backup_all_projects_files"
    #backup_all_projects_files

    exit
    ;;

  *)
    log_event "error" "INVALID SUBTASK: ${subtask}" "true"

    exit
    ;;

  esac

}

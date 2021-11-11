#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.72
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
  )

  chosen_backup_type="$(whiptail --title "SELECT BACKUP TYPE" --menu " " 20 78 10 "${backup_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_backup_type} == *"01"* ]]; then

      # BACKUP_ALL
      log_section "Backup All"

      # Preparing Mail Notifications Template
      mail_server_status_section

      # Databases Backup
      make_all_databases_backup

      # Files Backup
      make_all_files_backup

      # Footer
      mail_footer "${SCRIPT_V}"

      # Preparing Mail Notifications Template
      email_template="default"

      # New full email file
      email_html_file="${TMP_DIR}/full-email-${NOW}.mail"

      # Copy from template
      cp "${SFOLDER}/templates/emails/${email_template}/main-tpl.html" "${email_html_file}"

      # Begin to replace
      sed -i '/{{server_info}}/r '"${TMP_DIR}/server_info-${NOW}.mail" "${email_html_file}"
      sed -i '/{{databases_backup_section}}/r '"${TMP_DIR}/db-bk-${NOW}.mail" "${email_html_file}"
      sed -i '/{{configs_backup_section}}/r '"${TMP_DIR}/config-bk-${NOW}.mail" "${email_html_file}"
      sed -i '/{{files_backup_section}}/r '"${TMP_DIR}/file-bk-${NOW}.mail" "${email_html_file}"
      sed -i '/{{footer}}/r '"${TMP_DIR}/footer-${NOW}.mail" "${email_html_file}"

      # Delete vars not used anymore
      grep -v "{{packages_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{certificates_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{server_info}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{databases_backup_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{configs_backup_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{files_backup_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
      grep -v "{{footer}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"

      # Send html to a var
      mail_html="$(cat "${email_html_file}")"

      # Checking result status for mail subject
      email_status="$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${OUTDATED_PACKAGES}")"

      email_subject="${email_status} [${NOWDISPLAY}] - Complete Backup on ${VPSNAME}"

      # Sending email notification
      mail_send_notification "${email_subject}" "${mail_html}"

      #remove_mail_notifications_files

    fi

    if [[ ${chosen_backup_type} == *"02"* ]]; then

      # DATABASE_BACKUP
      log_section "Databases Backup"

      # Preparing Mail Notifications Template
      mail_server_status_section

      # Databases Backup
      make_all_databases_backup

      DB_MAIL="${TMP_DIR}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      email_subject="${STATUS_ICON_D} [${NOWDISPLAY}] - Database Backup on ${VPSNAME}"
      email_content="${HTMLOPEN} ${BODY_SRV} ${DB_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${email_subject}" "${email_content}"

    fi
    if [[ ${chosen_backup_type} == *"03"* ]]; then

      # FILES_BACKUP

      log_section "Files Backup"

      # Preparing Mail Notifications Template
      mail_server_status_section

      # Files Backup
      make_all_files_backup

      CONFIG_MAIL_VAR=$(cat "${TMP_DIR}/config-bk-${NOW}.mail")

      FILE_MAIL_VAR=$(cat "${TMP_DIR}/file-bk-${NOW}.mail")

      email_subject="${STATUS_ICON_F} [${NOWDISPLAY}] - Files Backup on ${VPSNAME}"
      email_content="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${email_subject}" "${email_content}"

    fi

    if [[ ${chosen_backup_type} == *"04"* ]]; then

      # PROJECT_BACKUP
      log_section "Project Backup"

      # Select project to work with
      directory_browser "Select a project to work with" "${PROJECTS_PATH}" #return $filename

      # Directory_broser returns: $filepath and $filename
      if [[ ${filename} != "" && ${filepath} != "" ]]; then

        DOMAIN="$(basename "${filepath}/${filename}")"

        make_project_backup "${DOMAIN}" "all"

        display --indent 6 --text "- Project backup" --result "DONE" --color GREEN

      else

        display --indent 6 --text "- Project backup" --result "SKIPPED" --color YELLOW

      fi

    fi

  fi

  menu_main_options

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
    "02)" "FROM BACKUP LINK (BETA)"
    "03)" "FROM LOCAL FILE (BETA)"
    "04)" "FROM FTP (BETA)"
  )

  chosen_restore_options="$(whiptail --title "RESTORE BACKUP" --menu " " 20 78 10 "${restore_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_restore_options} == *"01"* ]]; then
      restore_backup_server_selection

    fi
    if [[ ${chosen_restore_options} == *"02"* ]]; then

      # shellcheck source=${SFOLDER}/utils/wordpress_restore_from_source.sh
      source "${SFOLDER}/utils/wordpress_restore_from_source.sh"

      wordpress_restore_from_source

    fi
    if [[ ${chosen_restore_options} == *"03"* ]]; then

      restore_backup_from_local_file

    fi
    if [[ ${chosen_restore_options} == *"04"* ]]; then

      restore_backup_from_ftp

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
#   $1 = ${subtask}
#
# Outputs:
#   nothing
################################################################################

function subtasks_backup_handler() {

  local subtask=$1

  case ${subtask} in

  all)

    make_all_server_config_backup
    make_sites_files_backup

    exit
    ;;

  files)

    make_sites_files_backup

    exit
    ;;

  server-config)

    make_all_server_config_backup

    exit
    ;;

  databases)

    make_database_backup "${DBNAME}"

    exit
    ;;

  project)

    project_type="$(project_get_config "${PROJECTS_PATH}/${DOMAIN}" "project_type")"

    make_project_backup "${DOMAIN}" "${project_type}"

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
#   $1 = ${subtask}
#
# Outputs:
#   nothing
################################################################################

function subtasks_restore_handler() {

  local subtask=$1

  case ${subtask} in

  project)

    log_event "debug" "TODO: restore project backup" "true"
    #make_databases_backup
    #make_all_server_config_backup
    #make_sites_files_backup

    exit
    ;;

  files)

    log_event "debug" "TODO: restore files backup" "true"
    #make_sites_files_backup

    exit
    ;;

  server-config)

    log_event "debug" "TODO: restore config backup" "true"
    #make_all_server_config_backup

    exit
    ;;

  databases)

    log_event "warning" "TODO: restore database backup" "true"
    #log_event "debug" "Running: make_sites_files_backup"
    #make_sites_files_backup

    exit
    ;;

  *)
    log_event "error" "INVALID SUBTASK: ${subtask}" "true"

    exit
    ;;

  esac

}

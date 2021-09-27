#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.56
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
      mail_server_status_html="$(mail_server_status_section "${SERVER_IP}")"

      # Databases Backup
      make_all_databases_backup

      # Files Backup
      make_all_files_backup

      # Mail section for Database Backup
      mail_databases_backup_html=$(<"${TMP_DIR}/db-bk-${NOW}.mail")

      # Mail section for Server Config Backup
      mail_config_backup_html=$(<"${TMP_DIR}/config-bk-${NOW}.mail")

      # Mail section for Files Backup
      mail_file_backup_html=$(<"${TMP_DIR}/file-bk-${NOW}.mail")

      # Footer
      mail_footer_html="$(mail_footer "${SCRIPT_V}")"

      # Preparing Mail Notifications Template
      email_template="default"
      mail_html="$(cat "${SFOLDER}/templates/emails/${email_template}/main-tpl.html")"

      mail_html="$(${mail_html//"{{server_info}}"/${mail_server_status_html}})"
      mail_html="$(${mail_html//"{{configs_backup_section}}"/${mail_config_backup_html}})"
      mail_html="$(${mail_html//"{{databases_backup_section}}"/${mail_databases_backup_html}})"
      mail_html="$(${mail_html//"{{files_backup_section}}"/${mail_file_backup_html}})"
      mail_html="$(${mail_html//"{{footer}}"/${mail_footer_html}})"

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
      #HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # Databases Backup
      make_all_databases_backup

      DB_MAIL="${TMP_DIR}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      log_event "info" "Sending Email to ${MAILA} ..." "false"

      EMAIL_SUBJECT="${STATUS_ICON_D} [${NOWDISPLAY}] - Database Backup on ${VPSNAME}"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${DB_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi
    if [[ ${chosen_backup_type} == *"03"* ]]; then

      # FILES_BACKUP

      log_section "Files Backup"

      # Preparing Mail Notifications Template
      #HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # Files Backup
      make_all_files_backup

      CONFIG_MAIL="${TMP_DIR}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

      FILE_MAIL="${TMP_DIR}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<"${FILE_MAIL}")

      log_event "info" "Sending Email to ${MAILA} ..." "false"

      EMAIL_SUBJECT="${STATUS_ICON_F} [${NOWDISPLAY}] - Files Backup on ${VPSNAME}"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi

    if [[ ${chosen_backup_type} == *"04"* ]]; then

      # PROJECT_BACKUP
      log_section "Project Backup"

      # Select project to work with
      directory_browser "Select a project to work with" "${SITES}" #return $filename

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

    project_type="$(project_get_config "${SITES}/${DOMAIN}" "project_type")"

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

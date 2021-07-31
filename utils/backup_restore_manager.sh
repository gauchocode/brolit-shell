#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.52
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
    "01)" "BACKUP DATABASES"
    "02)" "BACKUP FILES"
    "03)" "BACKUP ALL"
    "04)" "BACKUP PROJECT"
  )

  chosen_backup_type="$(whiptail --title "SELECT BACKUP TYPE" --menu " " 20 78 10 "${backup_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_backup_type} == *"01"* ]]; then

      # DATABASE_BACKUP
      log_section "Databases Backup"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
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
    if [[ ${chosen_backup_type} == *"02"* ]]; then

      # FILES_BACKUP

      log_section "Files Backup"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
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
    if [[ ${chosen_backup_type} == *"03"* ]]; then

      # BACKUP_ALL
      log_section "Backup All"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # Databases Backup
      make_all_databases_backup

      # Files Backup
      make_all_files_backup

      # Mail section for Database Backup
      DB_MAIL="${TMP_DIR}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      # Mail section for Server Config Backup
      CONFIG_MAIL="${TMP_DIR}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

      # Mail section for Files Backup
      FILE_MAIL="${TMP_DIR}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<"${FILE_MAIL}")

      MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

      # Checking result status for mail subject
      EMAIL_STATUS="$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${OUTDATED_PACKAGES}")"

      log_event "info" "Sending Email to ${MAILA} ..."

      EMAIL_SUBJECT="${EMAIL_STATUS} [${NOWDISPLAY}] - Complete Backup on ${VPSNAME}"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${BODY_PKG} ${DB_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

      remove_mail_notifications_files

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
    "01)" "RESTORE FROM DROPBOX"
    "02)" "RESTORE FROM URL (BETA)"
    "03)" "RESTORE FROM FILE (BETA)"
  )

  chosen_restore_options="$(whiptail --title "RESTORE TYPE" --menu " " 20 78 10 "${restore_options[@]}" 3>&1 1>&2 2>&3)"
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
      restore_backup_from_file

    fi

  else

    log_event "debug" "Restore type selection skipped"

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

    make_database_backup "databases" "${DBNAME}"

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
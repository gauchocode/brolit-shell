#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Script Name: LEMP Utils Script
# Version: 3.0.2
################################################################################
#
# Style Guide and refs: https://google.github.io/styleguide/shell.xml
#
################################################################################

### Init #######################################################################

### Main dir check
SFOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
if [ -z "${SFOLDER}" ]; then
  exit 1  # error; the path is not accessible
fi

# Main library
chmod +x "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

# Script Initialization
script_init

if [ -t 1 ]; then

  ### Running from terminal

  check_root #moved here, because if runned by cron, sometimes fails

  if [[ -z "${MPASS}" || -z "${SITES}"|| 
        -z "${SMTP_U}" || -z "${SMTP_P}" || -z "${SMTP_TLS}" || -z "${SMTP_PORT}" || -z "${SMTP_SERVER}" || -z "${SMTP_P}" || -z "${MAILA}" ||
        -z "${DUP_BK}" || -z "${DUP_ROOT}" || -z "${DUP_SRC_BK}"|| -z "${DUP_FOLDERS}"|| -z "${DUP_BK_FULL_FREQ}"|| -z "${DUP_BK_FULL_LIFE}"|| 
        -z "${MAILCOW_BK}" ]]; then

    FIRST_RUN_OPTIONS="01 LEMP_SETUP 02 CONFIGURE_SCRIPT"
    CHOSEN_FR_OPTION=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 $(for x in ${FIRST_RUN_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      if [[ ${CHOSEN_FR_OPTION} == *"01"* ]]; then
        # shellcheck source=${SFOLDER}/utils/lemp_setup.sh
        source "${SFOLDER}/utils/lemp_setup.sh"

      else
        script_configuration_wizard "initial"
        main_menu

      fi

    fi

  else

    main_menu

  fi

else
  # Running from cron
  if [[ -z "${MPASS}" || -z "${SMTP_U}" || -z "${SMTP_P}" || -z "${SMTP_TLS}" || -z "${SMTP_PORT}" || -z "${SMTP_SERVER}" || -z "${SMTP_P}" || -z "${MAILA}" || -z "${SITES}" ]]; then
    log_event "critical" "Some required options need to be configured, please run de script manually to configure them." "false"
    return 1

  else

    # Running scripts
     "${SFOLDER}/cron/backups_tasks.sh"

  fi

fi

# Log End
log_event "info" "LEMP UTILS SCRIPT End -- $(date +%Y%m%d_%H%M)" "true"
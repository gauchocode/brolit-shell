#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Script Name: LEMP Utils Script
# Version: 3.0.6
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

if [ -t 1 ]; then

  ### Running from terminal

  # Script Initialization
  script_init

  check_root

  if [[ -z "${MPASS}" || -z "${SITES}"|| 
        -z "${SMTP_U}" || -z "${SMTP_P}" || -z "${SMTP_TLS}" || -z "${SMTP_PORT}" || -z "${SMTP_SERVER}" || -z "${SMTP_P}" || -z "${MAILA}" ||
        -z "${DUP_BK}" || -z "${DUP_ROOT}" || -z "${DUP_SRC_BK}"|| -z "${DUP_FOLDERS}"|| -z "${DUP_BK_FULL_FREQ}"|| -z "${DUP_BK_FULL_LIFE}"|| 
        -z "${MAILCOW_BK}" ]]; then

    first_run_options=("01)" "LEMP SETUP" "02)" "CONFIGURE SCRIPT")
    chosen_first_run_options=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 "${first_run_options[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_first_run_options} == *"01"* ]]; then
        # shellcheck source=${SFOLDER}/utils/lemp_setup.sh
        source "${SFOLDER}/utils/lemp_setup.sh"

      else
        script_configuration_wizard "initial"
        menu_main_options

      fi

    fi

  else

    # Check if there were no arguments provided 
    if [ $# -eq 0 ]; then
        menu_main_options

    else

      TASK=""; SITE=""; SHOWDEBUG=0;
    
      while [ $# -ge 1 ]; do

          case $1 in

              -h|-\?|--help)
                show_help    # Display a usage synopsis
                exit
                ;;

              -d|--debug)
                  SHOWDEBUG=1
              ;;

              -t|--task)
                  shift
                  TASK=$1
              ;;

              -s|--site)
                  shift
                  SITE=$1
              ;;

              *)
                  echo "INVALID OPTION (Display): $1" >&2
                  #ExitFatal
              ;;
          
          esac

          shift

      done

        case $TASK in

          project-backup)
            echo "TODO: run project-backup for $SITE"
            exit
            ;;

          project-restore)
            echo "TODO: run project-restore for $SITE"
            exit
          ;;

          project-install)
            echo "TODO: run project-install for $SITE"
            exit
          ;;

          cloudflare-api)
            echo "TODO: run cloudflare-api for $SITE"
            exit
          ;;

          *)
            echo "INVALID TASK: $TASK" >&2
            #ExitFatal
          ;;
      
      esac

    fi

  fi

  # Log End
  log_event "info" "LEMP UTILS SCRIPT End -- $(date +%Y%m%d_%H%M)"

else

  ### Running from cron
  log_event "error" "Nothing to do ..."
  return 1

fi
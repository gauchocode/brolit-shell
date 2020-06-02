#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
################################################################################

################################################################################
# GLOBALS
################################################################################

### Setup Foreground Colours
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
ORANGE='\033[0;33m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'
ENDCOLOR='\033[0m'

### Setup Background Colours
B_BLACK='\E[40m'
B_RED='\E[41m'
B_GREEN='\E[42m'
B_YELLOW='\E[43m'
B_ORANGE='\043[0m'
B_BLUE='\E[44m'
B_MAGENTA='\E[45m'
B_CYAN='\E[46m'
B_WHITE='\E[47m'
B_ENDCOLOR='\e[0m'

startdir=""
menutitle="Config Selection Menu"

################################################################################
# MAIN MENU
################################################################################

main_menu() {

  RUNNER_OPTIONS="01 MAKE_A_BACKUP 02 RESTORE_A_BACKUP 03 DELETE_PROJECT 04 WORDPRESS_INSTALLER 05 WPCLI_MANAGER 06 CERTBOT_MANAGER 07 IT_UTILS 08 SCRIPT_OPTIONS"
  CHOSEN_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 $(for x in ${RUNNER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_TYPE} == *"01"* ]]; then
      backup_menu

    fi
    if [[ ${CHOSEN_TYPE} == *"02"* ]]; then
      restore_menu

    fi

    if [[ ${CHOSEN_TYPE} == *"03"* ]]; then
      source "${SFOLDER}/delete_project.sh"

    fi

    if [[ ${CHOSEN_TYPE} == *"04"* ]]; then
      source "${SFOLDER}/utils/installers/wordpress_installer.sh"

    fi

    if [[ ${CHOSEN_TYPE} == *"05"* ]]; then
      source "${SFOLDER}/utils/wpcli_manager.sh"

    fi
    if [[ ${CHOSEN_TYPE} == *"06"* ]]; then
      source "${SFOLDER}/utils/certbot_manager.sh"

    fi
    if [[ ${CHOSEN_TYPE} == *"07"* ]]; then
      #source "${SFOLDER}/utils/it_utils.sh"
      it_utils_menu

    fi

    if [[ ${CHOSEN_TYPE} == *"08"* ]]; then
      script_configuration_wizard "reconfigure"

    fi

  else
    exit 1

  fi
}

backup_menu() {

  BACKUP_OPTIONS="01 DATABASE_BACKUP 02 FILES_BACKUP 03 BACKUP_ALL 04 PROJECT_BACKUP"
  CHOSEN_BACKUP_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a Backup Type to run" 20 78 10 $(for x in ${BACKUP_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  # Preparing Mail Notifications Template
  HTMLOPEN=$(mail_html_start)

  MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_BACKUP_TYPE} == *"01"* ]]; then

      source "${SFOLDER}/mysql_backup.sh"

      DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<${DB_MAIL})

      echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

      EMAIL_SUBJECT="${STATUS_ICON_D} ${VPSNAME} - Database Backup - [${NOWDISPLAY}]"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${DB_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi
    if [[ ${CHOSEN_BACKUP_TYPE} == *"02"* ]]; then

      source "${SFOLDER}/files_backup.sh"

      CONFIG_MAIL="${BAKWP}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<$CONFIG_MAIL)

      FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<$FILE_MAIL)

      echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

      EMAIL_SUBJECT="${STATUS_ICON_F} ${VPSNAME} - Files Backup - [${NOWDISPLAY}]"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi
    if [[ ${CHOSEN_BACKUP_TYPE} == *"03"* ]]; then

      # Running scripts
      "${SFOLDER}/mysql_backup.sh"
      "${SFOLDER}/files_backup.sh"

      DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<${DB_MAIL})

      CONFIG_MAIL="${BAKWP}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<$CONFIG_MAIL)

      FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<${FILE_MAIL})

      MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

      # Checking result status for mail subject
      EMAIL_STATUS=$(mail_subject_status "${STATUS_D}" "${STATUS_F}" "${OUTDATED}")

      echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

      EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Running Complete Backup - [${NOWDISPLAY}]"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${BODY_PKG} ${DB_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi

    if [[ ${CHOSEN_BACKUP_TYPE} == *"04"* ]]; then

      # Running project_backup script
      "${SFOLDER}/project_backup.sh"

    fi

  fi

}

restore_menu () {

  RESTORE_OPTIONS="01 RESTORE_FROM_DROPBOX 02 RESTORE_FROM_SOURCE"
  CHOSEN_RESTORE_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a Restore Option to run" 20 78 10 $(for x in ${RESTORE_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_RESTORE_TYPE} == *"01"* ]]; then
      source "${SFOLDER}/restore_from_backup.sh"
    fi

    if [[ ${CHOSEN_RESTORE_TYPE} == *"02"* ]]; then
      source "${SFOLDER}/utils/wordpress_restore_from_source.sh"
    fi

  fi

}

it_utils_menu() {

  IT_UTIL_OPTIONS="01 INSTALLERS_AND_CONFIGS 02 SERVER_OPTIMIZATIONS 03 BLACKLIST_CHECKER 04 BENCHMARK_SERVER"
  CHOSEN_IT_UTIL_TYPE=$(whiptail --title "IT UTILS MENU" --menu "Choose a script to Run" 20 78 10 $(for x in ${IT_UTIL_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_IT_UTIL_TYPE} == *"01"* ]]; then
      source "${SFOLDER}/installers_and_configurators.sh"

    fi

    if [[ ${CHOSEN_IT_UTIL_TYPE} == *"02"* ]]; then
      while true; do
        echo -e ${YELLOW}"> Do you really want to run the optimization script?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
        [Yy]*)
          source "${SFOLDER}/server_and_image_optimizations.sh"
          break
          ;;
        [Nn]*)
          echo -e ${RED}"Aborting optimization script ..."${ENDCOLOR}
          break
          ;;
        *) echo " > Please answer yes or no." ;;
        esac
      done

    fi

    if [[ ${CHOSEN_IT_UTIL_TYPE} == *"03"* ]]; then

      URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        source "${SFOLDER}/utils/third-party/google-insights-api-tools/gitools_v5.sh" gtmetrix "${URL_TO_TEST}"
      fi

    fi
    if [[ ${CHOSEN_IT_UTIL_TYPE} == *"04"* ]]; then
    
      IP_TO_TEST=$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        source "${SFOLDER}/utils/third-party/blacklist-checker/bl.sh" "${IP_TO_TEST}"
      fi

    fi

  else
    exit 1

  fi
}

script_configuration_wizard() {

  #$1 = options: initial or reconfigure

  CONFIG_MODE=$1

  if [[ ${CONFIG_MODE} == "reconfigure" ]]; then
    #Old Vars
    SMTP_SERVER_OLD=${SMTP_SERVER}
    SMTP_PORT_OLD=${SMTP_PORT}
    SMTP_TLS_OLD=${SMTP_TLS}
    SMTP_U_OLD=${SMTP_U}
    SMTP_P_OLD=${SMTP_P}
    MAILA=_OLD=${MAILA}
    SITES=_OLD=${SITES}

    #Reset Config Vars
    SMTP_SERVER=""
    SMTP_PORT=""
    SMTP_TLS=""
    SMTP_U=""
    SMTP_P=""
    MAILA=""
    SITES=""

    #Delet old Config File
    rm /root/.broobe-utils-options
    echo -e ${YELLOW}" > Script config file deleted: /root/.broobe-utils-options"${B_ENDCOLOR}

  fi

  ask_mysql_root_psw

  if [[ -z "${SMTP_SERVER}" ]]; then
    SMTP_SERVER=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server" 10 60 "${SMTP_SERVER_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_SERVER="${SMTP_SERVER} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_PORT}" ]]; then
    SMTP_PORT=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server Port" 10 60 "${SMTP_PORT_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_PORT="${SMTP_PORT} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_TLS}" ]]; then
    SMTP_TLS=$(whiptail --title "SMTP TLS" --inputbox "SMTP yes or no:" 10 60 "${SMTP_TLS_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_TLS="${SMTP_TLS} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_U}" ]]; then
    SMTP_U=$(whiptail --title "SMTP User" --inputbox "Please insert the SMTP user" 10 60 "${SMTP_U_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_U="${SMTP_U} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_P}" ]]; then
    SMTP_P=$(whiptail --title "SMTP Password" --inputbox "Please insert the SMTP user password" 10 60 "${SMTP_P_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_P="${SMTP_P} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${MAILA}" ]]; then
    MAILA=$(whiptail --title "Notification Email" --inputbox "Insert the email where you want to receive notifications." 10 60 "${MAILA_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "MAILA="${MAILA} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SITES}" ]]; then
    SITES=$(whiptail --title "Websites Root Directory" --inputbox "Insert the path where websites are stored. Ex: /var/www or /usr/share/nginx" 10 60 "${SITES_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SITES="${SITES} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${MAILCOW_BK}" ]]; then
    MAILCOW_BK_DEFAULT=false
    MAILCOW_BK=$(whiptail --title "Mailcow Backup Support?" --inputbox "Please insert true or false" 10 60 "${MAILCOW_BK_DEFAULT}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "MAILCOW_BK="${MAILCOW_BK} >>/root/.broobe-utils-options
      
      if [[ -z "${MAILCOW}" && "${MAILCOW_BK}" = true ]]; then

        # MailCow Dockerized default files location
        MAILCOW_DEFAULT="/opt/mailcow-dockerized"
        MAILCOW=$(whiptail --title "Mailcow Installation Path" --inputbox "Insert the path where Mailcow is installed" 10 60 "${MAILCOW_DEFAULT}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then
          echo "MAILCOW="${MAILCOW} >>/root/.broobe-utils-options
        else
          exit 1
        fi
      fi

    else
      exit 1
    fi
  fi

}

################################################################################
# LOGGERS
################################################################################

function __msg_error() {
    [[ "${ERROR}" == "1" ]] && echo -e "[ERROR]: $*"
}

function __msg_debug() {
    [[ "${DEBUG}" == "1" ]] && echo -e "[DEBUG]: $*"
}

function __msg_info() {
    [[ "${INFO}" == "1" ]] && echo -e "[INFO]: $*"
}

################################################################################
# CHECKERS
################################################################################

check_root() {
  # Check if user is root
  if [ ${USER} != root ]; then
    echo -e ${RED}" > Error: must be root! Exiting..."${ENDCOLOR}
    exit 0
  fi

}

check_distro() {

  #for ext check
  distro_old="false"

  # Running Ubuntu?
  DISTRO=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')
  if [ ! "$DISTRO" = "Ubuntu" ]; then
    echo " > ERROR: This script only run on Ubuntu ... Exiting"
    exit 1
  else
    MIN_V=$(echo "18.04" | awk -F "." '{print $1$2}')
    DISTRO_V=$(get_ubuntu_version)
    echo "ACTUAL DISTRO: ${DISTRO} ${DISTRO_V}"
    if [ ! "$DISTRO_V" -ge "$MIN_V" ]; then
      whiptail --title "UBUNTU VERSION WARNING" --msgbox "Ubuntu version must be 18.04 or 20.04! Use this script only for backup or restore purpose." 8 78
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        #echo " > Setting distro_old=true" >>$LOG
        distro_old="true"
      else
        exit 0
      fi
      
    fi
  fi
}

checking_scripts_permissions() {
  ### chmod
  find ./ -name "*.sh" -exec chmod +x {} \;

}

################################################################################
# HELPERS
################################################################################

log_event() {
    if [ -z "$time" ]; then
        LOG_TIME="$(date +'%F %T') $(basename $0)"
    else
        LOG_TIME="$date $time $(basename $0)"
    fi
    if [ "$1" -eq 0 ]; then
        echo "$LOG_TIME $2" >> $VESTA/log/system.log
    else
        echo "$LOG_TIME $2 [Error $1]" >> $VESTA/log/error.log
    fi
}

check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        if [ ! -z "$3" ]; then
            log_event "$3" "$ARGUMENTS"
            exit $3
        else
            log_event "$1" "$ARGUMENTS"
            exit $1
        fi
    fi
}

get_ubuntu_version() {

  lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $2}' | awk -F "." '{print $1$2}'

}

declare -a checklist_array

array_to_checklist() {
  i=0
  for option in $1; do
    checklist_array[$i]=$option
    i=$((i + 1))
    checklist_array[$i]=" "
    i=$((i + 1))
    checklist_array[$i]=off
    i=$((i + 1))
  done
}

file_browser() {
  # first parameter is Menu Title
  # second parameter is dir path to starting folder
  if [ -z $2 ]; then
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "$2"
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "$curdir" == "/" ]; then # Check if you are at root folder
    selection=$(whiptail --title "$1" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select $dir_list 3>&1 1>&2 2>&3)
  else # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "$1" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select ../ BACK $dir_list 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then # Check if User Selected Cancel
    return 1
  elif [ $RET -eq 0 ]; then
    if [[ -f "$selection" ]]; then # Check if File Selected
      if (whiptail --title "Confirm Selection" --yesno "Selection : $selection\n" 0 0 \
        --yes-button "Confirm" \
        --no-button "Retry"); then
        filename="$selection"
        filepath="$curdir" # Return full filepath and filename as selection variables
      fi
    fi
  fi
}

directory_browser() {
  # first parameter is Menu Title
  # second parameter is dir path to starting folder

  if [ -z $2 ]; then
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "$2"
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "$curdir" == "/" ]; then # Check if you are at root folder
    selection=$(whiptail --title "$1" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select $dir_list 3>&1 1>&2 2>&3)
  else # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "$1" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select ../ BACK $dir_list 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then # Check if User Selected Cancel
    return 1
  elif [ $RET -eq 0 ]; then
    if [[ -d "$selection" ]]; then # Check if Directory Selected
      if (whiptail --title "Confirm Selection" --yesno "Selection : $selection\n" 0 0 \
        --yes-button "Confirm" \
        --no-button "Retry"); then
        filename="$selection"
        filepath="$curdir" # Return full filepath and filename as selection variables

      fi
    fi
  fi
}

get_all_directories() {

  # $1 = ${SITES}

  MAIN_DIRECTORY=$1

  FIRST_LEVEL_DIRECTORIES=$(find ${MAIN_DIRECTORY} -maxdepth 1 -type d)

  echo "${FIRST_LEVEL_DIRECTORIES}"

}

copy_project_files() {

  # $1 = ${SOURCE_PATH}
  # $2 = ${DESTINATION_PATH}
  # $3 = ${EXCLUDED_PATH} - Neet to be a relative path

  local source_path=$1
  local destination_path=$2
  local excluded_path=$3

  #cp -r "${source_path}" "${destination_path}"

  if [ "${excluded_path}" != "" ];then
    rsync -ax --exclude "${excluded_path}" "${source_path}" "${destination_path}"

  else
    rsync -ax "${source_path}" "${destination_path}"

  fi

}

generate_dropbox_config() {

  OAUTH_ACCESS_TOKEN_STRING+= "\n . \n"
  OAUTH_ACCESS_TOKEN_STRING+=" 1) Log in: dropbox.com/developers/apps/create\n"
  OAUTH_ACCESS_TOKEN_STRING+=" 2) Click on \"Create App\" and select \"Dropbox API\".\n"
  OAUTH_ACCESS_TOKEN_STRING+=" 3) Choose the type of access you need.\n"
  OAUTH_ACCESS_TOKEN_STRING+=" 4) Enter the \"App Name\".\n"
  OAUTH_ACCESS_TOKEN_STRING+=" 5) Click on the \"Create App\" button.\n"
  OAUTH_ACCESS_TOKEN_STRING+=" 6) Click on the Generate button.\n"
  OAUTH_ACCESS_TOKEN_STRING+=" 7) Copy and paste the new access token here:\n\n"

  OAUTH_ACCESS_TOKEN=$(whiptail --title "Dropbox Uploader Configuration" --inputbox "${OAUTH_ACCESS_TOKEN_STRING}" 15 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" >${DPU_CONFIG_FILE}
    echo -e ${GREEN}" > The configuration has been saved! ..."${ENDCOLOR}

  else
    exit 1

  fi

}

generate_cloudflare_config() {

  CFL_EMAIL_STRING="Please insert the cloudflare email account here:\n\n"

  CFL_EMAIL=$(whiptail --title "Cloudflare Configuration" --inputbox "${CFL_EMAIL_STRING}" 15 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    echo "dns_cloudflare_email=$CFL_EMAIL">"${CLF_CONFIG_FILE}"

    GLOBAL_API_TOKEN_STRING+= "\n . \n"
    GLOBAL_API_TOKEN_STRING+=" 1) Log in on: cloudflare.com\n"
    GLOBAL_API_TOKEN_STRING+=" 2) Login and go to 'My Profile'.\n"
    GLOBAL_API_TOKEN_STRING+=" 3) Choose the type of access you need.\n"
    GLOBAL_API_TOKEN_STRING+=" 4) Click on 'API TOKENS' \n"
    GLOBAL_API_TOKEN_STRING+=" 5) In 'Global API Key' click on \"View\" button.\n"
    GLOBAL_API_TOKEN_STRING+=" 6) Copy the code and paste it here:\n\n"

    GLOBAL_API_TOKEN=$(whiptail --title "Cloudflare Configuration" --inputbox "${GLOBAL_API_TOKEN_STRING}" 15 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "dns_cloudflare_api_key=$GLOBAL_API_TOKEN">>"${CLF_CONFIG_FILE}"
      echo -e ${B_GREEN}" > The cloudflare configuration has been saved! ..."${ENDCOLOR}

    else
      exit 1

    fi

  else
    exit 1

  fi

}

calculate_disk_usage() {

  DISK_U=$(df -h | grep "${MAIN_VOL}" | awk {'print $5'})
  echo " > Disk usage: ${DISK_U} ..." >>"${LOG}"

}

check_if_folder_exists() {

  # $1 = ${FOLDER_TO_INSTALL}
  # $2 = ${DOMAIN}

  local FOLDER_TO_INSTALL=$1
  local DOMAIN=$2

  local PROJECT_DIR="${FOLDER_TO_INSTALL}/${DOMAIN}"
  
  if [ -d "${PROJECT_DIR}" ]; then
    echo "ERROR"

  else
    echo "${PROJECT_DIR}"

  fi
}

change_ownership(){

  #$1 = ${user}
  #$2 = ${group}
  #$3 = ${path}

  local user=$1
  local group=$2
  local path=$3

  echo " > Changing ownership ..." >>$LOG
  echo -e ${CYAN}" > Changing ownership ..."${ENDCOLOR}
  chown -R "${user}":"${group}" "${path}"

}

prompt_return_or_finish() {

  while true; do
    echo -e ${YELLOW}"> Do you want to return to menu?"${ENDCOLOR}
    read -p "Please type 'y' or 'n'" yn
    case $yn in
      [Yy]*)
        echo -e ${CYAN}"Returning to menu ..."${ENDCOLOR}
        break
        ;;
      [Nn]*)
        echo -e ${B_RED}"Exiting script ..."${ENDCOLOR}
        exit 0
        ;;
      *) echo "Please answer yes or no." ;;
    esac
  done

}

extract () {
  
  # $1 - File to uncompress or extract
  # $2 - Dir to uncompress file
  # $3 - Optional compress-program (ex: lbzip2)

  local file=$1
  local directory=$2
  local compress_type=$3

    if [ -f "${file}" ]; then
        case "${file}" in
            *.tar.bz2)  
              if [ -z "${compress_type}" ]; then
                 tar xp "${file}" -C "${directory}" --use-compress-program="${compress_type}"
              else
                 tar xjf "${file}" -C "${directory}"
              fi;;
            *.tar.gz)     tar -xzvf "${file}" -C "${directory}";;
            *.bz2)        bunzip2 "${file}";;
            *.rar)        unrar x "${file}";;
            *.gz)         gunzip "${file}";;
            *.tar)        tar xf "${file}" -C "${directory}";;  
            *.tbz2)       tar xjf "${file}" -C "${directory}";;
            *.tgz)        tar xzf "${file}" -C "${directory}";;
            *.zip)        unzip "${file}";;
            *.Z)          uncompress "${file}";;
            *.7z)         7z x "${file}";;
            *.tar.gz)     tar J "${file}" -C "${directory}";;
            *.xz)         tar xvf "${file}" -C "${directory}";;
            *)            echo "${file} cannot be extracted via extract()" ;;
        esac
    else
        echo "${file} is not a valid file"
    fi
}

cron_this () {

  #1 - croncmd ("/home/me/myfunction myargs > /home/me/myfunction.log 2>&1")
  #2 - crontime ("0 */15 * * *")

  croncmd=$1
  crontime=$2

  local cronjob="$crontime $croncmd"
  
  #Add it to the crontab, with no duplication
  ( crontab -l | grep -v -F "$croncmd" ; echo "$cronjob" ) | crontab -

}

cron_remove () {

  #1 - croncmd ("/home/me/myfunction myargs > /home/me/myfunction.log 2>&1")

  croncmd=$1
  
  #Remove it from the crontab whatever its current schedule
  ( crontab -l | grep -v -F "$croncmd" ) | crontab -

}

################################################################################
# VALIDATORS
################################################################################

is_domain_format_valid() {

  # $1 = domain

  local domain=$1

  object_name=${2-domain}
  exclude="[!|@|#|$|^|&|*|(|)|+|=|{|}|:|,|<|>|?|_|/|\|\"|'|;|%|\`| ]"
  if [[ ${domain} =~ $exclude ]] || [[ ${domain} =~ ^[0-9]+$ ]] || [[ ${domain} =~ "\.\." ]] || [[ ${domain} =~ "$(printf '\t')" ]]; then
    check_result $E_INVALID "invalid $object_name format :: ${domain}"
  fi
}

is_ip_format_valid() {

  # $1 = ip

  local ip=$1

  object_name=${2-ip}
  ip_regex='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
  ip_clean=$(echo "${ip%/*}")
  if ! [[ $ip_clean =~ ^$ip_regex\.$ip_regex\.$ip_regex\.$ip_regex$ ]]; then
    check_result $E_INVALID "invalid $object_name format :: ${ip}"
  fi
  if [ "${ip}" != "$ip_clean" ]; then
    ip_cidr="$ip_clean/"
    ip_cidr=$(echo "${1#$ip_cidr}")
    if [[ "$ip_cidr" -gt 32 ]] || [[ "$ip_cidr" =~ [:alnum:] ]]; then
      check_result $E_INVALID "invalid $object_name format :: ${ip}"
    fi
  fi
}

is_email_format_valid() {

  # $1 = email

  local email=$1

  if [[ ! "${email}" =~ ^[A-Za-z0-9._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,63}$ ]]; then
    check_result $E_INVALID "invalid email format :: ${email}"
  fi
}

################################################################################
# ASK-FOR
################################################################################

ask_project_state() {

  #$1 = ${state} optional to select default option

  local state=$1

  project_states="prod stage beta test dev"
  project_state=$(whiptail --title "Project State" --menu "Choose a Project State" 20 78 10 $(for x in ${project_states}; do echo "$x [X]"; done) --default-item "${state}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${project_state}"

  else
    return 1
  fi
}

ask_project_name() {

  #$1 = ${project_name} optional to select default option

  local name=$1

  # Replace '-' and '.' chars
  name=$(echo "${name}" | sed -r 's/[.-]+/_/g')

  project_name=$(whiptail --title "Project Name" --inputbox "Insert a project name (only separator allow is '_'). Ex: my_domain" 10 60 "${name}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${project_name}"

  else
    exit 1

  fi

}

ask_project_domain() {

  #$1 = ${project_domain} optional to select default option

  local project_domain=$1
  
  project_domain=$(whiptail --title "Domain" --inputbox "Insert the project's domain. Example: landing.domain.com" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${project_domain}"

  else
    exit 1

  fi

}

ask_rootdomain_to_cloudflare_config() {

  # $1 = ${root_domain} (could be empty)

  local root_domain=$1

  if [[ -z "${root_domain}" ]]; then
    root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
  else
    root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 "${root_domain}" 3>&1 1>&2 2>&3)
  fi
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${root_domain}"

  else
    exit 1

  fi

}

ask_subdomains_to_cloudflare_config() {

  # $1 = ${DOMAIN} optional to select default option (could be empty)

  local DOMAIN=$1;

  ROOT_DOMAIN=$(whiptail --title "Cloudflare Subdomains" --inputbox "Insert the subdomains you want to update in Cloudflare (comma separated). Example: www.broobe.com,broobe.com" 10 60 "${DOMAIN}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "Setting ROOT_DOMAIN=${ROOT_DOMAIN}" >>$LOG
    return 0

  else
    exit 1

  fi

}

ask_folder_to_install_sites() {

  # $1 = ${FOLDER_TO_INSTALL} optional to select default option (could be empty)

  local FOLDER_TO_INSTALL=$1

  if [[ -z "${FOLDER_TO_INSTALL}" ]]; then
    FOLDER_TO_INSTALL=$(whiptail --title "Folder to install" --inputbox "Please insert the full path where you want to install the site:" 10 60 "${FOLDER_TO_INSTALL}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "FOLDER_TO_INSTALL=${FOLDER_TO_INSTALL}" >>$LOG
      echo "${FOLDER_TO_INSTALL}"
    else
      exit 1
    fi
  else
    echo "FOLDER_TO_INSTALL=${FOLDER_TO_INSTALL}" >>$LOG
    echo "${FOLDER_TO_INSTALL}"
  fi

}

ask_mysql_root_psw() {

  if [[ -z "${MPASS}" ]]; then
    MPASS=$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root Password" 10 60 "${MPASS}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      #echo "> Running: mysql -u root -p${MPASS} -e"
      until mysql -u root -p${MPASS}S -e ";"; do
        read -s -p "Can't connect to MySQL, please re-enter $MUSER password: " MPASS
      
      done
      echo "MPASS="${MPASS} >>/root/.broobe-utils-options

    else
      exit 1

    fi
  fi

}

ask_url_search_and_replace() {

  # $1 = WP_PATH

  WP_PATH=$1

  if [[ -z "${existing_URL}" ]]; then
    existing_URL=$(whiptail --title "URL TO CHANGE" --inputbox "Insert the URL you want to change, including http:// or https://" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?

    echo "Setting existing_URL=${existing_URL}" >>$LOG

    if [ ${exitstatus} = 0 ]; then

      if [[ -z "${new_URL}" ]]; then
        new_URL=$(whiptail --title "THE NEW URL" --inputbox "Insert the new URL , including http:// or https://" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ ${exitstatus} = 0 ]; then

          echo "Setting new_URL=${new_URL}" >>$LOG

          wpcli_search_and_replace "${WP_PATH}" "${existing_URL}" "${new_URL}"

        fi

      fi

    fi

  fi

}

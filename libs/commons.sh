#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################

### GLOBALS

# Foreground Colours
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

# Background Colours
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

script_init() {

  ### Vars

  # Hostname
  VPSNAME="$HOSTNAME"

  # Time Vars
  NOW=$(date +"%Y-%m-%d")
  NOWDISPLAY=$(date +"%d-%m-%Y")
  ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

  # Folder blacklist
  SITES_BL=".wp-cli,phpmyadmin,html"

  # Database blacklist
  DB_BL="information_schema,performance_schema,mysql,sys,phpmyadmin"

  #MAILCOW BACKUP
  MAILCOW_TMP_BK="${SFOLDER}/tmp/mailcow"

  PHP_V=$(php -r "echo PHP_VERSION;" | grep --only-matching --perl-regexp "7.\d+")

  # NGINX config files location
  WSERVER="/etc/nginx"

  # MySQL config files location
  MySQL_CF="/etc/mysql"

  # PHP config files location
  PHP_CF="/etc/php"

  # Let's Encrypt config files location
  LENCRYPT_CF="/etc/letsencrypt"

  # Packages to watch
  PACKAGES=(linux-firmware dpkg perl nginx "php${PHP_V}-fpm" mysql-server curl openssl)

  MAIN_VOL=$(df /boot | grep -Eo '/dev/[^ ]+') # Main partition

  # Dropbox Folder Backup
  DROPBOX_FOLDER="/"

  # Dropbox Uploader Directory
  DPU_F="${SFOLDER}/utils/third-party/dropbox-uploader"

  # Temp folders
  BAKWP="${SFOLDER}/tmp"

  ### Creating temporary folders
  if [ ! -d "${BAKWP}" ]; then
    echo " > Folder ${BAKWP} doesn't exist. Creating now ..."
    mkdir "${BAKWP}"
  fi
  if [ ! -d "${BAKWP}/${NOW}" ]; then
    echo " > Folder ${BAKWP}/${NOW} doesn't exist. Creating now ..."
    mkdir "${BAKWP}/${NOW}"
  fi

  # MySQL host and user
  MHOST="localhost"
  MUSER="root"

  ### Log
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  PATH_LOG="${SFOLDER}/log"
  if [ ! -d "${SFOLDER}/log" ]; then
    echo " > Folder ${SFOLDER}/log doesn't exist. Creating now ..."
    mkdir "${SFOLDER}/log"
    echo " > Folder ${SFOLDER}/log created ..."
  fi

  LOG_NAME="log_lemp_utils_${TIMESTAMP}.log"
  LOG="${PATH_LOG}/${LOG_NAME}"

  find "${PATH_LOG}" -name "*.log" -type f -mtime +7 -print -delete >>"${LOG}"

  # Log Start
  log_event "info" "LEMP UTILS SCRIPT Start -- $(date +%Y%m%d_%H%M)" "true"

  ### Welcome #######################################################################

  log_event "" "                                                 " "true"
  log_event "" "██████╗ ██████╗  ██████╗  ██████╗ ██████╗ ███████" "true"
  log_event "" "██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗██╔══██╗██╔══  " "true"
  log_event "" "██████╔╝██████╔╝██║   ██║██║   ██║██████╔╝█████  " "true"
  log_event "" "██╔══██╗██╔══██╗██║   ██║██║   ██║██╔══██╗██╔    " "true"
  log_event "" "██████╔╝██║  ██║╚██████╔╝╚██████╔╝██████╔╝███████" "true"
  log_event "" "╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚══════" "true"
  log_event "" "                                                 " "true"

  # Ref: http://patorjk.com/software/taag/
  ################################################################################

  # Status (STATUS_D, STATUS_F, STATUS_S, OUTDATED)
  STATUS_D=""
  STATUS_F=""
  STATUS_S=""
  OUTDATED=false

  # Dropbox Uploader config file
  DPU_CONFIG_FILE=~/.dropbox_uploader
  if [[ -e ${DPU_CONFIG_FILE} ]]; then
    # shellcheck source=${DPU_CONFIG_FILE}
    source "${DPU_CONFIG_FILE}"
  else
    generate_dropbox_config
  fi
  DROPBOX_UPLOADER="${DPU_F}/dropbox_uploader.sh"

  # Cloudflare config file
  CLF_CONFIG_FILE=~/.cloudflare.conf
  if [[ -e ${CLF_CONFIG_FILE} ]]; then
    # shellcheck source=${CLF_CONFIG_FILE}
    source "${CLF_CONFIG_FILE}"
  else
    generate_cloudflare_config
  fi

  # BROOBE Utils config file
  if test -f /root/.broobe-utils-options; then
    source "/root/.broobe-utils-options"
  fi

  # Checking distro
  check_distro

  # Checking script permissions
  checking_scripts_permissions

  # Checking required packages to run
  # shellcheck source=${SFOLDER}/libs/packages_helper.sh
  source "${SFOLDER}/libs/packages_helper.sh"
  check_packages_required

  IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

  # MySQL
  MYSQL="$(which mysql)"
  MYSQLDUMP="$(which mysqldump)"

  # TAR
  TAR="$(which tar)"

  # FIND
  FIND="$(which find)"

  # EXPORT VARS (GLOBALS)
  export SCRIPT_V VPSNAME BAKWP SFOLDER DPU_F DROPBOX_UPLOADER SITES SITES_BL DB_BL WSERVER MAIN_VOL PACKAGES PHP_CF LENCRYPT_CF MySQL_CF MYSQL MYSQLDUMP TAR FIND DROPBOX_FOLDER MAILCOW_TMP_BK MHOST MUSER MPASS MAILA NOW NOWDISPLAY ONEWEEKAGO SENDEMAIL TAR DISK_U ONE_FILE_BK IP SMTP_SERVER SMTP_PORT SMTP_TLS SMTP_U SMTP_P STATUS_D STATUS_F STATUS_S OUTDATED LOG BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ENDCOLOR dns_cloudflare_email dns_cloudflare_api_key

}

main_menu() {

  local runner_options chosen_type

  runner_options="01 MAKE_A_BACKUP 02 RESTORE_A_BACKUP 03 PROJECT_UTILS 04 WPCLI_MANAGER 05 CERTBOT_MANAGER 06 CLOUDFLARE_MANAGER 07 INSTALLERS_AND_CONFIGS 08 IT_UTILS 09 SCRIPT_OPTIONS 10 CRON_SCRIPT_TASKS"
  chosen_type=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 $(for x in ${runner_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${chosen_type} == *"01"* ]]; then
      # shellcheck source=${SFOLDER}/libs/backup_helper.sh
      source "${SFOLDER}/libs/backup_helper.sh"
      backup_menu

    fi
    if [[ ${chosen_type} == *"02"* ]]; then
      # shellcheck source=${SFOLDER}/libs/backup_restore_helper.sh
      source "${SFOLDER}/libs/backup_restore_helper.sh"
      restore_menu

    fi

    if [[ ${chosen_type} == *"03"* ]]; then
      project_utils_menu

    fi

    if [[ ${chosen_type} == *"04"* ]]; then
      # shellcheck source=${SFOLDER}/utils/wpcli_manager.sh
      source "${SFOLDER}/utils/wpcli_manager.sh"

    fi
    if [[ ${chosen_type} == *"05"* ]]; then
      # shellcheck source=${SFOLDER}/utils/certbot_manager.sh
      source "${SFOLDER}/utils/certbot_manager.sh"

    fi
    if [[ ${chosen_type} == *"06"* ]]; then
      # shellcheck source=${SFOLDER}/utils/cloudflare_manager.sh
      source "${SFOLDER}/utils/cloudflare_manager.sh"

    fi
    if [[ ${chosen_type} == *"07"* ]]; then
      # shellcheck source=${SFOLDER}/installers_and_configurators.sh
      source "${SFOLDER}/installers_and_configurators.sh"

    fi
    if [[ ${chosen_type} == *"08"* ]]; then
      # shellcheck source=${SFOLDER}/utils/it_utils.sh
      source "${SFOLDER}/utils/it_utils.sh"

    fi
    if [[ ${chosen_type} == *"09"* ]]; then
      script_configuration_wizard "reconfigure"

    fi
    if [[ ${chosen_type} == *"10"* ]]; then
      # CRON_SCRIPT_TASKS
      install_crontab_script "${SFOLDER}/cron/backups_tasks.sh" "00" "45"

    fi
    

  fi

}

security_utils_menu () {

  local security_options chosen_security_options

  security_options="01 MALWARE_SCAN 02 AUDIT_SYSTEM"
  chosen_security_options=$(whiptail --title "SECURITY TOOLS" --menu "Choose an option to run" 20 78 10 $(for x in ${security_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    # shellcheck source=${SFOLDER}/libs/security_helper.sh
    source "${SFOLDER}/libs/security_helper.sh"

    security_install

    if [[ ${chosen_security_options} == *"01"* ]]; then
      security_clamav_scan_menu

    elif [[ ${chosen_security_options} == *"02"* ]]; then
      security_system_audit

    fi

  fi

  main_menu

}

security_clamav_scan_menu () {

  local to_scan

  startdir="${SITES}"
  directory_browser "${menutitle}" "${startdir}"

  to_scan=$filepath"/"$filename

  log_event "info" "Starting clamav scan" "true"
  log_event "info" "Directory to scan: ${to_scan}" "true"

  security_clamav_scan "${to_scan}"

}

project_utils_menu () {

  local project_utils_options chosen_project_utils_options

  project_utils_options="01 CREATE_WP_PROJECT 02 CREATE_PHP_PROJECT 03 DELETE_PROJECT 04 PUT_PROJECT_ONLINE 05 PUT_PROJECT_OFFLINE"
  chosen_project_utils_options=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a Restore Option to run" 20 78 10 $(for x in ${project_utils_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${chosen_project_utils_options} == *"01"* ]]; then
      # shellcheck source=${SFOLDER}/installers/wordpress_installer.sh
      source "${SFOLDER}/utils/installers/wordpress_installer.sh"
    fi

    if [[ ${chosen_project_utils_options} == *"02"* ]]; then

      # TODO: create empty dir on $SITES, create nginx server file, ask for database
      log_event "error" "TODO: CREATE_PHP_PROJECT MUST BE IMPLEMENTED SOON" "true"

    fi

    if [[ ${chosen_project_utils_options} == *"03"* ]]; then
      # shellcheck source=${SFOLDER}/delete_project.sh
      source "${SFOLDER}/delete_project.sh"
    fi

    if [[ ${chosen_project_utils_options} == *"04"* ]]; then
      # shellcheck source=${SFOLDER}/libs/nginx_helper.sh
      source "${SFOLDER}/libs/nginx_helper.sh"
      change_project_status "online"

    fi

    if [[ ${chosen_project_utils_options} == *"05"* ]]; then
      # shellcheck source=${SFOLDER}/libs/nginx_helper.sh
      source "${SFOLDER}/libs/nginx_helper.sh"
      change_project_status "offline"

    fi

  fi

  main_menu

}

change_project_status () {

  #$1 = ${project_status}

  local project_status=$1

  local to_change

  startdir="${SITES}"
  directory_browser "${menutitle}" "${startdir}"

  to_change=${filename%/}

  change_status_nginx_server "${to_change}" "${project_status}"

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

    log_event "warning" "Script config file deleted: /root/.broobe-utils-options" "true"

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
      echo "SITES=${SITES}" >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi

  # DUPLICITY CONFIG
  if [[ -z "${DUP_BK}" ]]; then

    DUP_BK_DEFAULT=false
    DUP_BK=$(whiptail --title "Duplicity Backup Support?" --inputbox "Please insert true or false" 10 60 "${DUP_BK_DEFAULT}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "DUP_BK=${DUP_BK}" >>/root/.broobe-utils-options

      if [[ "${DUP_BK}" = true ]]; then

        if [[ -z "${DUP_ROOT}" ]]; then

          # Duplicity Backups Directory
          DUP_ROOT_DEFAULT="/media/backups/PROJECT_NAME"
          DUP_ROOT=$(whiptail --title "Duplicity Backup Directory" --inputbox "Insert the directory path to storage duplicity Backup" 10 60 "${DUP_ROOT_DEFAULT}" 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "DUP_ROOT=${DUP_ROOT}" >>/root/.broobe-utils-options
          else
            exit 1
          fi
        fi

        if [[ -z "${DUP_SRC_BK}" ]]; then

          # Source of Directories to Backup
          DUP_SRC_BK_DEFAULT="${SITES}"
          DUP_SRC_BK=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_SRC_BK_DEFAULT}" 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "DUP_SRC_BK=${DUP_SRC_BK}" >>/root/.broobe-utils-options
          else
            exit 1
          fi
        fi

        if [[ -z "${DUP_FOLDERS}" ]]; then

          # Folders to Backup
          DUP_FOLDERS_DEFAULT="FOLDER1,FOLDER2"
          DUP_FOLDERS=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_FOLDERS_DEFAULT}" 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "DUP_FOLDERS=${DUP_FOLDERS}" >>/root/.broobe-utils-options
          else
            exit 1
          fi
        fi

        if [[ -z "${DUP_BK_FULL_FREQ}" ]]; then

          # Create a new full backup every ...
          DUP_BK_FULL_FREQ_DEFAULT="7D"
          DUP_BK_FULL_FREQ=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_BK_FULL_FREQ_DEFAULT}" 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "DUP_BK_FULL_FREQ=${DUP_BK_FULL_FREQ}" >>/root/.broobe-utils-options
          else
            exit 1
          fi
        fi

        if [[ -z "${DUP_BK_FULL_LIFE}" ]]; then

          # Delete any backup older than this
          DUP_BK_FULL_LIFE_DEFAULT="14D"
          DUP_BK_FULL_LIFE=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_BK_FULL_LIFE_DEFAULT}" 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "DUP_BK_FULL_LIFE=${DUP_BK_FULL_LIFE}" >>/root/.broobe-utils-options
          else
            exit 1
          fi
        fi

      else

        echo "DUP_ROOT=none" >>/root/.broobe-utils-options
        echo "DUP_SRC_BK=none" >>/root/.broobe-utils-options
        echo "DUP_FOLDERS=none" >>/root/.broobe-utils-options
        echo "DUP_BK_FULL_FREQ=none" >>/root/.broobe-utils-options
        echo "DUP_BK_FULL_LIFE=none" >>/root/.broobe-utils-options
        
      fi

    fi
  
  fi

  # TODO: MAKE TRUE OR FALSE
  if [[ -z "${MAILCOW_BK}" ]]; then

    MAILCOW_BK_DEFAULT=false
    
    MAILCOW_BK=$(whiptail --title "Mailcow Backup Support?" --inputbox "Please insert true or false" 10 60 "${MAILCOW_BK_DEFAULT}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "MAILCOW_BK=${MAILCOW_BK}" >>/root/.broobe-utils-options
      
      if [[ -z "${MAILCOW}" && "${MAILCOW_BK}" = true ]]; then

        # MailCow Dockerized default files location
        MAILCOW_DEFAULT="/opt/mailcow-dockerized"
        MAILCOW=$(whiptail --title "Mailcow Installation Path" --inputbox "Insert the path where Mailcow is installed" 10 60 "${MAILCOW_DEFAULT}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then
          echo "MAILCOW=${MAILCOW}" >>/root/.broobe-utils-options
        else
          return 1

        fi

      fi

    else
      return 1
      
    fi

  fi

}

################################################################################
# LOGGERS
################################################################################

log_event() {

  # $1 = {log_type} options: success, info, warning, error, critical
  # $2 = {message}
  # $3 = {console_display} optional (true or false, emtpy equals false)

  local log_type=$1
  local message=$2
  local console_display=$3

   case $log_type in

   success)
        echo " > SUCCESS: ${message}" >> "${LOG}"
        if [ "${console_display}" = "true" ]; then
          echo -e "${B_GREEN} > ${message}${ENDCOLOR}" >&2
        fi
        ;;

      info)
        echo " > INFO: ${message}" >> "${LOG}"
        if [ "${console_display}" = "true" ]; then
          echo -e "${B_CYAN} > ${message}${ENDCOLOR}" >&2
        fi
        ;;

      warning)
        echo " > WARNING: ${message}" >> "${LOG}"
        if [ "${console_display}" = "true" ]; then
          echo -e "${YELLOW} > ${message}${ENDCOLOR}" >&2
        fi
        ;;

      error)
        echo " > ERROR: ${message}" >> "${LOG}"
        if [ "${console_display}" = "true" ]; then
          echo -e "${RED} > ${message}${ENDCOLOR}" >&2
        fi
        ;;

      critical)
        echo " > CRITICAL: ${message}" >> "${LOG}"
        if [ "${console_display}" = "true" ]; then
          echo -e "${B_RED} > ${message}${ENDCOLOR}" >&2
        fi
        ;;

      *)
        echo " > ${message}" >> "${LOG}"
        if [ "${console_display}" = "true" ]; then
          echo -e "${CYAN} > ${message}${ENDCOLOR}" >&2
        fi
        ;;
    esac

}

################################################################################
# CHECKERS
################################################################################

check_root() {
  # Check if user is root
  if [ "${USER}" != root ]; then
    echo -e ${B_RED}" > Error: Script runned by ${USER}, but must be root! Exiting..."${ENDCOLOR}
    exit 1
  fi

}

check_distro() {

  local distro_old

  #for ext check
  distro_old="false"

  # Running Ubuntu?
  DISTRO=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')
  if [ ! "$DISTRO" = "Ubuntu" ]; then
    log_event "critical" "This script only run on Ubuntu ... Exiting" "true"
    exit 1

  else
    MIN_V=$(echo "18.04" | awk -F "." '{print $1$2}')
    DISTRO_V=$(get_ubuntu_version)
    
    log_event "info" "ACTUAL DISTRO: ${DISTRO} ${DISTRO_V}" "false"

    if [ ! "$DISTRO_V" -ge "$MIN_V" ]; then
      whiptail --title "UBUNTU VERSION WARNING" --msgbox "Ubuntu version must be 18.04 or 20.04! Use this script only for backup or restore purpose." 8 78
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        distro_old="true"
        log_event "info" "Setting distro_old: ${distro_old}" "false"
        
      else
        return 0

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

whiptail_event() {

  # $1 = {whip_title}
  # $2 = {whip_message}

  local whip_title=$1
  local whip_message=$2

  whip_message_result=$(whiptail --title "${whip_title}" --msgbox "${whip_message}" 15 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    log_event "info" "whip_message_result for ${whip_title}=$whip_message_result" "true"

  else
    return 1

  fi

}

get_ubuntu_version() {

  lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $2}' | awk -F "." '{print $1$2}'

}

# TODO: refactor this
declare -a checklist_array

array_to_checklist() {

  local i

  i=0
  for option in $1; do
    checklist_array[$i]=$option
    i=$((i + 1))
    checklist_array[$i]=" "
    i=$((i + 1))
    checklist_array[$i]=off
    i=$((i + 1))
  done

  # checklist_array returned

}

file_browser() {

  # $1= ${menutitle}
  # $2= ${startdir}

  local menutitle=$1
  local startdir=$2

  if [ -z "${startdir}" ]; then
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "${startdir}"
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "$curdir" == "/" ]; then # Check if you are at root folder
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select $dir_list 3>&1 1>&2 2>&3)
  else # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "${menutitle}" \
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

        # Return 1
        filename="$selection"
        # Return 2
        filepath="$curdir" # Return full filepath and filename as selection variables
      
      fi
    
    fi
  
  fi

}

directory_browser() {

  # $1= ${menutitle}
  # $2= ${startdir}

  local menutitle=$1
  local startdir=$2

  if [ -z "${startdir}" ]; then
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "${startdir}"
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "$curdir" == "/" ]; then # Check if you are at root folder
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select $dir_list 3>&1 1>&2 2>&3)
  else # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "${menutitle}" \
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

        # Return 1
        filename="$selection"
        # Return 2
        filepath="$curdir" # Return full filepath and filename as selection variables

      fi

    fi

  fi

}

get_all_directories() {

  # $1 = ${SITES}

  local main_dir=$1

  first_level_dir=$(find ${main_dir} -maxdepth 1 -type d)

  # Return
  echo "${first_level_dir}"

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

get_project_type() {

  # $1 = ${dir_path}

  local dir_path=$1

  local project_type is_wp

  if [ "${dir_path}" != "" ];then

    is_wp=$(search_wp_config "${dir_path}")

    if [ "${is_wp}" != "" ];then

      project_type="wordpress"

      else

      # TODO: implements laravel, yii, and others php framework support
      project_type="project_type_unknown"

    fi

  fi

  # Return
  echo "${project_type}"

}


generate_dropbox_config() {

  local oauth_access_token_string OAUTH_ACCESS_TOKEN

  oauth_access_token_string+="\n . \n"
  oauth_access_token_string+=" 1) Log in: dropbox.com/developers/apps/create\n"
  oauth_access_token_string+=" 2) Click on \"Create App\" and select \"Dropbox API\".\n"
  oauth_access_token_string+=" 3) Choose the type of access you need.\n"
  oauth_access_token_string+=" 4) Enter the \"App Name\".\n"
  oauth_access_token_string+=" 5) Click on the \"Create App\" button.\n"
  oauth_access_token_string+=" 6) Click on the Generate button.\n"
  oauth_access_token_string+=" 7) Copy and paste the new access token here:\n\n"

  OAUTH_ACCESS_TOKEN=$(whiptail --title "Dropbox Uploader Configuration" --inputbox "${oauth_access_token_string}" 15 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" >${DPU_CONFIG_FILE}
    log_event "info" "Dropbox configuration has been saved!" "true"

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
      return 1

    fi

  else
    return 1

  fi

}

calculate_disk_usage() {

  # $1 = ${disk_volume}

  local disk_volume=$1

  local disk_u

  # Need to use grep with -w to exact match of the main volume
  disk_u=$(df -h | grep -w "${disk_volume}" | awk {'print $5'})

  log_event "info" "Disk usage of ${disk_volume}: ${disk_u} ..." "true"

  echo "${disk_u}"

}

check_if_folder_exists() {

  # $1 = ${folder_to_install}
  # $2 = ${domain}

  local folder_to_install=$1
  local domain=$2

  local project_dir="${folder_to_install}/${domain}"
  
  if [ -d "${project_dir}" ]; then
    echo "ERROR"

  else
    echo "${project_dir}"

  fi
}

change_ownership(){

  #$1 = ${user}
  #$2 = ${group}
  #$3 = ${path}

  local user=$1
  local group=$2
  local path=$3

  log_event "info" "Running: chown -R ${user}:${group} ${path}" "true"
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

install_crontab_script() {

  # $1 = script
  # $2 = hh (hour)
  # $3 = mm (minutes)

  local script=$1
  local hh=$2
  local mm=$3

  local cron_file

  cron_file="/var/spool/cron/crontabs/root"

  if [ ! -f ${cron_file} ]; then
    log_event "info" "Cron file for root does not exist, creating ..." "true"

	  touch "${cron_file}"
	  /usr/bin/crontab "${cron_file}"

    log_event "success" "Cron file created" "true"

	fi

  grep -qi "${script}" "${cron_file}"
  grep_result=$?
	if [ ${grep_result} != 0 ]; then
    log_event "info" "Updating cron job for script ..." "true"
    /bin/echo "${mm} ${hh} * * * ${script}" >> "${cron_file}"
    
  else
    log_event "warning" "Script already installed" "true"

	fi

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
    return 1

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

ask_rootdomain_for_cloudflare_config() {

  # TODO: check with CF API if root domain exists

  # $1 = ${root_domain} (could be empty)

  local root_domain=$1

  if [[ -z "${root_domain}" ]]; then
    root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
  else
    root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 "${root_domain}" 3>&1 1>&2 2>&3)
  fi
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    # Return
    echo "${root_domain}"

  else
    return 1

  fi

}

ask_subdomains_to_cloudflare_config() {

  # TODO: MAKE IT WORKS

  # $1 = ${subdomains} optional to select default option (could be empty)

  local subdomains=$1;

  subdomains=$(whiptail --title "Cloudflare Subdomains" --inputbox "Insert the subdomains you want to update in Cloudflare (comma separated). Example: www.broobe.com,broobe.com" 10 60 "${DOMAIN}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    log_event "info" "Setting subdomains=${subdomains}" "true"
    # Return
    echo "${subdomains}"

  else
    return 1

  fi

}

ask_folder_to_install_sites() {

  # $1 = ${folder_to_install} optional to select default option (could be empty)

  local folder_to_install=$1

  if [[ -z "${folder_to_install}" ]]; then
    
    folder_to_install=$(whiptail --title "Folder to work with" --inputbox "Please insert the full path where you want to install the site:" 10 60 "${folder_to_install}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then

      log_event "info" "Folder to work with: ${folder_to_install}" "true"

      # Return
      echo "${folder_to_install}"

    else
      return 1

    fi

  else

    log_event "info" "Folder to install: ${folder_to_install}" "true"
    
    # Return
    echo "${folder_to_install}"
    
  fi

}

ask_mysql_root_psw() {

  # MPASS is defined globally

  if [[ -z "${MPASS}" ]]; then
    MPASS=$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root Password" 10 60 "${MPASS}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      #echo "> Running: mysql -u root -p${MPASS} -e"
      until mysql -u root -p"${MPASS}" -e ";"; do
        read -s -p " > Can't connect to MySQL, please re-enter $MUSER password: " MPASS
      
      done
      echo "MPASS=${MPASS}" >>/root/.broobe-utils-options

    else
      exit 1

    fi
  fi

}

ask_url_search_and_replace() {

  # $1 = wp_path

  local wp_path=$1

  if [[ -z "${existing_URL}" ]]; then
    existing_URL=$(whiptail --title "URL TO CHANGE" --inputbox "Insert the URL you want to change, including http:// or https://" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?

    #echo "Setting existing_URL=${existing_URL}" >>$LOG

    if [ ${exitstatus} = 0 ]; then

      if [[ -z "${new_URL}" ]]; then
        new_URL=$(whiptail --title "THE NEW URL" --inputbox "Insert the new URL , including http:// or https://" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ ${exitstatus} = 0 ]; then

          log_event "info" "Setting the new URL ${new_URL} on wordpress database" "true"

          wpcli_search_and_replace "${wp_path}" "${existing_URL}" "${new_URL}"

        fi

      fi

    fi

  fi

}

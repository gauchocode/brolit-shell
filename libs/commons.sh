#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.3
################################################################################

#
#################################################################################
#
# * Globals
#
#################################################################################
#

SCRIPT_N="LEMP UTILS SCRIPT"
SCRIPT_V="3.0.3"

# Hostname
VPSNAME="$HOSTNAME"

#
#################################################################################
#
# * Sources
#
#################################################################################
#

# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_restore_helper.sh
source "${SFOLDER}/libs/backup_restore_helper.sh"
# shellcheck source=${SFOLDER}/libs/certbot_helper.sh
source "${SFOLDER}/libs/certbot_helper.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/nginx_helper.sh
source "${SFOLDER}/libs/nginx_helper.sh"
# shellcheck source=${SFOLDER}/libs/optimizations_helper.sh
source "${SFOLDER}/libs/optimizations_helper.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"
# shellcheck source=${SFOLDER}/libs/project_helper.sh
source "${SFOLDER}/libs/project_helper.sh"
# shellcheck source=${SFOLDER}/libs/security_helper.sh
source "${SFOLDER}/libs/security_helper.sh"
# shellcheck source=${SFOLDER}/libs/sftp_helper.sh
source "${SFOLDER}/libs/sftp_helper.sh"
# shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
source "${SFOLDER}/libs/telegram_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
source "${SFOLDER}/libs/wordpress_helper.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"

################################################################################

#
#################################################################################
#
# * Options
#
#################################################################################
#
CRONJOB=0                           # Run as a cronjob
DEBUG=0                             # Debugging mode (to screen)
QUICKMODE=1                         # Don't wait for user input
QUIET=0                             # Show normal messages and warnings as well
SKIPLOGTEST=0                       # Skip logging for one test

WSERVER="/etc/nginx"                # NGINX config files location
MySQL_CF="/etc/mysql"               # MySQL config files location
PHP_CF="/etc/php"                   # PHP config files location
LENCRYPT_CF="/etc/letsencrypt"      # Let's Encrypt config files location

# Folder blacklist
SITES_BL=".wp-cli,html"

# Database blacklist
DB_BL="information_schema,performance_schema,mysql,sys,phpmyadmin"

#MAILCOW BACKUP
MAILCOW_TMP_BK="${SFOLDER}/tmp/mailcow"

PHP_V=$(php -r "echo PHP_VERSION;" | grep --only-matching --perl-regexp "7.\d+")
php_exit=$?
if [ "${php_exit}" -eq 1 ];then
  # TODO: must be an option
  # Packages to watch
  PACKAGES=(linux-firmware dpkg nginx "php${PHP_V}-fpm" mysql-server openssl)
fi

# MySQL host and user
MHOST="localhost"
MUSER="root"

# Main partition
MAIN_VOL=$(df /boot | grep -Eo '/dev/[^ ]+')

# Dropbox Folder Backup
DROPBOX_FOLDER="/"

# Dropbox Uploader Directory
DPU_F="${SFOLDER}/tools/third-party/dropbox-uploader"

# Time Vars
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

startdir=""
menutitle="Config Selection Menu"

#
#################################################################################
#
# * Colours
#
#################################################################################
#

# Text Styles
#NORMAL='\x1b[2m normal'
NORMAL="\033[m"
BOLD='\x1b[1m'
ITALIC='\x1b[3m'
UNDERLINED='\x1b[4m'
INVERTED='\x1b[7m'

# Text Colours
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

#
#################################################################################
#
# * Functions
#
#################################################################################
#

script_init() {

  # Temp folders
  BAKWP="${SFOLDER}/tmp"

  ### Creating temporary folders
  if [ ! -d "${BAKWP}" ]; then
    echo " > Folder ${BAKWP} doesn't exist. Creating ..."
    mkdir "${BAKWP}"
  fi
  if [ ! -d "${BAKWP}/${NOW}" ]; then
    echo " > Folder ${BAKWP}/${NOW} doesn't exist. Creating ..."
    mkdir "${BAKWP}/${NOW}"
  fi

  ### Log
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  PATH_LOG="${SFOLDER}/log"
  if [ ! -d "${SFOLDER}/log" ]; then
    mkdir "${SFOLDER}/log"
  fi

  LOG_NAME="log_lemp_utils_${TIMESTAMP}.log"
  LOG="${PATH_LOG}/${LOG_NAME}"

  find "${PATH_LOG}" -name "*.log" -type f -mtime +7 -print -delete >>"${LOG}"

  # Clear Screen
  clear_screen

  # Log Start
  log_event "" "WELCOME TO ${SCRIPT_N} v${SCRIPT_V}" "true"
  log_event "info" "Script Start -- $(date +%Y%m%d_%H%M)"

  ### Welcome #######################################################################

  log_event "" "                                                 " "true"
  log_event "" "██████╗ ██████╗  ██████╗  ██████╗ ██████╗ ███████" "true"
  log_event "" "██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗██╔══██╗██╔══  " "true"
  log_event "" "██████╔╝██████╔╝██║   ██║██║   ██║██████╔╝█████  " "true"
  log_event "" "██╔══██╗██╔══██╗██║   ██║██║   ██║██╔══██╗██╔    " "true"
  log_event "" "██████╔╝██║  ██║╚██████╔╝╚██████╔╝██████╔╝███████" "true"
  log_event "" "╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚══════" "true"
  log_event "" "                                                 " "true"

  log_event "" "-------------------------------------------------" "true"

  # Ref: http://patorjk.com/software/taag/
  ################################################################################

  # Status (STATUS_D, STATUS_F, STATUS_S, OUTDATED)
  STATUS_D=""
  STATUS_F=""
  STATUS_S=""
  STATUS_C=""
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

  # Telegram config file
  TEL_CONFIG_FILE=~/.telegram.conf
  if [[ -e ${TEL_CONFIG_FILE} ]]; then
    # shellcheck source=${CLF_CONFIG_FILE}
    source "${TEL_CONFIG_FILE}"
  else
    generate_telegram_config
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
  check_packages_required
  packages_output=$?
  if [ ${packages_output} -eq 1 ];then
    log_event "warning" "Some script dependencies are not setisfied." "true"
    prompt_return_or_finish
  fi

  # OLD METHOD (DEPRECATED)
  #SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

  # METHOD TO GET PUBLIC IP (if server has configured a floating ip, it will return this)
  SERVER_IP=$(ifconfig eth0 | grep 'inet ' | awk '{print $2}' | sed 's/addr://')

  if [ "${SERVER_IP}" == "" ]; then

    # Alternative method to get public IP
    SERVER_IP=$(curl -s http://ipv4.icanhazip.com)

  fi

  # EXPORT VARS (GLOBALS)
  export SCRIPT_V VPSNAME BAKWP SFOLDER DPU_F DROPBOX_UPLOADER SITES SITES_BL DB_BL WSERVER MAIN_VOL PACKAGES PHP_CF PHP_V LENCRYPT_CF MySQL_CF MYSQL MYSQLDUMP TAR FIND DROPBOX_FOLDER MAILCOW_TMP_BK MHOST MUSER MPASS MAILA NOW NOWDISPLAY ONEWEEKAGO SENDEMAIL DISK_U ONE_FILE_BK SERVER_IP SMTP_SERVER SMTP_PORT SMTP_TLS SMTP_U SMTP_P STATUS_D STATUS_F STATUS_S OUTDATED LOG BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ENDCOLOR dns_cloudflare_email dns_cloudflare_api_key

}

customize_ubuntu_login_message() {

  # TODO: screenfetch support?

  # Remove unnecesary messages
  if [ -d "/etc/update-motd.d/10-help-text " ]; then
    rm "/etc/update-motd.d/10-help-text "

  fi
  if [ -d "/etc/update-motd.d/50-motd-news" ]; then
    rm "/etc/update-motd.d/50-motd-news"

  fi
  if [ -d "/etc/update-motd.d/00-header" ]; then
    rm "/etc/update-motd.d/00-header"

  fi

  # Copy new login message
  cp "${SFOLDER}/config/motd/00-header" "/etc/update-motd.d"

  # Force update
  run-parts "/etc/update-motd.d"

}

main_menu() {

  local whip_title              # whiptail var
  local whip_description        # whiptail var
  local runner_options          # whiptail array options
  local chosen_type             # whiptail var

  whip_title="LEMP UTILS SCRIPT"
  whip_description=" "

  runner_options=("01)" "BACKUP OPTIONS" "02)" "RESTORE OPTIONS" "03)" "PROJECT UTILS" "04)" "WPCLI MANAGER" "05)" "CERTBOT MANAGER" "06)" "CLOUDFLARE MANAGER" "07)" "INSTALLERS & CONFIGS" "08)" "IT UTILS" "09)" "SCRIPT OPTIONS" "10)" "CRON TASKS")
  chosen_type=$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${runner_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_type} == *"01"* ]]; then
      backup_menu

    fi
    if [[ ${chosen_type} == *"02"* ]]; then
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
      # shellcheck source=${SFOLDER}/utils/installers_and_configurators.sh
      source "${SFOLDER}/utils/installers_and_configurators.sh"

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
      cron_script_tasks

    fi

  fi

}

cron_script_tasks() {

  local runner_options 
  local chosen_type 
  local scheduled_time

  runner_options=("01)" "BACKUPS TASKS" "02)" "OPTIMIZER TASKS" "03)" "WORDPRESS TASKS" "04)" "UPTIME TASKS" "05)" "SCRIPT UPDATER")
  chosen_type=$(whiptail --title "CRONEABLE TASKS" --menu "\n" 20 78 10 "${runner_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_type} == *"01"* ]]; then

      # BACKUPS-TASKS
      suggested_cron="45 00 * * *" # Every day at 00:45 AM
      scheduled_time=$(whiptail --title "CRON BACKUPS-TASKS" --inputbox "Insert a cron expression for the task:" 10 60 "${suggested_cron}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        
        install_crontab_script "${SFOLDER}/cron/backups_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"02"* ]]; then

      # OPTIMIZER-TASKS
      suggested_cron="45 04 * * *" # Every day at 04:45 AM
      scheduled_time=$(whiptail --title "CRON OPTIMIZER-TASKS" --inputbox "Insert a cron expression for the task:" 10 60 "${suggested_cron}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        
        install_crontab_script "${SFOLDER}/cron/optimizer_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"03"* ]]; then

      # WORDPRESS-TASKS
      suggested_cron="45 23 * * *" # Every day at 23:45 AM
      scheduled_time=$(whiptail --title "CRON WORDPRESS-TASKS" --inputbox "Insert a cron expression for the task:" 10 60 "${suggested_cron}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        
        install_crontab_script "${SFOLDER}/cron/wordpress_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"04"* ]]; then

      # UPTIME-TASKS
      suggested_cron="45 22 * * *" # Every day at 22:45 AM
      scheduled_time=$(whiptail --title "CRON UPTIME-TASKS" --inputbox "Insert a cron expression for the task:" 10 60 "${suggested_cron}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        
        install_crontab_script "${SFOLDER}/cron/uptime_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"05"* ]]; then

      # SCRIPT-UPDATER
      suggested_cron="45 22 * * *" # Every day at 22:45 AM
      scheduled_time=$(whiptail --title "CRON UPTIME-TASKS" --inputbox "Insert a cron expression for the task:" 10 60 "${suggested_cron}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        
        install_crontab_script "${SFOLDER}/cron/updater.sh" "${scheduled_time}"

      fi

    fi

    prompt_return_or_finish
    cron_script_tasks

  fi

  main_menu

}

security_utils_menu () {

  # TODO: new options? https://upcloud.com/community/tutorials/scan-ubuntu-server-malware/

  local security_options chosen_security_options

  security_options=("01)" "CLAMAV MALWARE SCAN" "02)" "CUSTOM MALWARE SCAN" "03)" "LYNIS SYSTEM AUDIT")
  chosen_security_options=$(whiptail --title "SECURITY TOOLS" --menu "Choose an option to run" 20 78 10 "${security_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    security_install

    if [[ ${chosen_security_options} == *"01"* ]]; then
      security_clamav_scan_menu

    fi
    if [[ ${chosen_security_options} == *"02"* ]]; then
      security_custom_scan_menu

    fi
    if [[ ${chosen_security_options} == *"03"* ]]; then
      security_system_audit

    fi

    prompt_return_or_finish
    security_utils_menu

  fi

  main_menu

}

security_clamav_scan_menu () {

  local to_scan

  startdir="${SITES}"
  directory_browser "${menutitle}" "${startdir}"

  to_scan=$filepath"/"$filename

  log_event "info" "Starting clamav scan on: ${to_scan}" "false"

  security_clamav_scan "${to_scan}"

}

security_custom_scan_menu () {

  local to_scan

  startdir="${SITES}"
  directory_browser "${menutitle}" "${startdir}"

  to_scan=$filepath"/"$filename

  log_event "info" "Starting custom scan on: ${to_scan}" "false"

  security_custom_scan "${to_scan}"

}

project_utils_menu () {

  local whip_title whip_description project_utils_options chosen_project_utils_options

  whip_title="PROJECT UTILS"
  whip_description=" "

  project_utils_options=("01)" "CREATE WP PROJECT" "02)" "CREATE PHP PROJECT" "03)" "DELETE PROJECT" "04)" "PUT PROJECT ONLINE" "05)" "PUT PROJECT OFFLINE" "06)" "REGENERATE NGINX SERVER" "07)" "BENCH PROJECT GTMETRIX")
  chosen_project_utils_options=$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_utils_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ ${exitstatus} = 0 ]; then

    if [[ ${chosen_project_utils_options} == *"01"* ]]; then
      
      # CREATE-WP-PROJECT

      # shellcheck source=${SFOLDER}/installers/wordpress_installer.sh
      source "${SFOLDER}/utils/installers/wordpress_installer.sh"
    fi

    if [[ ${chosen_project_utils_options} == *"02"* ]]; then

      # CREATE-PHP-PROJECT

      # TODO: create empty dir on $SITES, create nginx server file, ask for database
      log_event "error" "TODO: CREATE_PHP_PROJECT MUST BE IMPLEMENTED SOON" "true"

    fi

    if [[ ${chosen_project_utils_options} == *"03"* ]]; then

      # DELETE-PROJECT

      # shellcheck source=${SFOLDER}/utils/delete_project.sh
      source "${SFOLDER}/utils/delete_project.sh"

    fi

    if [[ ${chosen_project_utils_options} == *"04"* ]]; then

      # PUT-PROJECT-ONLINE
      change_project_status "online"

    fi

    if [[ ${chosen_project_utils_options} == *"05"* ]]; then

      # PUT-PROJECT-OFFLINE
      change_project_status "offline"

    fi

    if [[ ${chosen_project_utils_options} == *"06"* ]]; then

      # REGENERATE-NGINX-SERVER

      log_section "Nginx Manager"

      # Select project to work with
      directory_browser "Select a Website to work with" "${SITES}" #return $filename

      if [ "${filename}" != "" ]; then

        filename="${filename::-1}" # remove '/'
        
        display --indent 2 --text "- Selecting website to work with" --result DONE --color GREEN
        display --indent 4 --text "Selected website: ${filename}"

        # Aks project domain
        project_domain=$(ask_project_domain "${filename}")

        # Aks project type
        project_type=$(ask_project_type)
        
        # New site Nginx configuration
        nginx_server_create "${project_domain}" "${project_type}" "single" ""

      else

        display --indent 2 "Selecting website to work with" --result SKIPPED --color YELLOW

      fi

    fi

    if [[ ${chosen_project_utils_options} == *"07"* ]]; then

      # BENCH-PROJECT-GTMETRIX

      URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        # shellcheck source=${SFOLDER}/tools/third-party/google-insights-api-tools/gitools_v5.sh
        source "${SFOLDER}/tools/third-party/google-insights-api-tools/gitools_v5.sh" gtmetrix "${URL_TO_TEST}"
      fi

    fi

    prompt_return_or_finish
    project_utils_menu

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

  nginx_server_change_status "${to_change}" "${project_status}"

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
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "SMTP_SERVER="${SMTP_SERVER} >>/root/.broobe-utils-options
    else
      return 1
    fi
  fi
  if [[ -z "${SMTP_PORT}" ]]; then
    SMTP_PORT=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server Port" 10 60 "${SMTP_PORT_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "SMTP_PORT=${SMTP_PORT}" >>/root/.broobe-utils-options
    else
      return 1
    fi
  fi
  if [[ -z "${SMTP_TLS}" ]]; then
    SMTP_TLS=$(whiptail --title "SMTP TLS" --inputbox "SMTP yes or no:" 10 60 "${SMTP_TLS_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "SMTP_TLS=${SMTP_TLS}" >>/root/.broobe-utils-options
    else
      return 1
    fi
  fi
  if [[ -z "${SMTP_U}" ]]; then
    SMTP_U=$(whiptail --title "SMTP User" --inputbox "Please insert the SMTP user" 10 60 "${SMTP_U_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "SMTP_U=${SMTP_U}" >>/root/.broobe-utils-options
    else
      return 1
    fi
  fi
  if [[ -z "${SMTP_P}" ]]; then
    SMTP_P=$(whiptail --title "SMTP Password" --inputbox "Please insert the SMTP user password" 10 60 "${SMTP_P_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "SMTP_P=${SMTP_P}" >>/root/.broobe-utils-options
    else
      return 1
    fi
  fi
  if [[ -z "${MAILA}" ]]; then
    MAILA=$(whiptail --title "Notification Email" --inputbox "Insert the email where you want to receive notifications." 10 60 "${MAILA_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "MAILA=${MAILA}" >>/root/.broobe-utils-options
    else
      return 1
    fi
  fi
  if [[ -z "${SITES}" ]]; then
    SITES=$(whiptail --title "Websites Root Directory" --inputbox "Insert the path where websites are stored. Ex: /var/www or /usr/share/nginx" 10 60 "${SITES_OLD}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "SITES=${SITES}" >>/root/.broobe-utils-options
    else
      return 1
    fi
  fi

  # DUPLICITY CONFIG
  if [[ -z "${DUP_BK}" ]]; then

    DUP_BK_DEFAULT=false
    DUP_BK=$(whiptail --title "Duplicity Backup Support?" --inputbox "Please insert true or false" 10 60 "${DUP_BK_DEFAULT}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "DUP_BK=${DUP_BK}" >>/root/.broobe-utils-options

      if [[ "${DUP_BK}" = true ]]; then

        if [[ -z "${DUP_ROOT}" ]]; then

          # Duplicity Backups Directory
          DUP_ROOT_DEFAULT="/media/backups/PROJECT_NAME"
          DUP_ROOT=$(whiptail --title "Duplicity Backup Directory" --inputbox "Insert the directory path to storage duplicity Backup" 10 60 "${DUP_ROOT_DEFAULT}" 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [[ ${exitstatus} -eq 0 ]]; then
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
          if [[ ${exitstatus} -eq 0 ]]; then
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
          if [[ ${exitstatus} -eq 0 ]]; then
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
          if [[ ${exitstatus} -eq 0 ]]; then
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
          if [[ ${exitstatus} -eq 0 ]]; then
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
    if [[ ${exitstatus} -eq 0 ]]; then
      echo "MAILCOW_BK=${MAILCOW_BK}" >>/root/.broobe-utils-options
      
      if [[ -z "${MAILCOW}" && "${MAILCOW_BK}" = true ]]; then

        # MailCow Dockerized default files location
        MAILCOW_DEFAULT="/opt/mailcow-dockerized"
        MAILCOW=$(whiptail --title "Mailcow Installation Path" --inputbox "Insert the path where Mailcow is installed" 10 60 "${MAILCOW_DEFAULT}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
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

#
#################################################################################
#
# * Loggers
#
#################################################################################
#

log_event() {

  # Parameters
  # $1 = {log_type} (success, info, warning, error, critical)
  # $2 = {message}
  # $3 = {console_display} optional (true or false, default is false)

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
          echo -e "${YELLOW}${ITALIC} > ${message}${ENDCOLOR}" >&2
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

      debug)
        if [ "${DEBUG}" -eq 1 ]; then

          echo " > DEBUG: ${message}" >> "${LOG}"
          if [ "${console_display}" = "true" ]; then
            echo -e "${B_MAGENTA} > ${message}${ENDCOLOR}" >&2
          fi

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

log_break() {

  # Parameters
  # $1 = {console_display} optional (true or false, emtpy equals false)

  local console_display=$1

  local log_break
  
  log_break="    -------------------------------------------------------------------"
  
  echo "${log_break}" >> "${LOG}"
  if [ "${console_display}" = "true" ]; then
    echo -e "${MAGENTA}${log_break}${ENDCOLOR}" >&2
  fi

}

log_section() {

  # Parameters
  # $1 = {message}

  local message=$1

    if [ "${QUIET}" -eq 0 ]; then
        echo "" >&2
        echo -e "[+] Performing Action: ${YELLOW}${message}${NORMAL}" >&2
        echo "----------------------------------------------" >&2
    fi

}

log_subsection() {

  # Parameters
  # $1 = {message}

  local message=$1

    if [ "${QUIET}" -eq 0 ]; then
        echo "" >&2
        echo -e "    [·] ${CYAN}${message}${NORMAL}" >&2
        echo "    ------------------------------------------" >&2
    fi

}

clear_screen() {

  echo -en "\ec" >&2

}

clear_last_line() {

  printf "\033[1A" >&2
  echo "                                                                                             " >&2
  printf "\033[1A" >&2
  printf "\033[1A" >&2

}

display() {

  INDENT=0; TEXT=""; RESULT=""; TCOLOR=""; COLOR=""; SPACES=0; SHOWDEBUG=0; CRONJOB=0;
  
  while [ $# -ge 1 ]; do
      case $1 in
          --color)
              shift
                  case $1 in
                    GREEN)    COLOR=$GREEN   ;;
                    RED)      COLOR=$RED     ;;
                    WHITE)    COLOR=$WHITE   ;;
                    YELLOW)   COLOR=$YELLOW  ;;
                    MAGENTA)  COLOR=$MAGENTA  ;
                  esac
          ;;
          --debug)
              SHOWDEBUG=1
          ;;
          --indent)
              shift
              INDENT=$1
          ;;
          --result)
              shift
              RESULT=$1
          ;;
          --tcolor)
            shift
                case $1 in
                  GREEN)    COLOR=$GREEN   ;;
                  RED)      COLOR=$RED     ;;
                  WHITE)    COLOR=$WHITE   ;;
                  YELLOW)   COLOR=$YELLOW  ;;
                  MAGENTA)  COLOR=$MAGENTA  ;
                esac
          ;;
          --text)
              shift
              TEXT=$1
          ;;
          *)
              echo "INVALID OPTION (Display): $1" >&2
              #ExitFatal
          ;;
      esac
      # Go to next parameter
      shift
  done

  if [ -z "${RESULT}" ]; then
      RESULTPART=""
  else
      if [ ${CRONJOB} -eq 0 ]; then
          RESULTPART=" [ ${COLOR}${RESULT}${NORMAL} ]"
      else
          RESULTPART=" [ ${RESULT} ]"
      fi
  fi

  if [ -n "${TEXT}" ]; then
      SHOW=0

      if [ ${SHOW} -eq 0 ]; then
          # Display:
          # - for full shells, count with -m instead of -c, to support language locale (older busybox does not have -m)
          # - wc needs LANG to deal with multi-bytes characters but LANG has been unset in include/consts
          LINESIZE=$(export LC_ALL= ; echo "${TEXT}" | wc -m | tr -d ' ')
          if [ "${SHOWDEBUG}" -eq 1 ]; then DEBUGTEXT=" [${PURPLE}DEBUG${NORMAL}]"; else DEBUGTEXT=""; fi
          if [ "${INDENT}" -gt 0 ]; then SPACES=$((62 - INDENT - LINESIZE)); fi
          if [ "${SPACES}" -lt 0 ]; then SPACES=0; fi
          if [ "${CRONJOB}" -eq 0 ]; then
            # Check if we already have already discovered a proper echo command tool. It not, set it default to 'echo'.
            #if [ "${ECHOCMD}" = "" ]; then ECHOCMD="echo"; fi
            echo -e "\033[${INDENT}C${TCOLOR}${TEXT}${NORMAL}\033[${SPACES}C${RESULTPART}${DEBUGTEXT}" >&2

          else
            echo "${TEXT}${RESULTPART}" >&2

          fi
      fi

  fi

}

#
#################################################################################
#
# * Checkers
#
#################################################################################
#

check_root() {

  # Check if user is root
  if [ "${USER}" != root ]; then
    echo -e "${B_RED} > Error: Script runned by ${USER}, but must be root! Exiting ...${ENDCOLOR}"
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
    return 1

  else
    MIN_V=$(echo "18.04" | awk -F "." '{print $1$2}')
    DISTRO_V=$(get_ubuntu_version)
    
    log_event "info" "ACTUAL DISTRO: ${DISTRO} ${DISTRO_V}" "false"

    if [ ! "${DISTRO_V}" -ge "${MIN_V}" ]; then
      whiptail --title "UBUNTU VERSION WARNING" --msgbox "Ubuntu version must be 18.04 or 20.04! Use this script only for backup or restore purpose." 8 78
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        distro_old="true"
        log_event "info" "Setting distro_old: ${distro_old}" "false"
        
      else
        return 1

      fi
      
    fi

  fi

}

checking_scripts_permissions() {

  ### chmod
  find ./ -name "*.sh" -exec chmod +x {} \;

}

#
#################################################################################
#
# * Helpers
#
#################################################################################
#

whiptail_event() {

  # $1 = {whip_title}
  # $2 = {whip_message}

  local whip_title=$1
  local whip_message=$2

  whiptail --title "${whip_title}" --msgbox "${whip_message}" 15 60 3>&1 1>&2 2>&3
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    return 0

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

  #log_event "info" "Starting directory_browser ..." "true"

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
    if [[ -d "${selection}" ]]; then # Check if Directory Selected
      whiptail --title "Confirm Selection" --yesno "${selection}" --yes-button "Confirm" --no-button "Retry" 10 60 3>&1 1>&2 2>&3
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
          # Return 1
        filename="${selection}"
        # Return 2
        filepath="${curdir}" # Return full filepath and filename as selection variables

      else
        return 1

      fi

    fi

  fi

  #log_event "info" "Exiting directory_browser ..." "true"

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

  # shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
  source "${SFOLDER}/libs/wordpress_helper.sh"

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

  local oauth_access_token_string oauth_access_token

  oauth_access_token_string+="\n Please, provide a Dropbox Access Token ID.\n"
  oauth_access_token_string+=" 1) Log in: dropbox.com/developers/apps/create\n"
  oauth_access_token_string+=" 2) Click on \"Create App\" and select \"Dropbox API\".\n"
  oauth_access_token_string+=" 3) Choose the type of access you need.\n"
  oauth_access_token_string+=" 4) Enter the \"App Name\".\n"
  oauth_access_token_string+=" 5) Click on the \"Create App\" button.\n"
  oauth_access_token_string+=" 6) Click on the Generate button.\n"
  oauth_access_token_string+=" 7) Copy and paste the new access token here:\n\n"

  oauth_access_token=$(whiptail --title "Dropbox Uploader Configuration" --inputbox "${oauth_access_token_string}" 15 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Write config file
    echo "OAUTH_ACCESS_TOKEN=$oauth_access_token" >${DPU_CONFIG_FILE}
    log_event "info" "Dropbox configuration has been saved!" "false"

  else
    return 1

  fi

}

generate_cloudflare_config() {

  # ${CLF_CONFIG_FILE} is a Global var

  local cfl_email cfl_api_token cfl_email_string cfl_api_token_string

  cfl_email_string="\n\nPlease insert the Cloudflare email account here:\n\n"

  cfl_email=$(whiptail --title "Cloudflare Configuration" --inputbox "${cfl_email_string}" 15 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    echo "dns_cloudflare_email=${cfl_email}">"${CLF_CONFIG_FILE}"

    cfl_api_token_string+= "\n Please insert the Cloudflare Global API Key.\n"
    cfl_api_token_string+=" 1) Log in on: cloudflare.com\n"
    cfl_api_token_string+=" 2) Login and go to \"My Profile\".\n"
    cfl_api_token_string+=" 3) Choose the type of access you need.\n"
    cfl_api_token_string+=" 4) Click on \"API TOKENS\" \n"
    cfl_api_token_string+=" 5) In \"Global API Key\" click on \"View\" button.\n"
    cfl_api_token_string+=" 6) Copy the code and paste it here:\n\n"

    cfl_api_token=$(whiptail --title "Cloudflare Configuration" --inputbox "${cfl_api_token_string}" 15 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Write config file
      echo "dns_cloudflare_api_key=${cfl_api_token}">>"${CLF_CONFIG_FILE}"
      log_event "success" "The Cloudflare configuration has been saved!" "false"

    else
      return 1

    fi

  else
    return 1

  fi

}

generate_telegram_config() {

  # ${TEL_CONFIG_FILE} is a Global var

  local botfather_whip_line botfather_key

  botfather_whip_line+=" \n "
  botfather_whip_line+=" Open Telegram and follow the next steps:\n\n"
  botfather_whip_line+=" 1) Get a bot token. Contact @BotFather (https://t.me/BotFather) and send the command /newbot.\n"
  botfather_whip_line+=" 2) Follow the instructions and paste the token to access the HTTP API:\n\n"

  botfather_key=$(whiptail --title "Telegram BotFather Configuration" --inputbox "${botfather_whip_line}" 15 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Write config file
    echo "botfather_key=${botfather_key}" >>"/root/.telegram.conf"

    telegram_id_whip_line+=" \n\n "
		telegram_id_whip_line+=" 3) Contact the @myidbot (https://t.me/myidbot) bot and send the command /getid to get \n"
		telegram_id_whip_line+=" your personal chat id or invite him into a group and issue the same command to get the group chat id.\n"
		telegram_id_whip_line+=" 4) Paste the ID here:\n\n"
		
		telegram_user_id=$(whiptail --title "Telegram: BotID Configuration" --inputbox "${telegram_id_whip_line}" 15 60 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [[ ${exitstatus} -eq 0 ]]; then

      # Write config file
			echo "telegram_user_id=${telegram_user_id}" >>"/root/.telegram.conf"
      log_event "success" "The Telegram configuration has been saved!" "false"

      # shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
      source "${SFOLDER}/libs/telegram_notification_helper.sh"

      telegram_send_message "✅ ${VPSNAME}: Telegram notifications configured!"

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

  log_event "info" "Calculating disk usage of ${disk_volume}" "false"

  # Need to use grep with -w to exact match of the main volume
  disk_u=$(df -h | grep -w "${disk_volume}" | awk {'print $5'})

  log_event "info" "Disk usage of ${disk_volume}: ${disk_u}" "false"

  # Return
  echo "${disk_u}"

}

check_if_folder_exists() {

  # $1 = ${folder_to_install}
  # $2 = ${domain}

  local folder_to_install=$1
  local domain=$2

  local project_dir="${folder_to_install}/${domain}"
  
  if [ -d "${project_dir}" ]; then

    # Return
    echo "ERROR"

    log_event "info" "Project directory not found on: ${project_dir}" "false"

  else

    # Return
    echo "${project_dir}"

    log_event "info" "Project directory found on: ${project_dir}" "false"

  fi

}

change_ownership(){

  #$1 = ${user}
  #$2 = ${group}
  #$3 = ${path}

  local user=$1
  local group=$2
  local path=$3

  log_event "info" "Running: chown -R ${user}:${group} ${path}" "false"

  chown -R "${user}":"${group}" "${path}"

  #display --indent 2 --text "- Changing ownership of ${path} to ${user}:${group}" --result "DONE" --color GREEN

}

prompt_return_or_finish() {

  log_break "true"

  while true; do
    echo -e "${YELLOW}${ITALIC} > Do you want to return to menu?${ENDCOLOR}"
    read -p "Please type 'y' or 'n'" yn
    case $yn in
      [Yy]*)
        break
        ;;
      [Nn]*)
        echo -e "${B_RED}Exiting script ...${ENDCOLOR}"
        exit 0
        ;;
      *) echo "Please answer yes or no." ;;
    esac
  done

  clear_last_line
  clear_last_line

}

extract () {
  
  # $1 - File to uncompress or extract
  # $2 - Dir to uncompress file
  # $3 - Optional compress-program (ex: lbzip2)

  local file=$1
  local directory=$2
  local compress_type=$3

  log_event "info" "Trying to extract compressed file: ${file}" "false"

    if [ -f "${file}" ]; then
        case "${file}" in
            *.tar.bz2)
              if [ -z "${compress_type}" ]; then
                tar xp "${file}" -C "${directory}" --use-compress-program="${compress_type}"
              else
                tar xjf "${file}" -C "${directory}"
              fi;;

            *.tar.gz)
                tar -xzvf "${file}" -C "${directory}";;

            *.bz2)
                bunzip2 "${file}";;

            *.rar)
                unrar x "${file}";;

            *.gz)
                gunzip "${file}";;

            *.tar)
                tar xf "${file}" -C "${directory}";;

            *.tbz2)
                tar xjf "${file}" -C "${directory}";;

            *.tgz)
                tar xzf "${file}" -C "${directory}";;

            *.zip)
                unzip "${file}";;

            *.Z)
                uncompress "${file}";;

            *.7z)
                7z x "${file}";;

            *.tar.gz)
                tar J "${file}" -C "${directory}";;

            *.xz)
                tar xvf "${file}" -C "${directory}";;

            *)
                echo "${file} cannot be extracted via extract()";;
        esac
    else
        log_event "error" "${file} is not a valid file" "false"
    fi
}

install_crontab_script() {

  # $1 = ${script}
  # $2 = ${scheduled_time}

  local script=$1
  local scheduled_time=$2

  local cron_file

  cron_file="/var/spool/cron/crontabs/root"

  if [ ! -f ${cron_file} ]; then
    log_event "info" "Cron file for root does not exist, creating ..." "false"

	  touch "${cron_file}"
	  /usr/bin/crontab "${cron_file}"

    log_event "success" "Cron file created" "false"

	fi

  grep -qi "${script}" "${cron_file}"
  grep_result=$?
	if [ ${grep_result} != 0 ]; then
    log_event "info" "Updating cron job for script: ${script}" "false"
    /bin/echo "${scheduled_time} ${script}" >> "${cron_file}"
    
  else
    log_event "warning" "Script already installed" "false"

	fi

}

#
#################################################################################
#
# * Ask-for
#
#################################################################################
#

ask_project_state() {

  #$1 = ${state} optional to select default option

  local state=$1

  project_states="prod stage beta test dev"
  project_state=$(whiptail --title "Project State" --menu "Choose a Project State" 20 78 10 $(for x in ${project_states}; do echo "$x [X]"; done) --default-item "${state}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
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

  # TODO: remove some suffix keywords '_com' '_ar' '_es' ... and prefix 'www_'

  project_name=$(whiptail --title "Project Name" --inputbox "Insert a project name (only separator allow is '_'). Ex: my_domain" 10 60 "${name}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
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
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${project_domain}"

  else
    return 1

  fi

}

ask_project_type() {

  local project_types project_type

  project_types="WordPress X Laravel X Basic-PHP X HTML X"
  
  project_type=$(whiptail --title "SELECT PROJECT TYPE" --menu " " 20 78 10 $(for x in ${project_types}; do echo "$x"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Lowercase
    project_type="$(echo "${project_type}" | tr '[A-Z]' '[a-z]')"

    # Return
    echo "${project_type}"

  else
    return 1

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
  if [[ ${exitstatus} -eq 0 ]]; then
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
  if [[ ${exitstatus} -eq 0 ]]; then
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
    
    folder_to_install=$(whiptail --title "Folder to work with" --inputbox "Please select the project folder you want to work with:" 10 60 "${folder_to_install}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_event "info" "Folder to work with: ${folder_to_install}" "false"

      # Return
      echo "${folder_to_install}"

    else
      return 1

    fi

  else

    log_event "info" "Folder to install: ${folder_to_install}" "false"
    
    # Return
    echo "${folder_to_install}"
    
  fi

}

ask_mysql_root_psw() {

  # MPASS is defined globally

  if [[ -z "${MPASS}" ]]; then
    MPASS=$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root Password" 10 60 "${MPASS}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      #echo "> Running: mysql -u root -p${MPASS} -e"
      until mysql -u root -p"${MPASS}" -e ";"; do
        read -s -p " > Can't connect to MySQL, please re-enter $MUSER password: " MPASS
      
      done
      echo "MPASS=${MPASS}" >>/root/.broobe-utils-options

    else
      return 1

    fi
  fi

}

#
#################################################################################
#
# * Help
#
#################################################################################
#

show_help() {

  log_section "Help Menu"
  
  echo -n "./runner.sh [TASK]... [SITE]...

  Options:
    -t, --task        Task to run:
                        project-backup
                        project-restore
                        project-install
                        cloudflare-api
    -s  --site        Site/Domain for tasks execution
    -q, --quiet       Quiet (no output)
    -v, --verbose     Output more information. (Items echoed to 'verbose')
    -d, --debug       Runs script in BASH debug mode (set -x)
    -h, --help        Display this help and exit
        --version     Output version information and exit

  "
}
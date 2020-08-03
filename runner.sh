#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Script Name: LEMP Utils Script
# Version: 3.0-rc07
################################################################################
#
# Style Guide and refs: https://google.github.io/styleguide/shell.xml
#
################################################################################

SCRIPT_V="3.0-rc07"

### Init #######################################################################

SFOLDER="`dirname \"$0\"`" # relative
SFOLDER="`( cd \"$SFOLDER\" && pwd )`"   

if [ -z "$SFOLDER" ]; then
  exit 1  # error; the path is not accessible
fi

chmod +x "${SFOLDER}/libs/commons.sh"
chmod +x "${SFOLDER}/libs/mail_notification_helper.sh"
chmod +x "${SFOLDER}/libs/packages_helper.sh"

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"

### Vars #######################################################################

VPSNAME="$HOSTNAME"

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

# Temp folder
BAKWP="${SFOLDER}/tmp"

# MySQL host and user
MHOST="localhost"
MUSER="root"

### Log #######################################################################
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

echo "                                                 "; 
echo "██████╗ ██████╗  ██████╗  ██████╗ ██████╗ ███████"; 
echo "██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗██╔══██╗██╔══"; 
echo "██████╔╝██████╔╝██║   ██║██║   ██║██████╔╝█████"
echo "██╔══██╗██╔══██╗██║   ██║██║   ██║██╔══██╗██╔"
echo "██████╔╝██║  ██║╚██████╔╝╚██████╔╝██████╔╝███████"
echo "╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚══════"
echo "                                                 "; 

################################################################################

# Status (STATUS_D, STATUS_F, STATUS_S, OUTDATED)
STATUS_D=""
STATUS_F=""
STATUS_S=""
OUTDATED=false

# Backup rotation vars
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

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
export SCRIPT_V VPSNAME BAKWP SFOLDER DPU_F DROPBOX_UPLOADER SITES SITES_BL DB_BL WSERVER PHP_CF LENCRYPT_CF MySQL_CF MYSQL MYSQLDUMP TAR FIND DROPBOX_FOLDER MAILCOW_TMP_BK MHOST MUSER MPASS MAILA NOW NOWDISPLAY ONEWEEKAGO SENDEMAIL TAR DISK_U ONE_FILE_BK IP SMTP_SERVER SMTP_PORT SMTP_TLS SMTP_U SMTP_P STATUS_D STATUS_F STATUS_S OUTDATED LOG BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ENDCOLOR dns_cloudflare_email dns_cloudflare_api_key

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
        # shellcheck source=${SFOLDER}/lemp_setup.sh
        source "${SFOLDER}/lemp_setup.sh"
        exit 1

      else
        script_configuration_wizard "initial"

      fi

    fi

  fi

else
  #cron
  if [[ -z "${MPASS}" || -z "${SMTP_U}" || -z "${SMTP_P}" || -z "${SMTP_TLS}" || -z "${SMTP_PORT}" || -z "${SMTP_SERVER}" || -z "${SMTP_P}" || -z "${MAILA}" || -z "${SITES}" ]]; then
    echo "Some required VARS need to be configured, please run de script manually to configure them." >>$LOG
    exit 1

  fi

fi

### Disk Usage
disk_u=$(calculate_disk_usage "${MAIN_VOL}")

### Creating temporary folders
if [ ! -d "${BAKWP}" ]; then
  mkdir "${BAKWP}"
fi
if [ ! -d "${BAKWP}/${NOW}" ]; then
  mkdir "${BAKWP}/${NOW}"
fi

# Preparing Mail Notifications Template
HTMLOPEN=$(mail_html_start)
BODY_SRV=$(mail_server_status_section "${IP}" "${disk_u}")

if [ -t 1 ]; then

  # Running from terminal
  main_menu

else

  # Running from cron
  log_event "info" "Running from cron ..." "false"
  log_event "info" "Running apt update ..." "false"

  # Update packages index
  apt update

  # Compare package versions
  PKG_DETAILS=$(mail_package_section "${PACKAGES[@]}")
  mail_package_status_section "${PKG_DETAILS}"
  PKG_MAIL="${BAKWP}/pkg-${NOW}.mail"
  PKG_MAIL_VAR=$(<${PKG_MAIL})

  # Check certificates installed
  mail_cert_section
  CERT_MAIL="${BAKWP}/cert-${NOW}.mail"
  CERT_MAIL_VAR=$(<${CERT_MAIL})

  # Running scripts
  "${SFOLDER}/mysql_backup.sh"
  "${SFOLDER}/files_backup.sh"
  "${SFOLDER}/server_and_image_optimizations.sh"
  
  DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
  DB_MAIL_VAR=$(<${DB_MAIL})

  CONFIG_MAIL="${BAKWP}/config-bk-${NOW}.mail"
  CONFIG_MAIL_VAR=$(<${CONFIG_MAIL})

  FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
  FILE_MAIL_VAR=$(<${FILE_MAIL})

  MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

  # Checking result status for mail subject
  EMAIL_STATUS=$(mail_subject_status "${STATUS_D}" "${STATUS_F}" "${STATUS_S}" "${OUTDATED}")

  # Preparing email to send
  log_event "info" "Sending Email to ${MAILA} ..." "true"

  EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Running Complete Backup - [${NOWDISPLAY}]"
  EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

  # Sending email notification
  send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

fi

remove_mail_notifications_files

# Log End
log_event "info" "LEMP UTILS SCRIPT End -- $(date +%Y%m%d_%H%M)" "true"
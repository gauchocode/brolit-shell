#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Script Name: BROOBE Utils Scripts
# Version: 3.0-beta12
################################################################################
#
# TODO: For release 3.0-final
#       1- Complete restore_from_backup and delete_project scripts
#       2- Support for Ubuntu 20.04 LTS
#
# TODO: For release 3.1
#       1- Need to ask for STATUS on files backup (PROD, STAGE, etc)
#       2- On backup failure, the email must show what files fails and what files are correct backuped
#       3- Support for dailys, weeklys y monthlys backups
#       4- Mail notification when a new site is installed
#       5- Warning if script run on non default installation (no webserver or another than nginx)
#       6- Option to install script on crontab
#
# TODO: For release 3.5
#       1- Finish php_optimizations (deprecate Hetzner model mode) and integrate with Lemp Installer
#       2- Expand Duplicity support with a restore option
#       3- Full support for restore server config files
#       4- Rethink server_and_image_optimizations.sh (maybe add a pdf optimization files too)
#       5- MySQL optimization script
#       6- Rename database helper (with and without WP)
#       7- Add some IT utils (change hostname, add floating IP, change SSH port)
#
# TODO: For release 4.0
#       1- Refactor of backups/restore structure, see backup_helper.sh comments
#       2- Uptime Robot API?
#       3- Auto-update script option
#       4- Telegram notifications support: https://adevnull.com/enviar-mensajes-a-telegram-con-bash/
#       5- Better LEMP setup, tzdata y mysql_secure_installation without human intervention
#       6- Hetzner cloud cli support:
#           https://github.com/hetznercloud/cli
#           https://github.com/thabbs/hetzner-cloud-cli-sh
#           https://github.com/thlisym/hetznercloud-py
#           https://hcloud-python.readthedocs.io/en/latest/
#       7- Web GUI:
#           https://github.com/bugy/script-server
#           https://github.com/joewalnes/websocketd
#
################################################################################
#
# Style Guide and refs
#
# https://google.github.io/styleguide/shell.xml
#

SCRIPT_V="3.0-beta12"

### Checking some things...#####################################################
SFOLDER="`dirname \"$0\"`"                                                      # relative
SFOLDER="`( cd \"$SFOLDER\" && pwd )`"   

if [ -z "$SFOLDER" ]; then
  exit 1  # error; the path is not accessible
fi

chmod +x "${SFOLDER}/libs/commons.sh"
chmod +x "${SFOLDER}/libs/mail_notification_helper.sh"
chmod +x "${SFOLDER}/libs/packages_helper.sh"

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/mail_notification_helper.sh"
source "${SFOLDER}/libs/packages_helper.sh"

check_root
check_distro

checking_scripts_permissions

################################################################################

VPSNAME="$HOSTNAME"

# Folder blacklist
SITES_BL=".wp-cli,phpmyadmin,html"

# Database blacklist
DB_BL="information_schema,performance_schema,mysql,sys,phpmyadmin"

# DUPLICITY CONFIG
DUP_BK=false                                  # Duplicity Backups true or false (bool)
DUP_ROOT="/media/backups/PROJECT_NAME_OR_VPS" # Duplicity Backups destination folder
DUP_SRC_BK="/var/www/"                        # Source of Directories to Backup ${SITES}?
DUP_FOLDERS="FOLDER1,FOLDER2"                 # Folders to Backup
DUP_BK_FULL_FREQ="7D"                         # Create a new full backup every ...
DUP_BK_FULL_LIFE="14D"                        # Delete any backup older than this

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
PACKAGES=(linux-firmware dpkg perl nginx php${PHP_V}-fpm mysql-server curl openssl)

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
  source ${DPU_CONFIG_FILE}
else
  generate_dropbox_config
fi

# Cloudflare config file
CLF_CONFIG_FILE=~/.cloudflare.conf
if [[ -e ${CLF_CONFIG_FILE} ]]; then
  source ${CLF_CONFIG_FILE}
else
  generate_cloudflare_config
fi

# BROOBE Utils config file
if test -f /root/.broobe-utils-options; then
  source "/root/.broobe-utils-options"
fi

# Checking required packages to run
check_packages_required

IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

# MySQL
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

# TAR
TAR="$(which tar)"

# EXPORT VARS (GLOBALS)
export SCRIPT_V VPSNAME BAKWP SFOLDER DPU_F SITES SITES_BL DB_BL WSERVER PHP_CF LENCRYPT_CF MySQL_CF MYSQL MYSQLDUMP TAR DROPBOX_FOLDER MAIN_VOL DUP_BK DUP_ROOT DUP_SRC_BK DUP_FOLDERS DUP_BK_FULL_FREQ DUP_BK_FULL_LIFE MAILCOW_TMP_BK MHOST MUSER MPASS MAILA NOW NOWDISPLAY ONEWEEKAGO SENDEMAIL TAR DISK_U ONE_FILE_BK IP SMTP_SERVER SMTP_PORT SMTP_TLS SMTP_U SMTP_P STATUS_D STATUS_F STATUS_S OUTDATED LOG BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ENDCOLOR auth_email auth_key

if [ -t 1 ]; then

  ### Running from terminal

  if [[ -z "${MPASS}" || -z "${SMTP_U}" || -z "${SMTP_P}" || -z "${SMTP_TLS}" || -z "${SMTP_PORT}" || -z "${SMTP_SERVER}" || -z "${SMTP_P}" || -z "${MAILA}" || -z "${SITES}"|| -z "${MAILCOW_BK}" ]]; then

    FIRST_RUN_OPTIONS="01 LEMP_SETUP 02 CONFIGURE_SCRIPT"
    CHOSEN_FR_OPTION=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 $(for x in ${FIRST_RUN_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      if [[ ${CHOSEN_FR_OPTION} == *"01"* ]]; then
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

### Log Start
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="${SFOLDER}/logs"
if [ ! -d "${SFOLDER}/logs" ]; then
  echo " > Folder ${SFOLDER}/logs doesn't exist. Creating now ..."
  mkdir ${SFOLDER}/logs
  echo " > Folder ${SFOLDER}/logs created ..."
fi

LOG_NAME=log_back_${TIMESTAMP}.log
LOG=${PATH_LOG}/${LOG_NAME}

find ${PATH_LOG} -name "*.log" -type f -mtime +7 -print -delete >>$LOG

echo "Backup: Script Start -- $(date +%Y%m%d_%H%M)" >>$LOG

### Disk Usage
calculate_disk_usage

### Creating temporary folders
if [ ! -d "${BAKWP}" ]; then
  echo " > Folder ${BAKWP} doesn't exist. Creating now ..." >>$LOG
  mkdir ${BAKWP}
  echo " > Folder ${BAKWP} created ..." >>$LOG
fi
if [ ! -d "${BAKWP}/${NOW}" ]; then
  echo " > Folder ${BAKWP}/${NOW} doesn't exist. Creating now ..." >>$LOG
  mkdir ${BAKWP}/${NOW}
  echo " > Folder ${BAKWP}/${NOW} created ..." >>$LOG
fi

# Preparing Mail Notifications Template
HTMLOPEN=$(mail_html_start)
BODY_SRV=$(mail_server_status_section "${IP}" "${DISK_U}")

if [ -t 1 ]; then

  # Running from terminal
  main_menu

else

  # Running from cron
  echo " > Running from cron ..." >>${LOG}
  echo " > Running apt update ..." >>${LOG}
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
  ${SFOLDER}/mysql_backup.sh
  ${SFOLDER}/files_backup.sh
  ${SFOLDER}/server_and_image_optimizations.sh
  
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
  echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

  EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Running Complete Backup - [${NOWDISPLAY}]"
  EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

  # Sending email notification
  send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

fi

#remove_mail_notifications_files

echo " > DONE" >>$LOG
echo -e ${B_GREEN}" > DONE"${ENDCOLOR}

# Log End
echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >>$LOG

#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.7
################################################################################
#
# TODO: Para release 3.0
#       1- VAR conf para CloudFlare api -- DONE pero falta TESTING
#       2- VAR conf para Dropbox (pedirlo al inicio y no por el dropbox uploader) -- DONE
#       3- Terminar certbot_manager.sh
#       4- Refactor de menú principal del runner.sh (ojo que si al lemp le activamos netdata o monit, necesita db pass de root)
#       5- VAR conf para el ID de Telegram (quizá habría que guiar todo el proceso)
#       6- Terminar php_optimizations deprecando el modelo de Hetzner e integrandolo al Lemp Installer
#       7- Permitir restore del backup con Duplicity
#       8- Backup y Restore de archivos de Let's Encrypt (/etc/letsencrypt/)
#
################################################################################
#
# TODO: Para release 3.2
#       1- Repensar el server_and_image_optimizations.sh
#       2- Terminar el wordpress_wpcli_helper.sh
#       3- Terminar updater.sh
#       4- phpmyadmin installer
#       5- Optimizaciones de MySQL (instalacion de MySQL 8? https://phoenixnap.com/kb/how-to-install-mysql-on-ubuntu-18-04)
#       6- Corregir el bug que hay en el restore_from_backup.sh con los dominios con guion como (bes-ebike.com)
#       7- Mejorar LEMP setup, para que requiera menos intervencion humana (tzdata y mysql_secure_installation)
#
SCRIPT_V="2.9.7"

### Checking some things...#####################################################
SFOLDER="`dirname \"$0\"`"
SFOLDER="`( cd \"$SFOLDER\" && pwd )`"
if [ -z "$SFOLDER" ] ; then
  # error; the path is not accessible
  exit 1
fi

chmod +x ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/commons.sh

check_root
check_distro

### chmod
chmod +x ${SFOLDER}/mysql_backup.sh
chmod +x ${SFOLDER}/files_backup.sh
chmod +x ${SFOLDER}/lemp_setup.sh
chmod +x ${SFOLDER}/restore_from_backup.sh
chmod +x ${SFOLDER}/server_and_image_optimizations.sh
chmod +x ${SFOLDER}/installers_and_configurators.sh;
chmod +x ${SFOLDER}/utils/bench_scripts.sh
chmod +x ${SFOLDER}/utils/certbot_manager.sh
chmod +x ${SFOLDER}/utils/cloudflare_update_IP.sh
chmod +x ${SFOLDER}/utils/composer_installer.sh
chmod +x ${SFOLDER}/utils/netdata_installer.sh
chmod +x ${SFOLDER}/utils/monit_installer.sh
chmod +x ${SFOLDER}/utils/cockpit_installer.sh
chmod +x ${SFOLDER}/utils/php_optimizations.sh
chmod +x ${SFOLDER}/utils/wordpress_installer.sh
chmod +x ${SFOLDER}/utils/wordpress_migration_from_URL.sh
chmod +x ${SFOLDER}/utils/wordpress_wpcli_helper.sh;
chmod +x ${SFOLDER}/utils/replace_url_on_wordpress_db.sh
chmod +x ${SFOLDER}/utils/blacklist-checker/bl.sh
chmod +x ${SFOLDER}/utils/dropbox-uploader/dropbox_uploader.sh
chmod +x ${SFOLDER}/utils/google-insights-api-tools/gitools.sh
chmod +x ${SFOLDER}/utils/google-insights-api-tools/gitools_v5.sh
################################################################################

VPSNAME="$HOSTNAME"

DPU_F="${SFOLDER}/utils/dropbox-uploader"                                       # Dropbox Uploader Directory

SITES_BL=".wp-cli,phpmyadmin"                                                   # Folder blacklist
DB_BL="information_schema,performance_schema,mysql,sys"                         # Database blacklist

PHP_V=$(php -r "echo PHP_VERSION;" | grep --only-matching --perl-regexp "7.\d+")

WSERVER="/etc/nginx"                                                            # Webserver config files location
MySQL_CF="/etc/mysql"                                                           # MySQL config files location
PHP_CF="/etc/php/${PHP_V}/fpm"                                                  # PHP config files location

### DUPLICITY CONFIG
DUP_BK=false                                                                    # Duplicity Backups true or false (bool)
DUP_ROOT="/media/backups/PROJECT_NAME_OR_VPS"                                   # Duplicity Backups destination folder
DUP_SRC_BK="/var/www/"                                                          # Source of Directories to Backup
DUP_FOLDERS="FOLDER1,FOLDER2"                                                   # Folders to Backup
DUP_BK_FULL_FREQ="7D"                                                           # Create a new full backup every ...
DUP_BK_FULL_LIFE="14D"                                                          # Delete any backup older than this

### PACKAGES TO WATCH
# TODO: poder elejir desde las opciones version de php y motor de base de datos
PACKAGES=(linux-firmware dpkg perl nginx php${PHP_V}-fpm mysql-server curl openssl)

#Main partition
#MAIN_VOL="/dev/sda1"
MAIN_VOL=$(df /boot | grep -Eo '/dev/[^ ]+')

DROPBOX_FOLDER="/"                                                              # Dropbox Folder Backup
DB_BK=true                                                                      # Include database backup?
DEL_UP=true                                                                     # Delete backup files after upload?
BAKWP="${SFOLDER}/tmp"                                                          # Temp folder to store Backups

MHOST="localhost"
MUSER="root"

### Backup rotation vars
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

#Dropbox Uploader config file
DPU_CONFIG_FILE=~/.dropbox_uploader
if [[ -e ${DPU_CONFIG_FILE} ]]; then
  source ${DPU_CONFIG_FILE}

else

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
    echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" > ${DPU_CONFIG_FILE}
    echo -e ${GREEN}" > The configuration has been saved! ..."${ENDCOLOR}

  else
    exit 1

  fi

fi
### Broobe Utils config file
if test -f /root/.broobe-utils-options ; then
  source /root/.broobe-utils-options
fi

### Check if sendemail is installed
SENDEMAIL="$(which sendemail)"
if [ ! -x "${SENDEMAIL}" ]; then
	apt install sendemail libio-socket-ssl-perl
fi

### Check if pv is installed
PV="$(which pv)"
if [ ! -x "${PV}" ]; then
	apt install pv
fi

### MySQL
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### TAR
TAR="$(which tar)"

### Get server IPs
DIG="$(which dig)"
if [ ! -x "${DIG}" ]; then
	apt-get install dnsutils
fi
IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

### EXPORT VARS
export SCRIPT_V VPSNAME BAKWP SFOLDER DPU_F SITES SITES_BL DB_BL WSERVER PHP_CF MHOST MySQL_CF MYSQL MYSQLDUMP TAR DROPBOX_FOLDER MAIN_VOL DUP_BK DUP_ROOT DUP_SRC_BK DUP_FOLDERS DUP_BK_FULL_FREQ DUP_BK_FULL_LIFE MUSER MPASS MAILA NOW NOWDISPLAY ONEWEEKAGO SENDEMAIL TAR DISK_U DEL_UP ONE_FILE_BK IP SMTP_SERVER SMTP_PORT SMTP_TLS SMTP_U SMTP_P LOG BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ENDCOLOR auth_email auth_key

if [ -t 1 ]; then

  ### Running from terminal
  if [[ -z "${MPASS}" || -z "${SMTP_U}" || -z "${SMTP_P}" || -z "${SMTP_TLS}" || -z "${SMTP_PORT}" || -z "${SMTP_SERVER}" || -z "${SMTP_P}" || -z "${MAILA}" || -z "${SITES}" ]]; then

    FIRST_RUN_OPTIONS="01 LEMP_SETUP 02 CONFIGURE_SCRIPT"
    CHOSEN_FR_OPTION=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 `for x in ${FIRST_RUN_OPTIONS}; do echo "$x"; done` 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      if [[ ${CHOSEN_FR_OPTION} == *"01"* ]]; then
        source ${SFOLDER}/lemp_setup.sh;
        exit 1

      else
        if [[ -z "${MPASS}" ]]; then
          MPASS=$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root Password" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            #TODO: testear esto
            until $MYSQL -u $MUSER -p$MPASS  -e ";" ; do
              read -s -p "Can't connect to MySQL, please re-enter $MUSER password: " MPASS
            done
            echo "MPASS="${MPASS} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
        if [[ -z "${SMTP_SERVER}" ]]; then
          SMTP_SERVER=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "SMTP_SERVER="${SMTP_SERVER} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
        if [[ -z "${SMTP_PORT}" ]]; then
          SMTP_PORT=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server Port" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "SMTP_PORT="${SMTP_PORT} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
        if [[ -z "${SMTP_TLS}" ]]; then
          SMTP_TLS=$(whiptail --title "SMTP TLS" --inputbox "SMTP yes or no:" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "SMTP_TLS="${SMTP_TLS} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
        if [[ -z "${SMTP_U}" ]]; then
          SMTP_U=$(whiptail --title "SMTP User" --inputbox "Please insert the SMTP user" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "SMTP_U="${SMTP_U} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
        if [[ -z "${SMTP_P}" ]]; then
          SMTP_P=$(whiptail --title "SMTP Password" --inputbox "Please insert the SMTP user password" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "SMTP_P="${SMTP_P} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
        if [[ -z "${MAILA}" ]]; then
          MAILA=$(whiptail --title "Notification Email" --inputbox "Insert the email where you want to receive notifications." 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "MAILA="${MAILA} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
        if [[ -z "${SITES}" ]]; then
          SITES=$(whiptail --title "Websites Root Directory" --inputbox "Insert the path where websites are stored. Ex: /var/www or /usr/share/nginx" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo "SITES="${SITES} >> /root/.broobe-utils-options
          else
            exit 1
          fi
        fi
      fi
    fi
  fi
else
  #cron
  if [[ -z "${MPASS}" || -z "${SMTP_U}" || -z "${SMTP_P}" || -z "${SMTP_TLS}" || -z "${SMTP_PORT}" || -z "${SMTP_SERVER}" || -z "${SMTP_P}" || -z "${MAILA}" || -z "${SITES}" ]]; then
    echo "Some required VARS need to be configured, please run de script manually to configure them." >> $LOG
    exit 1

  fi

fi

### Log Start
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="${SFOLDER}/logs"
if [ ! -d "${SFOLDER}/logs" ]
then
    echo " > Folder ${SFOLDER}/logs doesn't exist. Creating now ..."
    mkdir ${SFOLDER}/logs
    echo " > Folder ${SFOLDER}/logs created ..."
fi

LOG_NAME=log_back_${TIMESTAMP}.log
LOG=${PATH_LOG}/${LOG_NAME}

find ${PATH_LOG} -name "*.log"  -type f -mtime +7 -print -delete >> $LOG
echo "Backup: Script Start -- $(date +%Y%m%d_%H%M)" >> $LOG

### Disk Usage
DISK_U=$( df -h | grep "${MAIN_VOL}" | awk {'print $5'} )
echo " > Disk usage: ${DISK_U} ..." >> ${LOG}

### Creating temporary folders
if [ ! -d "${BAKWP}" ]
then
    echo " > Folder ${BAKWP} doesn't exist. Creating now ..." >> $LOG
    mkdir ${BAKWP}
    echo " > Folder ${BAKWP} created ..." >> $LOG
fi
if [ ! -d "${BAKWP}/${NOW}" ]
then
    echo " > Folder ${BAKWP}/${NOW} doesn't exist. Creating now ..." >> $LOG
    mkdir ${BAKWP}/${NOW}
    echo " > Folder ${BAKWP}/${NOW} created ..." >> $LOG
fi

### Configure Server Mail Part
SRV_HEADEROPEN='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:#1DC6DF;padding:0 0 10px 10px;width:100%;height:30px">'
SRV_HEADERTEXT="Server Info"
SRV_HEADERCLOSE='</div>'

SRV_HEADER=${SRV_HEADEROPEN}${SRV_HEADERTEXT}${SRV_HEADERCLOSE}

SRV_BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
SRV_CONTENT="<b>Server IP: ${IP}</b><br /><b>Disk usage before the file backup: ${DISK_U}</b>.<br />"
SRV_BODYCLOSE='</div></div>'
SRV_BODY=${SRV_BODYOPEN}${SRV_CONTENT}${SRV_BODYCLOSE}

BODY_SRV=$SRV_HEADER$SRV_BODY

### Configure PKGS Mail Part
if [ "${OUTDATED}" = true ] ; then
	PKG_COLOR='red'
	PKG_STATUS='OUTDATED'
else
	PKG_COLOR='#1DC6DF'
	PKG_STATUS='OK'
fi

PKG_HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
PKG_HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
PKG_HEADEROPEN=${PKG_HEADEROPEN1}${PKG_COLOR}${PKG_HEADEROPEN2}
PKG_HEADERTEXT="Packages Status -> ${PKG_STATUS}"
PKG_HEADERCLOSE='</div>'

PKG_BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
PKG_BODYCLOSE='</div>'

PKG_HEADER=$PKG_HEADEROPEN$PKG_HEADERTEXT$PKG_HEADERCLOSE

PKG_MAIL="${BAKWP}/pkg-${NOW}.mail"
PKG_MAIL_VAR=$(<${PKG_MAIL})

BODY_PKG=${PKG_HEADER}${PKG_BODYOPEN}${PKG_MAIL_VAR}${PKG_BODYCLOSE}

if [ -t 1 ]; then

  ### Running from terminal
  RUNNER_OPTIONS="01 DATABASE_BACKUP 02 FILES_BACKUP 03 WORDPRESS_INSTALLER 04 BACKUP_RESTORE 05 HOSTING_TO_VPS 06 SERVER_OPTIMIZATIONS 07 INSTALLERS_AND_CONFIGS 08 REPLACE_WP_URL 09 WPCLI_HELPER 10 CERTBOT_MANAGER 11 BENCHMARKS 12 GTMETRIX_TEST 13 BLACKLIST_CHECKER 14 RESET_SCRIPT_OPTIONS"
  CHOSEN_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 `for x in ${RUNNER_OPTIONS}; do echo "$x"; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_TYPE} == *"01"* ]]; then
      while true; do
        echo -e ${YELLOW}"> Do you really want to run the database backup?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
            [Yy]* )

  					source ${SFOLDER}/mysql_backup.sh;

  					DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
  					DB_MAIL_VAR=$(<${DB_MAIL})
  					HTMLOPEN='<html><body>'
  					HTMLCLOSE='</body></html>'

            echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

  					sendEmail -f ${SMTP_U} -t ${MAILA} -u "${VPSNAME} - Database Backup - [${NOWDISPLAY} - ${STATUS_D}]" -o message-content-type=html -m "${HTMLOPEN} ${DB_MAIL_VAR} ${HTMLCLOSE}" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P};

  					break;;
            [Nn]* )
  					echo -e ${RED}"Aborting database backup script ..."${ENDCOLOR};
  					break;;
            * ) echo "Please answer yes or no.";;
        esac
      done
    fi
    if [[ ${CHOSEN_TYPE} == *"02"* ]]; then
      while true; do
          echo -e ${YELLOW}"> Do you really want to run the file backup?"${ENDCOLOR}
          read -p "Please type 'y' or 'n'" yn
          case $yn in
              [Yy]* )
    					source ${SFOLDER}/files_backup.sh;
    					FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
    					FILE_MAIL_VAR=$(<$FILE_MAIL)
    					HTMLOPEN='<html><body>'
    					HTMLCLOSE='</body></html>'
    					sendEmail -f ${SMTP_U} -t ${MAILA} -u "${STATUS_ICON_F} ${VPSNAME} - Files Backup [${NOWDISPLAY}]" -o message-content-type=html -m "${HTMLOPEN} ${BODY_SRV} ${BODY_PKG} ${FILE_MAIL_VAR} ${HTMLCLOSE}" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P};
    					break;;
              [Nn]* )
    					echo -e ${RED}"Aborting file backup script ..."${ENDCOLOR};
    					break;;
              * ) echo " > Please answer yes or no.";;
          esac
      done
    fi
    if [[ ${CHOSEN_TYPE} == *"03"* ]]; then
    	source ${SFOLDER}/utils/wordpress_installer.sh;

    fi
    if [[ ${CHOSEN_TYPE} == *"04"* ]]; then
    	source ${SFOLDER}/restore_from_backup.sh;
    fi
    if [[ ${CHOSEN_TYPE} == *"05"* ]]; then
    	while true; do
          echo -e ${YELLOW}"> Do you really want to run the server migration script?"${ENDCOLOR}
          read -p "Please type 'y' or 'n'" yn
    			case $yn in
    					[Yy]* )
    					source ${SFOLDER}/utils/wordpress_migration_from_URL.sh;
    					break;;
    					[Nn]* )
    					echo -e ${RED}"Aborting server migration script ..."${ENDCOLOR};
    					break;;
    					* ) echo " > Please answer yes or no.";;
    			esac
    	done
    fi
    if [[ ${CHOSEN_TYPE} == *"06"* ]]; then
      while true; do
          echo -e ${YELLOW}"> Do you really want to run the optimization script?"${ENDCOLOR}
          read -p "Please type 'y' or 'n'" yn
    			case $yn in
    					[Yy]* )
    					source ${SFOLDER}/server_and_image_optimizations.sh;
    					break;;
    					[Nn]* )
              echo -e ${RED}"Aborting optimization script ..."${ENDCOLOR};
    					break;;
    					* ) echo " > Please answer yes or no.";;
    			esac
    	done

    fi
    if [[ ${CHOSEN_TYPE} == *"07"* ]]; then
      source ${SFOLDER}/installers_and_configurators.sh;

    fi
    if [[ ${CHOSEN_TYPE} == *"08"* ]]; then
      source ${SFOLDER}/utils/replace_url_on_wordpress_db.sh;

    fi
    if [[ ${CHOSEN_TYPE} == *"09"* ]]; then
      source ${SFOLDER}/utils/wordpress_wpcli_helper.sh;

    fi
    if [[ ${CHOSEN_TYPE} == *"10"* ]]; then
      source ${SFOLDER}/utils/certbot_manager.sh;

    fi
    if [[ ${CHOSEN_TYPE} == *"11"* ]]; then
      source ${SFOLDER}/utils/bench_scripts.sh;

    fi
    if [[ ${CHOSEN_TYPE} == *"12"* ]]; then
          URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ ${exitstatus} = 0 ]; then
            source ${SFOLDER}/utils/google-insights-api-tools/gitools_v5.sh gtmetrix ${URL_TO_TEST};
          fi
    fi
    if [[ ${CHOSEN_TYPE} == *"13"* ]]; then
          IP_TO_TEST=$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ ${exitstatus} = 0 ]; then
            source ${SFOLDER}/utils/blacklist-checker/bl.sh ${IP_TO_TEST};
          fi
    fi
    if [[ ${CHOSEN_TYPE} == *"14"* ]]; then
      while true; do
          echo -e ${YELLOW}" > Do you really want to reset the script configuration?"${ENDCOLOR}
          read -p "Please type 'y' or 'n'" yn
          case $yn in
              [Yy]* )
              rm /root/.broobe-utils-options
              rm -fr ${DPU_CONFIG_FILE}
              break;;
              [Nn]* )
              echo -e ${RED}"Aborting ..."${ENDCOLOR};
              break;;
              * ) echo " > Please answer yes or no.";;
          esac
      done
    fi

  else
    exit 1

  fi

else
  ### Running from cron
  echo " > Running from cron ..." >> ${LOG}

  echo " > Running apt update ..." >> ${LOG}
  apt update

  ### Compare package versions
  OUTDATED=false
  echo "" > ${BAKWP}/pkg-${NOW}.mail
  for pk in ${PACKAGES[@]}; do
  	PK_VI=$(apt-cache policy ${pk} | grep Installed | cut -d ':' -f 2)
  	PK_VC=$(apt-cache policy ${pk} | grep Candidate | cut -d ':' -f 2)
  	if [ ${PK_VI} != ${PK_VC} ]; then
  		OUTDATED=true
  		echo " > ${pk} ${PK_VI} -> ${PK_VC} <br />" >> ${BAKWP}/pkg-${NOW}.mail
  	fi
  done

  ${SFOLDER}/mysql_backup.sh;
  ${SFOLDER}/files_backup.sh;
  ${SFOLDER}/server_and_image_optimizations.sh;

  DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
  DB_MAIL_VAR=$(<${DB_MAIL})

  FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
  FILE_MAIL_VAR=$(<${FILE_MAIL})

  HTMLOPEN='<html><body>'
  HTMLCLOSE='</body></html>'

  if [ "${STATUS_D}" = "ERROR" ] || [ "${STATUS_F}" = "ERROR" ]; then
    STATUS="ERROR"
    STATUS_ICON="⛔"
  else
    if [ "${OUTDATED}" = true ] ; then
      STATUS="WARNING"
      STATUS_ICON="⚠"
    else
      STATUS="OK"
      STATUS_ICON="✅"
    fi
  fi
  echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}
  sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${STATUS_ICON} ${VPSNAME} - Complete Backup - [${NOWDISPLAY}]" -o message-content-type=html -m "${HTMLOPEN} ${BODY_SRV} ${BODY_PKG} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${HTMLCLOSE}" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P};

fi

echo " > Removing temp files ..." >> $LOG
echo -e ${YELLOW}" > Removing temp files ..."${ENDCOLOR}

rm ${PKG_MAIL} ${DB_MAIL} ${FILE_MAIL}

echo " > DONE" >> $LOG
echo -e ${GREEN}" > DONE"${ENDCOLOR}

### Log End
echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >> $LOG

#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.9
################################################################################

### Setup Colours
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'
ENDCOLOR='\033[0m'

startdir=""
menutitle="Config Selection Menu"

################################################################################
# MAIN MENU
################################################################################

main_menu() {

  RUNNER_OPTIONS="01 MAKE_A_BACKUP 02 RESTORE_A_BACKUP 03 RESTORE_FROM_SOURCE 04 DELETE_PROJECT 05 WORDPRESS_INSTALLER 06 SERVER_OPTIMIZATIONS 07 INSTALLERS_AND_CONFIGS 08 WPCLI_MANAGER 09 CERTBOT_MANAGER 10 BENCHMARKS 11 GTMETRIX_TEST 12 BLACKLIST_CHECKER 13 RESET_SCRIPT_OPTIONS"
  CHOSEN_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a script to Run" 20 78 10 $(for x in ${RUNNER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_TYPE} == *"01"* ]]; then
      backup_menu

    fi
    if [[ ${CHOSEN_TYPE} == *"02"* ]]; then
      source ${SFOLDER}/restore_from_backup.sh
    fi
    if [[ ${CHOSEN_TYPE} == *"03"* ]]; then
      source ${SFOLDER}/utils/wordpress_restore_from_source.sh

    fi

    if [[ ${CHOSEN_TYPE} == *"04"* ]]; then
      source ${SFOLDER}/delete_project.sh

    fi

    if [[ ${CHOSEN_TYPE} == *"05"* ]]; then
      source ${SFOLDER}/utils/wordpress_installer.sh

    fi
    if [[ ${CHOSEN_TYPE} == *"06"* ]]; then
      while true; do
        echo -e ${YELLOW}"> Do you really want to run the optimization script?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
        [Yy]*)
          source ${SFOLDER}/server_and_image_optimizations.sh
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
    if [[ ${CHOSEN_TYPE} == *"07"* ]]; then
      source ${SFOLDER}/installers_and_configurators.sh

    fi
    if [[ ${CHOSEN_TYPE} == *"08"* ]]; then
      source ${SFOLDER}/utils/wpcli_manager.sh

    fi
    if [[ ${CHOSEN_TYPE} == *"09"* ]]; then
      source ${SFOLDER}/utils/certbot_manager.sh

    fi
    if [[ ${CHOSEN_TYPE} == *"10"* ]]; then
      source ${SFOLDER}/utils/bench_scripts.sh

    fi
    if [[ ${CHOSEN_TYPE} == *"11"* ]]; then
      URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        source ${SFOLDER}/utils/third-party/google-insights-api-tools/gitools_v5.sh gtmetrix ${URL_TO_TEST}
      fi
    fi
    if [[ ${CHOSEN_TYPE} == *"12"* ]]; then
      IP_TO_TEST=$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        source ${SFOLDER}/utils/third-party/blacklist-checker/bl.sh ${IP_TO_TEST}
      fi
    fi
    if [[ ${CHOSEN_TYPE} == *"13"* ]]; then
      while true; do
        echo -e ${YELLOW}" > Do you really want to reset the script configuration?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
        [Yy]*)
          # TODO: acá deberia correr el wizard original y levantar las variables seteadas
          show_script_configuration_wizard
          #rm /root/.broobe-utils-options
          #rm -fr ${DPU_CONFIG_FILE}
          break
          ;;
        [Nn]*)
          echo -e ${RED}"Aborting ..."${ENDCOLOR}
          break
          ;;
        *) echo " > Please answer yes or no." ;;
        esac
      done
    fi

  else
    exit 1

  fi
}

backup_menu() {

  BACKUP_OPTIONS="01 DATABASE_BACKUP 02 FILES_BACKUP 03 BACKUP_ALL"
  CHOSEN_BACKUP_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose a Backup Type to run" 20 78 10 $(for x in ${BACKUP_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  # Preparing Mail Notifications Template
  HTMLOPEN=$(mail_html_start)

  MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_BACKUP_TYPE} == *"01"* ]]; then

      while true; do
        echo -e ${YELLOW}"> Do you really want to run the database backup?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
        [Yy]*)

          source ${SFOLDER}/mysql_backup.sh

          DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
          DB_MAIL_VAR=$(<${DB_MAIL})

          echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

          EMAIL_SUBJECT="${STATUS_ICON_D} ${VPSNAME} - Database Backup - [${NOWDISPLAY}]"
          EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${DB_MAIL_VAR} ${MAIL_FOOTER}"

          # Sending email notification
          send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

          break
          ;;
        [Nn]*)
          echo -e ${RED}"Aborting database backup script ..."${ENDCOLOR}
          break
          ;;
        *) echo "Please answer yes or no." ;;
        esac
      done

    fi
    if [[ ${CHOSEN_BACKUP_TYPE} == *"02"* ]]; then

      while true; do
        echo -e ${YELLOW}"> Do you really want to run the file backup?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
        [Yy]*)

          source ${SFOLDER}/files_backup.sh

          FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
          FILE_MAIL_VAR=$(<$FILE_MAIL)

          echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

          EMAIL_SUBJECT="${STATUS_ICON_F} ${VPSNAME} - Files Backup - [${NOWDISPLAY}]"
          EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

          # Sending email notification
          send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

          break
          ;;
        [Nn]*)
          echo -e ${RED}"Aborting file backup script ..."${ENDCOLOR}
          break
          ;;
        *) echo " > Please answer yes or no." ;;
        esac
      done

    fi
    if [[ ${CHOSEN_BACKUP_TYPE} == *"03"* ]]; then

      while true; do
        echo -e ${YELLOW}"> Do you really want to backup files and databases?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
        [Yy]*)

          # Running scripts
          ${SFOLDER}/mysql_backup.sh
          ${SFOLDER}/files_backup.sh

          DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
          DB_MAIL_VAR=$(<${DB_MAIL})

          FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
          FILE_MAIL_VAR=$(<${FILE_MAIL})

          MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

          # Checking result status for mail subject
          EMAIL_STATUS=$(mail_subject_status "${STATUS_D}" "${STATUS_F}" "${OUTDATED}")

          echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

          EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Running Complete Backup - [${NOWDISPLAY}]"
          EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${BODY_PKG} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

          # Sending email notification
          send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

          break
          ;;
        [Nn]*)
          echo -e ${RED}"Aborting file backup script ..."${ENDCOLOR}
          break
          ;;
        *) echo " > Please answer yes or no." ;;
        esac

      done

    fi

  fi

}

show_script_configuration_wizard() {

  ask_mysql_root_psw

  if [[ -z "${SMTP_SERVER}" ]]; then
    SMTP_SERVER=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server" 10 60 "${SMTP_SERVER}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_SERVER="${SMTP_SERVER} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_PORT}" ]]; then
    SMTP_PORT=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server Port" 10 60 "${SMTP_PORT}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_PORT="${SMTP_PORT} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_TLS}" ]]; then
    SMTP_TLS=$(whiptail --title "SMTP TLS" --inputbox "SMTP yes or no:" 10 60 "${SMTP_TLS}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_TLS="${SMTP_TLS} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_U}" ]]; then
    SMTP_U=$(whiptail --title "SMTP User" --inputbox "Please insert the SMTP user" 10 60 "${SMTP_U}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_U="${SMTP_U} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SMTP_P}" ]]; then
    SMTP_P=$(whiptail --title "SMTP Password" --inputbox "Please insert the SMTP user password" 10 60 "${SMTP_P}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SMTP_P="${SMTP_P} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${MAILA}" ]]; then
    MAILA=$(whiptail --title "Notification Email" --inputbox "Insert the email where you want to receive notifications." 10 60 "${MAILA}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "MAILA="${MAILA} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi
  if [[ -z "${SITES}" ]]; then
    SITES=$(whiptail --title "Websites Root Directory" --inputbox "Insert the path where websites are stored. Ex: /var/www or /usr/share/nginx" 10 60 "${SITES}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "SITES="${SITES} >>/root/.broobe-utils-options
    else
      exit 1
    fi
  fi

}

################################################################################
# CHECKERS
################################################################################

check_root() {
  if [ ${USER} != root ]; then
    echo -e ${RED}" > Error: must be root! Exiting..."${ENDCOLOR}
    exit 0
  fi
}

check_distro() {
  # Running Ubuntu?
  DISTRO=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')
  if [ ! "$DISTRO" = "Ubuntu" ]; then
    echo " > ERROR: This script only run on Ubuntu ... Exiting"
    exit 1
  else
    echo "Setting DISTRO="$DISTRO
    MIN_V=$(echo "16.04" | awk -F "." '{print $1$2}')
    DISTRO_V=$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $2}' | awk -F "." '{print $1$2}')
    if [ ! "$DISTRO_V" -ge "$MIN_V" ]; then
      echo -e ${RED}" > ERROR: Ubuntu version must  >= 16.04 ... Exiting"${ENDCOLOR}
      exit 1
    fi
  fi
}

checking_scripts_permissions() {
  ### chmod
  find ./ -name "*.sh" -exec chmod +x {} \;

}

################################################################################
# VALIDATORS
################################################################################

is_domain_format_valid() {
  object_name=${2-domain}
  exclude="[!|@|#|$|^|&|*|(|)|+|=|{|}|:|,|<|>|?|_|/|\|\"|'|;|%|\`| ]"
  if [[ $1 =~ $exclude ]] || [[ $1 =~ ^[0-9]+$ ]] || [[ $1 =~ "\.\." ]] || [[ $1 =~ "$(printf '\t')" ]]; then
    check_result $E_INVALID "invalid $object_name format :: $1"
  fi
}

is_ip_format_valid() {
  object_name=${2-ip}
  ip_regex='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
  ip_clean=$(echo "${1%/*}")
  if ! [[ $ip_clean =~ ^$ip_regex\.$ip_regex\.$ip_regex\.$ip_regex$ ]]; then
    check_result $E_INVALID "invalid $object_name format :: $1"
  fi
  if [ $1 != "$ip_clean" ]; then
    ip_cidr="$ip_clean/"
    ip_cidr=$(echo "${1#$ip_cidr}")
    if [[ "$ip_cidr" -gt 32 ]] || [[ "$ip_cidr" =~ [:alnum:] ]]; then
      check_result $E_INVALID "invalid $object_name format :: $1"
    fi
  fi
}

is_email_format_valid() {
  if [[ ! "$1" =~ ^[A-Za-z0-9._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,63}$ ]]; then
    check_result $E_INVALID "invalid email format :: $1"
  fi
}

################################################################################
# HELPERS
################################################################################

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

    echo "dns_cloudflare_email=$CFL_EMAIL" >${CLF_CONFIG_FILE}

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
      echo "dns_cloudflare_api_key=$GLOBAL_API_TOKEN" >>${CLF_CONFIG_FILE}
      echo -e ${GREEN}" > The cloudflare configuration has been saved! ..."${ENDCOLOR}

    else
      exit 1

    fi

  else
    exit 1

  fi

}

calculate_disk_usage() {

  DISK_U=$(df -h | grep "${MAIN_VOL}" | awk {'print $5'})
  echo " > Disk usage: ${DISK_U} ..." >>${LOG}

}

################################################################################
# WP HELPERS
################################################################################

wp_download_wordpress() {

  echo "Trying to make a clean install of Wordpress ..." >>$LOG
  echo -e ${YELLOW}"Trying to make a clean install of Wordpress ..."${ENDCOLOR}
  cd ${FOLDER_TO_INSTALL}
  curl -O https://wordpress.org/latest.tar.gz
  tar -xzxf latest.tar.gz
  rm latest.tar.gz
  mv wordpress ${DOMAIN}
  cd ${DOMAIN}
  cp wp-config-sample.php ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php
  rm ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config-sample.php

}

# Used in:
# restore_from_backup.sh
# wordpress_installer.sh
wp_change_ownership() {

  # $1 = ${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT} or ${FOLDER_TO_INSTALL}/${DOMAIN}

  PROJECT_DIR=$1

  echo "Changing folder owner to www-data ..." >>$LOG
  echo -e ${YELLOW}"Changing '${PROJECT_DIR}' owner to www-data ..."${ENDCOLOR}

  chown -R www-data:www-data ${PROJECT_DIR}
  find ${PROJECT_DIR} -type d -exec chmod g+s {} \;
  chmod g+w ${PROJECT_DIR}/wp-content
  chmod -R g+w ${PROJECT_DIR}/wp-content/themes
  chmod -R g+w ${PROJECT_DIR}/wp-content/plugins

  echo " > DONE" >>$LOG
  echo -e ${GREEN}" > DONE"${ENDCOLOR}
}

# Used in:
# wordpress_installer.sh
# TODO: ver como hacer eso independientemente del idioma
wp_set_salts() {
  # English
  perl -i -pe'
    BEGIN {
      @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
      push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
      sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/put your unique phrase here/salt()/ge
  ' ${WPCONFIG}
  # Spanish
  perl -i -pe'
    BEGIN {
      @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
      push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
      sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/pon aquí tu frase aleatoria/salt()/ge
  ' ${WPCONFIG}
}

# Used in:
# restore_from_backup.sh
# wordpress_installer.sh
wp_database_creation() {

  if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${PROJECT_NAME}_user';" | $MYSQL -u ${MUSER} --password=${MPASS} | grep 1 &>/dev/null; then

    DB_PASS=$(openssl rand -hex 12)

    SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
    SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
    SQL4="FLUSH PRIVILEGES;"

    echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} ..."${ENDCOLOR}
    echo " > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} ..." >>$LOG

    $MYSQL -u ${MUSER} --password=${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}"

    if [ $? -eq 0 ]; then
      echo " > DONE!" >>$LOG
      echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
      echo " > Something went wrong!" >>$LOG
      echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
      exit 1
    fi

    echo -e ${YELLOW}" > Changing wp-config.php database parameters ..."${ENDCOLOR}
    sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASS}'/2" ${WPCONFIG}

  else
    echo " > User: ${PROJECT_NAME}_user already exist. Continue ..." >>$LOG

    SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
    SQL2="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
    SQL3="FLUSH PRIVILEGES;"

    echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and granting privileges to user: ${PROJECT_NAME}_user ..."${ENDCOLOR}

    $MYSQL -u ${MUSER} --password=${MPASS} -e "${SQL1}${SQL2}${SQL3}"

    if [ $? -eq 0 ]; then
      echo " > DONE!" >>$LOG
      echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
      echo " > Something went wrong!" >>$LOG
      echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
      exit 1
    fi

    echo -e ${YELLOW}" > Changing wp-config.php database parameters ..."${ENDCOLOR}
    echo -e ${YELLOW}" > Leaving DB_USER untouched ..."${ENDCOLOR}

  fi

  sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" ${WPCONFIG}
  sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_${PROJECT_STATE}'/2" ${WPCONFIG}
  sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" ${WPCONFIG}

}

################################################################################
# ASK-FOR
################################################################################

# Used in:
# restore_from_backup.sh
# wordpress_installer.sh
ask_project_state() {

  PROJECT_STATES="prod stage test dev"
  PROJECT_STATE=$(whiptail --title "PROJECT STATE" --menu "Choose a Project State" 20 78 10 $(for x in ${PROJECT_STATES}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo -e ${YELLOW}"Project state selected: ${PROJECT_STATE} ..."${ENDCOLOR}

  else
    exit 1
  fi

}

ask_project_name() {

  PROJECT_NAME=$(whiptail --title "Project Name" --inputbox "Please insert a project name. Example: broobe" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "Setting PROJECT_NAME="${PROJECT_NAME} >>$LOG
  else
    exit 1
  fi

}

ask_folder_to_install_sites() {

  if [[ -z "${FOLDER_TO_INSTALL}" ]]; then
    FOLDER_TO_INSTALL=$(whiptail --title "Folder to install" --inputbox "Please insert the full path where you want to install the site:" 10 60 "/var/www" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "FOLDER_TO_INSTALL="${FOLDER_TO_INSTALL}
      echo "FOLDER_TO_INSTALL="${FOLDER_TO_INSTALL} >>$LOG
    else
      exit 0
    fi
  fi

}

ask_mysql_root_psw() {

  if [[ -z "${MPASS}" ]]; then
    MPASS=$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root Password" 10 60 "${MPASS}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      #TODO: testear esto
      until $MYSQL -u $MUSER -p$MPASS -e ";"; do
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

    echo "Setting existing_URL="${existing_URL} >>$LOG

    if [ ${exitstatus} = 0 ]; then

      if [[ -z "${new_URL}" ]]; then
        new_URL=$(whiptail --title "THE NEW URL" --inputbox "Insert the new URL , including http:// or https://" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ ${exitstatus} = 0 ]; then

          echo "Setting new_URL="${new_URL} >>$LOG

          wpcli_search_and_replace "${WP_PATH}" "${existing_URL}" "${new_URL}"

        fi

      fi

    fi

  fi

}

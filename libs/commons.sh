#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.7
################################################################################

# TODO: refactor para seguir el code style "function_name ()"

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

checking_scripts_permissions() {
  ### chmod
  chmod +x ${SFOLDER}/mysql_backup.sh
  chmod +x ${SFOLDER}/files_backup.sh
  chmod +x ${SFOLDER}/lemp_setup.sh
  chmod +x ${SFOLDER}/restore_from_backup.sh
  chmod +x ${SFOLDER}/server_and_image_optimizations.sh
  chmod +x ${SFOLDER}/installers_and_configurators.sh
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
  chmod +x ${SFOLDER}/utils/wordpress_wpcli_helper.sh
  chmod +x ${SFOLDER}/utils/replace_url_on_wordpress_db.sh
  chmod +x ${SFOLDER}/utils/blacklist-checker/bl.sh
  chmod +x ${SFOLDER}/utils/dropbox-uploader/dropbox_uploader.sh
  chmod +x ${SFOLDER}/utils/google-insights-api-tools/gitools.sh
  chmod +x ${SFOLDER}/utils/google-insights-api-tools/gitools_v5.sh

}

check_packages_required() {
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

  ### Get server IPs
  DIG="$(which dig)"
  if [ ! -x "${DIG}" ]; then
    apt-get install dnsutils
  fi

}

compare_package_versions() {
  OUTDATED=false
  #echo "" >${BAKWP}/pkg-${NOW}.mail
  for pk in ${PACKAGES[@]}; do
    PK_VI=$(apt-cache policy ${pk} | grep Installed | cut -d ':' -f 2)
    PK_VC=$(apt-cache policy ${pk} | grep Candidate | cut -d ':' -f 2)
    if [ ${PK_VI} != ${PK_VC} ]; then
      OUTDATED=true
      # TODO: meterlo en un array para luego loopear
      #echo " > ${pk} ${PK_VI} -> ${PK_VC} <br />" >>${BAKWP}/pkg-${NOW}.mail
    fi
  done

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

  echo "Changing folder owner to www-data ..." >>$LOG
  echo -e ${YELLOW}"Changing '${FOLDER_TO_INSTALL}/${DOMAIN}' owner to www-data ..."${ENDCOLOR}

  chown -R www-data:www-data ${FOLDER_TO_INSTALL}/${DOMAIN}
  find ${FOLDER_TO_INSTALL}/${DOMAIN} -type d -exec chmod g+s {} \;
  chmod g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content
  chmod -R g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content/themes
  chmod -R g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content/plugins

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

    # HELPERS
    # para cambiar pass de un user existente
    # ALTER USER '_user'@'localhost' IDENTIFIED BY 'dadsada=';
    # para borrar usuario existente
    # DROP USER 'basfpoliuretanos_user'@'localhost';

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

# Used in:
# restore_from_backup.sh
# wordpress_installer.sh
choose_project_state() {
  PROJECT_STATES="prod stage test dev"
  PROJECT_STATE=$(whiptail --title "PROJECT STATE" --menu "Chose a Project State" 20 78 10 $(for x in ${PROJECT_STATES}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo -e ${YELLOW}"Project state selected: ${PROJECT_STATE} ..."${ENDCOLOR}

  else
    exit 1
  fi
}

folder_to_install_sites() {
  if [[ -z "${FOLDER_TO_INSTALL}" ]]; then
    FOLDER_TO_INSTALL=$(whiptail --title "Folder to install Sites" --inputbox "Please insert a folder to restore the backup files." 10 60 "/var/www" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "FOLDER_TO_INSTALL="${FOLDER_TO_INSTALL} >>$LOG
    else
      exit 0
    fi
  fi
}

Filebrowser() {
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

Directorybrowser() {
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

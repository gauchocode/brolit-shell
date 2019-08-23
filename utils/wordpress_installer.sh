#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.7
################################################################################
#
# https://github.com/AbhishekGhosh/Ubuntu-16.04-Nginx-WordPress-Autoinstall-Bash-Script/
# https://alonganon.info/2018/11/17/make-a-super-fast-and-lightweight-wordpress-on-ubuntu-18-04-with-php-7-2-nginx-and-mariadb/
#
################################################################################
SCRIPT_V="2.9.7"

# TODO: esto necesita un fuerte refactor, re-utilizar funciones que ya estan en los otros Scripts,
# y checkear que falla cuando ponemos www.DOMINIO.com y luego seleccionamos un stage distinto a prod.
#
#
# TODO: checkear si se trata de un multisite, para eso ver los siguientes
# define del wp-config.php:
#
# define('MULTISITE', true);
# define('SUBDOMAIN_INSTALL', false);
# define('DOMAIN_CURRENT_SITE', 'borealtech.com');
# define('PATH_CURRENT_SITE', '/');
# define('SITE_ID_CURRENT_SITE', 1);
#
### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mail_notification_helper.sh
source ${SFOLDER}/libs/mysql_helper.sh

#source ${SFOLDER}/utils/certbot_manager.sh

################################################################################

# Installation types
INSTALLATION_TYPES="CLEAN_INSTALL COPY_FROM_PROJECT"

INSTALLATION_TYPE=$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 `for x in ${INSTALLATION_TYPES}; do echo "$x [X]"; done` 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  ask_folder_to_install_sites

  if [[ ${INSTALLATION_TYPE} == *"COPY"* ]]; then

    startdir=${FOLDER_TO_INSTALL}
    menutitle="Site Selection Menu"
    directory_browser "$menutitle" "$startdir"
    COPY_PROJECT_PATH=$filepath"/"$filename
    echo "Setting COPY_PROJECT_PATH="${COPY_PROJECT_PATH}

    COPY_PROJECT=$(basename $COPY_PROJECT_PATH)
    echo "Setting COPY_PROJECT="${COPY_PROJECT}

    DOMAIN=$(whiptail --title "Domain" --inputbox "Insert the domain of the Project. Example: landing.broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      if [ -d "${FOLDER_TO_INSTALL}/${DOMAIN}" ]; then
          echo -e ${RED}"ERROR: Destination folder already exist, aborting ..."${ENDCOLOR}
          exit 1
      else
        echo "Setting DOMAIN="${DOMAIN} >> $LOG
      fi

    else
      exit 1
    fi
    ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "Setting ROOT_DOMAIN="${ROOT_DOMAIN} >> $LOG
    else
      exit 1
    fi
    
    ask_project_name

    ask_project_state

    echo "Trying to make a copy of ${COPY_PROJECT} ..." >> $LOG
    echo -e ${YELLOW}"Trying to make a copy of ${COPY_PROJECT} ..."${ENDCOLOR}

    cd ${FOLDER_TO_INSTALL}
    cp -r ${FOLDER_TO_INSTALL}/${COPY_PROJECT} ${FOLDER_TO_INSTALL}/${DOMAIN}

    echo "DONE" >> $LOG

  else

    DOMAIN=$(whiptail --title "Domain" --inputbox "Insert the domain of the Project. Example: landing.broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "Setting DOMAIN="${DOMAIN}

      ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo "Setting ROOT_DOMAIN="${ROOT_DOMAIN}

        PROJECT_NAME=$(whiptail --title "Project Name" --inputbox "Please insert a project name. Example: broobe" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then
          echo "Setting PROJECT_NAME="${PROJECT_NAME}

          ask_project_state

        else
          exit 1
        fi

      else
        exit 1
      fi

    else
      exit 1
    fi

    if [ -d "${FOLDER_TO_INSTALL}/${DOMAIN}" ]; then
      echo "ERROR: Destination folder already exist, aborting ..." >> $LOG
      echo -e ${RED}"ERROR: Destination folder already exist, aborting ..."${ENDCOLOR}
      exit 1

    fi

    wp_download_wordpress

  fi

  wp_change_ownership

  WPCONFIG=${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php

  # Create database and user
  wp_database_creation

  # Set WP salts
  wp_set_salts

  if [[ ${INSTALLATION_TYPE} == *"COPY"* ]]; then

    echo " > Copying database ...">> $LOG
    echo -e ${YELLOW}" > Copying database ..."${ENDCOLOR}
    ### Create dump file
    BK_FOLDER=${SFOLDER}/tmp/
    ### We get the database name from the copied wp-config.php
    SOURCE_WPCONFIG=${FOLDER_TO_INSTALL}/${COPY_PROJECT}
    DB_TOCOPY=`cat ${SOURCE_WPCONFIG}/wp-config.php | grep DB_NAME | cut -d \' -f 4`
    BK_FILE="db-${DB_TOCOPY}.sql"
    $MYSQLDUMP --max-allowed-packet=1073741824  -u ${MUSER} -p${MPASS} ${DB_TOCOPY} > ${BK_FOLDER}${BK_FILE}

    if [ "$?" -eq 0 ]; then

      echo " > mysqldump for ${DB_TOCOPY} OK ...">> $LOG
      echo -e ${GREEN}" > mysqldump for ${DB_TOCOPY} OK ..."${ENDCOLOR}
      echo " > Trying to restore database ...">> $LOG
      echo -e ${YELLOW}" > Trying to restore database ..."${ENDCOLOR}

      $MYSQL -u ${MUSER} --password=${MPASS} ${PROJECT_NAME}_${PROJECT_STATE} < ${BK_FOLDER}${BK_FILE}

      TARGET_DB=${PROJECT_NAME}_${PROJECT_STATE}
      ### OJO: heredamos el prefijo de la base copiada y no la reemplazamos.
      ### Ref: https://www.cloudways.com/blog/change-wordpress-database-table-prefix-manually/
      ### Cuando se implemento eso, debemos obtener el prefijo para la config de wp así:
      ### DB_PREFIX=$(cat ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php | grep "\$table_prefix" | cut -d \' -f 2)
      DB_PREFIX=$(cat ${FOLDER_TO_INSTALL}/${COPY_PROJECT}/wp-config.php | grep "\$table_prefix" | cut -d \' -f 2)

      ### TODO:
      ### echo "Changing database prefix on wp-config.php ..."
      export existing_URL new_URL MUSER MPASS TARGET_DB DB_PREFIX
      ${SFOLDER}/utils/replace_url_on_wordpress_db.sh

    else

      echo " > mysqldump ERROR: $? ...">> $LOG
      echo -e ${RED}" > mysqldump ERROR: $? ..."${ENDCOLOR}
      echo -e ${RED}" > Aborting ..."${ENDCOLOR}
      exit 1

    fi

  fi

  # Cloudflare API to change DNS records
  echo "Trying to access Cloudflare API and change record ${DOMAIN} ...">> $LOG
  echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${DOMAIN} ..."${ENDCOLOR}

  zone_name=${ROOT_DOMAIN}
  record_name=${DOMAIN}
  export zone_name record_name
  ${SFOLDER}/utils/cloudflare_update_IP.sh

  # TODO: que pasa si en vez de generarlo a partir de un template de conf de nginx, copio el del proyecto y reemplazo el dominio?

  # New site Nginx configuration
  echo " > Trying to generate nginx config for ${DOMAIN} ...">> $LOG
  echo -e ${YELLOW}" > Trying to generate nginx config for ${DOMAIN} ..."${ENDCOLOR}

  cp ${SFOLDER}/confs/nginx/sites-available/default /etc/nginx/sites-available/${DOMAIN}
  ln -s /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}
  # Replacing string to match domain name
  sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}
  # Need to run twice
  sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}
  # Restart nginx service
  service nginx reload

  echo " > DONE">> $LOG
  echo -e ${GREEN}" > DONE! Now you can run the certbot."${ENDCOLOR}

  # HTTPS with Certbot
  ${SFOLDER}/utils/certbot_manager.sh
  #certbot_certificate_install "${MAILA}" "${DOMAIN}"

fi

main_menu
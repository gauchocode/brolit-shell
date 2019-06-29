#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
#############################################################################
#
# https://github.com/AbhishekGhosh/Ubuntu-16.04-Nginx-WordPress-Autoinstall-Bash-Script/
# https://alonganon.info/2018/11/17/make-a-super-fast-and-lightweight-wordpress-on-ubuntu-18-04-with-php-7-2-nginx-and-mariadb/
#
#############################################################################
SCRIPT_V="2.9"

### Folders Setup
FOLDER_TO_INSTALL="/var/www"

### Checking some things
if [ $USER != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
if [[ -z "${SFOLDER}" || -z "${MPASS}" ]]; then
  echo -e ${RED}" > Error: SFOLDER and MPASS must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

echo -e ${RED}"SFOLDER: ${SFOLDER}"${ENDCOLOR}
echo -e ${RED}"MPASS: ${MPASS}"${ENDCOLOR}

# Installation types
INSTALLATION_TYPES="CLEAN_INSTALL COPY_FROM_PROJECT"

INSTALLATION_TYPE=$(whiptail --title "INSTALLATION TYPE" --menu "Chose an Installation Type" 20 78 10 `for x in ${INSTALLATION_TYPES}; do echo "$x [X]"; done` 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${INSTALLATION_TYPE} == *"COPY"* ]]; then

    COPY_PROJECT=$(whiptail --title "Project to Copy" --inputbox "Insert the domain of the project you want to copy. Example: dev.broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "Setting COPY_PROJECT="${COPY_PROJECT}
    else
      exit 1
    fi

    DOMAIN=$(whiptail --title "Domain" --inputbox "Insert the domain of the Project. Example: landing.broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      if [ -d "${FOLDER_TO_INSTALL}/${DOMAIN}" ]; then
          echo -e ${RED}"ERROR: Destination folder already exist, aborting ..."${ENDCOLOR}
          exit 1
      else
        echo "Setting DOMAIN="${DOMAIN}
      fi

    else
      exit 1
    fi
    ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "Setting ROOT_DOMAIN="${ROOT_DOMAIN}
    else
      exit 1
    fi
    PROJECT_NAME=$(whiptail --title "Project Name" --inputbox "Please insert a project name. Example: broobe" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "Setting PROJECT_NAME="${PROJECT_NAME}
    else
      exit 1
    fi
    PROJECT_STATES="prod stage test dev"
    PROJECT_STATE=$(whiptail --title "PROJECT STATE" --menu "Chose a Project State" 20 78 10 `for x in ${PROJECT_STATES}; do echo "$x [X]"; done` 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo -e ${YELLOW}"Project state selected: ${PROJECT_STATE} ..."${ENDCOLOR}
    else
      exit 1
    fi

    echo -e ${YELLOW}"Trying to make a copy of ${COPY_PROJECT} ..."${ENDCOLOR}
    cd ${FOLDER_TO_INSTALL}
    cp -r ${FOLDER_TO_INSTALL}/${COPY_PROJECT} ${FOLDER_TO_INSTALL}/${DOMAIN}

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

          PROJECT_STATES="prod stage test dev"
          PROJECT_STATE=$(whiptail --title "PROJECT STATE" --menu "Chose a Project State" 20 78 10 `for x in ${PROJECT_STATES}; do echo "$x [X]"; done` 3>&1 1>&2 2>&3)
          exitstatus=$?
          if [ $exitstatus = 0 ]; then
            echo -e ${YELLOW}"Project state selected: ${PROJECT_STATE} ..."${ENDCOLOR}

          else
            exit 1
          fi

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
        echo -e ${RED}"ERROR: Destination folder already exist, aborting ..."${ENDCOLOR}
        exit 1

    fi

    echo -e ${YELLOW}"Trying to make a clean install of Wordpress ..."${ENDCOLOR}
    cd ${FOLDER_TO_INSTALL}
    curl -O https://wordpress.org/latest.tar.gz
    tar -xzxf latest.tar.gz
    rm latest.tar.gz
    mv wordpress ${DOMAIN}
    cd ${DOMAIN}
    cp wp-config-sample.php ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php
    rm ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config-sample.php

  fi

  chown -R www-data:www-data ${FOLDER_TO_INSTALL}/${DOMAIN}
  find ${FOLDER_TO_INSTALL}/${DOMAIN} -type d -exec chmod g+s {} \;
  chmod g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content
  chmod -R g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content/themes
  chmod -R g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content/plugins

  # wp-cli
  #curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  #chmod +x wp-cli.phar
  #move it to /usr/local/bin so that it can be run directly
  #sudo mv wp-cli.phar /usr/local/bin/wp
  #sudo -u www-data wp plugin install wordpress-seo

  echo -e ${GREEN}" > DONE"${ENDCOLOR}

  WPCONFIG=${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php

  if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${PROJECT_NAME}_user';" | mysql -u root --password=${MPASS} | grep 1 &> /dev/null; then

    DB_PASS=$(openssl rand -hex 12)

    #para cambiar pass de un user existente
    #ALTER USER '_user'@'localhost' IDENTIFIED BY 'dadsada=';
    SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
    SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
    SQL4="FLUSH PRIVILEGES;"

    echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} ..."${ENDCOLOR}
    mysql -u root --password=${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}"

    echo -e ${GREEN}" > DONE"${ENDCOLOR}

    echo -e ${YELLOW}" > Changing wp-config.php database parameters ..."${ENDCOLOR}
    sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASS}'/2" ${WPCONFIG}

  else
      echo " > User: ${PROJECT_NAME}_user already exist. Continue ..." >> $LOG

      SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
      SQL2="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
      SQL3="FLUSH PRIVILEGES;"

      echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and granting privileges to user: ${PROJECT_NAME}_user ..."${ENDCOLOR}
      mysql -u root --password=${MPASS} -e "${SQL1}${SQL2}${SQL3}"

      echo -e ${GREEN}" > DONE"${ENDCOLOR}

      echo -e ${YELLOW}" > Changing wp-config.php database parameters ..."${ENDCOLOR}
      echo -e ${YELLOW}" > Leaving DB_USER untouched ..."${ENDCOLOR}

  fi

  sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" ${WPCONFIG}
  sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_${PROJECT_STATE}'/2" ${WPCONFIG}
  sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" ${WPCONFIG}

  # Set WP salts
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

  if [[ ${INSTALLATION_TYPE} == *"COPY"* ]]; then
    echo -e ${YELLOW}" > Copying database ..."${ENDCOLOR}
    ### Create dump file###
    BK_FOLDER=${SFOLDER}/tmp/
    ### We get the database name from the copied wp-config.php
    SOURCE_WPCONFIG=${FOLDER_TO_INSTALL}/${COPY_PROJECT}
    DB_TOCOPY=`cat ${SOURCE_WPCONFIG}/wp-config.php | grep DB_NAME | cut -d \' -f 4`
    BK_FILE="db-${DB_TOCOPY}.sql"
    $MYSQLDUMP --max-allowed-packet=1073741824  -u root -p${MPASS} ${DB_TOCOPY} > ${BK_FOLDER}${BK_FILE}
    if [ "$?" -eq 0 ]
    then
        echo -e ${GREEN}" > Mysqldump OK ..."${ENDCOLOR}
        echo -e ${YELLOW}" > Trying to restore database ..."${ENDCOLOR}
        mysql -u root --password=${MPASS} ${PROJECT_NAME}_${PROJECT_STATE} < ${BK_FOLDER}${BK_FILE}

        echo -e ${YELLOW}" > Replacing URLs on the new database ..."${ENDCOLOR}
        MUSER="root"
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
        echo -e ${RED}" > Mysqldump ERROR: $? ..."${ENDCOLOR}
        echo -e ${RED}" > Aborting ..."${ENDCOLOR}
        exit 1
    fi

  fi

  # Cloudflare API to change DNS records
  echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${DOMAIN} ..."${ENDCOLOR}  >> $LOG
  zone_name=${ROOT_DOMAIN}
  record_name=${DOMAIN}
  export zone_name record_name
  ${SFOLDER}/utils/cloudflare_update_IP.sh

  # New site Nginx configuration
  echo -e ${YELLOW}" > Trying to generate nginx config for ${DOMAIN} ..."${ENDCOLOR}
  cp ${SFOLDER}/confs/default /etc/nginx/sites-available/${DOMAIN}
  ln -s /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}
  # Replacing string to match domain name
  sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}
  # Need to run twice
  sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}
  # Restart nginx service
  service nginx reload

  echo -e ${GREEN}" > Everything is DONE! ..."${ENDCOLOR}

  # HTTPS with Certbot
  #echo -e ${YELLOW}" > Trying to execute certbot for ${CHOSEN_PROJECT} ..."${ENDCOLOR}
  # TODO: certbot --nginx -d ${CHOSEN_PROJECT} -d www.${CHOSEN_PROJECT}
  #certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}

fi

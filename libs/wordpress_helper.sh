#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc02
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/wpcli_helper.sh"

################################################################################

search_wp_config () {

    # $1 = ${DIR_TO_SEARCH}

    DIR_TO_SEARCH=$1

    find "${DIR_TO_SEARCH}" -name "wp-config.php" | sed 's|/[^/]*$||'

}


wp_download_wordpress() {

  # $1 = ${FOLDER_TO_INSTALL}
  # $2 = ${PROJECT_DOMAIN}

  FOLDER_TO_INSTALL=$1
  PROJECT_DOMAIN=$2

  echo "Trying to make a clean install of Wordpress ..." >>$LOG
  echo -e ${CYAN}"Trying to make a clean install of Wordpress ..."${ENDCOLOR}

  cd "${FOLDER_TO_INSTALL}"
  curl -O "https://wordpress.org/latest.tar.gz"
  tar -xzxf latest.tar.gz
  rm latest.tar.gz
  mv "wordpress" "${PROJECT_DOMAIN}"
  cd "${PROJECT_DOMAIN}"

  # Setup wp-config.php
  cp wp-config-sample.php "${FOLDER_TO_INSTALL}/${PROJECT_DOMAIN}/wp-config.php"
  rm "${FOLDER_TO_INSTALL}/${PROJECT_DOMAIN}/wp-config-sample.php"

}

wp_update_wpconfig() {

  # $1 = ${WP_SITE}
  # $2 = ${WP_PROJECT_NAME}
  # $3 = ${WP_PROJECT_STATE}
  # $4 = ${DB_USER_PASS}

  WP_SITE_PATH=$1
  WP_PROJECT_NAME=$2
  WP_PROJECT_STATE=$3
  DB_USER_PASS=$4

  # Change wp-config.php database parameters
  echo -e ${YELLOW}"Changing wp-config.php database parameters ..."${ENDCOLOR}
  echo " > Changing wp-config.php database parameters ..." >>$LOG
  
  sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" "${WP_SITE_PATH}/wp-config.php"
  
  if [[ ${WP_PROJECT_NAME} != "" ]]; then
    sed -i "/DB_NAME/s/'[^']*'/'${WP_PROJECT_NAME}_${WP_PROJECT_STATE}'/2" "${WP_SITE_PATH}/wp-config.php"
  fi
  if [[ ${DB_USER_PASS} != "" ]]; then
    sed -i "/DB_USER/s/'[^']*'/'${WP_PROJECT_NAME}_user'/2" "${WP_SITE_PATH}/wp-config.php"
    sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_USER_PASS}'/2" "${WP_SITE_PATH}/wp-config.php"
  fi

}

wp_change_ownership() {

  # $1 = ${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT} or ${FOLDER_TO_INSTALL}/${DOMAIN}

  PROJECT_DIR=$1

  echo "Changing folder owner to www-data ..." >>$LOG
  echo -e ${CYAN}"Changing '${PROJECT_DIR}' owner to www-data ..."${ENDCOLOR}

  chown -R www-data:www-data "${PROJECT_DIR}"
  find "${PROJECT_DIR}" -type d -exec chmod g+s {} \;
  chmod g+w "${PROJECT_DIR}/wp-content"
  chmod -R g+w "${PROJECT_DIR}/wp-content/themes"
  chmod -R g+w "${PROJECT_DIR}/wp-content/plugins"

  echo " > DONE" >>$LOG
  echo -e ${GREEN}" > DONE"${ENDCOLOR}
}

# TODO: Change this, because only works on english or spanish version of WP
wp_set_salts() {

  # English
  perl -i -pe'
    BEGIN {
      @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
      push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
      sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/put your unique phrase here/salt()/ge
  ' "${WPCONFIG}"
  # Spanish
  perl -i -pe'
    BEGIN {
      @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
      push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
      sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/pon aquí tu frase aleatoria/salt()/ge
  ' "${WPCONFIG}"
}

wp_database_creation() {

  # Parameters
  # $1 = ${PROJECT_NAME}
  # $2 = ${PROJECT_STATE}

  # Return: 
  # 0 if DB_USER not exits
  # 1 if DB_USER already exists

  PROJECT_NAME=$1
  PROJECT_STATE=$2

  if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${PROJECT_NAME}_user';" | $MYSQL -u ${MUSER} --password=${MPASS} | grep 1 &>/dev/null; then

    DB_PASS=$(openssl rand -hex 12)

    SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
    SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
    SQL4="FLUSH PRIVILEGES;"

    echo -e ${CYAN}"***********************************************************************************************"${ENDCOLOR}
    echo -e ${CYAN}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS}"${ENDCOLOR}
    echo -e ${CYAN}"***********************************************************************************************"${ENDCOLOR}

    echo " > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS}" >>$LOG

    $MYSQL -u ${MUSER} --password=${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}"

    if [ $? -eq 0 ]; then
      echo " > DONE!" >>$LOG
      echo -e ${GREEN}" > DONE!"${ENDCOLOR}
      return 0

    else
      echo " > Something went wrong!" >>$LOG
      echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
      exit 1

    fi

  else
    echo " > User: ${PROJECT_NAME}_user already exist. Continue ..." >>$LOG

    SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
    SQL2="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
    SQL3="FLUSH PRIVILEGES;"

    echo -e ${CYAN}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and granting privileges to user: ${PROJECT_NAME}_user ..."${ENDCOLOR}

    $MYSQL -u "${MUSER}" --password="${MPASS}" -e "${SQL1}${SQL2}${SQL3}"

    if [ $? -eq 0 ]; then
      echo " > DONE!" >>$LOG
      echo -e ${GREN}" > DONE!"${ENDCOLOR}
      return 1

    else
      echo " > Something went wrong!" >>$LOG
      echo -e ${B_RED}" > Something went wrong!"${ENDCOLOR}
      exit 1

    fi

  fi

}
#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"

################################################################################

search_wp_config () {

    # $1 = ${dir_to_search}

    local dir_to_search=$1

    find "${dir_to_search}" -name "wp-config.php" | sed 's|/[^/]*$||'

}


wp_download_wordpress() {

  # $1 = ${folder_to_install}
  # $2 = ${project_domain}

  local folder_to_install=$1
  local project_domain=$2

  echo "Trying to make a clean install of Wordpress ..." >>$LOG
  echo -e ${CYAN}"Trying to make a clean install of Wordpress ..."${ENDCOLOR}

  #cd "${folder_to_install}"
  #curl -O "https://wordpress.org/latest.tar.gz"

  wget -P "${folder_to_install}" "https://wordpress.org/latest.tar.gz"

  #tar -xzxf "${folder_to_install}/latest.tar.gz"

  extract "${folder_to_install}/latest.tar.gz" "${folder_to_install}"

  mv "${folder_to_install}/wordpress" "${folder_to_install}/${project_domain}"
  rm "${folder_to_install}/latest.tar.gz"

  # Setup wp-config.php
  cp "${folder_to_install}/${project_domain}/wp-config-sample.php" "${folder_to_install}/${project_domain}/wp-config.php"
  rm "${folder_to_install}/${project_domain}/wp-config-sample.php"

}

wp_update_wpconfig() {

  # $1 = ${project_dir}
  # $2 = ${wp_project_name}
  # $3 = ${wp_project_state}
  # $4 = ${db_user_pass}

  local wp_project_dir=$1
  local wp_project_name=$2
  local wp_project_state=$3
  local db_user_pass=$4

  # Change wp-config.php database parameters
  echo -e ${CYAN}"Changing wp-config.php database parameters ..."${ENDCOLOR}
  echo " > Changing wp-config.php database parameters ..." >>$LOG
  
  sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" "${wp_project_dir}/wp-config.php"
  
  if [[ ${wp_project_name} != "" ]]; then
    sed -i "/DB_NAME/s/'[^']*'/'${wp_project_name}_${wp_project_state}'/2" "${wp_project_dir}/wp-config.php"
  fi
  if [[ ${db_user_pass} != "" ]]; then
    sed -i "/DB_USER/s/'[^']*'/'${wp_project_name}_user'/2" "${wp_project_dir}/wp-config.php"
    sed -i "/DB_PASSWORD/s/'[^']*'/'${db_user_pass}'/2" "${wp_project_dir}/wp-config.php"
  fi

}

wp_change_ownership() {

  # $1 = ${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT} or ${FOLDER_TO_INSTALL}/${DOMAIN}

  local project_dir=$1

  # Change ownership
  change_ownership "www-data" "www-data" "${project_dir}"
  
  find "${project_dir}" -type d -exec chmod g+s {} \;
  chmod g+w "${project_dir}/wp-content"
  chmod -R g+w "${project_dir}/wp-content/themes"
  chmod -R g+w "${project_dir}/wp-content/plugins"

  echo " > DONE" >>$LOG
  echo -e ${GREEN}" > DONE"${ENDCOLOR}
}

# TODO: Change this, because only works on english or spanish version of WP
wp_set_salts() {

  # $1 = ${WPCONFIG}

  local wp_config=$1

  # English
  perl -i -pe'
    BEGIN {
      @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
      push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
      sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/put your unique phrase here/salt()/ge
  ' "${wp_config}"
  # Spanish
  perl -i -pe'
    BEGIN {
      @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
      push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
      sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/pon aquí tu frase aleatoria/salt()/ge
  ' "${wp_config}"
}

wp_database_creation() {

  # Parameters
  # $1 = ${project_name}
  # $2 = ${project_state}

  # Return: 
  # 0 if DB_USER not exits
  # 1 if DB_USER already exists

  local project_name=$1
  local project_state=$2

  if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${project_name}_user';" | $MYSQL -u "${MUSER}" --password="${MPASS}" | grep 1 &>/dev/null; then

    DB_PASS=$(openssl rand -hex 12)

    SQL1="CREATE DATABASE IF NOT EXISTS ${project_name}_${project_state};"
    SQL2="CREATE USER '${project_name}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    SQL3="GRANT ALL PRIVILEGES ON ${project_name}_${project_state} . * TO '${project_name}_user'@'localhost';"
    SQL4="FLUSH PRIVILEGES;"

    echo -e ${CYAN}"******************************************************************************************"${ENDCOLOR}
    echo -e ${CYAN}" > Creating database ${project_name}_${project_state}, and user ${project_name}_user with pass ${DB_PASS}"${ENDCOLOR}
    echo -e ${CYAN}"******************************************************************************************"${ENDCOLOR}

    echo " > Creating database ${project_name}_${project_state}, and user ${project_name}_user with pass ${DB_PASS}" >>$LOG

    $MYSQL -u "${MUSER}" --password="${MPASS}" -e "${SQL1}${SQL2}${SQL3}${SQL4}"

    if [ $? -eq 0 ]; then
      echo " > DATABASE AND DATABASE USER CREATED OK!" >>$LOG
      echo -e ${B_GREEN}" > DATABASE AND DATABASE USER CREATED OK!"${ENDCOLOR}
      return 0

    else
      echo " > Something went wrong!" >>$LOG
      echo -e ${B_RED}" > Something went wrong!"${ENDCOLOR}
      exit 1

    fi

  else
    echo " > User: ${project_name}_user already exist. Continue ..." >>$LOG

    SQL1="CREATE DATABASE IF NOT EXISTS ${project_name}_${project_state};"
    SQL2="GRANT ALL PRIVILEGES ON ${project_name}_${project_state} . * TO '${project_name}_user'@'localhost';"
    SQL3="FLUSH PRIVILEGES;"

    echo -e ${CYAN}" > Creating database ${project_name}_${project_state}, and granting privileges to user: ${project_name}_user ..."${ENDCOLOR}

    ${MYSQL} -u "${MUSER}" --password="${MPASS}" -e "${SQL1}${SQL2}${SQL3}"

    if [ $? -eq 0 ]; then
      echo " > DATABASE CREATED OK!" >>$LOG
      echo -e ${B_GREEN}" > DATABASE CREATED OK!"${ENDCOLOR}
      return 1

    else
      echo " > SOMETHING WENT WRONG CREATING DATABASE!" >>$LOG
      echo -e ${B_RED}" > SOMETHING WENT WRONG CREATING DATABASE!"${ENDCOLOR}
      exit 1

    fi

  fi

}

# Ref manual multisite: https://multilingualpress.org/docs/wordpress-multisite-database-tables/
#
#UPDATE ${db_prefix}${blog_id}_blogs SET domain='${domain}' WHERE blog_id='1';
#UPDATE ${db_prefix}${blog_id}_blogs SET domain='${domain}' WHERE blog_id='2';
#
#UPDATE ${db_prefix}options SET option_value='${new_URL}' WHERE option_id='1';
#UPDATE ${db_prefix}options SET option_value='${new_URL}' WHERE option_id='2';
#
#UPDATE ${db_prefix}${blog_id}_site SET domain='${domain}' WHERE id='1'; #${domain} instead of ${new_URL}
#
#UPDATE ${db_prefix}${blog_id}_sitemeta SET meta_value='${new_URL}' WHERE meta_id='14';
#
#UPDATE ${db_prefix}${blog_id}_options SET option_value='${new_URL}' WHERE option_id='1';
#UPDATE ${db_prefix}${blog_id}_options SET option_value='${new_URL}' WHERE option_id='2';

wp_replace_string_on_database() {

  # $1 = ${db_prefix}
  # $2 = ${target_db}

  local db_prefix=$1
  local target_db=$2

  if [[ -z "${db_prefix}" ]]; then
    db_prefix=$(whiptail --title "WordPress DB Prefix" --inputbox "Please insert the WordPress Database Prefix. Example: wp_" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "Setting db_prefix=${db_prefix}" >> $LOG
    else
      exit 1
    fi
  fi


  if [[ -z "${target_db}" ]]; then
    
    DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"
    
    CHOSEN_DB=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to work with" 20 78 10 `for x in ${DBS}; do echo "$x [DB]"; done` 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
      echo "Setting CHOSEN_DB=${CHOSEN_DB}" >> $LOG
    else
      exit 1
    fi

  else
    CHOSEN_DB=${target_db};

  fi

  if [[ -z "${existing_URL}" ]]; then
    existing_URL=$(whiptail --title "URL TO CHANGE" --inputbox "Insert the URL you want to change, including http:// or https://" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?

    echo "Setting existing_URL=${existing_URL}" >> $LOG

    if [ ${exitstatus} = 0 ]; then

      if [[ -z "${new_URL}" ]]; then
        new_URL=$(whiptail --title "THE NEW URL" --inputbox "Insert the new URL , including http:// or https://" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ ${exitstatus} = 0 ]; then

          echo "Setting new_URL=${new_URL}" >> $LOG

          echo "Executing mysqldump of ${CHOSEN_DB} before replace urls ...">> $LOG
          ${MYSQLDUMP} -u "${MUSER}" --password="${MPASS}" "${CHOSEN_DB}" > "${CHOSEN_DB}_bk_before_replace_urls.sql"

          echo "Database backup created: ${CHOSEN_DB}_bk_before_replace_urls.sql">> $LOG
          echo -e ${YELLOW}" > Database backup created: ${CHOSEN_DB}_bk_before_replace_urls.sql"${ENDCOLOR}

          # Queries
          SQL0="USE ${CHOSEN_DB};"
          SQL1="UPDATE ${db_prefix}options SET option_value = replace(option_value, '${existing_URL}', '${new_URL}') WHERE option_name = 'home' OR option_name = 'siteurl';"
          SQL2="UPDATE ${db_prefix}posts SET post_content = replace(post_content, '${existing_URL}', '${new_URL}');"
          SQL3="UPDATE ${db_prefix}posts SET guid = replace(guid, '${existing_URL}', '${new_URL}');"
          SQL4="UPDATE ${db_prefix}postmeta SET meta_value = replace(meta_value,'${existing_URL}','${new_URL}');"
          SQL5="UPDATE ${db_prefix}usermeta SET meta_value = replace(meta_value, '${existing_URL}','${new_URL}');"
          SQL6="UPDATE ${db_prefix}links SET link_url = replace(link_url, '${existing_URL}','${new_URL}');"
          SQL7="UPDATE ${db_prefix}comments SET comment_content = replace(comment_content , '${existing_URL}','${new_URL}');"

          echo "Replacing URLs in database ${CHOSEN_DB} ...">> $LOG
          echo -e ${YELLOW}" > Replacing URLs in database ${CHOSEN_DB} ..."${ENDCOLOR}

          ${MYSQL} -u "${MUSER}" --password="${MPASS}" -e "${SQL0}${SQL1}${SQL2}${SQL3}${SQL4}${SQL5}${SQL6}${SQL7}"

          echo " > STRING REPLACED OK">> $LOG
          echo -e ${B_GREEN}" > STRING REPLACED OK"${ENDCOLOR}

        fi

      fi

    fi

  fi

}
#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc04
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"
# shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
source "${SFOLDER}/libs/wordpress_helper.sh"
# shellcheck source=${SFOLDER}/libs/certbot_helper.sh
source "${SFOLDER}/libs/certbot_helper.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

make_temp_files_backup() {

  # $1 = Folder to backup

  local folder_to_backup=$1

  mkdir "${SFOLDER}/tmp/old_backup"
  mv "${folder_to_backup}" "${SFOLDER}/tmp/old_backup"

  echo " > Backup completed and stored here: ${SFOLDER}/tmp/old_backup ..." >>$LOG
  echo -e ${GREEN}" > Backup completed and stored here: ${SFOLDER}/tmp/old_backup ..."${ENDCOLOR}

}

make_temp_db_backup() {

  #$1 = ${chosen_project}

  local chosen_project=$1

  if [ -d "/var/lib/mysql/${chosen_project}" ]; then
    echo -e ${YELLOW}" > Executing mysqldump (will work if database exists) ..."${ENDCOLOR}
    mysqldump -u "${MUSER}" --password="${MPASS}" "${chosen_project}" >"${chosen_project}_bk_before_restore.sql"

  fi

}

restore_database_backup() {

  #$1 = ${chosen_project}
  #$2 = ${chosen_backup}

  local chosen_project=$1
  local chosen_backup=$2

  local project_name project_state db_user db_name db_exists user_db_exists db_pass

  echo " > Running restore_database_backup for ${chosen_backup} DB" >>$LOG
  echo -e "${CYAN} > Running restore_database_backup for ${chosen_backup} DB ${ENDCOLOR}"

  # Asking project state with suggested actual state
  suffix="$(cut -d'_' -f2 <<<"${chosen_project}")"
  project_state=$(ask_project_state "${suffix}")

  # Extract project_name (its removes last part of db name with "_" char)

  project_name=${chosen_project%"_$suffix"}

  project_name=$(whiptail --title "Project Name" --inputbox "Want to change the project name?" 10 60 "${project_name}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "Setting project_name=${project_name}" >>$LOG
  else
    exit 1
  fi

  db_user="${project_name}_user"
  db_name="${project_name}_${project_state}"

  # Check if database already exists
  db_exists=$(mysql_database_exists "${db_name}")
  if [[ ${db_exists} -eq 1 ]]; then  
    echo -e ${CYAN}" > Creating '${db_name}' database in MySQL ..."${ENDCOLOR}
    echo "Creating '${db_name}' database in MySQL ..." >>$LOG
    mysql_database_create "${db_name}"

  else
    echo -e ${B_GREEN}" > MySQL DB ${db_name} already exists"${ENDCOLOR}

    #TODO: ask what to do, if continue make a database backup

  fi

  # Check if user database already exists
  user_db_exists=$(mysql_user_exists "${db_user}")
  if [[ ${user_db_exists} -eq 0 ]]; then

    db_pass=$(openssl rand -hex 12)

    echo -e ${B_CYAN}" > Creating '${db_user}' user in MySQL with pass: ${db_pass}"${B_ENDCOLOR}
    echo " > Creating ${db_user} user in MySQL with pass: ${db_pass}" >>$LOG

    mysql_user_create "${db_user}" "${db_pass}"

  else
    echo -e ${B_GREEN}" > User ${db_user} already exists"${B_ENDCOLOR}
    echo " > User ${db_user} already exists"${ENDCOLOR} >>$LOG

  fi

  # Grant privileges to database user
  mysql_user_grant_privileges "${db_user}" "${db_name}"

  # Trying to restore Database
  chosen_backup="${chosen_backup%%.*}.sql"
  mysql_database_import "${project_name}_${project_state}" "${chosen_backup}"

  echo -e ${CYAN}" > Cleanning temp files ..."${ENDCOLOR}
  rm ${chosen_backup%%.*}.sql
  rm "${chosen_backup}"
  echo -e ${B_GREEN}" > DONE"${ENDCOLOR}

}

download_and_restore_config_files_from_dropbox(){

  #$1 = ${dropbox_chosen_type_path}
  #$2 = ${dropbox_project_list}

  local dropbox_chosen_type_path=$1
  local dropbox_project_list=$2

  local chosen_config_type dropbox_bk_list chosen_config_bk

  # Select config backup type
  chosen_config_type=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup type." 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    #Restore from Dropbox
    dropbox_bk_list=$($DROPBOX_UPLOADER -hq list "${dropbox_chosen_type_path}/${chosen_config_type}")
  fi

  chosen_config_bk=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup file to restore." 20 78 10 $(for x in ${dropbox_bk_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    cd "${SFOLDER}/tmp"

    echo " > Downloading from Dropbox ${dropbox_chosen_type_path}/${chosen_config_type}/${chosen_config_bk} ..." >>$LOG
    $DROPBOX_UPLOADER download "${dropbox_chosen_type_path}/${chosen_config_type}/${chosen_config_bk}"

    # Restore files
    mkdir "${chosen_config_type}"
    mv "${chosen_config_bk}" "${chosen_config_type}"
    cd "${chosen_config_type}"

    echo -e ${YELLOW} " > Uncompressing ${chosen_config_bk}" ${ENDCOLOR}
    echo " > Uncompressing ${chosen_config_bk}" >>$LOG
    
    pv "${chosen_config_bk}" | tar xp -C "${SFOLDER}/tmp/${chosen_config_type}" --use-compress-program=lbzip2

    if [[ "${chosen_config_bk}" == *"nginx"* ]]; then

    restore_nginx_site_files ""

    fi
    if [[ "${CHOSEN_CONFIG}" == *"mysql"* ]]; then
      echo -e ${B_RED}" > TODO: RESTORE MYSQL CONFIG ..."${ENDCOLOR}

    fi
    if [[ "${CHOSEN_CONFIG}" == *"php"* ]]; then
      echo -e ${B_RED}" > TODO: RESTORE PHP CONFIG ..."${ENDCOLOR}

    fi
    if [[ "${CHOSEN_CONFIG}" == *"letsencrypt"* ]]; then
      echo -e ${B_RED}" > TODO: RESTORE LETSENCRYPT CONFIG ..."${ENDCOLOR}

      #restore_letsencrypt_site_files ""

    fi

    # TODO: ask for remove tmp files
    #echo " > Removing ${SFOLDER}/tmp/${chosen_type} ..." >>$LOG
    #echo -e ${GREEN}" > Removing ${SFOLDER}/tmp/${chosen_type} ..."${ENDCOLOR}
    #rm -R ${SFOLDER}/tmp/${chosen_type}

    echo " > DONE ..." >>$LOG
    echo -e ${B_GREEN}" > DONE ..."${ENDCOLOR}

  fi

}

restore_nginx_site_files() {

  #$1 = ${domain} optional

  local domain=$1

  # TODO: support for domain parameter
  # TODO: if nginx is installed, ask if nginx.conf must be replace

  # Checking if default nginx folder exists
  if [[ -n "${WSERVER}" ]]; then

    echo -e ${GREEN}" > Folder ${WSERVER} exists ... OK"${ENDCOLOR}

    if [[ -z "${domain}" ]]; then

      startdir="${SFOLDER}/tmp/nginx/sites-available"
      file_browser "$menutitle" "$startdir"

      to_restore=$filepath"/"$filename
      echo -e ${YELLOW}" > File to restore: ${to_restore} ..."${ENDCOLOR}

    else

      filename=${domain}

    fi

    if [[ -f "${WSERVER}/sites-available/${filename}" ]]; then

      echo " > File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ..." >>$LOG
      echo -e ${CYAN}" > File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ..."${ENDCOLOR}
      mv "${WSERVER}/sites-available/${filename}" "${WSERVER}/sites-available/${filename}_bk"

      echo " > Restoring backup: ${filename} ..." >>$LOG
      echo -e ${CYAN}" > Restoring backup: ${filename} ..."${ENDCOLOR}
      cp "$to_restore" "${WSERVER}/sites-available/$filename"

      echo " > Reloading webserver ..." >>$LOG
      echo -e ${CYAN}" > Reloading webserver ..."${ENDCOLOR}
      service nginx reload

    else

      echo -e ${GREEN}" > File ${WSERVER}/sites-available/${filename} does NOT exists ..."${ENDCOLOR}

      echo " > Restoring backup: ${filename} ..." >>$LOG
      echo -e ${CYAN}" > Restoring backup: ${filename} ..."${ENDCOLOR}
      cp "$to_restore" "${WSERVER}/sites-available/$filename"
      ln -s "${WSERVER}/sites-available/$filename" "${WSERVER}/sites-enabled/$filename"

      echo " > Reloading webserver ..." >>$LOG
      echo -e ${YELLOW}" > Reloading webserver ..."${ENDCOLOR}
      service nginx reload

    fi

  else

    echo -e ${B_RED}" > /etc/nginx/sites-available NOT exist... Skipping!"${ENDCOLOR}

  fi

}

restore_letsencrypt_site_files() {

  # $1 = ${domain}

  local domain=$1

  mkdir "/etc/letsencrypt/archive/${domain}"
  mkdir "/etc/letsencrypt/live/${domain}"

  cp -r "${SFOLDER}/tmp/letsencrypt/archive/${domain}" "/etc/letsencrypt/archive/${domain}/"
  cp -r "${SFOLDER}/tmp/letsencrypt/live/${domain}" "/etc/letsencrypt/live/${domain}/"

  #cp "${SFOLDER}/tmp/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/cert.pem"
  #cp "${SFOLDER}/tmp/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/chain.pem"
  #cp "${SFOLDER}/tmp/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/fullchain.pem"
  #cp "${SFOLDER}/tmp/letsencrypt/live/${domain}/privkey.pem" "/etc/letsencrypt/live/${domain}/privkey.pem"

}

restore_site_files() {

  # $1 = ${chosen_domain} Here, should match with PROJECT_DOMAIN

  local domain=$1

  local actual_folder folder_to_install chosen_domain

  chosen_domain=$(whiptail --title "Project Name" --inputbox "Want to change the project's domain? Default:" 10 60 "${domain}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    echo "Setting chosen_domain=${chosen_domain}" >>$LOG

    # New tmp folder
    project_tmp_folder="${SFOLDER}/tmp/${chosen_domain}"

    # Renaming
    mv "${SFOLDER}/tmp/${domain}" "${project_tmp_folder}"
      
    # Ask folder to install
    folder_to_install=$(ask_folder_to_install_sites "${SITES}")

    # New destination directory
    actual_folder="${folder_to_install}/${chosen_domain}"

    # Check if destination folder exist
    if [ -d "${actual_folder}" ]; then

      echo " > ${actual_folder} exist. Let's make a Backup ..." >>$LOG
      echo -e ${YELLOW}" > ${actual_folder} exist. Let's make a Backup ..."${ENDCOLOR}

      make_temp_files_backup "${actual_folder}"

    fi

    # Restore files
    echo " > Moving files from ${project_tmp_folder} to ${folder_to_install} ..." >>$LOG
    echo -e ${CYAN}" > Moving files from ${project_tmp_folder} to ${folder_to_install} ..."${ENDCOLOR}
    
    mv "${project_tmp_folder}" "${folder_to_install}"

    install_path=$(search_wp_config "${actual_folder}")

    if [ -z "${install_path}" ]; then

      echo -e ${B_GREEN}" > WORDPRESS INSTALLATION FOUND ON PATH: ${actual_folder}/${install_path}"${ENDCOLOR}
      wp_change_ownership "${install_path}"

    fi

    # TODO: ask to choose between regenerate nginx config or restore backup
    # If choose restore config and has https, need to restore letsencrypt config and run cerbot

    #echo "Trying to restore nginx config for ${chosen_project} ..."
    # New site configuration
    #cp ${SFOLDER}/confs/default /etc/nginx/sites-available/${chosen_project}
    #ln -s /etc/nginx/sites-available/${chosen_project} /etc/nginx/sites-enabled/${chosen_project}
    # Replacing string to match domain name
    #sed -i "s#dominio.com#${chosen_project}#" /etc/nginx/sites-available/${chosen_project}
    # Need to be run twice
    #sed -i "s#dominio.com#${chosen_project}#" /etc/nginx/sites-available/${chosen_project}
    #service nginx reload

    echo -e ${B_GREEN}" > FILE RESTORED ON ${install_path}!"${ENDCOLOR}

  else
    exit 1
  fi

}

restore_database() {
  
  # $1 = chosen_project
  # $2 = chosen_backup_to_restore

  local chosen_project=$1
  local chosen_backup_to_restore=$2

  make_temp_db_backup "${chosen_project}"

  restore_database_backup "${chosen_project}" "${chosen_backup_to_restore}"

}

select_restore_type_from_dropbox() {
  
  # TODO: check project type (WP? Laravel? other?)
  # ask for directory_browser if apply
  # add credentials on external txt and send email

  # $1 = chosen_server
  # $2 = dropbox_type_list

  local chosen_server=$1
  local dropbox_type_list=$2

  local chosen_type dropbox_chosen_type_path dropbox_project_list domain bk_to_dowload

  chosen_type=$(whiptail --title "RESTORE FROM BACKUP" --menu "Choose a backup type. You can choose restore an entire project or only site files, database or config." 20 78 10 $(for x in ${dropbox_type_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    dropbox_chosen_type_path="${chosen_server}/${chosen_type}"

    echo "dropbox_chosen_type_path: ${dropbox_chosen_type_path}"

    if [[ ${chosen_type} == "project" ]]; then

      project_restore "${chosen_server}"

    elif [[ ${chosen_type} != "project" ]]; then

      dropbox_project_list=$($DROPBOX_UPLOADER -hq list "${dropbox_chosen_type_path}")
      
      if [[ ${chosen_type} == *"$CONFIG_F"* ]]; then

        download_and_restore_config_files_from_dropbox "${dropbox_chosen_type_path}" "${dropbox_project_list}"

      else # DB or SITE

        # Select Project
        chosen_project=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then
          DROPBOX_CHOSEN_BACKUP_PATH="${dropbox_chosen_type_path}/${chosen_project}"
          DROPBOX_BACKUP_LIST=$($DROPBOX_UPLOADER -hq list "${DROPBOX_CHOSEN_BACKUP_PATH}")

        fi
        # Select Backup File
        CHOSEN_BACKUP_TO_RESTORE=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${DROPBOX_BACKUP_LIST}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then

          cd "${SFOLDER}/tmp"

          bk_to_dowload="${chosen_server}/${chosen_type}/${chosen_project}/${CHOSEN_BACKUP_TO_RESTORE}"

          echo " > Running dropbox_uploader.sh download ${bk_to_dowload}" >>$LOG

          $DROPBOX_UPLOADER download "${bk_to_dowload}"

          echo -e ${CYAN}" > Uncompressing ${CHOSEN_BACKUP_TO_RESTORE}"${ENDCOLOR}
          echo " > Uncompressing ${CHOSEN_BACKUP_TO_RESTORE}" >>$LOG

          pv "${CHOSEN_BACKUP_TO_RESTORE}" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2

          if [[ ${chosen_type} == *"$DBS_F"* ]]; then

            restore_database "${chosen_project}" "${CHOSEN_BACKUP_TO_RESTORE}"

            # TODO: ask if want to change project db parameters and make cloudflare changes

            # TODO: check project type (WP, Laravel, etc)

            FOLDER_TO_INSTALL=$(ask_folder_to_install_sites "${SITES}")

            startdir=${FOLDER_TO_INSTALL}
            menutitle="Site Selection Menu"
            directory_browser "$menutitle" "$startdir"
            PROJECT_SITE=$filepath"/"$filename

            install_path=$(search_wp_config "${FOLDER_TO_INSTALL}/${filename}")

            echo -e ${B_CYAN}" > install_path: ${install_path}"${ENDCOLOR}
            echo -e ${B_CYAN}" > filename: ${filename}"${ENDCOLOR}

            # TODO: search_wp_config could be an array of dir paths, need to check that
            if [ "${install_path}" != "" ]; then

              echo -e ${B_GREEN}" > WORDPRESS INSTALLATION FOUND ON PATH: ${PROJECT_SITE}/${install_path}"${ENDCOLOR}

              # Change wp-config.php database parameters
              wp_update_wpconfig "${install_path}" "${project_name}" "${project_state}" "${DB_PASS}"

              # TODO: change the secret encryption keys

            else

              echo -e ${B_RED}" > WORDPRESS INSTALLATION NOT FOUND!"${ENDCOLOR}

            fi

            #TODO: ask if want to change IP from Cloudflare then ask for Cloudflare Root Domain

            # Asume that project main folder name is the project's domain, removing "/" char
            domain="${filename::-1}"
            
            # Only for Cloudflare API
            #suggested_root_domain=${domain#[[:alpha:]]*.}
            suggested_root_domain=${domain}

            root_domain=$(cloudflare_ask_root_domain "${suggested_root_domain}")

            cloudflare_change_a_record "${root_domain}" "${domain}"
            
            # HTTPS with Certbot
            certbot_helper_installer_menu "${MAILA}" "${domain}"

          else # site

            # Here, for convention, chosen_project should be CHOSEN_DOMAIN... 
            # Only for better code reading, i assign this new var:
            chosen_domain=${chosen_project}
            restore_site_files "${chosen_domain}"

          fi
        
        fi

      fi

    fi

  fi

}

project_restore() {

  # $1 = ${chosen_server}

  local chosen_server=$1

  local dropbox_project_list chosen_project dropbox_chosen_backup_path dropbox_backup_list bk_to_dowload chosen_backup_to_restore db_to_download

  dropbox_project_list=$($DROPBOX_UPLOADER -hq list "${chosen_server}/site")

  # Select Project
  chosen_project=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    dropbox_chosen_backup_path="${chosen_server}/site/${chosen_project}"
    echo "DROPBOX PATH TO EXPLORE: ${chosen_server}/site/${chosen_project}"

    dropbox_backup_list=$($DROPBOX_UPLOADER -hq list "${dropbox_chosen_backup_path}")

  fi
  # Select Backup File
  chosen_backup_to_restore=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${dropbox_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    cd "${SFOLDER}/tmp"

    bk_to_dowload="${chosen_server}/site/${chosen_project}/${chosen_backup_to_restore}"

    echo " > Running dropbox_uploader.sh download ${bk_to_dowload}" >>$LOG

    $DROPBOX_UPLOADER download "${bk_to_dowload}"

    echo -e ${CYAN}" > Uncompressing ${chosen_backup_to_restore}"${ENDCOLOR}
    echo " > Uncompressing ${chosen_backup_to_restore}" >>$LOG

    pv "${chosen_backup_to_restore}" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2

    project_type=$(get_project_type "${SFOLDER}/tmp/${chosen_project}")

    echo -e ${B_CYAN}" > Project Type: ${project_type}"${ENDCOLOR}
    echo " > Project Type: ${project_type}" >>$LOG

    echo -e ${B_CYAN}"TRYING TO EXTRACT DB PARAMETERS ..."
    
    case $project_type in

      wordpress)
        db_name=$(cat ${SFOLDER}/tmp/${chosen_project}/wp-config.php | grep DB_NAME | cut -d \' -f 4)
        db_user=$(cat ${SFOLDER}/tmp/${chosen_project}/wp-config.php | grep DB_USER | cut -d \' -f 4)
        db_pass=$(cat ${SFOLDER}/tmp/${chosen_project}/wp-config.php | grep DB_PASSWORD | cut -d \' -f 4)
        ;;

      laravel)
        echo -n "TODO"
        ;;

      yii)
        echo -n "TODO"
        ;;

      *)
        echo -n "Project Type Unknown"
        ;;
    esac

    # Here, for convention, chosen_project should be CHOSEN_DOMAIN... 
    # Only for better code reading, i assign this new var:
    chosen_domain=${chosen_project}
    restore_site_files "${chosen_domain}"

    backup_date=$(echo ${chosen_backup_to_restore} |grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')

    db_to_download="${chosen_server}/database/${db_name}/${db_name}_database_${backup_date}.tar.bz2"

    echo -e ${B_CYAN}"BACKUP DATE: ${backup_date}"
    echo -e ${B_CYAN}"DB NAME: ${db_name}"
    echo -e ${B_CYAN}"DB USER: ${db_user}"
    echo -e ${B_CYAN}"DB PASS: ${db_pass}"
    echo -e ${B_CYAN}"TRYING TO DOWNLOAD: ${db_to_download}"

    $DROPBOX_UPLOADER download "${db_to_download}"

    echo -e ${CYAN}" > Uncompressing ${db_to_download}"${ENDCOLOR}
    echo " > Uncompressing ${db_to_download}" >>$LOG

    pv "${db_name}_database_${backup_date}.tar.bz2" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2

    restore_database "${chosen_project}" "${db_name}_database_${backup_date}.tar.bz2"

    # Change wp-config.php database parameters
    #wp_update_wpconfig "${install_path}" "${project_name}" "${project_state}" "${db_pass}"

    #TODO: try to restore nginx_server config from project (now, need to download all, extract, and then select from project_name)

    restore_letsencrypt_site_files "${chosen_domain}"

    restore_nginx_site_files "${chosen_domain}"

  fi

}
#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.5
################################################################################

is_wp_project() {

  # $1 = project directory

  local project_dir=$1

  log_event "info" "Checking if ${project_dir} is a WordPress project ..."

  # Check if it has wp-config.php
  if [[ -f "${project_dir}/wp-config.php" ]]; then
    is_wp="true"
    log_event "info" "${project_dir} is a WordPress project"

  else
    is_wp="false"
    log_event "info" "${project_dir} is not a WordPress project"

  fi

  # Return
  echo "${is_wp}"

}

search_wp_config () {

    # $1 = ${dir_to_search}

    local dir_to_search=$1

    find "${dir_to_search}" -name "wp-config.php" | sed 's|/[^/]*$||'

}

#TODO: why not use https://developer.wordpress.org/cli/commands/config/create/ ?
wp_update_wpconfig() {

  # $1 = ${project_dir}
  # $2 = ${wp_project_name}
  # $3 = ${wp_project_state}
  # $4 = ${db_user_pass}

  local wp_project_dir=$1
  local wp_project_name=$2
  local wp_project_state=$3
  local db_user_pass=$4

  local sed_output

  # Change wp-config.php database parameters
  log_event "info" "Changing database parameters on ${wp_project_dir}/wp-config.php" "false"
  
  sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" "${wp_project_dir}/wp-config.php"
  
  if [[ ${wp_project_name} != "" ]]; then
    sed_output=$(sed -i "/DB_NAME/s/'[^']*'/'${wp_project_name}_${wp_project_state}'/2" "${wp_project_dir}/wp-config.php")
  fi
  if [[ ${db_user_pass} != "" ]]; then
    sed_output=$(sed -i "/DB_USER/s/'[^']*'/'${wp_project_name}_user'/2" "${wp_project_dir}/wp-config.php")
    sed_output=$(sed -i "/DB_PASSWORD/s/'[^']*'/'${db_user_pass}'/2" "${wp_project_dir}/wp-config.php")
  fi

  sed_result=$?
  if [ ${sed_result} -eq 0 ]; then
    display --indent 2 --text " - Changing database parameters on ${wp_project_dir}/wp-config.php" --result "DONE" --color GREEN
  else
    display --indent 2 --text " - Changing database parameters on ${wp_project_dir}/wp-config.php" --result "FAIL" --color RED
    display --indent 4 --text "sed output: ${sed_output}"
  fi

}

wp_change_permissions() {

  # $1 = ${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT} or ${FOLDER_TO_INSTALL}/${DOMAIN}

  local project_dir=$1

  # Change ownership
  change_ownership "www-data" "www-data" "${project_dir}"
  
  find "${project_dir}" -type d -exec chmod g+s {} \;

  if [ -d "${project_dir}/wp-content" ]; then

    chmod g+w "${project_dir}/wp-content"
    chmod -R g+w "${project_dir}/wp-content/themes"
    chmod -R g+w "${project_dir}/wp-content/plugins"

  fi

  log_event "info" "Permissions changes for: ${project_dir}" "false"
  display --indent 2 --text "- Setting default permissions on wordpress" --result "DONE" --color GREEN

  
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

  local chosen_db

  if [[ -z "${db_prefix}" ]]; then
   
    db_prefix=$(whiptail --title "WordPress DB Prefix" --inputbox "Please insert the WordPress Database Prefix. Example: wp_" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      log_event "info" "Setting db_prefix=${db_prefix}"
    else
      return 1
    fi

  fi


  if [[ -z "${target_db}" ]]; then
    
    DBS="$(${MYSQL} -u "${MUSER}" -p"${MPASS}" -Bse 'show databases')"
    
    chosen_db=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to work with" 20 78 10 `for x in ${DBS}; do echo "$x [DB]"; done` 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      log_event "info" "Setting chosen_db=${chosen_db}"
    else
      return 1
    fi

  else
    chosen_db=${target_db};

  fi

  if [[ -z "${existing_URL}" ]]; then
    existing_URL=$(whiptail --title "URL TO CHANGE" --inputbox "Insert the URL you want to change, including http:// or https://" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?

    log_event "info" "Setting existing_URL=${existing_URL}"

    if [ ${exitstatus} = 0 ]; then

      if [[ -z "${new_URL}" ]]; then
        new_URL=$(whiptail --title "THE NEW URL" --inputbox "Insert the new URL , including http:// or https://" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ ${exitstatus} = 0 ]; then

          log_event "info" "Setting new_URL=${new_URL}"
          log_event "info" "Executing mysqldump of ${chosen_db} before replace urls ..."

          ${MYSQLDUMP} -u "${MUSER}" --password="${MPASS}" "${chosen_db}" > "${chosen_db}_bk_before_replace_urls.sql"

          log_event "success" "Database backup created: ${chosen_db}_bk_before_replace_urls.sql"

          # Queries
          SQL0="USE ${chosen_db};"
          SQL1="UPDATE ${db_prefix}options SET option_value = replace(option_value, '${existing_URL}', '${new_URL}') WHERE option_name = 'home' OR option_name = 'siteurl';"
          SQL2="UPDATE ${db_prefix}posts SET post_content = replace(post_content, '${existing_URL}', '${new_URL}');"
          SQL3="UPDATE ${db_prefix}posts SET guid = replace(guid, '${existing_URL}', '${new_URL}');"
          SQL4="UPDATE ${db_prefix}postmeta SET meta_value = replace(meta_value,'${existing_URL}','${new_URL}');"
          SQL5="UPDATE ${db_prefix}usermeta SET meta_value = replace(meta_value, '${existing_URL}','${new_URL}');"
          SQL6="UPDATE ${db_prefix}links SET link_url = replace(link_url, '${existing_URL}','${new_URL}');"
          SQL7="UPDATE ${db_prefix}comments SET comment_content = replace(comment_content , '${existing_URL}','${new_URL}');"

          log_event "info" "Replacing URLs in database ${chosen_db} ..."

          ${MYSQL} -u "${MUSER}" --password="${MPASS}" -e "${SQL0}${SQL1}${SQL2}${SQL3}${SQL4}${SQL5}${SQL6}${SQL7}"

          log_event "success" "String replaced on database ${chosen_db} ..."

        fi

      fi

    fi

  fi

}

wp_ask_url_search_and_replace() {

  # $1 = wp_path

  local wp_path=$1

  if [[ -z "${existing_URL}" ]]; then
    existing_URL=$(whiptail --title "URL TO CHANGE" --inputbox "Insert the URL you want to change, including http:// or https://" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?

    #echo "Setting existing_URL=${existing_URL}" >>$LOG

    if [ ${exitstatus} = 0 ]; then

      if [[ -z "${new_URL}" ]]; then
        new_URL=$(whiptail --title "THE NEW URL" --inputbox "Insert the new URL , including http:// or https://" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?

        if [ ${exitstatus} = 0 ]; then

          ### Creating temporary folders
          if [ ! -d "${SFOLDER}/tmp-backup" ]; then
              mkdir "${SFOLDER}/tmp-backup"
              log_event "info" "Temp files directory created: ${SFOLDER}/tmp-backup" "false"
          fi

          project_name=$(basename "${wp_path}")

          wpcli_export_database "${wp_path}" "${SFOLDER}/tmp-backup/${project_name}_bk_before_replace_urls.sql"

          log_event "info" "Setting new URL ${new_URL} on wordpress database"

          wpcli_search_and_replace "${wp_path}" "${existing_URL}" "${new_URL}"

        fi

      fi

    fi

  fi

}
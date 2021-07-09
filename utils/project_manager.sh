#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.42
################################################################################

function menu_project_utils() {

  local whip_title
  local whip_description
  local project_utils_options
  local chosen_project_utils_options

  whip_title="PROJECT UTILS"
  whip_description=" "

  project_utils_options=(
    "01)" "CREATE NEW PROJECT"
    "02)" "DELETE PROJECT"
    "03)" "GENERATE PROJECT CONFIG"
    "04)" "CREATE PROJECT DB  & USER"
    "05)" "RENAME DATABASE"
    "06)" "PUT PROJECT ONLINE"
    "07)" "PUT PROJECT OFFLINE"
    "08)" "REGENERATE NGINX SERVER"
    "09)" "BENCH PROJECT GTMETRIX"
  )

  chosen_project_utils_options="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_utils_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} = 0 ]]; then

    if [[ ${chosen_project_utils_options} == *"01"* ]]; then

      # CREATE NEW PROJECT
      menu_new_project

    fi

    if [[ ${chosen_project_utils_options} == *"02"* ]]; then

      # DELETE PROJECT
      project_delete ""

    fi

    if [[ ${chosen_project_utils_options} == *"03"* ]]; then

      # GENERATE PROJECT CONFIG
      log_subsection "Project Config"

      # Folder where sites are hosted: $SITES
      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${SITES}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!" "false"

      else

        project_generate_config "${filepath}/${filename}"

      fi

    fi

    if [[ ${chosen_project_utils_options} == *"04"* ]]; then

      # CREATE PROJECT DATABASE & USER
      log_subsection "Create Project DB & User"

      # Folder where sites are hosted: $SITES
      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${SITES}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!" "false"

        # Return
        #return 1

      else

        project_name="$(extract_domain_extension "${filename%/}")"
        project_name="$(mysql_name_sanitize "${project_name}")"
        project_name="$(ask_project_name "${project_name}")"

        log_event "info" "project_name: ${project_name}!"

        project_state="$(ask_project_state "")"
        database_user_passw="$(openssl rand -hex 12)"

        mysql_database_create "${project_name}_${project_state}"
        mysql_user_db_scope="$(mysql_ask_user_db_scope)"
        mysql_user_create "${project_name}_user" "${database_user_passw}" "${mysql_user_db_scope}"
        mysql_user_grant_privileges "${project_name}_user" "${project_name}_${project_state}" "${mysql_user_db_scope}"

        # TODO: check if is a wp project
        # TODO: change wp-config.php on wp projects

        # TODO: ask if want to import?

      fi

    fi

    if [[ ${chosen_project_utils_options} == *"05"* ]]; then

      local chosen_db
      local new_database_name

      chosen_db="$(mysql_ask_database_selection)"

      new_database_name="$(whiptail --title "Database Name" --inputbox "Insert a new database name (only separator allow is '_'). Old name was: ${chosen_db}" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Setting new_database_name: ${new_database_name}" "false"

        # Return
        echo "${new_database_name}"

      else
        return 1

      fi

      # RENAME DATABASE
      mysql_database_rename "${chosen_db}" "${new_database_name}"

    fi

    if [[ ${chosen_project_utils_options} == *"06"* ]]; then

      # PUT PROJECT ONLINE
      project_change_status "online"

    fi

    if [[ ${chosen_project_utils_options} == *"07"* ]]; then

      # PUT PROJECT OFFLINE
      project_change_status "offline"

    fi

    if [[ ${chosen_project_utils_options} == *"08"* ]]; then

      # REGENERATE NGINX SERVER

      log_section "Nginx Manager"

      # Select project to work with
      directory_browser "Select a project to work with" "${SITES}" #return $filename

      if [[ ${filename} != "" ]]; then

        filename="${filename::-1}" # remove '/'

        display --indent 2 --text "- Selecting project" --result DONE --color GREEN
        display --indent 4 --text "Selected project: ${filename}"

        # Aks project domain
        project_domain="$(ask_project_domain "${filename}")"

        # Aks project type
        project_type="$(ask_project_type)"

        if [[ ${project_domain} == "${root_domain}" || ${project_domain} == "www.${root_domain}" ]]; then

          # Nginx config
          nginx_server_create "www.${root_domain}" "${project_type}" "root_domain" "${root_domain}"

          # Let's Encrypt
          certbot_certificate_install "${MAILA}" "${root_domain},www.${root_domain}"

        else

          # Nginx config
          nginx_server_create "${project_domain}" "${project_type}" "single"

          # Let's Encrypt
          certbot_certificate_install "${MAILA}" "${project_domain}"

        fi

      else

        display --indent 2 "Selecting website to work with" --result SKIPPED --color YELLOW

      fi

    fi

    if [[ ${chosen_project_utils_options} == *"09"* ]]; then

      # BENCH PROJECT GTMETRIX

      URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then

        log_section "GTMETRIX"

        display --indent 2 --text "- Testing project ${URL_TO_TEST}"

        # shellcheck source=${SFOLDER}/tools/third-party/google-insights-api-tools/gitools_v5.sh
        gtmetrix_result="$("${SFOLDER}/tools/third-party/google-insights-api-tools/gitools_v5.sh" gtmetrix "${URL_TO_TEST}")"

        gtmetrix_results_url="$(echo "${gtmetrix_result}" | grep -Po '(?<=Report:)[^"]*' | head -1 | cut -d " " -f 2)"

        clear_last_line
        display --indent 2 --text "- Testing project ${URL_TO_TEST}" --result DONE --color GREEN
        display --indent 4 --text "Please check results on ${MAGENTA}${gtmetrix_results_url}${ENDCOLOR}"
        #display --indent 4 --text "Please check results on log file" --tcolor MAGENTA
        log_event "info" "gtmetrix_result: ${gtmetrix_result}"

      fi

    fi

    prompt_return_or_finish
    menu_project_utils

  fi

  menu_main_options

}

function menu_new_project() {

  local project_type_options
  local chosen_project_type_options
  local whip_title
  local whip_description

  whip_title="PROJECT UTILS"
  whip_description=" "

  project_type_options=(
    "01)" "CREATE WP PROJECT"
    "02)" "CREATE LARAVEL PROJECT"
    "03)" "CREATE OTHER PHP PROJECT"
    "04)" "CREATE NODE JS PROJECT"
  )

  chosen_project_type_options="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_type_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} = 0 ]]; then

    if [[ ${chosen_project_type_options} == *"01"* ]]; then

      # WP PROJECT
      project_install "${SITES}" "wordpress"

    fi

    if [[ ${chosen_project_type_options} == *"02"* ]]; then

      # LARAVEL PROJECT
      project_install "${SITES}" "laravel"

    fi

    if [[ ${chosen_project_type_options} == *"03"* ]]; then

      # OTHER PHP PROJECT
      project_install "${SITES}" "php"

    fi

    if [[ ${chosen_project_type_options} == *"04"* ]]; then

      # NODE JS PROJECT
      project_install "${SITES}" "node-js"

    fi

  fi

}

function project_manager_menu() {

  local installation_types
  local project_type

  # Installation types
  installation_types="Laravel,PHP"

  project_type="$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 "$(for x in ${installation_types}; do echo "$x [X]"; done)" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    project_install "${SITES}" "${project_type}"

  fi

  menu_main_options

}
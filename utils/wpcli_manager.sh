#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
################################################################################
#
# WP-CLI Manager: WP-CLI functions manager.
#
################################################################################

################################################################################
# wpcli manager function
#
# Arguments:
#   ${1} = none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_manager() {

  local wpcli_installed
  local wp_site
  local install_path
  local project_path
  local project_install_type

  # Directory Browser
  startdir="${PROJECTS_PATH}"
  menutitle="Site Selection Menu"
  directory_browser "${menutitle}" "${startdir}"

  # If directory browser was cancelled
  [[ -z ${filename} ]] && menu_main_options

  # WP Path
  wp_site="${filepath}/${filename}"

  # Search a WordPress installation on selected directory
  install_path="$(wp_config_path "${wp_site}")"

  project_install_type="$(project_get_install_type "${wp_site}")"

  if [[ ${project_install_type} == "docker"* ]]; then

    # Check if wp-cli service is present on docker-compose.yml
    if grep -q "wordpress-cli:" "${wp_site}/docker-compose.yml"; then
      # Log
      log_event "debug" "wp-cli service found in docker-compose.yml" "false"
    else
      # Log
      log_event "error" "wp-cli service not found in docker-compose.yml" "true"
    fi

  else

    # Check if php is installed
    php_installed="$(php_check_if_installed)"
    if [[ ${php_installed} == "false" ]]; then

      whiptail_message "ERROR" "PHP is not installed. Please install it first."

      # Log
      log_event "debug" "PHP is not installed. Please install it first." "false"

      # Return
      menu_main_options

    fi

    # Install wpcli if not installed
    wpcli_installed="$(wpcli_check_if_installed)"
    if [[ ${wpcli_installed} == "true" ]]; then
      wpcli_update
    else
      # TODO: ask for install?
      wpcli_install
    fi

    

  fi

  # Install_path could return more than one wp installation
  project_path="$(wordpress_select_project_to_work_with "${install_path}")"

  # If project_path is not empty
  if [[ -n ${project_path} ]]; then

    log_event "debug" "Working with ${project_path}" "false"

    # Return
    wpcli_main_menu "${project_path}" "${project_install_type}"

  else

    # Log
    log_event "debug" "project_path=${project_path}" "false"
    log_event "info" "WordPress installation not found!" "false"
    display --indent 6 --text "- Searching WordPress installation" --result "FAIL" --color RED

    whiptail --title "WARNING" --msgbox "WordPress installation not found! Press Enter to return to the Main Menu." 8 78

    # Return
    menu_main_options

  fi

}

################################################################################
# Main menu for wpcli functions
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${project_install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_main_menu() {

  local wp_site="${1}"
  local project_install_type="${2}"

  local wpcli_options
  local chosen_wpcli_options
  local chosen_del_theme_option
  local wp_del_themes

  wpcli_options=(
    # WP CORE
    "01)" "VERIFY WP"
    "02)" "UPDATE WP"
    "03)" "REINSTALL WP"
    "04)" "DELETE NOT CORE FILES"
    # PLUGINS
    "05)" "INSTALL PLUGINS"
    "06)" "LIST INSTALLED PLUGINS"
    "07)" "DELETE PLUGINS"
    "08)" "REINSTALL ALL PLUGINS"
    # USERS
    "09)" "LIST WP USERS"
    "10)" "CREATE WP USER"
    "11)" "DELETE WP USER"
    "12)" "RESET WP USER PASSW"
    # DATABASE
    "13)" "CLEAN WP DB"
    "14)" "CHANGE TABLES PREFIX"
    "15)" "DELETE SPAM COMMENTS"
    "16)" "SCAN DATABASE FOR MALWARE"
    # MAINTENANCE & OPTIMIZATION
    "17)" "REPLACE URLs"
    "18)" "SEOYOAST RE-INDEX"
    "19)" "SHUFFLE SALTS"
    "20)" "SET MAINTENANCE MODE"
    "21)" "PROFILE WP"
    # SECURITY (APP PASSWORDS)
    "22)" "CREATE APP-PASS"
    "23)" "LIST APP-PASS"
    "24)" "DELETE APP-PASS"
    # POSTS CLEANUP
    "25)" "DELETE POSTS (spam/compromised accounts)"
  )

  chosen_wpcli_options="$(whiptail --title "WP-CLI HELPER" --menu "Choose an option to run" 20 78 10 "${wpcli_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # WP CORE - VERIFY WP
    if [[ ${chosen_wpcli_options} == *"01"* ]]; then

      log_subsection "WP Verify"

      wpcli_core_verify "${wp_site}" "${project_install_type}"
      wpcli_plugin_verify "${wp_site}" "${project_install_type}" "all"

    fi

    # WP CORE - UPDATE WP
    [[ ${chosen_wpcli_options} == *"02"* ]] && wpcli_core_update "${wp_site}" "${project_install_type}"

    # WP CORE - REINSTALL WP
    if [[ ${chosen_wpcli_options} == *"03"* ]]; then

      log_subsection "WP Core Re-install"

      wpcli_core_reinstall "${wp_site}" "${project_install_type}" ""
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && send_notification "${SERVER_NAME}" "WordPress re-installed on: ${wp_site}" "info"

    fi

    # WP CORE - DELETE NOT CORE FILES
    if [[ ${chosen_wpcli_options} == *"04"* ]]; then

      log_subsection "WP Delete not-core files"

      echo -e "${B_RED} > This script will delete all non-core wordpress files (except wp-content). Do you want to continue? [y/n]${ENDCOLOR}"
      read -r answer

      if [[ ${answer} == "y" ]]; then

        clear_previous_lines "2"

        wpcli_delete_not_core_files "${wp_site}" "${project_install_type}"

      fi

    fi

    # PLUGINS - INSTALL PLUGINS
    [[ ${chosen_wpcli_options} == *"05"* ]] && wpcli_default_plugins_installer "${wp_site}" "${project_install_type}"

    # PLUGINS - LIST INSTALLED PLUGINS
    [[ ${chosen_wpcli_options} == *"06"* ]] && wpcli_plugin_list "${wp_site}" "${project_install_type}" "" ""

    # PLUGINS - DELETE PLUGINS
    [[ ${chosen_wpcli_options} == *"07"* ]] && wpcli_delete_plugins_menu "${wp_site}" "${project_install_type}"

    # PLUGINS - REINSTALL ALL PLUGINS
    [[ ${chosen_wpcli_options} == *"08"* ]] && wpcli_plugin_reinstall "${wp_site}" "${project_install_type}" "all"

    # USERS - LIST WP USERS
    if [[ ${chosen_wpcli_options} == *"09"* ]]; then

      log_subsection "WP List Users"

      # Ask user to select role filter
      choosen_role="$(whiptail_selection_menu "FILTER BY ROLE" "Choose user role to list (or 'all' for all users):" "all administrator editor author contributor subscriber")"

      if [[ -n ${choosen_role} ]]; then
        wpcli_user_list "${wp_site}" "${project_install_type}" "${choosen_role}"
      fi

    fi

    # USERS - CREATE WP USER
    if [[ ${chosen_wpcli_options} == *"10"* ]]; then

      log_subsection "WP Create User"

      choosen_user="$(whiptail_input "WORDPRESS USERNAME" "Insert a username:" "")"
      if [[ -n ${choosen_user} ]]; then

        choosen_email="$(whiptail_input "WORDPRESS USER MAIL" "Insert the username email:" "")"
        if [[ -n ${choosen_email} ]]; then

          # List options
          choosen_role="$(whiptail_selection_menu "WORDPRESS USER ROLE" "Choose the user role:" "administrator editor author contributor subscriber")"
          [[ -n ${choosen_role} ]] && wpcli_user_create "${wp_site}" "${project_install_type}" "${choosen_user}" "${choosen_email}" "${choosen_role}"

        fi

      fi

    fi

    # USERS - DELETE WP USER
    if [[ ${chosen_wpcli_options} == *"11"* ]]; then

      log_subsection "WP Delete User"

      choosen_user="$(whiptail_input "WORDPRESS USERNAME" "Insert the username to delete:" "")"
      if [[ -n ${choosen_user} ]]; then

        # Confirm deletion
        if whiptail --title "CONFIRM DELETE USER" --yesno "Are you sure you want to delete user '${choosen_user}'? Posts will be reassigned to admin (user ID 1)." 10 60; then
          wpcli_user_delete "${wp_site}" "${project_install_type}" "${choosen_user}"
        fi

      fi

    fi

    # USERS - RESET WP USER PASSW
    if [[ ${chosen_wpcli_options} == *"12"* ]]; then

      log_subsection "WP Reset User Pass"

      choosen_user="$(whiptail --title "WORDPRESS USER" --inputbox "Insert the username you want to reset the password:" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        choosen_passw="$(whiptail --title "WORDPRESS USER PASSWORD" --inputbox "Insert the new password:" 10 60 "" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        [[ ${exitstatus} -eq 0 ]] && wpcli_user_reset_passw "${wp_site}" "${project_install_type}" "${choosen_user}" "${choosen_passw}"

      fi

    fi

    # DATABASE - CLEAN WP DB
    [[ ${chosen_wpcli_options} == *"13"* ]] && wpcli_clean_database "${wp_site}" "${project_install_type}"

    # DATABASE - CHANGE TABLES PREFIX
    if [[ ${chosen_wpcli_options} == *"14"* ]]; then

      log_subsection "WP Change Tables Prefix"

      # Generate WP tables PREFIX
      TABLES_PREFIX="$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)"

      # Change WP tables PREFIX
      wpcli_db_change_tables_prefix "${wp_site}" "${project_install_type}" "${TABLES_PREFIX}"

    fi

    # DATABASE - DELETE SPAM COMMENTS
    if [[ ${chosen_wpcli_options} == *"15"* ]]; then

      log_subsection "WP Delete Spam Comments"

      wpcli_delete_comments "${wp_site}" "${project_install_type}" "spam"
      wpcli_delete_comments "${wp_site}" "${project_install_type}" "hold"

    fi

    # DATABASE - SCAN DATABASE FOR MALWARE
    if [[ ${chosen_wpcli_options} == *"16"* ]]; then

      log_subsection "WP Scan Database for Malware"

      wpcli_wordpress_malware_scan "${wp_site}" "${project_install_type}"

    fi

    # MAINTENANCE - REPLACE URLs
    [[ ${chosen_wpcli_options} == *"17"* ]] && wp_ask_url_search_and_replace "${wp_site}" "${project_install_type}"

    # MAINTENANCE - SEOYOAST REINDEX
    [[ ${chosen_wpcli_options} == *"18"* ]] && wpcli_seoyoast_reindex "${wp_site}" "${project_install_type}"

    # MAINTENANCE - SHUFFLE SALTS
    if [[ ${chosen_wpcli_options} == *"19"* ]]; then

      log_subsection "WP Shuffle Salts"

      wpcli_shuffle_salts "${wp_site}" "${project_install_type}"

    fi

    # MAINTENANCE - SET MAINTENANCE MODE
    if [[ ${chosen_wpcli_options} == *"20"* ]]; then

      choosen_mode="$(whiptail --title "WORDPRESS MAINTENANCE MODE" --inputbox "Set new maintenance mode ('activate', 'deactivate')" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && wpcli_maintenance_mode_set "${wp_site}" "${project_install_type}" "${choosen_mode}"

    fi

    # MAINTENANCE - PROFILE WP
    [[ ${chosen_wpcli_options} == *"21"* ]] && wpcli_profiler_menu "${wp_site}" "${project_install_type}"

    # SECURITY - CREATE APP-PASS
    if [[ ${chosen_wpcli_options} == *"22"* ]]; then

      log_subsection "WP Create Application Password"

      choosen_user="$(whiptail_input "WORDPRESS USERNAME" "Insert a username:" "")"
      if [[ -n ${choosen_user} ]]; then

        choosen_app_name="$(whiptail_input "APPLICATION NAME" "Insert an application name:" "")"
        if [[ -n ${choosen_app_name} ]]; then

          app_pass="$(wpcli_user_create_application_password "${wp_site}" "${project_install_type}" "${choosen_user}" "${choosen_app_name}")"

          whiptail_message "APPLICATION PASSWORD" "The application password is: ${app_pass}"

        fi

      fi

    fi

    # SECURITY - LIST APP-PASS
    if [[ ${chosen_wpcli_options} == *"23"* ]]; then

      log_subsection "WP List Application Passwords"

      choosen_user="$(whiptail_input "WORDPRESS USERNAME" "Insert a username:" "")"
      if [[ -n ${choosen_user} ]]; then

        wpcli_user_list_application_passwords "${wp_site}" "${project_install_type}" "${choosen_user}"

      fi

    fi

    # SECURITY - DELETE APP-PASS
    if [[ ${chosen_wpcli_options} == *"24"* ]]; then

      log_subsection "WP Delete Application Password"

      choosen_user="$(whiptail_input "WORDPRESS USERNAME" "Insert a username:" "")"
      if [[ -n ${choosen_user} ]]; then

        choosen_uuid="$(whiptail_input "APPLICATION UUID" "Insert the application UUID to delete:" "")"
        if [[ -n ${choosen_uuid} ]]; then

          wpcli_user_delete_application_password "${wp_site}" "${project_install_type}" "${choosen_user}" "${choosen_uuid}"

        fi

      fi

    fi

    # MALWARE CLEANUP - DELETE MALICIOUS POSTS
    if [[ ${chosen_wpcli_options} == *"25"* ]]; then
      wpcli_delete_malicious_posts_menu "${wp_site}" "${project_install_type}"
    fi

    prompt_return_or_finish
    wpcli_main_menu "${wp_site}" "${project_install_type}"

  else

    menu_main_options

  fi

}

################################################################################
# wpcli delete plugins menu
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_plugins_menu() {

  local wp_site="${1}"
  local install_type="${2}"

  local wp_del_plugins
  local chosen_del_plugin_option

  # Check project_install_type
  [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
  [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"

  # Listing installed plugins
  wp_del_plugins="$(${wpcli_cmd} --path="${wp_site}" plugin list --quiet --field=name --status=inactive --allow-root)"

  # Log
  log_event "debug" "Running: wp --path=${wp_site} plugin list --quiet --field=name --status=inactive --allow-root" "false"
  log_event "debug" "wp_del_plugins=${wp_del_plugins}" "false"

  # Convert to checklist

  array_to_checklist "${wp_del_plugins}"
  chosen_del_plugin_option="$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to delete:" 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)"

  log_subsection "WP Delete Plugins"

  for plugin_del in ${chosen_del_plugin_option}; do

    plugin_del=$(sed -e 's/^"//' -e 's/"$//' <<<${plugin_del}) #needed to ommit double quotes

    wpcli_plugin_delete "${wp_site}" "${plugin_del}"

  done

}

################################################################################
# wpcli delete themes menu
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_themes_menu() {

  local wp_site="${1}"
  local install_type="${2}"

  local wpcli_cmd
  local wp_del_themes
  local chosen_del_theme_option

  # Check project_install_type
  [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
  [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"

  # Listing installed themes
  wp_del_themes="$(${wpcli_cmd} theme list --quiet --field=name --status=inactive --allow-root)"

  # Log
  log_event "debug" "Running: ${wpcli_cmd} theme list --quiet --field=name --status=inactive --allow-root" "false"
  log_event "debug" "wp_del_themes=${wp_del_themes}" "false"

  # Convert to checklist
  array_to_checklist "${wp_del_themes}"
  chosen_del_theme_option="$(whiptail --title "Theme Selection" --checklist "Select the themes you want to delete." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)"

  log_subsection "WP Delete Themes"

  for theme_del in ${chosen_del_theme_option}; do
    theme_del=$(sed -e 's/^"//' -e 's/"$//' <<<${theme_del}) #need to ommit double quotes
    wpcli_theme_delete "${wp_site}" "${install_type}" "${theme_del}"
  done

}

################################################################################
# wpcli profiler menu
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_profiler_menu() {

  local wp_site="${1}"
  local install_type="${2}"

  local is_installed
  local profiler_options
  local chosen_profiler_option

  log_subsection "WP Profile"

  # Check project_install_type
  [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
  [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"


  is_installed="$(wpcli_check_if_package_is_installed "profile-command")"
  if [[ ${is_installed} == "true" ]]; then
    #https://guides.wp-bullet.com/using-wp-cli-wp-profile-to-diagnose-wordpress-performance-issues/
    ${wpcli_cmd} package install wp-cli/profile-command:@stable --allow-root
  fi

  profiler_options=(
    "01)" "PROFILE STAGE"
    "02)" "PROFILE STAGE BOOTSTRAP"
    "03)" "PROFILE STAGE ALL"
    "04)" "PROFILE STAGE HOOK WP"
    "05)" "PROFILE STAGE HOOK ALL"
  )

  chosen_profiler_option="$(whiptail --title "WP-CLI PROFILER HELPER" --menu "Choose an option to run" 20 78 10 "${profiler_options[@]}" 3>&1 1>&2 2>&3)"

  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_profiler_option} == *"01"* ]]; then
      #This command shows the stages of loading WordPress
      log_event "info" "Executing: ${wpcli_cmd} --path=${wp_site} profile stage --allow-root" "false"
      ${wpcli_cmd} --path="${wp_site}" profile stage --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"02"* ]]; then
      #Can drill down into each stage, here we drill down into the bootstrap stage
      log_event "info" "Executing: ${wpcli_cmd} --path=${wp_site} profile stage bootstrap --allow-root" "false"
      ${wpcli_cmd} --path="${wp_site}" profile stage bootstrap --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"03"* ]]; then
      #All stage
      #You can also use the --spotlight flag to filter out zero-like values for easier reading
      log_event "info" "Executing: ${wpcli_cmd} --path=${wp_site} profile stage --all --spotlight --orderby=time --allow-root" "false"
      ${wpcli_cmd} --path="${wp_site}" profile stage --all --spotlight --orderby=time --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"04"* ]]; then
      #Here we dig into the wp hook
      log_event "info" "Executing: ${wpcli_cmd} --path=${wp_site} profile hook wp --allow-root" "false"
      ${wpcli_cmd} --path="${wp_site}" profile hook wp --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"05"* ]]; then
      #Here we dig into the wp hook
      log_event "info" "Executing: ${wpcli_cmd} --path=${wp_site} profile hook --all --spotlight --allow-root" "false"
      ${wpcli_cmd} --path="${wp_site}" profile hook --all --spotlight --allow-root

    fi

  fi

}

# TODO: Needs refactor
function wpcli_tasks_handler() {

  local subtask="${1}"

  log_subsection "WP-CLI Manager"

  case ${subtask} in

  #create-user)
  #
  #  wpcli_user_create "${PROJECTS_PATH}/${DOMAIN}" "${project_install_type}" "${choosen_user}" "${choosen_email}" "${choosen_role}"
  #
  #  exit
  #  ;;

  plugin-install)

    wpcli_plugin_install "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-activate)

    wpcli_plugin_activate "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-deactivate)

    wpcli_plugin_deactivate "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-version)

    wpcli_plugin_get_version "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-update)

    wpcli_plugin_update "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}" ""

    exit
    ;;

  clear-cache)

    wpcli_rocket_cache_clean "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  cache-activate)

    wpcli_rocket_cache_activate "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  cache-deactivate)

    wpcli_rocket_cache_deactivate "${PROJECTS_PATH}/${DOMAIN}"

    exit
    ;;

  verify-installation)

    # TODO: get install_type
    wpcli_core_verify "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}"
    wpcli_plugin_verify "${PROJECTS_PATH}/${DOMAIN}" "${TVALUE}" ""

    exit
    ;;

  core-update)

    wpcli_core_update "${PROJECTS_PATH}/${DOMAIN}"

    exit
    ;;

    #search-replace)
    #
    #  wpcli_rocket_cache_deactivate "${SITE}" "${existing_URL}" "${new_URL}"
    #
    # exit
    # ;;

  *)

    log_event "error" "INVALID SUBTASK: ${subtask}" "true"

    exit
    ;;

  esac

}

################################################################################
# Delete posts menu (for cleanup of spam, compromised accounts, etc.)
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_malicious_posts_menu() {

  local wp_site="${1}"
  local install_type="${2}"

  local cleanup_options
  local chosen_cleanup_option

  log_subsection "Delete Posts"

  cleanup_options=(
    "01)" "DELETE POSTS BY AUTHOR (username)"
    "02)" "DELETE POSTS BY AUTHOR ID"
    "03)" "DELETE POSTS BY DATE RANGE"
    "04)" "DELETE POSTS BY KEYWORD IN TITLE"
    "05)" "DELETE POSTS BY STATUS (draft/pending/spam)"
    "06)" "LIST RECENT POSTS (last 30 days)"
    "07)" "LIST POSTS BY AUTHOR"
  )

  chosen_cleanup_option="$(whiptail --title "DELETE POSTS" --menu "Choose filtering method:" 20 78 10 "${cleanup_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # DELETE POSTS BY AUTHOR USERNAME
    if [[ ${chosen_cleanup_option} == *"01"* ]]; then
      local author_name
      local post_type

      # Let user select from list of available users
      author_name="$(wpcli_select_user "${wp_site}" "${install_type}")"

      if [[ -n ${author_name} ]]; then
        post_type="$(whiptail_selection_menu "POST TYPE" "Select post type to delete:" "post page any")"

        if [[ -n ${post_type} ]]; then
          wpcli_delete_posts_by_author "${wp_site}" "${install_type}" "${author_name}" "${post_type}"
        fi
      fi
    fi

    # DELETE POSTS BY AUTHOR ID
    if [[ ${chosen_cleanup_option} == *"02"* ]]; then
      local author_name
      local author_id
      local post_type

      # Let user select from list of available users
      author_name="$(wpcli_select_user "${wp_site}" "${install_type}")"

      if [[ -n ${author_name} ]]; then
        # Get the user ID for the selected username
        if [[ ${install_type} == "docker"* ]]; then
          author_id=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp user get "${author_name}" --field=ID 2>/dev/null)
        else
          author_id=$(wp user get "${author_name}" --path="${wp_site}" --field=ID 2>/dev/null)
        fi

        if [[ -n ${author_id} ]]; then
          post_type="$(whiptail_selection_menu "POST TYPE" "Select post type to delete:" "post page any")"

          if [[ -n ${post_type} ]]; then
            wpcli_delete_posts_by_author_id "${wp_site}" "${install_type}" "${author_id}" "${post_type}"
          fi
        fi
      fi
    fi

    # DELETE POSTS BY DATE RANGE
    if [[ ${chosen_cleanup_option} == *"03"* ]]; then
      local start_date
      local end_date
      local post_type

      start_date="$(whiptail_input "START DATE" "Enter start date (YYYY-MM-DD):" "$(date -d '30 days ago' +%Y-%m-%d)")"

      if [[ -n ${start_date} ]]; then
        end_date="$(whiptail_input "END DATE" "Enter end date (YYYY-MM-DD):" "$(date +%Y-%m-%d)")"

        if [[ -n ${end_date} ]]; then
          post_type="$(whiptail_selection_menu "POST TYPE" "Select post type to delete:" "post page any")"

          if [[ -n ${post_type} ]]; then
            wpcli_delete_posts_by_date_range "${wp_site}" "${install_type}" "${start_date}" "${end_date}" "${post_type}"
          fi
        fi
      fi
    fi

    # DELETE POSTS BY KEYWORD IN TITLE
    if [[ ${chosen_cleanup_option} == *"04"* ]]; then
      local keyword
      local post_type

      keyword="$(whiptail_input "KEYWORD" "Enter keyword to search in post titles:" "")"

      if [[ -n ${keyword} ]]; then
        post_type="$(whiptail_selection_menu "POST TYPE" "Select post type to delete:" "post page any")"

        if [[ -n ${post_type} ]]; then
          wpcli_delete_posts_by_keyword "${wp_site}" "${install_type}" "${keyword}" "${post_type}"
        fi
      fi
    fi

    # DELETE POSTS BY STATUS
    if [[ ${chosen_cleanup_option} == *"05"* ]]; then
      local post_status
      local post_type

      post_status="$(whiptail_selection_menu "POST STATUS" "Select post status to delete:" "draft pending spam auto-draft")"

      if [[ -n ${post_status} ]]; then
        post_type="$(whiptail_selection_menu "POST TYPE" "Select post type to delete:" "post page any")"

        if [[ -n ${post_type} ]]; then
          wpcli_delete_posts_by_status "${wp_site}" "${install_type}" "${post_status}" "${post_type}"
        fi
      fi
    fi

    # LIST RECENT POSTS
    if [[ ${chosen_cleanup_option} == *"06"* ]]; then
      wpcli_list_recent_posts "${wp_site}" "${install_type}" "30"
    fi

    # LIST POSTS BY AUTHOR
    if [[ ${chosen_cleanup_option} == *"07"* ]]; then
      local author_name

      # Let user select from list of available users
      author_name="$(wpcli_select_user "${wp_site}" "${install_type}")"

      if [[ -n ${author_name} ]]; then
        wpcli_list_posts_by_author "${wp_site}" "${install_type}" "${author_name}"
      fi
    fi

  fi

}

################################################################################
# Get list of WordPress users and let user select one
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#
# Outputs:
#   Selected username (or empty if cancelled)
################################################################################

function wpcli_select_user() {

  local wp_site="${1}"
  local install_type="${2}"

  local users_list
  local user_options=()
  local selected_user
  local wpcli_result

  log_event "info" "Getting WordPress user list from: ${wp_site}" "false"

  # Get list of users with their roles
  if [[ ${install_type} == "docker"* ]]; then
    log_event "debug" "Running: docker compose -f ${wp_site}/docker-compose.yml run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp user list" "false"

    users_list=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp user list --fields=user_login,display_name,user_email,roles --format=csv 2>&1)
    wpcli_result=$?

    if [[ ${wpcli_result} -ne 0 ]]; then
      log_event "error" "WP-CLI command failed with exit code ${wpcli_result}: ${users_list}" "false"
    fi
  else
    log_event "debug" "Running: wp user list --path=${wp_site}" "false"

    users_list=$(wp user list --path="${wp_site}" --fields=user_login,display_name,user_email,roles --format=csv 2>&1)
    wpcli_result=$?

    if [[ ${wpcli_result} -ne 0 ]]; then
      log_event "error" "WP-CLI command failed with exit code ${wpcli_result}: ${users_list}" "false"
    fi
  fi

  # Check if we got users
  if [[ -z ${users_list} || ${wpcli_result} -ne 0 ]]; then
    display --indent 6 --text "- Getting user list" --result "FAIL" --color RED
    log_event "error" "Failed to get user list from WordPress" "false"
    return 1
  fi

  # Parse CSV and create menu options (skip header line)
  local line_num=0
  while IFS=',' read -r user_login display_name user_email roles; do
    line_num=$((line_num + 1))
    # Skip header
    if [[ ${line_num} -eq 1 ]]; then
      continue
    fi

    # Remove quotes from fields
    user_login="${user_login//\"/}"
    display_name="${display_name//\"/}"
    user_email="${user_email//\"/}"
    roles="${roles//\"/}"

    # Add to options array
    user_options+=("${user_login}" "${display_name} (${user_email}) [${roles}]")
  done <<< "${users_list}"

  # Check if we have any users
  if [[ ${#user_options[@]} -eq 0 ]]; then
    display --indent 6 --text "- Getting user list" --result "EMPTY" --color YELLOW
    log_event "warning" "No users found in WordPress" "false"
    return 1
  fi

  # Show selection menu
  selected_user="$(whiptail --title "SELECT USER" --menu "Choose a user:" 20 78 10 "${user_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 && -n ${selected_user} ]]; then
    echo "${selected_user}"
    return 0
  else
    return 1
  fi

}

################################################################################
# Delete posts by author username
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#  ${3} = ${author_name}
#  ${4} = ${post_type} (post, page, any)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_posts_by_author() {

  local wp_site="${1}"
  local install_type="${2}"
  local author_name="${3}"
  local post_type="${4}"

  local post_count
  local wpcli_result

  log_event "info" "Searching ${post_type} by author: ${author_name}" "false"
  display --indent 6 --text "- Searching ${post_type} by author: ${author_name}"

  # Count posts first
  if [[ ${install_type} == "docker"* ]]; then
    post_count=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --author="${author_name}" --post_type="${post_type}" --format=count --quiet 2>/dev/null)
  else
    post_count=$(wp post list --path="${wp_site}" --author="${author_name}" --post_type="${post_type}" --format=count --quiet 2>/dev/null)
  fi

  if [[ -z ${post_count} || ${post_count} -eq 0 ]]; then
    display --indent 8 --text "No ${post_type} found for author: ${author_name}" --tcolor YELLOW
    log_event "info" "No ${post_type} found for author: ${author_name}" "false"
    return 0
  fi

  display --indent 8 --text "Found ${post_count} ${post_type} by '${author_name}'" --tcolor RED

  # Show confirmation
  if whiptail --title "CONFIRM DELETION" --yesno "Found ${post_count} ${post_type} by author '${author_name}'.\n\nAre you sure you want to DELETE ALL these ${post_type}?\n\nThis action CANNOT be undone!" 14 70; then

    log_event "warning" "Deleting ${post_count} ${post_type} by author: ${author_name}" "false"

    # Delete posts
    if [[ ${install_type} == "docker"* ]]; then
      # First get the post IDs
      post_ids=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --author="${author_name}" --post_type="${post_type}" --format=ids --quiet 2>&1)
      # Then delete them
      wpcli_result=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post delete "${post_ids}" --force --quiet 2>&1)
    else
      post_ids=$(wp post list --path="${wp_site}" --author="${author_name}" --post_type="${post_type}" --format=ids --quiet)
      wpcli_result=$(wp post delete "${post_ids}" --force --path="${wp_site}" --quiet 2>&1)
    fi

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      display --indent 6 --text "- Deleting ${post_type} by author '${author_name}'" --result "DONE" --color GREEN
      log_event "success" "Deleted ${post_count} ${post_type} by author: ${author_name}" "false"
    else
      display --indent 6 --text "- Deleting ${post_type} by author '${author_name}'" --result "FAIL" --color RED
      log_event "error" "Failed to delete ${post_type}: ${wpcli_result}" "false"
      return 1
    fi

  else
    display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
    log_event "info" "Post deletion cancelled by user" "false"
  fi

}

################################################################################
# Delete posts by author ID
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#  ${3} = ${author_id}
#  ${4} = ${post_type} (post, page, any)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_posts_by_author_id() {

  local wp_site="${1}"
  local install_type="${2}"
  local author_id="${3}"
  local post_type="${4}"

  local post_count
  local wpcli_result

  log_event "info" "Searching ${post_type} by author ID: ${author_id}" "false"
  display --indent 6 --text "- Searching ${post_type} by author ID: ${author_id}"

  # Count posts first
  if [[ ${install_type} == "docker"* ]]; then
    post_count=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --author="${author_id}" --post_type="${post_type}" --format=count --quiet 2>/dev/null)
  else
    post_count=$(wp post list --path="${wp_site}" --author="${author_id}" --post_type="${post_type}" --format=count --quiet 2>/dev/null)
  fi

  if [[ -z ${post_count} || ${post_count} -eq 0 ]]; then
    display --indent 8 --text "No ${post_type} found for author ID: ${author_id}" --tcolor YELLOW
    log_event "info" "No ${post_type} found for author ID: ${author_id}" "false"
    return 0
  fi

  display --indent 8 --text "Found ${post_count} ${post_type} by author ID '${author_id}'" --tcolor RED

  # Show confirmation
  if whiptail --title "CONFIRM DELETION" --yesno "Found ${post_count} ${post_type} by author ID '${author_id}'.\n\nAre you sure you want to DELETE ALL these ${post_type}?\n\nThis action CANNOT be undone!" 14 70; then

    log_event "warning" "Deleting ${post_count} ${post_type} by author ID: ${author_id}" "false"

    # Delete posts
    if [[ ${install_type} == "docker"* ]]; then
      # First get the post IDs
      post_ids=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --author="${author_id}" --post_type="${post_type}" --format=ids --quiet 2>&1)
      # Then delete them
      wpcli_result=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post delete "${post_ids}" --force --quiet 2>&1)
    else
      post_ids=$(wp post list --path="${wp_site}" --author="${author_id}" --post_type="${post_type}" --format=ids --quiet)
      wpcli_result=$(wp post delete "${post_ids}" --force --path="${wp_site}" --quiet 2>&1)
    fi

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      display --indent 6 --text "- Deleting ${post_type} by author ID '${author_id}'" --result "DONE" --color GREEN
      log_event "success" "Deleted ${post_count} ${post_type} by author ID: ${author_id}" "false"
    else
      display --indent 6 --text "- Deleting ${post_type} by author ID '${author_id}'" --result "FAIL" --color RED
      log_event "error" "Failed to delete ${post_type}: ${wpcli_result}" "false"
      return 1
    fi

  else
    display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
    log_event "info" "Post deletion cancelled by user" "false"
  fi

}

################################################################################
# Delete posts by date range
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#  ${3} = ${start_date} (YYYY-MM-DD)
#  ${4} = ${end_date} (YYYY-MM-DD)
#  ${5} = ${post_type} (post, page, any)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_posts_by_date_range() {

  local wp_site="${1}"
  local install_type="${2}"
  local start_date="${3}"
  local end_date="${4}"
  local post_type="${5}"

  local post_count
  local wpcli_result

  log_event "info" "Searching ${post_type} between ${start_date} and ${end_date}" "false"
  display --indent 6 --text "- Searching ${post_type} from ${start_date} to ${end_date}"

  # Count posts first
  if [[ ${install_type} == "docker"* ]]; then
    post_count=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --post_type="${post_type}" --post_status=any --after="${start_date}" --before="${end_date}" --format=count --quiet 2>/dev/null)
  else
    post_count=$(wp post list --path="${wp_site}" --post_type="${post_type}" --post_status=any --after="${start_date}" --before="${end_date}" --format=count --quiet 2>/dev/null)
  fi

  if [[ -z ${post_count} || ${post_count} -eq 0 ]]; then
    display --indent 8 --text "No ${post_type} found in this date range" --tcolor YELLOW
    log_event "info" "No ${post_type} found between ${start_date} and ${end_date}" "false"
    return 0
  fi

  display --indent 8 --text "Found ${post_count} ${post_type} in date range" --tcolor RED

  # Show confirmation
  if whiptail --title "CONFIRM DELETION" --yesno "Found ${post_count} ${post_type} between ${start_date} and ${end_date}.\n\nAre you sure you want to DELETE ALL these ${post_type}?\n\nThis action CANNOT be undone!" 14 70; then

    log_event "warning" "Deleting ${post_count} ${post_type} from ${start_date} to ${end_date}" "false"

    # Delete posts
    if [[ ${install_type} == "docker"* ]]; then
      # First get the post IDs
      post_ids=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --post_type="${post_type}" --post_status=any --after="${start_date}" --before="${end_date}" --format=ids --quiet 2>&1)
      # Then delete them
      wpcli_result=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post delete "${post_ids}" --force --quiet 2>&1)
    else
      post_ids=$(wp post list --path="${wp_site}" --post_type="${post_type}" --post_status=any --after="${start_date}" --before="${end_date}" --format=ids --quiet)
      wpcli_result=$(wp post delete "${post_ids}" --force --path="${wp_site}" --quiet 2>&1)
    fi

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      display --indent 6 --text "- Deleting ${post_type} by date range" --result "DONE" --color GREEN
      log_event "success" "Deleted ${post_count} ${post_type} from ${start_date} to ${end_date}" "false"
    else
      display --indent 6 --text "- Deleting ${post_type} by date range" --result "FAIL" --color RED
      log_event "error" "Failed to delete ${post_type}: ${wpcli_result}" "false"
      return 1
    fi

  else
    display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
    log_event "info" "Post deletion cancelled by user" "false"
  fi

}

################################################################################
# Delete posts by keyword in title
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#  ${3} = ${keyword}
#  ${4} = ${post_type} (post, page, any)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_posts_by_keyword() {

  local wp_site="${1}"
  local install_type="${2}"
  local keyword="${3}"
  local post_type="${4}"

  local post_count
  local wpcli_result

  log_event "info" "Searching ${post_type} with keyword: ${keyword}" "false"
  display --indent 6 --text "- Searching ${post_type} with keyword: '${keyword}'"

  # Count posts first
  if [[ ${install_type} == "docker"* ]]; then
    post_count=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --post_type="${post_type}" --s="${keyword}" --format=count --quiet 2>/dev/null)
  else
    post_count=$(wp post list --path="${wp_site}" --post_type="${post_type}" --s="${keyword}" --format=count --quiet 2>/dev/null)
  fi

  if [[ -z ${post_count} || ${post_count} -eq 0 ]]; then
    display --indent 8 --text "No ${post_type} found with keyword: ${keyword}" --tcolor YELLOW
    log_event "info" "No ${post_type} found with keyword: ${keyword}" "false"
    return 0
  fi

  display --indent 8 --text "Found ${post_count} ${post_type} with keyword '${keyword}'" --tcolor RED

  # Show confirmation
  if whiptail --title "CONFIRM DELETION" --yesno "Found ${post_count} ${post_type} containing '${keyword}'.\n\nAre you sure you want to DELETE ALL these ${post_type}?\n\nThis action CANNOT be undone!" 14 70; then

    log_event "warning" "Deleting ${post_count} ${post_type} with keyword: ${keyword}" "false"

    # Delete posts
    if [[ ${install_type} == "docker"* ]]; then
      # First get the post IDs
      post_ids=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --post_type="${post_type}" --s="${keyword}" --format=ids --quiet 2>&1)
      # Then delete them
      wpcli_result=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post delete "${post_ids}" --force --quiet 2>&1)
    else
      post_ids=$(wp post list --path="${wp_site}" --post_type="${post_type}" --s="${keyword}" --format=ids --quiet)
      wpcli_result=$(wp post delete "${post_ids}" --force --path="${wp_site}" --quiet 2>&1)
    fi

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      display --indent 6 --text "- Deleting ${post_type} with keyword '${keyword}'" --result "DONE" --color GREEN
      log_event "success" "Deleted ${post_count} ${post_type} with keyword: ${keyword}" "false"
    else
      display --indent 6 --text "- Deleting ${post_type} with keyword '${keyword}'" --result "FAIL" --color RED
      log_event "error" "Failed to delete ${post_type}: ${wpcli_result}" "false"
      return 1
    fi

  else
    display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
    log_event "info" "Post deletion cancelled by user" "false"
  fi

}

################################################################################
# Delete posts by status
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#  ${3} = ${post_status}
#  ${4} = ${post_type} (post, page, any)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_delete_posts_by_status() {

  local wp_site="${1}"
  local install_type="${2}"
  local post_status="${3}"
  local post_type="${4}"

  local post_count
  local wpcli_result

  log_event "info" "Searching ${post_type} with status: ${post_status}" "false"
  display --indent 6 --text "- Searching ${post_type} with status: ${post_status}"

  # Count posts first
  if [[ ${install_type} == "docker"* ]]; then
    post_count=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --post_type="${post_type}" --post_status="${post_status}" --format=count --quiet 2>/dev/null)
  else
    post_count=$(wp post list --path="${wp_site}" --post_type="${post_type}" --post_status="${post_status}" --format=count --quiet 2>/dev/null)
  fi

  if [[ -z ${post_count} || ${post_count} -eq 0 ]]; then
    display --indent 8 --text "No ${post_type} found with status: ${post_status}" --tcolor YELLOW
    log_event "info" "No ${post_type} found with status: ${post_status}" "false"
    return 0
  fi

  display --indent 8 --text "Found ${post_count} ${post_type} with status '${post_status}'" --tcolor RED

  # Show confirmation
  if whiptail --title "CONFIRM DELETION" --yesno "Found ${post_count} ${post_type} with status '${post_status}'.\n\nAre you sure you want to DELETE ALL these ${post_type}?\n\nThis action CANNOT be undone!" 14 70; then

    log_event "warning" "Deleting ${post_count} ${post_type} with status: ${post_status}" "false"

    # Delete posts
    if [[ ${install_type} == "docker"* ]]; then
      # First get the post IDs
      post_ids=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --post_type="${post_type}" --post_status="${post_status}" --format=ids --quiet 2>&1)
      # Then delete them
      wpcli_result=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post delete "${post_ids}" --force --quiet 2>&1)
    else
      post_ids=$(wp post list --path="${wp_site}" --post_type="${post_type}" --post_status="${post_status}" --format=ids --quiet)
      wpcli_result=$(wp post delete "${post_ids}" --force --path="${wp_site}" --quiet 2>&1)
    fi

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      display --indent 6 --text "- Deleting ${post_type} with status '${post_status}'" --result "DONE" --color GREEN
      log_event "success" "Deleted ${post_count} ${post_type} with status: ${post_status}" "false"
    else
      display --indent 6 --text "- Deleting ${post_type} with status '${post_status}'" --result "FAIL" --color RED
      log_event "error" "Failed to delete ${post_type}: ${wpcli_result}" "false"
      return 1
    fi

  else
    display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
    log_event "info" "Post deletion cancelled by user" "false"
  fi

}

################################################################################
# List recent posts
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#  ${3} = ${days} (number of days to look back)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_list_recent_posts() {

  local wp_site="${1}"
  local install_type="${2}"
  local days="${3}"

  local start_date
  local wpcli_result

  start_date=$(date -d "${days} days ago" +%Y-%m-%d)

  log_event "info" "Listing posts from last ${days} days (since ${start_date})" "false"
  display --indent 6 --text "- Listing posts from last ${days} days"

  # List posts
  if [[ ${install_type} == "docker"* ]]; then
    wpcli_result=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --after="${start_date}" --format=table --fields=ID,post_date,post_author,post_title,post_status 2>&1)
  else
    wpcli_result=$(wp post list --path="${wp_site}" --after="${start_date}" --format=table --fields=ID,post_date,post_author,post_title,post_status 2>&1)
  fi

  echo ""
  echo "${wpcli_result}"
  echo ""

  log_event "info" "Listed recent posts" "false"

}

################################################################################
# List posts by author
#
# Arguments:
#  ${1} = ${wp_site}
#  ${2} = ${install_type}
#  ${3} = ${author_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_list_posts_by_author() {

  local wp_site="${1}"
  local install_type="${2}"
  local author_name="${3}"

  local wpcli_result

  log_event "info" "Listing posts by author: ${author_name}" "false"
  display --indent 6 --text "- Listing posts by author: ${author_name}"

  # List posts
  if [[ ${install_type} == "docker"* ]]; then
    wpcli_result=$(docker compose -f "${wp_site}/docker-compose.yml" run -T --rm -u 33 -e HOME=/tmp wordpress-cli wp post list --author="${author_name}" --format=table --fields=ID,post_date,post_title,post_status 2>&1)
  else
    wpcli_result=$(wp post list --path="${wp_site}" --author="${author_name}" --format=table --fields=ID,post_date,post_title,post_status 2>&1)
  fi

  echo ""
  echo "${wpcli_result}"
  echo ""

  log_event "info" "Listed posts by author: ${author_name}" "false"

}


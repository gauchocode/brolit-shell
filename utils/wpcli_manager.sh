#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
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
    "01)" "INSTALL PLUGINS"
    "02)" "LIST INSTALLED PLUGINS"
    "03)" "DELETE PLUGINS"
    "04)" "REINSTALL ALL PLUGINS"
    "05)" "VERIFY WP"
    "06)" "UPDATE WP"
    "07)" "REINSTALL WP"
    "08)" "CLEAN WP DB"
    "09)" "PROFILE WP"
    "10)" "CHANGE TABLES PREFIX"
    "11)" "REPLACE URLs"
    "12)" "SEOYOAST RE-INDEX"
    "13)" "DELETE NOT CORE FILES"
    "14)" "LIST WP USERS"
    "15)" "CREATE WP USER"
    "16)" "RESET WP USER PASSW"
    "17)" "SHUFFLE SALTS"
    "18)" "DELETE SPAM COMMENTS"
    "19)" "SET MAINTENANCE MODE"
  )

  chosen_wpcli_options="$(whiptail --title "WP-CLI HELPER" --menu "Choose an option to run" 20 78 10 "${wpcli_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # INSTALL PLUGINS
    [[ ${chosen_wpcli_options} == *"01"* ]] && wpcli_default_plugins_installer "${wp_site}" "${project_install_type}"

    # LIST INSTALLED PLUGINS
    [[ ${chosen_wpcli_options} == *"02"* ]] && wpcli_plugin_list "${wp_site}" "${project_install_type}" "" ""

    # DELETE THEMES
    #[[ ${chosen_wpcli_options} == *"02"* ]] && wpcli_delete_themes_menu "${wp_site}" "${project_install_type}"

    # DELETE_PLUGINS
    [[ ${chosen_wpcli_options} == *"03"* ]] && wpcli_delete_plugins_menu "${wp_site}" "${project_install_type}"

    # RE-INSTALL_PLUGINS
    [[ ${chosen_wpcli_options} == *"04"* ]] && wpcli_plugin_reinstall "${wp_site}" "all"

    # VERIFY_WP
    if [[ ${chosen_wpcli_options} == *"05"* ]]; then

      log_subsection "WP Verify"

      wpcli_core_verify "${wp_site}" "${project_install_type}"
      wpcli_plugin_verify "${wp_site}" "${project_install_type}" "all"

    fi

    # UPDATE_WP
    [[ ${chosen_wpcli_options} == *"06"* ]] && wpcli_core_update "${wp_site}" "${project_install_type}"

    # REINSTALL_WP
    if [[ ${chosen_wpcli_options} == *"07"* ]]; then

      log_subsection "WP Core Re-install"

      wpcli_core_reinstall "${wp_site}" "${project_install_type}" ""
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && send_notification "⚠️ ${SERVER_NAME}" "WordPress re-installed on: ${wp_site}"

    fi

    # CLEAN_DB
    [[ ${chosen_wpcli_options} == *"08"* ]] && wpcli_clean_database "${wp_site}" "${project_install_type}"

    # PROFILE_WP
    [[ ${chosen_wpcli_options} == *"09"* ]] && wpcli_profiler_menu "${wp_site}" "${project_install_type}"

    # CHANGE_TABLES_PREFIX
    if [[ ${chosen_wpcli_options} == *"10"* ]]; then

      log_subsection "WP Change Tables Prefix"

      # Generate WP tables PREFIX
      TABLES_PREFIX="$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)"

      # Change WP tables PREFIX
      wpcli_db_change_tables_prefix "${wp_site}" "${project_install_type}" "${TABLES_PREFIX}"

    fi

    # REPLACE_URLs
    [[ ${chosen_wpcli_options} == *"11"* ]] && wp_ask_url_search_and_replace "${wp_site}" "${project_install_type}"

    # SEOYOAST_REINDEX
    [[ ${chosen_wpcli_options} == *"12"* ]] && wpcli_seoyoast_reindex "${wp_site}" "${project_install_type}"

    # DELETE_NOT_CORE_FILES
    if [[ ${chosen_wpcli_options} == *"13"* ]]; then

      log_subsection "WP Delete not-core files"

      echo -e "${B_RED} > This script will delete all non-core wordpress files (except wp-content). Do you want to continue? [y/n]${ENDCOLOR}"
      read -r answer

      if [[ ${answer} == "y" ]]; then

        clear_previous_lines "2"

        wpcli_delete_not_core_files "${wp_site}" "${project_install_type}"

      fi

    fi

    # LIST WP USERS
    if [[ ${chosen_wpcli_options} == *"14"* ]]; then

      log_subsection "WP List Users"
      wpcli_user_list "${wp_site}" "${project_install_type}" 

    fi

    # CREATE WP USER
    if [[ ${chosen_wpcli_options} == *"15"* ]]; then

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

    # RESET WP USER PASSW
    if [[ ${chosen_wpcli_options} == *"16"* ]]; then

      log_subsection "WP Reset User Pass"

      choosen_user="$(whiptail --title "WORDPRESS USER" --inputbox "Insert the username you want to reset the password:" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        choosen_passw="$(whiptail --title "WORDPRESS USER PASSWORD" --inputbox "Insert the new password:" 10 60 "" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        [[ ${exitstatus} -eq 0 ]] && wpcli_user_reset_passw "${wp_site}" "${project_install_type}" "${choosen_user}" "${choosen_passw}"

      fi

    fi

    # SHUFLE SALTS
    if [[ ${chosen_wpcli_options} == *"17"* ]]; then

      log_subsection "WP Shuffle Salts"

      wpcli_shuffle_salts "${wp_site}" "${project_install_type}"

    fi

    # DELETE SPAM COMMENTS
    if [[ ${chosen_wpcli_options} == *"18"* ]]; then

      log_subsection "WP Delete Spam Comments"

      wpcli_delete_comments "${wp_site}" "${project_install_type}" "spam"
      wpcli_delete_comments "${wp_site}" "${project_install_type}" "hold"

    fi

    if [[ ${chosen_wpcli_options} == *"19"* ]]; then

      choosen_mode="$(whiptail --title "WORDPRESS MAINTENANCE MODE" --inputbox "Set new maintenance mode (‘activate’, ‘deactivate’)" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && wpcli_maintenance_mode_set "${wp_site}" "${project_install_type}" "${choosen_mode}"

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
  [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"

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
  [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"

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
  [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"


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

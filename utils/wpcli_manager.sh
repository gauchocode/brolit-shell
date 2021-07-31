#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.52
################################################################################
#
# WP-CLI Manager: WP-CLI functions manager.
#
################################################################################

function wpcli_manager() {

  local wpcli_installed
  local wp_site
  local chosen_wp_path

  # Directory Browser
  startdir="${SITES}"
  menutitle="Site Selection Menu"
  directory_browser "${menutitle}" "${startdir}"

  # If directory browser was cancelled
  if [[ -z ${filename} ]]; then

    # Return
    menu_main_options

  else

    # Install wpcli if not installed
    wpcli_installed="$(wpcli_check_if_installed)"
    if [[ ${wpcli_installed} == "true" ]]; then
      wpcli_update
    else
      wpcli_install
    fi

    # WP Path
    wp_site="${filepath}/${filename}"

    # Search a WordPress installation on selected directory
    install_path="$(wp_config_path "${wp_site}")"

    # Install_path could return more than one wp installation
    project_path="$(wordpress_select_project_to_work_with "${install_path}")"

    if [[ ${project_path} != '' ]]; then

      log_event "debug" "Working with ${project_path}" "false"

      # Return
      wpcli_main_menu "${project_path}"

    else

      log_event "info" "WordPress installation not found! Returning to Main Menu" "false"
      display --indent 2 --text "- Searching WordPress installation" --result "FAIL" --color RED

      whiptail --title "WARNING" --msgbox "WordPress installation not found! Press Enter to return to the Main Menu." 8 78

      # Return
      menu_main_options

    fi

  fi

}

function wpcli_main_menu() {

  # $1 = ${wp_site}

  local wp_site=$1

  local wpcli_options
  local wp_result
  local chosen_wpcli_options
  local chosen_del_theme_option
  local wp_del_themes

  wpcli_options=(
    "01)" "INSTALL PLUGINS"
    "02)" "DELETE THEMES"
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
    "14)" "CREATE WP USER"
    "15)" "RESET WP USER PASSW"
  )

  chosen_wpcli_options="$(whiptail --title "WP-CLI HELPER" --menu "Choose an option to run" 20 78 10 "${wpcli_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_wpcli_options} == *"01"* ]]; then

      wpcli_default_plugins_installer

    fi

    if [[ ${chosen_wpcli_options} == *"02"* ]]; then

      # DELETE_THEMES

      # Listing installed themes
      wp_del_themes="$(wp --path="${wp_site}" theme list --quiet --field=name --status=inactive --allow-root)"
      array_to_checklist "${wp_del_themes}"
      chosen_del_theme_option="$(whiptail --title "Theme Selection" --checklist "Select the themes you want to delete." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)"

      log_subsection "WP Delete Themes"

      for theme_del in ${chosen_del_theme_option}; do
        theme_del=$(sed -e 's/^"//' -e 's/"$//' <<<${theme_del}) #needed to ommit double quotes
        #echo "theme delete $theme_del"
        wpcli_theme_delete "${wp_site}" "${theme_del}"
      done

    fi
    if [[ ${chosen_wpcli_options} == *"03"* ]]; then

      # DELETE_PLUGINS

      # Listing installed plugins
      wp_del_plugins="$(wp --path="${wp_site}" plugin list --quiet --field=name --status=inactive --allow-root)"
      array_to_checklist "${wp_del_plugins}"
      chosen_del_plugin_option="$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to delete:" 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)"

      log_subsection "WP Delete Plugins"

      for plugin_del in ${chosen_del_plugin_option}; do

        plugin_del=$(sed -e 's/^"//' -e 's/"$//' <<<${plugin_del}) #needed to ommit double quotes

        wpcli_plugin_delete "${wp_site}" "${plugin_del}"

      done

    fi

    if [[ ${chosen_wpcli_options} == *"04"* ]]; then

      #REINSTALL_PLUGINS

      log_subsection "WP Re-install Plugins"

      wpcli_force_reinstall_plugins "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"05"* ]]; then

      # VERIFY_WP
      log_subsection "WP Verify"

      wpcli_core_verify "${wp_site}"
      wpcli_plugin_verify "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"06"* ]]; then

      # UPDATE_WP
      log_subsection "WP Core Update"

      wpcli_core_update "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"07"* ]]; then

      # REINSTALL_WP
      log_subsection "WP Core Re-install"

      wp_result="$(wpcli_core_reinstall "${wp_site}")"
      if [[ "${wp_result}" = "success" ]]; then

        send_notification "⚠️ ${VPSNAME}" "WordPress re-installed on: ${wp_site}"

      fi

    fi

    if [[ ${chosen_wpcli_options} == *"08"* ]]; then

      # CLEAN_DB
      log_subsection "WP Clean Database"

      wpcli_clean_database "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"09"* ]]; then

      # PROFILE_WP
      log_subsection "WP Profile"

      wpcli_profiler_menu "${wp_site}"

    fi
    if [[ ${chosen_wpcli_options} == *"10"* ]]; then

      # CHANGE_TABLES_PREFIX
      log_subsection "WP Change Tables Prefix"

      # Generate WP tables PREFIX
      TABLES_PREFIX="$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)"

      # Change WP tables PREFIX
      wpcli_change_tables_prefix "${wp_site}" "${TABLES_PREFIX}"

    fi
    if [[ ${chosen_wpcli_options} == *"11"* ]]; then

      # REPLACE_URLs
      log_subsection "WP Replace URLs"

      wp_ask_url_search_and_replace "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"12"* ]]; then

      # SEOYOAST_REINDEX
      log_subsection "WP SEO Yoast Re-index"

      wpcli_seoyoast_reindex "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"13"* ]]; then

      # DELETE_NOT_CORE_FILES
      log_subsection "WP Delete not-core files"

      echo -e "${B_RED} > This script will delete all non-core wordpress files (except wp-content). Do you want to continue? [y/n]${ENDCOLOR}"
      read -r answer

      if [[ ${answer} == "y" ]]; then
        wpcli_delete_not_core_files "${wp_site}"

      fi

    fi

    if [[ ${chosen_wpcli_options} == *"14"* ]]; then

      log_subsection "WP Create User"

      choosen_user="$(whiptail --title "WORDPRESS USER" --inputbox "Insert the username you want:" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        choosen_email="$(whiptail --title "WORDPRESS USER MAIL" --inputbox "Insert the username email:" 10 60 "" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          choosen_role="$(whiptail --title "WORDPRESS USER ROLE" --inputbox "Insert the user role (‘administrator’, ‘editor’, ‘author’, ‘contributor’, ‘subscriber’)" 10 60 "" 3>&1 1>&2 2>&3)"
          exitstatus=$?
          if [[ ${exitstatus} -eq 0 ]]; then

            wpcli_user_create "${wp_site}" "${choosen_user}" "${choosen_email}" "${choosen_role}"

          fi

        fi

      fi

    fi

    if [[ ${chosen_wpcli_options} == *"15"* ]]; then

      # RESET WP USER PASSW
      log_subsection "WP Reset User Pass"

      choosen_user="$(whiptail --title "WORDPRESS USER" --inputbox "Insert the username you want:" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        choosen_passw="$(whiptail --title "WORDPRESS USER PASSWORD" --inputbox "Insert the new password:" 10 60 "" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          wpcli_user_reset_passw "${wp_site}" "${choosen_user}" "${choosen_passw}"

        fi

      fi

    fi

    prompt_return_or_finish
    wpcli_main_menu "${wp_site}"

  else

    menu_main_options

  fi

}

function wpcli_profiler_menu() {

  # $1 = ${wp_site}

  local wp_site=$1

  local is_installed
  local profiler_options
  local chosen_profiler_option

  is_installed="$(wpcli_check_if_package_is_installed "profile-command")"
  if [[ ${is_installed} == "true" ]]; then
    #https://guides.wp-bullet.com/using-wp-cli-wp-profile-to-diagnose-wordpress-performance-issues/
    wp package install wp-cli/profile-command:@stable --allow-root
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
      log_event "info" "Executing: wp --path=${wp_site} profile stage --allow-root" "false"
      wp --path="${wp_site}" profile stage --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"02"* ]]; then
      #Can drill down into each stage, here we drill down into the bootstrap stage
      log_event "info" "Executing: wp --path=${wp_site} profile stage bootstrap --allow-root" "false"
      wp --path="${wp_site}" profile stage bootstrap --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"03"* ]]; then
      #All stage
      #You can also use the --spotlight flag to filter out zero-like values for easier reading
      log_event "info" "Executing: wp --path=${wp_site} profile stage --all --spotlight --orderby=time --allow-root" "false"
      wp --path="${wp_site}" profile stage --all --spotlight --orderby=time --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"04"* ]]; then
      #Here we dig into the wp hook
      log_event "info" "Executing: wp --path=${wp_site} profile hook wp --allow-root" "false"
      wp --path="${wp_site}" profile hook wp --allow-root

    fi
    if [[ ${chosen_profiler_option} == *"05"* ]]; then
      #Here we dig into the wp hook
      log_event "info" "Executing: wp --path=${wp_site} profile hook --all --spotlight --allow-root" "false"
      wp --path="${wp_site}" profile hook --all --spotlight --allow-root

    fi

  fi

}

function wpcli_tasks_handler() {

  local subtask=$1

  log_subsection "WP-CLI Manager"

  case ${subtask} in

  #create-user)
  #
  #  wpcli_user_create "${SITES}/${DOMAIN}" "${choosen_user}" "${choosen_email}" "${choosen_role}"
  #
  #  exit
  #  ;;

  plugin-install)

    wpcli_install_plugin "${SITES}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-activate)

    wpcli_plugin_activate "${SITES}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-deactivate)

    wpcli_plugin_deactivate "${SITES}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-version)

    wpcli_plugin_get_version "${SITES}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  plugin-update)

    wpcli_plugin_update "${SITES}/${DOMAIN}" "${TVALUE}"

    exit
    ;;

  clear-cache)

    wpcli_rocket_cache_clean "${SITES}/${DOMAIN}"

    exit
    ;;

  cache-activate)

    wpcli_rocket_cache_activate "${SITES}/${DOMAIN}"

    exit
    ;;

  cache-deactivate)

    wpcli_rocket_cache_deactivate "${SITES}/${DOMAIN}"

    exit
    ;;

  verify-installation)

    wpcli_core_verify "${SITES}/${DOMAIN}"
    wpcli_plugin_verify "${SITES}/${DOMAIN}"

    exit
    ;;

  core-update)

    wpcli_core_update "${SITES}/${DOMAIN}"

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

#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc10
################################################################################
#
# Ref: https://kinsta.com/blog/wp-cli/
#
# TODO: option to profile specific URL:
# Ex: php /var/www/.wp-cli/wp-cli.phar --path=/var/www/dev.bes-ebike.com/ profile hook --all --spotlight --url=https://dev.bes-ebike.com/shop-electric-bikes/ --allow-root
#
# TODO: check if is network project: https://developer.wordpress.org/cli/commands/core/is-installed/
#
# TODO: Healthchecks with wp doctor
# Ref: https://guides.wp-bullet.com/automating-wordpress-health-checks-with-wp-cli-doctor-command/

################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"
# shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
source "${SFOLDER}/libs/wordpress_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
source "${SFOLDER}/libs/telegram_notification_helper.sh"

################################################################################

wpcli_main_menu() {

  # $1 = ${wp_site}

  local wp_site=$1

  local wpcli_options wp_result chosen_wpcli_options wp_plugins chosen_plugin_option

  # Array of plugin slugs to install
  wp_plugins=(
    "wordpress-seo" " " off
    "duracelltomi-google-tag-manager" " " off
    "ewww-image-optimizer" " " off
    "post-smtp" " " off
    "contact-form-7" " " off
    "advanced-custom-fields" " " off
    "acf-vc-integrator" " " off
    "w3-total-cache" " " off
    "fast-velocity-minify" " " off
    "iwp-client" " " off
    "fresh-plugins" " " off
    "wordfence" " " off
    "better-wp-security" " " off
    "quttera-web-malware-scanner" " " off
  )

  wpcli_options="01 INSTALL_PLUGINS 02 DELETE_THEMES 03 DELETE_PLUGINS 04 REINSTALL_ALL_PLUGINS 05 VERIFY_WP 06 UPDATE_WP 07 REINSTALL_WP 08 CLEAN_WP_DB 09 PROFILE_WP 10 CHANGE_TABLES_PREFIX 11 REPLACE_URLs 12 SEOYOAST_REINDEX 13 DELETE_NOT_CORE_FILES"
  chosen_wpcli_options=$(whiptail --title "WP-CLI HELPER" --menu "Choose an option to run" 20 78 10 $(for x in ${wpcli_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${chosen_wpcli_options} == *"01"* ]]; then

      # INSTALL_PLUGINS
      chosen_plugin_option=$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to install." 20 78 15 "${wp_plugins[@]}" 3>&1 1>&2 2>&3)

      for plugin in $chosen_plugin_option; do

        wpcli_install_plugin "${wp_site}" "$plugin"

      done

    fi

    if [[ ${chosen_wpcli_options} == *"02"* ]]; then

      # DELETE_THEMES

      # Listing installed themes
      WP_DEL_THEMES=$(wp --path="${wp_site}" theme list --quiet --field=name --status=inactive --allow-root)
      array_to_checklist "$WP_DEL_THEMES"
      CHOSEN_DEL_THEME_OPTION=$(whiptail --title "Theme Selection" --checklist "Select the themes you want to delete." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)
      #echo "Setting CHOSEN_DEL_THEME_OPTION="$CHOSEN_DEL_THEME_OPTION

      for theme_del in $CHOSEN_DEL_THEME_OPTION; do
        theme_del=$(sed -e 's/^"//' -e 's/"$//' <<<$theme_del) #needed to ommit double quotes
        echo "theme delete $theme_del"
        wpcli_delete_theme "${wp_site}" "$theme_del"
      done

    fi
    if [[ ${chosen_wpcli_options} == *"03"* ]]; then

      # DELETE_PLUGINS

      # Listing installed plugins
      wp_del_plugins=$(wp --path="${wp_site}" plugin list --quiet --field=name --status=inactive --allow-root)
      array_to_checklist "${wp_del_plugins}"
      chosen_del_plugin_option=$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to delete:" 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)

      for plugin_del in ${chosen_del_plugin_option}; do
        plugin_del=$(sed -e 's/^"//' -e 's/"$//' <<<"${plugin_del}") #needed to ommit double quotes
        log_event "info" "Deleting plugin: ${plugin_del}" "true"
        wpcli_delete_plugin "${wp_site}" "${plugin_del}"

      done

    fi

    if [[ ${chosen_wpcli_options} == *"04"* ]]; then

      #REINSTALL_PLUGINS
      wpcli_force_reinstall_plugins "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"05"* ]]; then

      # VERIFY_WP
      wpcli_core_verify "${wp_site}"
      wpcli_plugin_verify "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"06"* ]]; then

      # UPDATE_WP
      wpcli_core_update "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"07"* ]]; then

      # REINSTALL_WP
      wp_result=$(wpcli_core_reinstall "${wp_site}")
      if [ "${wp_result}" = "success" ]; then
        telegram_send_message "⚠️ ${VPSNAME}: WordPress reinstalled on site: ${wp_site}"

      fi

    fi

    if [[ ${chosen_wpcli_options} == *"08"* ]]; then

      # CLEAN_DB
      log_event "info" "Executing: wp --path=${wp_site} transient delete --expired --allow-root" "true"
      wp --path="${wp_site}" transient delete --expired --allow-root

      log_event "info" "Executing: wp --path=${wp_site} cache flush --allow-root" "true"
      wp --path="${wp_site}" cache flush --allow-root

    fi

    if [[ ${chosen_wpcli_options} == *"09"* ]]; then

      # PROFILE_WP

      #Install PROFILER_OPTIONS
      #https://guides.wp-bullet.com/using-wp-cli-wp-profile-to-diagnose-wordpress-performance-issues/
      wp package install wp-cli/profile-command --allow-root

      PROFILER_OPTIONS="01 PROFILE_STAGE 02 PROFILE_STAGE_BOOTSTRAP 03 PROFILE_STAGE_ALL 04 PROFILE_STAGE_HOOK_WP 05 PROFILE_STAGE_HOOK_ALL"
      CHOSEN_PROF_OPTION=$(whiptail --title "WP-CLI PROFILER HELPER" --menu "Choose an option to run" 20 78 10 $(for x in ${PROFILER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

      if [ $exitstatus = 0 ]; then

        if [[ ${CHOSEN_PROF_OPTION} == *"01"* ]]; then
          #This command shows the stages of loading WordPress
          log_event "info" "Executing: wp --path=${wp_site} profile stage --allow-root" "true"
          wp --path="${wp_site}" profile stage --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"02"* ]]; then
          #Can drill down into each stage, here we drill down into the bootstrap stage
          log_event "info" "Executing: wp --path=${wp_site} profile stage bootstrap --allow-root" "true"
          wp --path="${wp_site}" profile stage bootstrap --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"03"* ]]; then
          #All stage
          #sudo -u www-data wp --path=${SITES}'/'${wp_site} profile stage --all --orderby=time --allow-root
          #You can also use the --spotlight flag to filter out zero-like values for easier reading
          log_event "info" "Executing: wp --path=${wp_site} profile stage --all --spotlight --orderby=time --allow-root" "true"
          wp --path="${wp_site}" profile stage --all --spotlight --orderby=time --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"04"* ]]; then
          #Here we dig into the wp hook
          log_event "info" "Executing: wp --path=${wp_site} profile hook wp --allow-root" "true"
          wp --path="${wp_site}" profile hook wp --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"05"* ]]; then
          #Here we dig into the wp hook
          log_event "info" "Executing: wp --path=${wp_site} profile hook --all --spotlight --allow-root" "true"
          wp --path="${wp_site}" profile hook --all --spotlight --allow-root

        fi

      fi

    fi
    if [[ ${chosen_wpcli_options} == *"10"* ]]; then

      # CHANGE_TABLES_PREFIX

      # Generate WP tables PREFIX
      TABLES_PREFIX=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)

      # Change WP tables PREFIX
      wpcli_change_tables_prefix "${wp_site}" "${TABLES_PREFIX}"

      echo " > New Tables prefix for ${wp_site}: ${TABLES_PREFIX}"

    fi
    if [[ ${chosen_wpcli_options} == *"11"* ]]; then

      # REPLACE_URLs
      wp_ask_url_search_and_replace "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"12"* ]]; then

      # SEOYOAST_REINDEX
      wpcli_seoyoast_reindex "${wp_site}"

    fi

    if [[ ${chosen_wpcli_options} == *"13"* ]]; then

      # DELETE_NOT_CORE_FILES
      echo -e ${B_RED} " > This script will delete all non-core wordpress files (except wp-content). Do you want to continue? [y/n]" ${ENDCOLOR}
      read -r answer
      
      if [[ $answer == "y" ]]; then
          wpcli_delete_not_core_files "${wp_site}"
      
      fi   

    fi

    prompt_return_or_finish
    wpcli_main_menu "${wp_site}"

  else

    main_menu

  fi

}

################################################################################

wpcli_install_if_not_installed

# Directory Browser
startdir=${SITES}
menutitle="Site Selection Menu"
directory_browser "${menutitle}" "${startdir}"

wp_site="${filepath}/${filename}"

log_event "info" "Searching WordPress Installation on directory: ${wp_site}" "true"

# Search a wordpress installation on selected directory
install_path=$(search_wp_config "${wp_site}")

if [[ -z "${install_path}" || "${install_path}" = '' ]]; then

  log_event "info" "Not WordPress Installation Found! Returning to Main Menu" "false"
  
  whiptail --title "WARNING" --msgbox "Not WordPress Installation Found! Press Enter to return to the Main Menu." 8 78
  
  main_menu
  
else

  # WordPress installation path
  wp_site=${install_path}

  log_event "info" "Working with wp_site=${wp_site}" "true"

  wpcli_main_menu "${wp_site}"

fi
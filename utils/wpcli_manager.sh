#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 3.0
################################################################################
#
# Ref: https://kinsta.com/blog/wp-cli/
#
# TODO: en el profiler, dar opcion de profilear una URL específica:
# Ex: php /var/www/.wp-cli/wp-cli.phar --path=/var/www/dev.bes-ebike.com/ profile hook --all --spotlight --url=https://dev.bes-ebike.com/shop-electric-bikes/ --allow-root
#
# Checkear si es red: https://developer.wordpress.org/cli/commands/core/is-installed/

################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/wpcli_helper.sh

################################################################################

wpcli_main_menu() {

  WPCLI_OPTIONS="01 INSTALL_PLUGINS 02 DELETE_THEMES 03 DELETE_PLUGINS 04 REINSTALL_PLUGINS 05 VERIFY_WP 06 UPDATE_WP 07 REINSTALL_WP 08 CLEAN_DB 09 PROFILE_WP 10 CHANGE_TABLES_PREFIX"
  CHOSEN_WPCLI_OPTION=$(whiptail --title "WP-CLI HELPER" --menu "Choose an option to run" 20 78 10 $(for x in ${WPCLI_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_WPCLI_OPTION} == *"01"* ]]; then

      CHOSEN_PLUGIN_OPTION=$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to install." 20 78 15 "${WP_PLUGINS[@]}" 3>&1 1>&2 2>&3)
      echo "Setting CHOSEN_PLUGIN_OPTION="$CHOSEN_PLUGIN_OPTION

      for plugin in $CHOSEN_PLUGIN_OPTION; do
        #echo "sudo -u www-data wp --path=${WP_SITE} plugin install $plugin --activate"
        wpcli_install_plugin "${WP_SITE}" "$plugin"
      done

    fi

    if [[ ${CHOSEN_WPCLI_OPTION} == *"02"* ]]; then

      # Listing installed themes
      WP_DEL_THEMES=$(wp --path=${WP_SITE} theme list --quiet --field=name --status=inactive --allow-root)
      array_to_checklist "$WP_DEL_THEMES"
      echo "Setting WP_DEL_THEMES=${checklist_array[@]}"
      CHOSEN_DEL_THEME_OPTION=$(whiptail --title "Theme Selection" --checklist "Select the themes you want to delete." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)
      #echo "Setting CHOSEN_DEL_THEME_OPTION="$CHOSEN_DEL_THEME_OPTION

      for theme_del in $CHOSEN_DEL_THEME_OPTION; do
        theme_del=$(sed -e 's/^"//' -e 's/"$//' <<<$theme_del) #needed to ommit double quotes
        echo "theme delete $theme_del"
        wpcli_delete_theme "${WP_SITE}" "$theme_del"
      done

    fi
    if [[ ${CHOSEN_WPCLI_OPTION} == *"03"* ]]; then

      # Listing installed plugins
      WP_DEL_PLUGINS=$(wp --path=${WP_SITE} plugin list --quiet --field=name --status=inactive --allow-root)
      array_to_checklist "$WP_DEL_PLUGINS"
      CHOSEN_DEL_PLUGIN_OPTION=$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to delete." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)

      for plugin_del in $CHOSEN_DEL_PLUGIN_OPTION; do
        plugin_del=$(sed -e 's/^"//' -e 's/"$//' <<<$plugin_del) #needed to ommit double quotes
        echo "plugin delete $plugin_del"
        wpcli_delete_plugin "${WP_SITE}" "$plugin_del"
      done

    fi

    if [[ ${CHOSEN_WPCLI_OPTION} == *"04"* ]]; then

      # Listing installed plugins
      #WP_DEL_PLUGINS=$(wp --path=${WP_SITE} plugin list -quiet --field=name --status=inactive --allow-root)
      echo "option 5: re-install plugins not implemented yet ..."

    fi

    if [[ ${CHOSEN_WPCLI_OPTION} == *"05"* ]]; then

      echo "Verifying Core Checksum ..."
      wpcli_verify_wp_core_installation "${WP_SITE}"

      echo "Verifying Plugin Checksum ..."
      wpcli_verify_wp_plugins_installation "${WP_SITE}"

      echo " > DONE"

    fi

    if [[ ${CHOSEN_WPCLI_OPTION} == *"06"* ]]; then

      echo "Updating WP ..."
      sudo -u www-data wp --path=${WP_SITE}'/'${WP_SITE} core update
      echo "Updating WP DB ..."
      sudo -u www-data wp --path=${WP_SITE}'/'${WP_SITE} core update-db
      echo " > DONE"

    fi

    if [[ ${CHOSEN_WPCLI_OPTION} == *"07"* ]]; then

      #esto vuelve a bajar wp y pisa archivos, no borra los archivos actuales, ojo
      sudo -u www-data wp --path=${WP_SITE}'/'${WP_SITE} core download --skip-content --force

    fi

    if [[ ${CHOSEN_WPCLI_OPTION} == *"08"* ]]; then

      echo " > Deleting transient ..."
      wp --path=${WP_SITE} transient delete --expired --allow-root
      echo " > Cache Flush ..."
      wp --path=${WP_SITE} cache flush --allow-root
      echo " > DONE"

    fi

    if [[ ${CHOSEN_WPCLI_OPTION} == *"09"* ]]; then

      #Install PROFILER_OPTIONS
      #https://guides.wp-bullet.com/using-wp-cli-wp-profile-to-diagnose-wordpress-performance-issues/
      wp package install wp-cli/profile-command --allow-root

      PROFILER_OPTIONS="01 PROFILE_STAGE 02 PROFILE_STAGE_BOOTSTRAP 03 PROFILE_STAGE_ALL 04 PROFILE_STAGE_HOOK_WP 05 PROFILE_STAGE_HOOK_ALL"
      CHOSEN_PROF_OPTION=$(whiptail --title "WP-CLI PROFILER HELPER" --menu "Choose an option to run" 20 78 10 $(for x in ${PROFILER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

      if [ $exitstatus = 0 ]; then

        if [[ ${CHOSEN_PROF_OPTION} == *"01"* ]]; then
          #This command shows the stages of loading WordPress.
          wp --path=${WP_SITE} profile stage --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"02"* ]]; then
          #Can drill down into each stage, here we drill down into the bootstrap stage
          wp --path=${WP_SITE} profile stage bootstrap --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"03"* ]]; then
          #All stage
          #sudo -u www-data wp --path=${SITES}'/'${WP_SITE} profile stage --all --orderby=time --allow-root
          #You can also use the --spotlight flag to filter out zero-like values for easier reading
          wp --path=${WP_SITE} profile stage --all --spotlight --orderby=time --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"04"* ]]; then
          #Here we dig into the wp hook
          wp --path=${WP_SITE} profile hook wp --allow-root

        fi
        if [[ ${CHOSEN_PROF_OPTION} == *"05"* ]]; then
          #Here we dig into the wp hook
          echo "Executing: wp --path=${WP_SITE} profile hook --all --spotlight --allow-root"
          wp --path=${WP_SITE} profile hook --all --spotlight --allow-root

        fi

      fi

    fi
    if [[ ${CHOSEN_WPCLI_OPTION} == *"10"* ]]; then
      
      # Generate WP tables PREFIX
      TABLES_PREFIX=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)
      # Change WP tables PREFIX
      wpcli_change_tables_prefix "${WP_SITE}" "${TABLES_PREFIX}"

      echo "New Tables prefix for ${WP_SITE}: ${TABLES_PREFIX}"

    fi
    #if [[ ${CHOSEN_WPCLI_OPTION} == *"11"* ]]; then

      #Install DOCTOR
      #https://github.com/wp-cli/doctor-command
    #  wp package install git@github.com:wp-cli/doctor-command.git --allow-root

    #  echo " > Checking WP Update ..."
    #  wp --path=${WP_SITE} doctor check core-update --allow-root
    #  echo " > Verify the site is public as expected ..."
    #  wp --path=${WP_SITE} doctor check option-blog-public --allow-root
    #  echo " > Verify cron count ..."
    #  wp --path=${WP_SITE} doctor check cron-count --allow-root
    #  echo " > Verify plugin active count ..."
    #  wp --path=${WP_SITE} doctor check plugin-active-count --allow-root
    #  echo " > DONE"
    #fi

    wpcli_main_menu

  else
    main_menu

  fi

}

################################################################################

WPCLI_INSTALLED=$(wpcli_check_if_installed)

if [[ "${WPCLI_INSTALLED}" == "false" ]]; then
  ${SFOLDER}/utils/installers/wpcli_installer.sh

fi

startdir=${SITES}
menutitle="Site Selection Menu"

directory_browser "$menutitle" "$startdir"
WP_SITE=$filepath"/"$filename
echo "Working with WP_SITE="${WP_SITE}

# Array of plugin slugs to install
WP_PLUGINS=(
  "wordpress-seo" " " off
  "ewww-image-optimizer" " " off
  "easy-wp-smtp" " " off
  "contact-form-7" " " off
  "advanced-custom-fields" " " off
  "acf-vc-integrator" " " off
  "w3-total-cache" " " off
  "fast-velocity-minify" " " off
  "fresh-plugins" " " off
  "wordfence" " " off
  "better-wp-security" " " off
  "quttera-web-malware-scanner" " " off
)

# TODO: Probar https://github.com/10up/wp-vulnerability-scanner

wpcli_main_menu

#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
################################################################################

startdir=${SITES}
menutitle="Site Selection Menu"

################################# HELPERS ######################################

Filebrowser() {
  # first parameter is Menu Title
  # second parameter is dir path to starting folder
  if [ -z $2 ] ; then
    dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "$2"
    dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "$curdir" == "/" ] ; then  # Check if you are at root folder
    selection=$(whiptail --title "$1" \
                          --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
                          --cancel-button Cancel \
                          --ok-button Select $dir_list 3>&1 1>&2 2>&3)
  else   # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "$1" \
                          --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
                          --cancel-button Cancel \
                          --ok-button Select ../ BACK $dir_list 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then  # Check if User Selected Cancel
    return 1
  elif [ $RET -eq 0 ]; then
    if [[ -d "$selection" ]]; then  # Check if Directory Selected
      if (whiptail --title "Confirm Selection" --yesno "Selection : $selection\n" 0 0 \
                   --yes-button "Confirm" \
                   --no-button "Retry"); then
        filename="$selection"
        filepath="$curdir"    # Return full filepath and filename as selection variables

      fi
    fi
  fi
}

declare -a checklist_array

Array_to_checklist() {
  i=0

  for option in $1; do
    checklist_array[$i]=$option
    i=$((i+1))
    checklist_array[$i]=" "
    i=$((i+1))
    checklist_array[$i]=off
    i=$((i+1))
  done
  #echo ${checklist_array[@]}
}

################################################################################

### Checking some things
if [ $USER != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
if [ ! -d "${SITES}/.wp-cli" ]; then
  cp -R ${SFOLDER}/utils/wp-cli ${SITES}/.wp-cli
fi

# Checking permissions and updating wp-cli
chown -R www-data:www-data ${SITES}/.wp-cli
chmod -R 777 ${SITES}/.wp-cli
chmod +x ${SITES}/.wp-cli/wp-cli.phar
sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar cli update

Filebrowser "$menutitle" "$startdir"
WP_SITE=$filepath"/"$filename
echo "Setting WP_SITE="${WP_SITE}

#define array of plugin slugs to install
WP_PLUGINS=("wordpress-seo" " " off
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

WPCLI_OPTIONS="01 INSTALL_PLUGINS 02 DELETE_THEMES 03 DELETE_PLUGINS 04 REINSTALL_PLUGINS 05 VERIFY_WP 06 UPDATE_WP 07 REINSTALL_WP 08 SET_INDEX_OPTION 09 CLEAN_DB 10 PROFILE_WP 11 DB_CLI 12 WP_DOCTOR"
CHOSEN_WPCLI_OPTION=$(whiptail --title "WP-CLI HELPER" --menu "Choose an option to run" 20 78 10 `for x in ${WPCLI_OPTIONS}; do echo "$x"; done` 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${CHOSEN_WPCLI_OPTION} == *"01"* ]]; then
    CHOSEN_PLUGIN_OPTION=$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to install." 20 78 15 "${WP_PLUGINS[@]}" 3>&1 1>&2 2>&3)
    echo "Setting CHOSEN_PLUGIN_OPTION="$CHOSEN_PLUGIN_OPTION
    for plugin in $CHOSEN_PLUGIN_OPTION; do
      #echo "sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} plugin install $plugin --activate"
      sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} plugin install $plugin --activate
    done
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"02"* ]]; then
    #para listar themes instalados
    WP_DEL_THEMES=$(php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} theme list --quiet --field=name --status=inactive --allow-root)
    Array_to_checklist "$WP_DEL_THEMES"
    echo "Setting WP_DEL_THEMES=${checklist_array[@]}"
    CHOSEN_DEL_THEME_OPTION=$(whiptail --title "Theme Selection" --checklist "Select the themes you want to delete." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)
    #echo "Setting CHOSEN_DEL_THEME_OPTION="$CHOSEN_DEL_THEME_OPTION
    for theme_del in $CHOSEN_DEL_THEME_OPTION; do
      theme_del=$(sed -e 's/^"//' -e 's/"$//' <<<$theme_del) #needed to ommit double quotes
      echo "theme delete $theme_del"
      sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} theme delete $theme_del
    done
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"03"* ]]; then
    #para listar plugins instalados
    WP_DEL_PLUGINS=$(php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} plugin list --quiet --field=name --status=inactive --allow-root)
    Array_to_checklist "$WP_DEL_PLUGINS"
    CHOSEN_DEL_PLUGIN_OPTION=$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to delete." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)
    for plugin_del in $CHOSEN_DEL_PLUGIN_OPTION; do
      plugin_del=$(sed -e 's/^"//' -e 's/"$//' <<<$plugin_del) #needed to ommit double quotes
      echo "plugin delete $plugin_del"
      sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} plugin delete $plugin_del
    done
  fi

  if [[ ${CHOSEN_WPCLI_OPTION} == *"04"* ]]; then
    #para listar plugins instalados
    #WP_DEL_PLUGINS=$(php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} plugin list -quiet --field=name --status=inactive --allow-root)
    echo "option 5: re-install plugins not implemented yet ..."
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"05"* ]]; then
    echo "Verifying Core Checksum ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} core verify-checksums --allow-root
    echo "Verifying Plugin Checksum ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} plugin verify-checksums --all --allow-root
    echo " > DONE"
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"06"* ]]; then
    echo "Updating WP ..."
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE}'/'${WP_SITE} core update
    echo "Updating WP DB ..."
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE}'/'${WP_SITE} core update-db
    echo " > DONE"
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"07"* ]]; then
    #esto vuelve a bajar wp y pisa archivos, no borra los archivos actuales, ojo
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE}'/'${WP_SITE} core download --skip-content --force
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"08"* ]]; then
    #para evitar que los motores de busqueda indexen el sitio
    echo " > Setting Index Option to Private ..."
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} option set blog_public 0
    echo " > Setting Index Option to Public ..."
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} option set blog_public 1
    echo " > DONE"
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"09"* ]]; then
    echo " > Deleting transient ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} transient delete --expired --allow-root
    echo " > Cache Flush ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} cache flush --allow-root
    echo " > DONE"
  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"10"* ]]; then

    #Install PROFILER_OPTIONS
    #https://guides.wp-bullet.com/using-wp-cli-wp-profile-to-diagnose-wordpress-performance-issues/
    php ${SITES}/.wp-cli/wp-cli.phar package install wp-cli/profile-command --allow-root

    PROFILER_OPTIONS="01 PROFILE_STAGE 02 PROFILE_STAGE_BOOTSTRAP 03 PROFILE_STAGE_ALL 04 PROFILE_STAGE_HOOK_WP 05 PROFILE_STAGE_HOOK_ALL"
    CHOSEN_PROF_OPTION=$(whiptail --title "WP-CLI PROFILER HELPER" --menu "Choose an option to run" 20 78 10 `for x in ${PROFILER_OPTIONS}; do echo "$x"; done` 3>&1 1>&2 2>&3)

    if [ $exitstatus = 0 ]; then

      if [[ ${CHOSEN_PROF_OPTION} == *"01"* ]]; then
        #This command shows the stages of loading WordPress.
        php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} profile stage --allow-root

      fi
      if [[ ${CHOSEN_PROF_OPTION} == *"02"* ]]; then
        #Can drill down into each stage, here we drill down into the bootstrap stage
        php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} profile stage bootstrap --allow-root

      fi
      if [[ ${CHOSEN_PROF_OPTION} == *"03"* ]]; then
        #All stage
        #sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} profile stage --all --orderby=time --allow-root
        #You can also use the --spotlight flag to filter out zero-like values for easier reading
        php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} profile stage --all --spotlight --orderby=time --allow-root

      fi
      if [[ ${CHOSEN_PROF_OPTION} == *"04"* ]]; then
        #Here we dig into the wp hook
        php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} profile hook wp --allow-root

      fi
      if [[ ${CHOSEN_PROF_OPTION} == *"05"* ]]; then
        #Here we dig into the wp hook
        php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} profile hook --all --spotlight --allow-root

      fi

    fi

  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"11"* ]]; then
    #https://github.com/wp-cli/db-command
    php ${SITES}/.wp-cli/wp-cli.phar package install git@github.com:wp-cli/db-command.git

  fi
  if [[ ${CHOSEN_WPCLI_OPTION} == *"12"* ]]; then

    #Install DOCTOR
    #https://github.com/wp-cli/doctor-command
    php ${SITES}/.wp-cli/wp-cli.phar package install git@github.com:wp-cli/doctor-command.git --allow-root

    echo " > Checking WP Update ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} doctor check core-update --allow-root
    echo " > Verify the site is public as expected ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} doctor check option-blog-public --allow-root
    echo " > Verify cron count ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} doctor check cron-count --allow-root
    echo " > Verify plugin active count ..."
    php ${SITES}/.wp-cli/wp-cli.phar --path=${WP_SITE} doctor check plugin-active-count --allow-root
    echo " > DONE"
  fi

else
  echo " > Exiting ..."
  exit 1
fi

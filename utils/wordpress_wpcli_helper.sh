#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
#############################################################################

### Checking some things
if [ $USER != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
if [ ! -d "${SITES}/.wp-cli" ]; then
  cp -R wp-cli ${SITES}/.wp-cli
fi

# Checking permissions and updating wp-cli
chown -R www-data:www-data ${SITES}/.wp-cli
chmod -R 777 ${SITES}/.wp-cli
chmod +x ${SITES}/.wp-cli/wp-cli.phar
sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar cli update

WP_SITE=$(whiptail --title "WP-CLI Site Selection" --inputbox "Please insert the website do you want to work with" 10 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ ${exitstatus} = 0 ]; then
  echo "Setting WP_SITE="${WP_SITE} >> $LOG
else
  exit 1
fi

WPCLI_OPTIONS="01 INSTALL_THEMES 02 INSTALL_PLUGINS 03 DELETE_THEMES 04 DELETE_PLUGINS 05 UPDATE_WP 06 SET_INDEX_OPTION"
CHOSEN_WPCLI_OPTIONS=$(whiptail --title "WP-CLI HELPER" --menu "Choose an option to run" 20 78 10 `for x in ${WPCLI_OPTIONS}; do echo "$x"; done` 3>&1 1>&2 2>&3)
if [ $exitstatus = 0 ]; then
  if [[ ${CHOSEN_TYPE} == *"01"* ]]; then
    #para instalar un plugin nuevo (ejemplo seo yoast)
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} plugin install twentytwelve
  fi
  if [[ ${CHOSEN_TYPE} == *"02"* ]]; then
    #para instalar un plugin nuevo (ejemplo seo yoast)
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} plugin install wordpress-seo --activate
  fi
  if [[ ${CHOSEN_TYPE} == *"03"* ]]; then
    #para borrar themes
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} theme delete twentytwelve
  fi
  if [[ ${CHOSEN_TYPE} == *"04"* ]]; then
    #para borrar plugins
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} plugin delete hello
  fi
  if [[ ${CHOSEN_TYPE} == *"05"* ]]; then
    #para actualizar wp (ojo que se manda a actualizar y no hace backup ni nada antes)
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} core update
    #para actualizar wp-db
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} core update-db
  fi
  if [[ ${CHOSEN_TYPE} == *"06"* ]]; then
    #para evitar que los motores de busqueda indexen el sitio
    sudo -u www-data php ${SITES}/.wp-cli/wp-cli.phar --path=${SITES}'/'${WP_SITE} option set blog_public 0
  fi
  
else
  exit 1

fi

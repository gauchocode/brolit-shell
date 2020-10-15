#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.6
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

php_installer() {

  local PHP_V=$1

  log_event "info" "Installing PHP-${PHP_V} and other libraries ..." "false"

  apt-get --yes install "php${PHP_V}-fpm" "php${PHP_V}-mysql" "php-imagick" "php${PHP_V}-xml" "php${PHP_V}-cli" "php${PHP_V}-curl" "php${PHP_V}-mbstring" "php${PHP_V}-gd" "php${PHP_V}-intl" "php${PHP_V}-zip" "php${PHP_V}-bz2" "php${PHP_V}-bcmath" "php${PHP_V}-soap" "php${PHP_V}-dev" "php-pear" -qq > /dev/null

  log_event "info" "PHP-${PHP_V} installed!" "false"

}

php_custom_installer() {
  
  add_ppa "ondrej/php"
  
  apt-get update -qq > /dev/null

  php_select_version_to_install

}

php_select_version_to_install() {

  local phpv_to_install 
  local chosen_phpv
  local phpv

  phpv_to_install=(
    "7.4" " " off
    "7.3" " " off
    "7.2" " " off
    "7.1" " " off
    "7.0" " " off
    "5.6" " " off
  )

  chosen_phpv=$(whiptail --title "PHP Version Selection" --checklist "Select the versions of PHP you want to install:" 20 78 15 "${phpv_to_install[@]}" 3>&1 1>&2 2>&3)
  echo "Setting CHOSEN_PHPV=${chosen_phpv}"
  
  for phpv in $chosen_phpv; do

    phpv=$(sed -e 's/^"//' -e 's/"$//' <<<${phpv}) #needed to ommit double quotes

    php_installer "${phpv}"

  done

}

php_redis_installer() {

  display --indent 2 --text "- Installing redis server"

  apt-get --yes install redis-server php-redis -qq > /dev/null
  systemctl enable redis-server.service

  cp "${SFOLDER}/config/redis/redis.conf" "/etc/redis/redis.conf"

  service redis-server restart

  clear_last_line
  display --indent 2 --text "- Installing redis server" --result "DONE" --color GREEN

}

mail_utils_installer() {

  log_event "info" "Installing mail mail_mime and net_smtp ..." "false"
  display --indent 2 --text "- Installing mail smtp"

  # Creating tmp directory
  # Ref: https://stackoverflow.com/questions/59720692/php-7-4-1-pecl-is-not-working-trying-to-access-array-offset-on-value-of-type
  mkdir -p /tmp/pear/cache

  pear channel-update pear.php.net

  pear -q install mail mail_mime net_smtp

  log_event "info" "mail mail_mime and net_smtp installed" "false"
  clear_last_line
  display --indent 2 --text "- Installing mail smtp" --result "DONE" --color GREEN

}

php_purge_all_installations() {

  log_event "info" "Removing all PHP versions and libraries ..." "false"
  display --indent 2 --text "- Purging PHP and libraries"

  apt-get --yes purge php* -qq > /dev/null

  log_event "info" "PHP purged!" "false"
  clear_last_line
  display --indent 2 --text "- Purging PHP and libraries" --result "DONE" --color GREEN

}

php_purge_installation() {

  log_event "info" "Removing PHP-${PHP_V} and libraries ..." "false"
  display --indent 2 --text "- Removing PHP-${PHP_V} and libraries"

  apt-get --yes purge "php${PHP_V}-fpm" "php${PHP_V}-mysql" php-xml "php${PHP_V}-xml" "php${PHP_V}-cli" "php${PHP_V}-curl" "php${PHP_V}-mbstring" "php${PHP_V}-gd" php-imagick "php${PHP_V}-intl" "php${PHP_V}-zip" "php${PHP_V}-bz2" php-bcmath "php${PHP_V}-soap" "php${PHP_V}-dev" php-pear -qq > /dev/null

  log_event "info" "PHP-${PHP_V} deleted!" "false"
  clear_last_line
  display --indent 2 --text "- Removing PHP-${PHP_V} and libraries" --result "DONE" --color GREEN

}

php_check_if_installed() {

  local php_installed php

  php="$(which php)"
  if [ ! -x "${php}" ]; then
    php_installed="false"

  else
    php_installed="true"

  fi

  # Return
  echo "${php_installed}"

}

php_check_installed_version() {
  
  php --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

php_reconfigure() {

  log_subsection "PHP Reconfigure"
  
  log_event "info" "Moving php.ini configuration file ..." "false"
  cat "${SFOLDER}/config/php/php.ini" >"/etc/php/${PHP_V}/fpm/php.ini"
  display --indent 2 --text "- Moving php.ini configuration file" --result "DONE" --color GREEN

  log_event "info" "Moving php-fpm.conf configuration file ..." "false"
  cat "${SFOLDER}/config/php/php-fpm.conf" >"/etc/php/${PHP_V}/fpm/php-fpm.conf"
  display --indent 2 --text "- Moving php-fpm.conf configuration file" --result "DONE" --color GREEN

  # Replace string to match PHP version
  log_event "info" "Replacing string to match PHP version" "false"
  sed -i "s#PHP_V#${PHP_V}#" "/etc/php/${PHP_V}/fpm/php-fpm.conf"
  sed -i "s#PHP_V#${PHP_V}#" "/etc/php/${PHP_V}/fpm/php-fpm.conf"
  sed -i "s#PHP_V#${PHP_V}#" "/etc/php/${PHP_V}/fpm/php-fpm.conf"
  display --indent 2 --text "- Replacing string to match PHP version" --result "DONE" --color GREEN

  # Unccoment /status from fpm configuration
  log_event "info" "Uncommenting /status from fpm configuration ..." "false"
  sed -i '/status_path/s/^;//g' "/etc/php/${PHP_V}/fpm/pool.d/www.conf"

  service php"${PHP_V}"-fpm reload
  display --indent 2 --text "- Reloading php${PHP_V}-fpm" --result "DONE" --color GREEN

}

################################################################################

php_is_installed=$(php_check_if_installed)

if [[ ${php_is_installed} == "false" ]]; then
  php_installer_title="PHP INSTALLER"
  php_installer_message="Choose a PHP version to install:"
  php_installer_options=("01)" "INSTALL PHP DEFAULT" "02)" "INSTALL PHP CUSTOM")
else
  php_installer_title="PHP CONFIGURATOR"
  php_installer_message="Choose an option to run:"
  php_installer_options=("01)" "INSTALL PHP DEFAULT" "02)" "INSTALL PHP CUSTOM" "03)" "RECONFIGURE PHP" "04)" "OPTIMIZE PHP" "05)" "REMOVE PHP")
fi

chosen_php_installer_options=$(whiptail --title "${php_installer_title}" --menu "${php_installer_message}" 20 78 10 "${php_installer_options[@]}" 3>&1 1>&2 2>&3)
exitstatus=$?
if [[ ${exitstatus} -eq 0 ]]; then

  if [[ ${chosen_php_installer_options} == *"01"* ]]; then
    
    DISTRO_V=$(get_ubuntu_version)
    if [ "${DISTRO_V}" -eq "1804" ]; then
      PHP_V="7.2"  #Ubuntu 18.04 LTS Default
    elif [ "${DISTRO_V}" -eq "2004" ]; then
      PHP_V="7.4"  #Ubuntu 20.04 LTS Default
    else
      log_event "critical" "Non standard distro!" "true"
      return 1
    fi

    log_subsection "PHP Installer"
    
    # Installing packages
    php_installer "${PHP_V}"
    mail_utils_installer
    php_redis_installer

  fi
  if [[ ${chosen_php_installer_options} == *"02"* ]]; then

    log_subsection "PHP Installer"

    # INSTALL PHP CUSTOM
    php_custom_installer
    mail_utils_installer
    #php_redis_installer

    # TODO: if you install a new PHP version, maybe you want to reconfigure an specific nginx_server
    # nginx_reconfigure_sites()
    # fastcgi_pass unix:/var/run/php/php5.6-fpm.sock;
    # fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;

  fi

  # Will only show if php is installed
  if [[ ${chosen_php_installer_options} == *"03"* ]]; then
    
    # RECONFIGURE PHP
    php_reconfigure

  fi
  if [[ ${chosen_php_installer_options} == *"04"* ]]; then
    
    # OPTIMIZE PHP
    "${SFOLDER}/utils/php_optimizations.sh"

  fi
  if [[ ${chosen_php_installer_options} == *"05"* ]]; then
    
    # REMOVE PHP
    php_purge_installation

  fi



fi


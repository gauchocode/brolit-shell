#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.1
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e "${B_RED} > Error: The script can only be runned by runner.sh! Exiting ...${ENDCOLOR}"
  exit 1
fi

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

  local phpv_to_install chosen_phpv phpv

  phpv_to_install=(
    "7.4" " " off
    "7.3" " " off
    "7.2" " " off
    "7.1" " " off
    "7.0" " " off
    "5.6" " " off
    "5.5" " " off
  )

  chosen_phpv=$(whiptail --title "PHP Version Selection" --checklist "Select the versions of PHP you want to install:" 20 78 15 "${phpv_to_install[@]}" 3>&1 1>&2 2>&3)
  echo "Setting CHOSEN_PHPV=$chosen_phpv"
  
  for phpv in $chosen_phpv; do

    phpv=$(sed -e 's/^"//' -e 's/"$//' <<<${phpv}) #needed to ommit double quotes

    php_installer "${phpv}"

  done

}

php_redis_installer() {

  apt-get --yes install redis-server php-redis -qq > /dev/null
  systemctl enable redis-server.service

  cp "${SFOLDER}/config/redis/redis.conf" "/etc/redis/redis.conf"

  service redis-server restart

}

mail_utils_installer() {

  log_event "info" "Installing mail mail_mime and net_smtp ..." "false"
  display --indent 2 --text "- Installing mail smtp"

  # Creating tmp directory
  # Ref: https://stackoverflow.com/questions/59720692/php-7-4-1-pecl-is-not-working-trying-to-access-array-offset-on-value-of-type
  mkdir -p /tmp/pear/cache

  pear -q install mail mail_mime net_smtp

  log_event "info" "mail mail_mime and net_smtp installed" "false"
  clear_last_line
  display --indent 2 --text "- Installing mail smtp" --result "DONE" --color GREEN

}

php_purge_all_installations() {

  log_event "info" "Removing all PHP versions and libraries ..." "false"

  apt-get --yes purge php* -qq > /dev/null

  log_event "info" "PHP purged!" "false"

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

}

################################################################################

#php_installed="true"
php_is_installed=$(php_check_if_installed)

# TODO: if installed, option to reinstall, remove, or reconfigure

#if [ ${php_installed} == "false" ]; then

PHP_INSTALLER_OPTIONS="01) INSTALL-PHP-DEFAULT 02) INSTALL-PHP-CUSTOM 03) RECONFIGURE-PHP 04) OPTIMIZE-PHP 05) REMOVE-PHP"
CHOSEN_PHP_INSTALLER_OPTION=$(whiptail --title "PHP INSTALLER" --menu "Choose a PHP version to install" 20 78 10 $(for x in ${PHP_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"01"* ]]; then
    
    DISTRO_V=$(get_ubuntu_version)
    if [ "${DISTRO_V}" -eq "1804" ]; then
      PHP_V="7.2"  #Ubuntu 18.04 LTS Default
    elif [ "${DISTRO_V}" -eq "2004" ]; then
      PHP_V="7.4"  #Ubuntu 20.04 LTS Default
    else
      log_event "critical" "Non standard distro!" "true"
      return 1
    fi
    
    # Installing packages
    php_installer "${PHP_V}"
    mail_utils_installer
    php_redis_installer

  fi
  if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"02"* ]]; then

    # INSTALL_PHP_CUSTOM
    php_custom_installer
    mail_utils_installer
    #php_redis_installer

  fi
  if [[ ${php_is_installed} = "true" ]]; then

    if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"03"* ]]; then
      
      # RECONFIGURE_PHP
      php_reconfigure

    fi
    if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"04"* ]]; then
      
      # OPTIMIZE_PHP
      "${SFOLDER}/utils/php_optimizations.sh"

    fi
    if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"05"* ]]; then
      
      # REMOVE_PHP
      php_purge_installation

    fi

  fi

fi
#fi

# TODO: if you install a new PHP version, maybe you want to reconfigure an specific nginx_server
# nginx_reconfigure_sites()
# fastcgi_pass unix:/var/run/php/php5.6-fpm.sock;
# fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;

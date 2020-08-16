#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi

################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

php_installer() {

  local PHP_V=$1

  apt --yes install "php${PHP_V}-fpm" "php${PHP_V}-mysql" php-imagick "php${PHP_V}-xml" "php${PHP_V}-cli" "php${PHP_V}-curl" "php${PHP_V}-mbstring" "php${PHP_V}-gd" "php${PHP_V}-intl" "php${PHP_V}-zip" "php${PHP_V}-bz2" "php${PHP_V}-bcmath" "php${PHP_V}-soap" "php${PHP_V}-dev" php-pear

}

php_custom_installer() {
  
  add_ppa "ondrej/php"
  
  apt-get update

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
    phpv=$(sed -e 's/^"//' -e 's/"$//' <<<$phpv) #needed to ommit double quotes

    php_installer "${phpv}"

  done

}

php_redis_installer() {

  apt --yes install redis-server php-redis
  systemctl enable redis-server.service

  cp "${SFOLDER}/config/redis/redis.conf" "/etc/redis/redis.conf"

  service redis-server restart

}

mail_utils_installer() {

  pear install mail mail_mime net_smtp

}

php_purge_all_installations() {

  echo " > Removing All PHP versions installed ..." >>$LOG
  apt --yes purge php*

}

php_purge_installation() {

  echo " > Removing PHP ${PHP_V} ..." >>$LOG
  apt --yes purge "php${PHP_V}-fpm" "php${PHP_V}-mysql" php-xml "php${PHP_V}-xml" "php${PHP_V}-cli" "php${PHP_V}-curl" "php${PHP_V}-mbstring" "php${PHP_V}-gd" php-imagick "php${PHP_V}-intl" "php${PHP_V}-zip" "php${PHP_V}-bz2" php-bcmath "php${PHP_V}-soap" "php${PHP_V}-dev" php-pear

}

php_check_if_installed() {

  local php_installed php

  php="$(which php)"
  if [ ! -x "${php}" ]; then
    php_installed="false"

  else
    php_installed="true"

  fi

  echo ${php_installed}

}

php_check_installed_version() {
  
  php --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

php_reconfigure() {
  
  log_event "info" "Moving php.ini configuration file ..." "true"
  cat "${SFOLDER}/config/php/php.ini" >"/etc/php/${PHP_V}/fpm/php.ini"

  log_event "info" "Moving php-fpm.conf configuration file ..." "true"
  cat "${SFOLDER}/config/php/php-fpm.conf" >"/etc/php/${PHP_V}/fpm/php-fpm.conf"

  # Replace string to match PHP version
  log_event "info" "Replace string to match PHP version ..." "true"
  sudo sed -i "s#PHP_V#${PHP_V}#" "/etc/php/${PHP_V}/fpm/php-fpm.conf"
  sudo sed -i "s#PHP_V#${PHP_V}#" "/etc/php/${PHP_V}/fpm/php-fpm.conf"
  sudo sed -i "s#PHP_V#${PHP_V}#" "/etc/php/${PHP_V}/fpm/php-fpm.conf"

  # Unccoment /status from fpm configuration
  log_event "info" "Unccoment /status from fpm configuration ..." "true"
  sed -i '/status_path/s/^;//g' "/etc/php/${PHP_V}/fpm/pool.d/www.conf"

}

################################################################################

#php_installed="true"
php_is_installed=$(php_check_if_installed)

# TODO: if installed, option to reinstall, remove, or reconfigure

#if [ ${php_installed} == "false" ]; then

PHP_INSTALLER_OPTIONS="01 INSTALL_PHP_STANDARD 02 INSTALL_PHP_CUSTOM 03 RECONFIGURE_PHP 04 OPTIMIZE_PHP"
CHOSEN_PHP_INSTALLER_OPTION=$(whiptail --title "PHP INSTALLER" --menu "Choose a PHP version to install" 20 78 10 $(for x in ${PHP_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"01"* ]]; then
    
    DISTRO_V=$(get_ubuntu_version)
    if [ ! "$DISTRO_V" == "1804" ]; then
      PHP_V="7.2"  #Ubuntu 18.04 LTS Default
    else
      PHP_V="7.4"  #Ubuntu 20.04 LTS Default
    fi
    
    # Installing packages
    php_installer "${PHP_V}"
    mail_utils_installer
    php_redis_installer

  fi
  if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"02"* ]]; then
    # Installing packages
    php_custom_installer
    mail_utils_installer
    #php_redis_installer

  fi
  if [[ ${php_is_installed} = "true" ]]; then

    if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"03"* ]]; then
      # PHP reconfigure
      php_reconfigure

    fi
    if [[ ${CHOSEN_PHP_INSTALLER_OPTION} == *"04"* ]]; then
      # Run php_optimizations.sh
      "${SFOLDER}/utils/php_optimizations.sh"

    fi

  fi

fi
#fi

# TODO: if you install a new PHP version, maybe you want to reconfigure an specific nginx_server
# nginx_reconfigure_sites()
# fastcgi_pass unix:/var/run/php/php5.6-fpm.sock;
# fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;

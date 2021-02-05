#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/php_helper.sh
source "${SFOLDER}/libs/php_helper.sh"

################################################################################

function php_installer() {

  local php_v=$1

  # Log
  display --indent 6 --text "- Installing PHP-${php_v} and libraries"
  log_event "info" "Installing PHP-${php_v} and libraries ..."

  # apt command
  apt-get --yes install "php${php_v}-fpm" "php${php_v}-mysql" "php-imagick" "php${php_v}-xml" "php${php_v}-cli" "php${php_v}-curl" "php${php_v}-mbstring" "php${php_v}-gd" "php${php_v}-intl" "php${php_v}-zip" "php${php_v}-bz2" "php${php_v}-bcmath" "php${php_v}-soap" "php${php_v}-dev" "php-pear" -qq > /dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Installing PHP-${php_v} and libraries" --result "DONE" --color GREEN
  log_event "info" "PHP-${php_v} installed"

}

function php_custom_installer() {
  
  add_ppa "ondrej/php"
  
  apt-get update -qq > /dev/null

  php_select_version_to_install

}

function php_select_version_to_install() {

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

function php_redis_installer() {

  # Log
  display --indent 6 --text "- Installing redis server"
  log_event "info" "Installing redis server ..."

  # apt command
  apt-get --yes install redis-server php-redis -qq > /dev/null
  systemctl enable redis-server.service

  # Creating config file
  cp "${SFOLDER}/config/redis/redis.conf" "/etc/redis/redis.conf"

  # Service restart
  service redis-server restart

  # Log
  clear_last_line
  display --indent 6 --text "- Installing redis server" --result "DONE" --color GREEN
  log_event "info" "redis server installed"

}

function mail_utils_installer() {

  # Log
  display --indent 2 --text "- Installing mail smtp"
  log_event "info" "Installing mail mail_mime and net_smtp ..."

  # Creating tmp directory
  # Ref: https://stackoverflow.com/questions/59720692/php-7-4-1-pecl-is-not-working-trying-to-access-array-offset-on-value-of-type
  mkdir -p /tmp/pear/cache

  pear channel-update pear.php.net

  pear -q install mail mail_mime net_smtp

  # Log
  clear_last_line
  display --indent 2 --text "- Installing mail smtp" --result "DONE" --color GREEN
  log_event "info" "mail mail_mime and net_smtp installed"

}

function php_purge_all_installations() {

  # Log
  display --indent 2 --text "- Purging PHP and libraries"
  log_event "info" "Removing all PHP versions and libraries ..."

  # apt command
  apt-get --yes purge php* -qq > /dev/null

  # Log
  clear_last_line
  display --indent 2 --text "- Purging PHP and libraries" --result "DONE" --color GREEN
  log_event "info" "PHP purged!"

}

function php_purge_installation() {

  # Log
  display --indent 2 --text "- Removing PHP-${PHP_V} and libraries"
  log_event "info" "Removing PHP-${PHP_V} and libraries ..."

  # apt command
  apt-get --yes purge "php${PHP_V}-fpm" "php${PHP_V}-mysql" php-xml "php${PHP_V}-xml" "php${PHP_V}-cli" "php${PHP_V}-curl" "php${PHP_V}-mbstring" "php${PHP_V}-gd" php-imagick "php${PHP_V}-intl" "php${PHP_V}-zip" "php${PHP_V}-bz2" php-bcmath "php${PHP_V}-soap" "php${PHP_V}-dev" php-pear -qq > /dev/null

  # Log
  clear_last_line
  display --indent 2 --text "- Removing PHP-${PHP_V} and libraries" --result "DONE" --color GREEN
  log_event "info" "PHP-${PHP_V} deleted!"

}

function php_installer_menu() {

  php_is_installed=$(php_check_if_installed)

  if [[ ${php_is_installed} == "false" ]]; then

    php_installer_title="PHP INSTALLER"
    php_installer_message="Choose a PHP version to install:"
    php_installer_options=(
      "01)" "INSTALL PHP DEFAULT" 
      "02)" "INSTALL PHP CUSTOM"
    )

  else

    php_installer_title="PHP HELPER"
    php_installer_message="Choose an option to run:"
    php_installer_options=(
      "01)" "INSTALL PHP DEFAULT" 
      "02)" "INSTALL PHP CUSTOM" 
      "03)" "RECONFIGURE PHP" 
      "04)" "ENABLE OPCACHE" 
      "05)" "DISABLE OPCACHE" 
      "06)" "OPTIMIZE PHP" 
      "07)" "REMOVE PHP"
    )

  fi

  # Check installed versions
  php_installed_versions=$(php_check_installed_version)

  # Setting PHP_V
  PHP_V=$(php_select_version_to_work_with "${php_installed_versions}")

  if [[ ${PHP_V} != "" ]]; then

    chosen_php_installer_options=$(whiptail --title "${php_installer_title}" --menu "${php_installer_message}" 20 78 10 "${php_installer_options[@]}" 3>&1 1>&2 2>&3)
    exitstatus="$?"
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_php_installer_options} == *"01"* ]]; then
        
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
        
        # ENABLE OPCACHE
        php_opcode_config "enable"

      fi
      if [[ ${chosen_php_installer_options} == *"05"* ]]; then
        
        # DISABLE OPCACHE
        php_opcode_config "disable"

      fi
      if [[ ${chosen_php_installer_options} == *"06"* ]]; then
        
        # OPTIMIZE PHP
        "${SFOLDER}/utils/php_optimizations.sh"

      fi
      if [[ ${chosen_php_installer_options} == *"07"* ]]; then
        
        # REMOVE PHP
        php_purge_installation

      fi

    fi

  fi
  
}

################################################################################

declare -g PHP_V

php_installer_menu
#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc3
################################################################################

################################################################################
# Get default php version for distro
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function php_get_distro_default_version() {

  local php_v

  DISTRO_V="$(get_ubuntu_version)"

  if [[ ${DISTRO_V} -eq "1804" ]]; then
    php_v="7.2" #Ubuntu 18.04 LTS Default

  elif [[ ${DISTRO_V} -eq "2004" ]]; then
    php_v="7.4" #Ubuntu 20.04 LTS Default

  elif [[ ${DISTRO_V} -eq "2204" ]]; then
    php_v="8.1" #Ubuntu 22.04 LTS Default

  else
    # Log
    display --indent 6 --text "- Checking distro version" --result "WARNING" --color YELLOW
    display --indent 8 --text "Non standard distro" --tcolor RED
    log_event "critical" "Non standard distro!" "false"
    return 1

  fi

  # Return
  echo "${php_v}"

  return 0

}

################################################################################
# Php installer
#
# Arguments:
#   $1 = ${php_v} - optional
#
# Outputs:
#   nothing
################################################################################

function php_installer() {

  local php_v="${1}"

  log_subsection "PHP Installer"

  if [[ -z ${php_v} || ${php_v} == "default" ]]; then
    php_v="$(php_get_distro_default_version)"
  fi

  php_bin="$(package_is_installed "php${php_v}-fpm")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then

    # Log
    display --indent 6 --text "- Installing php-${php_v} and libraries"
    log_event "info" "Installing php-${php_v} and libraries ..." "false"

    # Will remove all apt-get command output
    # sudo DEBIAN_FRONTEND=noninteractive apt-get install PACKAGE -y -qq < /dev/null > /dev/null

    # apt command
    sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install "php${php_v}-fpm" "php${php_v}-mysql" "php-imagick" "php${php_v}-xml" "php${php_v}-cli" "php${php_v}-curl" "php${php_v}-mbstring" "php${php_v}-gd" "php${php_v}-intl" "php${php_v}-zip" "php${php_v}-bz2" "php${php_v}-bcmath" "php${php_v}-soap" "php${php_v}-dev" "php-pear" -qq </dev/null >/dev/null

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Installing php-${php_v} and libraries" --result "DONE" --color GREEN
    log_event "info" "php-${php_v} installed" "false"

  fi

}

################################################################################
# Php custom installer
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function php_custom_installer() {

  add_ppa "ondrej/php"

  apt-get update -qq >/dev/null

  php_select_version_to_install

}

function php_select_version_to_install() {

  local phpv_to_install
  local chosen_phpv
  local phpv

  phpv_to_install=(
    "8.1" " " off
    "8.0" " " off
    "7.4" " " off
    "7.3" " " off
    "7.2" " " off
    "7.1" " " off
    "7.0" " " off
    "5.6" " " off
  )

  chosen_phpv="$(whiptail --title "PHP Version Selection" --checklist "Select the versions of PHP you want to install:" 20 78 15 "${phpv_to_install[@]}" 3>&1 1>&2 2>&3)"

  for phpv in ${chosen_phpv}; do

    phpv="$(sed -e 's/^"//' -e 's/"$//' <<<${phpv})" #needed to ommit double quotes

    php_installer "${phpv}"

  done

}

function php_redis_installer() {

  # apt command
  package_install_if_not "php-redis"

  # Service restart
  service redis-server restart

}

function mail_utils_installer() {

  pear_mail_is_installed="$(pear list | grep -w "Mail" | cut -d " " -f1)"

  if [[ ${pear_mail_is_installed} != "Mail" ]]; then

    # Log
    display --indent 6 --text "- Installing mail smtp"
    log_event "info" "Installing mail mail_mime and net_smtp ..." "false"

    # Creating tmp directory
    # Ref: https://stackoverflow.com/questions/59720692/php-7-4-1-pecl-is-not-working-trying-to-access-array-offset-on-value-of-type
    mkdir -p /tmp/pear/cache

    pear channel-update pear.php.net

    clear_previous_lines "2"

    # Install
    #pear -q install mail mail_mime net_smtp >/dev/null
    pear -q install mail >/dev/null
    pear -q install mail_mime >/dev/null
    pear -q install net_smtp >/dev/null

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Installing mail smtp" --result "DONE" --color GREEN
    log_event "info" "mail mail_mime and net_smtp installed" "false"

  fi

}

function php_purge_all_installations() {

  # Log
  display --indent 6 --text "- Purging PHP and libraries"
  log_event "info" "Removing all PHP versions and libraries ..." "false"

  # apt command
  apt-get --yes purge php* -qq >/dev/null

  # Log
  clear_previous_lines "1"
  display --indent 6 --text "- Purging PHP and libraries" --result "DONE" --color GREEN
  log_event "info" "PHP purged!" "false"

}

function php_purge_installation() {

  log_subsection "PHP Installer"

  # Log
  log_event "info" "Removing PHP-${PHP_V} and libraries ..." "false"
  display --indent 6 --text "- Removing PHP-${PHP_V} and libraries"

  # apt command
  apt-get --yes purge "php${PHP_V}-fpm" "php${PHP_V}-mysql" php-xml "php${PHP_V}-xml" "php${PHP_V}-cli" "php${PHP_V}-curl" "php${PHP_V}-mbstring" "php${PHP_V}-gd" php-imagick "php${PHP_V}-intl" "php${PHP_V}-zip" "php${PHP_V}-bz2" php-bcmath "php${PHP_V}-soap" "php${PHP_V}-dev" php-pear -qq >/dev/null

  # Log
  clear_previous_lines "1"
  log_event "info" "php-${PHP_V} and libraries deleted" "false"
  display --indent 6 --text "- Removing PHP-${PHP_V} and libraries" --result "DONE" --color GREEN

}

function php_composer_installer() {

  local composer_result
  local expected_signature
  local actual_signature

  log_event "info" "Running composer installer" "false"

  expected_signature="$(wget -q -O - https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  actual_signature="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

  if [[ ${expected_signature} != "${actual_signature}" ]]; then
    log_event "error" "Invalid installer signature" "false"
    rm composer-setup.php
    return 1

  fi

  # Command
  composer_result="$(${PHP} "${SCRIPTPATH}"/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    rm "${SCRIPTPATH}/composer-setup.php"

    log_event "info" "Composer Installer finished" "false"

    # Return
    echo "${exitstatus}"

    return 0

  else

    log_event "error" "Composer Installer failed" "false"
    log_event "debug" "composer_result=${composer_result}" "false"

    # Return
    echo "${exitstatus}"

    return 1

  fi

}

function php_composer_update_version() {

  composer self-update

}

function php_composer_update() {

  composer update

}

function php_composer_remove() {

  rm -rf /usr/local/bin/composer

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_event "info" "Composer removed" "false"

  else
    log_event "error" "Composer removal failed" "false"

  fi

}

function php_installer_menu() {

  declare -g PHP_V

  local php_installed_versions

  php_is_installed="$(php_check_if_installed)"

  if [[ ${php_is_installed} == "false" ]]; then

    php_installer_title="PHP INSTALLER"
    php_installer_message="Choose a PHP version to install:"
    php_installer_options=(
      "01)" "INSTALL PHP DEFAULT"
      "02)" "INSTALL PHP CUSTOM"
    )

  else

    php_installer_title="PHP INSTALLER"
    php_installer_message="Choose an option to run:"
    php_installer_options=(
      "01)" "INSTALL PHP DEFAULT"
      "02)" "INSTALL PHP CUSTOM"
      "03)" "RECONFIGURE PHP"
      "04)" "OPTIMIZE PHP"
      "05)" "UNINSTALL PHP"
    )

  fi

  # Check installed versions
  php_installed_versions="$(php_check_installed_version)"

  # Setting PHP_V
  if [[ ${php_installed_versions} != "" ]]; then

    PHP_V="$(php_select_version_to_work_with "${php_installed_versions}")"

  else

    PHP_V="$(php_get_distro_default_version)"

  fi

  chosen_php_installer_options="$(whiptail --title "${php_installer_title}" --menu "${php_installer_message}" 20 78 10 "${php_installer_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_php_installer_options} == *"01"* ]]; then

      # Installing packages
      php_installer
      mail_utils_installer
      php_redis_installer
      php_reconfigure "${PHP_V}"

    fi
    if [[ ${chosen_php_installer_options} == *"02"* ]]; then

      # INSTALL PHP CUSTOM
      php_custom_installer
      mail_utils_installer
      #php_redis_installer

    fi

    # Will only show if php is installed
    if [[ ${chosen_php_installer_options} == *"03"* ]]; then

      # RECONFIGURE PHP
      php_reconfigure ""

    fi
    if [[ ${chosen_php_installer_options} == *"04"* ]]; then

      # PHP OPTIZATIONS
      php_fpm_optimizations

    fi
    if [[ ${chosen_php_installer_options} == *"05"* ]]; then

      # REMOVE PHP
      php_purge_installation

    fi

  fi

}

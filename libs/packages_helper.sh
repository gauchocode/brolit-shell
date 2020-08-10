#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
#############################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"

################################################################################

# Check if program is installed (is_this_installed "mysql-server")
is_this_installed() {

  # $1 = ${package}

  local package=$1

  if [ "$(dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -c "ok installed")" == "1" ]; then

    log_event "info" "${package} is installed" "true"

    # Return
    echo "true"

  else

    log_event "info" "${package} is not installed" "true"

    # Return
    echo "false"

  fi
}

install_package_if_not() {

  # $1 = ${package}

  local package=$1

  if [[ "$(is_this_installed "${package}")" != "${package} is installed, it must be a clean server." ]]; then

    apt update -q4 &
    spinner_loading && apt install "${1}" -y

    log_event "info" "${package} installed" "true"

  fi

}

# Adding PPA (support multiple args)
# Ex: add_ppa ondrej/php ondrej/nginx
add_ppa() {

  for i in "$@"; do
    grep -h "^deb.*$i" /etc/apt/sources.list.d/* >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Adding ppa:$i"
      add-apt-repository -y ppa:$i
    else
      echo "ppa:$i already exists"
    fi
  done
  
}

check_packages_required() {

  # Check if sendemail is installed
  SENDEMAIL="$(which sendemail)"
  if [ ! -x "${SENDEMAIL}" ]; then
    apt -y install sendemail libio-socket-ssl-perl
  fi

  # Check if pv is installed
  PV="$(which pv)"
  if [ ! -x "${PV}" ]; then
    apt -y install pv
  fi

  # Check if bc is installed
  BC="$(which bc)"
  if [ ! -x "${BC}" ]; then
    apt -y install bc
  fi

  # Check if dig is installed
  DIG="$(which dig)"
  if [ ! -x "${DIG}" ]; then
    apt -y install dnsutils
  fi

  # Check if lbzip2 is installed
  LBZIP2="$(which lbzip2)"
  if [ ! -x "${LBZIP2}" ]; then
    apt -y install lbzip2
  fi

  # Check if dialog is installed
  DIALOG="$(which dialog)"
  if [ ! -x "${DIALOG}" ]; then
    apt -y install dialog
  fi

  WPCLI_INSTALLED=$(wpcli_check_if_installed)

  if [ "${WPCLI_INSTALLED}" = "true" ]; then

    wpcli_update

  else

    wpcli_install

  fi

}

check_default_php_version() {

  php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d"."

}

basic_packages_installation() {
  
  # Updating packages lists
  log_event "info" "Adding repos and updating package lists ..." "true"
  apt --yes install software-properties-common
  apt --yes update

  # Upgrading packages
  log_event "info" "Upgrading packages before installation ..." "true"
  apt --yes dist-upgrade

  # Installing packages
  log_event "info" "Installing basic packages ..." "true"
  apt --yes install vim unzip zip clamav ncdu imagemagick-* jpegoptim optipng webp sendemail libio-socket-ssl-perl dnsutils ghostscript pv ppa-purge

}

selected_package_installation() {

  # Define array of Apps to install
  local -n APPS_TO_INSTALL=(
    "certbot" " " off
    "monit" " " off
    "netdata" " " off
    "clamav" " " off
    "cockpit" " " off
    "wpcli" " " off
    "zabbix" " " off
  )

  local chosen_apps

  chosen_apps=$(whiptail --title "Apps Selection" --checklist "Select the apps you want to install:" 20 78 15 "${APPS_TO_INSTALL[@]}" 3>&1 1>&2 2>&3)
  
  for app in $chosen_apps; do
    
    app=$(sed -e 's/^"//' -e 's/"$//' <<<$app) #needed to ommit double quotes

    log_event "info" "Executing ${app} installer ..." "true"
    
    "${SFOLDER}/utils/installers/${app}_installer.sh"

  done

}

timezone_configuration() {

  #configure timezone
  dpkg-reconfigure tzdata

}

#compare_package_versions() {
#  OUTDATED=true
#  #echo "" >${BAKWP}/pkg-${NOW}.mail
#  for pk in ${PACKAGES[@]}; do
#    PK_VI=$(apt-cache policy ${pk} | grep Installed | cut -d ':' -f 2)
#    PK_VC=$(apt-cache policy ${pk} | grep Candidate | cut -d ':' -f 2)
#    if [ ${PK_VI} != ${PK_VC} ]; then
#      OUTDATED=false
#      # TODO: meterlo en un array para luego loopear
#      #echo " > ${pk} ${PK_VI} -> ${PK_VC} <br />" >>${BAKWP}/pkg-${NOW}.mail
#    fi
#  done
#}

remove_old_packages() {

  log_event "info" "Cleanning old system packages ..." "true"

  apt clean
  apt -y autoremove
  apt -y autoclean

  log_event "info" "System packages cleaned" "true"

}

install_image_optimize_packages() {

  apt -y install jpegoptim optipng pngquant gifsicle imagemagick-*

}

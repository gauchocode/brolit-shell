#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.2
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

  log_event "info" "Checking required packages ..." "false"
  log_section "Script Package Manager"

  # Check if sendemail is installed
  SENDEMAIL="$(which sendemail)"
  if [ ! -x "${SENDEMAIL}" ]; then
    display --indent 2 --text "- Installing sendemail"
    apt-get --yes install sendemail libio-socket-ssl-perl -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing sendemail" --result "DONE" --color GREEN
  fi

  # Check if pv is installed
  PV="$(which pv)"
  if [ ! -x "${PV}" ]; then
    display --indent 2 --text "- Installing pv"
    apt-get --yes install pv -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing pv" --result "DONE" --color GREEN
  fi

  # Check if bc is installed
  BC="$(which bc)"
  if [ ! -x "${BC}" ]; then
    display --indent 2 --text "- Installing bc"
    apt-get --yes install bc -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing bc" --result "DONE" --color GREEN
  fi

  # Check if dig is installed
  DIG="$(which dig)"
  if [ ! -x "${DIG}" ]; then
    display --indent 2 --text "- Installing dnsutils"
    apt-get --yes install dnsutils -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing dnsutils" --result "DONE" --color GREEN
  fi

  # Check if lbzip2 is installed
  LBZIP2="$(which lbzip2)"
  if [ ! -x "${LBZIP2}" ]; then
    display --indent 2 --text "- Installing lbzip2"
    apt-get --yes install lbzip2 -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing lbzip2" --result "DONE" --color GREEN
  fi

  # Check if zip is installed
  ZIP="$(which zip)"
  if [ ! -x "${ZIP}" ]; then
    display --indent 2 --text "- Installing zip"
    apt-get --yes install zip -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing zip" --result "DONE" --color GREEN
  fi

  # Check if unzip is installed
  UNZIP="$(which unzip)"
  if [ ! -x "${UNZIP}" ]; then
    display --indent 2 --text "- Installing unzip"
    apt-get --yes install unzip -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing unzip" --result "DONE" --color GREEN
  fi

  # Check if unzip is installed
  GIT="$(which git)"
  if [ ! -x "${GIT}" ]; then
    display --indent 2 --text "- Installing git"
    apt-get --yes install git -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Installing git" --result "DONE" --color GREEN
  fi

  # TAR
  TAR="$(which tar)"

  # FIND
  FIND="$(which find)"

  # MySQL
  MYSQL="$(which mysql)"
  MYSQLDUMP="$(which mysqldump)"
  if [ ! -x "${MYSQL}" ]; then
    display --indent 2 --text "- Checking MySQL installation" --result "ERROR" --color RED
    return 1
  fi

 # PHP
  PHP="$(which php)"
  if [ ! -x "${PHP}" ]; then
    display --indent 2 --text "- Checking PHP installation" --result "ERROR" --color RED
    return 1
  fi

  # CERTBOT
  CERTBOT="$(which certbot)"
  if [ ! -x "${CERTBOT}" ]; then
    display --indent 2 --text "- Checking CERTBOT installation" --result "WARNING" --color YELLOW
    return 1
  fi

  display --indent 2 --text "- Checking script dependencies" --result "DONE" --color GREEN

  # TODO: check if php is installed before ask for wp-cli

  WPCLI_INSTALLED=$(wpcli_check_if_installed)

  if [ "${WPCLI_INSTALLED}" = "true" ]; then

    wpcli_update

  else

    wpcli_install

  fi

  log_event "success" "All required packages are installed" "false"

}

check_default_php_version() {

  php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d"."

}

basic_packages_installation() {

  log_section "Basic Packages Installation"
  
  # Updating packages lists
  log_event "info" "Adding repos and updating package lists ..." "false"

  apt-get --yes install software-properties-common > /dev/null
  apt-get --yes update -qq > /dev/null

  display --indent 2 --text "- Adding repos and updating package lists" --result "DONE" --color GREEN

  # Upgrading packages
  log_event "info" "Upgrading packages before installation ..." "false"

  apt-get --yes dist-upgrade -qq > /dev/null

  display --indent 2 --text "- Upgrading packages before installation" --result "DONE" --color GREEN

  # Installing packages
  log_event "info" "Installing basic packages ..." "false"
  
  apt-get --yes install vim unzip zip clamav ncdu imagemagick-* jpegoptim optipng webp sendemail libio-socket-ssl-perl dnsutils ghostscript pv ppa-purge -qq > /dev/null

  display --indent 2 --text "- Installing basic packages" --result "DONE" --color GREEN

}

selected_package_installation() {

  # Define array of Apps to install
  local -n APPS_TO_INSTALL=(
    "certbot" " " off
    "monit" " " off
    "netdata" " " off
    "cockpit" " " off
    "zabbix" " " off
  )

  local chosen_apps

  chosen_apps=$(whiptail --title "Apps Selection" --checklist "Select the apps you want to install:" 20 78 15 "${APPS_TO_INSTALL[@]}" 3>&1 1>&2 2>&3)
  
  for app in $chosen_apps; do
    
    app=$(sed -e 's/^"//' -e 's/"$//' <<<${app}) #needed to ommit double quotes

    log_event "info" "Executing ${app} installer ..." "true"
    
    "${SFOLDER}/utils/installers/${app}_installer.sh"

  done

}

timezone_configuration() {

  #configure timezone
  dpkg-reconfigure tzdata
  
  display --indent 2 --text "- Time Zone configuration" --result "DONE" --color GREEN

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

  log_event "info" "Cleanning old system packages ..." "false"

  apt-get --yes clean -qq > /dev/null
  apt-get --yes autoremove -qq > /dev/null
  apt-get --yes autoclean -qq > /dev/null

  log_event "info" "System packages cleaned" "false"

}

install_image_optimize_packages() {

  apt-get --yes install jpegoptim optipng pngquant gifsicle imagemagick-* -qq > /dev/null

}

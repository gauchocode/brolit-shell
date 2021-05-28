#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.27
#############################################################################

# Check if program is installed (is_this_installed "mysql-server")
function is_this_installed() {

  # $1 = ${package}

  local package=$1

  if [ "$(dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -c "ok installed")" == "1" ]; then

    log_event "info" "${package} is installed"

    # Return
    echo "true"

  else

    log_event "info" "${package} is not installed"

    # Return
    echo "false"

  fi

}

function install_package_if_not() {

  # $1 = ${package}

  local package=$1

  if [[ "$(is_this_installed "${package}")" != "${package} is installed, it must be a clean server." ]]; then

    apt update -q4 &
    spinner_loading && apt install "${package}" -y

    log_event "info" "${package} installed"

  fi

}

function add_ppa() {

  # $@ - list of ppas

  for i in "$@"; do

    grep -h "^deb.*$i" /etc/apt/sources.list.d/* >/dev/null 2>&1

    exit_status=$?
    if [[ ${exit_status} -ne 0 ]]; then

      log_event "info" "Adding ppa:$i" "false"

      add-apt-repository -y ppa:"${i}"

    else

      log_event "info" "ppa:${i} already installed" "false"

    fi

  done

}

function check_packages_required() {

  log_event "info" "Checking required packages ..."
  log_section "Script Package Manager"

  # Declare globals
  declare -g SENDEMAIL
  declare -g PV
  declare -g BC
  declare -g DIG
  declare -g LBZIP2
  declare -g ZIP
  declare -g UNZIP
  declare -g GIT
  declare -g MOGRIFY
  declare -g JPEGOPTIM
  declare -g OPTIPNG
  declare -g TAR
  declare -g FIND
  declare -g MYSQL
  declare -g MYSQLDUMP
  declare -g PHP
  declare -g CERTBOT

  # Check if sendemail is installed
  SENDEMAIL="$(command -v sendemail)"
  if [[ ! -x "${SENDEMAIL}" ]]; then
    display --indent 2 --text "- Installing sendemail"
    apt-get --yes install sendemail libio-socket-ssl-perl -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing sendemail" --result "DONE" --color GREEN
  fi

  # Check if pv is installed
  PV="$(command -v pv)"
  if [[ ! -x "${PV}" ]]; then
    display --indent 2 --text "- Installing pv"
    apt-get --yes install pv -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing pv" --result "DONE" --color GREEN
  fi

  # Check if bc is installed
  BC="$(command -v bc)"
  if [[ ! -x "${BC}" ]]; then
    display --indent 2 --text "- Installing bc"
    apt-get --yes install bc -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing bc" --result "DONE" --color GREEN
  fi

  # Check if dig is installed
  DIG="$(command -v dig)"
  if [[ ! -x "${DIG}" ]]; then
    display --indent 2 --text "- Installing dnsutils"
    apt-get --yes install dnsutils -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing dnsutils" --result "DONE" --color GREEN
  fi

  # Check if net-tools is installed
  IFCONFIG="$(command -v ifconfig)"
  if [[ ! -x "${IFCONFIG}" ]]; then
    display --indent 2 --text "- Installing net-tools"
    apt-get --yes install net-tools -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing net-tools" --result "DONE" --color GREEN
  fi

  # Check if lbzip2 is installed
  LBZIP2="$(command -v lbzip2)"
  if [[ ! -x "${LBZIP2}" ]]; then
    display --indent 2 --text "- Installing lbzip2"
    apt-get --yes install lbzip2 -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing lbzip2" --result "DONE" --color GREEN
  fi

  # Check if zip is installed
  ZIP="$(command -v zip)"
  if [[ ! -x "${ZIP}" ]]; then
    display --indent 2 --text "- Installing zip"
    apt-get --yes install zip -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing zip" --result "DONE" --color GREEN
  fi

  # Check if unzip is installed
  UNZIP="$(command -v unzip)"
  if [[ ! -x "${UNZIP}" ]]; then
    display --indent 2 --text "- Installing unzip"
    apt-get --yes install unzip -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing unzip" --result "DONE" --color GREEN
  fi

  # Check if git is installed
  GIT="$(command -v git)"
  if [[ ! -x "${GIT}" ]]; then
    display --indent 2 --text "- Installing git"
    apt-get --yes install git -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing git" --result "DONE" --color GREEN
  fi

  # Check if vim is installed
  VIM="$(command -v vim)"
  if [[ ! -x "${VIM}" ]]; then
    display --indent 2 --text "- Installing vim"
    apt-get --yes install vim -qq >/dev/null
    clear_last_line
    display --indent 2 --text "- Installing vim" --result "DONE" --color GREEN
  fi

  # MOGRIFY
  MOGRIFY="$(command -v mogrify)"
  if [[ ! -x "${MOGRIFY}" ]]; then
    # Install image optimize packages
    install_image_optimize_packages
  fi

  # JPEGOPTIM
  JPEGOPTIM="$(command -v jpegoptim)"
  if [[ ! -x "${JPEGOPTIM}" ]]; then
    display --indent 2 --text "- Installing jpegoptim"
    # apt command
    apt-get --yes install jpegoptim -qq >/dev/null
    # Log
    clear_last_line
    display --indent 2 --text "- Installing jpegoptim" --result "DONE" --color GREEN
  fi

  # OPTIPNG
  OPTIPNG="$(command -v optipng)"
  if [[ ! -x "${OPTIPNG}" ]]; then
    display --indent 2 --text "- Installing optipng"
    # apt command
    apt-get --yes install optipng -qq >/dev/null
    # Log
    clear_last_line
    display --indent 2 --text "- Installing optipng" --result "DONE" --color GREEN
  fi

  # TAR
  TAR="$(command -v tar)"

  # FIND
  FIND="$(command -v find)"

  # CERTBOT
  CERTBOT="$(command -v certbot)"
  if [[ ! -x "${CERTBOT}" ]]; then
    display --indent 2 --text "- Checking CERTBOT installation" --result "WARNING" --color YELLOW
    display --indent 4 --text "CERTBOT not found" --tcolor YELLOW
    return 1

  fi

  # MySQL
  MYSQL="$(command -v mysql)"
  if [[ ! -x ${MYSQL} ]]; then

    if [[ ${SERVER_CONFIG} == *"mysql"* ]]; then

      display --indent 2 --text "- Checking MySQL installation" --result "ERROR" --color RED
      display --indent 4 --text "MySQL not found" --tcolor RED

      # TODO: ask for installation?

      return 1

    fi

  else

    MYSQLDUMP="$(command -v mysqldump)"

    if [[ -f ${MYSQL_CONF} ]]; then
      # Append login parameters to command
      MYSQL_ROOT="${MYSQL} --defaults-file=${MYSQL_CONF}"
      MYSQLDUMP_ROOT="${MYSQLDUMP} --defaults-file=${MYSQL_CONF}"

    fi

  fi

  # PHP
  PHP="$(command -v php)"
  if [[ ! -x "${PHP}" ]]; then

    if [[ ${SERVER_CONFIG} == *"php"* ]]; then

      # Log
      display --indent 2 --text "- Checking PHP installation" --result "ERROR" --color RED
      display --indent 4 --text "PHP not found" --tcolor RED

      return 1

    fi

  else

    # PHP is installed, now checking WP-CLI
    WPCLI_INSTALLED="$(wpcli_check_if_installed)"
    if [[ ${WPCLI_INSTALLED} = "true" ]]; then
      wpcli_update
    else
      wpcli_install
    fi

  fi

  # Log
  display --indent 2 --text "- Checking script dependencies" --result "DONE" --color GREEN
  log_event "info" "All required packages are installed"

}

function basic_packages_installation() {

  # Log
  log_subsection "Basic Packages Installation"

  log_event "info" "Adding repos and updating package lists ..."
  display --indent 6 --text "- Adding repos and updating package lists"

  # Updating packages lists
  apt-get --yes install software-properties-common >/dev/null
  apt-get --yes update -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Adding repos and updating package lists" --result "DONE" --color GREEN

  log_event "info" "Upgrading packages before installation ..."
  display --indent 6 --text "- Upgrading packages before installation"

  # Upgrading packages
  apt-get --yes dist-upgrade -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Upgrading packages before installation" --result "DONE" --color GREEN

  # Installing packages
  log_event "info" "Installing basic packages ..."
  display --indent 6 --text "- Installing basic packages"

  # Installing packages
  apt-get --yes install ncdu imagemagick-* webp ghostscript pv ppa-purge -qq >/dev/null

  # Log
  clear_last_line
  clear_last_line
  display --indent 6 --text "- Installing basic packages" --result "DONE" --color GREEN

}

function selected_package_installation() {

  # Define array of Apps to install
  local -n apps_to_install=(
    "certbot" " " off
    "monit" " " off
    "netdata" " " off
    #"cockpit" " " off
  )

  local chosen_apps

  chosen_apps="$(whiptail --title "Apps Selection" --checklist "Select the apps you want to install:" 20 78 15 "${apps_to_install[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_subsection "Package Installer"

    for app in ${chosen_apps}; do

      app=$(sed -e 's/^"//' -e 's/"$//' <<<${app}) #needed to ommit double quotes

      log_event "info" "Executing ${app} installer ..."

      case ${app} in

      certbot)
        certbot_installer
        ;;

      monit)
        monit_installer_menu
        ;;

      netdata)
        netdata_installer
        ;;

      cockpit)
        cockpit_installer
        ;;

      *)
        log_event "error" "Package installer for ${app} not found!"
        ;;

      esac

    done

  else

    log_event "info" "Package installer ommited ..."

  fi

}

function timezone_configuration() {

  # Log
  log_subsection "Timezone Configuration"

  # Configure timezone
  dpkg-reconfigure tzdata

  # Log
  clear_last_line
  clear_last_line
  clear_last_line
  display --indent 6 --text "- Time Zone configuration" --result "DONE" --color GREEN

  log_break "true"

}

function remove_old_packages() {

  # Log
  log_event "info" "Cleanning old system packages ..."
  display --indent 6 --text "- Cleanning old system packages"

  # apt commands
  apt-get --yes clean -qq >/dev/null
  apt-get --yes autoremove -qq >/dev/null
  apt-get --yes autoclean -qq >/dev/null

  # Log
  clear_last_line
  log_event "info" "Old system packages cleaned"
  display --indent 6 --text "- Cleanning old system packages" --result "DONE" --color GREEN

}

function install_image_optimize_packages() {

  # Log
  log_event "info" "Installing jpegoptim, optipng and imagemagick"
  display --indent 6 --text "- Installing jpegoptim, optipng and imagemagick"

  # apt command
  apt-get --yes install jpegoptim optipng pngquant gifsicle imagemagick-* -qq >/dev/null

  # Log
  log_event "info" "Installation finished"
  clear_last_line # need an extra call to clear installation output
  clear_last_line
  display --indent 6 --text "- Installing jpegoptim, optipng and imagemagick" --result "DONE" --color GREEN

}

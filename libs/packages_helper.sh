#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 3.0
################################################################################

# Check if program is installed (is_this_installed apache2)
is_this_installed() {
  if [ "$(dpkg-query -W -f='${Status}' "${1}" 2>/dev/null | grep -c "ok installed")" == "1" ]; then
    print_text_in_color "$IRed" "${1} is installed, it must be a clean server."
    exit 1
  fi
}

# Install_if_not program
install_if_not() {
  if [[ "$(is_this_installed "${1}")" != "${1} is installed, it must be a clean server." ]]; then
    apt update -q4 &
    spinner_loading && apt install "${1}" -y
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

  echo " > Cleanning old system packages ..." >>$LOG
  echo -e ${YELLOW}" > Cleanning old system packages ..."${ENDCOLOR}
  apt clean
  apt -y autoremove
  apt -y autoclean

}

install_image_optimize_packages() {

  apt -y install jpegoptim optipng pngquant gifsicle

}

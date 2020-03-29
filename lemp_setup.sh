#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta10
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh

################################################################################

basic_packages_installation() {
  # Updating packages
  echo " > Adding repos and updating package lists ..." >>$LOG
  apt --yes install software-properties-common
  apt --yes update
  echo " > Upgrading packages before installation ..." >>$LOG
  apt --yes dist-upgrade

  echo " > Installing basic packages ..." >>$LOG
  apt --yes install unzip zip clamav ncdu jpegoptim optipng webp sendemail libio-socket-ssl-perl dnsutils ghostscript pv
}

selected_package_installation() {

  CHOSEN_APPS=$(whiptail --title "Apps Selection" --checklist "Select the apps you want to install after LEMP setup:" 20 78 15 "${APPS_TO_INSTALL[@]}" 3>&1 1>&2 2>&3)
  echo "Setting CHOSEN_APPS="$CHOSEN_APPS
  for app in $CHOSEN_APPS; do
    app=$(sed -e 's/^"//' -e 's/"$//' <<<$app) #needed to ommit double quotes
    echo -e ${CYAN}" > Executing ${app} installer ..."${ENDCOLOR}
    ${SFOLDER}/utils/installers/${app}_installer.sh

  done

}

timezone_configuration() {

  #configure timezone
  dpkg-reconfigure tzdata

}

################################################################################

PHP_V="7.2" # Ubuntu 18.04 LTS Default

# Define array of Apps to install
APPS_TO_INSTALL=(
  "certbot" " " off
  "monit" " " off
  "netdata" " " off
  "cockpit" " " off
  "wpcli" " " off
)

### Log Start
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="${SFOLDER}/logs"
if [ ! -d "${SFOLDER}/logs" ]; then
  echo " > Folder ${SFOLDER}/logs doesn't exist. Creating now ..."
  mkdir ${SFOLDER}/logs
  echo " > Folder ${SFOLDER}/logs created ..."
fi

LOG_NAME=log_lemp_${TIMESTAMP}.log
LOG=${PATH_LOG}/${LOG_NAME}

### exoirt LOG and SFOLDER vars
export LOG SFOLDER

checking_scripts_permissions

basic_packages_installation

${SFOLDER}/utils/installers/mysql_installer.sh

${SFOLDER}/utils/installers/nginx_installer.sh

${SFOLDER}/utils/installers/php_installer.sh

# Configuring packages
timezone_configuration

#${SFOLDER}/utils/php_optimizations.sh

selected_package_installation

echo -e ${GREEN}" > LEMP SETUP COMPLETED ..."${ENDCOLOR}

echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >>$LOG

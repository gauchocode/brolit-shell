#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc01
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/packages_helper.sh"

################################################################################

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
  mkdir "${SFOLDER}/logs"
  echo " > Folder ${SFOLDER}/logs created ..."
fi

LOG_NAME=log_lemp_${TIMESTAMP}.log
LOG=${PATH_LOG}/${LOG_NAME}

### exoirt LOG and SFOLDER vars
export LOG SFOLDER

checking_scripts_permissions

basic_packages_installation

"${SFOLDER}/utils/installers/mysql_installer.sh"

"${SFOLDER}/utils/installers/nginx_installer.sh"

"${SFOLDER}/utils/installers/php_installer.sh"

# Configuring packages
timezone_configuration

#${SFOLDER}/utils/php_optimizations.sh

selected_package_installation "${APPS_TO_INSTALL[@]}"

echo -e ${GREEN}" > LEMP SETUP COMPLETED ..."${ENDCOLOR}

echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >>$LOG

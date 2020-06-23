#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc05
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"

################################################################################

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

# Configuring packages
timezone_configuration

# Installing basic packages
basic_packages_installation

# MySQL Installer
"${SFOLDER}/utils/installers/mysql_installer.sh"

# Nginx Installer
"${SFOLDER}/utils/installers/nginx_installer.sh"

# PHP Installer
"${SFOLDER}/utils/installers/php_installer.sh"

selected_package_installation

echo -e ${B_GREEN}" > LEMP SETUP COMPLETED!"${ENDCOLOR}

echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >>$LOG

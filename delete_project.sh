#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.9
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
    echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
    exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh

################################################################################

ask_folder_to_install_sites

MENU_TITLE="PROJECT TO DELETE"
directory_browser "${MENU_TITLE}" "${FOLDER_TO_INSTALL}"

mkdir ${SFOLDER}/tmp-backup

echo -e ${CYAN}" > Making a backup ..."${ENDCOLOR}
cp -r $filepath"/"$filename ${SFOLDER}/tmp-backup
echo -e ${GREEN}" > Project files stored: ${SFOLDER}/tmp-backup"${ENDCOLOR}

rm -R ${SFOLDER}/tmp-backup
echo -e ${GREEN}" > Project Files Deleted!"${ENDCOLOR}

mysql_databases_list
CHOSEN_DB=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to work with" 20 78 10 $(for x in ${DBS}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Setting CHOSEN_DB="${CHOSEN_DB} >>$LOG
else
    exit 1
fi

# TODO: remove _STATE to make USER_DB

mysql_database_export "${CHOSEN_DB}" "${filename}_DB.sql"

#mysql_user_delete "${USER_DB}"

mysql_database_drop "${CHOSEN_DB}"

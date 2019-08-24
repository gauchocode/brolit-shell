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

# Folder where sites are hosted
ask_folder_to_install_sites

MENU_TITLE="PROJECT TO DELETE"
directory_browser "${MENU_TITLE}" "${FOLDER_TO_INSTALL}"

echo "directory_broser returns: " $filepath"/"$filename
if [[ -z "${filepath}" || ${filepath} == "" ]]; then

    echo -e ${YELLOW}" > Skipped!"${ENDCOLOR}

else

    # Creating a tmp directory
    mkdir ${SFOLDER}/tmp-backup

    # Making a backup of project files
    echo -e ${CYAN}" > Making a backup ..."${ENDCOLOR}
    cp -r $filepath"/"$filename ${SFOLDER}/tmp-backup
    echo -e ${GREEN}" > Project files stored: ${SFOLDER}/tmp-backup"${ENDCOLOR}

    # Deleting project files
    rm -R $filepath"/"$filename
    echo -e ${GREEN}" > Project Files Deleted!"${ENDCOLOR}

    # Removing last slash from string
    filename=${filename%/}

    # Making a copy of nginx configuration file
    cp -r /etc/nginx/sites-available/${filename} ${SFOLDER}/tmp-backup

    # Deleting nginx configuration file
    rm /etc/nginx/sites-available/${filename}
    rm /etc/nginx/sites-enabled/${filename}

fi

# List databases
DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"
CHOSEN_DB=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to work with" 20 78 10 $(for x in ${DBS}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Setting CHOSEN_DB="${CHOSEN_DB} >>$LOG

    # Removing DB prefix to find mysql user
    suffix="$(cut -d'_' -f2 <<<"${CHOSEN_DB}")"
    PROJECT_NAME=${CHOSEN_DB%"_$suffix"}
    USER_DB="${PROJECT_NAME}_user"

    # Making a database Backup
    mysql_database_export "${CHOSEN_DB}" "${filename}_DB.sql"

    # Deleting mysql user
    mysql_user_delete "${USER_DB}"

    # Deleting project database
    mysql_database_drop "${CHOSEN_DB}"

else
    exit 1

fi
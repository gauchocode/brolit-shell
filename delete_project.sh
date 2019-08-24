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

# Creating a tmp directory
mkdir ${SFOLDER}/tmp-backup

echo "directory_broser returns: " $filepath"/"$filename
if [[ -z "${filepath}" || ${filepath} == "" ]]; then

    echo -e ${YELLOW}" > Skipped!"${ENDCOLOR}

else

    # Removing last slash from string
    filename=${filename%/}

    # Making a backup of project files
    echo -e ${CYAN}" > Making a backup ..."${ENDCOLOR}
    #cp -r $filepath"/"$filename ${SFOLDER}/tmp-backup
    TAR_FILE=$($TAR --exclude '.git' --exclude '*.log' -jcpf ${SFOLDER}/tmp-backup/backup-${filename}_files.tar.bz2 --directory=${FOLDER_TO_INSTALL} ${filename} >>$LOG)

    if ${TAR_FILE}; then

        echo -e ${GREEN}" > Backup project files stored: ${SFOLDER}/tmp-backup"${ENDCOLOR}

        echo " > Trying to create folder ${FOLDER_NAME} in Dropbox ..." >>$LOG
        OLD_SITES_DP_F="/old-sites"
        ${DPU_F}/dropbox_uploader.sh mkdir /${OLD_SITES_DP_F}
        ${DPU_F}/dropbox_uploader.sh mkdir /${OLD_SITES_DP_F}/${filename}/

        echo " > Uploading backup to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${SFOLDER}/tmp-backup/backup-${filename}_files.tar.bz2 ${OLD_SITES_DP_F}/${filename}/

        # Deleting project files
        #rm -R $filepath"/"$filename
        echo -e ${GREEN}" > Project files deleted from ${FOLDER_TO_INSTALL}!"${ENDCOLOR}

        # Making a copy of nginx configuration file
        cp -r /etc/nginx/sites-available/${filename} ${SFOLDER}/tmp-backup

        # Deleting nginx configuration file
        rm /etc/nginx/sites-available/${filename}
        rm /etc/nginx/sites-enabled/${filename}
    fi

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
    mysql_database_export "${CHOSEN_DB}" "${SFOLDER}/tmp-backup/${CHOSEN_DB}_DB.sql"

    # TODO: TAR Backup and Upload to Dropbox
    
    # Deleting project database
    mysql_database_drop "${CHOSEN_DB}"

    # Deleting mysql user

    # TODO: need to ask
    #mysql_user_delete "${USER_DB}"

else
    exit 1

fi

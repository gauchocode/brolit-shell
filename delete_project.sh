#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta7
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
    echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
    exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh
source ${SFOLDER}/libs/backup_helper.sh

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

    TAR_FILE=$($TAR --exclude '.git' --exclude '*.log' -jcpf ${SFOLDER}/tmp-backup/backup-${filename}_files.tar.bz2 --directory=${FOLDER_TO_INSTALL} ${filename} >>$LOG)

    if ${TAR_FILE}; then

        echo -e ${GREEN}" > Backup project files stored: ${SFOLDER}/tmp-backup"${ENDCOLOR}

        echo " > Trying to create folder ${FOLDER_NAME} in Dropbox ..." >>$LOG
        OLD_SITES_DP_F="/old-sites"
        ${DPU_F}/dropbox_uploader.sh mkdir /${OLD_SITES_DP_F}
        ${DPU_F}/dropbox_uploader.sh mkdir /${OLD_SITES_DP_F}/${filename}/

        echo " > Uploading backup to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${SFOLDER}/tmp-backup/backup-${filename}_files.tar.bz2 ${OLD_SITES_DP_F}/${filename}/

        # Delete project files
        rm -R $filepath"/"$filename
        echo -e ${GREEN}" > Project files deleted from ${FOLDER_TO_INSTALL}!"${ENDCOLOR}

        # Make a copy of nginx configuration file
        cp -r /etc/nginx/sites-available/${filename} ${SFOLDER}/tmp-backup

        # Delete nginx configuration file
        rm /etc/nginx/sites-available/${filename}
        rm /etc/nginx/sites-enabled/${filename}
        echo -e ${GREEN}" > Nginx config files deleted!"${ENDCOLOR}

    fi

fi

# List databases
DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"
CHOSEN_DB=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to work with" 20 78 10 $(for x in ${DBS}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Setting CHOSEN_DB="${CHOSEN_DB} >>$LOG

    # Remove DB prefix to find mysql user
    suffix="$(cut -d'_' -f2 <<<"${CHOSEN_DB}")"
    PROJECT_NAME=${CHOSEN_DB%"_$suffix"}
    USER_DB="${PROJECT_NAME}_user"

    # Make a database Backup
    mysql_database_export "${CHOSEN_DB}" "${SFOLDER}/tmp-backup/${CHOSEN_DB}_DB.sql"

    # TO-TEST
    make_database_backup "database" "${CHOSEN_DB}"

    # Delete project database
    mysql_database_drop "${CHOSEN_DB}"

    # Delete mysql user
    # TODO (steps): 
    # 1- Read user form wp-config if exists (if not show message)
    # 2- Check if user exists, 
    # 3- Ask if you want delete it}
    # 4- Remove it or ignore it
    #mysql_user_exists "" ""
    #mysql_user_delete "${USER_DB}"

else
    exit 1

fi

# Delete tmp backups
#rm -R ${SFOLDER}/tmp-backup

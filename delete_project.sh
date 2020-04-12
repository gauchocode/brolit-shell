#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta11
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
    echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
    exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/mysql_helper.sh"
source "${SFOLDER}/libs/backup_helper.sh"

################################################################################

# TODO: NEED REFACTOR
# 1- Files backup with file_backups functions, checking if site is WP or what.
# 2- MySQL backup with mysql_backup functions, try to search for a wp-config or another parameter file on site.
# 3- If BD and USER is found, backup and upload DB, and ask for confirm user deletion.
# 4- Ask for confirm delete temp files.
#
# IMPORTANT: POSIBLE NEW BACKUP STRUCTURE
#
# VPS_NAME -> SERVER_CONFIGS (PHP, MySQL, Custom Status Log)
#          -> PROYECTS -> ACTIVE
#                      -> INACTIVE
#                      -> ACTIVE/INACTIVE  -> DATABASE
#                                          -> FILES
#                                          -> CONFIGS (nginx, letsencrypt)
#          -> DATABASES
#          -> SITES_NO_DB
#
# The problem with this new structure is that you need to match FILES-BD.
#
# Symphony, config BD on /var/www/PROJECT/app/config/parameters.yml
#

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

    BK_TYPE="sites"

    # Removing last slash from string
    FILENAME=${filename%/}

    # Making a backup of project files
    echo -e ${CYAN}" > Making a backup ..."${ENDCOLOR}

    #TAR_FILE=$($TAR --exclude '.git' --exclude '*.log' -jcpf ${SFOLDER}/tmp-backup/backup-${filename}_files.tar.bz2 --directory=${FOLDER_TO_INSTALL} ${filename} >>$LOG)
    make_files_backup "${BK_TYPE}" "${SITES}" "${FILENAME}"

    # if ${TAR_FILE}; then

    #     echo -e ${GREEN}" > Backup project files stored: ${SFOLDER}/tmp-backup"${ENDCOLOR}

    #     echo " > Trying to create folder ${FOLDER_NAME} in Dropbox ..." >>$LOG
    #     OLD_SITES_DP_F="/old-sites"
    #     ${DPU_F}/dropbox_uploader.sh mkdir /${OLD_SITES_DP_F}
    #     ${DPU_F}/dropbox_uploader.sh mkdir /${OLD_SITES_DP_F}/${filename}/

    #     echo " > Uploading backup to Dropbox ..." >>$LOG
    #     ${DPU_F}/dropbox_uploader.sh upload ${SFOLDER}/tmp-backup/backup-${filename}_files.tar.bz2 ${OLD_SITES_DP_F}/${filename}/

    #     # Delete project files
    #     rm -R $filepath"/"$filename
    #     echo -e ${GREEN}" > Project files deleted from ${FOLDER_TO_INSTALL}!"${ENDCOLOR}

    #     # Make a copy of nginx configuration file
    #     cp -r /etc/nginx/sites-available/${filename} ${SFOLDER}/tmp-backup

    #     # Delete nginx configuration file
    #     rm /etc/nginx/sites-available/${filename}
    #     rm /etc/nginx/sites-enabled/${filename}
    #     echo -e ${GREEN}" > Nginx config files deleted!"${ENDCOLOR}

    # fi

    if [ $? -eq 0 ]; then

        # Creating new folder structure for old projects
        ${DPU_F}/dropbox_uploader.sh -q mkdir "/old-sites"

        # Moving deleted project backups to another dropbox directory
        #move <REMOTE_FILE/DIR> <REMOTE_FILE/DIR>
        echo -e ${B_CYAN}" > Running: ${DPU_F}/dropbox_uploader.sh move ${BK_TYPE}/${FILENAME} /old-sites"${ENDCOLOR}
        ${DPU_F}/dropbox_uploader.sh move "${BK_TYPE}/${FILENAME}" "/old-sites"

        # Delete project files
        rm -R $filepath"/"$FILENAME
        echo -e ${GREEN}" > Project files deleted for ${FILENAME}!"${ENDCOLOR}

        # Make a copy of nginx configuration file
        cp -r /etc/nginx/sites-available/${FILENAME} ${SFOLDER}/tmp-backup

        # Delete nginx configuration file
        rm /etc/nginx/sites-available/${FILENAME}
        rm /etc/nginx/sites-enabled/${FILENAME}
        echo -e ${B_GREEN}" > Nginx config files for ${FILENAME} deleted!"${ENDCOLOR}

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

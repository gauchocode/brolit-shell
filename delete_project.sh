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
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"

################################################################################

# TODO: NEED REFACTOR
# 1- Files backup with file_backups functions, checking if site is WP or what.
# 2- MySQL backup with mysql_backup functions, try to search for a wp-config or another parameter file on site.
# 3- If BD and USER is found, backup and upload DB, and ask for confirm user deletion.
# 4- Ask for confirm delete temp files.
#
# Symphony, config BD on /var/www/PROJECT/app/config/parameters.yml
#

# Folder where sites are hosted
folder_to_work=$(ask_folder_to_install_sites "${SITES}")

menu_title="PROJECT TO DELETE"
directory_browser "${menu_title}" "${folder_to_work}"

# Creating a tmp directory
mkdir "${SFOLDER}/tmp-backup"

#echo "directory_broser returns: " $filepath"/"$filename
if [[ -z "${filepath}" || ${filepath} == "" ]]; then

    echo -e ${YELLOW}" > Skipped!"${ENDCOLOR}

else

    BK_TYPE="site"

    # Removing last slash from string
    filename=${filename%/}

    # Trying to know project type
    project_type=$(get_project_type "${SITES}/${filename}")

    # TODO: if project_type = wordpress, get database credentials from wp-config.php
    project_db_name=$(get_project_db_name "${project_type}")
    project_db_user=$(get_project_db_user "${project_type}")
    project_db_pass=$(get_project_db_pass "${project_type}")

    echo -e ${CYAN}" > Project Type: ${project_type}"${ENDCOLOR}
    echo " > Project Type: ${project_type}!">>$LOG

    # Making a backup of project files
    make_files_backup "${BK_TYPE}" "${SITES}" "${filename}"

    if [ $? -eq 0 ]; then

        # Creating new folder structure for old projects
        output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}/offline-site" 2>&1)

        # Moving deleted project backups to another dropbox directory
        echo -e ${B_CYAN}" > Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${filename} /${VPSNAME}/offline-site"${ENDCOLOR}
        $DROPBOX_UPLOADER move "/${VPSNAME}/${BK_TYPE}/${filename}" "/${VPSNAME}/offline-site"

        # Delete project files
        rm -R $filepath"/"$filename
        echo -e ${GREEN}" > Project files deleted for ${filename}"${ENDCOLOR}
        echo " > Project files deleted for ${filename}">>$LOG

        # Make a copy of nginx configuration file
        cp -r "/etc/nginx/sites-available/${filename}" "${SFOLDER}/tmp-backup"

        # TODO: make a copy of letsencrypt files?

        # TODO: upload to dropbox config_file ??

        # Delete nginx configuration file
        delete_nginx_server "${filename}"
        echo -e ${B_GREEN}" > Nginx config files for ${filename} deleted!"${ENDCOLOR}

    fi

fi

# TODO: if project_db_name, project_db_user and project_db_pass are defined 
#       and can connect to db, only ask for delete confirmation

# List databases
DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"
CHOSEN_DB=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to work with" 20 78 10 $(for x in ${DBS}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

    BK_TYPE="database"

    echo "Setting CHOSEN_DB="${CHOSEN_DB} >>$LOG

    # Remove DB prefix to find mysql user
    suffix="$(cut -d'_' -f2 <<<"${CHOSEN_DB}")"
    project_name=${CHOSEN_DB%"_$suffix"}
    user_db="${project_name}_user"

    # Make a database Backup
    make_database_backup "${BK_TYPE}" "${CHOSEN_DB}"

    # Moving deleted project backups to another dropbox directory
    echo -e ${B_CYAN}" > Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${CHOSEN_DB} /${VPSNAME}/offline-site"${ENDCOLOR}
    $DROPBOX_UPLOADER move "/${VPSNAME}/${BK_TYPE}/${CHOSEN_DB}" "/${VPSNAME}/offline-site"

    # Delete project database
    mysql_database_drop "${CHOSEN_DB}"

    # Delete mysql user
    # TODO (steps): 
    # 1- Read user form wp-config if exists (if not show message)
    # 2- Check if user exists, 
    # 3- Ask if you want delete it (maybe we should search in al wp-config.php if user is used?)
    # 4- Remove it or ignore it
    #mysql_user_exists ""
    #mysql_user_delete "${user_db}"

else
    exit 1

fi

#TODO: ask for deleting tmp-backup folder
# Delete tmp backups
#rm -R ${SFOLDER}/tmp-backup

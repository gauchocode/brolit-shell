#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
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
# shellcheck source=${SFOLDER}/libs/nginx_helper.sh
source "${SFOLDER}/libs/nginx_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"

################################################################################

# TODO: NEED REFACTOR
# 1- Files backup with file_backups functions, checking if site is WP or what.
# 2- Ask for confirm delete temp files.
# 3- Ask what to do with letsencrypt and nginx server config files
#
# Symphony, config BD on /var/www/PROJECT/app/config/parameters.yml
#

delete_project_files() {

    log_event "info" "Running delete_project script" "true"

    # Folder where sites are hosted: $SITES
    menu_title="PROJECT TO DELETE"
    directory_browser "${menu_title}" "${SITES}"

    ### Creating temporary folders
    if [ ! -d "${SFOLDER}/tmp-backup" ]; then
        mkdir "${SFOLDER}/tmp-backup"
        log_event "info" "Temp files directory created: ${SFOLDER}/tmp-backup" "true"
    fi

    #echo "directory_broser returns: " $filepath"/"$filename
    if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Skipped!" "true"

        # Return
        echo "error"

    else

        BK_TYPE="site"

        # Removing last slash from string
        filename=${filename%/}

        log_event "info" "Project to delete: ${filename}" "true"

        # Trying to know project type
        project_type=$(get_project_type "${SITES}/${filename}")

        # TODO: if project_type = wordpress, get database credentials from wp-config.php
        #project_db_name=$(get_project_db_name "${project_type}")
        #project_db_user=$(get_project_db_user "${project_type}")

        log_event "info" "Project Type: ${project_type}" "true"

        # Making a backup of project files
        make_files_backup "${BK_TYPE}" "${SITES}" "${filename}"

        if [ $? -eq 0 ]; then

            # Creating new folder structure for old projects
            output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}/offline-site" 2>&1)

            # Moving deleted project backups to another dropbox directory
            log_event "info" "dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${filename} /${VPSNAME}/offline-site" "true"
            $DROPBOX_UPLOADER move "/${VPSNAME}/${BK_TYPE}/${filename}" "/${VPSNAME}/offline-site"

            # Delete project files
            rm -R $filepath"/"$filename
            log_event "info" "Project files deleted for ${filename}" "true"

            # Make a copy of nginx configuration file
            cp -r "/etc/nginx/sites-available/${filename}" "${SFOLDER}/tmp-backup"

            # TODO: make a copy of letsencrypt files?

            # TODO: upload to dropbox config_file ??

            # Delete nginx configuration file
            nginx_server_delete "${filename}"

            telegram_send_message "⚠️ ${VPSNAME}: Project files deleted for: ${filename}"

            # Return
            echo "${filename}"
        
        else

            # Return
            echo "error"
            

        fi

    fi

}

delete_project_database() {

    # $1 = {database}

    local database=$1

    # TODO: if project_db_name, project_db_user and project_db_pass are defined 
    #       and can connect to db, only ask for delete confirmation

    # List databases
    DBS=$(${MYSQL} -u "${MUSER}" -p"${MPASS}" -Bse 'show databases')
    CHOSEN_DB=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to delete" 20 78 10 $(for x in ${DBS}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then

        BK_TYPE="database"

        # Remove DB prefix to get project_name
        suffix="$(cut -d'_' -f2 <<<"${CHOSEN_DB}")"
        project_name=${CHOSEN_DB%"_$suffix"}
        user_db="${project_name}_user"

        # Make a database Backup
        make_database_backup "${BK_TYPE}" "${CHOSEN_DB}"

        # Moving deleted project backups to another dropbox directory
        log_event "info" "Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${CHOSEN_DB} /${VPSNAME}/offline-site" "true"
        ${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${CHOSEN_DB}" "/${VPSNAME}/offline-site"

        # Delete project database
        mysql_database_drop "${CHOSEN_DB}"

        # Delete mysql user
        while true; do

            echo -e ${YELLOW}"> Do you want to remove database user? It could be used on another project."${ENDCOLOR}
            read -p "Please type 'y' or 'n'" yn

            case $yn in
                [Yy]* )
                
                mysql_user_delete "${user_db}"
                break;;
                
                [Nn]* )

                log_event "warning" "Aborting MySQL user deletion ..." "true"
                break;;

                * ) echo " > Please answer yes or no.";;
            esac
        done

        telegram_send_message "⚠️ ${VPSNAME}: Database ${CHOSEN_DB} deleted!"

    else
        # Return
        echo "error"

    fi

}

delete_project() {

    local delete_files_result

    delete_files_result=$(delete_project_files)

    #log_event "debug" "delete_files_result=$delete_files_result" "true"

    if [ "${delete_files_result}" != "error" ]; then

        delete_project_database "${delete_files_result}"

    else

        log_event "error" "Error deleting project ..." "true"
        exit 1

    fi
 
    #TODO: ask for deleting tmp-backup folder
    # Delete tmp backups
    #rm -R ${SFOLDER}/tmp-backup

}

################################################################################

delete_project
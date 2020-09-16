#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.2
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
    echo -e "${B_RED} > Error: The script can only be runned by runner.sh! Exiting ...${ENDCOLOR}"
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
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"
# shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
source "${SFOLDER}/libs/telegram_notification_helper.sh"

################################################################################

# TODO: NEED REFACTOR
# 1- Files backup with file_backups functions, checking if site is WP or what.
# 2- Ask for confirm delete temp files.
# 3- Ask what to do with letsencrypt and nginx server config files
#
# Symphony, config BD on /var/www/PROJECT/app/config/parameters.yml
#

delete_project_files() {

    local project_domain dropbox_output

    log_event "info" "Performing Action: Delete Project" "false"

    log_section "Delete Project"

    # Folder where sites are hosted: $SITES
    menu_title="PROJECT TO DELETE"
    directory_browser "${menu_title}" "${SITES}"

    # Directory_broser returns: " $filepath"/"$filename
    if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Delete project cancelled" "false"

        # Return
        return 1

    else

        ### Creating temporary folders
        if [ ! -d "${SFOLDER}/tmp-backup" ]; then
            mkdir "${SFOLDER}/tmp-backup"
            log_event "info" "Temp files directory created: ${SFOLDER}/tmp-backup" "false"
        fi

        BK_TYPE="site"

        # Removing last slash from string
        project_domain=${filename%/}

        log_event "info" "Project to delete: ${project_domain}" "false"
        display --indent 2 --text "- Selecting ${project_domain} for deletion" --result "DONE" --color GREEN

        # Trying to know project type
        project_type=$(get_project_type "${SITES}/${project_domain}")

        # TODO: if project_type = wordpress, get database credentials from wp-config.php
        #project_db_name=$(get_project_db_name "${project_type}")
        #project_db_user=$(get_project_db_user "${project_type}")

        log_event "info" "Project Type: ${project_type}" "false"

        # Making a backup of project files
        make_files_backup "${BK_TYPE}" "${SITES}" "${project_domain}"

        if [ $? -eq 0 ]; then

            # Creating new folder structure for old projects
            dropbox_output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}/offline-site" 2>&1)

            # Moving deleted project backups to another dropbox directory
            log_event "info" "dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${project_domain} /${VPSNAME}/offline-site" "false"
            dropbox_output=$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${project_domain}" "/${VPSNAME}/offline-site" 2>&1)
            # TODO: if destination folder already exists, it fails
            display --indent 2 --text "- Moving to offline projects on Dropbox" --result "DONE" --color GREEN

            # Delete project files
            rm -R "${filepath}/${project_domain}"
            log_event "info" "Project files deleted for ${project_domain}" "false"
            display --indent 2 --text "- Deleting project files on server" --result "DONE" --color GREEN


            # Make a copy of nginx configuration file
            cp -r "/etc/nginx/sites-available/${project_domain}" "${SFOLDER}/tmp-backup"

            # TODO: make a copy of letsencrypt files?

            # TODO: upload to dropbox config_file ??

            # Delete nginx configuration file
            nginx_server_delete "${project_domain}"
            display --indent 2 --text "- Deleting nginx server configuration" --result "DONE" --color GREEN

            # Cloudflare Manager
            project_domain=$(whiptail --title "CLOUDFLARE MANAGER" --inputbox "Do you want to delete the Cloudflare entries for the followings subdomains?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)
            exitstatus=$?
            if [ $exitstatus = 0 ]; then
            
                # Delete Cloudflare entries
                cloudflare_delete_a_record "${project_domain}"

            else

                log_event "info" "Cloudflare entries not deleted. Skipped by user." "false"

            fi

            telegram_send_message "⚠️ ${VPSNAME}: Project files deleted for: ${project_domain}"

            # TODO: Maybe return database name? extracted from wp-config or something?
        
        else

            return 1

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

        # Log
        log_subsection "Delete Database"
        display --indent 2 --text "- Initializing database deletion" --result "DONE" --color GREEN

        BK_TYPE="database"

        # Remove DB prefix to get project_name
        suffix="$(cut -d'_' -f2 <<<"${CHOSEN_DB}")"
        project_name=${CHOSEN_DB%"_$suffix"}
        user_db="${project_name}_user"

        # Make a database Backup
        make_database_backup "${BK_TYPE}" "${CHOSEN_DB}"

        # Moving deleted project backups to another dropbox directory
        log_event "info" "Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${CHOSEN_DB} /${VPSNAME}/offline-site" "false"
        dropbox_output=$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${CHOSEN_DB}" "/${VPSNAME}/offline-site" 1>&2)
        display --indent 2 --text "- Moving dropbox backup to offline directory" --result "DONE" --color GREEN

        # Delete project database
        mysql_database_drop "${CHOSEN_DB}"

        # Delete mysql user
        while true; do

            echo -e "${YELLOW} > Do you want to remove database user? Maybe is used by another project.${ENDCOLOR}"
            read -p "Please type 'y' or 'n'" yn

            case $yn in
                [Yy]* )
                
                mysql_user_delete "${user_db}"
                break;;
                
                [Nn]* )

                log_event "warning" "Aborting MySQL user deletion ..." "false"
                break;;

                * ) echo " > Please answer yes or no.";;
            esac

        done

    else
        # Return
        echo "error"

    fi

}

delete_project() {

    # Delete Files
    delete_project_files

    # Delete Database
    delete_project_database "${delete_files_result}"
 
    #TODO: ask for deleting tmp-backup folder
    # Delete tmp backups
    #rm -R ${SFOLDER}/tmp-backup

}

################################################################################

delete_project
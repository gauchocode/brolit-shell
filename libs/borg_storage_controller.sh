#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
################################################################################
#
# Storage Controller: Controller to upload and download backups.
#
################################################################################

################################################################################
#
# Important: Backup/Restore utils selection with borg.
#
#   Backup Uploader:
#       Simple way to upload backup file to this cloud service.
#
################################################################################

################################################
# umount storage box
#
# Arguments:
#   ${1} = {directory}
#
# Outputs:
#   None
################################################


function umount_storage_box() {

  local directory="${1}"

  is_mounted=$(mount -v | grep "storage-box" > /dev/null; echo "$?")

  if [[ ${is_mounted} -eq 0 ]]; then
        log_subsection "Desmontando storage-box"
        umount ${directory}
  fi

}

#################################################
# mount storage box
#
# Arguments:
#   ${1} = {directory}
#
# Outputs:
#   None
################################################

function mount_storage_box() {

  local number_of_servers=$(jq ".BACKUPS.methods[].borg[].config | length" /root/.brolit_conf.json)

  local whip_title       # whiptail var
  local whip_description # whiptail var
  local runner_options   # whiptail array options
  local chosen_type      # whiptail var

  ## Select storage box to work with

  whip_title="SELECT STORAGE-BOX TO WORK WITH"
  whip_description=" "
  local runner_options=()

  # Dynamically build the runner_options array options
  for ((i=1; i<=number_of_servers; i++)); do
    index=$(printf "%02d)" "$i")        # Format "01)", "02)", ...
    label="STORAGE-BOX $i"                   # Associated text
    runner_options+=("$index" "$label") # Add to array
  done

  # Display the array with whiptail (e.g., using radiolist)
  chosen_type=$(whiptail --title "$whip_title" \
                       --radiolist "$whip_description" 20 78 10 \
                       "${runner_options[@]}" \
                       3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
      echo "You chose: $chosen_type"
  else
      echo "You canceled the selection."
  fi

  local directory="${1}"

  is_mounted=$(mount -v | grep "storage-box" > /dev/null; echo "$?")

  if [[ ${is_mounted} -eq 1 ]]; then
      log_subsection "Montando storage-box"
      sshfs -o default_permissions -p ${BACKUP_BORG_PORT} ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:/home/applications ${directory}
  fi

}


#################################################
# restore backup with borg
#
# Arguments:
#   ${1} = {server_hostname}
#
# Outputs:
#   Return 0 if ok, 1 on error. 
################################################

function restore_backup_with_borg() {
    
    local storage_box_directory="/mnt/storage-box"

    # Create storage box directory if not exists where it will be mounted
    [[ ! -d ${storage_box_directory} ]] && mkdir ${storage_box_directory}

    log_section "Restore Backup"

    # umount storage box
    umount_storage_box ${storage_box_directory} && sleep 1

    # mount storage box
    mount_storage_box ${storage_box_directory} && sleep 1

    local storage_box_directory=${storage_box_directory}
    local remote_server_list=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)

    # Menu
    local chosen_server=$(whiptail --title "BACKUP SELECTION" --menu "Choose a server to work with" 20 78 10 $(for x in ${remote_server_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)

    if [[ ${chosen_server} != ""  ]]; then
        log_subsection "Restore Project Backup"
        restore_project_with_borg "${chosen_server}"
    else
        display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW
        return 1
    fi

    umount_storage_box ${storage_box_directory}

}

function generate_tar_and_decompress() {
    
    local chosen_archive="${1}"
    local project_domain="${2}"
    local project_install_type="${3}"
    local project_backup_file=${chosen_archive}.tar.bz2
    local destination_dir="${PROJECTS_PATH}/${project_domain}"
    local repo_path="ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${chosen_domain}"
    
    # Backup integrity verification
    display --indent 6 --text "- Verifying backup integrity: ${chosen_archive}"
    spinner_start "Verifying backup"
    
    if ! borg check --info "${repo_path}::{chosen_archive}"; then
        spinner_stop 1
        log_event "error" "Corrupted backup: ${chosen_archive}" "true"
        display --indent 6 --text "- Backup verification" --result "FAIL" --color RED
        
        # Detailed error handling with existing notifications
        case $? in
            1)
                error_msg="Warning: The backup has minor issues but might be restorable."
                send_notification "${SERVER_NAME}" "Warning in backup ${chosen_archive}: minor issues detected" "warning"
                ;;
            2)
                error_msg="Critical error: The backup is corrupted and cannot be restored."
                send_notification "${SERVER_NAME}" "CRITICAL ERROR: Backup ${chosen_archive} corrupted during restoration" "alert"
                ;;
            3)
                error_msg="Connection error: Could not access the remote repository."
                send_notification "${SERVER_NAME}" "Connection error to repository for backup ${chosen_archive}" "alert"
                ;;
            *)
                error_msg="Unknown error during backup verification."
                send_notification "${SERVER_NAME}" "Unknown error in backup verification ${chosen_archive}" "alert"
                ;;
        esac
        
        whiptail_message "VERIFICATION FAILED" "${error_msg}\n\nDo you want to try another backup?"
        
        # Ofrecer opciones al usuario
        if whiptail --title "OPCIONES" --yesno "¿Desea intentar con otro backup?" 10 60; then
            return 1  # Permitir al usuario seleccionar otro backup
        else
            return 1
        fi
    else
        spinner_stop 0
        display --indent 6 --text "- Verificación del backup" --result "OK" --color GREEN
        # Notificación de éxito
        send_notification "${SERVER_NAME}" "Backup ${chosen_archive} verificado correctamente" "info"
    fi
    
    # Exportar el backup verificado
    # borg export-tar --tar-filter='auto' --progress ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${chosen_domain}::${chosen_archive} ${BROLIT_MAIN_DIR}/tmp/${project_backup_file}
    borg export-tar --tar-filter='auto' --progress "${repo_path}::{chosen_archive}" ${BROLIT_MAIN_DIR}/tmp/${project_backup_file}

    exitstatus=$?

    if [[ exitstatus -eq 0 ]]; then
        display --indent 6 --text "- Exporting compressed file from storage box" --result "DONE" --color GREEN
        log_event "info" "${project_backup_file} downloaded" "false"
    else
        display --indent 6 --text "- Exporting compressed file from storage box" --result "FAIL" --color RED
        log_event "error" "Error trying to export ${project_backup_file}!" "false"
        exit 1
    fi

    #log_event "info" "Extracting compressed file: ${project_backup_file}" "false"
    #display --indent 6 --text "- Extracting compressed file"

    if [ -f "${BROLIT_MAIN_DIR}/tmp/${project_backup_file}" ]; then

        # If project directory exists, make a backup of it
        if [[ -d "${destination_dir}" ]]; then

            whiptail --title "Warning" --yesno "The project directory already exist. Do you want to continue? A backup of current directory will be stored on BROLIT tmp folder." 10 60 3>&1 1>&2 2>&3

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

            # If project_install_type == docker, stop and remove containers
            if [[ ${project_install_type} == "docker"* ]]; then

                # Stop containers
                docker_compose_stop "${destination_dir}/docker-compose.yml"

                # Remove containers
                docker_compose_rm "${destination_dir}/docker-compose.yml"

            fi

            # Backup old project
            _create_tmp_copy "${destination_dir}" "move"
            [[ $? -eq 1 ]] && return 1

            else

            # Log
            log_event "info" "The project directory already exist. User skipped operation." "false"
            display --indent 6 --text "- Restore files" --result "SKIPPED" --color YELLOW

            return 1

            fi

        fi

        # Extract project
        pv --width 70 "${BROLIT_MAIN_DIR}/tmp/${project_backup_file}" | tar xpj -C / var/www

        # if extracted ok then
        if [[ $? -eq 0 ]]; then

            clear_previous_lines "2"

            log_event "info" "${file_path} extracted ok!" "false"
            display --indent 6 --text "- Extracting compressed file" --result "DONE" --color GREEN

            return 0

        else

            clear_previous_lines "2"

            log_event "error" "Error extracting ${file_path}" "false"
            display --indent 6 --text "- Extracting compressed file" --result "FAIL" --color RED

            return 1

        fi       

        sleep 1

        rm -rf ${BROLIT_MAIN_DIR}/tmp/${project_backup_file}
        [[ $? -eq 0 ]] && echo "Eliminando archivos temporales"
    else

        echo "Error al exportar el archivo ${project_backup_file}"
        exit 1

    fi

}


#################################################
# restore project with borg
#
# Arguments:
#   ${1} = {server_hostname}
#
# Outputs:
#   None
################################################

function restore_project_with_borg() {

    local server_hostname="${1}"
    local storage_box_directory="/mnt/storage-box"
    local repo_path="ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site"

    # Create storage-box directory if not exists
    remote_domain_list=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort | uniq)

    project_status=$(storage_remote_status_list)

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to choose project status" "false"
        exit 1
    fi

    log_event "info" "Selected project status: ${project_status}" "false"

    restore_type=$(storage_remote_type_list)

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to choose restore type" "false"
        exit 1
    fi

    log_event "info" "Selected restore type: ${restore_type}" "false"

    chosen_domain="$(whiptail --title "BACKUP SELECTION" --menu "Choose a domain to work with" 20 78 10 $(for x in ${remote_domain_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

    # Repository integrity verification
    display --indent 6 --text "- Verifying repository integrity"
    spinner_start "Verifying repository"
    
    if ! borg check --info "${repo_path}/${chosen_domain}"; then
        spinner_stop 1
        log_event "error" "Corrupted repository for ${chosen_domain}" "true"
        display --indent 6 --text "- Repository verification" --result "FAIL" --color RED
        
        # Specific Borg error handling with existing notifications
        case $? in
            1)
                error_msg="Warning: The repository has minor issues but might be restorable."
                send_notification "${SERVER_NAME}" "Warning in repository ${chosen_domain}: minor issues detected" "warning"
                ;;
            2)
                error_msg="Critical error: The repository is corrupted and cannot be restored."
                send_notification "${SERVER_NAME}" "CRITICAL ERROR: Repository ${chosen_domain} corrupted during restoration" "alert"
                ;;
            *)
                error_msg="Unknown error during repository verification."
                send_notification "${SERVER_NAME}" "Unknown error in repository verification ${chosen_domain}" "alert"
                ;;
        esac
        
        whiptail_message "VERIFICATION FAILED" "${error_msg}\n\nDo you want to try another backup or server?"
        return 1
    else
        spinner_stop 0
        display --indent 6 --text "- Verificación del repositorio" --result "OK" --color GREEN
        # Notificación de éxito opcional
        send_notification "${SERVER_NAME}" "Repositorio ${chosen_domain} verificado correctamente" "info"
    fi

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to choose project status" "false"
        exit 1
    fi

    log_event "info" "Selected project status: ${project_status}" "false"

    restore_type=$(storage_remote_type_list)

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to choose restore type" "false"
        exit 1
    fi

    log_event "info" "Selected restore type: ${restore_type}" "false"

    chosen_domain="$(whiptail --title "BACKUP SELECTION" --menu "Choose a domain to work with" 20 78 10 $(for x in ${remote_domain_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

    local project_name="$(project_get_name_from_domain "${chosen_domain}")"

    if [[ ${restore_type} == "project" ]]; then
        local destination_dir="${PROJECTS_PATH}/${chosen_domain}/"
    elif [[ ${restore_type} == "database" ]]; then
        local destination_dir="${PROJECTS_PATH}/${chosen_domain}/"
        mkdir -p "${destination_dir}"
    fi

    if [[ ${chosen_domain} != "" ]]; then

        if [[ ${restore_type} == "project" ]]; then

            arhives="$(borg list --format '{archive}{NL}' ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${chosen_domain} | sort -r)"

            chosen_archive="$(whiptail --title "BACKUP SELECTION" --menu "Choose an archive to work with" 20 78 10 $(for x in ${arhives}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

            if [[ ${chosen_archive} != "" ]]; then
                display --indent 6 --text "- Selecting Project Backup" --result "DONE" --color GREEN
                display --indent 8 --text "${chosen_archive}.tar.bz2" --tcolor YELLOW
                generate_tar_and_decompress "${chosen_archive}" "${chosen_domain}" "${project_install_type}"

                local sql_file=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" -maxdepth 1 -type f -name '*.sql' -print -quit)

                if [[ -z ${sql_file} ]]; then
                    log_event "error" "SQL file not found at remote path: ${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" "false"
                    display --indent 6 --text "- SQL file not found at remote path" --result "FAIL" --color RED
                    exit 1
                else

                    echo "SQL file path: ${sql_file}"

                    cp "${sql_file}" "${destination_dir}/$(basename ${sql_file})"

                    if [[ $? -eq 0 ]]; then
                        log_event "info" "SQL file restored successfully to ${local_project_path}" "false"
                        display --indent 6 --text "- SQL file restored" --result "DONE" --color GREEN
                    else
                        log_event "error" "Error restoring SQL file from remote server" "false"
                        display --indent 6 --text "- SQL file restore" --result "FAIL" --color RED
                    fi

                fi

            else
                display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW
                return 1
            fi

        elif [[ ${restore_type} == "database" ]]; then

            local sql_file=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" -maxdepth 1 -type f -name '*.sql' -print -quit)

            if [[ -z ${sql_file} ]]; then
                log_event "error" "SQL file not found at remote path: ${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" "false"
                display --indent 6 --text "- SQL file not found at remote path" --result "FAIL" --color RED
                exit 1
            else
                echo "SQL file path: ${sql_file}"
                mkdir -p "${destination_dir}"
                cp "${sql_file}" "${destination_dir}/$(basename ${sql_file})"

                if [[ $? -eq 0 ]]; then
                    log_event "info" "SQL file restored successfully to ${destination_dir}" "false"
                    display --indent 6 --text "- SQL file restored" --result "DONE" --color GREEN
                else
                    log_event "error" "Error restoring SQL file from remote server" "false"
                    display --indent 6 --text "- SQL file restore" --result "FAIL" --color RED
                fi

            fi
        fi

        # If project_install_type == docker, build containers
        if [[ ${project_install_type} == "docker"* ]]; then
            log_subsection "Restore Files Backup"
            docker_setup_configuration "${project_name}" "${destination_dir}" "${chosen_domain}"
            docker_compose_build "${destination_dir}/docker-compose.yml"


            # Project domain configuration (webserver+certbot+DNS)
            https_enable="$(project_update_domain_config "${project_domain_new}" "${project_type}" "${project_install_type}" "${project_port}")"

            # TODO: if and old project with same domain was found, ask what to do (delete old project or skip this step)

            # Post-restore/install tasks
            project_post_install_tasks "${project_install_path}" "${project_type}" "${project_install_type}" "${project_name}" "${project_stage}" "${db_pass}" "${project_domain}" "${project_domain_new}"

            # Create/update brolit_project_conf.json file with project info
            project_update_brolit_config "${project_install_path}" "${project_name}" "${project_stage}" "${project_type}" "${project_db_status}" "${db_engine}" "${project_name}_${project_stage}" "localhost" "${db_user}" "${db_pass}" "${project_domain_new}" "" "" "" ""
        #fi                
        else
            display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW
            return 1
        fi

    fi 

}

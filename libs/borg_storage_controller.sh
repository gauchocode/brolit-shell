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
      echo "Desmontando storage-box"
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

  local directory="${1}"

  is_mounted=$(mount -v | grep "storage-box" > /dev/null; echo "$?")

  if [[ ${is_mounted} -eq 1 ]]; then
      echo "Montando storage-box"
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
#   None
################################################

function restore_backup_with_borg() {

    umount_storage_box "/mnt/storage-box" && sleep 1

    mount_storage_box "/mnt/storage-box" && sleep 1

    local storage_box_directory="/mnt/storage-box"
    local remote_server_list=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
    
    # Menu
    local chosen_server=$(whiptail --title "BACKUP SELECTION" --menu "Choose a server to work with" 20 78 10 $(for x in ${remote_server_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)

    restore_project_with_borg "${chosen_server}"

    umount_storage_box "/mnt/storage-box"

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

    # Create storage-box directory if not exists
    [[ ! -d ${storage_box_directory} ]] && mkdir ${storage_box_directory}

    remote_domain_list=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}" -maxdepth 3 -mindepth 3 -type d -exec basename {} \; | sort)

    chosen_domain="$(whiptail --title "BACKUP SELECTION" --menu "Choose a domain to work with" 20 78 10 $(for x in ${remote_domain_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

    if [ ${chosen_domain} != "" ]; then

      arhives="$(borg list --format '{archive}{NL}' ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${chosen_domain} | sort -r)"

      chosen_archive="$(whiptail --title "BACKUP SELECTION" --menu "Choose an archive to work with" 20 78 10 $(for x in ${arhives}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

      [[ ${chosen_archive} == "" ]] && return 1

      project_backup_file=${chosen_archive}.tar.bz2

      borg export-tar --tar-filter='auto' --progress ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${chosen_domain}::${chosen_archive} ${BROLIT_MAIN_DIR}/tmp/${project_backup_file}

      if [ $? -ne 0 ]; then
        echo "Error al exportar el archivo ${project_backup_file}"
        exit 1
      else
        echo "Archivo ${project_backup_file} descargado satisfactoriamente"

        tar --force-local -C / -xvf "${BROLIT_MAIN_DIR}/tmp/${project_backup_file}" var/www

        [[ $? -eq 1 ]] && exit 1 

        echo "Archivo ${project_backup_file} descomprimido satisfactoriamente"

        sleep 1

        rm -rf ${BROLIT_MAIN_DIR}/tmp/${project_backup_file}
        [[ $? -eq 0 ]] && echo "Eliminando archivos temporales"

      fi

    fi 

}
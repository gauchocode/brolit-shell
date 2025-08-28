#!/usr/bin/env bash
#
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
#############################################################################

function test_borg_helper_funtions() {

    borg_list_directory_on_server "brolit-dev"

    #echo "BORG USER: ${BACKUP_BORG_USER}"
    #echo "BORG SERVER ${BACKUP_BORG_SERVER}"
    #echo "BORG PASS: ${BACKUP_BORG_PORT}"
}

function umount_storage_box() {

  local directory="${1}"

  is_mounted=$(mount -v | grep "storage-box" > /dev/null; echo "$?")

  if [[ ${is_mounted} -eq 0 ]]; then
      echo "Desmontando storage-box"
      umount ${directory}
  fi

}

function mount_storage_box() {


  return 0

}


function borg_list_directory_on_server() {

    local server_hostname="${1}"
    local storage_box_directory="/mnt/storage-box"


    # Create storage-box directory if not exists
    [[ ! -d ${storage_box_directory} ]] && mkdir ${storage_box_directory}

    umount_storage_box ${storage_box_directory}

    sleep 1

    mount_storage_box ${storage_box_directory}

    sleep 1

    remote_server_list=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}" -maxdepth 3 -mindepth 3 -type d -exec basename {} \; | sort)
    #echo "El hostname directory: ${hostname_directory}"

    chosen_domain="$(whiptail --title "BACKUP SELECTION" --menu "Choose a domain to work with" 20 78 10 $(for x in ${remote_server_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

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

    umount_storage_box ${storage_box_directory}
}


##############################################################################
# Directory browser on Storage Box
#
# Arguments:
#   ${1} = ${menutitle}
#   ${2} = ${server_hostname}
#   none
#
# Outputs:
#   none
##############################################################################

function directory_browser_storage_box() {

  local menutitle="${1}"
  local server_hostname="${2}"

  local startdir="$(find /mnt/storage-box/ -maxdepth 2 -mindepth 2 -type d -name "${server_hostname}")/projects-online/site"
  #local projects=$(find "${hostname_directory}" -maxdepth 3 -mindepth 3 -type d | awk -F/ '{print $NF}')

  echo "El stardir ${startdir}"

  local dir_list

  if [ -z "${startdir}" ]; then
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "${startdir}"
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "${curdir}" == "/" ]; then # Check if you are at root folder
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select ${dir_list} 3>&1 1>&2 2>&3)
  else # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n${curdir}" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select ../ BACK ${dir_list} 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then # Check if User Selected Cancel
    return 1
  elif [ $RET -eq 0 ]; then
    if [[ -d "${selection}" ]]; then # Check if Directory Selected
      whiptail --title "Confirm Selection" --yesno "${selection}" --yes-button "Confirm" --no-button "Retry" 10 60 3>&1 1>&2 2>&3
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # Return 1
        filename="${selection}"
        # Return 2
        filepath="${curdir}" # Return full filepath and filename as selection variables

      else
        return 1

      fi

    fi

  fi

}

#############################################################################
# Check if borg is installed.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
#############################################################################

function borg_check_if_installed() {
    local borg_installed
    local borg

    borg="$(command -v borg)"
    if [[ ! -x "${borg}" ]]; then
        borg_installed="false"
    else
        borg_installed="true"
    fi

    log_event "info" "borg_installed=${borg_installed}" "true"

    # Return
    echo "${borg_installed}"
}


#############################################################################
# Borg installer.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
#############################################################################

function borg_installer() {
    log_subsection "Borg Installer"

    display --indent 6 --text "- Updating repositories"

    # Update repositories
    package_update

    clear_previous_lines "1"
    display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

    # Installing borg
    display --indent 6 --text "- Installing borg and dependencies"

    package_install  "borgbackup"

    exitstatus=$?

    if [[ ${exitstatus} -ne 0 ]]; then

        # Log
        clear_previous_lines "2"
        display --indent 6 --text "- Installing borg and dependencies" --result "FAILED" --color RED
        log_event "error" "Installing borg and dependencies" "false"

        return 1
    else
        # Log
        clear_previous_lines "2"
        display --indent 6 --text "- Installing borg and dependencies" --result "DONE" --color GREEN
        log_event "info" "Installing borg and dependencies" "false"

        return 0
    fi

}

##############################################################################
# Uninstall Borg.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was uninstalled, 1 on error.
##############################################################################

function borg_purge() {
    log_subsection "Borg Uninstaller"

    package_purge "borgbackup"

    return $?
}

##############################################################################
# Borg installer menu.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
##############################################################################

function borg_installer_menu() {
    local borg_is_installed

    borg_is_installed=$(borg_check_if_installed)

    if [[ ${borg_is_installed} == "false" ]]; then

        borg_installer_title="BORG INSTALLER"
        borg_installer_message="Choose an option to run:"
        borg_installer_options=(
            "01)" "INSTALL BORG"
        )

        chosen_certbot_installer_options="$(whiptail --title "${borg_installer_title}" --menu "${borg_installer_message}" 20 78 10 "${borg_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_borg_installer_options} == *"01"* ]]; then

                borg_installer
            fi

        fi
    
    else
        borg_installer_title="BORG INSTALLER"
        borg_installer_message="Choose an option to run:"
        borg_installer_options=(
            "01)" "UNINSTALL BORG"
        )

        chosen_certbot_installer_options="$(whiptail --title "${borg_installer_title}" --menu "${borg_installer_message}" 20 78 10 "${borg_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_borg_installer_options} == *"01"* ]]; then

                borg_purge
            
            fi

        fi

    fi
}

##############################################################################
# Borg backup database.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
##############################################################################

function test_borg_backup_database() {

  local directorio="/var/www/"
  local nombre_carpeta="gauchocode.com"

  source /root/brolit-shell/libs/commons.sh
    
  # Verifica si existe el archivo .env
  if [[ -f "${directorio}/${nombre_carpeta}/.env" ]]; then
      # Exporta las variables del archivo .env
      export $(grep -v '^#' "${directorio}/${nombre_carpeta}/.env" | xargs)
      mysql_database="${MYSQL_DATABASE}"
      container_name="${PROJECT_NAME}_mysql"
      mysql_user="${MYSQL_USER}"
      mysql_password="${MYSQL_PASSWORD}"
  else
      echo "Error: .env file not found in ${directorio}/${nombre_carpeta}/."
      return 1
  fi

  # Generar timestamp para el archivo SQL dump
  now=$(date +"%Y-%m-%dT%H:%M:%S")

  # Realizar el dump
  dump_file="/var/www/${nombre_carpeta}/${mysql_database}_database_${now}.sql"
  echo "Generando dump de la base de datos en $dump_file..."
  docker exec "$container_name" sh -c "mysqldump -u$mysql_user -p$mysql_password $mysql_database > /tmp/database_dump.sql"
  docker cp "$container_name:/tmp/database_dump.sql" "$dump_file"

  # Verifica si el dump fue generado correctamente
  if [ -f "$dump_file" ]; then
      echo "Dump generado con éxito en $dump_file."

      # Comprimir el archivo SQL dump
      compressed_dump_file="/var/www/${nombre_carpeta}/${mysql_database}_database_${now}.tar.gz"
      echo "Comprimiendo el dump..."
      compress "/var/www/${nombre_carpeta}" "${mysql_database}_database_${now}.sql" "$compressed_dump_file"
      
      if [ $? -eq 0 ]; then
          echo "Dump comprimido exitosamente en $compressed_dump_file."
          
          # Subir el archivo dump comprimido al servidor de backups
          echo "Subiendo dump comprimido a servidor de backups..."
          scp -P "${BACKUP_BORG_PORT}" "$compressed_dump_file" "${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:/home/applications/${BACKUP_BORG_GROUP}/${HOSTNAME}/projects-online/database/${nombre_carpeta}"

          # Verifica si la transferencia fue exitosa
          if [ $? -eq 0 ]; then
              echo "Dump comprimido subido exitosamente."
              
              # Eliminar el archivo dump comprimido localmente
              echo "Eliminando dump comprimido local: $compressed_dump_file"
              rm "$compressed_dump_file"
              if [ $? -eq 0 ]; then
                  echo "Dump comprimido eliminado localmente con éxito."
              else
                  echo "Error al eliminar el archivo dump comprimido local."
              fi
          else
              echo "Error subiendo el dump comprimido al servidor de backups."
          fi
      else
          echo "Error al comprimir el dump."
      fi
  else
      echo "Error: no se pudo generar el dump de la base de datos."
  fi
}
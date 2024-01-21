#!/bin/bash

# Por cada direcorio existenten en /www/var generar un archivo .yml

BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)

[[ -z "${BROLIT_MAIN_DIR}" ]] && exit 1 # error; the path is not accessible

directorio="/var/www"

if [ ! -d "$directorio" ]; then
	echo "El directorio '$directorio' no existe"
	exit 1
fi

source "${BROLIT_MAIN_DIR}/brolit_lite.sh"
source "${BROLIT_MAIN_DIR}/libs/local/project_helper.sh"
source "${BROLIT_MAIN_DIR}/libs/commons.sh"
source "${BROLIT_MAIN_DIR}/utils/brolit_configuration_manager.sh"

function _brolit_configuration_load_backup_borg() {
    local server_config_file="${1}"

    #Globals
    declare -g BACKUP_BORG_USER
    declare -g BACKUP_BORG_SERVER
    declare -g BACKUP_BORG_PORT
    declare -g BACKUP_BORG_GROUP

    BACKUP_BORG_STATUS="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].status")"

    if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then

        BACKUP_BORG_USER="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[].user")"
        [[ -z "${BACKUP_BORG_USER}" ]] && die "Error reading BACKUP_BORG_USER from server config file."

        BACKUP_BORG_SERVER="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[].server")"
        [[ -z "${BACKUP_BORG_SERVER}" ]] && die "Error reading BACKUP_BORG_SERVER from server config file."

        BACKUP_BORG_PORT="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[].port")"
        [[ -z "${BACKUP_BORG_PORT}" ]] && die "Error reading BACKUP_BORG_PORT from server config file."

        BACKUP_BORG_GROUP="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[].group")"
        [[ -z "${BACKUP_BORG_GROUP}" ]] && die "Error reading BACKUP_BORG_GROUP from server config file."

    fi 

    export BACKUP_BORG_STATUS BACKUP_BORG_USER BACKUP_BORG_SERVER BACKUP_BORG_PORT BACKUP_BORG_GROUP
}


function _brolit_configuration_load_ntfy() {

    local server_config_file="${1}"

    # Globals
    declare -g NOTIFICATION_NTFY_STATUS
    declare -g NOTIFICATION_NTFY_USERNAME
    declare -g NOTIFICATION_NTFY_PASSWORD
    declare -g NOTIFICATION_NTFY_SERVER
    declare -g NOTIFICATION_NTFY_TOPIC
    
    NOTIFICATION_NTFY_STATUS="$(_json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].status")"

    if [[ ${NOTIFICATION_NTFY_STATUS} == "enabled" ]]; then

        # Required
        NOTIFICATION_NTFY_USERNAME="$(_json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].username")"
        [[ -z ${NOTIFICATION_NTFY_USERNAME} ]] && die "Error reading NOTIFICATION_NTFY_USERNAME from server config file."

        NOTIFICATION_NTFY_PASSWORD="$(_json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].password")"
        [[ -z ${NOTIFICATION_NTFY_PASSWORD} ]] && die "Error reading NOTIFICATION_NTFY_PASSWORD from server config file."

        NOTIFICATION_NTFY_SERVER="$(_json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].server")"
        [[ -z ${NOTIFICATION_NTFY_SERVER} ]] && die "Error reading NOTIFICATION_NTFY_SERVER from server config file."
    fi

    export NOTIFICATION_NTFY_STATUS NOTIFICATION_NTFY_USERNAME NOTIFICATION_NTFY_PASSWORD NOTIFICATION_NTFY_SERVER NOTIFICATION_NTFY_TOPIC

}

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh

# Iteramos las carpetas sobre el directorio

_brolit_configuration_load_backup_borg "/root/.brolit_conf.json"
_brolit_configuration_load_ntfy "/root/.brolit_conf.json"

if [ "${BACKUP_BORG_STATUS}" == "enabled" ]; then

	for carpeta in "$directorio"/*; do
		if [ -d "$carpeta" ]; then
			nombre_carpeta=$(basename "$carpeta")
			archivo_yml="$nombre_carpeta.yml"
			project_install_type="$(_project_get_install_type "/var/www/${nombre_carpeta}")"

            #if [ ${project_install_type} == "default" ]; then
            #    echo "Install type ${project_install_type}"
            #    project_type="$(project_get_type "/var/www/${project_domain}")"
            #    db_name="$(project_get_configured_database "${PROJECTS_PATH}/${nombre_carpeta}" "wordpress" "${project_install_type}")"

            #    echo "----------------- Project type: ${project_type} ------- "
            #    echo "----------------- DB NAME: ${db_name} ----------------- "
            #fi

			if [ $nombre_carpeta == "html" ]; then
				continue
			fi

            if [ ! -f "/etc/borgmatic.d/$archivo_yml" ]; then

                if [ ${project_install_type} == "default" ]; then
                    echo "---- Projecto no dockerizado escribir el nombre de la base de datos manualmente!! ----"
                    cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-default.yml" "/etc/borgmatic.d/$archivo_yml"
                else
                    cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template.yml" "/etc/borgmatic.d/$archivo_yml"
                fi

                PROJECT=$nombre_carpeta yq -i '.constants.project = strenv(PROJECT)' "/etc/borgmatic.d/$archivo_yml"
                GROUP=$BACKUP_BORG_GROUP yq -i '.constants.group = strenv(GROUP)' "/etc/borgmatic.d/$archivo_yml"
                HOST=$HOSTNAME yq -i '.constants.hostname = strenv(HOST)' "/etc/borgmatic.d/$archivo_yml"
                USER=$BACKUP_BORG_USER yq -i '.constants.username = strenv(USER)' "/etc/borgmatic.d/$archivo_yml"
                SERVER=$BACKUP_BORG_SERVER yq -i '.constants.server = strenv(SERVER)' "/etc/borgmatic.d/$archivo_yml"
                PORT=$BACKUP_BORG_PORT yq -i '.constants.port = strenv(PORT)' "/etc/borgmatic.d/$archivo_yml"
                NTFY_USER=$NOTIFICATION_NTFY_USERNAME yq -i '.constants.ntfy_username = strenv(NTFY_USER)' "/etc/borgmatic.d/$archivo_yml"
                NTFY_PASS=$NOTIFICATION_NTFY_PASSWORD yq -i '.constants.ntfy_password = strenv(NTFY_PASS)' "/etc/borgmatic.d/$archivo_yml"
                NTFY_SERVER=$NOTIFICATION_NTFY_SERVER yq -i '.constants.ntfy_server = strenv(NTFY_SERVER)' "/etc/borgmatic.d/$archivo_yml"
                #NTFY_TOPIC=$NOTIFICATION_NTFY_TOPIC yq -i '.constants.ntfy_topic = strenv(NTFY_TOPIC)' "/etc/borgmatic.d/$archivo_yml"
                echo "Archivo $archivo_yml generado."
                echo "Esperando 3 segundos..."
                sleep 3
            else
                echo "El archivo $archivo_yml ya existe."	
                sleep 1
            fi	
                echo "Inicializando repo"
                ssh -p ${BACKUP_BORG_PORT} ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER} "mkdir -p /home/applications/'$BACKUP_BORG_GROUP'/'$HOSTNAME'/projects-online/site/'$nombre_carpeta'"
                sleep 1
                borgmatic init --encryption=none --config "/etc/borgmatic.d/$archivo_yml"
		fi
	done
else
	echo "Borg no esta habilitado"
fi
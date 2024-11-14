#!/bin/bash

# For every directory in /www/var generates a yml file

BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)

[[ -z "${BROLIT_MAIN_DIR}" ]] && exit 1 # error; the path is not accessible

directorio="/var/www"

mkdir -p /etc/borgmatic.d

if [ ! -d "$directorio" ]; then
	echo "The directory '$directorio' doesn't exists"
	exit 1
fi

source "${BROLIT_MAIN_DIR}/brolit_lite.sh"
source "${BROLIT_MAIN_DIR}/libs/local/project_helper.sh"
source "${BROLIT_MAIN_DIR}/libs/commons.sh"
source "${BROLIT_MAIN_DIR}/utils/brolit_configuration_manager.sh"

BACKUP_BORG_USERS=()
BACKUP_BORG_SERVERS=()
BACKUP_BORG_PORTS=()

function _brolit_configuration_load_backup_borg() {
    local server_config_file="${1}"
    local number_of_servers=$(jq ".BACKUPS.methods[].borg[].config | length" /root/.brolit_conf.json)

    #Globals
    declare -g BACKUP_BORG_GROUP

    BACKUP_BORG_STATUS="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].status")"

    if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then

        for i in $(eval echo {1..$number_of_servers})
        do
            BACKUP_BORG_USERS[$i]="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[$(($i-1))].user")"
            [[ -z "${BACKUP_BORG_USERS[i]}" ]] && die "Error reading BACKUP_BORG_USER from server config file."

            BACKUP_BORG_SERVERS[$i]="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[$(($i-1))].server")"
            [[ -z "${BACKUP_BORG_SERVERS[i]}" ]] && die "Error reading BACKUP_BORG_SERVER from server config file."

            BACKUP_BORG_PORTS[$i]="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[$(($i-1))].port")"
            [[ -z "${BACKUP_BORG_PORTS[i]}" ]] && die "Error reading BACKUP_BORG_PORT from server config file."

        done

        BACKUP_BORG_GROUP="$(_json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].group")"
        [[ -z "${BACKUP_BORG_GROUP}" ]] && die "Error reading BACKUP_BORG_GROUP from server config file."

    fi 

    export BACKUP_BORG_STATUS BACKUP_BORG_GROUP BACKUP_BORG_USERS BACKUP_BORG_SERVERS BACKUP_BORG_PORTS
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

        NOTIFICATION_NTFY_TOPIC="$(_json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].topic")"
        [[ -z ${NOTIFICATION_NTFY_TOPIC} ]] && die "Error reading NOTIFICATION_NTFY_TOPIC from server config file."
    fi

    export NOTIFICATION_NTFY_STATUS NOTIFICATION_NTFY_USERNAME NOTIFICATION_NTFY_PASSWORD NOTIFICATION_NTFY_SERVER NOTIFICATION_NTFY_TOPIC

}

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh

# Iteramos las carpetas sobre el directorio



function generate_config() {

    _brolit_configuration_load_backup_borg "/root/.brolit_conf.json"
    _brolit_configuration_load_ntfy "/root/.brolit_conf.json"

    if [ "${BACKUP_BORG_STATUS}" == "enabled" ]; then
        local number_of_servers=$(jq ".BACKUPS.methods[].borg[].config | length" /root/.brolit_conf.json)
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

                echo "------------------------ Project name: ${nombre_carpeta} ------------------------ "

                if [ ! -f "/etc/borgmatic.d/$archivo_yml" ]; then

                    # Crea el archivo de configuracion
                    echo "El archivo $archivo_yml no existe"
                    echo "Generando"
                    sleep 2

                    if [ ${project_install_type} == "default" ]; then
                        echo "---- Project it's not dockerized, write the database name manually!! ----"
                        cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-default.yml" "/etc/borgmatic.d/$archivo_yml"
                    else
                        cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template.yml" "/etc/borgmatic.d/$archivo_yml"
                    fi

                    PROJECT=$nombre_carpeta yq -i '.constants.project = strenv(PROJECT)' "/etc/borgmatic.d/$archivo_yml"
                    GROUP=$BACKUP_BORG_GROUP yq -i '.constants.group = strenv(GROUP)' "/etc/borgmatic.d/$archivo_yml"
                    HOST=$HOSTNAME yq -i '.constants.hostname = strenv(HOST)' "/etc/borgmatic.d/$archivo_yml"

                    for i in $(seq $number_of_servers -1 1)
                    do
                        sed -i '/^constants:/a\  port_'"$i"': '"${BACKUP_BORG_PORTS[i]}"' ' /etc/borgmatic.d/$archivo_yml
                        sed -i '/^constants:/a\  server_'"$i"': '"${BACKUP_BORG_SERVERS[i]}"' ' /etc/borgmatic.d/$archivo_yml
                        sed -i '/^constants:/a\  user_'"$i"': '"${BACKUP_BORG_USERS[i]}"' ' /etc/borgmatic.d/$archivo_yml

                        ## Generamos la ssh url
                        sed -i '/^repositories:/a\  - path: ssh:\/\/{user_'"$i"'}@{server_'"$i"'}:{port_'"$i"'}\/.\/applications\/{group}\/{hostname}\/projects-online\/site\/{project}\n    label: "storage-{user_'"$i"'}"' /etc/borgmatic.d/$archivo_yml 
                    done

                    NTFY_USER=$NOTIFICATION_NTFY_USERNAME yq -i '.constants.ntfy_username = strenv(NTFY_USER)' "/etc/borgmatic.d/$archivo_yml"
                    NTFY_PASS=$NOTIFICATION_NTFY_PASSWORD yq -i '.constants.ntfy_password = strenv(NTFY_PASS)' "/etc/borgmatic.d/$archivo_yml"
                    NTFY_SERVER=$NOTIFICATION_NTFY_SERVER yq -i '.constants.ntfy_server = strenv(NTFY_SERVER)' "/etc/borgmatic.d/$archivo_yml"
                    NTFY_TOPIC=$NOTIFICATION_NTFY_TOPIC yq -i '.constants.ntfy_topic = strenv(NTFY_TOPIC)' "/etc/borgmatic.d/$archivo_yml"

                    echo "File $archivo_yml generated."
                    echo "Please wait 3 seconds..."
                    sleep 3
                else
                    echo "The file $archivo_yml exists."	
                    sleep 1
                    # Read the .env file

                fi	
                    
                echo "Initializing repo"
                for i in $(eval echo {1..$number_of_servers})
                do
                    echo "Creating remote directory"
                    ssh -p ${BACKUP_BORG_PORTS[i]} ${BACKUP_BORG_USERS[i]}@${BACKUP_BORG_SERVERS[i]} "mkdir -p /home/applications/'$BACKUP_BORG_GROUP'/'$HOSTNAME'/projects-online/site/'$nombre_carpeta'"
                    ssh -p ${BACKUP_BORG_PORTS[i]} ${BACKUP_BORG_USERS[i]}@${BACKUP_BORG_SERVERS[i]} "mkdir -p /home/applications/'$BACKUP_BORG_GROUP'/'$HOSTNAME'/projects-online/database/'$nombre_carpeta'"
                    sleep 1
                done
                sleep 1
                borgmatic init --encryption=none --config "/etc/borgmatic.d/$archivo_yml"

                #if [[ -f "${directorio}/${nombre_carpeta}/.env" ]]; then

                #    export $(grep -v '^#' "${directorio}/${nombre_carpeta}/.env" | xargs)

                #    mysql_database="${MYSQL_DATABASE}"
                #    container_name="${PROJECT_NAME}_mysql"
                #    mysql_user="${MYSQL_USER}"
                #    mysql_password="${MYSQL_PASSWORD}"

                #else
                #    echo "Error: .env file not found in ${directorio}/${nombre_carpeta}/."
                #    return 1

                #fi

                ## Generate timestamp for the SQL dump file
                #now=$(date +"%Y-%m-%d")
                #    
                ## dump
                #dump_file="/var/www/${nombre_carpeta}/${mysql_database}_database_${now}.sql"
                #echo "Generating database $dump_file..."
                #docker exec "$container_name" sh -c "mysqldump -u$mysql_user -p$mysql_password $mysql_database > /tmp/database_dump.sql"
                #docker cp "$container_name:/tmp/database_dump.sql" "$dump_file"

                #if [ -f "$dump_file" ]; then
                #     echo "Importing database from $dump_file..."
                #    docker exec -i "$container_name" mysql -u"$mysql_user" -p"$mysql_password" "$mysql_database" < "$dump_file"
                #    if [ $? -eq 0 ]; then
                #        echo "Database import completed successfully."
                #    else
                #        echo "Error during database import."
                #    fi
                #fi

                #for i in $(eval echo {1..$number_of_servers})
                #do
                #    scp -P ${BACKUP_BORG_PORTS[i]} "$dump_file" ${BACKUP_BORG_USERS[i]}@${BACKUP_BORG_SERVERS[i]}:/home/applications/"$BACKUP_BORG_GROUP"/"$HOSTNAME"/projects-online/database/"$nombre_carpeta"
                #done 


                #if [ $? -eq 0 ]; then
                #    echo "Dump uploaded successfully."
                #    if [ -f "$dump_file" ]; then
                #        echo "Deleting dump file: $dump_file"
                #        rm "$dump_file"
                #        if [ $? -eq 0 ]; then
                #            echo "Dump file deleted successfully."
                #        else
                #            echo "Error deleting dump file."
                #        fi
                #    else
                #        echo "Error: Dump file does not exist."
                #    fi
                #else
                #    echo "Error uploading dump to remote server."
                #fi
            else
                echo "Error: Dump file not generated."
            fi
    	done
    else
    	echo "Borg is not enabled"
    fi
}

generate_config
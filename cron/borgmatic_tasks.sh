#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.12
################################################################################

# Generates a yml file for every directory in /var/www

# Get the main directory path
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)

# Exit if BROLIT_MAIN_DIR is not accessible
[[ -z "${BROLIT_MAIN_DIR}" ]] && exit 1

# Source required libraries
source "${BROLIT_MAIN_DIR}/libs/commons.sh"
source "${BROLIT_MAIN_DIR}/libs/notification_controller.sh"
source "${BROLIT_MAIN_DIR}/libs/local/log_and_display_helper.sh"

# Script initialization
script_init "true"

# Define constants
readonly BORG_DIR="/etc/borgmatic.d"
readonly WWW_DIR="/var/www"
readonly HTML_EXCLUDE="html"

# Check required commands are available
for cmd in borgmatic borg jq yq ssh; do
    if ! command -v "$cmd" &> /dev/null; then
        log_event "critical" "Required command '$cmd' not found" "true"
        send_notification "${SERVER_NAME}" "Required command '$cmd' not found in borgmatic_tasks.sh" "alert"
        exit 1
    fi
done

# Validate WWW directory exists
if [ ! -d "${WWW_DIR}" ]; then
    log_event "critical" "Directory '${WWW_DIR}' does not exist" "true"
    send_notification "${SERVER_NAME}" "Directory '${WWW_DIR}' does not exist in borgmatic_tasks.sh" "alert"
    exit 1
fi

# The sources are already included above

# Arrays to store backup configuration
BACKUP_BORG_USERS=()
BACKUP_BORG_SERVERS=()
BACKUP_BORG_PORTS=()

function _brolit_configuration_load_backup_borg() {
    local server_config_file="${1}"
    
    # Declare global variables
    declare -g BACKUP_BORG_STATUS
    declare -g BACKUP_BORG_GROUP
    declare -g -a BACKUP_BORG_USERS
    declare -g -a BACKUP_BORG_SERVERS
    declare -g -a BACKUP_BORG_PORTS
    
    # Reset arrays
    BACKUP_BORG_USERS=()
    BACKUP_BORG_SERVERS=()
    BACKUP_BORG_PORTS=()
    
    # Read backup status
    BACKUP_BORG_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].status")"
    
    if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then
        local number_of_servers
        number_of_servers=$(jq ".BACKUPS.methods[].borg[].config | length" /root/.brolit_conf.json)
        
        for i in $(seq 1 "$number_of_servers"); do
            local user server port
            
            user="$(json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[$((i-1))].user")"
            [[ -z "${user}" ]] && die "Error reading BACKUP_BORG_USER from server config file."
            BACKUP_BORG_USERS+=("${user}")
            
            server="$(json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[$((i-1))].server")"
            [[ -z "${server}" ]] && die "Error reading BACKUP_BORG_SERVER from server config file."
            BACKUP_BORG_SERVERS+=("${server}")
            
            port="$(json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].config[$((i-1))].port")"
            [[ -z "${port}" ]] && die "Error reading BACKUP_BORG_PORT from server config file."
            BACKUP_BORG_PORTS+=("${port}")
        done
        
        BACKUP_BORG_GROUP="$(json_read_field "${server_config_file}" "BACKUPS.methods[].borg[].group")"
        [[ -z "${BACKUP_BORG_GROUP}" ]] && die "Error reading BACKUP_BORG_GROUP from server config file."
    fi 
    
    export BACKUP_BORG_STATUS BACKUP_BORG_GROUP BACKUP_BORG_USERS BACKUP_BORG_SERVERS BACKUP_BORG_PORTS
}


function _brolit_configuration_load_ntfy() {
    local server_config_file="${1}"
    
    # Declare global variables
    declare -g NOTIFICATION_NTFY_STATUS
    declare -g NOTIFICATION_NTFY_USERNAME
    declare -g NOTIFICATION_NTFY_PASSWORD
    declare -g NOTIFICATION_NTFY_SERVER
    declare -g NOTIFICATION_NTFY_TOPIC
    
    # Reset variables
    NOTIFICATION_NTFY_STATUS=""
    NOTIFICATION_NTFY_USERNAME=""
    NOTIFICATION_NTFY_PASSWORD=""
    NOTIFICATION_NTFY_SERVER=""
    NOTIFICATION_NTFY_TOPIC=""
    
    # Read notification status
    NOTIFICATION_NTFY_STATUS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].status")"
    
    if [[ ${NOTIFICATION_NTFY_STATUS} == "enabled" ]]; then
        # Required fields
        NOTIFICATION_NTFY_USERNAME="$(json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].username")"
        [[ -z ${NOTIFICATION_NTFY_USERNAME} ]] && die "Error reading NOTIFICATION_NTFY_USERNAME from server config file."
        
        NOTIFICATION_NTFY_PASSWORD="$(json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].password")"
        [[ -z ${NOTIFICATION_NTFY_PASSWORD} ]] && die "Error reading NOTIFICATION_NTFY_PASSWORD from server config file."
        
        NOTIFICATION_NTFY_SERVER="$(json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].server")"
        [[ -z ${NOTIFICATION_NTFY_SERVER} ]] && die "Error reading NOTIFICATION_NTFY_SERVER from server config file."
        
        NOTIFICATION_NTFY_TOPIC="$(json_read_field "${server_config_file}" "NOTIFICATIONS.ntfy[].config[].topic")"
        [[ -z ${NOTIFICATION_NTFY_TOPIC} ]] && die "Error reading NOTIFICATION_NTFY_TOPIC from server config file."
    fi
    
    export NOTIFICATION_NTFY_STATUS NOTIFICATION_NTFY_USERNAME NOTIFICATION_NTFY_PASSWORD NOTIFICATION_NTFY_SERVER NOTIFICATION_NTFY_TOPIC
}

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh

# Backup validation and helper functions
function validate_ssh_connection() {
    local user=$1 server=$2 port=$3
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes -p "$port" "$user@$server" "exit"; then
        echo "Error: Cannot connect to $server:$port"
        return 1
    fi
    return 0
}

function create_remote_directories() {
    local user=$1 server=$2 port=$3 group=$4 hostname=$5 project=$6
    ssh -p "$port" "$user@$server" "mkdir -p /home/applications/'$group'/'$hostname'/projects-online/site/'$project'" || return 1
    ssh -p "$port" "$user@$server" "mkdir -p /home/applications/'$group'/'$hostname'/projects-online/database/'$project'" || return 1
    return 0
}

function initialize_repository() {
    local config_file=$1
    if borgmatic --config "$config_file" info &>/dev/null; then
        echo "Repository already exists, skipping initialization"
        return 0
    fi
    
    echo "Initializing new repository"
    if ! borgmatic init --encryption=none --config "$config_file"; then
        echo "Error: Repository initialization failed"
        return 1
    fi
    return 0
}

# Process each folder in the WWW directory
function generate_config() {
    # Load configuration
    _brolit_configuration_load_backup_borg "/root/.brolit_conf.json"
    _brolit_configuration_load_ntfy "/root/.brolit_conf.json"

    # Check if Borg backup is enabled
    if [ "${BACKUP_BORG_STATUS}" == "enabled" ]; then
        local number_of_servers
        number_of_servers=$(jq ".BACKUPS.methods[].borg[].config | length" /root/.brolit_conf.json)
        
        # Process each directory in WWW_DIR
        for folder in "${WWW_DIR}"/*; do
            if [ -d "${folder}" ]; then
                local folder_name
                folder_name=$(basename "${folder}")
                local yml_file="${folder_name}.yml"
                local project_install_type
                project_install_type="$(project_get_install_type "/var/www/${folder_name}")"

                # Skip HTML directory
                if [ "${folder_name}" == "${HTML_EXCLUDE}" ]; then
                    continue
                fi

                log_event "info" "Processing project: ${folder_name}" "false"

                # Check if config file already exists
                if [ ! -f "${BORG_DIR}/${yml_file}" ]; then
                    log_event "info" "Config file ${yml_file} does not exist" "false"
                    log_event "info" "Generating configuration file..." "false"
                    sleep 2

                    if [ "${project_install_type}" == "default" ]; then
                        echo "---- Project it's not dockerized, write the database name manually!! ----"
                        cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-default.yml" "${BORG_DIR}/${yml_file}"
                    else
                        cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template.yml" "${BORG_DIR}/${yml_file}"
                    fi

                    # Update configuration file with project-specific values
                    PROJECT="${folder_name}" yq -i '.constants.project = strenv(PROJECT)' "${BORG_DIR}/${yml_file}"
                    GROUP="${BACKUP_BORG_GROUP}" yq -i '.constants.group = strenv(GROUP)' "${BORG_DIR}/${yml_file}"
                    HOST="${HOSTNAME}" yq -i '.constants.hostname = strenv(HOST)' "${BORG_DIR}/${yml_file}"

                    # Add server configuration for each backup server
                    for i in $(seq 1 "$number_of_servers"); do
                        # Add server configuration to constants
                        sed -i "/^constants:/a\  port_${i}: ${BACKUP_BORG_PORTS[i-1]}" "${BORG_DIR}/${yml_file}"
                        sed -i "/^constants:/a\  server_${i}: ${BACKUP_BORG_SERVERS[i-1]}" "${BORG_DIR}/${yml_file}"
                        sed -i "/^constants:/a\  user_${i}: ${BACKUP_BORG_USERS[i-1]}" "${BORG_DIR}/${yml_file}"
                        
                        # Add repository configuration
                        sed -i "/^repositories:/a\  - path: ssh://{user_${i}}@{server_${i}}:{port_${i}}/.//applications/{group}/{hostname}/projects-online/site/{project}\n    label: \"storage-{user_${i}}\"" "${BORG_DIR}/${yml_file}"
                    done

                    # Add notification configuration
                    NTFY_USER="${NOTIFICATION_NTFY_USERNAME}" yq -i '.constants.ntfy_username = strenv(NTFY_USER)' "${BORG_DIR}/${yml_file}"
                    NTFY_PASS="${NOTIFICATION_NTFY_PASSWORD}" yq -i '.constants.ntfy_password = strenv(NTFY_PASS)' "${BORG_DIR}/${yml_file}"
                    NTFY_SERVER="${NOTIFICATION_NTFY_SERVER}" yq -i '.constants.ntfy_server = strenv(NTFY_SERVER)' "${BORG_DIR}/${yml_file}"
                    NTFY_TOPIC="${NOTIFICATION_NTFY_TOPIC}" yq -i '.constants.ntfy_topic = strenv(NTFY_TOPIC)' "${BORG_DIR}/${yml_file}"

                    log_event "info" "Config file ${yml_file} generated." "false"
                    echo "Please wait 3 seconds..."
                    sleep 3
                else
                    log_event "info" "Config file ${yml_file} already exists." "false"
                    sleep 1
                fi	
                    
                echo "Validating and preparing backup servers"
                local server_reachable=0
                for i in $(seq 1 "$number_of_servers"); do
                    log_event "info" "Validating connection to ${BACKUP_BORG_SERVERS[i-1]}:p${BACKUP_BORG_PORTS[i-1]}" "false"
                    if ! validate_ssh_connection "${BACKUP_BORG_USERS[i-1]}" "${BACKUP_BORG_SERVERS[i-1]}" "${BACKUP_BORG_PORTS[i-1]}"; then
                        log_event "warning" "Skipping server ${BACKUP_BORG_SERVERS[i-1]} due to connection issues" "false"
                        continue
                    fi
                    
                    log_event "info" "Creating remote directories on ${BACKUP_BORG_SERVERS[i-1]}" "false"
                    if ! create_remote_directories "${BACKUP_BORG_USERS[i-1]}" "${BACKUP_BORG_SERVERS[i-1]}" "${BACKUP_BORG_PORTS[i-1]}" "${BACKUP_BORG_GROUP}" "${HOSTNAME}" "${folder_name}"; then
                        log_event "warning" "Failed to create directories on ${BACKUP_BORG_SERVERS[i-1]}" "false"
                        continue
                    fi
                    ((server_reachable++))
                done

                if [ "$server_reachable" -eq 0 ]; then
                    log_event "error" "No reachable backup servers for ${folder_name}" "true"
                    send_notification "${SERVER_NAME}" "No reachable backup servers for ${folder_name}" "alert"
                    continue
                fi

                log_event "info" "Initializing repository for ${folder_name}" "false"
                if ! initialize_repository "${BORG_DIR}/${yml_file}"; then
                    log_event "error" "Failed to initialize repository for ${folder_name}" "true"
                    send_notification "${SERVER_NAME}" "Failed to initialize repository for ${folder_name}" "alert"
                    continue
                fi
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
    	log_event "info" "Borg backup is not enabled" "false"
    fi
}

generate_config

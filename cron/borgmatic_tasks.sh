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
#source "${BROLIT_MAIN_DIR}/libs/notification_controller.sh"
#source "${BROLIT_MAIN_DIR}/libs/local/log_and_display_helper.sh"

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

# Load configurations from central sources
function load_configurations() {
    _brolit_configuration_load_backup_borg "/root/.brolit_conf.json"
    _brolit_configuration_load_ntfy "/root/.brolit_conf.json"
}

# Generate Borg configuration file for a project
function generate_borg_config() {
    local project_name="${1}"
    local yml_file="${BORG_DIR}/${project_name}.yml"
    local project_install_type
    
    project_install_type="$(project_get_install_type "/var/www/${project_name}")"
    
    # Check if config file already exists
    if [ ! -f "${yml_file}" ]; then
        log_event "info" "Config file ${yml_file} does not exist" "false"
        log_event "info" "Generating configuration file..." "false"
        sleep 2

        if [ "${project_install_type}" == "default" ]; then
            echo "---- Project it's not dockerized, write the database name manually!! ----"
            cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-default.yml" "${yml_file}"
        else
            cp "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template.yml" "${yml_file}"
        fi

        # Update configuration file with project-specific values
        PROJECT="${project_name}" yq -i '.constants.project = strenv(PROJECT)' "${yml_file}"
        GROUP="${BACKUP_BORG_GROUP}" yq -i '.constants.group = strenv(GROUP)' "${yml_file}"
        HOST="${HOSTNAME}" yq -i '.constants.hostname = strenv(HOST)' "${yml_file}"

        # Add server configuration for each backup server
        for i in $(seq 1 "$number_of_servers"); do
            # Add server configuration to constants
            sed -i "/^constants:/a\  port_${i}: ${BACKUP_BORG_PORTS[i-1]}" "${yml_file}"
            sed -i "/^constants:/a\  server_${i}: ${BACKUP_BORG_SERVERS[i-1]}" "${yml_file}"
            sed -i "/^constants:/a\  user_${i}: ${BACKUP_BORG_USERS[i-1]}" "${yml_file}"
            
            # Add repository configuration
            sed -i "/^repositories:/a\  - path: ssh://{user_${i}}@{server_${i}}:{port_${i}}/.//applications/{group}/{hostname}/projects-online/site/{project}\n    label: \"storage-{user_${i}}\"" "${yml_file}"
        done

        # Add notification configuration
        NTFY_USER="${NOTIFICATION_NTFY_USERNAME}" yq -i '.constants.ntfy_username = strenv(NTFY_USER)' "${yml_file}"
        NTFY_PASS="${NOTIFICATION_NTFY_PASSWORD}" yq -i '.constants.ntfy_password = strenv(NTFY_PASS)' "${yml_file}"
        NTFY_SERVER="${NOTIFICATION_NTFY_SERVER}" yq -i '.constants.ntfy_server = strenv(NTFY_SERVER)' "${yml_file}"
        NTFY_TOPIC="${NOTIFICATION_NTFY_TOPIC}" yq -i '.constants.ntfy_topic = strenv(NTFY_TOPIC)' "${yml_file}"

        log_event "info" "Config file ${yml_file} generated." "false"
        echo "Please wait 3 seconds..."
        sleep 3
    else
        log_event "info" "Config file ${yml_file} already exists." "false"
        sleep 1
    fi
}

# Estimate backup size
function estimate_backup_size() {
    local project_path="${1}"
    local size_kb
    local size_mb
    
    # Estimar tamaño del proyecto
    size_kb=$(du -sk "${project_path}" | awk '{print $1}')
    size_mb=$((size_kb / 1024))
    
    # Añadir margen del 20% para compresión y metadatos
    size_mb=$(((size_mb * 120) / 100))
    
    log_event "info" "Estimated backup size for $(basename "${project_path}"): ${size_mb}MB" "false"
    
    echo "${size_mb}"
}

# Check remote disk space based on backup size estimation
function check_remote_disk_space() {
    local user="${1}"
    local server="${2}"
    local port="${3}"
    local required_space_mb="${4}"  # tamaño estimado del backup
    local safety_margin="${5:-20}"  # margen de seguridad en porcentaje
    local mount_point="${6:-/}"
    
    # Calcular espacio requerido con margen
    local required_space_with_margin
    required_space_with_margin=$(((required_space_mb * (100 + safety_margin)) / 100))
    
    # Obtener espacio libre en disco remoto
    local free_space_kb
    free_space_kb=$(ssh -p "${port}" "${user}@${server}" "df -k '${mount_point}'" | awk 'NR==2 {print $4}')
    
    # Convertir KB a MB
    local free_space_mb=$((free_space_kb / 1024))
    
    log_event "info" "Espacio libre en ${server}:${mount_point}: ${free_space_mb}MB, Requerido con margen: ${required_space_with_margin}MB" "false"
    
    # Verificar si hay suficiente espacio
    if [[ ${free_space_mb} -lt ${required_space_with_margin} ]]; then
        log_event "error" "Espacio insuficiente en ${server}:${mount_point}. Requiere ${required_space_with_margin}MB, disponible ${free_space_mb}MB" "true"
        return 1
    fi
    
    return 0
}

function setup_project_directories() {
    local project_name="${1}"
    local project_path="${WWW_DIR}/${project_name}"
    local successful_servers=0
    local total_servers=0
    
    # Estimar tamaño del backup
    local estimated_size
    estimated_size=$(estimate_backup_size "${project_path}")
    
    for i in $(seq 1 "$number_of_servers"); do
        local user="${BACKUP_BORG_USERS[i-1]}"
        local server="${BACKUP_BORG_SERVERS[i-1]}"
        local port="${BACKUP_BORG_PORTS[i-1]}"
        
        ((total_servers++))
        
        log_event "info" "Validating connection to ${server}:p${port}" "false"
        if ! validate_ssh_connection "${user}" "${server}" "${port}"; then
            log_event "error" "Failed to connect to backup server ${server}" "true"
            send_notification "${SERVER_NAME}" "Critical: Failed to connect to backup server ${server} for ${project_name}" "alert"
            continue
        fi
        
        log_event "info" "Checking disk space on ${server}" "false"
        if ! check_remote_disk_space "${user}" "${server}" "${port}" "${estimated_size}" "20"; then
            log_event "error" "Insufficient disk space on backup server ${server}" "true"
            send_notification "${SERVER_NAME}" "Critical: Insufficient disk space on backup server ${server} for ${project_name}" "alert"
            continue
        fi
        
        log_event "info" "Creating remote directories on ${server}" "false"
        if ! create_remote_directories "${user}" "${server}" "${port}" "${BACKUP_BORG_GROUP}" "${HOSTNAME}" "${project_name}"; then
            log_event "error" "Failed to create directories on backup server ${server}" "true"
            send_notification "${SERVER_NAME}" "Critical: Failed to create directories on backup server ${server} for ${project_name}" "alert"
            continue
        fi
        
        ((successful_servers++))
    done
    
    # Si no todos los servidores fueron exitosos, es un error crítico
    if [[ ${successful_servers} -lt ${total_servers} ]]; then
        log_event "error" "Not all backup servers were successfully configured for ${project_name}. Success: ${successful_servers}/${total_servers}" "true"
        send_notification "${SERVER_NAME}" "Critical: Incomplete backup server configuration for ${project_name}. Success: ${successful_servers}/${total_servers}" "alert"
        return 1
    fi
    
    log_event "info" "All backup servers successfully configured for ${project_name}" "false"
    return 0
}

# Initialize repository if needed
function initialize_repository_if_needed() {
    local config_file="${1}"
    local project_name="${2}"
    
    log_event "info" "Initializing repository for ${project_name}" "false"
    if ! initialize_repository "${config_file}"; then
        log_event "error" "Failed to initialize repository for ${project_name}" "true"
        send_notification "${SERVER_NAME}" "Critical: Failed to initialize repository for ${project_name}" "alert"
        return 1
    fi
    
    return 0
}

# Process each folder in the WWW directory
function generate_config() {
    # Load configuration
    load_configurations

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

                # Skip HTML directory
                if [ "${folder_name}" == "${HTML_EXCLUDE}" ]; then
                    continue
                fi

                log_event "info" "Processing project: ${folder_name}" "false"

                # Generate Borg configuration
                generate_borg_config "${folder_name}"
                
                # Setup project directories
                if setup_project_directories "${folder_name}"; then
                    # Initialize repository if needed
                    initialize_repository_if_needed "${BORG_DIR}/${yml_file}" "${folder_name}"
                fi
            fi
    	done
    else
    	log_event "info" "Borg backup is not enabled" "false"
    fi
}

generate_config

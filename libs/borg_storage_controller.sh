#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
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

        log_subsection "Umounting storage-box"
        umount "${directory}"

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
  
  # Check if Borg is enabled
  if [[ "${BACKUP_BORG_STATUS}" != "enabled" ]]; then
    log_event "error" "Borg backup is not enabled" "false"
    display --indent 6 --text "- Borg backup not enabled" --result "FAIL" --color RED
    return 1
  fi

  # Get number of servers from the global arrays
  local number_of_servers=${#BACKUP_BORG_USERS[@]}
  
  # Validate number_of_servers is a positive integer
  if [ "${number_of_servers}" -lt 1 ]; then
    log_event "error" "No Borg servers configured or invalid configuration" "false"
    display --indent 6 --text "- No Borg servers configured" --result "FAIL" --color RED
    return 1
  fi

  local whip_title="SELECT STORAGE-BOX TO WORK WITH"
  local whip_description="Choose a storage box to work with:"
  local runner_options=()
  local chosen_index
  local chosen_type

  # Dynamically build the runner_options array options
  for ((i=0; i<number_of_servers; i++)); do
    local server_user="${BACKUP_BORG_USERS[$i]}"
    local server_server="${BACKUP_BORG_SERVERS[$i]}"
    local server_port="${BACKUP_BORG_PORTS[$i]}"

    # Skip if any required parameter is empty
    if [[ -z "${server_user}" || -z "${server_server}" || -z "${server_port}" ]]; then
      continue
    fi

    index=$(printf "%02d)" $((i+1)))  # Format "01)", "02)", ...
    label="STORAGE-BOX $((i+1)) (${server_user}@${server_server}:${server_port})"  # Associated text with server details

    # Set first item as selected, others as not selected
    # whiptail radiolist requires: tag name status [on|off]
    if [[ ${#runner_options[@]} -eq 0 ]]; then
      runner_options+=("$index" "$label" "ON")  # First item: selected by default
    else
      runner_options+=("$index" "$label" "OFF")  # Other items: not selected
    fi
  done

  # Check if we have any valid servers
  if [[ ${#runner_options[@]} -eq 0 ]]; then
    log_event "error" "No valid Borg servers configured" "false"
    display --indent 6 --text "- No valid Borg servers configured" --result "FAIL" --color RED
    return 1
  fi

  # Display the array with whiptail (e.g., using radiolist)
  chosen_type=$(whiptail --title "$whip_title" \
                       --radiolist "$whip_description" 20 78 10 \
                       "${runner_options[@]}" \
                       3>&1 1>&2 2>&3)
  exitstatus=$?
  
  # Log the raw selection for debugging
  log_event "debug" "Raw storage box selection: '${chosen_type}'" "false"
  
  # Clean the chosen_type to extract only the index number
  if [ $exitstatus = 0 ] && [[ -n "${chosen_type}" ]]; then
    # Extract the index number from the chosen type (e.g., "01)" -> "1")
    chosen_index=$(echo "${chosen_type}" | grep -o '^[0-9]*')
    
    # Log the extracted index for debugging
    log_event "debug" "Extracted storage box index: '${chosen_index}'" "false"
    
    # Validate chosen_index
    if [[ -n "${chosen_index}" ]] && [[ "${chosen_index}" =~ ^[0-9]+$ ]] && [ "${chosen_index}" -ge 1 ] && [ "${chosen_index}" -le "${number_of_servers}" ]; then
      # Set the global variables for the selected server (adjusting for 0-based array indexing)
      local array_index=$((chosen_index - 1))
      BACKUP_BORG_USER="${BACKUP_BORG_USERS[$array_index]}"
      BACKUP_BORG_SERVER="${BACKUP_BORG_SERVERS[$array_index]}"
      BACKUP_BORG_PORT="${BACKUP_BORG_PORTS[$array_index]}"
      
      log_event "info" "Selected storage box ${chosen_index}: ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}" "false"
      display --indent 6 --text "- Storage box selection" --result "DONE" --color GREEN
    else
      log_event "error" "Invalid storage box selection: ${chosen_type}" "false"
      log_event "error" "Expected numeric index between 1 and ${number_of_servers}, got: '${chosen_index}'" "false"
      display --indent 6 --text "- Invalid storage box selection" --result "FAIL" --color RED
      display --indent 8 --text "Invalid selection: ${chosen_type}" --tcolor RED
      display --indent 8 --text "Please try again and select a valid storage box" --tcolor YELLOW
      return 1
    fi
  else
    log_event "info" "Storage box selection canceled by user" "false"
    display --indent 6 --text "- Storage box selection canceled" --result "SKIPPED" --color YELLOW
    return 1
  fi

  # Check server connectivity before attempting to mount
  log_event "info" "Checking connectivity to selected server: ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}" "false"
  display --indent 6 --text "- Checking server connectivity" --result "RUNNING" --color YELLOW
  
  # Create temporary arrays with only the selected server for connectivity check
  local temp_users=("${BACKUP_BORG_USER}")
  local temp_servers=("${BACKUP_BORG_SERVER}")
  local temp_ports=("${BACKUP_BORG_PORT}")
  
  # Temporarily override global arrays for single server check
  local original_users=("${BACKUP_BORG_USERS[@]}")
  local original_servers=("${BACKUP_BORG_SERVERS[@]}")
  local original_ports=("${BACKUP_BORG_PORTS[@]}")
  
  BACKUP_BORG_USERS=("${temp_users[@]}")
  BACKUP_BORG_SERVERS=("${temp_servers[@]}")
  BACKUP_BORG_PORTS=("${temp_ports[@]}")
  
  # Run connectivity check
  if ! check_borg_server_connectivity; then
      # Restore original arrays
      BACKUP_BORG_USERS=("${original_users[@]}")
      BACKUP_BORG_SERVERS=("${original_servers[@]}")
      BACKUP_BORG_PORTS=("${original_ports[@]}")
      
      log_event "error" "Server connectivity check failed, aborting mount operation" "false"
      display --indent 6 --text "- Server connectivity check" --result "FAIL" --color RED
      
      # Ask user if they want to continue anyway
      if whiptail --title "CONNECTIVITY WARNING" --yesno "Server connectivity check failed. Do you want to continue with the mount operation anyway? This may fail." 10 60; then
          log_event "info" "User chose to continue despite connectivity issues" "false"
          display --indent 6 --text "- User override" --result "CONTINUE" --color YELLOW
      else
          log_event "info" "User canceled mount due to connectivity issues" "false"
          display --indent 6 --text "- Mount operation" --result "CANCELED" --color YELLOW
          return 1
      fi
  else
      # Restore original arrays
      BACKUP_BORG_USERS=("${original_users[@]}")
      BACKUP_BORG_SERVERS=("${original_servers[@]}")
      BACKUP_BORG_PORTS=("${original_ports[@]}")
      
      log_event "info" "Server connectivity check passed" "false"
      display --indent 6 --text "- Server connectivity check" --result "OK" --color GREEN
  fi

  is_mounted=$(mount -v | grep "storage-box" > /dev/null; echo "$?")

  if [[ ${is_mounted} -eq 1 ]]; then
    log_subsection "Mounting storage-box"
    log_event "info" "Mounting storage box: sshfs -o default_permissions -p ${BACKUP_BORG_PORT} ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:/home/applications ${directory}" "false"
    
    # Test SSH connection first
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -p "${BACKUP_BORG_PORT}" "${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}" "exit" 2>/dev/null; then
      sshfs -o default_permissions -p "${BACKUP_BORG_PORT}" "${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}":/home/applications "${directory}"
      if [[ $? -eq 0 ]]; then
        log_event "info" "Storage box mounted successfully" "false"
        display --indent 6 --text "- Mount storage box" --result "DONE" --color GREEN
      else
        log_event "error" "Failed to mount storage box" "false"
        display --indent 6 --text "- Mount storage box" --result "FAIL" --color RED
        return 1
      fi
    else
      log_event "error" "Cannot connect to storage box via SSH: ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}" "false"
      display --indent 6 --text "- SSH connection failed" --result "FAIL" --color RED
      return 1
    fi
  else
    log_event "info" "Storage box already mounted" "false"
    display --indent 6 --text "- Storage box already mounted" --result "SKIPPED" --color YELLOW
  fi

}


#################################################
# check borg server connectivity
#
# Arguments:
#   None
#
# Outputs:
#   Return 0 if all servers are reachable, 1 if any server fails
################################################

function check_borg_server_connectivity() {
    
    log_subsection "Borg Server Connectivity Check"
    
    # Check if Borg is enabled
    if [[ "${BACKUP_BORG_STATUS}" != "enabled" ]]; then
        log_event "info" "Borg backup is not enabled, skipping connectivity check" "false"
        display --indent 6 --text "- Borg backup not enabled" --result "SKIPPED" --color YELLOW
        return 0
    fi

    # Get number of servers from the global arrays
    local number_of_servers=${#BACKUP_BORG_USERS[@]}
    
    # Validate number_of_servers is a positive integer
    if [ "${number_of_servers}" -lt 1 ]; then
        log_event "error" "No Borg servers configured or invalid configuration" "false"
        display --indent 6 --text "- No Borg servers configured" --result "FAIL" --color RED
        return 1
    fi
    
    local failed_servers=0
    local total_servers=${number_of_servers}
    
    log_event "info" "Checking connectivity for ${total_servers} Borg server(s)" "false"
    display --indent 6 --text "- Checking ${total_servers} server(s)" --result "RUNNING" --color YELLOW
    
    # Check each configured server
    for ((i=0; i<number_of_servers; i++)); do
        local server_user="${BACKUP_BORG_USERS[$i]}"
        local server_server="${BACKUP_BORG_SERVERS[$i]}"
        local server_port="${BACKUP_BORG_PORTS[$i]}"
        
        # Skip if any required parameter is empty
        if [[ -z "${server_user}" || -z "${server_server}" || -z "${server_port}" ]]; then
            log_event "warning" "Skipping incomplete server configuration at index ${i}" "false"
            display --indent 8 --text "Server ${i}: Incomplete configuration" --tcolor YELLOW
            ((failed_servers++))
            continue
        fi
        
        log_event "info" "Testing connectivity to ${server_user}@${server_server}:${server_port}" "false"
        display --indent 8 --text "Testing ${server_user}@${server_server}:${server_port}"
        
        # Test DNS resolution first
        if ! nslookup "${server_server}" >/dev/null 2>&1; then
            # Log detailed error message
            log_event "error" "❌ Borg Server Connectivity Issue - Server: ${server_user}@${server_server}:${server_port} - Issue: DNS resolution failed" "false"
            log_event "error" "🔍 Possible causes: Incorrect server hostname, DNS server issues, Network connectivity problems" "false"
            log_event "error" "🛠️  Solutions: Verify server hostname in .brolit_conf.json, Check network connectivity, Test with: nslookup ${server_server}" "false"
            
            # Display error message
            display --indent 6 --text "- Borg Server Connectivity Issue" --result "FAIL" --color RED
            display --indent 8 --text "Server: ${server_user}@${server_server}:${server_port}" --tcolor RED
            display --indent 8 --text "Issue: DNS resolution failed" --tcolor YELLOW
            display --indent 8 --text "🔍 Possible causes:" --tcolor WHITE
            display --indent 10 --text "• Incorrect server hostname" --tcolor YELLOW
            display --indent 10 --text "• DNS server issues" --tcolor YELLOW
            display --indent 10 --text "• Network connectivity problems" --tcolor YELLOW
            display --indent 8 --text "🛠️  Solutions:" --tcolor WHITE
            display --indent 10 --text "• Verify server hostname in .brolit_conf.json" --tcolor GREEN
            display --indent 10 --text "• Check network connectivity" --tcolor GREEN
            display --indent 10 --text "• Test with: nslookup ${server_server}" --tcolor GREEN
            
            # Send notification with possible causes
            local error_msg="❌ Borg Server Connectivity Issue\n\n"
            error_msg+="Server: ${server_user}@${server_server}:${server_port}\n"
            error_msg+="Issue: DNS resolution failed\n\n"
            error_msg+="🔍 Possible causes:\n"
            error_msg+="• Incorrect server hostname\n"
            error_msg+="• DNS server issues\n"
            error_msg+="• Network connectivity problems\n\n"
            error_msg+="🛠️  Solutions:\n"
            error_msg+="• Verify server hostname in .brolit_conf.json\n"
            error_msg+="• Check network connectivity\n"
            error_msg+="• Test with: nslookup ${server_server}"
            
            send_notification "${SERVER_NAME}" "${error_msg}" "alert"
            ((failed_servers++))
            continue
        fi
        
        # Test port connectivity
        if ! timeout 8 bash -c "echo >/dev/tcp/${server_server}/${server_port}" 2>/dev/null; then
            # Log detailed error message
            log_event "error" "❌ Borg Server Connectivity Issue - Server: ${server_user}@${server_server}:${server_port} - Issue: Port ${server_port} is not reachable" "false"
            log_event "error" "🔍 Possible causes: Firewall blocking the port, Server not listening on port ${server_port}, Network ACL restrictions" "false"
            log_event "error" "🛠️  Solutions: Verify port ${server_port} is open on the server, Check firewall rules, Test with: telnet ${server_server} ${server_port}" "false"
            
            # Display error message
            display --indent 6 --text "- Borg Server Connectivity Issue" --result "FAIL" --color RED
            display --indent 8 --text "Server: ${server_user}@${server_server}:${server_port}" --tcolor RED
            display --indent 8 --text "Issue: Port ${server_port} is not reachable" --tcolor YELLOW
            display --indent 8 --text "🔍 Possible causes:" --tcolor WHITE
            display --indent 10 --text "• Firewall blocking the port" --tcolor YELLOW
            display --indent 10 --text "• Server not listening on port ${server_port}" --tcolor YELLOW
            display --indent 10 --text "• Network ACL restrictions" --tcolor YELLOW
            display --indent 8 --text "🛠️  Solutions:" --tcolor WHITE
            display --indent 10 --text "• Verify port ${server_port} is open on the server" --tcolor GREEN
            display --indent 10 --text "• Check firewall rules" --tcolor GREEN
            display --indent 10 --text "• Test with: telnet ${server_server} ${server_port}" --tcolor GREEN
            
            # Send notification with possible causes
            local error_msg="❌ Borg Server Connectivity Issue\n\n"
            error_msg+="Server: ${server_user}@${server_server}:${server_port}\n"
            error_msg+="Issue: Port ${server_port} is not reachable\n\n"
            error_msg+="🔍 Possible causes:\n"
            error_msg+="• Firewall blocking the port\n"
            error_msg+="• Server not listening on port ${server_port}\n"
            error_msg+="• Network ACL restrictions\n\n"
            error_msg+="🛠️  Solutions:\n"
            error_msg+="• Verify port ${server_port} is open on the server\n"
            error_msg+="• Check firewall rules\n"
            error_msg+="• Test with: telnet ${server_server} ${server_port}"
            
            send_notification "${SERVER_NAME}" "${error_msg}" "alert"
            ((failed_servers++))
            continue
        fi
        
        # Test SSH connection with detailed error handling
        local ssh_result
        ssh_result=$(ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -p "${server_port}" "${server_user}@${server_server}" "exit" 2>&1)
        local ssh_exit_code=$?
        
        if [ ${ssh_exit_code} -eq 0 ]; then
            log_event "info" "Successfully connected to ${server_user}@${server_server}:${server_port}" "false"
            display --indent 8 --text "SSH connection: OK" --tcolor GREEN
        else
            # Analyze SSH error for detailed logging and display
            local error_title="SSH connection failed"
            local error_causes=()
            local error_solutions=()
            
            if [[ "${ssh_result}" == *"Permission denied"* ]]; then
                error_title="SSH Permission denied"
                error_causes=(
                    "• Incorrect username or password"
                    "• SSH key authentication issues"
                    "• Account disabled on server"
                )
                error_solutions=(
                    "• Verify username and credentials"
                    "• Check SSH key configuration"
                    "• Test manual SSH connection"
                )
            elif [[ "${ssh_result}" == *"Connection refused"* ]]; then
                error_title="SSH Connection refused"
                error_causes=(
                    "• SSH service not running on server"
                    "• Server is down"
                    "• Port forwarding issues"
                )
                error_solutions=(
                    "• Check if SSH service is running on server"
                    "• Verify server status"
                    "• Test with: ssh -p ${server_port} ${server_user}@${server_server}"
                )
            elif [[ "${ssh_result}" == *"No route to host"* ]] || [[ "${ssh_result}" == *"Network is unreachable"* ]]; then
                error_title="Network connectivity issues"
                error_causes=(
                    "• Network connectivity issues"
                    "• Server is unreachable"
                    "• Routing problems"
                )
                error_solutions=(
                    "• Check network connectivity"
                    "• Verify server IP address"
                    "• Test with: ping ${server_server}"
                )
            elif [[ "${ssh_result}" == *"Host key verification failed"* ]]; then
                error_title="Host key verification failed"
                error_causes=(
                    "• Host key changed or mismatch"
                    "• Known hosts file corruption"
                )
                error_solutions=(
                    "• Remove entry from ~/.ssh/known_hosts"
                    "• Use ssh-keygen -R ${server_server}"
                )
            else
                error_title="SSH connection failed"
                error_causes=(
                    "• Generic SSH connection issues"
                    "• Server configuration problems"
                    "• Authentication failures"
                )
                error_solutions=(
                    "• Check server SSH configuration"
                    "• Verify authentication method"
                    "• Review server logs for details"
                )
            fi
            
            # Log detailed error message
            local causes_log=""
            local solutions_log=""
            for cause in "${error_causes[@]}"; do
                causes_log+="${cause}; "
            done
            for solution in "${error_solutions[@]}"; do
                solutions_log+="${solution}; "
            done
            
            log_event "error" "❌ Borg Server Connectivity Issue - Server: ${server_user}@${server_server}:${server_port} - Issue: ${error_title}" "false"
            log_event "error" "🔍 Possible causes: ${causes_log}" "false"
            log_event "error" "🛠️  Solutions: ${solutions_log}" "false"
            log_event "error" "📝 SSH error details: ${ssh_result}" "false"
            
            # Display error message with proper formatting
            display --indent 6 --text "- Borg Server Connectivity Issue" --result "FAIL" --color RED
            display --indent 8 --text "Server: ${server_user}@${server_server}:${server_port}" --tcolor RED
            display --indent 8 --text "Issue: ${error_title}" --tcolor YELLOW
            display --indent 8 --text "🔍 Possible causes:" --tcolor WHITE
            
            # Display causes with proper indentation
            for cause in "${error_causes[@]}"; do
                display --indent 10 --text "${cause}" --tcolor YELLOW
            done
            
            display --indent 8 --text "🛠️  Solutions:" --tcolor WHITE
            
            # Display solutions with proper indentation
            for solution in "${error_solutions[@]}"; do
                display --indent 10 --text "${solution}" --tcolor GREEN
            done
            
            display --indent 8 --text "📝 Error details:" --tcolor WHITE
            display --indent 10 --text "${ssh_result}" --tcolor GRAY
            
            # Send notification with possible causes
            local error_msg="❌ Borg Server Connectivity Issue\n\n"
            error_msg+="Server: ${server_user}@${server_server}:${server_port}\n"
            error_msg+="Issue: ${error_title}\n\n"
            error_msg+="🔍 Possible causes:\n${error_causes}\n\n"
            error_msg+="🛠️  Solutions:\n${error_solutions}\n\n"
            error_msg+="📝 Error details:\n${ssh_result}"
            
            send_notification "${SERVER_NAME}" "${error_msg}" "alert"
            ((failed_servers++))
        fi
    done
    
    # Summary
    if [ ${failed_servers} -eq 0 ]; then
        log_event "info" "All ${total_servers} Borg servers are reachable" "false"
        display --indent 6 --text "- Connectivity check" --result "SUCCESS" --color GREEN
        display --indent 8 --text "${total_servers} server(s) OK" --tcolor GREEN
        return 0
    else
        local success_servers=$((total_servers - failed_servers))
        log_event "warning" "${failed_servers} out of ${total_servers} Borg servers failed connectivity check" "false"
        display --indent 6 --text "- Connectivity check" --result "PARTIAL" --color YELLOW
        display --indent 8 --text "${success_servers}/${total_servers} server(s) OK" --tcolor YELLOW
        display --indent 8 --text "${failed_servers} server(s) FAILED" --tcolor RED
        return 1
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

    log_subsection "Restore Backup"
    
    # Log diagnostic information
    log_event "debug" "Starting restore backup process" "false"
    log_event "debug" "BACKUP_BORG_STATUS: ${BACKUP_BORG_STATUS}" "false"
    log_event "debug" "BACKUP_BORG_GROUP: ${BACKUP_BORG_GROUP}" "false"
    log_event "debug" "Number of configured servers: ${#BACKUP_BORG_USERS[@]}" "false"
    
    # Log server configurations
    for i in "${!BACKUP_BORG_USERS[@]}"; do
        log_event "debug" "Server ${i}: ${BACKUP_BORG_USERS[$i]}@${BACKUP_BORG_SERVERS[$i]}:${BACKUP_BORG_PORTS[$i]}" "false"
    done

    # First, let user choose which Borg server to use for restore
    if [[ ${#BACKUP_BORG_USERS[@]} -gt 1 ]]; then
        log_event "debug" "Multiple servers configured, showing selection menu" "false"
        
        local server_options=()
        for i in "${!BACKUP_BORG_USERS[@]}"; do
            local index=$(printf "%02d)" $((i+1)))
            local label="${BACKUP_BORG_USERS[$i]}@${BACKUP_BORG_SERVERS[$i]}:${BACKUP_BORG_PORTS[$i]}"
            server_options+=("$index" "$label")
        done
        
        local chosen_server_config
        chosen_server_config=$(whiptail --title "BORG SERVER SELECTION" --menu "Choose a Borg server to restore from" 20 78 10 "${server_options[@]}" 3>&1 1>&2 2>&3)
        
        # Log the raw selection for debugging
        log_event "debug" "Raw server selection: '${chosen_server_config}'" "false"
        
        if [[ -z "${chosen_server_config}" ]]; then
            log_event "info" "Server selection canceled by user" "false"
            display --indent 6 --text "- Server selection" --result "CANCELED" --color YELLOW
            return 1
        fi
        
        # Extract the index number and set the global variables
        # Improved extraction to handle formats like "01)" correctly
        local chosen_index
        chosen_index=$(echo "${chosen_server_config}" | grep -o '^[0-9]*')
        
        # Log the extracted index for debugging
        log_event "debug" "Extracted index: '${chosen_index}'" "false"
        
        # Validate the extracted index
        if [[ -n "${chosen_index}" ]] && [[ "${chosen_index}" =~ ^[0-9]+$ ]] && [ "${chosen_index}" -ge 1 ] && [ "${chosen_index}" -le "${#BACKUP_BORG_USERS[@]}" ]; then
            local array_index=$((chosen_index - 1))
            BACKUP_BORG_USER="${BACKUP_BORG_USERS[$array_index]}"
            BACKUP_BORG_SERVER="${BACKUP_BORG_SERVERS[$array_index]}"
            BACKUP_BORG_PORT="${BACKUP_BORG_PORTS[$array_index]}"
            
            log_event "info" "Selected Borg server ${chosen_index}: ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}" "false"
            display --indent 6 --text "- Server selection" --result "DONE" --color GREEN
        else
            # Improved error handling with user-friendly message
            log_event "error" "Invalid server selection: ${chosen_server_config}" "false"
            log_event "error" "Expected numeric index between 1 and ${#BACKUP_BORG_USERS[@]}, got: '${chosen_index}'" "false"
            display --indent 6 --text "- Server selection" --result "FAIL" --color RED
            display --indent 8 --text "Invalid selection: ${chosen_server_config}" --tcolor RED
            display --indent 8 --text "Please try again and select a valid server" --tcolor YELLOW
            return 1
        fi
    else
        # Use the first (and only) configured server
        BACKUP_BORG_USER="${BACKUP_BORG_USERS[0]}"
        BACKUP_BORG_SERVER="${BACKUP_BORG_SERVERS[0]}"
        BACKUP_BORG_PORT="${BACKUP_BORG_PORTS[0]}"
        
        log_event "info" "Using single configured server: ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}" "false"
        display --indent 6 --text "- Server configuration" --result "SINGLE" --color GREEN
    fi

    # Check server connectivity before proceeding
    log_event "info" "Checking connectivity to selected server: ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}" "false"
    display --indent 6 --text "- Checking server connectivity" --result "RUNNING" --color YELLOW
    
    # Create temporary arrays with only the selected server for connectivity check
    local temp_users=("${BACKUP_BORG_USER}")
    local temp_servers=("${BACKUP_BORG_SERVER}")
    local temp_ports=("${BACKUP_BORG_PORT}")
    
    # Temporarily override global arrays for single server check
    local original_users=("${BACKUP_BORG_USERS[@]}")
    local original_servers=("${BACKUP_BORG_SERVERS[@]}")
    local original_ports=("${BACKUP_BORG_PORTS[@]}")
    
    BACKUP_BORG_USERS=("${temp_users[@]}")
    BACKUP_BORG_SERVERS=("${temp_servers[@]}")
    BACKUP_BORG_PORTS=("${temp_ports[@]}")
    
    # Run connectivity check
    if ! check_borg_server_connectivity; then
        # Restore original arrays
        BACKUP_BORG_USERS=("${original_users[@]}")
        BACKUP_BORG_SERVERS=("${original_servers[@]}")
        BACKUP_BORG_PORTS=("${original_ports[@]}")
        
        log_event "error" "Server connectivity check failed, aborting restore operation" "false"
        display --indent 6 --text "- Server connectivity check" --result "FAIL" --color RED
        
        # Ask user if they want to continue anyway
        if whiptail --title "CONNECTIVITY WARNING" --yesno "Server connectivity check failed. Do you want to continue with the restore operation anyway? This may fail." 10 60; then
            log_event "info" "User chose to continue despite connectivity issues" "false"
            display --indent 6 --text "- User override" --result "CONTINUE" --color YELLOW
        else
            log_event "info" "User canceled restore due to connectivity issues" "false"
            display --indent 6 --text "- Restore operation" --result "CANCELED" --color YELLOW
            return 1
        fi
    else
        # Restore original arrays
        BACKUP_BORG_USERS=("${original_users[@]}")
        BACKUP_BORG_SERVERS=("${original_servers[@]}")
        BACKUP_BORG_PORTS=("${original_ports[@]}")
        
        log_event "info" "Server connectivity check passed" "false"
        display --indent 6 --text "- Server connectivity check" --result "OK" --color GREEN
    fi

    # umount storage box first
    umount_storage_box ${storage_box_directory} && sleep 1

    # mount the selected storage box
    if ! mount_storage_box ${storage_box_directory}; then
        log_event "error" "Failed to mount storage box" "false"
        display --indent 6 --text "- Mounting storage box" --result "FAIL" --color RED
        return 1
    fi
    
    sleep 1

    # Log the selected server details
    log_event "debug" "Storage box mounted with server: ${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}" "false"
    
    # Validate that the mount was successful
    if [[ ! -d "${storage_box_directory}/${BACKUP_BORG_GROUP}" ]]; then
        log_event "error" "Storage box mount failed or group directory not found: ${storage_box_directory}/${BACKUP_BORG_GROUP}" "false"
        display --indent 6 --text "- Checking mounted directory" --result "FAIL" --color RED
        umount_storage_box ${storage_box_directory}
        return 1
    fi
    
    log_event "debug" "Storage box mounted successfully at: ${storage_box_directory}" "false"

    # Now list available servers in the mounted directory for final selection
    local remote_server_list
    remote_server_list=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | sort)
    
    log_event "debug" "Available servers in mounted directory: ${remote_server_list}" "false"
    
    if [[ -z "${remote_server_list}" ]]; then
        log_event "error" "No servers found in mounted directory: ${storage_box_directory}/${BACKUP_BORG_GROUP}" "false"
        display --indent 6 --text "- Finding servers" --result "FAIL" --color RED
        display --indent 8 --text "Directory is empty or inaccessible" --tcolor RED
        umount_storage_box ${storage_box_directory}
        return 1
    fi

    # Menu for final server selection (from mounted content)
    local chosen_server
    chosen_server=$(whiptail --title "BACKUP SERVER SELECTION" --menu "Choose a backup server to restore from" 20 78 10 $(for x in ${remote_server_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)
    
    log_event "debug" "User selected backup server: ${chosen_server}" "false"

    if [[ -n "${chosen_server}" ]]; then

        log_subsection "Restore Project Backup (Borg)"
        restore_project_with_borg "${chosen_server}"

    else

        log_event "info" "Backup server selection canceled by user" "false"
        display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW
        umount_storage_box ${storage_box_directory}
        return 1

    fi

    umount_storage_box ${storage_box_directory}
    
    log_event "debug" "Restore backup process completed" "false"

}

function generate_tar_and_decompress() {
    
    local chosen_archive="${1}"
    local project_domain="${2}"
    local project_install_type="${3}"
    local server_hostname="${4}"  # Added missing parameter

    local project_backup_file="${chosen_archive}.tar.bz2"
    local destination_dir="${PROJECTS_PATH}/${project_domain}"
    local repo_path="ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${project_domain}"
    
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
        if whiptail --title "OPTIONS" --yesno "¿Desea intentar con otro backup?" 10 60; then
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
    # borg export-tar --tar-filter='auto' --progress ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${project_domain}::${chosen_archive} ${BROLIT_MAIN_DIR}/tmp/${project_backup_file}
    borg export-tar --tar-filter='auto' --progress "${repo_path}::{chosen_archive}" "${BROLIT_MAIN_DIR}/tmp/${project_backup_file}"

    local exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Exporting compressed file from storage box" --result "DONE" --color GREEN
        log_event "info" "${project_backup_file} downloaded" "false"

    else

        display --indent 6 --text "- Exporting compressed file from storage box" --result "FAIL" --color RED
        log_event "error" "Error trying to export ${project_backup_file}!" "false"
        return 1

    fi

    #log_event "info" "Extracting compressed file: ${project_backup_file}" "false"
    #display --indent 6 --text "- Extracting compressed file"

    if [ -f "${BROLIT_MAIN_DIR}/tmp/${project_backup_file}" ]; then

        # If project directory exists, make a backup of it
        if [[ -d "${destination_dir}" ]]; then

            whiptail --title "Warning" --yesno "The project directory already exist. Do you want to continue? A backup of current directory will be stored on BROLIT tmp folder." 10 60 3>&1 1>&2 2>&3

            local exitstatus=$?
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

            log_event "info" "${project_backup_file} extracted ok!" "false"
            display --indent 6 --text "- Extracting compressed file" --result "DONE" --color GREEN

            return 0

        else

            clear_previous_lines "2"

            log_event "error" "Error extracting ${project_backup_file}" "false"
            display --indent 6 --text "- Extracting compressed file" --result "FAIL" --color RED

            return 1

        fi       

        sleep 1

        rm -rf "${BROLIT_MAIN_DIR}/tmp/${project_backup_file}"
        [[ $? -eq 0 ]] && log_event "info" "Removing tmp files" "false"
        
    else

        log_event "error" "Error exporting file: ${project_backup_file}" "false"
        display --indent 6 --text "- Exporting file" --result "FAIL" --color RED
        return 1

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
    local remote_domain_list
    remote_domain_list=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort | uniq)

    local project_status
    project_status=$(storage_remote_status_list)

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to choose project status" "false"
        exit 1
    fi

    log_event "info" "Selected project status: ${project_status}" "false"

    local restore_type
    restore_type=$(storage_remote_type_list)

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to choose restore type" "false"
        exit 1
    fi

    log_event "info" "Selected restore type: ${restore_type}" "false"

    local chosen_domain
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

    local project_name
    project_name="$(project_get_name_from_domain "${chosen_domain}")"

    local destination_dir
    if [[ ${restore_type} == "project" ]]; then

        destination_dir="${PROJECTS_PATH}/${chosen_domain}/"

    elif [[ ${restore_type} == "database" ]]; then

        destination_dir="${PROJECTS_PATH}/${chosen_domain}/"
        mkdir -p "${destination_dir}"

    fi

    if [[ ${chosen_domain} != "" ]]; then

        if [[ ${restore_type} == "project" ]]; then

            local archives
            archives="$(borg list --format '{archive}{NL}' ssh://${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:${BACKUP_BORG_PORT}/./applications/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/site/${chosen_domain} | sort -r)"

            local chosen_archive
            chosen_archive="$(whiptail --title "BACKUP SELECTION" --menu "Choose an archive to work with" 20 78 10 $(for x in ${archives}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

            if [[ ${chosen_archive} != "" ]]; then

                display --indent 6 --text "- Selecting Project Backup" --result "DONE" --color GREEN
                display --indent 8 --text "${chosen_archive}.tar.bz2" --tcolor YELLOW
                
                # Get project install type before calling generate_tar_and_decompress
                local project_install_type
                project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${chosen_domain}")"
                
                generate_tar_and_decompress "${chosen_archive}" "${chosen_domain}" "${project_install_type}" "${server_hostname}"

                local sql_file
                sql_file=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" -maxdepth 1 -type f -name '*.sql' -print -quit)

                if [[ -z ${sql_file} ]]; then

                    log_event "error" "SQL file not found at remote path: ${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" "false"
                    display --indent 6 --text "- SQL file not found at remote path" --result "FAIL" --color RED
                    exit 1

                else

                    log_event "info" "SQL file path: ${sql_file}" "false"

                    cp "${sql_file}" "${destination_dir}/$(basename ${sql_file})"

                    if [[ $? -eq 0 ]]; then

                        log_event "info" "SQL file restored successfully to ${destination_dir}" "false"
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

            local sql_file
            sql_file=$(find "${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" -maxdepth 1 -type f -name '*.sql' -print -quit)

            if [[ -z ${sql_file} ]]; then

                log_event "error" "SQL file not found at remote path: ${storage_box_directory}/${BACKUP_BORG_GROUP}/${server_hostname}/projects-online/database/${chosen_domain}" "false"
                display --indent 6 --text "- SQL file not found at remote path" --result "FAIL" --color RED
                exit 1

            else

                log_event "info" "SQL file path: ${sql_file}" "false"
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
        local project_install_type
        project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${chosen_domain}")"
        
        if [[ ${project_install_type} == "docker"* ]]; then

            log_subsection "Restore Files Backup"
            docker_setup_configuration "${project_name}" "${destination_dir}" "${chosen_domain}"
            docker_compose_build "${destination_dir}/docker-compose.yml"

            # Project domain configuration (webserver+certbot+DNS)
            local https_enable
            local project_type
            local project_port
            local project_domain_new="${chosen_domain}"
            local project_install_path="${destination_dir}"
            local project_stage
            local db_pass
            local project_db_status
            local db_engine
            local db_user
            
            https_enable="$(project_update_domain_config "${project_domain_new}" "${project_type}" "${project_install_type}" "${project_port}")"

            # TODO: if and old project with same domain was found, ask what to do (delete old project or skip this step)

            # Post-restore/install tasks
            project_post_install_tasks "${project_install_path}" "${project_type}" "${project_install_type}" "${project_name}" "${project_stage}" "${db_pass}" "${chosen_domain}" "${project_domain_new}"

            # Create/update brolit_project_conf.json file with project info
            project_update_brolit_config "${project_install_path}" "${project_name}" "${project_stage}" "${project_type}" "${project_db_status}" "${db_engine}" "${project_name}_${project_stage}" "localhost" "${db_user}" "${db_pass}" "${project_domain_new}" "" "" "" ""
        fi                
    else
        display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW
        return 1
    fi

}

################################################################################
# Initialize Borg repository if needed
#
# Arguments:
#   ${1} = ${config_file} - Path to borgmatic config file
#
# Outputs:
#   Return 0 if ok, 1 on error.
################################################################################

function initialize_repository() {

    local config_file="${1}"

    # Check if config file exists
    if [[ ! -f "${config_file}" ]]; then
        log_event "error" "Borgmatic config file not found: ${config_file}" "false"
        display --indent 6 --text "- Borgmatic config file not found" --result "FAIL" --color RED
        display --indent 8 --text "${config_file}" --tcolor YELLOW
        return 1
    fi

    # Resolve borgmatic command robustly
    local borg_cmd=""
    if command -v borgmatic >/dev/null 2>&1; then
        borg_cmd="borgmatic"
    elif [[ -x "/root/.local/bin/borgmatic" ]]; then
        borg_cmd="/root/.local/bin/borgmatic"
    elif command -v pipx >/dev/null 2>&1; then
        borg_cmd="pipx run borgmatic"
    elif command -v python3 >/dev/null 2>&1; then
        borg_cmd="python3 -m borgmatic"
    fi

    if [[ -z "${borg_cmd}" ]]; then
        log_event "error" "Borgmatic executable not found via PATH, /root/.local/bin, pipx, or python3 -m" "true"
        display --indent 6 --text "- Borgmatic executable not found" --result "FAIL" --color RED
        return 1
    fi

    # Check if repository already exists
    if eval "${borg_cmd} --config \"${config_file}\" info" >/dev/null 2>&1; then
        log_event "info" "Repository already exists, skipping initialization" "false"
        return 0
    fi

    display --indent 6 --text "- Initializing Borg repository" --result "RUNNING" --color YELLOW
    log_event "info" "Initializing new repository with '${borg_cmd}'" "false"

    # Try to initialize and capture output for diagnostics (e.g., Python Traceback)
    local init_output
    if ! init_output=$(eval "${borg_cmd} init --encryption=none --config \"${config_file}\"" 2>&1); then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Repository initialization" --result "FAIL" --color RED
        log_event "error" "Repository initialization failed. Command='${borg_cmd} init --encryption=none --config ${config_file}'" "false"
        # Surface a short snippet to logs to aid troubleshooting
        log_event "error" "borgmatic stderr: $(echo "${init_output}" | tail -n 10 | tr '\n' ' ')" "true"

        # Detect Python traceback to provide a specific hint
        if echo "${init_output}" | grep -qi "Traceback"; then
            log_event "warning" "Python traceback detected during borgmatic execution. Environment may have broken pipx/venv or mismatched borgmatic install. Consider reinstalling borgmatic with pipx and ensuring PATH includes ~/.local/bin." "true"
        fi

        return 1
    fi

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Repository initialization" --result "DONE" --color GREEN
    log_event "info" "Repository initialized successfully" "false"

    return 0

}

################################################################################
# Update borgmatic templates
#
# Arguments:
#   none
#
# Outputs:
#   Return 0 if ok, 1 on error.
################################################################################

function borg_update_templates() {
    
    local borg_config_dir="/etc/borgmatic.d"
    local template_dir="${BROLIT_MAIN_DIR}/config/borg"
    local backup_dir="${borg_config_dir}/backup-$(date +%Y%m%d-%H%M%S)"
    
    # Check if borg is enabled
    if [[ ${BACKUP_BORG_STATUS} != "enabled" ]]; then
        log_event "info" "Borg backup is not enabled" "false"
        display --indent 6 --text "- Borg backup not enabled" --result "SKIPPED" --color YELLOW
        return 0
    fi
    
    # Check if config directory exists
    if [[ ! -d "${borg_config_dir}" ]]; then
        log_event "error" "Borg config directory not found: ${borg_config_dir}" "false"
        display --indent 6 --text "- Borg config directory not found" --result "FAIL" --color RED
        return 1
    fi

    # Check if template directory exists
    if [[ ! -d "${template_dir}" ]]; then
        log_event "error" "Template directory not found: ${template_dir}" "false"
        display --indent 6 --text "- Template directory not found" --result "FAIL" --color RED
        return 1
    fi

    # Ask for confirmation
    if ! whiptail --title "UPDATE BORGMATIC TEMPLATES" --yesno "This operation will update all borgmatic configuration files and may affect backup creation. A backup will be created in ${BROLIT_TMP_DIR}. Do you want to continue?" 10 80; then
        log_event "info" "User canceled borgmatic template update" "false"
        display --indent 6 --text "- Update canceled by user" --result "SKIPPED" --color YELLOW
        return 1
    fi
    
    # Create backup directory in Brolit tmp directory
    local backup_dir="${BROLIT_TMP_DIR}/borgmatic-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${backup_dir}"
    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to create backup directory: ${backup_dir}" "false"
        display --indent 6 --text "- Create backup directory" --result "FAIL" --color RED
        return 1
    fi
    
    log_event "info" "Backup directory created: ${backup_dir}" "false"
    display --indent 6 --text "- Create backup directory" --result "DONE" --color GREEN
    
    local updated_count=0
    local skipped_count=0
    
    # Find all config files, excluding backup directories
    local config_files=()
    while IFS= read -r -d '' file; do
        # Skip files in backup directories (directories starting with "backup-")
        if [[ ! "${file}" =~ /backup- ]]; then
            config_files+=("${file}")
        fi
    done < <(find "${borg_config_dir}" -name "*.yml" -print0)
    
    # Debug: Show how many files were found
    display --indent 6 --text "- Found $((${#config_files[@]})) config files in ${borg_config_dir}" --tcolor YELLOW
    log_event "info" "Found $((${#config_files[@]})) config files in ${borg_config_dir}" "false"
    
    # Process each config file
    for config_file in "${config_files[@]}"; do
    
        local config_name=$(basename "${config_file}")
        local config_backup="${backup_dir}/${config_name}"
        local updated="false"
        
        # Backup current config
        cp "${config_file}" "${config_backup}"
        if [[ $? -ne 0 ]]; then
            log_event "error" "Failed to backup config: ${config_file}" "false"
            display --indent 6 --text "- Backup ${config_name}" --result "FAIL" --color RED
            continue
        fi
        
        # Determine project name from config file
        local project=$(basename "${config_file}" .yml)

        # Detect if project is Docker
        local project_path="${PROJECTS_PATH}/${project}"
        local project_install_type

        if [[ -d "${project_path}" ]]; then
            # shellcheck source=${BROLIT_MAIN_DIR}/libs/local/project_helper.sh
            source "${BROLIT_MAIN_DIR}/libs/local/project_helper.sh"
            project_install_type="$(project_get_install_type "${project_path}" 2>/dev/null || echo "default")"
        else
            project_install_type="default"
        fi

        # Select appropriate template based on project type
        local template_name
        if [[ "${project_install_type}" == "docker-compose" ]]; then
            template_name="borgmatic.template-docker.yml"
        else
            template_name="borgmatic.template-default.yml"
        fi

        # Update template path
        template="${template_dir}/${template_name}"

        # Check if selected template exists
        if [[ ! -f "${template}" ]]; then
            log_event "error" "Template file not found: ${template}" "false"
            display --indent 8 --text "- Template ${template_name} not found" --result "FAIL" --color RED
            continue
        fi

        display --indent 6 --text "- Processing ${config_name} (type: ${project_install_type})" --tcolor YELLOW

        # Compare template with config
        if ! diff -q "${template}" "${config_file}" >/dev/null 2>&1; then

            display --indent 8 --text "Differences found in ${config_name}" --tcolor YELLOW
            log_event "info" "Differences found between ${template_name} and ${config_name}" "false"
            
            # Ask user if they want to update
            if whiptail --title "UPDATE BORGMATIC CONFIG" --yesno "Do you want to update ${config_name} with changes from ${template_name}?" 10 60; then
                    
                # Create temporary file with updated content
                local temp_file=$(mktemp)
                
                # Copy template content
                cp "${template}" "${temp_file}"

                # Leer valores reales desde .brolit_conf.json
                local group=$(yq -r '.BACKUPS.methods[].borg[].group // ""' /root/.brolit_conf.json)
                local ntfy_username=$(yq -r '.NOTIFICATIONS.ntfy[].config[].username // ""' /root/.brolit_conf.json)
                local ntfy_password=$(yq -r '.NOTIFICATIONS.ntfy[].config[].password // ""' /root/.brolit_conf.json)
                local ntfy_server=$(yq -r '.NOTIFICATIONS.ntfy[].config[].server // ""' /root/.brolit_conf.json)
                local ntfy_topic=$(yq -r '.NOTIFICATIONS.ntfy[].config[].topic // ""' /root/.brolit_conf.json)
                local loki_url=$(yq -r '.constants.loki_url // ""' "${config_file}")
                
                # Usar hostname del sistema
                local hostname=$(hostname)
                
                # Registrar el comando yq real que se está ejecutando
                log_event "debug" "Reading group from brolit_conf.json: yq -r '.BACKUPS.methods[].borg[].group // \"\"' /root/.brolit_conf.json" "false"
                log_event "debug" "Reading ntfy_username from brolit_conf.json: yq -r '.NOTIFICATIONS.ntfy[].config[].username // \"\"' /root/.brolit_conf.json" "false"
                log_event "debug" "Reading ntfy_password from brolit_conf.json: yq -r '.NOTIFICATIONS.ntfy[].config[].password // \"\"' /root/.brolit_conf.json" "false"
                log_event "debug" "Reading ntfy_server from brolit_conf.json: yq -r '.NOTIFICATIONS.ntfy[].config[].server // \"\"' /root/.brolit_conf.json" "false"
                log_event "debug" "Using system hostname: $(hostname)" "false"
                
                # Mostrar valores leídos
                log_event "debug" "Final values: project='${project}', group='${group}', hostname='${hostname}', ntfy_server='${ntfy_server}', ntfy_username='${ntfy_username}', loki_url='${loki_url}'" "false"
                
                declare -A server_user
                declare -A server_server
                declare -A server_port
                
                # Get number of servers from .brolit_conf.json
                local number_of_servers=$(jq -r '.BACKUPS.methods[].borg[].config | length' /root/.brolit_conf.json)
                
                # Validate number_of_servers is a positive integer
                if ! [[ "${number_of_servers}" =~ ^[0-9]+$ ]] || [ "${number_of_servers}" -lt 1 ]; then
                    number_of_servers=0
                fi
                
                # Read server configuration from .brolit_conf.json
                for i in $(seq 1 "${number_of_servers}"); do

                    server_user[${i}]=$(jq -r ".BACKUPS.methods[].borg[].config[${i}-1].user // \"\"" /root/.brolit_conf.json)
                    server_server[${i}]=$(jq -r ".BACKUPS.methods[].borg[].config[${i}-1].server // \"\"" /root/.brolit_conf.json)
                    server_port[${i}]=$(jq -r ".BACKUPS.methods[].borg[].config[${i}-1].port // \"\"" /root/.brolit_conf.json)
                    
                    # Log the jq commands being executed
                    log_event "debug" "Reading server ${i} user: jq -r '.BACKUPS.methods[].borg[].config[${i}-1].user // \"\"' /root/.brolit_conf.json" "false"
                    log_event "debug" "Reading server ${i} server: jq -r '.BACKUPS.methods[].borg[].config[${i}-1].server // \"\"' /root/.brolit_conf.json" "false"
                    log_event "debug" "Reading server ${i} port: jq -r '.BACKUPS.methods[].borg[].config[${i}-1].port // \"\"' /root/.brolit_conf.json" "false"
                    
                    # Log the values read
                    log_event "debug" "Server ${i} values: user='${server_user[${i}]}' server='${server_server[${i}]}' port='${server_port[${i}]}'" "false"
                    
                    # Skip if any required server parameter is empty
                    if [[ -z "${server_user[${i}]}" || -z "${server_server[${i}]}" || -z "${server_port[${i}]}" ]]; then
                        log_event "warning" "Skipping incomplete server configuration for server ${i}" "false"
                        continue
                    fi

                done
                
                # Restore project-specific constants
                if [[ -n "${project}" && "${project}" != "null" ]]; then
                    if yq -i ".constants.project = \"${project}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated project constant" "false"
                    else
                        display --indent 10 --text "project: ${project} [FAIL]" --tcolor RED
                        log_event "error" "Failed to update project constant" "false"
                    fi
                fi
                
                if [[ -n "${group}" && "${group}" != "null" ]]; then
                    if yq -i ".constants.group = \"${group}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated group constant" "false"
                    else
                        display --indent 10 --text "group: ${group} [FAIL]" --tcolor RED
                        log_event "error" "Failed to update group constant" "false"
                    fi
                fi
                
                if [[ -n "${hostname}" && "${hostname}" != "null" ]]; then
                    if yq -i ".constants.hostname = \"${hostname}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated hostname constant" "false"
                    else
                        display --indent 10 --text "hostname: ${hostname} [FAIL]" --tcolor RED
                        log_event "error" "Failed to update hostname constant" "false"
                    fi
                fi
                
                if [[ -n "${ntfy_server}" && "${ntfy_server}" != "null" ]]; then
                    if yq -i ".constants.ntfy_server = \"${ntfy_server}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated ntfy_server constant" "false"
                    else
                        display --indent 10 --text "ntfy_server: ${ntfy_server} [FAIL]" --tcolor RED
                        log_event "error" "Failed to update ntfy_server constant" "false"
                    fi
                fi
                
                if [[ -n "${ntfy_username}" && "${ntfy_username}" != "null" ]]; then
                    if yq -i ".constants.ntfy_username = \"${ntfy_username}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated ntfy_username constant" "false"
                    else
                        display --indent 10 --text "ntfy_username: ${ntfy_username} [FAIL]" --tcolor RED
                        log_event "error" "Failed to update ntfy_username constant" "false"
                    fi
                fi
                
                if [[ -n "${ntfy_password}" && "${ntfy_password}" != "null" ]]; then
                    if yq -i ".constants.ntfy_password = \"${ntfy_password}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated ntfy_password constant" "false"
                    else
                        display --indent 10 --text "ntfy_password: [HIDDEN] [FAIL]" --tcolor RED
                        log_event "error" "Failed to update ntfy_password constant" "false"
                    fi
                fi
                
                if [[ -n "${ntfy_topic}" && "${ntfy_topic}" != "null" ]]; then
                    if yq -i ".constants.ntfy_topic = \"${ntfy_topic}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated ntfy_topic constant" "false"
                    else
                        display --indent 10 --text "ntfy_topic: ${ntfy_topic} [FAIL]" --tcolor RED
                        log_event "error" "Failed to update ntfy_topic constant" "false"
                    fi
                fi
                
                if [[ -n "${loki_url}" && "${loki_url}" != "null" ]]; then
                    if yq -i ".constants.loki_url = \"${loki_url}\"" "${temp_file}"; then
                        log_event "info" "Successfully updated loki_url constant" "false"
                    else
                        display --indent 10 --text "loki_url: ${loki_url} [FAIL]" --tcolor RED
                        log_event "error" "Failed to update loki_url constant" "false"
                    fi
                fi
                
                # Remove loki section if loki_url is not set
                if [[ -z "${loki_url}" || "${loki_url}" == "null" ]]; then
                    yq -i 'del(.loki)' "${temp_file}"
                fi
                
                # Restore server-specific constants
                for i in $(seq 1 "${number_of_servers}"); do

                    [[ -n "${server_user[${i}]}" && "${server_user[${i}]}" != "null" ]] && yq -i ".constants.user_${i} = \"${server_user[${i}]}\"" "${temp_file}"
                    [[ -n "${server_server[${i}]}" && "${server_server[${i}]}" != "null" ]] && yq -i ".constants.server_${i} = \"${server_server[${i}]}\"" "${temp_file}"
                    [[ -n "${server_port[${i}]}" && "${server_port[${i}]}" != "null" ]] && yq -i ".constants.port_${i} = \"${server_port[${i}]}\"" "${temp_file}"
                done
                
                # Remove all existing repositories
                yq -i 'del(.repositories)' "${temp_file}"
                
                # Initialize repositories as empty array
                yq -i '.repositories = []' "${temp_file}"
                
                # Add new repository entries with real values
                for i in $(seq 1 "${number_of_servers}"); do
                    if [[ -n "${server_user[${i}]}" && -n "${server_server[${i}]}" && -n "${server_port[${i}]}" ]]; then
                        yq -i ".repositories += [{\"path\": \"ssh://${server_user[${i}]}@${server_server[${i}]}:${server_port[${i}]}/./applications/${group}/${hostname}/projects-online/site/${project}\", \"label\": \"storage-${server_user[${i}]}\"}]" "${temp_file}"
                    fi
                done
                
                # Move updated file to final location
                mv "${temp_file}" "${config_file}"
                
                log_event "info" "Updated ${config_name} with changes from ${template_name}" "false"
                display --indent 6 --text "- Update ${config_name}" --result "DONE" --color GREEN
                
                # Test the updated configuration
                display --indent 6 --text "- Testing updated configuration"

                # 1. Validate YAML syntax
                if yq eval '.' "${config_file}" > /dev/null 2>&1; then

                    # Log
                    display --indent 8 --text "YAML syntax test: OK" --tcolor WHITE
                    log_event "info" "YAML syntax test passed for ${config_name}" "false"
                    
                    # 2. Test SSH connectivity to each server
                    local ssh_test_passed=true
                    for i in $(seq 1 "${number_of_servers}"); do

                        display --indent 8 --text "Testing SSH connection to ${server_server[${i}]} (port ${server_port[${i}]})"
                        
                        if ssh -o ConnectTimeout=10 -o BatchMode=yes -p "${server_port[${i}]}" "${server_user[${i}]}@${server_server[${i}]}" "exit"; then
                            display --indent 8 --text "Connection to ${server_server[${i}]} OK" --tcolor GREEN
                            log_event "info" "Successfully connected to ${server_server[${i}]}:${server_port[${i}]}" "false"
                        else
                            display --indent 8 --text "Connection to ${server_server[${i}]} FAILED" --tcolor RED
                            log_event "error" "Cannot connect to ${server_server[${i}]}:${server_port[${i}]}" "false"
                            ssh_test_passed=false
                        fi
                        
                    done
                    
                    # 3. Only if SSH tests pass, try borgmatic test (as warning if it fails)
                    if [[ "${ssh_test_passed}" == "true" ]]; then

                        if borgmatic --config "${config_file}" --list --dry-run > /dev/null 2>&1; then

                            display --indent 8 --text "Borgmatic test: OK" --tcolor GREEN
                            log_event "info" "Borgmatic test passed for ${config_name}" "false"

                        else

                            display --indent 8 --text "Borgmatic test: WARNING (expected if repository doesn't exist)" --tcolor YELLOW
                            log_event "warning" "Borgmatic test failed for ${config_name}, but this is expected if repository doesn't exist yet" "false"
                        
                        fi

                    else

                        display --indent 8 --text "Skipping borgmatic test due to SSH connection failures" --tcolor YELLOW

                    fi
                    
                else
                    # Log
                    display --indent 8 --text "YAML syntax test: FAIL" --tcolor RED
                    log_event "error" "YAML syntax test failed for ${config_name}" "false"
                    send_notification "${SERVER_NAME}" "YAML syntax test failed for ${config_name}" "alert"

                fi
                
                updated="true"
                ((updated_count++))

            else

                log_event "info" "Skipped update for ${config_name}" "false"
                display --indent 6 --text "- Update ${config_name}" --result "SKIPPED" --color YELLOW
                ((skipped_count++))

            fi

        else

            log_event "info" "No differences found between ${template_name} and ${config_name}" "false"
            
        fi
        
        [[ "${updated}" == "false" ]] && ((skipped_count++))
        
    done
    
    # Show summary
    display --indent 6 --text "- Update summary"
    display --indent 8 --text "Updated: ${updated_count}" --tcolor GREEN
    display --indent 8 --text "Skipped: ${skipped_count}" --tcolor YELLOW
    
    if [[ ${updated_count} -gt 0 ]]; then
    
        log_event "info" "Successfully updated ${updated_count} borgmatic config files" "false"
        return 0

    else

        log_event "info" "No borgmatic config files were updated" "false"
        return 0

    fi

}
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
################################################################################
#
# Borg Storage Controller - Additional Functions
#
################################################################################

################################################################################
# Test Borgmatic Configuration
#
# Arguments:
#   none
#
# Outputs:
#   Return 0 if valid, 1 on error.
################################################################################

function borgmatic_test_config() {

    local borg_config_dir="/etc/borgmatic.d"
    local config_count=0
    local valid_count=0
    local invalid_count=0

    # Check if borg is enabled
    if [[ ${BACKUP_BORG_STATUS} != "enabled" ]]; then
        log_event "info" "Borg backup is not enabled" "false"
        display --indent 6 --text "- Borg backup not enabled" --result "SKIPPED" --color YELLOW
        return 0
    fi

    # Check if borgmatic is installed
    if ! command -v borgmatic &> /dev/null; then
        log_event "error" "borgmatic command not found" "false"
        display --indent 6 --text "- borgmatic not installed" --result "FAIL" --color RED
        return 1
    fi

    # Check if config directory exists
    if [[ ! -d "${borg_config_dir}" ]]; then
        log_event "error" "Borg config directory not found: ${borg_config_dir}" "false"
        display --indent 6 --text "- Config directory not found" --result "FAIL" --color RED
        return 1
    fi

    log_subsection "Testing Borgmatic Configurations"

    # Test each config file
    for config_file in "${borg_config_dir}"/*.yaml; do
        if [[ -f "${config_file}" ]]; then
            ((config_count++))

            config_name=$(basename "${config_file}")
            display --indent 6 --text "- Testing ${config_name}"

            if borgmatic validate --config "${config_file}" &>/dev/null; then
                ((valid_count++))
                clear_previous_lines "1"
                display --indent 6 --text "- ${config_name}" --result "VALID" --color GREEN
                log_event "info" "Config valid: ${config_name}" "false"
            else
                ((invalid_count++))
                clear_previous_lines "1"
                display --indent 6 --text "- ${config_name}" --result "INVALID" --color RED
                log_event "error" "Config invalid: ${config_name}" "false"

                # Show validation errors
                display --indent 8 --text "Running detailed validation..." --tcolor YELLOW
                borgmatic validate --config "${config_file}"
            fi
        fi
    done

    # Summary
    display --indent 6 --text "- Validation summary"
    display --indent 8 --text "Total: ${config_count}" --tcolor WHITE
    display --indent 8 --text "Valid: ${valid_count}" --tcolor GREEN
    display --indent 8 --text "Invalid: ${invalid_count}" --tcolor RED

    if [[ ${invalid_count} -gt 0 ]]; then
        return 1
    fi

    return 0

}

################################################################################
# List Borgmatic Archives
#
# Arguments:
#   none
#
# Outputs:
#   Return 0 if ok, 1 on error.
################################################################################

function borg_list_archives() {

    local borg_config_dir="/etc/borgmatic.d"
    local config_file

    # Check if borg is enabled
    if [[ ${BACKUP_BORG_STATUS} != "enabled" ]]; then
        log_event "info" "Borg backup is not enabled" "false"
        display --indent 6 --text "- Borg backup not enabled" --result "SKIPPED" --color YELLOW
        return 0
    fi

    # Check if borgmatic is installed
    if ! command -v borgmatic &> /dev/null; then
        log_event "error" "borgmatic command not found" "false"
        display --indent 6 --text "- borgmatic not installed" --result "FAIL" --color RED
        return 1
    fi

    # Let user select which config to list archives from
    local config_files=()
    local config_options=()
    local index=1

    for config_file in "${borg_config_dir}"/*.yaml; do
        if [[ -f "${config_file}" ]]; then
            config_name=$(basename "${config_file}" .yaml)
            config_files+=("${config_file}")
            config_options+=("${index}" "${config_name}")
            ((index++))
        fi
    done

    if [[ ${#config_files[@]} -eq 0 ]]; then
        log_event "warning" "No borgmatic config files found" "false"
        display --indent 6 --text "- No config files found" --result "WARNING" --color YELLOW
        return 1
    fi

    # Add "ALL" option
    config_options+=("${index}" "ALL REPOSITORIES")

    chosen_config=$(whiptail --title "SELECT BORGMATIC CONFIG" --menu "Choose a repository to list archives" 20 78 10 "${config_options[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?

    if [[ ${exitstatus} -ne 0 ]]; then
        log_event "info" "User canceled archive listing" "false"
        display --indent 6 --text "- Listing canceled" --result "SKIPPED" --color YELLOW
        return 1
    fi

    log_subsection "Listing Borgmatic Archives"

    # If "ALL" was selected
    if [[ ${chosen_config} -eq ${index} ]]; then
        for config_file in "${config_files[@]}"; do
            config_name=$(basename "${config_file}" .yaml)
            display --indent 6 --text "- Archives for ${config_name}"
            display --indent 8 --text "Running borgmatic list..." --tcolor YELLOW

            borgmatic list --config "${config_file}" 2>&1 | tail -20

            echo ""
        done
    else
        # List archives for selected config
        selected_index=$((chosen_config - 1))
        config_file="${config_files[$selected_index]}"
        config_name=$(basename "${config_file}" .yaml)

        display --indent 6 --text "- Listing archives for ${config_name}"
        log_event "info" "Listing archives for ${config_name}" "false"

        borgmatic list --config "${config_file}" 2>&1 | tail -50
    fi

    return 0

}

################################################################################
# Prune Old Borgmatic Archives
#
# Arguments:
#   none
#
# Outputs:
#   Return 0 if ok, 1 on error.
################################################################################

function borg_prune_archives() {

    local borg_config_dir="/etc/borgmatic.d"
    local config_file

    # Check if borg is enabled
    if [[ ${BACKUP_BORG_STATUS} != "enabled" ]]; then
        log_event "info" "Borg backup is not enabled" "false"
        display --indent 6 --text "- Borg backup not enabled" --result "SKIPPED" --color YELLOW
        return 0
    fi

    # Check if borgmatic is installed
    if ! command -v borgmatic &> /dev/null; then
        log_event "error" "borgmatic command not found" "false"
        display --indent 6 --text "- borgmatic not installed" --result "FAIL" --color RED
        return 1
    fi

    # Let user select which config to prune
    local config_files=()
    local config_options=()
    local index=1

    for config_file in "${borg_config_dir}"/*.yaml; do
        if [[ -f "${config_file}" ]]; then
            config_name=$(basename "${config_file}" .yaml)
            config_files+=("${config_file}")
            config_options+=("${index}" "${config_name}")
            ((index++))
        fi
    done

    if [[ ${#config_files[@]} -eq 0 ]]; then
        log_event "warning" "No borgmatic config files found" "false"
        display --indent 6 --text "- No config files found" --result "WARNING" --color YELLOW
        return 1
    fi

    # Add "ALL" option
    config_options+=("${index}" "ALL REPOSITORIES")

    chosen_config=$(whiptail --title "SELECT BORGMATIC CONFIG" --menu "Choose repositories to prune old archives" 20 78 10 "${config_options[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?

    if [[ ${exitstatus} -ne 0 ]]; then
        log_event "info" "User canceled prune operation" "false"
        display --indent 6 --text "- Prune canceled" --result "SKIPPED" --color YELLOW
        return 1
    fi

    log_subsection "Pruning Old Borgmatic Archives"

    # If "ALL" was selected
    if [[ ${chosen_config} -eq ${index} ]]; then
        for config_file in "${config_files[@]}"; do
            config_name=$(basename "${config_file}" .yaml)
            display --indent 6 --text "- Pruning ${config_name}"

            if borgmatic prune --config "${config_file}" --stats 2>&1; then
                clear_previous_lines "1"
                display --indent 6 --text "- ${config_name}" --result "PRUNED" --color GREEN
                log_event "info" "Successfully pruned archives for ${config_name}" "false"
            else
                clear_previous_lines "1"
                display --indent 6 --text "- ${config_name}" --result "FAIL" --color RED
                log_event "error" "Failed to prune archives for ${config_name}" "false"
            fi
        done
    else
        # Prune selected config
        selected_index=$((chosen_config - 1))
        config_file="${config_files[$selected_index]}"
        config_name=$(basename "${config_file}" .yaml)

        display --indent 6 --text "- Pruning archives for ${config_name}"
        log_event "info" "Pruning archives for ${config_name}" "false"

        if borgmatic prune --config "${config_file}" --stats 2>&1; then
            clear_previous_lines "1"
            display --indent 6 --text "- Prune ${config_name}" --result "DONE" --color GREEN
            log_event "info" "Successfully pruned archives for ${config_name}" "false"
        else
            clear_previous_lines "1"
            display --indent 6 --text "- Prune ${config_name}" --result "FAIL" --color RED
            log_event "error" "Failed to prune archives for ${config_name}" "false"
            return 1
        fi
    fi

    return 0

}

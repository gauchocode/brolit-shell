#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
################################################################################
#
# Packages Helper: Perform apt actions.
#
#       Ref: https://api.cloudflare.com/
#
################################################################################

################################################################################
# Private: get the Cloudflare domain zone id
#
# Arguments:
#   ${1} = ${zone_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _cloudflare_get_zone_id() {

    local zone_name="${1}"

    local zone_id

    # Using globals: ${SUPPORT_CLOUDFLARE_EMAIL} and ${SUPPORT_CLOUDFLARE_API_KEY}
    if [[ -z ${SUPPORT_CLOUDFLARE_EMAIL} || -z ${SUPPORT_CLOUDFLARE_API_KEY} ]]; then
        # Log
        display --indent 6 --text "- Accessing Cloudflare API" --result "FAIL" --color RED
        display --indent 8 --text "Cloudflare credentials not set"
        log_event "error" "Cloudflare credentials not set" "false"
        return 1
    fi

    # Log
    log_event "debug" "Accessing Cloudflare API ..." "false"
    log_event "debug" "Getting Zone ID for domain: ${zone_name}" "false"
    #display --indent 6 --text "- Accessing Cloudflare API" --result "DONE" --color GREEN
    #display --indent 6 --text "- Checking if domain exists" --result "DONE" --color GREEN

    # Get Zone ID
    zone_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" \
        -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
        -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
        -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${zone_id} ]]; then
        # Log
        log_event "info" "Zone ID found: ${zone_id} for domain ${zone_name}"
        display --indent 8 --text "Domain ${zone_name} found" --tcolor GREEN
        # Return
        echo "${zone_id}"
        return 0
    else
        # Log
        log_event "info" "Zone ID not found for domain ${zone_name}. Maybe domain is not configured yet."
        log_event "debug" "Last command executed: curl -s -X GET \"https://api.cloudflare.com/client/v4/zones?name=${zone_name}\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type: application/json\" | grep -Po '(?<=\"id\":\")[^\"]*' | head -1"
        display --indent 8 --text "Domain ${zone_name} not found" --tcolor YELLOW
        return 1
    fi

}

################################################################################
# Get the Cloudflare domain zone information
#
# Arguments:
#   ${1} = ${zone_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_get_zone_info() {

    local zone_name="${1}"

    log_event "info" "Getting zone information for: ${zone_name}" "false"

    zone_info="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}&status=active" \
        -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
        -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
        -H "Content-Type: application/json")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Zone information: ${zone_info}" "false"

        # Return
        echo "${zone_id}"

        return 0

    else

        log_event "error" "Getting zone information for: ${zone_name}" "false"
        return 1

    fi

}

################################################################################
# Check if domain exists on Cloudflare account
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_domain_exists() {

    local root_domain="${1}"

    local zone_name
    local zone_id

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"
    [[ $? -eq 0 && -n ${zone_id} ]] && return 0

    return 1

}

################################################################################
# Clear Cloudflare cache for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_clear_cache() {

    local root_domain="${1}"

    local zone_name
    local purge_cache

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "info" "Clearing Cloudflare cache for domain: ${root_domain}" "false"
        log_event "debug" "Running: curl -s -X DELETE \"https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type:application/json\" --data '{\"purge_everything\":true}')"

        purge_cache="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type:application/json" \
            --data '{"purge_everything":true}')"

        if [[ ${purge_cache} == *"\"success\":false"* || ${purge_cache} == "" ]]; then
            message="Error trying to clear Cloudflare cache. Results:\n${update}"
            log_event "error" "${message}"
            display --indent 6 --text "- Clearing Cloudflare cache" --result "FAIL" --color RED
            return 1

        else
            message="Cache cleared for domain: ${root_domain}"
            log_event "info" "${message}"
            display --indent 6 --text "- Clearing Cloudflare cache" --result "DONE" --color GREEN
        fi

    else

        return 1

    fi

}

################################################################################
# Set develoment mode for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${dev_mode}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_development_mode() {

    local root_domain="${1}"
    local dev_mode="${2}"

    local purge_cache

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Enabling Development Mode for domain: ${root_domain}" "false"

        dev_mode_result="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/development_mode" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${dev_mode}\"}")"

        # Remove Cloudflare API garbage output
        clear_previous_lines "4"

        if [[ ${dev_mode_result} == *"\"success\":false"* || ${dev_mode_result} == "" ]]; then
            message="Error trying to change development mode for ${root_domain}. Results:\n ${dev_mode_result}"
            log_event "error" "${message}"
            log_event "debug" "Last command executed: curl -X PATCH \"https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/development_mode\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type: application/json\" --data \"{\"value\":\"${dev_mode}\"}\""
            display --indent 6 --text "- Enabling development mode" --result "FAIL" --color RED

            return 1

        else
            message="Development mode for ${root_domain} is ${dev_mode}"
            log_event "info" "${message}"
            display --indent 6 --text "- Enabling development mode" --result "DONE" --color GREEN

        fi

    else

        return 1

    fi

}

################################################################################
# Get configured ssl mode for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_get_ssl_mode() {

    local root_domain="${1}"

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        ssl_mode_result=$(curl -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")

        # Log
        display --indent 6 --text "- Getting SSL Mode for: ${zone_name}" --result "DONE" --color GREEN
        display --indent 8 --text "SSL Mode: ${ssl_mode_result}" --tcolor YELLOW
        log_event "info" "Getting SSL Mode for: ${zone_name}" "false"
        log_event "info" "SSL Mode: ${ssl_mode_result}" "false"

        # Return
        # Possible return values: off, flexible, full, strict
        echo "${ssl_mode_result}"
        return 0

    else
        # Log
        display --indent 6 --text "- Getting SSL Mode for: ${zone_name}" --result "FAIL" --color RED
        log_event "error" "Getting SSL Mode for: ${zone_name}" "false"
        return 1
    fi

}

################################################################################
# Set configured ssl mode for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${ssl_mode} default value: off, valid values: off, flexible, full, strict
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_ssl_mode() {

    local root_domain="${1}"
    local ssl_mode="${2}"

    local ssl_mode_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting SSL Mode for: ${root_domain}"

        ssl_mode_result="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${ssl_mode}\"}")"

        # Remove Cloudflare API garbage output
        #clear_previous_lines "4"

        if [[ ${ssl_mode_result} == *"\"success\":false"* || ${ssl_mode_result} == "" ]]; then
            log_event "error" "Error trying to set ssl mode for ${root_domain}. Results:\n ${ssl_mode_result}" "false"
            return 1

        else
            display --indent 6 --text "- Setting SSL Mode for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "New SSL Mode: ${ssl_mode}" --tcolor YELLOW
            log_event "info" "New SSL mode for ${root_domain} is ${ssl_mode}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Check if record exists for the configured domain
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${zone_id}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_record_exists() {

    local domain="${1}"
    local zone_id="${2}"
    local record_type="${3}"

    local record_name
    local record_id

    # IMPORTANT: We have only insterest on A and CNAME records
    # So, we need to check
    [[ -z ${record_type} ]] && record_type="A"

    # Cloudflare API to change DNS records
    log_event "info" "Checking if record ${domain} exists" "false"

    # Only for better readibility
    record_name="${domain}"

    # Retrieve record_id
    record_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}&type=${record_type}" -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*')"

    if [[ -z ${record_id} ]]; then
        # Log
        display --indent 6 --text "- Record ${record_name} not found"
        log_event "error" "Record ${record_name} not found on Cloudflare" "false"
        log_event "debug" "Last command executed: curl -s -X GET \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}&type=${record_type}\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type: application/json\" | grep -Po '(?<=\"id\":\")[^\"]*'"
        return 1
    else
        # Clean output
        record_id="$(echo "${record_id}" | tr -d '\n')"
        # Log
        log_event "info" "Record ${record_name} found with id: ${record_id}" "false"
        # Return
        echo "${record_id}"
        return 0
    fi

}

################################################################################
# Get record details for the configured domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${domain}
#   ${3} = ${field} - Values: all, id, type, name, content, proxiable, proxied, ttl, locked, zone_id, zone_name, created_on, modified_on
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_get_record_details() {

    local root_domain="${1}"
    local domain="${2}"
    local field="${3}"

    local record_name
    local cur_ip
    local zone_id
    local record_id

    record_name="${domain}"

    cur_ip="${SERVER_IP}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}" "${record_type}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${record_id} ]]; then

        # DNS Record Details
        record="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" 2>&1)"

        # Remove Cloudflare API garbage output (curl progress bars, etc)
        clear_previous_lines "4"

        if [[ ${record} == *"\"success\":false"* || ${record} == "" ]]; then
            # Log
            log_event "error" "Get record details failed. Results:\n${record}"
            display --indent 6 --text "- Getting record details" --result "FAIL" --color RED
            display --indent 8 --text "${message}" --tcolor RED
            return 1
        else
            # Get record details
            record_detail="$(echo "${record}" | grep -Po '(?<="'"${field}"'":")[^"]*' | head -1)"
            # Log
            log_event "info" "Getting record details. Results:\n${record}" "false"
            log_event "info" "${field}: ${record_detail}" "false"
            display --indent 6 --text "- Getting record details" --result "DONE" --color GREEN
            display --indent 8 --text "${field}: ${record_detail}" --tcolor GREEN
            # Return
            echo "${record_detail}"
            return 0
        fi

    fi

}

################################################################################
# Set record details for the configured domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${domain}
#   ${3} = ${record_type} - valid values: A, AAAA, CNAME, HTTPS, TXT, SRV, LOC, MX, NS, SPF, CERT, DNSKEY, DS, NAPTR, SMIMEA, SSHFP, SVCB, TLSA, URI
#   ${4} = ${proxy_status} - true/false
#   ${5} = ${cur_ip}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_record() {

    local root_domain="${1}"
    local domain="${2}"
    local record_type="${3}"
    local proxy_status="${4}"
    local cur_ip="${5}"

    local ttl
    local record_type
    local cur_ip
    local zone_id
    local record_id
    local record_name

    # Only for convention
    record_name="${domain}"

    #TODO: in the future we must rewrite the vars and remove this ugly replace
    ttl=1 #1 for Auto

    # Default value
    proxy_status=false #need to be a bool, not a string

    [[ ${proxy_status} == "true" ]] && proxy_status=true

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"
    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}" "${record_type}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${record_id} ]]; then

        local current_content
        current_content="$(cloudflare_get_record_details "${root_domain}" "${record_name}" "content")"
        exitstatus_current=$?
        if [[ ${exitstatus_current} -eq 0 && "${current_content}" == "${cur_ip}" ]]; then
            log_event "info" "Record ${record_name} already points to ${cur_ip}, skipping update." "false"
            display --indent 6 --text "- Verifying ${record_name} record" --result "DONE" --color GREEN
            display --indent 8 --text "Already correct, skipping" --tcolor GREEN
            return 0
        fi

        # Log
        display --indent 6 --text "- Changing ${record_name} record ..."

        # First delete existing entry
        log_event "debug" "Running: curl -s -X DELETE \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type: application/json\""

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        log_event "debug" "Running: curl -s -X POST \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type: application/json\" --data \"{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}\""

        # Then create (work-around because sometimes update an entry does not work)
        update="$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"

        # Remove Cloudflare API garbage output
        clear_previous_lines "1"

        if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then
            
            # Log
            log_event "error" "Update failed for ${record_name}. Results:\n${update}" "false"
            display --indent 6 --text "- Updating ${record_name} on Cloudflare" --result "FAIL" --color RED
            display --indent 8 --text "Error details in log" --tcolor RED

            if ! whiptail --title "Cloudflare Update Failed" --yesno "Failed to update record for ${record_name}.\n\nDo you want to continue the procedure? (No will abort the whole process)" 12 60; then
                log_event "error" "User chose to abort on failure for ${record_name}" "false"
                return 1
            fi
            log_event "warning" "Continuing despite failure for ${record_name}" "false"
            return 0

        else
            # Log
            log_event "info" "Record ${record_name} updated to: ${cur_ip}" "false"
            display --indent 6 --text "- Updating ${record_name} on Cloudflare" --result "DONE" --color GREEN
            display --indent 8 --text "content: ${cur_ip}" --tcolor GREEN

            return 0

        fi

    else

        # Log
        display --indent 6 --text "- Creating subdomain ${record_name}"
        log_event "debug" "Record ID not found. Trying to add the subdomain: ${record_name}"
        log_event "debug" "Running: curl -s -X POST \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type: application/json\" --data \"{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}\""

        # Command
        update="$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"

        # Remove Cloudflare API garbage output
        clear_previous_lines "1"

        if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then
            # Log
            display --indent 6 --text "- Creating subdomain ${record_name}" --result "FAIL" --color RED
            log_event "error" "Error creating subdomain ${record_name}. Results:\n${update}" "false"

            if ! whiptail --title "Cloudflare Creation Failed" --yesno "Failed to create record for ${record_name}.\n\nDo you want to continue the procedure? (No will abort the whole process)" 12 60; then
                log_event "error" "User chose to abort on failure for ${record_name}" "false"
                return 1
            fi
            log_event "warning" "Continuing despite failure for ${record_name}" "false"
            return 0
        else
            # Log
            display --indent 6 --text "- Creating subdomain ${record_name}" --result "DONE" --color GREEN
            log_event "info" "Subdomain ${record_name} added successfully" "false"
            log_event "debug" "Command returned: ${update}" "false"
            return 0
        fi

    fi

}

################################################################################
# Update record details for the configured domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${domain}
#   ${3} = ${record_type} - valid values: A, AAAA, CNAME, HTTPS, TXT, SRV, LOC, MX, NS, SPF, CERT, DNSKEY, DS, NAPTR, SMIMEA, SSHFP, SVCB, TLSA, URI
#   ${4} = ${proxy_status} - true/false
#   ${5} = ${cur_ip}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_update_record() {

    local root_domain="${1}"
    local domain="${2}"
    local record_type="${3}"
    local proxy_status="${4}"
    local cur_ip="${5}"

    local ttl
    local record_type
    local cur_ip
    local zone_id
    local record_id

    ttl=3600

    record_name="${domain}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"
    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}" "${record_type}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${record_id} ]]; then

        log_event "info" "Trying to update the record '${record_name}'" "false"
        log_event "debug" "Running: curl -s -X PATCH \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}\" \ 
        -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" \ 
        -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" \ 
        -H \"Content-Type: application/json\" \
        --data \"{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}\""

        update="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"

        # Remove Cloudflare API garbage output
        #clear_previous_lines "4"

        if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then
            # Log
            display --indent 6 --text "- Updating subdomain ${record_name}" --result "FAIL" --color RED
            log_event "error" "Updating subdomain ${record_name}" "false"
            log_event "debug" "Command returned: ${update}" "false"
            return 1
        else
            # Log
            display --indent 6 --text "- Updating subdomain ${MAGENTA}${record_name}${ENDCOLOR}" --result "DONE" --color GREEN
            log_event "info" "Subdomain ${record_name} updated successfully" "false"
            log_event "debug" "Command returned: ${update}" "false"
            return 0
        fi

    else

        # TODO: add an error message trying to update a record that does not exist.
        return 1

    fi

}

################################################################################
# Delete record
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_delete_record() {

    local root_domain="${1}"
    local domain="${2}"
    local record_type="${3}"

    local ttl
    local cur_ip
    local zone_id
    local record_id
    local record_name

    record_name="${domain}"

    ttl=1 #1 for Auto

    cur_ip="${SERVER_IP}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"
    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}" "${record_type}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${record_id} ]]; then # Record found on Cloudflare

        log_event "info" "Trying to delete the '${record_type}' record from: '${domain}'" "false"

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${delete} == *"\"success\":false"* || ${delete} == "" ]]; then
            # Log
            log_event "error" "'${record_type}' record delete failed. Results:\n${delete}" "false"
            log_event "debug" "Last command executed: curl -s -X DELETE \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}\" -H \"X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}\" -H \"X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}\" -H \"Content-Type: application/json\""
            display --indent 6 --text "- Deleting '${record_type}' record from Cloudflare" --result "FAIL" --color RED
            display --indent 8 --text "Results:\n${delete}" --tcolor RED

            return 1

        else
            # Log
            log_event "info" "'${record_type}' record deleted: ${record_name}" "false"
            display --indent 6 --text "- Deleting '${record_type}' record from Cloudflare" --result "DONE" --color GREEN
            display --indent 8 --text "Record deleted: ${record_name}" --tcolor YELLOW
            return 0

        fi

    else

        # Record not found
        return 1

    fi

}

################################################################################
# Set cache TTL
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${cache_ttl_value} - default value: 14400, valid values: 0, 30, 60, 300, 1200, 1800, 3600, 7200, 10800, 14400, 18000, 28800, 43200, 57600, 72000, 86400, 172800, 259200, 345600, 432000, 691200, 1382400, 2073600, 2678400, 5356800, 16070400, 31536000
#                             setting a TTL of 0 is equivalent to selecting 'Respect Existing Headers'
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_cache_ttl_value() {

    local root_domain="${1}"
    local cache_ttl_value="${2}"

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then # Zone found

        cache_ttl_result="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/browser_cache_ttl" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${cache_ttl_value}\"}")"

        # Remove Cloudflare API garbage output
        clear_previous_lines "4"

        if [[ ${cache_ttl_result} == *"\"success\":false"* || ${cache_ttl_result} == "" ]]; then
            message="Error trying to set cache ttl for ${root_domain}. Results:\n ${cache_ttl_result}"
            log_event "error" "${message}"
            display --indent 6 --text "- Setting TTL Cache value '${cache_ttl_value}' for ${root_domain}" --result "FAIL" --color RED
            return 1

        else
            message="Cache TTL value for ${root_domain} is ${cache_ttl_result}"
            log_event "info" "${message}"
            display --indent 6 --text "- Setting TTL Cache value '${cache_ttl_value}' for ${root_domain}" --result "DONE" --color GREEN

        fi

    else

        # Zone not found
        return 1

    fi
}

################################################################################

# CLOUDFLARE WAF/SECURITY

################################################################################
# Get security level for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   Prints the current security level value and returns 0 if ok, 1 on error.
################################################################################

function cloudflare_get_security_level() {

    local root_domain="${1}"

    local security_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        security_result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/security_level" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${security_result} == *"\"success\":false"* || ${security_result} == "" ]]; then
            return 1
        else
            # Extract value from JSON response
            local security_value
            security_value="$(echo "${security_result}" | grep -Po '(?<="value":")[^"]*' | head -1)"
            echo "${security_value}"
            return 0
        fi

    else
        return 1
    fi

}

################################################################################
# View all WAF settings for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_view_all_waf_settings() {

    local root_domain="${1}"

    display --indent 6 --text "- Retrieving WAF settings for ${root_domain}"

    # Get Security Level
    local security_level
    security_level="$(cloudflare_get_security_level "${root_domain}")"
    if [[ $? -eq 0 ]]; then
        display --indent 6 --text "Security Level: ${security_level}" --tcolor YELLOW
    else
        display --indent 6 --text "Security Level: Error retrieving" --tcolor RED
    fi

    # Get Bot Fight Mode
    local bot_fight
    bot_fight="$(cloudflare_get_bot_fight_mode "${root_domain}")"
    if [[ $? -eq 0 ]]; then
        display --indent 6 --text "Bot Fight Mode: ${bot_fight}" --tcolor YELLOW
    else
        display --indent 6 --text "Bot Fight Mode: Error retrieving" --tcolor RED
    fi

    # Get Browser Integrity Check
    local browser_check
    browser_check="$(cloudflare_get_browser_check "${root_domain}")"
    if [[ $? -eq 0 ]]; then
        display --indent 6 --text "Browser Integrity Check: ${browser_check}" --tcolor YELLOW
    else
        display --indent 6 --text "Browser Integrity Check: Error retrieving" --tcolor RED
    fi

    # Get Challenge TTL
    local challenge_ttl
    challenge_ttl="$(cloudflare_get_challenge_ttl "${root_domain}")"
    if [[ $? -eq 0 ]]; then
        display --indent 6 --text "Challenge Passage Time: ${challenge_ttl} seconds" --tcolor YELLOW
    else
        display --indent 6 --text "Challenge Passage Time: Error retrieving" --tcolor RED
    fi

    # Get WAF Managed Ruleset
    local waf_status
    waf_status="$(cloudflare_get_waf_managed_ruleset "${root_domain}")"
    if [[ $? -eq 0 ]]; then
        display --indent 6 --text "WAF Managed Ruleset: ${waf_status}" --tcolor YELLOW
    else
        display --indent 6 --text "WAF Managed Ruleset: Error retrieving" --tcolor RED
    fi

    display --indent 6 --text "- Custom Firewall Rules and IP Access Rules can be viewed from their respective menus" --tcolor WHITE

    return 0

}

################################################################################
# Get bot fight mode status for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   Bot fight mode value (on/off), 1 on error.
################################################################################

function cloudflare_get_bot_fight_mode() {

    local root_domain="${1}"

    local bot_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Get bot management configuration
        bot_result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/bot_management" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${bot_result} == *"\"success\":false"* || ${bot_result} == "" ]]; then
            return 1
        else
            # Extract fight_mode value from JSON response
            local bot_value
            bot_value="$(echo "${bot_result}" | grep -Po '(?<="fight_mode":)(true|false)' | head -1)"

            # Convert true/false to on/off
            if [[ ${bot_value} == "true" ]]; then
                echo "on"
            elif [[ ${bot_value} == "false" ]]; then
                echo "off"
            else
                echo "off"  # Default to off if unable to parse
            fi
            return 0
        fi

    else
        return 1
    fi

}

################################################################################
# Get browser integrity check status for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   Browser check value (on/off), 1 on error.
################################################################################

function cloudflare_get_browser_check() {

    local root_domain="${1}"

    local browser_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        browser_result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/browser_check" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${browser_result} == *"\"success\":false"* || ${browser_result} == "" ]]; then
            return 1
        else
            # Extract value from JSON response
            local browser_value
            browser_value="$(echo "${browser_result}" | grep -Po '(?<="value":")[^"]*' | head -1)"
            echo "${browser_value}"
            return 0
        fi

    else
        return 1
    fi

}

################################################################################
# Get challenge TTL for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   Challenge TTL value in seconds, 1 on error.
################################################################################

function cloudflare_get_challenge_ttl() {

    local root_domain="${1}"

    local ttl_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        ttl_result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/challenge_ttl" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${ttl_result} == *"\"success\":false"* || ${ttl_result} == "" ]]; then
            return 1
        else
            # Extract value from JSON response
            local ttl_value
            ttl_value="$(echo "${ttl_result}" | grep -Po '(?<="value":)[^,}]*' | head -1)"
            echo "${ttl_value}"
            return 0
        fi

    else
        return 1
    fi

}

################################################################################
# Get WAF managed ruleset status for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   WAF status (on/off), 1 on error.
################################################################################

function cloudflare_get_waf_managed_ruleset() {

    local root_domain="${1}"

    local waf_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        waf_result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/waf" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${waf_result} == *"\"success\":false"* || ${waf_result} == "" ]]; then
            return 1
        else
            # Extract value from JSON response
            local waf_value
            waf_value="$(echo "${waf_result}" | grep -Po '(?<="value":")[^"]*' | head -1)"
            echo "${waf_value}"
            return 0
        fi

    else
        return 1
    fi

}

################################################################################
# Set security level for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${security_level} - valid values: off, essentially_off, low, medium, high, under_attack
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_security_level() {

    local root_domain="${1}"
    local security_level="${2}"

    local security_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting Security Level for: ${root_domain}"

        security_result="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/security_level" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${security_level}\"}")"

        if [[ ${security_result} == *"\"success\":false"* || ${security_result} == "" ]]; then
            log_event "error" "Error trying to set security level for ${root_domain}. Results:\n ${security_result}" "false"
            display --indent 6 --text "- Setting Security Level" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- Setting Security Level for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "New Security Level: ${security_level}" --tcolor YELLOW
            log_event "info" "New security level for ${root_domain} is ${security_level}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Set bot fight mode for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${bot_fight_mode} - valid values: on, off
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_bot_fight_mode() {

    local root_domain="${1}"
    local bot_fight_mode="${2}"

    local bot_fight_result
    local fight_mode_bool

    # Convert on/off to true/false
    if [[ ${bot_fight_mode} == "on" ]]; then
        fight_mode_bool="true"
    else
        fight_mode_bool="false"
    fi

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting Bot Fight Mode for: ${root_domain}"

        # Try bot_management endpoint first
        bot_fight_result="$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/bot_management" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"fight_mode\":${fight_mode_bool}}")"

        if [[ ${bot_fight_result} == *"\"success\":false"* || ${bot_fight_result} == *"\"code\":1003"* ]]; then
            # If that fails, try the settings endpoint
            bot_fight_result="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/bot_fight_mode" \
                -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
                -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
                -H "Content-Type: application/json" \
                --data "{\"value\":\"${bot_fight_mode}\"}")"
        fi

        if [[ ${bot_fight_result} == *"\"success\":false"* || ${bot_fight_result} == "" ]]; then
            log_event "error" "Error trying to set bot fight mode for ${root_domain}. Results:\n ${bot_fight_result}" "false"
            display --indent 6 --text "- Setting Bot Fight Mode" --result "FAIL" --color RED
            display --indent 8 --text "Check logs for details" --tcolor RED
            return 1

        else
            display --indent 6 --text "- Setting Bot Fight Mode for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "Bot Fight Mode: ${bot_fight_mode}" --tcolor YELLOW
            log_event "info" "Bot fight mode for ${root_domain} is ${bot_fight_mode}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Set browser integrity check for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${browser_check} - valid values: on, off
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_browser_check() {

    local root_domain="${1}"
    local browser_check="${2}"

    local browser_check_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting Browser Integrity Check for: ${root_domain}"

        browser_check_result="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/browser_check" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${browser_check}\"}")"

        if [[ ${browser_check_result} == *"\"success\":false"* || ${browser_check_result} == "" ]]; then
            log_event "error" "Error trying to set browser check for ${root_domain}. Results:\n ${browser_check_result}" "false"
            display --indent 6 --text "- Setting Browser Integrity Check" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- Setting Browser Integrity Check for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "Browser Check: ${browser_check}" --tcolor YELLOW
            log_event "info" "Browser integrity check for ${root_domain} is ${browser_check}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Set challenge passage time for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${challenge_ttl} - valid values: 300, 900, 1800, 2700, 3600, 7200, 10800, 14400, 28800, 43200, 86400
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_challenge_ttl() {

    local root_domain="${1}"
    local challenge_ttl="${2}"

    local challenge_ttl_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting Challenge Passage Time for: ${root_domain}"

        challenge_ttl_result="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/challenge_ttl" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":${challenge_ttl}}")"

        if [[ ${challenge_ttl_result} == *"\"success\":false"* || ${challenge_ttl_result} == "" ]]; then
            log_event "error" "Error trying to set challenge ttl for ${root_domain}. Results:\n ${challenge_ttl_result}" "false"
            display --indent 6 --text "- Setting Challenge Passage Time" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- Setting Challenge Passage Time for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "Challenge TTL: ${challenge_ttl} seconds" --tcolor YELLOW
            log_event "info" "Challenge passage time for ${root_domain} is ${challenge_ttl}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Set WAF managed ruleset (Free) for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${waf_status} - valid values: on, off
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_waf_managed_ruleset() {

    local root_domain="${1}"
    local waf_status="${2}"

    local waf_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting WAF Managed Ruleset for: ${root_domain}"

        waf_result="$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/waf" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${waf_status}\"}")"

        if [[ ${waf_result} == *"\"success\":false"* || ${waf_result} == "" ]]; then
            log_event "error" "Error trying to set WAF for ${root_domain}. Results:\n ${waf_result}" "false"
            display --indent 6 --text "- Setting WAF Managed Ruleset" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- Setting WAF Managed Ruleset for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "WAF Status: ${waf_status}" --tcolor YELLOW
            log_event "info" "WAF managed ruleset for ${root_domain} is ${waf_status}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# List custom firewall rules for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_list_custom_rules() {

    local root_domain="${1}"

    local rules_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Listing Custom Firewall Rules for: ${root_domain}"

        # Get the custom rules ruleset
        rules_result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/rulesets/phases/http_request_firewall_custom/entrypoint" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        # Log the raw response for debugging
        log_event "debug" "Custom rules API response: ${rules_result}" "false"

        if [[ ${rules_result} == *"\"success\":false"* || ${rules_result} == "" ]]; then
            log_event "error" "Error trying to list custom rules for ${root_domain}. Results:\n ${rules_result}" "false"
            display --indent 6 --text "- Listing Custom Rules" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- Custom Firewall Rules for: ${root_domain}" --result "DONE" --color GREEN

            # Save response to temp file for better parsing
            local temp_file="/tmp/cf_rules_$$.json"
            echo "${rules_result}" > "${temp_file}"

            # Count rules - look for rules inside the "rules" array
            local rules_count
            rules_count="$(grep -o '"description"' "${temp_file}" | wc -l)"

            display --indent 8 --text "Total rules: ${rules_count}/5" --tcolor YELLOW

            # If no rules found, show the raw JSON structure for debugging
            if [[ ${rules_count} -eq 0 ]]; then
                display --indent 8 --text "No rules found. Check logs for API response." --tcolor RED
                log_event "debug" "JSON structure: $(echo "${rules_result}" | grep -o '"result":{[^}]*}' | head -c 500)" "false"
                rm -f "${temp_file}"
                return 0
            fi

            echo ""

            # Extract rules from the JSON
            # Try to extract each rule by parsing the rules array
            local rule_counter=1
            local in_rules_array=0

            # Split JSON into lines and process
            while IFS= read -r line; do
                # Check if we're entering the rules array
                if [[ ${line} == *'"rules"'* ]]; then
                    in_rules_array=1
                    continue
                fi

                # Look for rule entries within the rules array
                if [[ ${in_rules_array} -eq 1 ]] && [[ ${line} == *'"id"'* ]]; then
                    # Extract rule ID
                    local rule_id
                    rule_id="$(echo "${line}" | grep -o '"id":"[^"]*"' | sed 's/"id":"//g' | sed 's/"//g')"

                    # Skip empty IDs
                    [[ -z ${rule_id} ]] && continue

                    # Extract description
                    local rule_desc
                    rule_desc="$(grep -A 5 "\"id\":\"${rule_id}\"" "${temp_file}" | grep '"description"' | head -1 | sed 's/.*"description":"\([^"]*\)".*/\1/')"

                    # Extract action
                    local rule_action
                    rule_action="$(grep -A 10 "\"id\":\"${rule_id}\"" "${temp_file}" | grep '"action"' | head -1 | sed 's/.*"action":"\([^"]*\)".*/\1/')"

                    # Extract expression
                    local rule_expr
                    rule_expr="$(grep -A 10 "\"id\":\"${rule_id}\"" "${temp_file}" | grep '"expression"' | head -1 | sed 's/.*"expression":"\([^"]*\)".*/\1/' | sed 's/\\//g')"

                    # Only display if we found a description (indicates it's a real rule)
                    if [[ -n ${rule_desc} ]]; then
                        display --indent 8 --text "Rule #${rule_counter}:" --tcolor YELLOW
                        display --indent 10 --text "Name: ${rule_desc}" --tcolor GREEN
                        display --indent 10 --text "ID: ${rule_id}" --tcolor CYAN
                        display --indent 10 --text "Action: ${rule_action}" --tcolor MAGENTA
                        display --indent 10 --text "Expression: ${rule_expr}" --tcolor WHITE
                        echo ""

                        rule_counter=$((rule_counter + 1))
                    fi
                fi
            done < "${temp_file}"

            # Clean up temp file
            rm -f "${temp_file}"

            log_event "info" "Custom rules listed for ${root_domain}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Create custom firewall rule for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${rule_name}
#   ${3} = ${rule_expression}
#   ${4} = ${rule_action} - valid values: block, challenge, js_challenge, managed_challenge, allow, log
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_create_custom_rule() {

    local root_domain="${1}"
    local rule_name="${2}"
    local rule_expression="${3}"
    local rule_action="${4}"

    local create_result
    local ruleset_id

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Creating Custom Firewall Rule for: ${root_domain}"
        log_event "debug" "Rule name: ${rule_name}, Expression: ${rule_expression}, Action: ${rule_action}"

        # First, get the ruleset ID for the zone
        ruleset_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/rulesets/phases/http_request_firewall_custom/entrypoint" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)"

        if [[ -z ${ruleset_id} ]]; then
            # If no ruleset exists, create one first
            log_event "debug" "No ruleset found, creating new ruleset"

            create_result="$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/rulesets" \
                -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
                -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
                -H "Content-Type: application/json" \
                --data "{\"name\":\"Custom Firewall Rules\",\"description\":\"Custom firewall rules for zone\",\"kind\":\"zone\",\"phase\":\"http_request_firewall_custom\",\"rules\":[{\"description\":\"${rule_name}\",\"expression\":\"${rule_expression}\",\"action\":\"${rule_action}\"}]}")"
        else
            # Add rule to existing ruleset
            log_event "debug" "Adding rule to existing ruleset: ${ruleset_id}"

            create_result="$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/rulesets/${ruleset_id}" \
                -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
                -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
                -H "Content-Type: application/json" \
                --data "{\"rules\":[{\"description\":\"${rule_name}\",\"expression\":\"${rule_expression}\",\"action\":\"${rule_action}\"}]}")"
        fi

        if [[ ${create_result} == *"\"success\":false"* || ${create_result} == "" ]]; then
            log_event "error" "Error trying to create custom rule for ${root_domain}. Results:\n ${create_result}" "false"
            display --indent 6 --text "- Creating Custom Rule" --result "FAIL" --color RED
            display --indent 8 --text "Check logs for details" --tcolor RED
            return 1

        else
            display --indent 6 --text "- Creating Custom Rule for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "Rule: ${rule_name}" --tcolor YELLOW
            display --indent 8 --text "Action: ${rule_action}" --tcolor YELLOW
            log_event "info" "Custom rule created for ${root_domain}: ${rule_name}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Delete custom firewall rule for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${rule_id}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_delete_custom_rule() {

    local root_domain="${1}"
    local rule_id="${2}"

    local delete_result
    local ruleset_id

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Deleting Custom Firewall Rule for: ${root_domain}"

        # Get the ruleset ID
        ruleset_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/rulesets/phases/http_request_firewall_custom/entrypoint" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)"

        if [[ -z ${ruleset_id} ]]; then
            log_event "error" "No ruleset found for ${root_domain}" "false"
            display --indent 6 --text "- Deleting Custom Rule" --result "FAIL" --color RED
            display --indent 8 --text "No ruleset found" --tcolor RED
            return 1
        fi

        delete_result="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/rulesets/${ruleset_id}/rules/${rule_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${delete_result} == *"\"success\":false"* || ${delete_result} == "" ]]; then
            log_event "error" "Error trying to delete custom rule for ${root_domain}. Results:\n ${delete_result}" "false"
            display --indent 6 --text "- Deleting Custom Rule" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- Deleting Custom Rule for: ${root_domain}" --result "DONE" --color GREEN
            log_event "info" "Custom rule deleted for ${root_domain}: ${rule_id}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# List IP access rules for domain
#
# Arguments:
#   ${1} = ${root_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_list_ip_access_rules() {

    local root_domain="${1}"

    local rules_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Listing IP Access Rules for: ${root_domain}"

        rules_result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/firewall/access_rules/rules" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${rules_result} == *"\"success\":false"* || ${rules_result} == "" ]]; then
            log_event "error" "Error trying to list IP access rules for ${root_domain}. Results:\n ${rules_result}" "false"
            display --indent 6 --text "- Listing IP Access Rules" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- IP Access Rules for: ${root_domain}" --result "DONE" --color GREEN

            # Parse and display rules
            local rules_count
            rules_count="$(echo "${rules_result}" | grep -o '"id":' | wc -l)"

            display --indent 8 --text "Total IP rules: ${rules_count}" --tcolor YELLOW

            # Display rules with their IPs and actions
            echo "${rules_result}" | grep -o '"configuration":{"target":"[^"]*","value":"[^"]*"},"mode":"[^"]*"' | while read -r rule_line; do
                local ip_value
                local mode_value
                ip_value="$(echo "${rule_line}" | grep -o '"value":"[^"]*"' | sed 's/"value":"//g' | sed 's/"//g')"
                mode_value="$(echo "${rule_line}" | grep -o '"mode":"[^"]*"' | sed 's/"mode":"//g' | sed 's/"//g')"
                display --indent 8 --text "- IP: ${ip_value} | Action: ${mode_value}" --tcolor GREEN
            done

            log_event "info" "IP access rules listed for ${root_domain}" "false"
            log_event "debug" "Rules data: ${rules_result}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Add IP access rule for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${ip_address}
#   ${3} = ${action} - valid values: block, challenge, whitelist, js_challenge, managed_challenge
#   ${4} = ${note} - optional note
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_add_ip_access_rule() {

    local root_domain="${1}"
    local ip_address="${2}"
    local action="${3}"
    local note="${4}"

    local create_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Adding IP Access Rule for: ${root_domain}"
        log_event "debug" "IP: ${ip_address}, Action: ${action}, Note: ${note}"

        # Build the data payload
        local data_payload
        if [[ -n ${note} ]]; then
            data_payload="{\"mode\":\"${action}\",\"configuration\":{\"target\":\"ip\",\"value\":\"${ip_address}\"},\"notes\":\"${note}\"}"
        else
            data_payload="{\"mode\":\"${action}\",\"configuration\":{\"target\":\"ip\",\"value\":\"${ip_address}\"}}"
        fi

        create_result="$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/firewall/access_rules/rules" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "${data_payload}")"

        if [[ ${create_result} == *"\"success\":false"* || ${create_result} == "" ]]; then
            log_event "error" "Error trying to add IP access rule for ${root_domain}. Results:\n ${create_result}" "false"
            display --indent 6 --text "- Adding IP Access Rule" --result "FAIL" --color RED
            display --indent 8 --text "Check logs for details" --tcolor RED
            return 1

        else
            display --indent 6 --text "- Adding IP Access Rule for: ${root_domain}" --result "DONE" --color GREEN
            display --indent 8 --text "IP: ${ip_address}" --tcolor YELLOW
            display --indent 8 --text "Action: ${action}" --tcolor YELLOW
            log_event "info" "IP access rule added for ${root_domain}: ${ip_address} (${action})" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################
# Delete IP access rule for domain
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${rule_id}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_delete_ip_access_rule() {

    local root_domain="${1}"
    local rule_id="${2}"

    local delete_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Deleting IP Access Rule for: ${root_domain}"

        delete_result="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/firewall/access_rules/rules/${rule_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${delete_result} == *"\"success\":false"* || ${delete_result} == "" ]]; then
            log_event "error" "Error trying to delete IP access rule for ${root_domain}. Results:\n ${delete_result}" "false"
            display --indent 6 --text "- Deleting IP Access Rule" --result "FAIL" --color RED
            return 1

        else
            display --indent 6 --text "- Deleting IP Access Rule for: ${root_domain}" --result "DONE" --color GREEN
            log_event "info" "IP access rule deleted for ${root_domain}: ${rule_id}" "false"
            return 0
        fi

    else

        return 1

    fi

}

################################################################################

# CLOUDFLARE PRO

################################################################################
# Set http3
#
# Arguments:
#   ${1} = ${root_domain}
#   ${2} = ${http3_setting} - default value: off, valid values: on, off
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function cloudflare_set_http3_setting() {

    local root_domain="${1}"
    local http3_setting="${2}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then # Zone found

        cache_ttl_result="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/http3" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${http3_setting}\"}")"

        if [[ ${cache_ttl_result} == *"\"success\":false"* || ${cache_ttl_result} == "" ]]; then
            message="Error trying to set http3 for ${root_domain}. Results:\n ${cache_ttl_result}"
            log_event "error" "${message}" "false"
            return 1

        else
            message="HTTP3 setting for ${root_domain} is ${cache_ttl_result}"
            log_event "info" "${message}" "false"

            return 0

        fi

    else

        # Zone not found
        return 1

    fi

}

#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
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
        record="$(curl -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        # Remove Cloudflare API garbage output
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
        # clear_previous_lines "4"

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
            display --indent 8 --text "Content: ${cur_ip}" --tcolor GREEN

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

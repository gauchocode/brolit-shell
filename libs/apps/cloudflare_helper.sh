#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.43
################################################################################
#
#   Ref: https://api.cloudflare.com/
#
################################################################################

function _cloudflare_get_zone_id() {

    # $1 = ${zone_name}

    local zone_name=$1

    local zone_id

    # Checking cloudflare credentials file
    generate_cloudflare_config

    # Using globals: ${dns_cloudflare_email} and ${dns_cloudflare_api_key}

    # Log
    display --indent 6 --text "- Accessing Cloudflare API" --result "DONE" --color GREEN
    display --indent 6 --text "- Checking if domain exists" --result "DONE" --color GREEN
    log_event "info" "Accessing Cloudflare API ..."
    log_event "info" "Getting Zone ID for domain: ${zone_name}"

    # Get Zone ID
    zone_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" \
        -H "X-Auth-Email: ${dns_cloudflare_email}" \
        -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
        -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${zone_id} != "" ]]; then

        # Log
        log_event "info" "Zone ID found: ${zone_id} for domain ${zone_name}"
        display --indent 8 --text "Domain ${zone_name} found" --tcolor GREEN

        # Return
        echo "${zone_id}"

    else

        # Log
        log_event "info" "Zone ID not found for domain ${zone_name}. Maybe domain is not configured yet."
        log_event "debug" "Last command executed: curl -s -X GET \"https://api.cloudflare.com/client/v4/zones?name=${zone_name}\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type: application/json\" | grep -Po '(?<=\"id\":\")[^\"]*' | head -1"
        display --indent 8 --text "Domain ${zone_name} not found" --tcolor YELLOW

        return 1

    fi

}

function _cloudflare_clear_garbage_output() {

    # Remove Cloudflare API garbage output
    clear_last_line
    clear_last_line
    clear_last_line
    clear_last_line

}

################################################################################

function cloudflare_get_zone_info() {

    log_event "info" "Getting zone information for: ${zone_name}"

    zone_info="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}&status=active" \
        -H "X-Auth-Email: ${dns_cloudflare_email}" \
        -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
        -H "Content-Type: application/json")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Zone information: ${zone_info}"

        # Return
        echo "${zone_id}"

    else

        return 1

    fi

}

function cloudflare_domain_exists() {

    # $1 = ${root_domain}

    local root_domain=$1

    local zone_name
    local zone_id

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${zone_id} != "" ]]; then

        # Return
        return 0

    else

        # Return
        return 1
    fi

}

function cloudflare_clear_cache() {

    # $1 = ${root_domain}

    local root_domain=$1

    local zone_name
    local purge_cache

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "info" "Clearing Cloudflare cache for domain: ${root_domain}"
        log_event "debug" "Running: curl -s -X DELETE \"https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type:application/json\" --data '{\"purge_everything\":true}')"

        purge_cache="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
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

function cloudflare_set_development_mode() {

    # $1 = ${root_domain}
    # $2 = ${dev_mode}

    local root_domain=$1
    local dev_mode=$2

    local purge_cache

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Enabling Development Mode for domain: ${root_domain}"

        dev_mode_result="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/development_mode" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${dev_mode}\"}")"

        # Remove Cloudflare API garbage output
        _cloudflare_clear_garbage_output

        if [[ ${dev_mode_result} == *"\"success\":false"* || ${dev_mode_result} == "" ]]; then
            message="Error trying to change development mode for ${root_domain}. Results:\n ${dev_mode_result}"
            log_event "error" "${message}"
            log_event "debug" "Last command executed: curl -X PATCH \"https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/development_mode\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type: application/json\" --data \"{\"value\":\"${dev_mode}\"}\""
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

function cloudflare_get_ssl_mode() {

    # $1 = ${root_domain}

    local root_domain=$1

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Gettinh SSL Mode for: ${zone_name}"
        display --indent 6 --text "- Gettinh SSL Mode for: ${zone_name}"

        ssl_mode_result=$(curl -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json")

        # Return
        # Possible return values: off, flexible, full, strict
        echo "${ssl_mode_result}"

    else

        return 1

    fi

}

function cloudflare_set_ssl_mode() {

    # $1 = ${root_domain}
    # $2 = ${ssl_mode} default value: off, valid values: off, flexible, full, strict

    local root_domain=$1
    local ssl_mode=$2

    local ssl_mode_result

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting SSL Mode for: ${zone_name}"
        display --indent 6 --text "- Setting SSL Mode for: ${zone_name}"

        ssl_mode_result="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${ssl_mode}\"}")"

        # Remove Cloudflare API garbage output
        _cloudflare_clear_garbage_output

        if [[ ${ssl_mode_result} == *"\"success\":false"* || ${ssl_mode_result} == "" ]]; then
            message="Error trying to change ssl mode for ${root_domain}. Results:\n ${ssl_mode_result}"
            log_event "error" "${message}"
            return 1

        else
            message="SSL mode for ${root_domain} is ${ssl_mode}"
            log_event "info" "${message}"

        fi

    else

        return 1

    fi

}

function cloudflare_record_exists() {

    # $1 = ${domain}
    # $2 = ${zone_id}

    local domain=$1
    local zone_id=$2

    # Cloudflare API to change DNS records
    log_event "info" "Checking if record ${domain} exists"

    # Only for better readibility
    record_name="${domain}"

    # Retrieve record_id
    record_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: ${dns_cloudflare_email}" -H "X-Auth-Key: ${dns_cloudflare_api_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*')"

    log_event "debug" "Last command executed: curl -s -X GET \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type: application/json\" | grep -Po '(?<=\"id\":\")[^\"]*'"

    exitstatus=$?
    if [[ ${record_id} == "" ]]; then

        log_event "info" "Record ${record_name} not found on Cloudflare"
        display --indent 6 --text "- Record ${record_name} not found"

        return 1

    else

        # Clean output
        record_id="$(echo "${record_id}" | tr -d '\n')"

        log_event "info" "Record ${record_name} found with id: ${record_id}"

        # Return
        echo "${record_id}"

    fi

}

function cloudflare_get_record_details() {

    # $1 = ${root_domain}
    # $2 = ${domain}
    # $3 = ${field} - Values: all, id, type, name, content, proxiable, proxied, ttl, locked, zone_id, zone_name, created_on, modified_on

    local root_domain=$1
    local domain=$2
    local field=$3

    local record_name
    local cur_ip
    local zone_id
    local record_id

    record_name="${domain}"

    cur_ip="${SERVER_IP}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${record_id} != "" ]]; then

        # DNS Record Details
        record="$(curl -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json")"

        # Remove Cloudflare API garbage output
        _cloudflare_clear_garbage_output

        if [[ ${record} == *"\"success\":false"* || ${record} == "" ]]; then

            log_event "error" "Get record details failed. Results:\n${record}"
            display --indent 6 --text "- Getting record details" --result "FAIL" --color RED
            display --indent 8 --text "${message}" --tcolor RED

            return 1

        else

            log_event "info" "Getting record details. Results:\n${record}"
            display --indent 6 --text "- Getting record details" --result "DONE" --color GREEN

            record_detail="$(echo "${record}" | grep -Po '(?<="'"${field}"'":")[^"]*' | head -1)"

            display --indent 8 --text "${field}: ${record_detail}" --tcolor GREEN

        fi

    fi

}

function cloudflare_set_record() {

    # $1 = ${root_domain}
    # $2 = ${domain}
    # $3 = ${record_type} - valid values: A, AAAA, CNAME, HTTPS, TXT, SRV, LOC, MX, NS, SPF, CERT, DNSKEY, DS, NAPTR, SMIMEA, SSHFP, SVCB, TLSA, URI
    # $4 = ${proxy_status} - true/false

    local root_domain=$1
    local domain=$2
    local record_type=$3
    local proxy_status=$4

    local ttl
    local record_type
    local cur_ip
    local zone_id
    local record_id

    record_name="${domain}"

    #TODO: in the future we must rewrite the vars and remove this ugly replace
    ttl=1 #1 for Auto

    if [[ -z "${proxy_status}" || ${proxy_status} == "" || ${proxy_status} == "false" ]]; then

        # Default value
        proxy_status=false #need to be a bool, not a string

    else

        proxy_status=true #need to be a bool, not a string

    fi

    cur_ip="${SERVER_IP}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${record_id} != "" ]]; then

        # Log
        display --indent 6 --text "- Changing ${record_name} IP ..."

        # First delete
        log_event "debug" "Running: curl -s -X DELETE \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type: application/json\""

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json")"

        log_event "debug" "Running: curl -s -X POST \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type: application/json\" --data \"{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}\""

        # Then create (work-around because sometimes update an entry does not work)
        update="$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"

        # Remove Cloudflare API garbage output
        _cloudflare_clear_garbage_output

        if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then
            message="Update failed. Results:\n${update}"
            log_event "error" "${message}" "false"
            display --indent 6 --text "- Updating subdomain on Cloudflare" --result "FAIL" --color RED
            display --indent 8 --text "${message}" --tcolor RED

            return 1

        else
            message="IP changed to: ${SERVER_IP}"
            log_event "info" "${message}" "false"
            display --indent 6 --text "- Updating subdomain on Cloudflare" --result "DONE" --color GREEN
            display --indent 8 --text "IP: ${SERVER_IP}" --tcolor GREEN

            return 0

        fi

    else

        display --indent 6 --text "- Creating subdomain ${MAGENTA}${record_name}${ENDCOLOR}"
        log_event "debug" "Record ID not found. Trying to add the subdomain: ${record_name}"

        update="$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Remove Cloudflare API garbage output
            _cloudflare_clear_garbage_output

            display --indent 6 --text "- Creating subdomain ${MAGENTA}${record_name}${ENDCOLOR}" --result "DONE" --color GREEN
            log_event "info" "Subdomain ${record_name} added successfully" "false"

            return 0

        else

            # Remove Cloudflare API garbage output
            _cloudflare_clear_garbage_output

            display --indent 6 --text "- Creating subdomain ${record_name}" --result "FAIL" --color RED
            log_event "error" "Error creating subdomain ${record_name}" "false"
            log_event "debug" "Last command executed: curl -X POST \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type: application/json\" --data \"{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}\""

            return 1

        fi

    fi

}

function cloudflare_update_record() {

    # $1 = ${root_domain}
    # $2 = ${domain}
    # $3 = ${record_type} - valid values: A, AAAA, CNAME, HTTPS, TXT, SRV, LOC, MX, NS, SPF, CERT, DNSKEY, DS, NAPTR, SMIMEA, SSHFP, SVCB, TLSA, URI
    # $4 = ${proxy_status} - true/false

    local root_domain=$1
    local domain=$2
    local record_type=$3
    local proxy_status=$4

    local ttl
    local record_type
    local cur_ip
    local zone_id
    local record_id

    record_name="${domain}"

    # TODO: This should be a parameter ($record_content)
    cur_ip="${SERVER_IP}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${record_id} != "" ]]; then

        update="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"

        # Remove Cloudflare API garbage output
        _cloudflare_clear_garbage_output

    fi

}

function cloudflare_delete_a_record() {

    # $1 = ${root_domain}
    # $2 = ${domain}

    local root_domain=$1
    local domain=$2

    # Cloudflare API to delete record
    log_event "info" "Accessing to Cloudflare API to delete record ${domain}"

    record_name="${domain}"

    #TODO: in the future we must rewrite the vars and remove this ugly replace
    record_type="A"
    ttl=1 #1 for Auto

    cur_ip="${SERVER_IP}"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    record_id="$(cloudflare_record_exists "${record_name}" "${zone_id}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${record_id} != "" ]]; then # Record found on Cloudflare

        log_event "info" "Trying to delete the record ..."

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json")"

        # Remove Cloudflare API garbage output
        _cloudflare_clear_garbage_output

        if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then

            message="A record delete failed. Results:\n${delete}"
            log_event "error" "${message}"
            log_event "debug" "Last command executed: curl -s -X DELETE \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}\" -H \"X-Auth-Email: ${dns_cloudflare_email}\" -H \"X-Auth-Key: ${dns_cloudflare_api_key}\" -H \"Content-Type: application/json\""
            display --indent 6 --text "- Deleting A record from Cloudflare" --result "FAIL" --color RED
            display --indent 8 --text "${message}" --tcolor RED

            return 1

        else
            message="A record deleted: ${record_name}"
            log_event "info" "${message}"
            display --indent 6 --text "- Deleting A record from Cloudflare" --result "DONE" --color GREEN
            display --indent 8 --text "Record deleted: ${record_name}" --tcolor YELLOW

        fi

        return 0

    else

        # Record not found
        return 1

    fi

}

function cloudflare_set_cache_ttl_value() {

    # $1 = ${root_domain}
    # $2 = ${cache_ttl_value} - default value: 14400, valid values: 0, 30, 60, 300, 1200, 1800, 3600, 7200, 10800, 14400, 18000, 28800, 43200, 57600, 72000, 86400, 172800, 259200, 345600, 432000, 691200, 1382400, 2073600, 2678400, 5356800, 16070400, 31536000
    #                           setting a TTL of 0 is equivalent to selecting 'Respect Existing Headers'

    local root_domain=$1
    local cache_ttl_value=$2

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then # Zone found

        cache_ttl_result="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/browser_cache_ttl" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${cache_ttl_value}\"}")"

        # Remove Cloudflare API garbage output
        _cloudflare_clear_garbage_output

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

# PRO

function cloudflare_set_http3_setting() {

    # $1 = ${root_domain}
    # $2 = ${http3_setting} - default value: off, valid values: on, off

    local root_domain=$1
    local http3_setting=$2

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then # Zone found

        cache_ttl_result="$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/http3" \
            -H "X-Auth-Email: ${dns_cloudflare_email}" \
            -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
            -H "Content-Type: application/json" \
            --data "{\"value\":\"${http3_setting}\"}")"

        if [[ ${cache_ttl_result} == *"\"success\":false"* || ${cache_ttl_result} == "" ]]; then
            message="Error trying to set http3 for ${root_domain}. Results:\n ${cache_ttl_result}"
            log_event "error" "${message}"
            return 1

        else
            message="HTTP3 setting for ${root_domain} is ${cache_ttl_result}"
            log_event "info" "${message}"

        fi

    else

        # Zone not found
        return 1

    fi

}

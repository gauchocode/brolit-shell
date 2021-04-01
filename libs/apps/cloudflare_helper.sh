#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.21
################################################################################
#
#   Ref: https://api.cloudflare.com/
#
################################################################################

function _cloudflare_get_zone_id() {

    # $1 = ${zone_name}

    local zone_name=$1

    local zone_id
    
    #zone_name="${root_domain}"

    # We need to do this, because certbot use this file with this vars
    # And this script need this others var names 
    auth_email="${dns_cloudflare_email}"
    auth_key="${dns_cloudflare_api_key}"

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config

    fi

    # Log
    display --indent 6 --text "- Accessing Cloudflare API" --result "DONE" --color GREEN
    log_event "info" "Accessing Cloudflare API ..."
    log_event "info" "Getting Zone & Record ID's for zone: ${zone_name}"
    log_event "debug" "Running: curl -s -X GET \"https://api.cloudflare.com/client/v4/zones?name=${zone_name}\" -H \"X-Auth-Email: ${auth_email}\" -H \"X-Auth-Key: ${auth_key}\" -H \"Content-Type: application/json\" | grep -Po '(?<=\"id\":\")[^\"]*' | head -1"

    # Get Zone ID
    zone_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" \
                -H "X-Auth-Email: ${auth_email}" \
                -H "X-Auth-Key: ${auth_key}" \
                -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        
        log_event "info" "Zone ID found: ${zone_id}"

        # Return
        echo "${zone_id}"
    
    else

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

function cloudflare_ask_root_domain() {

    # $1 = ${suggested_root_domain}

    local suggested_root_domain=$1
    local root_domain

    root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 "${suggested_root_domain}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${root_domain}"

    fi

}

function cloudflare_get_zone_info() {

    log_event "info" "Getting zone information for: ${zone_name}"

    zone_info="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}&status=active" \
                    -H "X-Auth-Email: ${auth_email}" \
                    -H "X-Auth-Key: ${auth_key}" \
                    -H "Content-Type: application/json" )"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        
        log_event "debug" "Zone information: ${zone_info}"

        # Return
        echo "${zone_id}"
    
    else

        return 1

    fi

}

function cloudflare_domain_exists () {

    # $1 = ${root_domain}

    local root_domain=$1

    local zone_name 
    local zone_id

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    if [[ ${zone_id} == *"\"success\":false"* || ${zone_id} == "" ]]; then
        message="Error: the zone is not configured on the Cloudflare account."
        display --indent 6 --text "- Getting Zone ID for ${root_domain}" --result "FAIL" --color RED
        display --indent 8 --text "${message}"
        
        # Return
        return 1

    else
        log_event "info" "Zone ID found: ${zone_id}"
        display --indent 6 --text "- Getting Zone ID for ${root_domain}" --result "DONE" --color GREEN
        display --indent 8 --text "Zone ID found: ${zone_id}"

        # Return
        return 0
    fi

}

function cloudflare_clear_cache() {

    # $1 = ${root_domain}

    local root_domain=$1

    local zone_name 
    local purge_cache

    zone_name="${root_domain}"

    #We need to do this, because certbot use this file with this vars
    #And this script need this others var names 
    auth_email="${dns_cloudflare_email}"
    auth_key="${dns_cloudflare_api_key}"

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config

    fi

    log_event "info" "Getting Zone ID for domain: ${root_domain}"
    #display --indent 6 --text "- Getting Zone ID"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    log_event "info" "Zone ID found: ${zone_id}"
    #clear_last_line
    display --indent 6 --text "- Getting Zone ID for ${root_domain}" --result "DONE" --color GREEN
    display --indent 8 --text "Zone ID found: ${zone_id}"

    purge_cache="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
    -H "X-Auth-Email: ${auth_email}" \
    -H "X-Auth-Key: ${auth_key}" \
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

        dev_mode_result=$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/development_mode" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" \
        --data "{\"value\":\"${dev_mode}\"}" )

        if [[ ${dev_mode_result} == *"\"success\":false"* || ${dev_mode_result} == "" ]]; then
            message="Error trying to change development mode for ${root_domain}. Results:\n ${dev_mode_result}"
            log_event "error" "${message}"
            display --indent 2 --text "- Enabling development mode" --result "FAIL" --color RED
            return 1

        else
            message="Development mode for ${root_domain} is ${dev_mode}"
            log_event "info" "${message}"
            display --indent 2 --text "- Enabling development mode" --result "DONE" --color GREEN

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
                        -H "X-Auth-Email: ${auth_email}" \
                        -H "X-Auth-Key: ${auth_key}" \
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

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "Setting SSL Mode for: ${zone_name}"
        display --indent 6 --text "- Setting SSL Mode for: ${zone_name}"

        ssl_mode_result=$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
                            -H "X-Auth-Email: ${auth_email}" \
                            -H "X-Auth-Key: ${auth_key}" \
                            -H "Content-Type: application/json" \
                            --data "{\"value\":\"${ssl_mode}\"}")

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

function cloudflare_change_a_record () {

    # $1 = ${root_domain}
    # $2 = ${domain}
    # $3 = ${proxy_status} true/false

    local root_domain=$1
    local domain=$2
    local proxy_status=$3

    local ttl
    local record_type
    local cur_ip
    local zone_id
    local record_id

    # Cloudflare API to change DNS records

    record_name=${domain}

    #TODO: in the future we must rewrite the vars and remove this ugly replace
    record_type="A"
    ttl=1 #1 for Auto

    if [[ -z "${proxy_status}" || ${proxy_status} == "" || ${proxy_status} == "false" ]]; then

        # Default value
        proxy_status=false #need to be a bool, not a string

    else

        proxy_status=true #need to be a bool, not a string

    fi

    cur_ip="${SERVER_IP}"

    zone_id=$(_cloudflare_get_zone_id "${root_domain}")
    
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

    if [[ -z "${record_id}" || ${record_id} == "" ]]; then

        log_event "debug" "ZONE_ID found: ${zone_id}"
        log_event "debug" "RECORD_ID not found: Trying to add the subdomain ..."
        display --indent 6 --text "- Adding the subdomain: ${record_name}"

        update="$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"\

    else

        log_event "debug" "ZONE_ID found: ${zone_id}"
        log_event "debug" "RECORD_ID found: ${record_id}"
        display --indent 6 --text "- Changing ${record_name} IP ..."

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" )"
        
        update="$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":${proxy_status}}")"\

    fi

    # Remove Cloudflare API garbage output
    _cloudflare_clear_garbage_output

    if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then
        message="API UPDATE FAILED. RESULTS:\n${update}"
        log_event "error" "${message}"
        display --indent 6 --text "- Updating subdomain on Cloudflare" --result "FAIL" --color RED
        display --indent 8 --text "${message}" --tcolor RED
        
        return 1

    else
        message="IP changed to: ${SERVER_IP}"
        log_event "info" "${message}"
        display --indent 6 --text "- Updating subdomain on Cloudflare" --result "DONE" --color GREEN
        display --indent 8 --text "IP: ${SERVER_IP}" --tcolor GREEN

    fi


}

function cloudflare_delete_a_record () {

    # $1 = ${root_domain}
    # $2 = ${domain}

    local root_domain=$1
    local domain=$2

    # Cloudflare API to change DNS records
    log_event "info" "Accessing to Cloudflare API to change record ${domain}"

    record_name="${domain}"

    #TODO: in the future we must rewrite the vars and remove this ugly replace
    record_type="A"
    ttl=1 #1 for Auto

    #ip_file="ip.txt"
    #id_file="cloudflare.ids"

    # SCRIPT START
    log_event "info" "Cloudflare Script Initiated"

    cur_ip=${SERVER_IP}

    # RETRIEVE/ SAVE zone_id AND record_id
    zone_id=$(_cloudflare_get_zone_id "${root_domain}")

    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

    log_event "info" "RECORD_ID: ${record_id}"

    #echo "${zone_id}" > "${id_file}"
    #echo "${record_id}" >> "${id_file}"

    if [[ -z "${record_id}" || ${record_id} == "" ]]; then

        log_event "info" "Record not found on Cloudflare"
        display --indent 6 --text "- Record not found on Cloudflare" --result "FAIL" --color RED

        return 1

    else
     
        log_event "info" "RECORD_ID found: ${record_id}"
        log_event "info" "Trying to delete the record ..."

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json")"
        
    fi

    if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then

        message="A record delete failed. Results:\n${delete}"
        log_event "error" "${message}"
        display --indent 6 --text "- Deleting A record from Cloudflare" --result "FAIL" --color RED
        display --indent 8 --text "${message}" --tcolor RED

        return 1

    else
        message="A record deleted: ${record_name}"
        log_event "info" "${message}"
        display --indent 6 --text "- Deleting A record from Cloudflare" --result "DONE" --color GREEN
        display --indent 8 --text "Record deleted: ${record_name}" --tcolor YELLOW

    fi

    #rm "${id_file}"

}
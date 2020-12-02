#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.7
################################################################################
#
#   Ref: https://api.cloudflare.com/
#
################################################################################

cloudflare_ask_root_domain () {

    # $1 = ${suggested_root_domain}

    local suggested_root_domain=$1
    local root_domain

    root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 "${suggested_root_domain}" 3>&1 1>&2 2>&3)
    exitstatus="$?"
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${root_domain}"

    fi

}

cloudflare_domain_exists () {

# $1 = ${root_domain}

    local root_domain=$1

    local zone_name 
    local zone_id

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

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    if [[ ${zone_id} == *"\"success\":false"* || ${zone_id} == "" ]]; then
        message="Error: the zone is not configured on the Cloudflare account."
        #log_event "error" "${message}"
        display --indent 6 --text "- Getting Zone ID for ${root_domain}" --result "FAIL" --color RED
        display --indent 8 --text "${message}"
        # Return
        return 1

    else
        log_event "info" "Zone ID found: ${zone_id}"
        #clear_last_line
        display --indent 6 --text "- Getting Zone ID for ${root_domain}" --result "DONE" --color GREEN
        display --indent 8 --text "Zone ID found: ${zone_id}"
        # Return
        return 0
    fi

}

cloudflare_clear_cache() {

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
    #display --indent 2 --text "- Getting Zone ID"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    log_event "info" "Zone ID found: ${zone_id}"
    #clear_last_line
    display --indent 2 --text "- Getting Zone ID for ${root_domain}" --result "DONE" --color GREEN
    display --indent 4 --text "Zone ID found: ${zone_id}"

    purge_cache="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
    -H "X-Auth-Email: ${auth_email}" \
    -H "X-Auth-Key: ${auth_key}" \
    -H "Content-Type:application/json" \
    --data '{"purge_everything":true}' >/dev/null)"

    #if [[ ${purge_cache} == *"\"success\":false"* ]]; then
    if [[ ${purge_cache} == *"\"success\":false"* || ${purge_cache} == "" ]]; then
        message="Error trying to clear Cloudflare cache. Results:\n${update}"
        log_event "error" "${message}"
        display --indent 2 --text "- Clearing Cloudflare cache" --result "FAIL" --color RED
        return 1

    else
        message="Cache cleared for domain: ${root_domain}"
        log_event "success" "${message}"
        display --indent 2 --text "- Clearing Cloudflare cache" --result "DONE" --color GREEN
    fi

}

cloudflare_development_mode() {

    # $1 = ${root_domain}
    # $2 = ${dev_mode}

    local root_domain=$1
    local dev_mode=$2

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

    log_event "info" "Getting Zone & Record ID's for domain: ${root_domain}" "false"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    log_event "info" "Zone ID found: ${zone_id}" "false"

    dev_mode_result=$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/development_mode" \
     -H "X-Auth-Email: ${auth_email}" \
     -H "X-Auth-Key: ${auth_key}" \
     -H "Content-Type: application/json" \
     --data "{\"value\":\"${dev_mode}\"}" >/dev/null)

    #if [[ ${dev_mode_result} == *"\"success\":false"* ]]; then
    if [[ ${dev_mode_result} == *"\"success\":false"* || ${dev_mode_result} == "" ]]; then
        message="Error trying to change development mode for ${root_domain}. Results:\n ${dev_mode_result}"
        log_event "error" "${message}"
        display --indent 2 --text "- Enabling development mode" --result "FAIL" --color RED
        return 1

    else
        message="Development mode for ${root_domain} is ${dev_mode}"
        log_event "success" "${message}"
        display --indent 2 --text "- Enabling development mode" --result "DONE" --color GREEN

    fi

}

cloudflare_ssl_mode() {

    # $1 = ${root_domain}
    # $2 = ${ssl_mode} default value: off, valid values: off, flexible, full, strict

    local root_domain=$1
    local ssl_mode=$2

    local zone_name
    local ssl_mode_result

    zone_name="${root_domain}"

    #We need to do this, because certbot use this file with this vars
    #And this script need this others var names 
    auth_email="${dns_cloudflare_email}"
    auth_key="${dns_cloudflare_api_key}"

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config

    fi

    log_event "info" "Getting Zone & Record ID's for domain: ${root_domain}"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    log_event "info" "Zone ID found: ${zone_id}"

    ssl_mode_result=$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
     -H "X-Auth-Email: ${auth_email}" \
     -H "X-Auth-Key: ${auth_key}" \
     -H "Content-Type: application/json" \
     --data "{\"value\":\"${ssl_mode}\"}" >/dev/null)

    #if [[ ${ssl_mode_result} == *"\"success\":false"* ]]; then
    if [[ ${ssl_mode_result} == *"\"success\":false"* || ${ssl_mode_result} == "" ]]; then
        message="Error trying to change ssl mode for ${root_domain}. Results:\n ${ssl_mode_result}"
        log_event "error" "${message}"
        return 1

    else
        message="SSL mode for ${root_domain} is ${ssl_mode}"
        log_event "success" "${message}"

    fi

}

cloudflare_change_a_record () {

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
    log_event "info" "Accessing Cloudflare API and change record ${domain}" "false"
    display --indent 2 --text "- Accessing Cloudflare API" --result "DONE" --color GREEN

    zone_name=${root_domain}
    record_name=${domain}

    #TODO: in the future we must rewrite the vars and remove this ugly replace

    #We need to do this, because certbot use this file with this vars
    #And this script need this others var names 
    auth_email=${dns_cloudflare_email}
    auth_key=${dns_cloudflare_api_key}

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config
    fi

    record_type="A"
    ttl=1 #1 for Auto

    if [[ -z "${proxy_status}" || ${proxy_status} == "" ]]; then
        proxy_status="false"
    fi

    cur_ip="${SERVER_IP}"

    log_event "info" "Getting Zone & Record ID's ..." "false"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

    if [[ -z "${record_id}" || ${record_id} == "" ]]; then

        log_event "info" "ZONE_ID found: ${zone_id}" "false"
        log_event "info" "RECORD_ID not found: Trying to add the subdomain ..." "false"
        display --indent 2 --text "- Adding the subdomain: ${record_name}"

        #log_event "info" "curl -X POST \"https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records\" \
        #-H \"X-Auth-Email: ${auth_email}\" \
        #-H \"X-Auth-Key: ${auth_key}\" \
        #-H \"Content-Type: application/json\" \
        #--data \"{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":\"${proxy_status}\"}" "false"

        update="$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":\"${proxy_status}\"}" >/dev/null)"

    else

        log_event "info" "ZONE_ID found: ${zone_id}"
        log_event "info" "RECORD_ID found: ${record_id}"
        display --indent 2 --text "- Changing ${record_name} IP ..."

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" >/dev/null)"
        
        update="$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":\"${proxy_status}\"}" >/dev/null)"

    fi

    #fi

    #if [[ ${update} == *"\"success\":false"* ]]; then
    if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then
        message="API UPDATE FAILED. RESULTS:\n${update}"
        log_event "error" "${message}"
        
        return 1

    else
        message="IP changed to: ${SERVER_IP}"
        log_event "success" "${message}" "false"
        display --indent 2 --text "- Updating subdomain on Cloudflare" --result "DONE" --color GREEN
        display --indent 4 --text "IP: ${SERVER_IP}" --tcolor GREEN

    fi


}

cloudflare_delete_a_record () {

    # $1 = ${root_domain}
    # $2 = ${domain}

    local root_domain=$1
    local domain=$2

    # Cloudflare API to change DNS records
    log_event "info" "Accessing to Cloudflare API to change record ${domain}" "false"

    zone_name="${root_domain}"
    record_name="${domain}"

    #TODO: in the future we must rewrite the vars and remove this ugly replace

    #We need to do this, because certbot use this file with this vars
    #And this script need this others var names 
    auth_email="${dns_cloudflare_email}"
    auth_key="${dns_cloudflare_api_key}"

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config

    fi

    record_type="A"
    ttl=1 #1 for Auto
    proxied_value="false"

    #ip_file="ip.txt"
    id_file="cloudflare.ids"

    # SCRIPT START
    log_event "info" "Cloudflare Script Initiated"

    cur_ip=${SERVER_IP}

    # RETRIEVE/ SAVE zone_id AND record_id
    log_event "info" "Getting Zone & Record ID's ..."
    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

    log_event "info" "ZONE_ID: ${zone_id}"
    log_event "info" "RECORD_ID: ${record_id}"

    echo "${zone_id}" > "${id_file}"
    echo "${record_id}" >> "${id_file}"

    if [[ -z "${record_id}" || ${record_id} == "" ]]; then

        log_event "info" "Record not found on Cloudflare"
        display --indent 2 --text "- Record not found on Cloudflare" --result "FAIL" --color RED

        return 1

    else
     
        log_event "info" "RECORD_ID found: ${record_id}"
        log_event "info" "Trying to delete the record ..."

        delete="$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" >/dev/null)"
        
    fi

    #if [[ ${delete} == *"\"success\":false"* ]]; then
    if [[ ${update} == *"\"success\":false"* || ${update} == "" ]]; then

        message="A record delete failed. Results:\n${delete}"
        log_event "error" "${message}"
        display --indent 2 --text "- Deleting A record from Cloudflare" --result "FAIL" --color RED

        return 1

    else
        message="A record deleted: ${record_name}"
        log_event "success" "${message}"
        display --indent 2 --text "- Deleting A record from Cloudflare" --result "DONE" --color GREEN
        display --indent 4 --text "Record deleted: ${record_name}" --tcolor YELLOW

    fi

    rm "${id_file}"

}
#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################
#
#   Ref: https://api.cloudflare.com/
#
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

cloudflare_ask_root_domain () {

    # $1 = ${suggested_root_domain}

    local suggested_root_domain=$1
    local root_domain

    root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 "${suggested_root_domain}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        echo "${root_domain}"

    fi

}

cloudflare_clear_cache() {

    # $1 = ${root_domain}

    local root_domain=$1

    local zone_name purge_cache

    zone_name=${root_domain}

    #We need to do this, because certbot use this file with this vars
    #And this script need this others var names 
    auth_email=${dns_cloudflare_email}
    auth_key=${dns_cloudflare_api_key}

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config

    fi

    log_event "info" "Getting Zone & Record ID's for domain: ${root_domain}" "true"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    log_event "info" "Zone ID found: ${zone_id}" "true"

    purge_cache=$(curl -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/purge_cache" \
    -H "X-Auth-Email: ${auth_email}" \
    -H "X-Auth-Key: ${auth_key}" \
    -H "Content-Type:application/json" \
    --data '{"purge_everything":true}')

    if [[ ${purge_cache} == *"\"success\":false"* ]]; then
        message="Error trying to clear Cloudflare cache. Results:\n${update}"
        log_event "error" "${message}" "true"
        return 1

    else
        message="Cache cleared for domain: ${root_domain}"
        log_event "success" "${message}" "true"

    fi

}

cloudflare_development_mode() {

    # $1 = ${root_domain}
    # $2 = ${dev_mode}

    local root_domain=$1
    local dev_mode=$2

    local zone_name purge_cache

    zone_name=${root_domain}

    #We need to do this, because certbot use this file with this vars
    #And this script need this others var names 
    auth_email=${dns_cloudflare_email}
    auth_key=${dns_cloudflare_api_key}

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config

    fi

    log_event "info" "Getting Zone & Record ID's for domain: ${root_domain}" "true"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    log_event "info" "Zone ID found: ${zone_id}" "true"

    dev_mode_result=$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/development_mode" \
     -H "X-Auth-Email: ${auth_email}" \
     -H "X-Auth-Key: ${auth_key}" \
     -H "Content-Type: application/json" \
     --data "{\"value\":\"${dev_mode}\"}")

    if [[ ${dev_mode_result} == *"\"success\":false"* ]]; then
        message="Error trying to change development mode for ${root_domain}. Results:\n ${dev_mode_result}"
        log_event "error" "${message}" "true"
        return 1

    else
        message="Development mode for ${root_domain} is ${dev_mode}"
        log_event "success" "${message}" "true"

    fi

}

cloudflare_ssl_mode() {

    # $1 = ${root_domain}
    # $2 = ${ssl_mode} default value: off, valid values: off, flexible, full, strict

    local root_domain=$1
    local ssl_mode=$2

    local zone_name ssl_mode_result

    zone_name=${root_domain}

    #We need to do this, because certbot use this file with this vars
    #And this script need this others var names 
    auth_email=${dns_cloudflare_email}
    auth_key=${dns_cloudflare_api_key}

    # Checking cloudflare credentials file
    if [[ -z "${auth_email}" ]]; then
        generate_cloudflare_config

    fi

    log_event "info" "Getting Zone & Record ID's for domain: ${root_domain}" "true"

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: ${auth_key}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )

    log_event "info" "Zone ID found: ${zone_id}" "true"

    ssl_mode_result=$(curl -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
     -H "X-Auth-Email: ${auth_email}" \
     -H "X-Auth-Key: ${auth_key}" \
     -H "Content-Type: application/json" \
     --data "{\"value\":\"${ssl_mode}\"}")

    if [[ $ssl_mode_result == *"\"success\":false"* ]]; then
        message="Error trying to change ssl mode for ${root_domain}. Results:\n ${ssl_mode_result}"
        log_event "error" "${message}" "true"
        return 1

    else
        message="SSL mode for ${root_domain} is ${ssl_mode}"
        log_event "success" "${message}" "true"

    fi

}

cloudflare_change_a_record () {

    # $1 = ${root_domain}
    # $2 = ${domain}
    # $3 = ${proxy_status} true/false

    local root_domain=$1
    local domain=$2
    local proxy_status=$3

    # Cloudflare API to change DNS records
    log_event "info" "Trying to access Cloudflare API and change record ${domain}" "true"

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

    #ip_file="ip.txt"
    id_file="cloudflare.ids"

    # SCRIPT START
    log_event "info" "Cloudflare Script Initiated" "true"

    # FOR IPV6 EDIT THE LINK TO THIS -> (https://api6.ipify.org)
    #cur_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
    cur_ip=${SERVER_IP}

    # RETRIEVE/ SAVE zone_id AND record_id
    log_event "info" "CHECKING FOR ZONE & RECORD ID's ..." "true"
    if [[ -f ${id_file} ]] && [[ $(wc -l ${id_file} | awk '{print $1}') == 2 ]]; then

        zone_id=$(head -1 ${id_file})
        record_id=$(tail -1 ${id_file})

        log_event "info" "ZONE_ID found: ${zone_id}" "true"
        log_event "info" "RECORD_ID found: ${record_id}" "true"

    else

        log_event "info" "Getting Zone & Record ID's ..." "true"

        zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
        record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

        echo "${zone_id}" > ${id_file}
        echo "${record_id}" >> ${id_file}

        log_event "info" "ZONE_ID found: ${zone_id}" "true"
        log_event "info" "RECORD_ID found: ${record_id}" "true"

        if [[ -z "${record_id}" || ${record_id} == "" ]]; then

            log_event "info" "RECORD_ID not found: Trying to add the entry ..." "true"

            update=$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${auth_email}" \
            -H "X-Auth-Key: ${auth_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":$proxy_status}")

        else

            log_event "info" "RECORD_ID found: ${record_id}" "true"
            log_event "info" "Trying to change the domain IP ..." "true"

            delete=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
            -H "X-Auth-Email: ${auth_email}" \
            -H "X-Auth-Key: ${auth_key}" \
            -H "Content-Type: application/json")
            
            update=$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${auth_email}" \
            -H "X-Auth-Key: ${auth_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${cur_ip}\",\"ttl\":${ttl},\"priority\":10,\"proxied\":$proxy_status}")

            #update=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
            #-H "X-Auth-Email: $auth_email" \
            #-H "X-Auth-Key: $auth_key" \
            #-H "Content-Type: application/json" \
            #--data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"ttl\":$ttl,\"priority\":10,\"proxied\":$proxied_value}")
            #--data "{\"id\":\"$zone_id\",\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"ttl\":$ttl,\"proxied\":$proxied_value}")

        fi

    fi

    if [[ ${update} == *"\"success\":false"* ]]; then
        message=" > API UPDATE FAILED. RESULTS:\n${update}"
        log_event "error" "${message}" "true"
        return 1

    else
        message=" > IP changed to: ${SERVER_IP}."
        #echo "$SERVER_IP" > $ip_file
        log_event "success" "${message}" "true"

    fi

    rm ${id_file}

    return 0

}

cloudflare_delete_a_record () {

    # $1 = ${root_domain}
    # $2 = ${domain}

    local root_domain=$1
    local domain=$2

    # Cloudflare API to change DNS records
    log_event "info" "Trying to access Cloudflare API and change record ${domain}" "true"

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
    proxied_value="false"

    #ip_file="ip.txt"
    id_file="cloudflare.ids"

    # SCRIPT START
    log_event "info" "Cloudflare Script Initiated" "true"

    cur_ip=${SERVER_IP}

    # RETRIEVE/ SAVE zone_id AND record_id
    log_event "info" "Getting Zone & Record ID's ..." "true"
    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${auth_email}" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

    log_event "info" "ZONE_ID: ${zone_id}" "true"
    log_event "info" "RECORD_ID: ${record_id}" "true"

    echo "${zone_id}" > ${id_file}
    echo "${record_id}" >> ${id_file}

    if [[ -z "${record_id}" || ${record_id} == "" ]]; then

        log_event "info" "RECORD_ID not found ..." "true"

    else
     
        log_event "info" "RECORD_ID found: ${record_id}" "true"
        log_event "info" "Trying to delete the record ..." "true"

        delete=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json")
        
    fi

    if [[ ${delete} == *"\"success\":false"* ]]; then
        message="API UPDATE FAILED. RESULTS:\n${delete}"
        log_event "error" "${message}" "true"
        return 1

    else
        message="IP changed to: ${SERVER_IP}."
        #echo "$SERVER_IP" > $ip_file
        log_event "success" "${message}" "true"

    fi

    rm ${id_file}
    #rm $ip_file

}
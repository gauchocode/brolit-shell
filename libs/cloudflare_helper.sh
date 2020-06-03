#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc04
################################################################################

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

cloudflare_change_a_record () {

    # $1 = ${root_domain}
    # $2 = ${domain}

    local root_domain=$1
    local domain=$2

    # Cloudflare API to change DNS records
    echo "Trying to access Cloudflare API and change record ${domain} ..." >>$LOG
    echo -e ${CYAN}"Trying to access Cloudflare API and change record ${domain} ..."${ENDCOLOR}

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

    ip=$(curl -s http://ipv4.icanhazip.com)
    #ip=$(dig +short myip.opendns.com @resolver1.opendns.com) 2>/dev/null

    #ip_file="ip.txt"
    id_file="cloudflare.ids"

    # SCRIPT START
    echo " > Cloudflare Script Initiated ...">>$LOG
    echo -e ${GREN}" > Cloudflare Script Initiated ..."${ENDCOLOR}

    # TODO: uncomment to check if server IP has change (extract to another function)
    
    #echo " > GETTING SAVED IP ...">>$LOG
    #echo -e ${YELLOW}" > GETTING SAVED IP ..."${ENDCOLOR}

    #if [[ -f $ip_file ]];
    #then
    #    sav_ip=$(cat $ip_file)
    #    echo " > SAVED IP: $sav_ip ...">>$LOG
    #    echo -e ${YELLOW}" > SAVED IP: $sav_ip ..."${ENDCOLOR}
    #else
    #    echo " > SAVED IP: NONE ...">>$LOG
    #    echo -e ${YELLOW}" > SAVED IP: NONE ..."${ENDCOLOR}
    #fi

    #echo -e ${YELLOW}" > CHECKING FOR NEW IP ..."${ENDCOLOR}

    # FOR IPV6 EDIT THE LINK TO THIS -> (https://api6.ipify.org)
    #cur_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
    cur_ip=$ip

    #cur_ip_avail=$?
    #pre_ip=$sav_ip

    #if [[ $cur_ip_avail == 0 ]];
    #then
    #    if [[ $cur_ip == $pre_ip ]];
    #    then
    #        echo " > NO NEW IP DETECTED!"
    #        echo -e " > EXITING...\n"
    #        exit 0
    #    else
    #        echo -e " > NEW IP DETECTED: ${cur_ip} \n"
    #    fi
    #else
    #    echo -e ${B_RED}" > FAILED CHECKING FOR NEW IP!"${ENDCOLOR}
    #    echo -e ${B_RED}" > EXITING ..."${ENDCOLOR}
    #    exit 1
    #fi

    # RETRIEVE/ SAVE zone_id AND record_id
    echo -e ${CYAN}" > CHECKING FOR ZONE & RECORD ID's..."${ENDCOLOR}
    #if [ -f $id_file ] && [ $(wc -l $id_file | cut -d " " -f 1) == 2 ]; then
    if [[ -f $id_file ]] && [[ $(wc -l $id_file | awk '{print $1}') == 2 ]]; then

        zone_id=$(head -1 $id_file)
        record_id=$(tail -1 $id_file)
        echo -e ${GREEN} " > ZONE_ID FOUND: ${zone_id} \n"${ENDCOLOR}
        echo -e ${GREEN} " > RECORD_ID FOUND: ${record_id} \n"${ENDCOLOR}

    else

        echo -e ${CYAN}" > GETTING ZONE & RECORD ID'S..."${ENDCOLOR}

        zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
        record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

        echo "$zone_id" > $id_file
        echo "$record_id" >> $id_file

        echo -e ${CYAN}" > ZONE_ID: ${zone_id} \n"${ENDCOLOR}
        echo -e ${CYAN}" > RECORD_ID: ${zone_id} \n"${ENDCOLOR}

        if [[ -z "${record_id}" || ${record_id} == "" ]]; then

            echo -e " > RECORD_ID not found: Trying to add the entry... \n"

            update=$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${auth_email}" \
            -H "X-Auth-Key: ${auth_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"ttl\":$ttl,\"priority\":10,\"proxied\":$proxied_value}")

        else

            echo -e ${CYAN} " > RECORD_ID found: ${record_id} \n"${ENDCOLOR}
            echo -e ${CYAN} " > Trying to change the domain IP... \n"${ENDCOLOR}

            delete=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
            -H "X-Auth-Email: $auth_email" \
            -H "X-Auth-Key: $auth_key" \
            -H "Content-Type: application/json")
            
            update=$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            -H "X-Auth-Email: ${auth_email}" \
            -H "X-Auth-Key: ${auth_key}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"ttl\":$ttl,\"priority\":10,\"proxied\":$proxied_value}")

            #update=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
            #-H "X-Auth-Email: $auth_email" \
            #-H "X-Auth-Key: $auth_key" \
            #-H "Content-Type: application/json" \
            #--data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"ttl\":$ttl,\"priority\":10,\"proxied\":$proxied_value}")
            #--data "{\"id\":\"$zone_id\",\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"ttl\":$ttl,\"proxied\":$proxied_value}")

        fi

    fi

    if [[ $update == *"\"success\":false"* ]]; then
        message="API UPDATE FAILED. RESULTS:\n$update"
        echo "$message">>$LOG
        echo -e ${CYAN}"$message"${ENDCOLOR}
        exit 1

    else
        message="IP changed to: $ip."
        #echo "$ip" > $ip_file
        echo "$message">>$LOG
        echo -e ${CYAN}"$message"${ENDCOLOR}

    fi

    rm $id_file
    #rm $ip_file

}

cloudflare_delete_a_record () {

    # $1 = ${root_domain}
    # $2 = ${domain}

    local root_domain=$1
    local domain=$2

    # Cloudflare API to change DNS records
    echo "Trying to access Cloudflare API and change record ${domain} ..." >>$LOG
    echo -e ${CYAN}"Trying to access Cloudflare API and change record ${domain} ..."${ENDCOLOR}

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

    ip=$(curl -s http://ipv4.icanhazip.com)
    #ip=$(dig +short myip.opendns.com @resolver1.opendns.com) 2>/dev/null

    #ip_file="ip.txt"
    id_file="cloudflare.ids"

    # SCRIPT START
    echo " > Cloudflare Script Initiated ...">>$LOG
    echo -e ${GREN}" > Cloudflare Script Initiated ..."${ENDCOLOR}

    cur_ip=$ip

    # RETRIEVE/ SAVE zone_id AND record_id
    echo -e ${CYAN}" > GETTING ZONE & RECORD ID'S..."${ENDCOLOR}

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

    echo "$zone_id" > $id_file
    echo "$record_id" >> $id_file

    echo -e ${CYAN}" > ZONE_ID: ${zone_id} \n"${ENDCOLOR}
    echo -e ${CYAN}" > RECORD_ID: ${zone_id} \n"${ENDCOLOR}

    if [[ -z "${record_id}" || ${record_id} == "" ]]; then

        echo -e " > RECORD_ID not found ... \n"

    else

        echo -e ${CYAN} " > RECORD_ID found: ${record_id} \n"${ENDCOLOR}
        echo -e ${CYAN} " > Trying to delete the record ... \n"${ENDCOLOR}

        delete=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "X-Auth-Email: $auth_email" \
        -H "X-Auth-Key: $auth_key" \
        -H "Content-Type: application/json")
        
    fi

    if [[ $delete == *"\"success\":false"* ]]; then
        message="API UPDATE FAILED. RESULTS:\n$delete"
        echo "$message">>$LOG
        echo -e ${CYAN}"$message"${ENDCOLOR}
        exit 1

    else
        message="IP changed to: $ip."
        #echo "$ip" > $ip_file
        echo "$message">>$LOG
        echo -e ${CYAN}"$message"${ENDCOLOR}

    fi

    rm $id_file
    #rm $ip_file

}


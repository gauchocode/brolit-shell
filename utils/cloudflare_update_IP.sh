#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
################################################################################

# TODO: agregar opción de habilitar cloudflare-proxy
# https://github.com/HillLiu/cloudflare-bash-util

### Checking Script Execution
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi

################################################################################

source ${SFOLDER}/libs/commons.sh

################################################################################

# Checking cloudflare credentials file
if [[ -z "${auth_email}" ]]; then
  generate_cloudflare_config

fi

record_type="A"
proxied_value="false"                                                           # Do you want to proxy your site through cloudflare? E.g., Orange Cloud (true), Grey Cloud (false)

ip=$(curl -s http://ipv4.icanhazip.com)

ip_file="ip.txt"
id_file="cloudflare.ids"

# SCRIPT START
echo " > Cloudflare Script Initiated ...">>$LOG
echo -e ${GREN}" > Cloudflare Script Initiated ..."${ENDCOLOR}

echo " > GETTING SAVED IP ...">>$LOG
echo -e ${YELLOW}" > GETTING SAVED IP ..."${ENDCOLOR}

if [[ -f $ip_file ]];
then
    sav_ip=$(cat $ip_file)
    echo " > SAVED IP: $sav_ip ...">>$LOG
    echo -e ${YELLOW}" > SAVED IP: $sav_ip ..."${ENDCOLOR}
else
    echo " > SAVED IP: NONE ...">>$LOG
    echo -e ${YELLOW}" > SAVED IP: NONE ..."${ENDCOLOR}
fi

echo -e ${YELLOW}" > CHECKING FOR NEW IP ..."${ENDCOLOR}

# FOR IPV6 EDIT THE LINK TO THIS -> (https://api6.ipify.org)
cur_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
cur_ip_avail=$?
pre_ip=$sav_ip

if [[ $cur_ip_avail == 0 ]];
then
    if [[ $cur_ip == $pre_ip ]];
    then
        echo " > NO NEW IP DETECTED!"
        echo -e " > EXITING...\n"
        exit 0
    else
        echo -e " > NEW IP DETECTED: ${cur_ip} \n"
    fi
else
    echo -e ${RED}" > FAILED CHECKING FOR NEW IP!"${ENDCOLOR}
    echo -e ${RED}" > EXITING ..."${ENDCOLOR}
    exit 1
fi

# RETRIEVE/ SAVE zone_id AND record_id
echo -e ${YELLOW}" > CHECKING FOR ZONE & RECORD ID's..."${ENDCOLOR}
#if [ -f $id_file ] && [ $(wc -l $id_file | cut -d " " -f 1) == 2 ]; then
if [[ -f $id_file ]] && [[ $(wc -l $id_file | awk '{print $1}') == 2 ]]; then

    zone_id=$(head -1 $id_file)
    record_id=$(tail -1 $id_file)
    echo -e " > ZONE_ID FOUND: ${zone_id} \n"
    echo -e " > RECORD_ID FOUND: ${record_id} \n"

else

    echo -e ${YELLOW}" > ZONE & RECORD ID'S NOT FOUND! GETTING ZONE & RECORD ID'S..."${ENDCOLOR}

    zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*')

    echo "$zone_id" > $id_file
    echo "$record_id" >> $id_file
    echo -e " > ZONE_ID: ${zone_id} \n"

    if [[ -z "${record_id}" || ${record_id} == "" ]]; then

      echo -e " > RECORD_ID not found: Trying to add the entry... \n"

      update=$(curl -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
      -H "X-Auth-Email: ${auth_email}" \
      -H "X-Auth-Key: ${auth_key}" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"ttl\":120,\"priority\":10,\"proxied\":$proxied_value}")

    else

      echo -e " > RECORD_ID found: ${record_id} \n"
      echo -e " > Trying to change the domain IP... \n"

      update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" -H "X-Auth-Email: $auth_email" -H "X-Auth-Key: $auth_key" -H "Content-Type: application/json" --data "{\"id\":\"$zone_id\",\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$cur_ip\",\"proxied\":$proxied_value}")

    fi

fi

if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. RESULTS:\n$update"
    echo "$message">>$LOG
    echo -e "$message"
    exit 1

else
    message="IP changed to: $ip"
    echo "$ip" > $ip_file
    echo "$message">>$LOG
    echo "$message"

fi

rm $id_file
rm $ip_file

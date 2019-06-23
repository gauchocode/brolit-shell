#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.5
#############################################################################

### Setup Colours ###
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'

MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### Checking some things... ###
if [ $USER != root ]; then
  echo -e ${RED}" > Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi

if [[ -z "${MUSER}" ]]; then
  MUSER=$(whiptail --title "MySQL user with full Privileges" --inputbox "Please enter a MySQL user with full Privileges" 10 60 3>&1 1>&2 2>&3)
fi

if [[ -z "${MPASS}" ]]; then
  MPASS=$(whiptail --title "MySQL user password" --inputbox "Please insert the MySQL user Password" 10 60 3>&1 1>&2 2>&3)
fi

if [[ -z "${DB_PREFIX}" ]]; then
  DB_PREFIX=$(whiptail --title "WordPress DB Prefix" --inputbox "Please insert the WordPress Database Prefix without the '_'" 10 60 3>&1 1>&2 2>&3)
fi

if [[ -z "${TARGET_DB}" ]]; then
  DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"
  # Elijo DB a remplazar las URLs
  CHOSEN_DB=$(whiptail --title "REPLACING URLS ON WP DATABASE" --menu "Chose a Database to work with" 20 78 10 `for x in ${DBS}; do echo "$x [DB]"; done` 3>&1 1>&2 2>&3)
  #exitstatus=$?

else
  CHOSEN_DB=${TARGET_DB};

fi

if [[ -z "${existing_URL}" ]]; then
  existing_URL=$(whiptail --title "URL TO CHANGE" --inputbox "Insert the URL you want to change, including http:// or https://" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?

  if [ ${exitstatus} = 0 ]; then

    # OK
    if [[ -z "${new_URL}" ]]; then
      new_URL=$(whiptail --title "THE NEW URL" --inputbox "Insert the new URL , including http:// or https://" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?

      if [ ${exitstatus} = 0 ]; then
        # OK
        # Backupeamos base actual
        echo -e ${YELLOW}" > Executing mysqldump of ${CHOSEN_DB} before replace urls ..."${ENDCOLOR}
        ${MYSQLDUMP} -u ${MUSER} --password=${MPASS} ${CHOSEN_DB} > ${CHOSEN_DB}_bk_before_replace_urls.sql

        # Queries
        SQL0="USE ${CHOSEN_DB};"
        SQL1="UPDATE ${DB_PREFIX}_options SET option_value = replace(option_value, '${existing_URL}', '${new_URL}') WHERE option_name = 'home' OR option_name = 'siteurl';"
        SQL2="UPDATE ${DB_PREFIX}_posts SET post_content = replace(post_content, '${existing_URL}', '${new_URL}');"
        SQL3="UPDATE ${DB_PREFIX}_postmeta SET meta_value = replace(meta_value,'${existing_URL}','${new_URL}');"
        SQL4="UPDATE ${DB_PREFIX}_usermeta SET meta_value = replace(meta_value, '${existing_URL}','${new_URL}');"
        SQL5="UPDATE ${DB_PREFIX}_links SET link_url = replace(link_url, '${existing_URL}','${new_URL}');"
        SQL6="UPDATE ${DB_PREFIX}_comments SET comment_content = replace(comment_content , '${existing_URL}','${new_URL}');"

        echo -e ${YELLOW}" > Replacing URLs in database ${PROJECT_NAME} ..."${ENDCOLOR}
        ${MYSQL} -u ${MUSER} --password=${MPASS} -e "${SQL0}${SQL1}${SQL2}${SQL3}${SQL4}${SQL5}${SQL6}"

      fi

    fi

  fi

fi

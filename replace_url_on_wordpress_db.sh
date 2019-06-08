#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.5
#############################################################################

### VARS ###
existing_URL=""
new_URL=""

### MySQL CONFIG ###
MUSER="root"              							      #MySQL User
MPASS=""          								            #MySQL User Pass
DB_PREFIX=""

MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### Setup Colours ###
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'

### Checking some things... ###
if [ $USER != root ]; then
  echo -e ${RED}" > Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
if [[ -z "${DB_PREFIX}" || -z "${existing_URL}" || -z "${new_URL}" ]]; then
  echo -e ${RED}" > Error: DB_PREFIX, existing_URL and new_URL vars must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

### Global VARS ###
DBS="$(${MYSQL} -u ${MUSER} -h ${MHOST} -p${MPASS} -Bse 'show databases')"

# Elijo DB a remplazar las URLs
CHOSEN_DB=$(whiptail --title "REPLACING URLS ON WP DATABASE" --menu "Chose a Database to work with" 20 78 10 `for x in ${DBS}; do echo "$x [DB]"; done` 3>&1 1>&2 2>&3)
exitstatus=$?

# Backupeamos base actual
echo " > Executing mysqldump of ${CHOSEN_DB} before replace urls ..."
mysqldump -u ${MUSER} --password=${MPASS} ${CHOSEN_DB} > ${CHOSEN_DB}_bk_before_replace_urls.sql

# Queries
SQL0="USE DATABASE ${CHOSEN_DB};"
SQL1="UPDATE ${DB_PREFIX}_options SET option_value = replace(option_value, '${existing_URL}', '${new_URL}') WHERE option_name = 'home' OR option_name = 'siteurl';"
SQL2="UPDATE ${DB_PREFIX}_posts SET post_content = replace(post_content, '${existing_URL}', '${new_URL}');"
SQL3="UPDATE ${DB_PREFIX}_postmeta SET meta_value = replace(meta_value,'${existing_URL}','${new_URL}');"
SQL4="UPDATE ${DB_PREFIX}_usermeta SET meta_value = replace(meta_value, '${existing_URL}','${new_URL}');"
SQL5="UPDATE ${DB_PREFIX}_links SET link_url = replace(link_url, '${existing_URL}','${new_URL}');"
SQL6="UPDATE ${DB_PREFIX}_comments SET comment_content = replace(comment_content , '${existing_URL}','${new_URL}');"

echo "Replacing URLs in database ${PROJECT_NAME} ..."
mysql -u root --password=${MySQL_ROOT_PASS} -e "${SQL0}${SQL1}${SQL2}${SQL3}${SQL4}${SQL5}${SQL6}"

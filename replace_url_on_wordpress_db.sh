#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.1
#############################################################################

### MySQL CONFIG ###
DB_PREFIX="wp"
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### Global VARS ###
DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"

# Backupeamos base actual
echo "Executing mysqldump (will work if database exists)..."
mysqldump -u root --password=${MySQL_ROOT_PASS} ${CHOSEN_PROJECT} > ${CHOSEN_PROJECT}_bk_before_restore.sql

# Elijo DB a remplazar las URLs
CHOSEN_DB=$(whiptail --title "RESTORE BACKUP" --menu "Chose Database" 20 78 10 `for x in ${DBS}; do echo "$x [DB]"; done` 3>&1 1>&2 2>&3)
exitstatus=$?

# Queries
SQL1="UPDATE ${DB_PREFIX}_options SET option_value = replace(option_value, '${existing_URL}', '${new_URL}') WHERE option_name = 'home' OR option_name = 'siteurl';"
SQL2="UPDATE ${DB_PREFIX}_posts SET post_content = replace(post_content, '${existing_URL}', '${new_URL}');"
SQL3="UPDATE ${DB_PREFIX}_postmeta SET meta_value = replace(meta_value,'${existing_URL}','${new_URL}');"
SQL4="UPDATE ${DB_PREFIX}_usermeta SET meta_value = replace(meta_value, '${existing_URL}','${new_URL}');"
SQL5="UPDATE ${DB_PREFIX}_links SET link_url = replace(link_url, '${existing_URL}','${new_URL}');"
SQL6="UPDATE ${DB_PREFIX}_comments SET comment_content = replace(comment_content , '${existing_URL}','${new_URL}');"

echo "Replacing URLs in database ${PROJECT_NAME}_prod ..."
mysql -u root --password=${MySQL_ROOT_PASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}"

#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.1
#############################################################################
### TODO:
# 1- List backup date to restore (dropbox listing option)
# 2- Download selected backup (file and database)
# 3- Backup actual files on target Directories on new tar.bz2 files
# 4- Un compress downloaded backup files with:
#      tar xvjf /root/backup-scripts/tmp/201X-XX-XX/databases-201X-XX-XX.tar.bz2
#      tar xvjf /root/backup-scripts/tmp/201X-XX-XX/backup-files-201X-XX-XX.tar.bz2
#      tar xvjf /root/backup-scripts/tmp/201X-XX-XX/webserver-config-files-201X-XX-XX.tar.bz2
# 5- Backup actual databases if they exists
# 6- Restore databases with:
#      mysql -uroot -e "CREATE DATABASE base_de_datos;"
#      mysql --max_allowed_packet=16M -h localhost -u root -p --default-character-set=latin1 base_de_datos < backup.sql
#
# BK TYPES:
# CONFIG WS: ${CONFIG_F}/webserver-config-files-${ONEWEEKAGO}.tar.bz2
# CONFIG PHP: ${CONFIG_F}/php-config-files-${ONEWEEKAGO}.tar.bz2
# CONFIG MYSQL: ${CONFIG_F}/mysql-config-files-${ONEWEEKAGO}.tar.bz2
# FILES: ${SITES_F}/backup-files_${ONEWEEKAGO}.tar.bz2
# DB: ${DBS_F}/${DATABASE}/db-${DATABASE}_${ONEWEEKAGO}.tar.bz2
#
#
SITES_F="sites"
CONFIG_F="configs"
DBS_F="databases"
SFOLDER="/root/broobe-utils-scripts"					          #Backup Scripts folder
#Restore Local?
#$SFOLDER/tmp/backups/*.tar.gz

#Restore from Dropbox
DROPBOX_LIST_TYPE=$(${SFOLDER}/dropbox_uploader.sh list)
DROPBOX_LIST_PROJECT=$(${SFOLDER}/dropbox_uploader.sh list databases)
#DROPBOX_LIST_DATE=$(${SFOLDER}/dropbox_uploader.sh list databases)

# Disaplay choose dialog with available backups
CHOSEN_TYPE=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Type" 20 78 10 `for x in ${DROPBOX_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
CHOSEN_PROJECT=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Project" 20 78 10 `for x in ${DROPBOX_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
CHOSEN_BACKUP=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Project" 20 78 10 `for x in ${DROPBOX_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
#CHOSEN_DATE=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Date" 20 78 10 `for x in ${DROPBOX_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
        # Get files and database backup file names
        #WWW_BACKUP=$(ls /home/example/backups/www-${CHOSEN_DATE}.tar.gz | tail -n 1)
        #SQL_BACKUP=$(ls /home/example/backups/unon-${CHOSEN_DATE}.sql | tail -n 1)

        echo "trying to run dropbox_uploader.sh download ${CONFIG_F}/webserver-config-files-${CHOSEN_DATE}.tar.bz2 /tmp"
        ./dropbox_uploader.sh download ${CONFIG_F}/webserver-config-files-${CHOSEN_DATE}.tar.bz2 /tmp

        # Restore files
        #tar -xpzf $WWW_BACKUP -C /

        # Restore database
        #mysql -u example --password=example example < $SQL_BACKUP

        # Clear drupal caches
        #drush -r /home/example/www/ cc all
fi

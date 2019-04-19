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
# 5- Backup actual databases if they exists and drop them
# 6- Restore databases with:
#      mysql -uroot -e "CREATE DATABASE base_de_datos;"
#      mysql --max_allowed_packet=16M -h localhost -u root -p --default-character-set=latin1 base_de_datos < backup.sql
#
# BK TYPES:
# CONFIG WS: ${CONFIG_F}/webserver-config-files-${ONEWEEKAGO}.tar.bz2
# CONFIG PHP: ${CONFIG_F}/php-config-files-${ONEWEEKAGO}.tar.bz2
# CONFIG MYSQL: ${CONFIG_F}/mysql-config-files-${ONEWEEKAGO}.tar.bz2
# FILES ALL SITES: ${SITES_F}/backup-files_${ONEWEEKAGO}.tar.bz2
# FILES ONE SITE: ${SITES_F}/${FOLDER_NAME}/backup-${FOLDER_NAME}_files_${ONEWEEKAGO}.tar.bz2
# DB: ${DBS_F}/${DATABASE}/db-${DATABASE}_${ONEWEEKAGO}.tar.bz2
#
#
SITES_F="sites"
CONFIG_F="configs"
DBS_F="databases"
SFOLDER="/root/broobe-utils-scripts"					          #Backup Scripts folder
#Restore Local?
#$SFOLDER/tmp/backups/*.tar.gz

RESTORE_TYPES="${CONFIG_F} ${DBS_F} ${SITES_F}"

# Disaplay choose dialog with available backups
CHOSEN_TYPE=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Type" 20 78 10 `for x in ${RESTORE_TYPES}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
        #Restore from Dropbox
        echo "trying to run ${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}"
        DROPBOX_PROJECT_LIST=$(${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE})
        #DROPBOX_LIST_TYPE=$(${SFOLDER}/dropbox_uploader.sh list)
        #DROPBOX_LIST_PROJECT=$(${SFOLDER}/dropbox_uploader.sh list databases)
        #DROPBOX_LIST_DATE=$(${SFOLDER}/dropbox_uploader.sh list databases)
fi

# if DROPBOX_PROJECT_LIST = ${CONFIG_F} then list, download, ucompress and ask for restore
if [[ ${DROPBOX_PROJECT_LIST} == *"$CONFIG_F"* ]]; then
  CHOSEN_CONFIG=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Project" 20 78 10 `for x in ${DROPBOX_PROJECT_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          #echo "trying to run ${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_CONFIG}"
          #DROPBOX_BACKUP_LIST=$(${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_CONFIG})
          echo "trying to run dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}"
          ./dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}
  fi

else
  CHOSEN_PROJECT=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Project" 20 78 10 `for x in ${DROPBOX_PROJECT_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          echo "trying to run ${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_PROJECT}"
          DROPBOX_BACKUP_LIST=$(${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_PROJECT})
  fi
  CHOSEN_BACKUP=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup" 20 78 10 `for x in ${DROPBOX_BACKUP_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          # Get files and database backup file names
          #WWW_BACKUP=$(ls /home/example/backups/www-${CHOSEN_DATE}.tar.gz | tail -n 1)
          #SQL_BACKUP=$(ls /home/example/backups/unon-${CHOSEN_DATE}.sql | tail -n 1)

          echo "trying to run dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}"
          ./dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}

          mv ${CHOSEN_BACKUP} tmp/
          cd tmp/

          # TODO: checkear si es un CONFIG, una BD o Arhivos


          # Si es una BD
          # Restore files
          tar -xvjf ${CHOSEN_BACKUP} -C /

          # importante:
          # primero backupear base actual
          # segundo dropearla
          # tercero importar la base a restaurar

          # Restore database
          #mysql -u example --password=example example < $SQL_BACKUP


  fi
fi

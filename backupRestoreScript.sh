#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.1
#############################################################################
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

MySQL_ROOT_PASS=""
FOLDER_TO_RESTORE="/var/www"

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
        #echo "trying to run ${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}"
        DROPBOX_PROJECT_LIST=$(${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE})
fi

# if DROPBOX_PROJECT_LIST = ${CONFIG_F} then list, download, ucompress and ask for restore
if [[ ${DROPBOX_PROJECT_LIST} == *"$CONFIG_F"* ]]; then
  CHOSEN_CONFIG=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Project" 20 78 10 `for x in ${DROPBOX_PROJECT_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          #echo "trying to run ${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_CONFIG}"
          #DROPBOX_BACKUP_LIST=$(${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_CONFIG})
          #echo "trying to run dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}"
          ./dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}
          mv ${CHOSEN_CONFIG} tmp/
          cd tmp/
          # Restore files
          tar -xvjf ${CHOSEN_CONFIG}
  fi
else
  #elijo proyecto
  CHOSEN_PROJECT=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Project" 20 78 10 `for x in ${DROPBOX_PROJECT_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          #echo "trying to run ${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_PROJECT}"
          DROPBOX_BACKUP_LIST=$(${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_PROJECT})
  fi
  #elijo backup a restaurar
  CHOSEN_BACKUP=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup" 20 78 10 `for x in ${DROPBOX_BACKUP_LIST}; do echo "$x backup" | sed 's/.*www-\(.*\).tar.gz/\1/'; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

          #echo "trying to run dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}"
          ./dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}

          mv ${CHOSEN_BACKUP} tmp/
          cd tmp/

          # ucompress files
          echo "Ucompressing ${CHOSEN_BACKUP}"
          tar -xvjf ${CHOSEN_BACKUP}

          if [[ ${DROPBOX_PROJECT_LIST} == *"$SITES_F"* ]]; then
            # Si es un website
            # Restore files
            echo "Trying to restore ${CHOSEN_BACKUP} files"

            #moving old files
            echo "Trying to execute: mkdir ${SFOLDER}/tmp/old_backup ..."
            mkdir ${SFOLDER}/tmp/old_backup
            #echo "Executing: mv ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT} ${SFOLDER}/tmp/old_backup ..."
            mv ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT} ${SFOLDER}/tmp/old_backup

            #echo "Executing: mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_RESTORE} ..."
            mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_RESTORE}

            #echo "Executing: chown -R www-data:www-data ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT} ..."
            chown -R www-data:www-data ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT}

          else
            # Si es una BD
            # TODO: contemplar 2 opciones: base existente y base inexistente (habría que crear el usuario)

            # Restore DB
            echo "Trying to restore ${CHOSEN_BACKUP} DB"
            # importante:
            # primero backupear base actual
            echo "Executing mysqldump ..."
            mysqldump -u root --password=${MySQL_ROOT_PASS} ${CHOSEN_PROJECT} > ${CHOSEN_PROJECT}_bk_before_restore.sql
            # tercero importar la base a restaurar
            echo "Restoring database ..."
            mysql -u root --password=${MySQL_ROOT_PASS} ${CHOSEN_PROJECT} < ${CHOSEN_BACKUP%%.*}.sql

            echo "DB ${CHOSEN_BACKUP} restored!"

          fi

  fi
fi

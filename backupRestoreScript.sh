#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.0
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
# Step 1
$SFOLDER/dropbox_uploader.sh list

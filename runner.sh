#!/bin/bash
/root/backup-scripts/mysqlBackupScript.sh
/root/backup-scripts/filesBackupScript.sh
#cd /root/backup-scripts/
#./dropbox_uploader.sh upload ./ /$HOSTNAME/
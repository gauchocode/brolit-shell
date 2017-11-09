#!/bin/bash

 ### TO EDIT ###
SFOLDER="/root/backup-scripts/"

 ### RUNNER ###
$SFOLDER/mysqlBackupScript.sh
$SFOLDER/filesBackupScript.sh

#cd /root/backup-scripts/
#./dropbox_uploader.sh upload ./ /$HOSTNAME/

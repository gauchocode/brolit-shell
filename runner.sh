#! /bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.6
#############################################################################

SCRIPT_V="1.6"

### TO EDIT ###

###TODO: Check of other webserver config locations (apache? other s.o?)
###TODO: Check if you want file back, check if you want databases backups
###TODO: Check whitelist or blacklist of Files, DBS.
###TODO: List folders to backup from "SITES"
###TODO: One tar for all databases or individual tar for database (var option).
ONE_FILE_BK=true

VPSNAME="$HOSTNAME"               		#Or choose a name
SFOLDER="/root/backup-scripts"   			#Backup Scripts folder
SITES="/var/www"                 			#Where sites are stored
WSERVER="/etc/nginx"               		#Webserver config files
BAKWP="$SFOLDER/tmp"              		#Temp folder to store Backups
DROPBOX_FOLDER="/"										#Dropbox Folder Backup
MAIN_VOL="/dev/sda1"									#Main partition
DEL_UP=false													#Delete backup files after upload?

### DUPLICITY CONFIG ###
DUP_BK=false									    		#Duplicity Backups true or false (bool)
DUP_ROOT="/mnt/backup"								#Duplicity Backups destination folder
DUP_SRC_BK="/var/www"									#Source of Directories to Backup
DUP_FOLDERS="FOLDER1,FOLDER2"	    		#Folders to Backup

### MYSQL CONFIG ###
MUSER="[MYSQL_USER]"              		#MySQL User
MPASS="[MYSQL_PASSWORD]"          		#MySQL User Pass

### SENDEMAIL CONFIG ###
###TODO: make MAILA work on "sendEmail" command.
MAILA="servidores@broobe.com"     		#Notification Email
SMTP_SERVER="mx.bmailing.com.ar:587"	#SMTP Server and Port
SMTP_TLS="yes"												#TLS: yes or no
SMTP_U="[SMTP_USER]"									#SMTP User
SMTP_P="[SMTP_PASSWORD]"							#SMTP Password

### Backup rotation ###
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

### Disk Usage ###
DISK_U=$( df -h | grep "$MAIN_VOL" | awk {'print $5'} )
echo " > Disk usage before the backup: $DISK_U ..."

### chmod
chmod +x dropbox_uploader.sh
chmod +x mysqlBackupScript.sh
chmod +x filesBackupScript.sh

### Check if sendemail is installed ###
SENDEMAIL="$(which sendemail)"
if [ ! -x "${SENDEMAIL}" ]; then
	apt-get install sendemail libio-socket-ssl-perl
fi

### TAR ###
TAR="$(which tar)"

### Get server IPs ###
DIG="$(which dig)"
if [ ! -x "${DIG}" ]; then
	apt-get install dnsutils
fi
IP=`dig +short myip.opendns.com @resolver1.opendns.com	` 2> /dev/null

### EXPORT VARS ###
export SCRIPT_V VPSNAME BAKWP SFOLDER SITES WSERVER DROPBOX_FOLDER MAIN_VOL DUP_BK DUP_ROOT DUP_SRC_BK DUP_FOLDERS MUSER MPASS MAILA NOW NOWDISPLAY ONEWEEKAGO SENDEMAIL TAR DISK_U DEL_UP ONE_FILE_BK IP SMTP_SERVER SMTP_TLS SMTP_U SMTP_P

### Creating temporary folders ###
if [ ! -d "$BAKWP" ]
then
    echo " > Folder $BAKWP doesn't exist. Creating now ..."
    mkdir $BAKWP
    echo " > Folder $BAKWP created ..."
fi
if [ ! -d "$BAKWP/$NOW" ]
then
    echo " > Folder $BAKWP/$NOW doesn't exist. Creating now ..."
    mkdir $BAKWP/$NOW
    echo " > Folder $BAKWP/$NOW created ..."
fi

### Running from terminal ###
if [ -t 1 ]
then
    while true; do
      read -p " > Do you want to run the database backup? y/n" yn
      case $yn in
          [Yy]* ) $SFOLDER/mysqlBackupScript.sh; break;;
          [Nn]* ) echo "Aborting database backup...";break;;
          * ) echo "Please answer yes or no.";;
      esac
  done
  while true; do
      read -p " > Do you want to run the file backup? y/n" yn
      case $yn in
          [Yy]* ) $SFOLDER/filesBackupScript.sh; break;;
          [Nn]* ) echo "Aborting file backup...";exit;;
          * ) echo " > Please answer yes or no.";;
      esac
  done
### Running from cron ###
else
    $SFOLDER/mysqlBackupScript.sh;
    $SFOLDER/filesBackupScript.sh;
fi

#! /bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
#############################################################################

### TO EDIT ###

###TODO: Delete files after upload (var option).
DEL_UP=false											#Delete backup files after upload?
###TODO: One tar for all databases or individual tar for database (var option).
ONE_FILE_BK=true

VPSNAME="$HOSTNAME"               #Or choose a name
SFOLDER="/root/backup-scripts"   	#Backup Scripts folder
BAKWP="$SFOLDER/tmp"              #Temp folder to store Backups
SITES="/var/www"                 	#Where sites are stored
NGINX="/etc/nginx"               	#Nginx config files
DUP_BK=false									    #Duplicity Backups true or false (bool)
DUP_ROOT="/mnt/backup"						#Duplicity Backups destination folder
DUP_SRC_BK="/var/www"							#Source of Directories to Backup
DUP_FOLDERS="FOLDER1,FOLDER2"	    #Folders to Backup
MUSER="[MYSQL_USER]"              #MySQL User
MPASS="[MYSQL_PASSWORD]"          #MySQL User Pass
MAILA="servidores@broobe.com"     #Notification Email

### Backup rotation ###
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

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
export VPSNAME BAKWP SFOLDER SITES NGINX DUP_BK DUP_ROOT DUP_SRC_BK DUP_FOLDERS MUSER MPASS MAILA NOW NOWDISPLAY ONEWEEKAGO SENDEMAIL TAR DEL_UP ONE_FILE_BK IP

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
          [Nn]* ) echo "Aborting...";exit;;
          * ) echo "Please answer yes or no.";;
      esac
  done
  while true; do
      read -p " > Do you want to run the file backup? y/n" yn
      case $yn in
          [Yy]* ) $SFOLDER/filesBackupScript.sh; break;;
          [Nn]* ) echo "Aborting...";exit;;
          * ) echo " > Please answer yes or no.";;
      esac
  done
### Running from cron ###
else
    $SFOLDER/mysqlBackupScript.sh;
    $SFOLDER/filesBackupScript.sh;
fi

#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.9
#############################################################################

SCRIPT_V="1.9"

### TO EDIT ###

###TODO: Check of other webserver config locations (apache? other s.o?)
###TODO: Check if you want file back, check if you want databases backups
###TODO: Check whitelist or blacklist of Files, DBS.

VPSNAME="$HOSTNAME"               						#Or choose a name
SFOLDER="/root/backup-scripts"   							#Backup Scripts folder
SITES="/var/www"                 							#Where sites are stored
WSERVER="/etc/nginx"               						#Webserver config files
BAKWP="$SFOLDER/tmp"              						#Temp folder to store Backups
DROPBOX_FOLDER="/"														#Dropbox Folder Backup
MAIN_VOL="/dev/sda1"													#Main partition

ONE_FILE_BK=false															#One tar for all databases or individual tar for database
DB_BK=true																		#Include database backup?
DEL_UP=true																		#Delete backup files after upload?

### PACKAGES TO WATCH ###
PACKAGES=(linux-firmware dpkg perl nginx php7.2-fpm mysql-server curl openssl)

### DUPLICITY CONFIG ###
DUP_BK=false									    						#Duplicity Backups true or false (bool)
DUP_ROOT="/media/backups/PROJECT_NAME_OR_VPS"	#Duplicity Backups destination folder
DUP_SRC_BK="/var/www/"												#Source of Directories to Backup
DUP_FOLDERS="FOLDER1,FOLDER2"	    						#Folders to Backup

### MYSQL CONFIG ###
MUSER=""              												#MySQL User
MPASS=""          														#MySQL User Pass

### SENDEMAIL CONFIG ###
###TODO: make MAILA work on "sendEmail" command.
MAILA="servidores@broobe.com"     						#Notification Email
SMTP_SERVER="mx.bmailing.com.ar:587"					#SMTP Server and Port
SMTP_TLS="yes"																#TLS: yes or no
SMTP_U="no-reply@send.broobe.com"							#SMTP User
SMTP_P=""																			#SMTP Password

### Backup rotation ###
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

### Disk Usage ###
DISK_U=$( df -h | grep "$MAIN_VOL" | awk {'print $5'} )
echo " > Disk usage: $DISK_U ..."

### chmod
chmod +x $SFOLDER/dropbox_uploader.sh
chmod +x $SFOLDER/mysqlBackupScript.sh
chmod +x $SFOLDER/filesBackupScript.sh

### Update package definitions ###
echo " > Running apt update..."
apt update

### Check if sendemail is installed ###
SENDEMAIL="$(which sendemail)"
if [ ! -x "${SENDEMAIL}" ]; then
	apt install sendemail libio-socket-ssl-perl
fi

### TAR ###
TAR="$(which tar)"

### Get server IPs ###
DIG="$(which dig)"
if [ ! -x "${DIG}" ]; then
	apt-get install dnsutils
fi
IP=`dig +short myip.opendns.com @resolver1.opendns.com	` 2> /dev/null

### Compare package versions ###
OUTDATED=false
echo "" > $BAKWP/pkg-$NOW.mail
for pk in ${PACKAGES[@]}; do
	PK_VI=$(apt-cache policy $pk | grep Installed | cut -d ':' -f 2)
	PK_VC=$(apt-cache policy $pk | grep Candidate | cut -d ':' -f 2)
	if [ $PK_VI != $PK_VC ]; then
		OUTDATED=true
		echo " > $pk $PK_VI -> $PK_VC <br />" >> $BAKWP/pkg-$NOW.mail
	fi
done

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

### Configure Server Mail Part ###
SRV_HEADEROPEN='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:#1DC6DF;padding:0 0 10px 10px;width:100%;height:30px">'
SRV_HEADERTEXT="Server Info"
SRV_HEADERCLOSE='</div>'

SRV_HEADER=$SRV_HEADEROPEN$SRV_HEADERTEXT$SRV_HEADERCLOSE

SRV_BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
SRV_CONTENT="<b>Server IP: $IP</b><br /><b>Disk usage before the file backup: $DISK_U</b>.<br />"
SRV_BODYCLOSE='</div></div>'
SRV_BODY=$SRV_BODYOPEN$SRV_CONTENT$SRV_BODYCLOSE

BODY_SRV=$SRV_HEADER$SRV_BODY

### Configure PKGS Mail Part ###
if [ "$OUTDATED" = true ] ; then
	PKG_COLOR='red'
	PKG_STATUS='OUTDATED'
else
	PKG_COLOR='#1DC6DF'
	PKG_STATUS='OK'
fi

PKG_HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
PKG_HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
PKG_HEADEROPEN=$PKG_HEADEROPEN1$PKG_COLOR$PKG_HEADEROPEN2
PKG_HEADERTEXT="Packages Status -> $PKG_STATUS"
PKG_HEADERCLOSE='</div>'

PKG_BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
PKG_BODYCLOSE='</div>'

PKG_HEADER=$PKG_HEADEROPEN$PKG_HEADERTEXT$PKG_HEADERCLOSE

PKG_MAIL="$BAKWP/pkg-$NOW.mail"
PKG_MAIL_VAR=$(<$PKG_MAIL)

BODY_PKG=$PKG_HEADER$PKG_BODYOPEN$PKG_MAIL_VAR$PKG_BODYCLOSE

### Running from terminal ###
if [ -t 1 ]
then
    while true; do
      read -p " > Do you want to run the database backup? y/n" yn
      case $yn in
          [Yy]* )
					source $SFOLDER/mysqlBackupScript.sh;

					DB_MAIL="$BAKWP/db-bk-$NOW.mail"
					DB_MAIL_VAR=$(<$DB_MAIL)

					HTMLOPEN='<html><body>'
					HTMLCLOSE='</body></html>'

					sendEmail -f $SMTP_U -t "servidores@broobe.com" -u "$VPSNAME - Database Backup - [$NOWDISPLAY - $STATUS_D]" -o message-content-type=html -m "$HTMLOPEN $DB_MAIL_VAR $HTMLCLOSE" -s $SMTP_SERVER -o tls=$SMTP_TLS -xu $SMTP_U -xp $SMTP_P;
					break;;

          [Nn]* )
					echo -e "\e[31mAborting database backup...\e[0m";
					break;;

          * ) echo "Please answer yes or no.";;
      esac
  done
  while true; do
      read -p " > Do you want to run the file backup? y/n" yn
      case $yn in
          [Yy]* )
					source $SFOLDER/filesBackupScript.sh;

					FILE_MAIL="$BAKWP/file-bk-$NOW.mail"
					FILE_MAIL_VAR=$(<$FILE_MAIL)

					HTMLOPEN='<html><body>'
					HTMLCLOSE='</body></html>'

					sendEmail -f $SMTP_U -t "servidores@broobe.com" -u "$STATUS_ICON_F $VPSNAME - Files Backup [$NOWDISPLAY]" -o message-content-type=html -m "$HTMLOPEN $BODY_SRV $BODY_PKG $FILE_MAIL_VAR $HTMLCLOSE" -s $SMTP_SERVER -o tls=$SMTP_TLS -xu $SMTP_U -xp $SMTP_P;
					break;;

          [Nn]* )
					echo -e "\e[31mAborting file backup...\e[0m";
					break;;

          * ) echo " > Please answer yes or no.";;
      esac
  done

	### NEW RESTORE BACKUP OPTION ###
	while true; do
			read -p " > Do you want to run restore script? y/n" yn
			case $yn in
					[Yy]* )
					source $SFOLDER/backupRestoreScript.sh;
					break;;

					[Nn]* )
					echo -e "\e[31mAborting restore script...\e[0m";
					break;;

					* ) echo " > Please answer yes or no.";;
			esac
	done

### Running from cron ###
else
    $SFOLDER/mysqlBackupScript.sh;
    $SFOLDER/filesBackupScript.sh;

		DB_MAIL="$BAKWP/db-bk-$NOW.mail"
		DB_MAIL_VAR=$(<$DB_MAIL)

		FILE_MAIL="$BAKWP/file-bk-$NOW.mail"
		FILE_MAIL_VAR=$(<$FILE_MAIL)

		HTMLOPEN='<html><body>'
		HTMLCLOSE='</body></html>'

		if [ "$STATUS_D" = "ERROR" ] || [ "$STATUS_F" = "ERROR" ]; then
			STATUS="ERROR"
			STATUS_ICON="⛔"
		else
			if [ "$OUTDATED" = true ] ; then
				STATUS="WARNING"
				STATUS_ICON="⚠"
			else
				STATUS="OK"
				STATUS_ICON="✅"
			fi
		fi
		sendEmail -f $SMTP_U -t "servidores@broobe.com" -u "$STATUS_ICON $VPSNAME - Complete Backup - [$NOWDISPLAY]" -o message-content-type=html -m "$HTMLOPEN $BODY_SRV $BODY_PKG $DB_MAIL_VAR $FILE_MAIL_VAR $HTMLCLOSE" -s $SMTP_SERVER -o tls=$SMTP_TLS -xu $SMTP_U -xp $SMTP_P;

fi

echo " > Removing temp files..."
rm $PKG_MAIL $DB_MAIL $FILE_MAIL
echo -e "\e[42m > DONE \e[0m"

#! /bin/bash
# Autor: broobe. web + mobile development - http://broobe.com
#############################################################################

### TO EDIT ###
VPSNAME="$HOSTNAME"               #Or choose a name
BAKWP="/root/tmp"                 #Temp folder to store Backups
SFOLDER="/root/backup-scripts/"   #Backup Scripts folder
SITES="/var/www/"                 #Where sites are stored
NGINX="/etc/nginx/"               #Nginx config files
DUP_BK=false									    #Duplicity Backups true or false (bool)
DUP_ROOT="/mnt/backup/"						#Duplicity Backups destination folder
DUP_SRC_BK="/var/www/"						#Source of Directories to Backup
DUP_FOLDERS="FOLDER1,FOLDER2"	    #Folders to Backup

MAILA="soporte@broobe.com"

### Starting Message ###
echo "Starting file backup script..."

### Check BAKWP folder ###
if [ ! -d "$BAKWP" ]
then
    echo "Folder doesn't exist. Creating now"
    mkdir $BAKWP
    echo "Folder created"
fi

### Gzip and backup rotation ###
TAR="$(which tar)"
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

### Remove old backups ###
rm -f $BAKWP/nginx-$ONEWEEKAGO.tar.gz
rm -f $BAKWP/files-$ONEWEEKAGO.tar.gz

### TAR Nginx Config ###
$TAR -zcvpf $BAKWP/nginx-$NOW.tar.gz $NGINX

### TAR Sites ###
$TAR -zcvpf $BAKWP/files-$NOW.tar.gz --exclude .git --exclude "*.log" $SITES

### Upload Nginx Config ###
$SFOLDER/dropbox_uploader.sh upload $BAKWP/nginx-$NOW.tar.gz /
$SFOLDER/dropbox_uploader.sh remove /nginx-$ONEWEEKAGO.tar.gz

 ### Upload Sites ###
$SFOLDER/dropbox_uploader.sh upload $BAKWP/files-$NOW.tar.gz /
$SFOLDER/dropbox_uploader.sh remove /files-$ONEWEEKAGO.tar.gz

### DUPLICITY ###
if [ "$DUP_BK" = true ] ; then
	### Check if DUPLICITY is installed ###
	DUPLICITY="$(which duplicity)"
	if [ ! -x "${DUPLICITY}" ]; then
	  apt-get install duplicity
	fi
	### Loop in to Directories ###
	for i in $(echo $DUP_FOLDERS | sed "s/,/ /g")
	do
		MANIFEST=`ls -1R $DUP_ROOT$i/ |  grep -i .*.gz | wc -l`
		if [ $MANIFEST == 0 ]; then
			### If no MANIFEST is found, then create a full Backup ###
			duplicity full -v4 --no-encryption $DUP_SRC_BK$i file://$DUP_ROOT$i
			echo "Full Backup de $i realizado con exito en $DUP_ROOT$i."
		else
			### Else, do an incremantal Backup ###
			duplicity incremental -v4 --no-encryption $DUP_SRC_BK$i file://$DUP_ROOT$i
			echo "Backup incremental de $i realizado con exito en $DUP_ROOT$i."
		fi
	done
fi

### File Check ###
AMOUNT_FILES=`ls -1R $BAKWP/ |  grep -i .*$NOW.tar.gz | wc -l`
BACKUPEDLIST_FILES=`ls $BAKWP/ | grep -i .*$NOW.tar.gz`

### Check if sendemail is installed ###
SENDEMAIL="$(which sendemail)"
if [ ! -x "${SENDEMAIL}" ]; then
	apt-get install sendemail libio-socket-ssl-perl
fi


##TODO: INCLUIR EN EL MAIL LOS BACKUPS DE DUPLICITY

### Configuring Email ###
if [ 2 -ne $AMOUNT_FILES ]; then
  STATUS_ICON="💩"
	STATUS="ERROR"
	CONTENT="<b>Ocurrio un error. Los archivos incluidos en el backup, son menos que la cantidad de esperada</b> <br />"
	COLOR='red'
	echo "Backup con errores. No se pudo generar el tar.gz"
else
  STATUS_ICON="✅"
	STATUS="OK"
	CONTENT="<b>Los archivos incluidos en el backup diario son:</b><br />"
  FILES_INC=""
  for t in $(echo $BACKUPEDLIST_FILES | sed "s/,/ /g")
	do
    FILES_INC="$FILES_INC $t<br />"
  done
	COLOR='#1DC6DF'
	echo "Backup exitoso"
fi
HEADERTEXT="$STATUS_ICON $VPSNAME - Files Backup - [$NOWDISPLAY - $STATUS]"
HEADEROPEN1='<html><body><div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF; float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERCLOSE='</div>'
BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
BODYCLOSE='</div>'
FOOTER='<div style="font-size:10px; float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">Broobe Team</div></div></body></html>'
HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$FILES_INC$BODYCLOSE

### Sending Email ###
sendEmail -f no-reply@send.broobe.com -t "soporte@broobe.com" -u "$VPSNAME [$NOWDISPLAY] - Files Backup - [$STATUS]" -o message-content-type=html -m "$HEADER $BODY $FOOTER" -s mx.bmailing.com.ar:587 -o tls=yes -xu no-reply@send.broobe.com -xp broobe2020*

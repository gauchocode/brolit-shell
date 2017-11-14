#! /bin/bash
# Autor: broobe. web + mobile development - http://broobe.com
#############################################################################

### TO EDIT ###
BAKWP="/root/tmp"
SFOLDER="/root/backup-scripts/"
SITES="/var/www/"
VPSNAME="$HOSTNAME"
MAILA="soporte@broobe.com"

### Check BAKWP folder ###
if [ ! -d "$BAKWP" ]
then
    echo "Folder doesn't exist. Creating now"
    mkdir $BAKWP
    echo "Folder created"
else
    echo "Folder exists"
fi

### Gzip and backup rotation ###
TAR="$(which tar)"
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

### Remove old backups ###
rm -rf $BAKWP/files-$ONEWEEKAGO.tar.gz

cd $SITES
$TAR -zcvpf $BAKWP/files-$NOW.tar.gz $SITES

### Dropbox Uploader ###
cd $SFOLDER
./dropbox_uploader.sh upload $BAKWP/files-$NOW.tar.gz /
./dropbox_uploader.sh remove /files-$ONEWEEKAGO.tar.gz

AMOUNT2=`ls -1R $BAKWP/ |  grep -i .*$NOW.tar.gz | wc -l`
BACKUPEDLIST2=`ls $BAKWP/ | grep -i .*$NOW.tar.gz`

### Configuring Email ###
if [ $AMOUNT2 -ne $BACKUPEDLIST2 ]; then
	STATUS="ERROR 💩"
	CONTENT="<b>Ocurrio un error. Los archivos incluidos en el backup, son menos que la cantidad de esperada</b> <br />"
	COLOR='red'
	echo "Backup con errores. Se esperaban encontrar $AMOUNT2 tar.gz y solo se hicieron $BACKUPEDLIST2"
else
	STATUS="OK 😎"
	CONTENT="<b>Los archivos incluidos en el backup diario son:</b><br />$BACKUPEDLIST2"
	COLOR='#1DC6DF'
	echo "Backup exitoso"
fi
HEADERTEXT="$VPSNAME [$NOWDISPLAY] - Files Backup - [$STATUS]"
HEADEROPEN1='<html><body><div style="float:left;width:100%"><div style="font-size:13px;color:#FFF; float:left;font-family:Verdana,Helvetica,Arial;line-height:31px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:500px;height:20px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERCLOSE='</div>'
BODYOPEN='<div style="color:#000;font-size:10px; float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;height:130px">'
BODYCLOSE='</div>'
FOOTER='<div style="font-size:10px; float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">Broobe Team</div></div></body></html>'
HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$BODYCLOSE

### Sending Email ###
sendEmail -f no-reply@send.broobe.com -t "soporte@broobe.com" -u "$VPSNAME [$NOWDISPLAY] - Files Backup - [$STATUS]" -o message-content-type=html -m "$HEADER $BODY $FOOTER" -s mx.bmailing.com.ar:587 -o tls=yes -xu no-reply@send.broobe.com -xp broobe2020*

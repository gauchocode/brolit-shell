#! /bin/bash
#
# mysqlBackup.sh
# Genera un archivo backup (dump) de la base configurada le agrega un
# timestamp y lo sube por dropbox. Borra el backup de una semana atras.
#
# Autor: broobe. web + mobile development - http://broobe.com
#############################################################################

### TO EDIT ###
#VPSNAME="$HOSTNAME"
VPSNAME="[VPS_NAME]"
MUSER="[MYSQL_USER]"
MPASS="[MYSQL_PASSWORD]"
BAK="/root/tmp"
SFOLDER="/root/backup-scripts/"
MAILA="soporte@broobe.com"

### MySQL CONFIG ###
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### Starting Message ###
echo " > Starting database backup script..."

### Check BAK folder ###
if [ ! -d "$BAK" ]
then
    echo " > Folder doesn't exist. Creating now"
    mkdir $BAK
    echo " > Folder $BAK created"
fi

### Gzip and backup rotation ###
GZIP="$(which gzip)"
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

### Get all databases name ###
DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"
COUNT=0
for db in $DBS
do
  if [ "${db}" != "information_schema" ] && [ "${db}" != "performance_schema" ] && [ "${db}" != "mysql" ] && [ "${db}" != "sys" ]; then
    ### Create tar for each database ###
    FILE=$BAK/db-$db-$NOW.gz
    echo " > Deleting old database backup [$db] ..."
    rm -f $BAK/db-$db-$ONEWEEKAGO.gz
	  ### Create dump file###
    echo " > Creating new database backup [$db] ..."
    $MYSQLDUMP -u $MUSER -h $MHOST -p$MPASS $db | $GZIP -9 > $FILE
    ### Upload to Dropbox ###
    echo " > Uploading new database backup [$db] ..."
    $SFOLDER/dropbox_uploader.sh upload $FILE /
    $SFOLDER/dropbox_uploader.sh remove /db-$db-$ONEWEEKAGO.gz
    COUNT=$((COUNT+1))
  fi
done

### File Check ###
AMOUNT=`ls -1R $BAK/ |  grep -i .*$NOW.gz | wc -l`
BACKUPEDLIST=`ls -1R $BAK/ |  grep -i .*$NOW.gz`

### Check if sendemail is installed ###
SENDEMAIL="$(which sendemail)"
if [ ! -x "${SENDEMAIL}" ]; then
	apt-get install sendemail libio-socket-ssl-perl
fi

### Configure Email ###
if [ $COUNT -ne $AMOUNT ]; then
  STATUS_ICON="💩"
	STATUS="ERROR"
	CONTENT="<b>Ocurrio un error. Los archivos incluidos en el backup, son menos que la cantidad de esperada</b> <br />"
	COLOR='red'
	echo "Backup con errores. Se esperaban backupear $COUNT bases de datos y solo se hicieron $AMOUNT"
else
  STATUS_ICON="✅"
	STATUS="OK"
	CONTENT="<b>Los archivos incluidos en el backup diario son:</b><br />"
  FILES_INC=""
  for t in $(echo $BACKUPEDLIST | sed "s/,/ /g")
	do
    FILES_INC="$FILES_INC $t<br />"
  done
	COLOR='#1DC6DF'
	echo "Backup exitoso"
fi
HEADERTEXT="$STATUS_ICON $VPSNAME - Database Backup - [$NOWDISPLAY - $STATUS]"
HEADEROPEN1='<html><body><div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF; float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERCLOSE='</div>'
BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
BODYCLOSE='</div>'
FOOTER='<div style="font-size:10px; float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">Broobe Team</div></div></body></html>'
HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$FILES_INC$BODYCLOSE

### Send Email ###
sendEmail -f no-reply@send.broobe.com -t "soporte@broobe.com" -u "$STATUS_ICON $VPSNAME - Database Backup - [$NOWDISPLAY - $STATUS]" -o message-content-type=html -m "$HEADER $BODY $FOOTER" -s mx.bmailing.com.ar:587 -o tls=yes -xu no-reply@send.broobe.com -xp broobe2020*

#! /bin/bash
#
# mysqlBackup.sh
# Genera un archivo backup (dump) de la base configurada le agrega un
# timestamp y lo sube por dropbox. Borra el backup de una semana atras.
#
# Autor: broobe. web + mobile development - http://broobe.com
#############################################################################

 ### TO EDIT ###
MUSER="[MYSQL_USER]"
MPASS="[MYSQL_PASSWORD]"
BAK="/root/tmp"
SFOLDER="/root/backup-scripts/"
#VPSNAME="$HOSTNAME"

### MySQL CONFIG ###
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### Check BAK folder ###
if [ ! -d "$BAK" ]
then
    echo "Folder doesn't exist. Creating now"
    mkdir $BAK
    echo "Folder created"
else
    echo "Folder exists"
fi

### Gzip and backup rotation ###
GZIP="$(which gzip)"
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

### Get all databases name ###
DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"
for db in $DBS
do
  if [ "${db}" != "information_schema" ] && [ "${db}" != "performance_schema" ] && [ "${db}" != "mysql" ] && [ "${db}" != "sys" ]; then
    ### Create tar for each database ###
    FILE=$BAK/db-$db-$NOW.gz
    rm -rf $BAK/db-$db-$ONEWEEKAGO.gz
    $MYSQLDUMP -u $MUSER -h $MHOST -p$MPASS $db | $GZIP -9 > $FILE
  fi
done
#DBSCLEAN="$DBSCLEAN,$db"

AMOUNT=`ls -1R $BAK/ |  grep -i .*$NOW.gz | wc -l`
BACKUPEDLIST=`ls -1R $BAK/ |  grep -i .*$NOW.gz`

### Dropbox Uploader ###
cd $SFOLDER
./dropbox_uploader.sh upload $FILE /
./dropbox_uploader.sh remove /db-$db-$ONEWEEKAGO.gz

#
#if [ 1 -ne $AMOUNT ]; then
#STATE="ERROR"
#SUBJECT="DROBI-VPS [$NOWDISPLAY] - mysqlBackups - ERROR"
#CONTENT="<b>Ocurrio un error. Los archivos incluidos en el backup, son menos que la cantidad de bases de arqa:</b> <br />"
#COLOR='red'
#
#else
#STATE="OK"
#SUBJECT="DROBI-VPS [$NOWDISPLAY] - mysqlBackups - OK"
#CONTENT="<b>Los archivos incluidos en el backup diario son:</b><br />$BACKUPEDLIST"
#COLOR='#1DC6DF'
#fi
#HEADEROPEN1='<html><body><div style="float:left;width:500px"><div style="font-size:13px;color:#FFF;float:left;font-family: Verdana, Tahoma, Helvetica, Arial;line-height:31px;background:'
#HEADEROPEN2='; padding-left:5px;width:500px; height:20px">'
#HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
#HEADERCLOSE='</div>'
#BODYOPEN='<div style="color:#000;font-size:10px; float:left;font-family: Verdana, Tahoma, Helvetica, Arial;background:#D8D8D8;padding-left:5px;width:500px; height:130px">'
#BODYCLOSE='</div>'
#FOOTER='<div style="font-size:10px; float:left;font-family: Verdana, Tahoma, Helvetica, Arial;text-align:right; padding-right:5px;width:500px; height:20px">Broobe Team</div></div></body></html>'
#
#HEADER=$HEADEROPEN$SUBJECT$HEADERCLOSE
#
#BODY=$BODYOPEN$CONTENT$BODYCLOSE
#
#sendEmail -f admin@broobe.com -t "dev@broobe.com" -u "BROOBE-VPS01-BACKUPS [MySQL] - [$STATE] ($NOWDISPLAY)" -m "$HEADER $BODY $FOOTER" -s smtp.gmail.com -o tls=yes -xu admin@broobe.com -xp br00b34dm1n

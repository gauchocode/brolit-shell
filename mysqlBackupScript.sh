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

### Send Email ###
if [ 1 -ne $AMOUNT ]; then
  echo "HUBO UN PROBLEMA CON EL BACKUP EN $VPSNAME" | mailx -v -r "no-reply@send.broobe.com" -a 'Content-Type: text/html' -s "BROOBE: $VPSNAME DB BACKUP --ERROR" -S smtp-use-starttls -S smtp="mx.bmailing.com.ar:587" -S smtp-auth=login -S smtp-auth-user="no-reply@send.broobe.com" -S smtp-auth-password="broobe2020*" -S ssl-verify=ignore $MAILA
  echo "Backup con errores"
else
  echo "BACKUP REALIZADO CON EXITO EN $VPSNAME<br /><br /><b>Los archivos incluidos en el backup diario son:</b><br />$BACKUPEDLIST" | mailx -v -r "no-reply@send.broobe.com" -a 'Content-Type: text/html' -s "BROOBE: $VPSNAME DB BACKUP --OK" -S smtp-use-starttls -S smtp="mx.bmailing.com.ar:587" -S smtp-auth=login -S smtp-auth-user="no-reply@send.broobe.com" -S smtp-auth-password="broobe2020*" -S ssl-verify=ignore $MAILA
  echo "Backup exitoso"
fi

#! /bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.4
#############################################################################

### Helpers ###
count_dabases (){
  TOTAL_DBS=0
  for db in $DBS
  do
    if  [ "${db}" != "information_schema" ] &&
        [ "${db}" != "performance_schema" ] &&
        [ "${db}" != "mysql" ] &&
        [ "${db}" != "sys" ]; then
      TOTAL_DBS=$((TOTAL_DBS+1))
    fi
  done
  return $TOTAL_DBS
}

### MySQL CONFIG ###
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

### Global VARS ###
DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"

### Starting Message ###
echo " > Starting database backup script..."

### Get all databases name ###
COUNT=0
count_dabases
echo " > $TOTAL_DBS databases found ..."
for DATABASE in $DBS
do
  if  [ "${DATABASE}" != "information_schema" ] &&
      [ "${DATABASE}" != "performance_schema" ] &&
      [ "${DATABASE}" != "mysql" ] &&
      [ "${DATABASE}" != "mysql" ] &&
      [ "${DATABASE}" != "sys" ]; then
    ### Create zip for each database ###
    FILE=$BAKWP/$NOW/db-${DATABASE}-$NOW.sql
    ### Create dump file###
    echo " > Creating new database backup in [$FILE] ..."
    $MYSQLDUMP --max-allowed-packet=1073741824  -u $MUSER -h $MHOST -p$MPASS $DATABASE > $FILE
    if [ "$?" -eq 0 ]
    then
        echo " > Mysqldump OK ..."
    else
        echo " > Mysqldump ERROR: $? ..."
        echo " > Aborting ..."
        exit 1
    fi
    if [ "$ONE_FILE_BK" = false ] ; then
      ### Upload to Dropbox ###
      echo " > Making a tar.bz2 file of [$FILE]..."
      $TAR -jcvpf db-$NOW.tar.bz2 $FILE
      echo " > Uploading new database backup [$FILE] ..."
      $SFOLDER/dropbox_uploader.sh upload $FILE $DROPBOX_FOLDER
      ### Delete old backups ###
      echo " > Trying to delete old database backup [db-$DATABASE-$ONEWEEKAGO.tar.bz2] ..."
      if [ "$DROPBOX_FOLDER" != "/" ] ; then
        $SFOLDER/dropbox_uploader.sh remove $DROPBOX_FOLDER/db-$DATABASE-$ONEWEEKAGO.tar.bz2
      else
        $SFOLDER/dropbox_uploader.sh remove /db-$DATABASE-$ONEWEEKAGO.tar.bz2
      fi
    fi
    ### Count and echo ###
    COUNT=$((COUNT+1))
    echo " > Backup $COUNT of $TOTAL_DBS ..."
  fi
done

### Create new backups ###
if [ "$ONE_FILE_BK" = true ] ; then
  cd $BAKWP/$NOW
  echo " > Making a tar.bz2 file with all databases ..."
  $TAR -jcvpf databases-$NOW.tar.bz2 $BAKWP/$NOW
  ### Upload new backups ###
  echo " > Uploading all databases on tar.bz2 file ..."
  $SFOLDER/dropbox_uploader.sh upload databases-$NOW.tar.bz2 $DROPBOX_FOLDER
  ### Remove old backups ###
  echo " > Trying to delete old [databases-$ONEWEEKAGO.tar.bz2] from Dropbox..."
  if [ "$DROPBOX_FOLDER" != "/" ] ; then
    $SFOLDER/dropbox_uploader.sh remove $DROPBOX_FOLDER/databases-$ONEWEEKAGO.tar.bz2
  else
    $SFOLDER/dropbox_uploader.sh remove /databases-$ONEWEEKAGO.tar.bz2
  fi
fi

### File Check ###
AMOUNT=`ls -1R $BAKWP/$NOW |  grep -i .*$NOW.sql | wc -l`
BACKUPEDLIST=`ls -1R $BAKWP/$NOW |  grep -i .*$NOW.sql`

### Remove server backups ###
echo " > Deleting all .sql files ..."
rm -r $BAKWP/$NOW/*.sql
if [ "$DEL_UP" = true ] ; then
  echo " > Deleting all backup files from server ..."
  rm -r $BAKWP/$NOW/databases-$NOW.tar.bz2
else
  OLD_BK_DBS=$BAKWP/$ONEWEEKAGO/databases-$ONEWEEKAGO.tar.bz2
  if [ ! -f $OLD_BK_DBS ]; then
    echo " > Old backups not found in server ..."
  else
    echo " > Deleting old backup files from server ..."
    rm -r $OLD_BK_DBS
  fi
fi

### Configure Email ###
if [ $COUNT -ne $AMOUNT ]; then
  STATUS_ICON="💩"
	STATUS="ERROR"
	CONTENT="<b>Server IP: $IP</b><br /><b>Backup with errors.<br />MySQL has $COUNT databases, but only $AMOUNT have a backup.<br />Please check log file.</b> <br />"
	COLOR='red'
	echo " > Backup with errors. MySQL has $COUNT databases, but only $AMOUNT have a backup."
else
  STATUS_ICON="✅"
	STATUS="OK"
	CONTENT="<b>Server IP: $IP</b><br /><b>Backup files included:</b><br />"
  FILES_INC=""
  for t in $(echo $BACKUPEDLIST | sed "s/,/ /g")
	do
    FILES_INC="$FILES_INC $t<br />"
  done
	COLOR='#1DC6DF'
	echo " > Backup OK"
fi
HEADERTEXT="$STATUS_ICON $VPSNAME - Database Backup - [$NOWDISPLAY - $STATUS]"
HEADEROPEN1='<html><body><div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERCLOSE='</div>'
BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
BODYCLOSE='</div>'
FOOTER='<div style="font-size:10px; float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">Broobe Team</div></div></body></html>'
HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$FILES_INC$BODYCLOSE

### Send Email ###
sendEmail -f $SMTP_U -t "servidores@broobe.com" -u "$STATUS_ICON $VPSNAME - Database Backup - [$NOWDISPLAY - $STATUS]" -o message-content-type=html -m "$HEADER $BODY $FOOTER" -s $SMTP_SERVER -o tls=$SMTP_TLS -xu $SMTP_U -xp $SMTP_P

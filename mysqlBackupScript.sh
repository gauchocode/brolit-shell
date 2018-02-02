#! /bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.8
#############################################################################

### VARS ###
BK_TYPE="Database"
ERROR=false
ERROR_TYPE=""

### Helpers ###
count_dabases (){
  TOTAL_DBS=0
  for db in $DBS
  do
    if  [ "${db}" != "phpmyadmin" ] &&
        [ "${db}" != "information_schema" ] &&
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
echo -e "\e[42m > Starting database backup script...\e[0m"

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
      BK_SIZE[$COUNT]=$(ls -lah db-$NOW.tar.bz2 | awk '{ print $5}')
      echo " > Backup created, final size: $BK_SIZE[$COUNT] ..."
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
  $TAR -jcvpf databases-$NOW.tar.bz2 $BAKWP/$NOW/*.sql
  BK_SIZE[0]=$(ls -lah databases-$NOW.tar.bz2 | awk '{ print $5}')
  echo " > Backup created, final size: $BK_SIZE ..."

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

### Disk Usage ###
DISK_UDB=$( df -h | grep "$MAIN_VOL" | awk {'print $5'} )

### Configure Email ###
if [ $COUNT -ne $AMOUNT ]; then
  STATUS_ICON_D="💩"
	STATUS_D="ERROR"
	CONTENT_D="<b>Backup with errors.<br />MySQL has $COUNT databases, but only $AMOUNT have a backup.<br />Please check log file.</b> <br />"
	COLOR_D='red'
	echo " > Backup with errors. MySQL has $COUNT databases, but only $AMOUNT have a backup."
else
  COUNT=0
  STATUS_ICON_D="✅"
	STATUS_D="OK"
	CONTENT_D=""
  COLOR_D='#1DC6DF'
  SIZE_D="Backup file size: <b>$BK_SIZE</b><br />"
  FILES_LABEL_D="<b>Backup files included:</b><br />"
  FILES_INC_D=""
  for t in $(echo $BACKUPEDLIST | sed "s/,/ /g")
	do
    FILES_INC_D="$FILES_INC_D $t<br />"
    COUNT=$((COUNT+1))
  done
	echo -e "\e[42m > Database Backup OK\e[0m"
fi

HEADEROPEN1_D='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2_D=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN_D=$HEADEROPEN1_D$COLOR_D$HEADEROPEN2_D
HEADERTEXT_D="Database Backup -> $STATUS_D"
HEADERCLOSE_D='</div>'

BODYOPEN_D='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
BODYCLOSE_D='</div>'

HEADER_D=$HEADEROPEN_D$HEADERTEXT_D$HEADERCLOSE_D
BODY_D=$BODYOPEN_D$CONTENT_D$SIZE_D$FILES_LABEL_D$FILES_INC_D$BODYCLOSE_D

echo $HEADER_D > $BAKWP/db-bk-$NOW.mail
echo $BODY_D >> $BAKWP/db-bk-$NOW.mail

export STATUS_D STATUS_ICON_D HEADER_D BODY_D

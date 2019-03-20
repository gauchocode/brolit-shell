#! /bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.9
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
echo -e "\e[42m > Starting database backup script...\e[0m" >> $LOG

### Get all databases name ###
COUNT=0
count_dabases
echo " > $TOTAL_DBS databases found ..." >> $LOG
for DATABASE in $DBS
do
  if  [ "${DATABASE}" != "information_schema" ] &&
      [ "${DATABASE}" != "performance_schema" ] &&
      [ "${DATABASE}" != "mysql" ] &&
      [ "${DATABASE}" != "mysql" ] &&
      [ "${DATABASE}" != "sys" ]; then
    ### Create zip for each database ###
    FILE=$BAKWP/"$NOW"/db-${DATABASE}_"$NOW".sql
    ### Create dump file###
    echo " > Creating new database backup in [$FILE] ..." >> $LOG
    $MYSQLDUMP --max-allowed-packet=1073741824  -u $MUSER -h $MHOST -p$MPASS $DATABASE > $FILE
    if [ "$?" -eq 0 ]
    then
        echo " > Mysqldump OK ..." >> $LOG
    else
        echo " > Mysqldump ERROR: $? ..." >> $LOG
        echo " > Aborting ..." >> $LOG
        exit 1
    fi
    if [ "$ONE_FILE_BK" = false ] ; then
      cd $BAKWP/$NOW
      echo " > Making a tar.bz2 file of [$FILE]..." >> $LOG
      $TAR -jcvpf $BAKWP/"$NOW"/db-${DATABASE}_"$NOW".tar.bz2 $FILE
      BK_SIZE[$COUNT]=$(ls -lah db-${DATABASE}_"$NOW".tar.bz2 | awk '{ print $5}')
      echo " > Backup created, final size: $BK_SIZE[$COUNT] ..." >> $LOG
      ### Upload to Dropbox ###
      echo " > Uploading new database backup [db-${DATABASE}_"$NOW"] ..." >> $LOG
      $SFOLDER/dropbox_uploader.sh upload db-${DATABASE}_"$NOW".tar.bz2 $DROPBOX_FOLDER
      ### Delete old backups ###
      echo " > Trying to delete old database backup [db-$DATABASE_$ONEWEEKAGO.tar.bz2] ..." >> $LOG
      if [ "$DROPBOX_FOLDER" != "/" ] ; then
        $SFOLDER/dropbox_uploader.sh remove $DROPBOX_FOLDER/db-$DATABASE_"$ONEWEEKAGO".tar.bz2
      else
        $SFOLDER/dropbox_uploader.sh remove /db-$DATABASE_"$ONEWEEKAGO".tar.bz2
      fi
      if [ "$DEL_UP" = true ] ; then
        echo " > Deleting backup from server ..." >> $LOG
        rm -r $BAKWP/"$NOW"/db-${DATABASE}_"$NOW".tar.bz2
      fi
    fi
    ### Count and echo ###
    COUNT=$((COUNT+1))
    echo " > Backup $COUNT of $TOTAL_DBS ..." >> $LOG
    echo " ###################################################" >> $LOG
  fi
done

### Create new backups ###
if [ "$ONE_FILE_BK" = true ] ; then
  cd $BAKWP/$NOW
  echo " > Making a tar.bz2 file with all databases ..." >> $LOG
  $TAR -jcvpf databases_$NOW.tar.bz2 $BAKWP/"$NOW"/*.sql
  BK_SIZE[0]=$(ls -lah databases-$NOW.tar.bz2 | awk '{ print $5}')
  echo " > Backup created, final size: $BK_SIZE ..." >> $LOG
  ### Upload new backups ###
  echo " > Uploading all databases on tar.bz2 file ..." >> $LOG
  $SFOLDER/dropbox_uploader.sh upload databases_$NOW.tar.bz2 $DROPBOX_FOLDER
  ### Remove old backups ###
  echo " > Trying to delete old [databases_$ONEWEEKAGO.tar.bz2] from Dropbox..." >> $LOG
  if [ "$DROPBOX_FOLDER" != "/" ] ; then
    $SFOLDER/dropbox_uploader.sh remove $DROPBOX_FOLDER/databases_"$ONEWEEKAGO".tar.bz2
  else
    $SFOLDER/dropbox_uploader.sh remove /databases_"$ONEWEEKAGO".tar.bz2
  fi
fi

### File Check ###
AMOUNT=`ls -1R $BAKWP/$NOW |  grep -i .*$NOW.sql | wc -l`
BACKUPEDLIST=`ls -1R $BAKWP/$NOW |  grep -i .*$NOW.sql`

### Remove server backups ###
echo " > Deleting all .sql files ..." >> $LOG
rm -r $BAKWP/"$NOW"/*.sql
if [ "$DEL_UP" = true ] ; then
  echo " > Deleting all backup files from server ..." >> $LOG
  rm -r $BAKWP/"$NOW"/databases_"$NOW".tar.bz2
else
  OLD_BK_DBS=$BAKWP/"$ONEWEEKAGO"/databases_"$ONEWEEKAGO".tar.bz2
  if [ ! -f $OLD_BK_DBS ]; then
    echo " > Old backups not found in server ..." >> $LOG
  else
    echo " > Deleting old backup files from server ..." >> $LOG
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
	echo " > Backup with errors. MySQL has $COUNT databases, but only $AMOUNT have a backup." >> $LOG
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

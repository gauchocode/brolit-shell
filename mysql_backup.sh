#! /bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
#############################################################################

### VARS
BK_TYPE="Database"
ERROR=false
ERROR_TYPE=""
DBS_F="databases"

### Dropbox Uploader Directory
DPU_F="${SFOLDER}/utils/dropbox-uploader"

### Helpers
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

DBS="$($MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse 'show databases')"

### Starting Message
echo -e ${GREEN}" > Starting database backup script ..."${ENDCOLOR} >> $LOG

### Get all databases name
COUNT=0
count_dabases
echo " > $TOTAL_DBS databases found ..." >> $LOG
for DATABASE in $DBS
do
  if  [ "${DATABASE}" != "information_schema" ] && [ "${DATABASE}" != "performance_schema" ] && [ "${DATABASE}" != "mysql" ] && [ "${DATABASE}" != "sys" ]; then

    BK_FOLDER=${BAKWP}/${NOW}/
    BK_FILE="db-${DATABASE}_${NOW}.sql"

    ### Create dump file
    echo " > Creating new database backup in [${BK_FOLDER}${BK_FILE}] ..." >> $LOG
    $MYSQLDUMP --max-allowed-packet=1073741824  -u ${MUSER} -h ${MHOST} -p${MPASS} ${DATABASE} > ${BK_FOLDER}${BK_FILE}

    if [ "$?" -eq 0 ]; then

      echo -e ${GREEN}" > Mysqldump OK ..."${ENDCOLOR}

      cd ${BAKWP}/${NOW}
      echo " > Making a tar.bz2 file of [${FILE}] ..." >> $LOG

      #echo " > $TAR -jcvpf ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.tar.bz2 --directory=${BK_FOLDER} ${BK_FILE}"
      $TAR -jcvpf ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.tar.bz2 --directory=${BK_FOLDER} ${BK_FILE}

      BACKUPEDLIST[${COUNT}]=db-${DATABASE}_${NOW}.tar.bz2
      BK_SIZE[${COUNT}]=$(ls -lah db-${DATABASE}_${NOW}.tar.bz2 | awk '{ print $5}')
      DB_BK_SIZE=$BK_SIZE[${COUNT}]

      echo " > Backup for ${DATABASE} created, final size: ${DB_BK_SIZE} ..."

      #echo " > Creating Dropbox Databases Folder ..." >> $LOG
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}/${DATABASE}
      ### Upload to Dropbox
      echo " > Uploading new database backup [db-${DATABASE}_${NOW}] ..."
      ${DPU_F}/dropbox_uploader.sh upload db-${DATABASE}_${NOW}.tar.bz2 $DROPBOX_FOLDER/${DBS_F}/${DATABASE}
      ### Delete old backups
      echo " > Trying to delete old database backup [db-${DATABASE}_${ONEWEEKAGO}.tar.bz2] ..."
      if [ "${DROPBOX_FOLDER}" != "/" ] ; then
        ${DPU_F}/dropbox_uploader.sh -q remove $DROPBOX_FOLDER/${DBS_F}/${DATABASE}/db-${DATABASE}_${ONEWEEKAGO}.tar.bz2
      else
        ${DPU_F}/dropbox_uploader.sh -q remove ${DBS_F}/${DATABASE}/db-${DATABASE}_${ONEWEEKAGO}.tar.bz2
      fi
      if [ "${DEL_UP}" = true ] ; then
        echo " > Deleting backup from server ..." >> $LOG
        rm ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.sql
        rm ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.tar.bz2
      fi
    else
      echo -e ${RED}" > Mysqldump ERROR: $? ..."${ENDCOLOR}
      ERROR=true
      ERROR_TYPE="mysqldump error with ${DATABASE}"
    fi
      COUNT=$((COUNT+1))
      echo -e ${CYAN}"> Backup ${COUNT} of ${TOTAL_DBS} ..."${ENDCOLOR}
      echo " ###################################################" >> $LOG
  fi
done

### Remove server backups
if [ "${DEL_UP}" = false ] ; then
  OLD_BK_DBS=${BAKWP}/${ONEWEEKAGO}/databases_${ONEWEEKAGO}.tar.bz2
  if [ ! -f ${OLD_BK_DBS} ]; then
    echo " > Old backups not found in server ..." >> $LOG
  else
    echo " > Deleting old backup files from server ..." >> $LOG
    rm -r ${OLD_BK_DBS}
  fi
fi

### Disk Usage
DISK_UDB=$( df -h | grep "${MAIN_VOL}" | awk {'print $5'} )

### Configure Email
if [ "${ERROR}" = true ]; then
  STATUS_ICON_D="💩"
	STATUS_D="ERROR"
	CONTENT_D="<b>Backup with errors:<br />${ERROR_TYPE}<br /><br />Please check log file.</b> <br />"
	COLOR_D='red'
	echo " > Backup with errors: ${ERROR_TYPE}." >> $LOG

else
  COUNT=0
  STATUS_ICON_D="✅"
	STATUS_D="OK"
	CONTENT_D=""
  COLOR_D='#1DC6DF'
  SIZE_D=""
  FILES_LABEL_D="<b>Backup files included:</b><br />"
  FILES_INC_D=""
  #for t in $(echo $BACKUPEDLIST | sed "s/,/ /g")
  for t in $BACKUPEDLIST
	do
    DB_BK_SIZE=$BK_SIZE[${COUNT}]
    FILES_INC_D="$FILES_INC_D $t ${DB_BK_SIZE}<br />"
    COUNT=$((COUNT+1))
  done
	echo -e ${GREEN}" > Database Backup OK"${ENDCOLOR}

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

echo $HEADER_D > ${BAKWP}/db-bk-${NOW}.mail
echo $BODY_D >> ${BAKWP}/db-bk-${NOW}.mail

export STATUS_D STATUS_ICON_D HEADER_D BODY_D

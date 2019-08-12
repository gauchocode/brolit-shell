#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.7
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh

# TODO: refactor del manejo de ERRORES

### VARS
BK_TYPE="File"
ERROR=false
ERROR_TYPE=""
SITES_F="sites"
CONFIG_F="configs"

### Starting Message
echo " > Starting file backup script ..." >>$LOG
echo -e ${GREEN}" > Starting file backup script ..."${ENDCOLOR}

echo " > Creating Dropbox folder ${CONFIG_F} on Dropbox ..." >>$LOG
${DPU_F}/dropbox_uploader.sh mkdir /${CONFIG_F}

### TAR Webserver Config Files
if [ -n "${WSERVER}" ]; then
  echo " > Trying to make an Nginx Config Files Backup ..." >>$LOG
  echo -e ${GREEN}" > Trying to make an Nginx Config Files Backup ..."${ENDCOLOR}

  if $TAR -jcpf ${BAKWP}/${NOW}/webserver-config-files-${NOW}.tar.bz2 --directory=${WSERVER} .; then
    echo " > Nginx Config Files Backup created..." >>$LOG
    echo " > Uploading TAR to Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/webserver-config-files-${NOW}.tar.bz2 ${DROPBOX_FOLDER}/${CONFIG_F}
    echo " > Trying to delete old backup from Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh remove ${CONFIG_F}/webserver-config-files-${ONEWEEKAGO}.tar.bz2

    echo -e ${GREEN}" > Nginx Config Files Backup OK"${ENDCOLOR}

  else
    ERROR=true
    ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/webserver-config-files-${NOW}.tar.bz2"
    echo $ERROR_TYPE >>$LOG

  fi
fi

### TAR PHP Config Files
if [ -n "${PHP_CF}" ]; then
  if $TAR -jcpf ${BAKWP}/${NOW}/php-config-files-${NOW}.tar.bz2 --directory=${PHP_CF} .; then
    echo " > PHP Config Files Backup created..." >>$LOG
    echo " > Uploading TAR to Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/php-config-files-${NOW}.tar.bz2 ${DROPBOX_FOLDER}/${CONFIG_F}
    echo " > Trying to delete old backup from Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh remove ${CONFIG_F}/php-config-files-${ONEWEEKAGO}.tar.bz2

    echo -e ${GREEN}" > PHP Config Files Backup OK"${ENDCOLOR}

  else
    ERROR=true
    ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/php-config-files-${NOW}.tar.bz2"
    echo ${ERROR_TYPE} >>$LOG

  fi
fi

### TAR MySQL Config Files
if [ -n "${MySQL_CF}" ]; then
  if $TAR -jcpf ${BAKWP}/${NOW}/mysql-config-files-${NOW}.tar.bz2 --directory=${MySQL_CF} .; then
    echo " > MySQL Config Files Backup created..." >>$LOG
    echo " > Uploading TAR to Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/mysql-config-files-${NOW}.tar.bz2 ${DROPBOX_FOLDER}/${CONFIG_F}
    echo " > Trying to delete old backup from Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh remove ${CONFIG_F}/mysql-config-files-${ONEWEEKAGO}.tar.bz2

    echo -e ${GREEN}" > MySQL Config Files Backup OK"${ENDCOLOR}

  else
    ERROR=true
    ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/mysql-config-files-${NOW}.tar.bz2"
    echo ${ERROR_TYPE} >>$LOG

  fi
fi

### TAR Let's Encrypt Config Files
if [ -n "${LENCRYPT_CF}" ]; then
  if $TAR -jcpf ${BAKWP}/${NOW}/letsencrypt-config-files-${NOW}.tar.bz2 --directory=${LENCRYPT_CF} .; then
    echo " > Let's Encrypt Config Files Backup created..." >>$LOG
    echo " > Uploading TAR to Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/letsencrypt-config-files-${NOW}.tar.bz2 ${DROPBOX_FOLDER}/${CONFIG_F}
    echo " > Trying to delete old backup from Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh remove ${CONFIG_F}/letsencrypt-config-files-${ONEWEEKAGO}.tar.bz2

    echo -e ${GREEN}" > Let's Encrypt Config Files Backup OK"${ENDCOLOR}

  else
    ERROR=true
    ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/letsencrypt-config-files-${NOW}.tar.bz2"
    echo ${ERROR_TYPE} >>$LOG

  fi
fi

k=0
COUNT=0
declare -a BACKUPED_LIST
declare -a BK_FL_SIZES

for j in $(find $SITES -maxdepth 1 -type d); do
  if [[ "$k" -gt 0 ]]; then

    FOLDER_NAME=$(basename $j)

    if [[ $SITES_BL != *"${FOLDER_NAME}"* ]]; then

      echo " > Making TAR from: $FOLDER_NAME ..." >>$LOG
      #echo " > $TAR --exclude '.git' --exclude '*.log' -jcpf ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2 --directory=${SITES} ${FOLDER_NAME} ..."
      TAR_FILE=$($TAR --exclude '.git' --exclude '*.log' -jcpf ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2 --directory=${SITES} ${FOLDER_NAME} >>$LOG)

      if ${TAR_FILE}; then

        BACKUPED_LIST[$COUNT]=backup-${FOLDER_NAME}_files_${NOW}.tar.bz2
        BACKUPED_FL=${BACKUPED_LIST[$COUNT]}
        BK_FL_SIZES[$COUNT]=$(ls -lah ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2 | awk '{ print $5}')
        BK_FL_SIZE=${BK_FL_SIZES[$COUNT]}
        echo " > Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..." >>$LOG

        echo " > Creating Dropbox Folder ${FOLDER_NAME} ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh mkdir /${SITES_F}
        ${DPU_F}/dropbox_uploader.sh mkdir /${SITES_F}/${FOLDER_NAME}/

        echo " > Uploading TAR to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2 $DROPBOX_FOLDER/${SITES_F}/${FOLDER_NAME}/

        echo " > Trying to delete old backup from Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh remove $DROPBOX_FOLDER/${SITES_F}/${FOLDER_NAME}/backup-${FOLDER_NAME}_files_${ONEWEEKAGO}.tar.bz2

        if [ "$DEL_UP" = true ]; then
          echo " > Deleting backup from server ..." >>$LOG
          rm -r ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2

        fi

        echo -e ${GREEN}"> DONE ..."${ENDCOLOR}

        COUNT=$((COUNT + 1))

      else
        ERROR=true
        ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2"
        echo ${ERROR_TYPE} >>$LOG

      fi

    else
      echo " > Omiting ${FOLDER_NAME} TAR file (blacklisted) ..." >>$LOG

    fi

    echo " ###################################################"
    echo " ###################################################" >>$LOG

  fi

  k=$k+1
done

### File Check
AMOUNT_FILES=$(ls -d ${BAKWP}/${NOW}/*_files_${NOW}.tar.bz2 | wc -l)
echo " > Number of backup files found: ${AMOUNT_FILES} ..." >>$LOG

### Deleting old backup files
if [ "$DEL_UP" = true ]; then
  rm -r ${BAKWP}/${NOW}
else
  OLD_BK="${BAKWP}/${ONEWEEKAGO}/"
  if [ ! -f ${OLD_BK} ]; then
    echo " > Old backups not found in server ..." >>$LOG
  else
    ### Remove old backup from server ###
    echo " > Deleting old backups from server ..." >>$LOG
    rm -r ${OLD_BK}
  fi
fi

### DUPLICITY
if [ "${DUP_BK}" = true ]; then
  ### Check if DUPLICITY is installed
  DUPLICITY="$(which duplicity)"
  if [ ! -x "${DUPLICITY}" ]; then
    apt-get install duplicity
  fi
  ### Loop in to Directories
  for i in $(echo ${DUP_FOLDERS} | sed "s/,/ /g"); do
    duplicity --full-if-older-than ${DUP_BK_FULL_FREQ} -v4 --no-encryption ${DUP_SRC_BK}$i file://${DUP_ROOT}$i
    RETVAL=$?
    duplicity remove-older-than ${DUP_BK_FULL_LIFE} --force ${DUP_ROOT}/$i

  done
  [ $RETVAL -eq 0 ] && echo "*** DUPLICITY SUCCESS ***" >>$LOG
  [ $RETVAL -ne 0 ] && echo "*** DUPLICITY ERROR ***" >>$LOG

fi

if [ "$ERROR" = true ]; then
  STATUS_ICON_F="💩"
  STATUS_F="ERROR"
  CONTENT="<b>Server IP: $IP</b><br /><b>$BK_TYPE Backup Error: $ERROR_TYPE<br />Please check log file.</b> <br />"
  COLOR='red'
  echo " > File Backup ERROR: $ERROR_TYPE" >>$LOG
else
  STATUS_ICON_F="✅"
  STATUS_F="OK"
  CONTENT=""
  COLOR='#1DC6DF'
  SIZE_LABEL=""
  FILES_LABEL='<b>Backup files includes:</b><br /><div style="color:#000;font-size:12px;line-height:24px;padding-left:10px;">'
  FILES_INC=""
  COUNT=0
  for t in "${BACKUPED_LIST[@]}"; do
    BK_FL_SIZE=${BK_FL_SIZES[$COUNT]}
    FILES_INC="$FILES_INC $t ${BK_FL_SIZE}<br />"
    COUNT=$((COUNT + 1))
  done

  FILES_LABEL_END='</div>'
  echo " > File Backup OK" >>$LOG
  echo -e ${GREEN}" > File Backup OK"${ENDCOLOR}

  if [ "${DUP_BK}" = true ]; then
    DBK_SIZE=$(du -hs $DUP_ROOT | cut -f1)
    DBK_SIZE_LABEL="Duplicity Backup size: <b>$DBK_SIZE</b><br /><b>Duplicity Backup includes:</b><br />$DUP_FOLDERS"
  fi

fi

HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
HEADEROPEN2=';padding:0 0 10px 10px;width:100%;height:30px">'
HEADEROPEN=$HEADEROPEN1$COLOR$HEADEROPEN2
HEADERTEXT="Files Backup -> $STATUS_F"
HEADERCLOSE='</div>'

BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
BODYCLOSE='</div></div>'

# TODO: el footer debería armarlo el runner u otro script que se dedique a armar la estructura del mail.
FOOTEROPEN='<div style="font-size:10px;float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px">'
SCRIPTSTRING="Script Version: $SCRIPT_V by Broobe."
FOOTERCLOSE='</div></div>'

HEADER=$HEADEROPEN$HEADERTEXT$HEADERCLOSE
BODY=$BODYOPEN$CONTENT$SIZE_LABEL$FILES_LABEL$FILES_INC$FILES_LABEL_END$DBK_SIZE_LABEL$BODYCLOSE
FOOTER=$FOOTEROPEN$SCRIPTSTRING$FOOTERCLOSE

echo $HEADER >${BAKWP}/file-bk-${NOW}.mail
echo $BODY >>${BAKWP}/file-bk-${NOW}.mail
echo $FOOTER >>${BAKWP}/file-bk-${NOW}.mail

export STATUS_F STATUS_ICON_F HTMLOPEN HEADER BODY FOOTER HTMLCLOSE

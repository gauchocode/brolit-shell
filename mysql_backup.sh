#! /bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh
source ${SFOLDER}/libs/mail_notification_helper.sh

#############################################################################

# VARS
BK_TYPE="Database"
ERROR=false
ERROR_TYPE=""
DBS_F="databases"

# Starting Message
echo " > Starting database backup script ..." >>$LOG
echo -e ${GREEN}" > Starting database backup script ..."${ENDCOLOR}

# Get MySQL DBS
DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"

# Get all databases name
TOTAL_DBS=$(count_dabases "${DBS}")
echo " > ${TOTAL_DBS} databases found ..." >>$LOG
echo -e ${CYAN}" > ${TOTAL_DBS} databases found ..."${ENDCOLOR}

# Settings some vars
COUNT=0
declare -a BACKUPEDLIST
declare -a BK_DB_SIZES

for DATABASE in ${DBS}; do

  echo -e ${YELLOW}" > Processing [${DATABASE}] ..."${ENDCOLOR}

  if [[ ${DB_BL} != *"${DATABASE}"* ]]; then

    BK_FOLDER=${BAKWP}/${NOW}/
    BK_FILE="db-${DATABASE}_${NOW}.sql"

    # Create dump file
    echo " > Creating new database backup in [${BK_FOLDER}${BK_FILE}] ..." >>$LOG
    echo -e ${YELLOW}" > Creating new database backup [${BK_FILE}] ..."${ENDCOLOR}

    $MYSQLDUMP --max-allowed-packet=1073741824 -u ${MUSER} -h ${MHOST} -p${MPASS} ${DATABASE} >${BK_FOLDER}${BK_FILE}

    if [ "$?" -eq 0 ]; then

      echo " > Mysqldump OK ..." >>$LOG
      echo -e ${WHITE}" > Mysqldump OK ..."${ENDCOLOR}

      cd ${BAKWP}/${NOW}

      echo " > Making a tar.bz2 file of [${BK_FILE}] ..." >>$LOG
      echo -e ${WHITE}" > Making a tar.bz2 file of [${BK_FILE}] ..."${ENDCOLOR}

      #echo " > $TAR -jcvpf ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.tar.bz2 --directory=${BK_FOLDER} ${BK_FILE}"
      $TAR -jcvpf ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.tar.bz2 --directory=${BK_FOLDER} ${BK_FILE}

      BACKUPEDLIST[$COUNT]=db-${DATABASE}_${NOW}.tar.bz2
      BK_DB_SIZES[$COUNT]=$(ls -lah db-${DATABASE}_${NOW}.tar.bz2 | awk '{ print $5}')
      BK_DB_SIZE=${BK_DB_SIZES[$COUNT]}

      echo " > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..." >>$LOG
      echo -e ${CYAN}" > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..."${ENDCOLOR}

      #echo " > Creating Dropbox Databases Folder ..." >> $LOG
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}/${DATABASE}

      ### Upload to Dropbox
      echo " > Uploading new database backup [db-${DATABASE}_${NOW}] ..."
      ${DPU_F}/dropbox_uploader.sh upload db-${DATABASE}_${NOW}.tar.bz2 $DROPBOX_FOLDER/${DBS_F}/${DATABASE}

      ### Delete old backups
      echo " > Trying to delete old database backup [db-${DATABASE}_${ONEWEEKAGO}.tar.bz2] ..."

      if [ "${DROPBOX_FOLDER}" != "/" ]; then
        ${DPU_F}/dropbox_uploader.sh -q remove $DROPBOX_FOLDER/${DBS_F}/${DATABASE}/db-${DATABASE}_${ONEWEEKAGO}.tar.bz2

      else
        ${DPU_F}/dropbox_uploader.sh -q remove ${DBS_F}/${DATABASE}/db-${DATABASE}_${ONEWEEKAGO}.tar.bz2

      fi

      echo " > Deleting backup from server ..." >>$LOG
      rm ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.sql
      rm ${BAKWP}/${NOW}/db-${DATABASE}_${NOW}.tar.bz2

    else

      echo " > Mysqldump ERROR: $? ..." >>$LOG
      echo -e ${RED}" > Mysqldump ERROR: $? ..."${ENDCOLOR}
      ERROR=true
      ERROR_TYPE="mysqldump error with ${DATABASE}"

    fi

    COUNT=$((COUNT + 1))

    echo -e ${GREEN}" > Backup ${COUNT} of ${TOTAL_DBS} DONE."${ENDCOLOR}
    echo "> Backup ${COUNT} of ${TOTAL_DBS} DONE." >>$LOG

    echo -e ${GREEN}"###################################################"${ENDCOLOR}
    echo "###################################################" >>$LOG

  else
    echo -e ${YELLOW}" > Ommiting the blacklisted database: [${DATABASE}] ..."${ENDCOLOR}

  fi

done

# Disk Usage
#DISK_UDB=$(df -h | grep "${MAIN_VOL}" | awk {'print $5'})

# Configure Email
mail_mysqlbackup_section "${ERROR}" "${ERROR_TYPE}" "${BACKUPEDLIST}" "${BK_DB_SIZES}"

#export STATUS_D STATUS_ICON_D HEADER_D BODY_D

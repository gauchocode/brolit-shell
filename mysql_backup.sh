#! /bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 3.0
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

################################################################################

make_database_backup() {

  # $1 = Backup Type
  # $2 = Database

  local BK_TYPE=$1 #configs,sites,databases
  local DATABASE=$2

  local BK_FOLDER=${BAKWP}/${NOW}/
  local DB_FILE="${DATABASE}_${BK_TYPE}_${NOW}.sql"

  local OLD_BK_FILE="${DATABASE}_${BK_TYPE}_${ONEWEEKAGO}.tar.bz2"
  local BK_FILE="${DATABASE}_${BK_TYPE}_${NOW}.tar.bz2"

  echo -e ${CYAN}" > Creating new database backup of ${DATABASE} ..."${ENDCOLOR}
  echo " > Creating new database backup of ${DATABASE} ..." >>$LOG

  # Create dump file
  $MYSQLDUMP --max-allowed-packet=1073741824 -u ${MUSER} -h ${MHOST} -p${MPASS} ${DATABASE} >${BK_FOLDER}${DB_FILE}

  if [ "$?" -eq 0 ]; then

    echo -e ${GREEN}" > mysqldump OK!"${ENDCOLOR}
    echo " > mysqldump OK!" >>$LOG

    cd ${BAKWP}/${NOW}

    echo -e ${CYAN}" > Making a tar.bz2 file of [${DB_FILE}] ..."${ENDCOLOR}
    echo " > Making a tar.bz2 file of [${DB_FILE}] ..." >>$LOG

    #echo -e ${MAGENTA}" > tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}"${ENDCOLOR}
    tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}
    #(tar -cf - ${BAKWP}/${NOW}/${DB_FILE} | pv -ns $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Making backup of '${DB_FILE} 7 70
    #TAR_FILE=$($TAR -cpf ${BAKWP}/${NOW}/${BK_FILE} --directory=${BK_FOLDER} ${DB_FILE} --use-compress-program=lbzip2)

    # Test backup file
    echo -e ${CYAN}" > Testing backup file: ${DB_FILE} ..."${ENDCOLOR}
    echo " > Testing backup file: ${DB_FILE} ..." >>$LOG
    lbzip2 -t ${BAKWP}/${NOW}/${BK_FILE}

    if [ $? -eq 0 ]; then

      echo -e ${GREEN}" > ${BK_FILE} OK!"${ENDCOLOR}
      echo " > ${BK_FILE} OK!" >>$LOG

      BACKUPED_DB_LIST[$DB_BK_INDEX]=${BK_FILE}

      # Calculate backup size
      BK_DB_SIZES[$DB_BK_INDEX]=$(ls -lah ${BK_FILE} | awk '{ print $5}')
      BK_DB_SIZE=${BK_DB_SIZES[$DB_BK_INDEX]}

      echo -e ${GREEN}" > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..."${ENDCOLOR}
      echo " > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..." >>$LOG

      #echo " > Creating Dropbox Databases Folder ..." >> $LOG
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}/${DATABASE}

      # New folder structure with date
      #${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}
      #${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}/${NOW}

      # Upload to Dropbox
      echo " > Uploading new database backup [${BK_FILE}] ..."
      #${DPU_F}/dropbox_uploader.sh upload ${BK_FILE} /${SITES_F}/${FOLDER_NAME}/${NOW}
      ${DPU_F}/dropbox_uploader.sh upload ${BK_FILE} $DROPBOX_FOLDER/${DBS_F}/${DATABASE}

      # Delete old backups
      echo " > Trying to delete old database backup [${OLD_BK_FILE}] ..."
      #${DPU_F}/dropbox_uploader.sh delete ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${ONEWEEKAGO}

      ${DPU_F}/dropbox_uploader.sh -q remove ${DBS_F}/${DATABASE}/${OLD_BK_FILE}

      echo -e ${CYAN}" > Deleting backup from server ..."${ENDCOLOR}
      echo " > Deleting backup from server ..." >>$LOG
      rm ${BAKWP}/${NOW}/${DB_FILE}
      rm ${BAKWP}/${NOW}/${BK_FILE}

    fi

  else

    echo " > mysqldump ERROR: $? ..." >>$LOG
    echo -e ${RED}" > mysqldump ERROR: $? ..."${ENDCOLOR}
    ERROR=true
    ERROR_TYPE="mysqldump error with ${DATABASE}"

  fi

}

#############################################################################

# GLOBALS
BK_TYPE="database"
ERROR=false
ERROR_TYPE=""
DBS_F="databases"

# TODO: esto hacerlos globales en runner.sh?
SITES_F="sites"

# Starting Message
echo " > Starting database backup script ..." >>$LOG
echo -e ${GREEN}" > Starting database backup script ..."${ENDCOLOR}

# Get MySQL DBS
DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"

# Get all databases name
TOTAL_DBS=$(count_dabases "${DBS}")
echo " > ${TOTAL_DBS} databases found ..." >>$LOG
echo -e ${CYAN}" > ${TOTAL_DBS} databases found ..."${ENDCOLOR}

# MORE GLOBALS
DB_BK_INDEX=0
declare -a BACKUPED_DB_LIST
declare -a BK_DB_SIZES

for DATABASE in ${DBS}; do

  echo -e ${YELLOW}" > Processing [${DATABASE}] ..."${ENDCOLOR}

  if [[ ${DB_BL} != *"${DATABASE}"* ]]; then

    make_database_backup "database" "${DATABASE}"

    DB_BK_INDEX=$((DB_BK_INDEX + 1))

    echo -e ${GREEN}" > Backup ${DB_BK_INDEX} of ${TOTAL_DBS} DONE"${ENDCOLOR}
    echo "> Backup ${DB_BK_INDEX} of ${TOTAL_DBS} DONE" >>$LOG

    echo -e ${GREEN}"###################################################"${ENDCOLOR}
    echo "###################################################" >>$LOG

  else
    echo -e ${YELLOW}" > Ommiting the blacklisted database: [${DATABASE}] ..."${ENDCOLOR}

  fi

done

# Configure Email
echo -e ${CYAN}" > BACKUPED_DB_LIST: ${BACKUPED_DB_LIST}"${ENDCOLOR}

mail_mysqlbackup_section "${ERROR}" "${ERROR_TYPE}" ${BACKUPED_DB_LIST} ${BK_DB_SIZES}

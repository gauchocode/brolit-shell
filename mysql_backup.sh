#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta12
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/mysql_helper.sh"
source "${SFOLDER}/libs/backup_helper.sh"
source "${SFOLDER}/libs/mail_notification_helper.sh"

#############################################################################

# GLOBALS
BK_TYPE="database"
ERROR=false
ERROR_TYPE=""
DBS_F="databases"

#SITES_F="sites"

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
BK_DB_INDEX=0
declare -a BACKUPED_DB_LIST
declare -a BK_DB_SIZES

for DATABASE in ${DBS}; do

  echo -e ${CYAN}" > Processing [${DATABASE}] ..."${ENDCOLOR}

  if [[ ${DB_BL} != *"${DATABASE}"* ]]; then

    make_database_backup "database" "${DATABASE}"

    BK_DB_INDEX=$((BK_DB_INDEX + 1))

    echo -e ${GREEN}" > Backup ${BK_DB_INDEX} of ${TOTAL_DBS} DONE"${ENDCOLOR}
    echo "> Backup ${BK_DB_INDEX} of ${TOTAL_DBS} DONE" >>$LOG

    echo -e ${GREEN}"###################################################"${ENDCOLOR}
    echo "###################################################" >>$LOG

  else
    echo -e ${YELLOW}" > Ommiting the blacklisted database: [${DATABASE}] ..."${ENDCOLOR}

  fi

done

# Configure Email
echo -e ${CYAN}"> Preparing mail databases backup section ..."${ENDCOLOR}
#mail_mysqlbackup_section "${ERROR}" "${ERROR_TYPE}" ${BACKUPED_DB_LIST} ${BK_DB_SIZES}
mail_mysqlbackup_section "${BACKUPED_DB_LIST[@]}" "${BK_DB_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"
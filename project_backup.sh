#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
#############################################################################
#
# TODO: This script need a refactor
# 
# The script main function need to be backup an entire project
# (files, database, nginx and let's encrypt configuration)
#
# Funtion steps:
#    1- Select a project to backup (selecting a directory from $SITES).
#    2- Then try to extract DB config from (wp-config, parameters.yml, etc)
#       If can't find, ask if has database or not. If has, select one from db list.
#    3- Then we could write a custom config file to match directory, with db.
#    3- Backup nginx and let's encrypts config.
#

### Checking Script Execution
if [[ -z "${SFOLDER}" ]]; then
    echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
    exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

# GLOBALS
BK_TYPE="Project"
ERROR=false
ERROR_TYPE=""
SITES_F="sites"
CONFIG_F="configs"

# Starting Message
echo " > Starting project backup script ..." >>$LOG
echo -e ${GREEN}" > Starting project backup script ..."${ENDCOLOR}

# Get all directories
TOTAL_SITES=$(find ${SITES} -maxdepth 1 -type d)

## Get length of $TOTAL_SITES
COUNT_TOTAL_SITES=$(find ${SITES} -maxdepth 1 -type d -printf '.' | wc -c)
COUNT_TOTAL_SITES=$((${COUNT_TOTAL_SITES} - 1))

echo -e ${CYAN}" > ${COUNT_TOTAL_SITES} directory found ..."${ENDCOLOR}
echo " > ${COUNT_TOTAL_SITES} directory found ..." >>$LOG

# MORE GLOBALS
BK_FILE_INDEX=0
BK_FL_ARRAY_INDEX=0
declare -a BACKUPED_LIST
declare -a BK_FL_SIZES

k=0

for j in ${TOTAL_SITES}; do

    echo -e ${YELLOW}" > Processing [${j}] ..."${ENDCOLOR}

    if [[ "$k" -gt 0 ]]; then

        FOLDER_NAME=$(basename $j)

        if [[ $SITES_BL != *"${FOLDER_NAME}"* ]]; then

            make_project_backup "site" "${FOLDER_NAME}" "${SITES}" "${FOLDER_NAME}"
            BK_FL_ARRAY_INDEX=$((BK_FL_ARRAY_INDEX + 1))

        else
            echo " > Omiting ${FOLDER_NAME} TAR file (blacklisted) ..." >>$LOG

        fi

        echo -e ${GREEN}" > Processed ${BK_FILE_INDEX} of ${COUNT_TOTAL_SITES} directories"${ENDCOLOR}
        echo "> Processed ${BK_FILE_INDEX} of ${COUNT_TOTAL_SITES} directories" >>$LOG

        BK_FILE_INDEX=$((BK_FILE_INDEX + 1))

    fi

    echo -e ${CYAN}"###################################################"${ENDCOLOR}
    echo "###################################################" >>$LOG

    k=$k+1

done

# Deleting old backup files
rm -r "${BAKWP}/${NOW}"

# Configure Email        
echo -e ${CYAN}"> Preparing mail files backup section ..."${ENDCOLOR}
mail_filesbackup_section "${BACKUPED_LIST[@]}" "${BK_FL_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"

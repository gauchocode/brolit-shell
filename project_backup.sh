#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta7
#############################################################################
#
# Este script va a sustituir varias de las tareas que hoy hacen 
# files_backup y mysql_backup, pero antes habría que implementar:
#
#    1- Backup de proyecto individual (seleccionándolo).
#    2- Si no encuentro la BD, pedir que se seleccione por prompt y quizá deberia 
#       generar un archivo en el proyecto para ya dejar el matching.
#    3- Backup de archivos que no tienen BD.
#    4- Backup de DB que no tiene archivos asociados.
#

### Checking Script Execution
if [[ -z "${SFOLDER}" ]]; then
    echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
    exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh
source ${SFOLDER}/libs/backup_helper.sh
source ${SFOLDER}/libs/wpcli_helper.sh
source ${SFOLDER}/libs/mail_notification_helper.sh

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
COUNT_TOTAL_SITES=$(find /var/www -maxdepth 1 -type d -printf '.' | wc -c)
COUNT_TOTAL_SITES=$((${COUNT_TOTAL_SITES} - 1))

echo -e ${CYAN}" > ${COUNT_TOTAL_SITES} directory found ..."${ENDCOLOR}
echo " > ${COUNT_TOTAL_SITES} directory found ..." >>$LOG

# MORE GLOBALS
FILE_BK_INDEX=1
declare -a BACKUPED_LIST
declare -a BK_FL_SIZES

k=0

for j in ${TOTAL_SITES}; do

    echo -e ${YELLOW}" > Processing [${j}] ..."${ENDCOLOR}

    if [[ "$k" -gt 0 ]]; then

        FOLDER_NAME=$(basename $j)

        if [[ $SITES_BL != *"${FOLDER_NAME}"* ]]; then

            make_project_backup "site" "${FOLDER_NAME}" "${SITES}" "${FOLDER_NAME}"

        else
            echo " > Omiting ${FOLDER_NAME} TAR file (blacklisted) ..." >>$LOG

        fi

        echo -e ${GREEN}" > Processed ${FILE_BK_INDEX} of ${COUNT_TOTAL_SITES} directories"${ENDCOLOR}
        echo "> Processed ${FILE_BK_INDEX} of ${COUNT_TOTAL_SITES} directories" >>$LOG

        FILE_BK_INDEX=$((FILE_BK_INDEX + 1))

    fi

    echo -e ${CYAN}"###################################################"${ENDCOLOR}
    echo "###################################################" >>$LOG

    k=$k+1

done

# Deleting old backup files
rm -r ${BAKWP}/${NOW}

# Configure Email
mail_filesbackup_section "${ERROR}" "${ERROR_TYPE}" ${BACKUPED_LIST} ${BK_FL_SIZES}

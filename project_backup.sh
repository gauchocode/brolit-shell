#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 3.0
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
source ${SFOLDER}/libs/wpcli_helper.sh
source ${SFOLDER}/libs/mail_notification_helper.sh

################################################################################

make_project_backup() {

    # $1 = Backup Type
    # $2 = Backup SubType
    # $3 = Path folder to Backup
    # $4 = Folder to Backup

    local BK_TYPE=$1     #configs,sites,databases
    local BK_SUB_TYPE=$2 #config_name,site_domain,database_name
    local SITES=$3
    local FOLDER_NAME=$4

    local BK_FOLDER=${BAKWP}/${NOW}/

    local OLD_BK_FILE="${FOLDER_NAME}_${BK_TYPE}-files_${ONEWEEKAGO}.tar.bz2"
    local BK_FILE="${FOLDER_NAME}_${BK_TYPE}-files_${NOW}.tar.bz2"

    echo -e ${CYAN}" > Making TAR.BZ2 from: ${FOLDER_NAME} ..."${ENDCOLOR}
    echo " > Making TAR.BZ2 from: ${FOLDER_NAME} ..." >>$LOG

    (tar --exclude '.git' --exclude '*.log' -cf - --directory=${SITES} ${FOLDER_NAME} | pv -ns $(du -sb ${SITES}/${FOLDER_NAME} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Processing '${FILE_BK_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${FOLDER_NAME} 7 70

    # Test backup file
    lbzip2 -t ${BAKWP}/${NOW}/${BK_FILE}

    if [ $? -eq 0 ]; then

        echo -e ${GREEN}" > ${BK_FILE} OK!"${ENDCOLOR}
        echo " > ${BK_FILE} OK!" >>$LOG

        BACKUPED_LIST[$FILE_BK_INDEX]=${BK_FILE}
        BACKUPED_FL=${BACKUPED_LIST[$FILE_BK_INDEX]}

        # Calculate backup size
        BK_FL_SIZES[$FILE_BK_INDEX]=$(ls -lah ${BAKWP}/${NOW}/${BK_FILE} | awk '{ print $5}')
        BK_FL_SIZE=${BK_FL_SIZES[$FILE_BK_INDEX]}

        echo -e ${GREEN}" > File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..."${ENDCOLOR}
        echo " > File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..." >>$LOG

        # Checking whether WordPress is installed or not
        if ! $(wp core is-installed); then

            # Check Composer and Yii Projects

            # Yii Project
            echo -e ${CYAN}" > Trying to get database name from project ..."${ENDCOLOR}
            echo " > Trying to get database name from project ..." >>$LOG
            DB_NAME=$(grep 'dbname=' ${SITES}/${FOLDER_NAME}/common/config/main-local.php | tail -1 | sed 's/$dbname=//g;s/,//g' | cut -d "'" -f4 | cut -d "=" -f3)

            local DB_FILE="${DB_NAME}.sql"

            # Create dump file
            echo -e ${CYAN}" > Creating a dump file of: ${DB_NAME}"${ENDCOLOR}
            echo " > Creating a dump file of: ${DB_NAME}" >>$LOG
            $MYSQLDUMP --max-allowed-packet=1073741824 -u ${MUSER} -h ${MHOST} -p${MPASS} ${DB_NAME} >${BK_FOLDER}${DB_FILE}

            # TODO: control dump OK (deberia usar helper mysql)

        else

            DB_NAME=$(wp --allow-root --path=${SITES}/${FOLDER_NAME} eval 'echo DB_NAME;')

            local DB_FILE="${DB_NAME}.sql"

            wpcli_export_db "${SITES}/${FOLDER_NAME}" "${BK_FOLDER}${DB_FILE}"

        fi

        echo -e ${PURPLE}" > DB_NAME=${DB_NAME}"${ENDCOLOR}
        echo " > DB_NAME=${DB_NAME}" >>$LOG

        BK_TYPE="database"
        local OLD_BK_DB_FILE="${DB_NAME}_${BK_TYPE}_${ONEWEEKAGO}.tar.bz2"
        local BK_DB_FILE="${DB_NAME}_${BK_TYPE}_${NOW}.tar.bz2"

        echo -e ${CYAN}" > Making TAR.BZ2 for database: ${DB_FILE} ..."${ENDCOLOR}
        echo " > Making TAR.BZ2 for database: ${DB_FILE} ..." >>$LOG

        echo " > tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_DB_FILE}" >>$LOG
        tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_DB_FILE}

        # Test backup file
        lbzip2 -t ${BAKWP}/${NOW}/${BK_DB_FILE}

        # TODO: control de lbzip2 ok

        # TODO: backup nginx

        echo -e ${CYAN}" > Trying to create folder in Dropbox ..."${ENDCOLOR}
        echo " > Trying to create folders in Dropbox ..." >>$LOG

        ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}

        # New folder structure with date
        ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}
        ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}/${NOW}

        echo -e ${CYAN}" > Uploading file backup ${BK_FILE} to Dropbox ..."${ENDCOLOR}
        echo " > Uploading file backup ${BK_FILE} to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_FILE} $DROPBOX_FOLDER/${SITES_F}/${FOLDER_NAME}/${NOW}

        echo -e ${CYAN}" > Uploading database backup ${BK_DB_FILE} to Dropbox ..."${ENDCOLOR}
        echo " > Uploading database backup ${BK_DB_FILE} to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_DB_FILE} ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${NOW}

        echo -e ${CYAN}" > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..."${ENDCOLOR}
        echo " > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh delete ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${ONEWEEKAGO}
        #${DPU_F}/dropbox_uploader.sh remove ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${OLD_BK_DB_FILE}

        echo " > Deleting backup from server ..." >>$LOG
        rm -r ${BAKWP}/${NOW}/${BK_FILE}

        echo -e ${GREEN}" > DONE"${ENDCOLOR}

    else
        ERROR=true
        ERROR_TYPE="ERROR: Making backup ${BAKWP}/${NOW}/${BK_FILE}"
        echo ${ERROR_TYPE} >>$LOG

    fi

}

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

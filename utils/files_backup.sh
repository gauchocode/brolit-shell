#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.9
#############################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

#############################################################################

# GLOBALS
BK_TYPE="File"
ERROR=false
ERROR_TYPE=""
SITES_F="sites"
CONFIG_F="configs"

export BK_TYPE
export SITES_F

################################### MAILCOW FILES ##################################

# MAILCOW Files
if [[ ${MAILCOW_BK} = true ]]; then

  if [ ! -d "${MAILCOW_TMP_BK}" ]; then
    log_event "info" "Folder ${MAILCOW_TMP_BK} doesn't exist. Creating now ..."
    mkdir "${MAILCOW_TMP_BK}"
    log_event "success" "Folder ${MAILCOW_TMP_BK} created"
  fi

  make_mailcow_backup "${MAILCOW}"

fi

# TODO: error_type needs refactoring

############################### SERVER CONFIG FILES ################################

make_all_server_config_backup

# Configure Files Backup Section for Email Notification
mail_configbackup_section "${BACKUPED_SCF_LIST[@]}" "${BK_SCF_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"

################################### SITES FILES ###################################

make_all_files_backup

# Deleting old backup files
rm -r "${BAKWP:?}/${NOW}"

# DUPLICITY
duplicity_backup

# Configure Files Backup Section for Email Notification
mail_filesbackup_section "${BACKUPED_LIST[@]}" "${BK_FL_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"

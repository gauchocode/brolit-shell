#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
#############################################################################
#
# SFTP Local Helper: Local sftp configuration functions
#
################################################################################

################################################################################
# Private: add folder permission
#
# Arguments:
#  ${1} = ${username}
#  ${2} = ${dir_path}
#  ${3} = ${folder}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function _sftp_add_folder_permission() {

    local username="${1}"
    local dir_path="${2}"
    local folder="${3}"

    # Create user subfolder
    mkdir -p "/home/${username}/${folder}"
    chown root "/home/${username}"

    # Log
    display --indent 6 --text "- Creating user subfolder" --result "DONE" --color GREEN
    log_event "info" "Creating user subfolder: /home/${username}/${folder}" "false"

    # Create project subfolder
    mkdir -p "${dir_path}/${folder}"
    log_event "info" "Creating subfolder ${dir_path}/${folder}" "false"

    # Mounting
    mount --bind "${dir_path}${folder}" "/home/${username}/${folder}"

    # Log
    display --indent 6 --text "- Mounting subfolder" --result "DONE" --color GREEN
    log_event "info" "Mounting subfolder ${dir_path}${folder} on /home/${username}/${folder}" "false"
    log_event "debug" "Running: mount --bind ${dir_path}${folder} /home/${username}/${folder}" "false"

    # Mount permanent
    echo "${dir_path}${folder} /home/${username}/${folder} none bind   0      0" >>"/etc/fstab"

    # Log
    display --indent 6 --text "- Writing fstab to make it permanent" --result "DONE" --color GREEN
    log_event "debug" "Running: echo ${dir_path}${folder} /home/${username}/${folder} none bind   0      0  >>/etc/fstab" "false"

    ## Refs: 
    ### https://tecadmin.net/how-to-create-sftp-user-for-a-web-server-document-root/
    ### https://serverfault.com/questions/584986/bad-ownership-or-modes-for-chroot-directory-component
    find "${dir_path}/${folder}" -type d -exec chmod 775 {} \;
    find "${dir_path}/${folder}" -type f -exec chmod 664 {} \;
    find "${dir_path}/${folder}" -type d -exec chmod g+s {} \;
    log_event "debug" "Running: find ${dir_path}${folder} -type d -exec chmod g+s {} \;" "false"

    # We want any new files created in the document root from now on to inherit the group name
    chmod g+s "${dir_path}${folder}"

    # Log
    display --indent 6 --text "- Changing folder permission" --result "DONE" --color GREEN

}

################################################################################
# Private: test sftp connection
#
# Arguments:
#  ${1} = ${username}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function _sftp_test_connection() {

    local username="${1}"

    sftp "${username}@localhost"

}

################################################################################
# Create sftp user
#
# Arguments:
#  ${1} = ${username}
#  ${2} = ${groupname}
#  ${3} = ${shell_access} (true,false)
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

# Ref: https://askubuntu.com/questions/134425/how-can-i-chroot-sftp-only-ssh-users-into-their-homes

#without-shell-access
function sftp_create_user() {

    local username="${1}"
    local userpassw="${2}"
    local groupname="${3}"
    local project_path="${4}"
    local shell_access="${5}" #no or yes

    # Non-interactive adduser
    # ref: https://askubuntu.com/questions/94060/run-adduser-non-interactively
    adduser --disabled-password --gecos "" "${username}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Creating sftp user" --result "DONE" --color GREEN
        log_event "info" "New sftp user created: ${username}"

        if [[ -z ${userpassw} ]]; then

            userpassw="$(openssl rand -hex 12)"

        fi

        # Changing password
        chpasswd <<<"${username}:${userpassw}"

        # Log
        display --indent 6 --text "- Setting sftp user password" --result "DONE" --color GREEN
        display --indent 8 --text "Password: ${userpassw}" --tcolor YELLOW
        log_event "info" "Sftp user password: ${userpassw}"

    else

        return 1
    fi

    # Add user to the groups
    usermod -aG "${groupname}" "${username}"

    _sftp_add_folder_permission "${username}" "${project_path}" "public"

    # Log
    display --indent 6 --text "- Adding user to group ${groupname}" --result "DONE" --color GREEN
    log_event "info" "User added to group ${groupname}"

    # Backup actual config
    mv "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bk"
    log_event "debug" "Running: mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bk"

    # Copy new config
    cp "${BROLIT_MAIN_DIR}/config/sftp/sshd_config" "/etc/ssh/sshd_config"
    log_event "debug" "Running: cp ${BROLIT_MAIN_DIR}/config/sftp/sshd_config /etc/ssh/sshd_config"

    # Replace SFTP_U and SFTP_PATH
    if [[ -n ${project_path} ]]; then
        sed -i "s+SFTP_U+${username}+g" "/etc/ssh/sshd_config"
        sed -i "s+SFTP_PATH+${project_path}+g" "/etc/ssh/sshd_config"
        log_event "debug" "Running: s+SFTP_U+${username}+g /etc/ssh/sshd_config"
        log_event "debug" "Running: s+SFTP_PATH+${project_path}+g /etc/ssh/sshd_config"
    else
        return 1
    fi

    # Shell Access
    if [[ ${shell_access} == "" ]]; then
        shell_access="no"
    fi

    # Replacing SHELL_ACCESS with $shell_access
    sed -i "s+SHELL_ACCESS+${shell_access}+g" "/etc/ssh/sshd_config"
    log_event "debug" "Running: s+SHELL_ACCESS+${shell_access}+g /etc/ssh/sshd_config"

    # Log
    display --indent 6 --text "- Configuring SSH access" --result "DONE" --color GREEN
    log_event "info" "SSH access configured" "false"

    # Service restart
    service sshd restart

}

################################################################################
# Create sftp group
#
# Arguments:
#  ${1} = ${groupname} #sftp_users
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function sftp_create_group() {

    local groupname="${1}"

    groupadd "${groupname}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Creating system group" --result "DONE" --color GREEN
        log_event "info" "New group created: ${groupname}" "false"

    else

        return 1

    fi

}

################################################################################
# Delete sftp user
#
# Arguments:
#  ${1} = ${username}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function sftp_delete_user() {

    local username="${1}"

    whiptail_message_with_skip_option "SFTP USER DELETE" "Are you sure you want to delete the user '${username}'? It will remove all user files."
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Remove user, home directory and mail spool
        userdel --remove "${username}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Log
            display --indent 6 --text "- Deleting system user" --result "DONE" --color GREEN
            log_event "info" "System user deleted: ${username}" "false"

        else

            return 1

        fi

    else

        # Log
        display --indent 6 --text "- Deleting system user" --result "SKIPPED" --color GREEN

    fi

}

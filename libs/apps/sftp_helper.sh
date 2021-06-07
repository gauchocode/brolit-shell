#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.33
#############################################################################

function _sftp_add_folder_permission() {

    # $1 = username
    # $2 = dir_path
    # $3 = folder

    local username=$1
    local dir_path=$2
    local folder=$3

    # Create user subfolder
    mkdir "/home/${username}/${folder}"

    # Log
    display --indent 6 --text "- Creating user subfolder" --result "DONE" --color GREEN
    log_event "info" "Creating user subfolder: /home/${username}/${folder}"

    # Create project subfolder
    mkdir "${dir_path}/${folder}"
    log_event "info" "Creating subfolder ${dir_path}/${folder}"

    # Mounting
    mount --bind "${dir_path}${folder}" "/home/${username}/${folder}"

    # Log
    display --indent 6 --text "- Mounting subfolder" --result "DONE" --color GREEN
    log_event "info" "Mounting subfolder ${dir_path}${folder} on /home/${username}/${folder}"
    log_event "debug" "Running: mount --bind ${dir_path}${folder} /home/${username}/${folder}"

    # Mount permanent
    echo "${dir_path}/${folder} /home/${username}/${folder} none bind   0      0" >>"/etc/fstab"

    # Log
    display --indent 6 --text "- Writing fstab to make it permanent" --result "DONE" --color GREEN
    log_event "debug" "Running: echo ${dir_path}${folder} /home/${username}/${folder} none bind   0      0  >>/etc/fstab"

    # The command below will set the document root and all subfolders to 775
    find "${dir_path}/${folder}" -type d -exec chmod g+s {} \;
    log_event "debug" "Running: find ${dir_path}${folder} -type d -exec chmod g+s {} \;"

    # We want any new files created in the document root from now on to inherit the group name
    chmod g+s "${dir_path}${folder}"

    # Log
    display --indent 6 --text "- Changing folder permission" --result "DONE" --color GREEN

}

function _sftp_test_conection() {

    # $1 = username

    local username=$1

    sftp "${username}@localhost"

}

#############################################################################

#without-shell-access
function sftp_create_user() {

    # $1 = username
    # $2 = groupname
    # $3 = shell_access (true,false)

    local username=$1
    local groupname=$2
    local shell_access=$3 #no or yes

    # TODO: non-interactive adduser
    # ref: https://askubuntu.com/questions/94060/run-adduser-non-interactively
    adduser "${username}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        # Log
        display --indent 6 --text "- Creating system user" --result "DONE" --color GREEN
        log_event "info" "New user created: ${username}"
    else
        return 1
    fi

    # Add user to the groups
    usermod -aG "${groupname}" "${username}"
    # Log
    display --indent 6 --text "- Adding user to group ${groupname}" --result "DONE" --color GREEN
    log_event "info" "User added to group ${groupname}"

    # Backup actual config
    mv "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.bk"
    log_event "debug" "Running: mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bk"

    # Copy new config
    cp "${SFOLDER}/config/sftp/sshd_config" "/etc/ssh/sshd_config"
    log_event "debug" "Running: cp ${SFOLDER}/config/sftp/sshd_config /etc/ssh/sshd_config"

    # Replace SFTP_U to new sftp user
    if [[ ${username} != "" ]]; then
        # Replacing SFTP_U with $username
        sed -i "s+SFTP_U+${username}+g" "/etc/ssh/sshd_config"
        log_event "debug" "Running: s+SFTP_U+${username}+g /etc/ssh/sshd_config"
        #sed -i "/SFTP_U/s/'[^']*'/'${username}'/2" "/etc/ssh/sshd_config"
        #log_event "debug" "Running: sed -i /SFTP_U/s/'[^']*'/'${username}'/2 /etc/ssh/sshd_config"
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
    log_event "info" "SSH access configured"

    # Select project to work with
    directory_browser "Select a project to work with" "${SITES}" #return $filename
    # Directory_broser returns: $filepath and $filename
    if [[ ${filename} != "" && ${filepath} != "" ]]; then
        # Create and add folder permission
        _sftp_add_folder_permission "${username}" "${filepath}/${filename}" "public"

    fi

    # Service restart
    service sshd restart

}

function sftp_create_group() {

    # $1 = groupname #sftp_users
    local groupname=$1

    groupadd "${groupname}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        # Log
        display --indent 6 --text "- Creating system group" --result "DONE" --color GREEN
        log_event "info" "New group created: ${groupname}"
    else
        return 1
    fi

}

function sftp_delete_user() {

    # $1 = username
    local username=$1

    whiptail_message_with_skip_option "SFTP USER DELETE" "Are you sure you want to delete the user '${username}'? It will remove all user files."
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Remove user, home directory and mail spool
        userdel --remove "${username}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            # Log
            display --indent 6 --text "- Deleting system user" --result "DONE" --color GREEN
            log_event "info" "System user deleted: ${username}"
        else
            return 1
        fi

    else

        # Log
        display --indent 6 --text "- Deleting system user" --result "SKIPPED" --color GREEN

    fi

}

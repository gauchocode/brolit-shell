#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.17
#############################################################################

#without-shell-access
function sftp_add_user() {

    # $1 = username
    # $2 = groupname
    # $3 = shell_access (true,false)

    local username=$1
    local groupname=$2
    local shell_access=$3 #no or yes

    # TODO: non-interactive
    # ref: https://askubuntu.com/questions/94060/run-adduser-non-interactively
    adduser "${username}"

    # Add user to the groups
    usermod -aG "${groupname}" "${username}"
    #usermod -aG www-data "${username}"

    # Backup actual config
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bk

    # Copy new config
    cp "${SFOLDER}/config/sftp/sshd_config" /etc/ssh/sshd_config

    # Replace SFTP_U to new sftp user
    if [[ ${username} != "" ]]; then
        sed -i "/SFTP_U/s/'[^']*'/'${username}'/2" "/etc/ssh/sshd_config"
    fi
    if [[ ${shell_access} = "" || ${shell_access} = "no" ]]; then

        sed -i "/SHELL_ACCESS/s/'[^']*'/'${shell_access}'/2" "/etc/ssh/sshd_config"

    else
    
        sed -i "/SHELL_ACCESS/s/'[^']*'/'${shell_access}'/2" "/etc/ssh/sshd_config"

    fi

    service sshd restart

}

function sftp_create_group() {

    # $1 = groupname #sftp_users
    local groupname=$1

    groupadd "${groupname}"

}

function sftp_test_conection() {

    # $1 = username

    local username=$1

    sftp "${username}@localhost"
}

function sftp_add_folder_permission() {

    # $1 = username
    # $2 = dir_path
    # $3 = folder

    local username=$1
    local dir_path=$2
    local folder=$3

    #mkdir
    mkdir "/home/${username}/${folder}"

    # mount
    mount --bind "${dir_path}/${folder}" "/home/${username}/${folder}"

    # mount permanent
    #cat "${dir_path}/${folder} /home/${username}/${folder} none bind   0      0"  >>"/etc/fstab"

    # The command below will set the document root and all subfolders to 775
    #find "${dir_path}/${folder}" -type d -exec chmod g+s {} \;
    # We want any new files created in the document root from now on to inherit the group name
    #chmod g+s "${dir_path}/${folder}"
}
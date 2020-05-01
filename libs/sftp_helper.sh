#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc01
#############################################################################

#without-shell-access
sftp_add_user() {

    # $1 = USERNAME
    # $2 = GROUPNAME
    # $3 = SHELL_ACCESS (true,false)

    USERNAME=$1
    GROUPNAME=$2

    #adduser --shell /bin/false ${USERNAME}
    adduser ${USERNAME}

    # add user to the groups
    usermod -aG ${GROUPNAME} ${USERNAME}
    usermod -aG www-data ${USERNAME}

    # create home dir
    #mkdir -p /var/sftp/${USERNAME}

    # In /etc/ssh/sshd_config
    # Comment: #Subsystem sftp  /usr/lib/openssh/sftp-server
    # Write:    Subsystem sftp internal-sftp
    #
    # At the end add:
    #
    # Match User webdev
    #    ChrootDirectory /var/www/
    #    ForceCommand internal-sftp -u 0022  #will prevent this user from logging in over SSH
    #    X11Forwarding no
    #    AllowTcpForwarding no
    #    PasswordAuthentication yes

    service sshd restart

    # The command below will set the document root and all subfolders to 775
    find /var/www/ -type d -exec chmod g+s {} \;
    # We want any new files created in the document root from now on to inherit the group name
    chmod g+s /var/www/

}

sftp_create_group() {

    # $1 = GROUPNAME #sftp_users
    GROUPNAME=$1

    groupadd ${GROUPNAME}

}

sftp_test_conection() {

    # $1 = USERNAME

    USERNAME=$1

    sftp ${USERNAME}@localhost
}

#!/bin/bash
set -e

printf "\n\033[0;44m---> Configuring SSH user and starting server.\033[0m\n"

# Set password at runtime (not build time)
if [ -n "${SSH_MASTER_USER}" ] && [ -n "${SSH_MASTER_PASS}" ]; then
    echo "${SSH_MASTER_USER}:${SSH_MASTER_PASS}" | chpasswd
    echo "SSH user password configured for: ${SSH_MASTER_USER}"

    # Ensure ChrootDirectory is owned by root (OpenSSH requirement)
    chown root:root /home/${SSH_MASTER_USER}
    chmod 755 /home/${SSH_MASTER_USER}

    # Ensure the application subdirectory is writable by the user
    if [ -d /home/${SSH_MASTER_USER}/application ]; then
        chown 33:33 /home/${SSH_MASTER_USER}/application
    fi
else
    echo "WARNING: SSH_MASTER_USER or SSH_MASTER_PASS not set!"
fi

# Start SSH server
service ssh start
service ssh status

exec "$@"

#!/bin/bash
set -e

printf "\n\033[0;44m---> Configuring SSH user and starting server.\033[0m\n"

# Set password at runtime (not build time)
if [ -n "${SSH_MASTER_USER}" ] && [ -n "${SSH_MASTER_PASS}" ]; then
    echo "${SSH_MASTER_USER}:${SSH_MASTER_PASS}" | chpasswd
    echo "SSH user password configured for: ${SSH_MASTER_USER}"
else
    echo "WARNING: SSH_MASTER_USER or SSH_MASTER_PASS not set!"
fi

# Start SSH server
service ssh start
service ssh status

exec "$@"

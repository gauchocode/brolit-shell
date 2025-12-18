#!/bin/bash
set -e

echo "---> Creating SSH alias user"

usermod -s /bin/bash www-data

if ! id "${SSH_MASTER_USER}" >/dev/null 2>&1; then
  useradd \
    --non-unique \
    -u 33 \
    -g 33 \
    -M \
    -s /bin/bash \
    "${SSH_MASTER_USER}"
fi

if [ ! -d /home/${SSH_MASTER_USER} ]; then
  mkdir -p /home/${SSH_MASTER_USER}
  chown 33:33 /home/${SSH_MASTER_USER}
  chmod 755 /home/${SSH_MASTER_USER}
fi

echo "${SSH_MASTER_USER}:${SSH_MASTER_PASS}" | chpasswd
#!/bin/bash
set -e

echo "---> Creating SSH alias user"

# Asegurar shell para www-data
usermod -s /bin/bash www-data

# Crear alias (mismo UID/GID)
if ! id "${SSH_MASTER_USER}" >/dev/null 2>&1; then
  useradd \
    --non-unique \
    -u 33 \
    -g 33 \
    -M \
    -s /bin/bash \
    "${SSH_MASTER_USER}"
fi

# Home propio (solo para comodidad)
if [ ! -d /home/${SSH_MASTER_USER} ]; then
  mkdir -p /home/${SSH_MASTER_USER}
  chown 33:33 /home/${SSH_MASTER_USER}
  chmod 755 /home/${SSH_MASTER_USER}
fi

# Password del alias
echo "${SSH_MASTER_USER}:${SSH_MASTER_PASS}" | chpasswd
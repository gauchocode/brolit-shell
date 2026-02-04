#!/bin/bash
set -e

echo "---> Creating SSH alias user"

usermod -s /bin/bash www-data

if [ -n "${SSH_MASTER_USER}" ]; then
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
  fi

  # ChrootDirectory requires the directory to be owned by root
  # and not writable by group/others
  chown root:root /home/${SSH_MASTER_USER}
  chmod 755 /home/${SSH_MASTER_USER}

  echo "SSH user created: ${SSH_MASTER_USER}"
else
  echo "WARNING: SSH_MASTER_USER not set, using default www-data"
fi

# Password is now set in entrypoint.sh at runtime, not during build

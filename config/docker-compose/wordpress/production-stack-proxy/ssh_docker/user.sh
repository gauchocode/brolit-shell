#!/bin/bash
set -e

printf "\n\033[0;44m---> Creating SSH master user.\033[0m\n"

# Crear grupos si no existen
groupadd -f ssh
groupadd -f sftp

# Crear usuario
useradd -m \
  -d /home/${SSH_MASTER_USER} \
  -s /bin/bash \
  -G ssh \
  ${SSH_MASTER_USER}

# Setear password
echo "${SSH_MASTER_USER}:${SSH_MASTER_PASS}" | chpasswd

# Perfil PATH
echo 'PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin"' >> /home/${SSH_MASTER_USER}/.profile
chown ${SSH_MASTER_USER}:${SSH_MASTER_USER} /home/${SSH_MASTER_USER}/.profile

# Sudo sin romper sudoers
cat <<EOF > /etc/sudoers.d/${SSH_MASTER_USER}
${SSH_MASTER_USER} ALL=NOPASSWD:/bin/rm
${SSH_MASTER_USER} ALL=NOPASSWD:/bin/mkdir
${SSH_MASTER_USER} ALL=NOPASSWD:/bin/chown
${SSH_MASTER_USER} ALL=NOPASSWD:/usr/sbin/useradd
${SSH_MASTER_USER} ALL=NOPASSWD:/usr/sbin/deluser
${SSH_MASTER_USER} ALL=NOPASSWD:/usr/sbin/chpasswd
EOF

chmod 0440 /etc/sudoers.d/${SSH_MASTER_USER}

# Agregar a www-data (CORRECTO)
usermod -aG www-data ${SSH_MASTER_USER}

#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
#############################################################################

### VARS
NETDATA_SUBDOMAIN=""                             # Domain for Netdata. Example: monitor.broobe.com
ROOT_DOMAIN=""                                   # Only for Cloudflare API. Example: broobe.com

### Checking some things... ###
if [[ -z "${NETDATA_SUBDOMAIN}" || -z "${ROOT_DOMAIN}" || -z "${MPASS}" ]]; then
  echo -e ${RED}" > Error: NETDATA_SUBDOMAIN, ROOT_DOMAIN and MPASS must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

#TODO: ya dejar configurada las extensiones
echo -e ${YELLOW}"\nInstalling Netdata...\n"${ENDCOLOR}
apt --yes install zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python-mysqldb
git clone https://github.com/firehol/netdata.git --depth=1
cd netdata && ./netdata-installer.sh --dont-wait
killall netdata && cp system/netdata.service /etc/systemd/system/

#netdata nginx proxy configuration
cp confs/monitor /etc/nginx/sites-available
sed -i "s#dominio.com#${NETDATA_SUBDOMAIN}#" /etc/nginx/sites-available/monitor
ln -s /etc/nginx/sites-available/monitor /etc/nginx/sites-enabled/monitor

#TODO: Agregar otras confs y la config de las notificaciones
#TODO: Checkear si mandando la conf a /usr/share/netdata hace que con un update de netdata no se borre la config
#TODO: Acá hay que hacer un sed para agregar el pass de root (quiza hasta sea menor ni copiar el mysql.conf)
cat confs/netdata/python.d/mysql.conf > /usr/lib/netdata/conf.d/python.d/mysql.conf
cat confs/netdata/python.d/monit.conf > /usr/lib/netdata/conf.d/python.d/monit.conf
cat confs/netdata/health_alarm_notify.conf > /usr/lib/netdata/conf.d/health_alarm_notify.conf

SQL1="CREATE USER 'netdata'@'localhost';"
SQL2="GRANT USAGE on *.* to 'netdata'@'localhost';"
SQL3="FLUSH PRIVILEGES;"

echo "Creating netdata user in MySQL ..." >> $LOG
mysql -u root -p${MPASS} -e "${SQL1}${SQL2}${SQL3}" >> $LOG

systemctl daemon-reload && systemctl enable netdata && service netdata start

echo -e ${GREEN}" > DONE"${ENDCOLOR}

# Usamos cloudflare API para modificar o agregar el registro de DNS sobre el dominio en cuestión
echo -e ${YELLOW}" > Trying to access Cloudflare API and change record ${NETDATA_SUBDOMAIN} ..."  >> $LOG
zone_name=${ROOT_DOMAIN}
record_name=${NETDATA_SUBDOMAIN}
export zone_name record_name
${SFOLDER}/utils/cloudflare_update_IP.sh

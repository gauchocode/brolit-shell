#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
#############################################################################

SCRIPT_V="2.9"

### VARS
FOLDER_TO_RESTORE="/var/www"

SITES_F="sites"
CONFIG_F="configs"
DBS_F="databases"

# TODO: otra opcion 'complete_site' para que intente restaurar archivos y base de un proyecto
# TODO: otra opcion 'multi_sites' para que intente restaurar sitios que estan backupeados en dropbox

#Restore Local?
#$SFOLDER/tmp/backups/*.tar.gz

### Checking some things
if [ $USER != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi

if test -f /root/.broobe-utils-options ; then
  source /root/.broobe-utils-options
fi

# TODO: en realidad no debo preguntarlo, debo cortar, la idea es que el script corra desde runner.sh y no individualmente
# Display dialog to imput MySQL root pass and then store it into a hidden file
if [[ -z "${MPASS}" ]]; then
  MPASS=$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root Password" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          #TODO: testear el password antes de guardarlo
          echo "MPASS="${MPASS} >> /root/.broobe-utils-options
  fi
fi

RESTORE_TYPES="${CONFIG_F} ${DBS_F} ${SITES_F}"

# Display choose dialog with available backups
CHOSEN_TYPE=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Type" 20 78 10 `for x in ${RESTORE_TYPES}; do echo "$x [D]"; done` 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
        #Restore from Dropbox
        DROPBOX_PROJECT_LIST=$(${DPU_F}/dropbox_uploader.sh -hq list ${CHOSEN_TYPE})
fi
if [[ ${CHOSEN_TYPE} == *"$CONFIG_F"* ]]; then
  CHOSEN_CONFIG=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Chose Configs Backup" 20 78 10 `for x in ${DROPBOX_PROJECT_LIST}; do echo "$x [F]"; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          cd tmp/

          #echo "Trying to run dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}"
          ${DPU_F}/dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}

          # Restore files
          mkdir ${CHOSEN_TYPE}
          mv ${CHOSEN_CONFIG} ${CHOSEN_TYPE}
          cd ${CHOSEN_TYPE}
          tar -xvjf ${CHOSEN_CONFIG}
  fi
else
  # Select Project
  CHOSEN_PROJECT=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup Project" 20 78 10 `for x in ${DROPBOX_PROJECT_LIST}; do echo "$x [D]"; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          #echo "Trying to run ${SFOLDER}/dropbox_uploader.sh list ${CHOSEN_TYPE}/${CHOSEN_PROJECT}"
          DROPBOX_BACKUP_LIST=$(${DPU_F}/dropbox_uploader.sh -hq list ${CHOSEN_TYPE}/${CHOSEN_PROJECT})
  fi
  # Select Backup File
  CHOSEN_BACKUP=$(whiptail --title "RESTORE BACKUP" --menu "Chose Backup to Download" 20 78 10 `for x in ${DROPBOX_BACKUP_LIST}; do echo "$x [F]"; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

          #echo "Trying to run dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}"
          ${DPU_F}/dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}

          mv ${CHOSEN_BACKUP} tmp/
          cd tmp/

          # ucompress files
          echo "Ucompressing ${CHOSEN_BACKUP}"
          tar -xvjf ${CHOSEN_BACKUP}

          if [[ ${CHOSEN_TYPE} == *"$SITES_F"* ]]; then
            # Restore files
            echo "Trying to restore ${CHOSEN_BACKUP} files"

            # Moving old files
            # echo "Trying to execute: mkdir ${SFOLDER}/tmp/old_backup ..."
            mkdir ${SFOLDER}/tmp/old_backup
            #echo "Executing: mv ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT} ${SFOLDER}/tmp/old_backup ..."
            mv ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT} ${SFOLDER}/tmp/old_backup

            #echo "Executing: mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_RESTORE} ..."
            mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_RESTORE}

            echo "Executing: chown -R www-data:www-data ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT} ..."
            chown -R www-data:www-data ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT}

            # TODO: ver si se puede restaurar un viejo backup del site-available de nginx y luego
            # forzar al certbot (si existe manera, por que el renew no funciona y la instalacion normal tampoco)

            echo "Trying to restore nginx config for ${CHOSEN_PROJECT} ..."
            # New site configuration
            cp ${SFOLDER}/confs/default /etc/nginx/sites-available/${CHOSEN_PROJECT}
            ln -s /etc/nginx/sites-available/${CHOSEN_PROJECT} /etc/nginx/sites-enabled/${CHOSEN_PROJECT}
            # Replacing string to match domain name
            sed -i "s#dominio.com#${CHOSEN_PROJECT}#" /etc/nginx/sites-available/${CHOSEN_PROJECT}
            # Need to be run twice
            sed -i "s#dominio.com#${CHOSEN_PROJECT}#" /etc/nginx/sites-available/${CHOSEN_PROJECT}
            service nginx reload

          else
            if [[ ${CHOSEN_TYPE} == *"$DBS_F"* ]]; then
              # Si es una BD
              # TODO: contemplar 2 opciones: base existente y base inexistente (habría que crear el usuario)

              echo "Trying to restore ${CHOSEN_BACKUP} DB"

              echo "Executing mysqldump (will work if database exists)..."
              mysqldump -u root --password=${MPASS} ${CHOSEN_PROJECT} > ${CHOSEN_PROJECT}_bk_before_restore.sql

              ### Helper para extraer el nombre del proyecto

              ### TODO: debería extraer el sufijo real y no asumir que es _prod
              suffix="_prod"
              PROJECT_STAGE="prod"
              PROJECT_NAME=${CHOSEN_PROJECT%"$suffix"}
              #echo "${PROJECT_NAME}"

              ### Vamos a crear el usuario y la base siguiendo el nuevo estandard de broobe

              ### TODO: ojo que me cambia el pass en el wp-config.php por más que el usuario exista, CORREGIR!!!
              DB_PASS=$(openssl rand -hex 12)

              #para cambiar pass de un user existente
              #ALTER USER 'makana_user'@'localhost' IDENTIFIED BY '0p2eE2a0ed4d8=';

              SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STAGE};"
              SQL2="CREATE USER IF NOT EXISTS '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
              SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STAGE} . * TO '${PROJECT_NAME}_user'@'localhost';"
              SQL4="FLUSH PRIVILEGES;"

              echo "Creating database ${PROJECT_NAME}_${PROJECT_STAGE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} if they not exist ..."
              mysql -u root --password=${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}"

              # tercero importar la base a restaurar
              echo "Restoring database ..."
              mysql -u root --password=${MPASS} ${PROJECT_NAME}_${PROJECT_STAGE} < ${CHOSEN_BACKUP%%.*}.sql

              echo "DB ${CHOSEN_BACKUP} restored!"

              echo "Cleanning tmp files ..."
              rm ${CHOSEN_BACKUP%%.*}.sql
              rm ${CHOSEN_BACKUP}
              echo "OK ..."

              echo -e ${YELLOW}"Trying to find a directory matching the database imported ..."${ENDCOLOR}
              for j in $(find $FOLDER_TO_RESTORE -maxdepth 1 -type d)
              do
                FOLDER_NAME=$(basename $j)

                # TODO: quizarle al project name - y caracteres especiales

                if [[ ${FOLDER_NAME} == *"${PROJECT_NAME}"* ]]; then
                  echo -e ${GREEN}" Matching directory found: ${FOLDER_NAME}"${ENDCOLOR}
                  #change wp-config.php database parameters
                  echo "Changing wp-config.php database parameters ..."
                  sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" ${j}/wp-config.php
                  sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_${PROJECT_STAGE}'/2" ${j}/wp-config.php
                  sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" ${j}/wp-config.php
                  sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASS}'/2" ${j}/wp-config.php

                  # TODO: cambiar las secret encryption key

                  echo -e ${GREEN}" > DONE"${ENDCOLOR}

                fi
              done

              # TODO: Checkeamos Cloudflare si es la misma IP y si no cambiamos?

              # echo "Trying to execute certbot for ${CHOSEN_PROJECT} ..."
              # TODO: certbot --nginx -d ${CHOSEN_PROJECT} -d www.${CHOSEN_PROJECT}
              # certbot --nginx -d ${CHOSEN_PROJECT} -d www.${CHOSEN_PROJECT}

            fi
          fi

  fi
fi

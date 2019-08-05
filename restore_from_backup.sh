#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.7
################################################################################

# TODO: ARREGLAR RESTORE DE BD! el matching directory es un peligro!
# y ni hablar de cambiar el wp-config sin checkear los datos del usuario creado.

SCRIPT_V="2.9.7"

# TODO: otra opcion 'complete_site' para que intente restaurar archivos y base de un proyecto
# TODO: otra opcion 'multi_sites' para que intente restaurar sitios que estan backupeados en dropbox

#Restore Local?
#$SFOLDER/tmp/backups/*.tar.gz

source ${SFOLDER}/libs/commons.sh

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

SITES_F="sites"
CONFIG_F="configs"
DBS_F="databases"

RESTORE_TYPES="${SITES_F} ${CONFIG_F} ${DBS_F}"

# Display choose dialog with available backups
CHOSEN_TYPE=$(whiptail --title "RESTORE BACKUP" --menu "Choose a backup type. If you want to restore an entire site, first restore the site files, then the config, and last the database." 20 78 10 `for x in ${RESTORE_TYPES}; do echo "$x [D]"; done` 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
        #Restore from Dropbox
        DROPBOX_PROJECT_LIST=$(${DPU_F}/dropbox_uploader.sh -hq list ${CHOSEN_TYPE})
fi

if [[ ${CHOSEN_TYPE} == *"$CONFIG_F"* ]]; then
  CHOSEN_CONFIG=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Chose Configs Backup" 20 78 10 `for x in ${DROPBOX_PROJECT_LIST}; do echo "$x [F]"; done` 3>&1 1>&2 2>&3)
  exitstatus=$?

  if [ $exitstatus = 0 ]; then

          cd ${SFOLDER}/tmp

          echo " > Downloading from Dropbox ${CHOSEN_TYPE}/${CHOSEN_CONFIG} ..." >> $LOG
          echo -e ${YELLOW}" > Trying to run ${DPU_F}/dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}"${ENDCOLOR}
          ${DPU_F}/dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_CONFIG}

          # Restore files
          mkdir ${CHOSEN_TYPE}
          mv ${CHOSEN_CONFIG} ${CHOSEN_TYPE}
          cd ${CHOSEN_TYPE}

          echo "Uncompressing ${CHOSEN_CONFIG}">> $LOG
          echo -e ${YELLOW} "Uncompressing ${CHOSEN_CONFIG}" ${ENDCOLOR}
          tar -xvjf ${CHOSEN_CONFIG}

          # TODO: intentar backupear config actual e instalar el nuevo (aplica a todo)

          if [[ "${CHOSEN_CONFIG}" == *"webserver"* ]];then

            # TODO: si es nginx, preguntar si queremos copiar nginx.conf

            # Checking that default webserver folder exists
            if [[ -n "${WSERVER}" ]]; then

              echo -e ${GREEN} " > Folder ${WSERVER} exists ... OK" ${ENDCOLOR}

              startdir="${SFOLDER}/tmp/${CHOSEN_TYPE}/sites-available"
              Filebrowser "$menutitle" "$startdir"

              to_restore=$filepath"/"$filename
              echo -e ${YELLOW}" > File to restore: ${to_restore} ..."${ENDCOLOR}

              if [[ -f "${WSERVER}/sites-available/${filename}" ]]; then

                echo " > File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ...">>$LOG
                echo -e ${YELLOW}" > File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ..."${ENDCOLOR}
                mv ${WSERVER}/sites-available/${filename} ${WSERVER}/sites-available/${filename}_bk

                echo " > Restoring backup: ${filename} ...">>$LOG
                echo -e ${YELLOW}" > Restoring backup: ${filename} ..."${ENDCOLOR}
                cp $to_restore ${WSERVER}/sites-available/$filename

                echo " > Reloading webserver ...">>$LOG
                echo -e ${YELLOW}" > Reloading webserver ..."${ENDCOLOR}
                service nginx reload

              else
                echo -e ${GREEN}" > File ${WSERVER}/sites-available/${filename} does NOT exists ..."${ENDCOLOR}

                echo " > Restoring backup: ${filename} ...">>$LOG
                echo -e ${YELLOW}" > Restoring backup: ${filename} ..."${ENDCOLOR}
                cp $to_restore ${WSERVER}/sites-available/$filename
                ln -s ${WSERVER}/sites-available/$filename ${WSERVER}/sites-enabled/$filename

                echo " > Reloading webserver ...">>$LOG
                echo -e ${YELLOW}" > Reloading webserver ..."${ENDCOLOR}
                service nginx reload

              fi

            else

              echo -e ${RED} " /etc/nginx/sites-available NOT exist... Quiting!" ${ENDCOLOR}

            fi

          fi
          if [[ "${CHOSEN_CONFIG}" == *"mysql"* ]];then
            echo "TODO: RESTORE MYSQL CONFIG ..."
          fi
          if [[ "${CHOSEN_CONFIG}" == *"php"* ]];then
            echo "TODO: RESTORE PHP CONFIG ..."
          fi

          echo " > Removing ${SFOLDER}/tmp/${CHOSEN_TYPE} ..." >> $LOG
          echo -e ${GREEN}" > Removing ${SFOLDER}/tmp/${CHOSEN_TYPE} ..."${ENDCOLOR}
          rm -R ${SFOLDER}/tmp/${CHOSEN_TYPE}

          echo " > DONE ...">>$LOG
          echo -e ${GREEN}" > DONE ..."${ENDCOLOR}

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
  CHOSEN_BACKUP=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 `for x in ${DROPBOX_BACKUP_LIST}; do echo "$x [F]"; done` 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

          cd ${SFOLDER}/tmp

          echo " > Downloading from Dropbox ${CHOSEN_TYPE}/${CHOSEN_CONFIG} ..." >> $LOG
          echo -e ${YELLOW} " > Trying to run ${DPU_F}/dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}" ${ENDCOLOR}
          ${DPU_F}/dropbox_uploader.sh download ${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}

          echo " > Uncompressing ${CHOSEN_BACKUP}">> $LOG
          tar -xvjf ${CHOSEN_BACKUP}

          if [[ ${CHOSEN_TYPE} == *"$SITES_F"* ]]; then

            FolderToRestore

            ACTUAL_FOLDER="${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT}"

            if [ -n "${ACTUAL_FOLDER}" ]; then

              echo " > ${ACTUAL_FOLDER} exist. Let's make a Backup ...">> $LOG
              echo -e ${YELLOW}" > ${ACTUAL_FOLDER} exist. Let's make a Backup ..."${ENDCOLOR}

              mkdir ${SFOLDER}/tmp/old_backup
              mv ${ACTUAL_FOLDER} ${SFOLDER}/tmp/old_backup

              echo " > Backup completed and stored here: ${SFOLDER}/tmp/old_backup ...">> $LOG
              echo -e ${GREEN}" > Backup completed and stored here: ${SFOLDER}/tmp/old_backup ..."${ENDCOLOR}

            fi

            # Restore files
            echo "Trying to restore ${CHOSEN_BACKUP} files ...">> $LOG
            echo -e ${YELLOW} "Trying to restore ${CHOSEN_BACKUP} files ..."${ENDCOLOR}

            #echo "Executing: mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_RESTORE} ..."
            mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_RESTORE}

            echo -e ${YELLOW} "Executing: chown -R www-data:www-data ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT} ..."${ENDCOLOR}
            chown -R www-data:www-data ${FOLDER_TO_RESTORE}/${CHOSEN_PROJECT}

            # TODO: ver si se puede restaurar un viejo backup del site-available de nginx y luego
            # forzar al certbot (si existe manera, por que el renew no funciona y la instalacion normal tampoco)

            #echo "Trying to restore nginx config for ${CHOSEN_PROJECT} ..."
            # New site configuration
            #cp ${SFOLDER}/confs/default /etc/nginx/sites-available/${CHOSEN_PROJECT}
            #ln -s /etc/nginx/sites-available/${CHOSEN_PROJECT} /etc/nginx/sites-enabled/${CHOSEN_PROJECT}
            # Replacing string to match domain name
            #sed -i "s#dominio.com#${CHOSEN_PROJECT}#" /etc/nginx/sites-available/${CHOSEN_PROJECT}
            # Need to be run twice
            #sed -i "s#dominio.com#${CHOSEN_PROJECT}#" /etc/nginx/sites-available/${CHOSEN_PROJECT}
            #service nginx reload

          else
            if [[ ${CHOSEN_TYPE} == *"$DBS_F"* ]]; then

              # Si es una BD
              # TODO: contemplar 2 opciones: base existente y base inexistente (habría que crear el usuario)

              if [ -d /var/lib/mysql/databasename ] ; then
                echo -e ${YELLOW}" > Executing mysqldump (will work if database exists) ..."${ENDCOLOR}
                mysqldump -u ${MUSER} --password=${MPASS} ${CHOSEN_PROJECT} > ${CHOSEN_PROJECT}_bk_before_restore.sql
              fi

              echo " > Trying to restore ${CHOSEN_BACKUP} DB">> $LOG
              echo -e ${YELLOW}" > Trying to restore ${CHOSEN_BACKUP} DB"${ENDCOLOR}

              ### TODO?: debería extraer el sufijo real y no preguntar? mnmnm
              ChooseProjectState

              suffix="$(cut -d'_' -f2 <<<"${CHOSEN_PROJECT}")"
              #echo "$A"
              #two

              #suffix="_${PROJECT_STATE}"

              ### Extract PROJECT_NAME
              PROJECT_NAME=${CHOSEN_PROJECT%"_$suffix"}

              PROJECT_NAME=$(whiptail --title "Project Name" --inputbox "Want to change the project name?" 10 60 "${PROJECT_NAME}" 3>&1 1>&2 2>&3)
              exitstatus=$?
              if [ $exitstatus = 0 ]; then
                echo "Setting PROJECT_NAME="${PROJECT_NAME} >> $LOG
              #else
              #  exit 1
              fi

              echo " > Creating user and database ...">>$LOG
              echo -e ${YELLOW}" > Creating user and database ..."${ENDCOLOR}

              ### TODO: ojo que me cambia el pass en el wp-config.php por más que el usuario exista, CORREGIR!!!
              DB_PASS=$(openssl rand -hex 12)

              #para cambiar pass de un user existente
              #ALTER USER 'makana_user'@'localhost' IDENTIFIED BY '0p2eE2a0ed4d8=';

              SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
              SQL2="CREATE USER IF NOT EXISTS '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
              SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
              SQL4="FLUSH PRIVILEGES;"

              echo "Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} if they not exist ...">> $LOG
              echo -e ${CYAN}"Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} if they not exist ..."${ENDCOLOR}

              mysql -u ${MUSER} --password=${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}"

              if [ $? -eq 0 ]; then
                echo " > DONE!">>$LOG
                echo -e ${GREN}" > DONE!"${ENDCOLOR}
              else
                echo " > Something went wrong!">>$LOG
                echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
                exit 1
              fi

              # Trying to restore Database
              pv ${CHOSEN_BACKUP%%.*}.sql | mysql -f -u ${MUSER} --password=${MPASS} ${PROJECT_NAME}_${PROJECT_STATE}

              if [ $? -eq 0 ]; then
                echo " > DB ${CHOSEN_BACKUP} restored successfully!">>$LOG
                echo -e ${GREN}" > DB ${CHOSEN_BACKUP} restored successfully!"${ENDCOLOR}
              else
                echo " > DB ${CHOSEN_BACKUP} restored failed!">>$LOG
                echo -e ${RED}" > DB ${CHOSEN_BACKUP} restored failed!"${ENDCOLOR}
                exit 1
              fi

              echo " > Cleanning tmp files ..."
              rm ${CHOSEN_BACKUP%%.*}.sql
              rm ${CHOSEN_BACKUP}
              echo " > DONE"

              FolderToRestore

              echo -e ${YELLOW}"Trying to find a directory matching the database imported ..."${ENDCOLOR}
              for j in $(find $FOLDER_TO_RESTORE -maxdepth 1 -type d)
              do
                FOLDER_NAME=$(basename $j)

                # TODO: quizarle al project name - y caracteres especiales

                # TOFIX: ESTO ES SUPER PELIGROSO, NO SIRVE CUANDO HAY VARIOS SUBDOMINIOS DE UN MISMO PROYECTO
                if [[ ${FOLDER_NAME} == *"${PROJECT_NAME}"* ]]; then
                  echo -e ${GREEN}" Matching directory found: ${FOLDER_NAME}"${ENDCOLOR}
                  #change wp-config.php database parameters
                  echo "Changing wp-config.php database parameters ..."
                  sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" ${j}/wp-config.php
                  sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_${PROJECT_STATE}'/2" ${j}/wp-config.php
                  sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" ${j}/wp-config.php
                  sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASS}'/2" ${j}/wp-config.php

                  # TODO: cambiar las secret encryption key

                  echo -e ${GREEN}" > DONE"${ENDCOLOR}
                else
                  echo -e ${RED}" > DIDN'T FIND A MATCHING DIRECTORY!"${ENDCOLOR}

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

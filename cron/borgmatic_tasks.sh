#!/bin/bash

# Por cada direcorio existenten en /www/var generar un archivo .yml

group="broobe-hosts"
hostname="brolit-dev"

directorio="/var/www"

if [ ! -d "$directorio" ]; then
	echo "El directorio '$directorio' no existe"
	exit 1
fi

	# Iteramos las carpetas sobre el directorio

for carpeta in "$directorio"/*; do
if [ -d "$carpeta" ]; then
		nombre_carpeta=$(basename "$carpeta")
		archivo_yml="$nombre_carpeta.yml"

		if [ $nombre_carpeta == "html" ]; then
			continue
		fi

		if [ ! -f "/etc/borgmatic.d/$archivo_yml" ]; then
			borgmatic config generate --destination "/etc/borgmatic.d/$archivo_yml"
			cp /root/brolit-shell/config/borg/borgmatic.template.yml "/etc/borgmatic.d/$archivo_yml"

			PROJECT=$nombre_carpeta yq -i '.constants.project = strenv(PROJECT)' "/etc/borgmatic.d/$archivo_yml"
			GROUP=$group yq -i '.constants.group = strenv(GROUP)' "/etc/borgmatic.d/$archivo_yml"
			HOST=$hostname yq -i '.constants.hostname = strenv(HOST)' "/etc/borgmatic.d/$archivo_yml"
			echo "Archivo $archivo_yml generado."
			echo "Esperando 3 segundos..."
			sleep 3
		else
			echo "El archivo $archivo_yml ya existe."	
			sleep 1
		fi	
		echo "Inicializando repo"
		ssh -p23 u372319@u372319.your-storagebox.de 'mkdir -p /home/applications/'$group'/'$hostname'/projects-online/site/'$nombre_carpeta''
		sleep 1
		borgmatic init --encryption=none --config "/etc/borgmatic.d/$archivo_yml"
	fi
done
#!/bin/bash

# Por cada direcorio existenten en /www/var generar un archivo .yml

directorio="/var/www"

if [ ! -d "$directorio" ]; then
	echo "El directorio '$directorio' no existe"
	exit 1
fi

	# Iteramos las carpetas sobre el directorio

for carpeta in "$directorio"/*; do
	if [[ -d $carpeta ]]; then
		nombre_carpeta=$(basename "$carpeta")
		archivo_yml="$nombre_carpeta.yml"

		if [ ! -f "/etc/borgmatic.d/$archivo_yml" ]; then
			borgmatic config generate --destination "/etc/borgmatic.d/$archivo_yml"
			cp borgmatic.template.yml "/etc/borgmatic.d/$archivo_yml"

			PROJECT=$nombre_carpeta yq -i '.constants.project = strenv(PROJECT)' "/etc/borgmatic.d/$archivo_yml"
			yq -i '.constants.group = "broobe-hosts"' "/etc/borgmatic.d/$archivo_yml"
			HOST="broobe-docker-host01-clusc" yq -i '.constants.hostname = strenv(HOST)' "/etc/borgmatic.d/$archivo_yml"
			echo "Archivo $archivo_yml generado."
			echo "Esperando 5 segundos..."
			sleep 5
		else
			echo "El archivo $archivo_yml ya existe."	
			sleep 1
		fi	

	fi
done
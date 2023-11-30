#!/bin/bash

# Por cada direcorio existenten en /www/var generar un archivo .yml

directorio="/var/www"

if [ !d "$directorio" ]; then
	echo "El directorio '$directorio' no existe"
	exit 1
fi

	# Iteramos las carpetas sobre el directorio

for carpeta in "$directorio"/*; do
	if [[ -d $carpeta ]]; then
		nombre_carpeta=$(basename "$carpeta")
		archivo_yml="$nombre_carpeta.yml"

		borgmatic config generate --destination "/etc/borgmatic.d/$archivo_yml"
		echo "Esperando 5 segundos..."
		sleep 5

	echo "Archivo $archivo_yml generado."
	fi
done
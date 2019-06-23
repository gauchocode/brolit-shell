#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.5
#############################################################################

# TODO step by step
#
# 1- Listar Sitios instalados en el VPS donde se ejecuta el script
# 2- Pedir que tipo de ambiente se va a querer replicar: test, dev o stage
# 3- Preguntar si es local o remoto. En caso de ser remoto, pedir credenciales de VPS a donde se va a crear.
# 4- Crear dump de BD en cuestión y dejarlo en un temp
# 5- Tirar un rsync de los archivos y BD
# 6- Usar esto: https://stackoverflow.com/questions/28360288/ssh-remotely-run-a-script-and-stay-there
#    para poder ejecutar parte del script de manera remota. Ya que en el nuevo VPS hay que armar el nuevo ambiente
#    y acá se replica lo que se hizo en otros scripts, se crea BD y usuario, se pasa los archivos a /var/www
#    se asigna los permisos a las carpetas y se intenta levantar el site configurando nginx y cloudflare.

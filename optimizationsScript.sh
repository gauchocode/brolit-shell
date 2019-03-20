#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.0
#############################################################################

### Remove old packages from system ###
apt clean
apt-get -y autoremove
apt-get -y autoclean

### Remove old log files from system ###
find /var/log/ -mtime +7 -type f -delete

# Optimización de imágenes (.jpg) para archivos modificados en los últimos 7 días
cd $SITES
find -mtime -7 -type f -name "*.jpg" -exec jpegoptim --max=80 --strip-all {} \;

# Optimización de imágenes (.png) para archivos modificados en los últimos 7 días
find -mtime -7 -type f -name "*.png" -exec optipng -o7 -strip all {} \;

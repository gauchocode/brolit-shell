#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.5
#############################################################################
#
SCRIPT_V="2.5"

DOMAIN=""                                    # Domain for WP installation. Example: landing.broobe.com
ROOT_DOMAIN=""                               # Only for Cloudflare API. Example: broobe.com
PROJECT_NAME=""                              # Project Name. Example: landing_broobe

EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
then
    >&2 echo 'ERROR: Invalid installer signature' >>$LOG
    rm composer-setup.php
    exit 1
fi
php composer-setup.php --quiet
RESULT=$?
rm composer-setup.php
exit $RESULT

echo -e ${GREEN}" > Everything is DONE! ..."${ENDCOLOR}

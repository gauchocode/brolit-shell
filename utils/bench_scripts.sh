#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################

# TODO: Una opcion de whiptail por script y cada uno con un sub-menu
# https://github.com/haydenjames/bench-scripts

echo -e ${GREEN} " > Running benchmark ..." ${ENDCOLOR}
echo " > Running benchmark ..." >>$LOG

(curl -s wget.racing/nench.sh | bash; curl -s wget.racing/nench.sh | bash) 2>&1 | tee benchmark_nench.log

echo -e ${GREEN} " > DONE" ${ENDCOLOR}
echo " > DONE" >>$LOG

main_menu
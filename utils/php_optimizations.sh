#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.11
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/php_helper.sh
source "${SFOLDER}/libs/php_helper.sh"

################################################################################

log_event "info" "RUNNING PHP OPTIMIZATION TOOL"

log_subsection "PHP Optimization Tool"

php_fpm_optimizations
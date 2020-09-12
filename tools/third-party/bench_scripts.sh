#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.1
################################################################################
#
# Ref: https://github.com/haydenjames/bench-scripts
#

log_event "info" "Running Benchmark ..." "true"

(curl -s wget.racing/nench.sh | bash; curl -s wget.racing/nench.sh | bash) 2>&1 | tee benchmark_nench.log

log_event "info" "Benchmark finished" "true"

main_menu
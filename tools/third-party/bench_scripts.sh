#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.50
################################################################################
#
# Ref: https://github.com/haydenjames/bench-scripts
#

log_event "info" "Running Benchmark ..." "true"

(curl -s wget.racing/nench.sh | bash; curl -s wget.racing/nench.sh | bash) 2>&1 | tee benchmark_nench.log

log_event "info" "Benchmark finished" "true"

menu_main_options
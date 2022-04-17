#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc1
################################################################################
#
# Loki Installer
#
#   Ref: https://grafana.com/docs/loki/latest/installation/docker/
#
################################################################################

function loki_installer() {

    log_subsection "Loki Installer"

    # Download loki config
    wget https://raw.githubusercontent.com/grafana/loki/v2.4.1/cmd/loki/loki-local-config.yaml -O loki-config.yaml
    
    # Run loki
    docker run --name loki -v $(pwd):/mnt/config -p 3100:3100 grafana/loki:2.4.1 -config.file=/mnt/config/loki-config.yaml
    
    # Download promtail config
    wget https://raw.githubusercontent.com/grafana/loki/v2.4.1/clients/cmd/promtail/promtail-docker-config.yaml -O promtail-config.yaml
    
    # Run promtail
    docker run -v $(pwd):/mnt/config -v /var/log:/var/log --link loki grafana/promtail:2.4.1 -config.file=/mnt/config/promtail-config.yaml

}

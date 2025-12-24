#!/bin/bash

# Source docker helper to use docker_find_mysql_containers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../libs/apps/docker_helper.sh"

# Get a list of all running MySQL/MariaDB containers using multiple detection methods
running_containers=$(docker_find_mysql_containers)

if [[ -z "$running_containers" ]]; then
    #echo "No MySQL containers are running."
    exit 1
else
    # Loop through each container and check its status
    for container in $running_containers; do
        # Chequear si el contenedor responde a un simple query
        if ! docker exec "$container" mysqladmin ping -h 127.0.0.1 --silent; then
            #echo "MySQL container $container is not responding."
            exit 1
        fi
    done
fi

#echo "All MySQL containers are running and responding."
exit 0

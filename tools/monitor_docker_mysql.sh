#!/bin/bash

# Get a list of all running containers with "mysql" in their name
running_containers=$(docker ps --filter "ancestor=mysql" --format "{{.Names}}")

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

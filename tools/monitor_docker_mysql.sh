#!/bin/bash

# Get a list of all running containers with "mysql" in their name
containers=$(docker ps --filter "name=mysql" --format "{{.ID}}")

# Loop through each container and check its status
if [ -n "$containers" ]; then
  for container in $containers; do
    status=$(docker inspect --format '{{.State.Running}}' "$container")
    if [ "$status" != "true" ]; then
      #echo "Container $container is not running"
      exit 1
    fi
  done
  exit 0
else
  #echo "No MySQL containers found"
  exit 0
fi

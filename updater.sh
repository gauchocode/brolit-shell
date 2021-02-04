#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
#############################################################################

SCRIPT="$(readlink -f "$0")"
SCRIPTFILE="$(basename "${SCRIPT}")"
SCRIPTPATH="$(dirname "${SCRIPT}")"
SCRIPTNAME="$0"
ARGS=( "$@" )
BRANCH="master"

self_update() {

    # Store credentials on first git pull
    git config --global credential.helper store

    git fetch

    [ -n "$(git diff --name-only "origin/${BRANCH}" "${SCRIPTFILE}")" ] && {
        echo "Found a new version of LEMP Script Utils, updating ..."

        git checkout "${BRANCH}"
        git reset --hard origin/master
        git pull --ff-only --force
        
        chmod +x runner.sh updater.sh

        exit 1
    }
    
    echo "Already the latest version."

}

#############################################################################

self_update

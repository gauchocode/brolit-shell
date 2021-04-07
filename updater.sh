#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.22
#############################################################################

SCRIPT="$(readlink -f "$0")"
SCRIPTFILE="$(basename "${SCRIPT}")"
SCRIPTPATH="$(dirname "${SCRIPT}")"
SCRIPTNAME="$0"
ARGS=("$@")
BRANCH="master"

# Foreground/Text Colours
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
ENDCOLOR='\033[0m'

function _self_update() {

    # Store credentials on first git pull
    git config --global credential.helper store

    git fetch

    [ -n "$(git diff --name-only "origin/${BRANCH}" "${SCRIPTFILE}")" ] && {

        echo -e "${GREEN}Found a new version of LEMP Script Utils, updating ...${ENDCOLOR}"

        git checkout "${BRANCH}"
        git reset --hard origin/master
        git pull --ff-only --force

        find ./ -name "*.sh" -exec chmod +x {} \;

        exit 1

    }

    echo -e "${YELLOW}Already the latest version.${ENDCOLOR}"

}

#############################################################################

_self_update

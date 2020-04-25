#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc01
#############################################################################

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
SCRIPTNAME="$0"
ARGS="$@"
BRANCH="https://github.com/lpadula/lemp-ubuntu-utils.git"

self_update() {
    cd ${SCRIPTPATH}
    git fetch

    [ -n "$(git diff --name-only origin/$BRANCH | grep ${SCRIPTNAME})" ] && {
        echo "Found a new version, updating ..."
        git pull --force
        git checkout ${BRANCH}
        git pull --force
        echo "Running the new version..."
        exec "${SCRIPTNAME}" "$@"

        # Now exit this old instance
        exit 1
    }
    echo "Already the latest version."
}

main() {
    echo "Running updater ..."
}

self_update
main

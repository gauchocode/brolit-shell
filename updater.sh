#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.10
#############################################################################

BRANCH="master"

# Foreground/Text Colours
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
CYAN='\E[36;40m'
ENDCOLOR='\033[0m'

function _self_update() {

    # Store credentials on first git pull
    git config --global credential.helper store

    git fetch

    # A detached HEAD (e.g. left over from a manual "git checkout <sha>") is
    # itself a reason to update: it's never on ${BRANCH}, so it would never
    # self-correct on its own. Otherwise, only update when the working tree
    # actually differs from origin/${BRANCH} - not just when updater.sh
    # itself changed (the previous check filtered the diff down to only
    # this file's own name, so it essentially never fired and servers
    # silently drifted arbitrarily far behind while this printed "latest
    # version").
    local is_detached="false"
    git symbolic-ref -q HEAD >/dev/null || is_detached="true"

    if [[ "${is_detached}" == "true" ]] || [[ -n "$(git diff --name-only "origin/${BRANCH}")" ]]; then

        echo -e "${GREEN}Found a new version of BROLIT Shell, updating ...${ENDCOLOR}"

        git checkout --quiet "${BRANCH}"
        git reset --hard --quiet origin/master
        git pull --ff-only --force --quiet

        echo -e "${GREEN}Running chmod ...${ENDCOLOR}"
        find ./ -name "*.sh" ! -perm /u+x -exec chmod +x {} \;

        echo -e "${CYAN}Now you can run the runner.sh, enjoy!${ENDCOLOR}"

        exit 1

    else

        echo -e "${YELLOW}Already the latest version.${ENDCOLOR}"

    fi

}

#############################################################################

_self_update

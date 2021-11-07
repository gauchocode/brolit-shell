#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.71
#############################################################################

SCRIPT="$(readlink -f "$0")"
SCRIPTFILE="$(basename "${SCRIPT}")"
SCRIPTPATH="$(dirname "${SCRIPT}")"
BRANCH="master"

# Foreground/Text Colours
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
CYAN='\E[36;40m'
ENDCOLOR='\033[0m'

function _install_script_aliases() {

    local timestamp

    if [[ ! -f ~/.bash_aliases ]]; then

        cp "${SCRIPTPATH}/aliases.sh" ~/.bash_aliases

    else

        timestamp="$(date +%Y%m%d_%H%M%S)"

        mv ~/.bash_aliases ~/.bash_aliases_bk-"${timestamp}"

        cp "${SCRIPTPATH}/aliases.sh" ~/.bash_aliases

        source ~/.bash_aliases

    fi

}

function _self_update() {

    # Store credentials on first git pull
    git config --global credential.helper store

    git fetch

    if git diff --name-only "origin/${BRANCH}" | grep -q "${SCRIPTFILE}"; then

        echo -e "${GREEN}Found a new version of BROLIT Shell, updating ...${ENDCOLOR}"

        git checkout --quiet "${BRANCH}"
        git reset --hard --quiet origin/master
        git pull --ff-only --force --quiet

        echo -e "${GREEN}Running chmod ...${ENDCOLOR}"
        find ./ -name "*.sh" -exec chmod +x {} \;

        echo -e "${GREEN}Updating aliases ...${ENDCOLOR}"
        _install_script_aliases

        echo -e "${CYAN}Now you can run the runner.sh, enjoy!${ENDCOLOR}"

        exit 1

    else

        echo -e "${YELLOW}Already the latest version.${ENDCOLOR}"

    fi

}

#############################################################################

_self_update

#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.26
#############################################################################

SCRIPT="$(readlink -f "$0")"
SCRIPTFILE="$(basename "${SCRIPT}")"
SCRIPTPATH="$(dirname "${SCRIPT}")"
#SCRIPTNAME="$0"
#ARGS=("$@")
BRANCH="master"

# Foreground/Text Colours
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
CYAN='\E[36;40m'
ENDCOLOR='\033[0m'

# BROOBE Utils config file
LEMP_UTILS_CONFIG_FILE=~/.broobe-utils-options

function _check_and_update_script_version() {

    if test -f ${LEMP_UTILS_CONFIG_FILE}; then

        source "${LEMP_UTILS_CONFIG_FILE}"

        declare -g CURRENT_SCRIPT_VERSION

        CURRENT_SCRIPT_VERSION="3.0.26"

        if [[ -z ${SCRIPT_VERSION} ]]; then

            echo "SCRIPT_VERSION=${CURRENT_SCRIPT_VERSION}" >>${LEMP_UTILS_CONFIG_FILE}

        else

            if [[ ${SCRIPT_VERSION} != "${CURRENT_SCRIPT_VERSION}" ]]; then

                # Search and replace ${SCRIPT_VERSION} string with ${CURRENT_SCRIPT_VERSION}
                sed -i "s/${SCRIPT_VERSION}/${CURRENT_SCRIPT_VERSION}/g" "${LEMP_UTILS_CONFIG_FILE}"

            fi

        fi

    else

        return 1

    fi

}

function _install_script_aliases() {

    local timestamp

    if [[ ! -f ~/.bash_aliases ]]; then

        cp "${SCRIPTPATH}/utils/aliases.sh" ~/.bash_aliases

    else

        timestamp="$(date +%Y%m%d_%H%M%S)"

        mv ~/.bash_aliases ~/.bash_aliases_bk-"${timestamp}"

        cp "${SCRIPTPATH}/utils/aliases.sh" ~/.bash_aliases

        source ~/.bash_aliases

    fi

}

function _self_update() {

    # Store credentials on first git pull
    git config --global credential.helper store

    git fetch

    if git diff --name-only "origin/${BRANCH}" | grep -q "${SCRIPTFILE}"; then

        echo -e "${GREEN}Found a new version of LEMP Script Utils, updating ...${ENDCOLOR}"

        git checkout --quiet "${BRANCH}"
        git reset --hard --quiet origin/master
        git pull --ff-only --force --quiet

        echo -e "${GREEN}Running chmod ...${ENDCOLOR}"
        find ./ -name "*.sh" -exec chmod +x {} \;

        echo -e "${GREEN}Updating aliases ...${ENDCOLOR}"
        _install_script_aliases

        echo -e "${GREEN}Updating script version on ${LEMP_UTILS_CONFIG_FILE}...${ENDCOLOR}"
        _check_and_update_script_version

        echo -e "${CYAN}Now you can run the runner.sh, enjoy!${ENDCOLOR}"

        exit 1

    else

        echo -e "${YELLOW}Already the latest version.${ENDCOLOR}"

    fi

}

#############################################################################

_self_update

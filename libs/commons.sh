#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################

################################################################################
# Private: source all scripts
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

# cron runs with PATH=/usr/bin:/bin. Tools the shell installs itself (yq, wp,
# pipx apps) live in /usr/local/bin and /root/.local/bin, so without this a tool
# installed during the run was still "missing" for the same run (dev04, 2026-11-22:
# every Borg backup failed with yq_missing right after "yq installed").
function brolit_ensure_path() {
  local dir
  for dir in /usr/local/sbin /usr/local/bin /usr/sbin /sbin /root/.local/bin; do
    case ":${PATH}:" in
      *":${dir}:"*) ;;
      *) [[ -d "${dir}" ]] && PATH="${PATH}:${dir}" ;;
    esac
  done
  export PATH
}
brolit_ensure_path

function _source_all_scripts() {

  local libs_apps_path
  local libs_apps_scripts

  # Source all apps libs
  libs_apps_path="${BROLIT_MAIN_DIR}/libs/apps"
  libs_apps_scripts="$(find "${libs_apps_path}" -maxdepth 1 -name '*.sh' -type f -print)"
  for f in ${libs_apps_scripts}; do source "${f}"; done

  # Source all local libs
  libs_local_path="${BROLIT_MAIN_DIR}/libs/local"
  libs_local_scripts="$(find "${libs_local_path}" -maxdepth 1 -name '*.sh' -type f -print)"
  for j in ${libs_local_scripts}; do source "${j}"; done

  # Source utils
  utils_path="${BROLIT_MAIN_DIR}/utils"
  utils_scripts="$(find "${utils_path}" -maxdepth 1 -name '*.sh' -type f -print)"
  for k in ${utils_scripts}; do source "${k}"; done

  # Load other sources
  source "${BROLIT_MAIN_DIR}/libs/notification_controller.sh"
  source "${BROLIT_MAIN_DIR}/libs/database_controller.sh"
  source "${BROLIT_MAIN_DIR}/libs/storage_controller.sh"
  source "${BROLIT_MAIN_DIR}/libs/borg_storage_controller.sh"

  # Load task runner (flags handler, validation, etc.)
  source "${BROLIT_MAIN_DIR}/libs/task_runner.sh"

}

################################################################################
# Private: setup global vars and script options
#
# Arguments:
#   none
#
# Outputs:
#   global vars
################################################################################

function _setup_globals_and_options() {

  # Script
  declare -g SCRIPT_N="BROLIT SHELL"
  # Banner version: release/version.env is authoritative (it is what the
  # rollout tooling bumps); the constant only covers legacy checkouts where
  # that file is absent. Without this the banner showed 3.13 on every
  # release-based install regardless of the real version.
  declare -g SCRIPT_V="3.13"
  local version_env_file
  if [[ -z "${BROLIT_MAIN_DIR:-}" ]]; then
    version_env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/release/version.env"
  else
    version_env_file="${BROLIT_MAIN_DIR}/release/version.env"
  fi
  if [[ -f "${version_env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${version_env_file}"
    [[ -n "${BROLIT_RELEASE_VERSION:-}" ]] && declare -g SCRIPT_V="${BROLIT_RELEASE_VERSION}"
  fi

  # Hostname
  declare -g SERVER_NAME="$HOSTNAME"

  # Default directories
  declare -g BROLIT_CONFIG_PATH="/etc/brolit"

  # Creating brolit folder
  [[ ! -d ${BROLIT_CONFIG_PATH} ]] && mkdir "${BROLIT_CONFIG_PATH}"

  # Main partition
  declare -g MAIN_VOL
  MAIN_VOL="$(df / | grep -Eo '/dev/[^ ]+')"

  # Time Vars
  declare -g NOW
  NOW="$(date +"%Y-%m-%d")"

  declare -g NOWDISPLAY
  NOWDISPLAY="$(date +"%d-%m-%Y")"

  # Others
  declare -g startdir=""
  declare -g menutitle="Config Selection Menu"

  # Apps globals
  declare -g TAR
  declare -g FIND
  declare -g CURL

  TAR="$(command -v tar)"
  FIND="$(command -v find)"
  CURL="curl --silent -L --fail --connect-timeout 3 --retry 0" # CURL (better curl to download files and getting http return codes). Ref: https://everything.curl.dev/usingcurl/returns

  export NOW NOWDISPLAY CURL TAR FIND MAIN_VOL

}

################################################################################
# Private: setup color vars
#
# Arguments:
#   none
#
# Outputs:
#   global vars
################################################################################

function _setup_colors_and_styles() {

  # Refs:
  # https://misc.flogisoft.com/bash/tip_colors_and_formatting

  # RUNNING FROM TERMINAL
  if [[ -t 1 ]]; then

    # Text Styles
    readonly NORMAL="\033[m"
    readonly BOLD='\x1b[1m'
    readonly ITALIC='\x1b[3m'
    readonly UNDERLINED='\x1b[4m'
    readonly INVERTED='\x1b[7m'

    # Foreground/Text Colours
    readonly BLACK='\E[30;40m'
    readonly RED='\E[31;40m'
    readonly GREEN='\E[32;40m'
    readonly YELLOW='\E[33;40m'
    readonly ORANGE='\033[0;33m'
    readonly MAGENTA='\E[35;40m'
    readonly CYAN='\E[36;40m'
    readonly WHITE='\E[37;40m'
    readonly ENDCOLOR='\033[0m'
    readonly F_DEFAULT='\E[39m'

    # Background Colours
    readonly B_BLACK='\E[40m'
    readonly B_RED='\E[41m'
    readonly B_GREEN='\E[42m'
    readonly B_YELLOW='\E[43m'
    readonly B_ORANGE='\043[0m'
    readonly B_MAGENTA='\E[45m'
    readonly B_CYAN='\E[46m'
    readonly B_WHITE='\E[47m'
    readonly B_ENDCOLOR='\e[0m'
    readonly B_DEFAULT='\E[49m'

  else

    # Text Styles
    readonly NORMAL=''
    readonly BOLD=''
    readonly ITALIC=''
    readonly UNDERLINED=''
    readonly INVERTED=''

    # Foreground/Text Colours
    readonly BLACK=''
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly ORANGE=''
    readonly MAGENTA=''
    readonly CYAN=''
    readonly WHITE=''
    readonly ENDCOLOR=''
    readonly F_DEFAULT=''

    # Background Colours
    readonly B_BLACK=''
    readonly B_RED=''
    readonly B_GREEN=''
    readonly B_YELLOW=''
    readonly B_ORANGE=''
    readonly B_MAGENTA=''
    readonly B_CYAN=''
    readonly B_WHITE=''
    readonly B_ENDCOLOR=''
    readonly B_DEFAULT=''

  fi

  # Export all declared vars
  export NORMAL BOLD ITALIC UNDERLINED INVERTED BLACK RED GREEN YELLOW ORANGE MAGENTA CYAN WHITE ENDCOLOR F_DEFAULT B_BLACK B_RED B_GREEN B_YELLOW B_ORANGE B_MAGENTA B_CYAN B_WHITE B_ENDCOLOR B_DEFAULT

}

################################################################################
# Private: check if user is root
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function _check_root() {

  local is_root

  is_root="$(id -u)" # if return 0, the script is runned by the root user

  # Check if user is root
  if [[ ${is_root} -ne 0 ]]; then
    # $USER is a env var
    die "Script runned by ${USER}, but must be root! Exiting ..."

  else
    log_event "debug" "Script runned by root" "false"
    return 0

  fi

}

################################################################################
# Private: check script permissions
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function _check_scripts_permissions() {

  # Log
  log_event "info" "Checking scripts permissions" "false"
  log_event "debug" "Executing chmod +x on *.sh" "false"

  ### chmod (only if not already executable, avoids git noise)
  find "${BROLIT_MAIN_DIR}" -name "*.sh" ! -perm /u+x -exec chmod +x {} \;

  # Check errors
  if [[ $? -ne 0 ]]; then
    die "Error setting scripts permissions! Exiting ..."

  else
    log_event "debug" "Scripts permissions setted" "false"
    return 0

  fi

}

################################################################################
# Get server IPs
#
# Arguments:
#   none
#
# Outputs:
#   ${public_ip}
################################################################################

function get_server_public_ip() {

  local default_interface
  local public_ip
  local external_ip

  default_interface=$(ip route | awk '/default/ {print $5}')
  public_ip=$(ip addr show dev "${default_interface}" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n 1)

  # A VM behind NAT (for example a Proxmox guest) has a private address on its
  # interface; that is not where the world reaches it. Ask what the outside sees
  # instead, and keep the interface address only if that is unavailable (callers
  # that write DNS refuse private addresses on their own).
  if [[ -n ${public_ip} ]] && network_is_private_ipv4 "${public_ip}"; then
    external_ip="$(curl --silent --max-time 5 http://ipv4.icanhazip.com | tr -d '[:space:]')"
    if [[ ${external_ip} =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && ! network_is_private_ipv4 "${external_ip}"; then
      public_ip="${external_ip}"
    fi
  fi

  if [[ -z ${public_ip} ]]; then
    # Alternative method
    public_ip="$(curl --silent http://ipv4.icanhazip.com)"
  fi

  # Return
  echo "${public_ip}"

}

################################################################################
# Address this server uses on its internal network (the source address of the
# default route). On a Proxmox guest this is the address the OpenResty gateway
# reaches it on.
#
# Arguments:
#   none
#
# Outputs:
#   IPv4 address, empty if it cannot be determined.
################################################################################

function network_get_internal_ip() {

  local internal_ip

  internal_ip="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -n 1)"

  echo "${internal_ip}"

}

################################################################################
# Whether an IPv4 address is private, loopback, link-local or carrier-grade NAT
# (RFC 1918, 127/8, 169.254/16, 100.64/10): an address that cannot be reached
# from the internet and must never be published in DNS.
#
# Arguments:
#   ${1} = ${ip}
#
# Outputs:
#   0 if private, 1 otherwise.
################################################################################

function network_is_private_ipv4() {

  local ip="${1}"

  [[ ${ip} =~ ^10\. ]] && return 0
  [[ ${ip} =~ ^192\.168\. ]] && return 0
  [[ ${ip} =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] && return 0
  [[ ${ip} =~ ^127\. ]] && return 0
  [[ ${ip} =~ ^169\.254\. ]] && return 0
  [[ ${ip} =~ ^100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\. ]] && return 0

  return 1

}

################################################################################
# Get server IPs (legacy)
#
# Arguments:
#   none
#
# Outputs:
#   ${public_ip}
################################################################################

# TODO: Should return server IPs?
function get_server_ips() {

  # Global vars
  declare -g LOCAL_IP
  declare -g SERVER_IP
  declare -g SERVER_IPv6

  # If the server has configured a floating ip, it will return this:
  LOCAL_IP="$(ip route get 1 | awk '{print $(NF-2);exit}')"

  # PUBLIC IP
  SERVER_IP="$(get_server_public_ip)"

  # Get IPv6 too
  SERVER_IPv6="$(curl --silent 'https://api64.ipify.org')"

  # Log
  log_event "info" "LOCAL IPv4: ${LOCAL_IP}" "false"
  log_event "info" "SERVER IPv4: ${SERVER_IP}" "false"
  log_event "info" "SERVER IPv6: ${SERVER_IPv6}" "false"

}

################################################################################
# Private: check linux distro
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function _check_distro() {

  declare -g DISTRO

  # Running Ubuntu?
  DISTRO="$(lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $1}')"

  if [[ ${DISTRO} == "Ubuntu" ]]; then

    MIN_V="$(echo "20.04" | awk -F "." '{print $1$2}')"
    DISTRO_V="$(get_ubuntu_version)"

    log_event "info" "Actual linux distribution: ${DISTRO} ${DISTRO_V}" "false"

    if [[ ! ${DISTRO_V} -ge ${MIN_V} ]]; then

      log_event "warning" "Ubuntu version must be 20.04, 22.04 or 24.04! Use this script only for backup or restore purpose." "true"

      spinner_start "Script starts in 3 seconds ..."
      sleep 3
      spinner_stop $?

    fi

  else

    if [[ ${DISTRO} == "Pop!_OS" || ${DISTRO} == "Debian" ]]; then

      log_event "warning" "BROLIT Shell has partial support for Debian, some features may not work as expected!" "true"

    else

      log_event "error" "Only Ubuntu 20.04, 22.04 or 24.04 are supported! Exiting ..." "true"
      return 0

    fi

  fi

}

################################################################################
# Script init
#
# Arguments:
#  ${1} = ${SKIPTESTS} - 1 or 0 (enabled/disabled)
#
# Outputs:
#   global vars
################################################################################

function script_init() {

  # Parameters
  declare -g SKIPTESTS="${1}"
  local exec_mode="${2:-interactive}"
  declare -g BROLIT_EXEC_MODE="${exec_mode}"
  export BROLIT_EXEC_MODE

  # Define log name
  declare -g BROLIT_LOG_FILE
  declare -g BROLIT_EXEC_TYPE

  declare -g BROLIT_CONFIG_FILE=~/.brolit_conf.json
  if [[ -z "${BROLIT_RUNTIME_STATE_DIR:-}" ]]; then
    if [[ "${BROLIT_MAIN_DIR}" == */brolit-shell/releases/* || "${BROLIT_MAIN_DIR}" == */brolit-shell/current* ]]; then
      declare -g BROLIT_RUNTIME_STATE_DIR="${BROLIT_STATE_DIR:-/var/lib/brolit}"
    else
      declare -g BROLIT_RUNTIME_STATE_DIR="${BROLIT_MAIN_DIR}"
    fi
    export BROLIT_RUNTIME_STATE_DIR
  fi

  local timestamp
  local path_log
  local log_name
  local path_reports

  # Log
  timestamp="$(date +%Y%m%d_%H%M%S)"
  path_log="${BROLIT_RUNTIME_STATE_DIR}/log"
  if [[ ! -d "${path_log}" ]]; then
    mkdir -p "${path_log}"
  fi
  # Reports
  path_reports="${BROLIT_RUNTIME_STATE_DIR}/reports"
  if [[ ! -d "${path_reports}" ]]; then
    mkdir -p "${path_reports}"
  fi
  mkdir -p "${BROLIT_RUNTIME_STATE_DIR}/tmp"
  if [[ "${BROLIT_RUNTIME_STATE_DIR}" != "${BROLIT_MAIN_DIR}" ]]; then
    umask 077
    chmod 700 "${BROLIT_RUNTIME_STATE_DIR}" "${BROLIT_RUNTIME_STATE_DIR}/tmp" "${path_log}" "${path_reports}" 2>/dev/null || true
    find "${BROLIT_RUNTIME_STATE_DIR}" -type f -exec chmod 600 {} + 2>/dev/null || true
  fi

  ## Only for BROLIT-UI
  if [[ -n ${SLOG} ]]; then
    # And add second parameter to the log name
    #log_name="log_lemp_utils_${SLOG}.log"
    log_name="${SLOG}.json"
    BROLIT_EXEC_TYPE="external"
  else
    # Default log name
    log_name="brolit_shell_${timestamp}.log"
    BROLIT_EXEC_TYPE="default"
  fi
  export BROLIT_EXEC_TYPE

  BROLIT_LOG_FILE="${path_log}/${log_name}"

  # Source all scripts
  _source_all_scripts

  # Script setup
  _setup_globals_and_options

  # Load colors and styles
  _setup_colors_and_styles

  # Clear Screen & Banner (interactive only)
  if [[ "${exec_mode}" != "cli" ]]; then
    clear_screen

    log_event "" "                                             " "true"
    log_event "" "██████╗ ██████╗  ██████╗ ██╗     ██╗████████╗" "true"
    log_event "" "██╔══██╗██╔══██╗██╔═══██╗██║     ██║╚══██╔══╝" "true"
    log_event "" "██████╔╝██████╔╝██║   ██║██║     ██║   ██║   " "true"
    log_event "" "██╔══██╗██╔══██╗██║   ██║██║     ██║   ██║   " "true"
    log_event "" "██████╔╝██║  ██║╚██████╔╝███████╗██║   ██║   " "true"
    log_event "" "╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝   ╚═╝   " "true"
    log_event "" "              ${SCRIPT_N} v${SCRIPT_V} by GauchoCode" "true"
    log_event "" "                                             " "true"
    log_event "" "------------------------------------------------------------" "true"
  fi

  # Log Start
  log_event "info" "BROLIT Shell start" "false"

  # Install required package to read configuration file
  package_install_if_not "jq"

  # Brolit configuration check
  brolit_configuration_file_check "${BROLIT_CONFIG_FILE}"
  brolit_configuration_setup_check "${BROLIT_CONFIG_FILE}"

  log_section "Initialization"

  # Checking distro
  _check_distro

  # Checking if user is root
  _check_root

  # Checking scripts permissions
  _check_scripts_permissions

  # Get server IPs
  get_server_ips

  # Clean old Brolit log files
  del_logs="$(find "${path_log}" -name "*.log" -type f -mtime +7 -print -delete | tr '\n' ' ')"
  del_reports="$(find "${path_reports}" -name "*.log" -type f -mtime +7 -print -delete | tr '\n' ' ')"

  ## Log
  log_event "debug" "Deleting old script logs: ${del_logs}" "false"
  log_event "debug" "Deleting old script reports: ${del_reports}" "false"

  # Checking required packages
  package_check_required

  # Check configuration
  brolit_configuration_load "${BROLIT_CONFIG_FILE}"

  # EXPORT VARS
  export SCRIPT_V SERVER_NAME BROLIT_CONFIG_PATH BROLIT_MAIN_DIR PACKAGES
  export DISK_U ONE_FILE_BK NOTIFICATION_EMAIL_SMTP_SERVER NOTIFICATION_EMAIL_SMTP_PORT NOTIFICATION_EMAIL_SMTP_TLS NOTIFICATION_EMAIL_SMTP_USER NOTIFICATION_EMAIL_SMTP_UPASS
  export BROLIT_LOG_FILE DEBUG SKIPTESTS
  export BROLIT_CONFIG_FILE

}

################################################################################
# Customize Ubuntu Welcome/Login Message
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function customize_ubuntu_login_message() {

  # Remove unnecesary messages
  if [[ -d "/etc/update-motd.d/10-help-text " ]]; then
    rm "/etc/update-motd.d/10-help-text "

  fi
  if [[ -d "/etc/update-motd.d/50-motd-news" ]]; then
    rm "/etc/update-motd.d/50-motd-news"

  fi
  if [[ -d "/etc/update-motd.d/00-header" ]]; then
    rm "/etc/update-motd.d/00-header"

  fi

  # Disable default messages
  chmod -x /etc/update-motd.d/*

  # Copy new login message
  cp "${BROLIT_MAIN_DIR}/config/motd/00-header" "/etc/update-motd.d"

  # Enable new message
  chmod +x "/etc/update-motd.d/00-header"

  # Force update
  run-parts "/etc/update-motd.d"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_event "info" "Welcome message changed!" "false"
    return 0

  else

    log_event "error" "Something went wrong trying to change Welcome message" "false"
    return 1

  fi

}

################################################################################
# Install BROLIT aliases
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function install_script_aliases() {

  local brolit_bin="/usr/local/bin/brolit"
  local brolit_target="${BROLIT_MAIN_DIR}/runner.sh"

  log_subsection "Bash Aliases"

  if [[ ! -f ~/.bash_aliases ]]; then
    cp "${BROLIT_MAIN_DIR}/aliases.sh" ~/.bash_aliases
    display --indent 4 --text "- Installing script aliases" --result "DONE" --color GREEN
    display --indent 6 --text "Please now run: source ~/.bash_aliases" --tcolor CYAN

  else

    display --indent 2 --text "- File .bash_aliases already exists" --color YELLOW

    timestamp="$(date +%Y%m%d_%H%M%S)"
    mv ~/.bash_aliases ~/.bash_aliases_bk-"${timestamp}"

    display --indent 4 --text "- Backup old aliases" --result "DONE" --color GREEN

    cp "${BROLIT_MAIN_DIR}/aliases.sh" ~/.bash_aliases

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      display --indent 4 --text "- Installing BROLIT aliases" --result "DONE" --color GREEN
      display --indent 6 --text "Please now run: source ~/.bash_aliases" --tcolor CYAN
      log_event "info" "BROLIT aliases installed" "false"

    else

      display --indent 4 --text "- Installing BROLIT aliases" --result "FAIL" --color RED
      log_event "error" "Something went wrong installing BROLIT aliases" "false"

      return 1

    fi

  fi

  if [[ -L "${brolit_bin}" ]]; then
    local current_target
    current_target="$(readlink -f "${brolit_bin}")"
    if [[ "${current_target}" == "$(readlink -f "${brolit_target}")" ]]; then
      display --indent 4 --text "- Symlink ${brolit_bin} already correct" --result "DONE" --color GREEN
    else
      ln -sf "${brolit_target}" "${brolit_bin}"
      display --indent 4 --text "- Updated symlink ${brolit_bin}" --result "DONE" --color GREEN
    fi
  elif [[ -e "${brolit_bin}" ]]; then
    display --indent 4 --text "- ${brolit_bin} exists but is not a symlink, skipping" --result "WARN" --color YELLOW
  else
    ln -s "${brolit_target}" "${brolit_bin}"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      display --indent 4 --text "- Created symlink: ${brolit_bin}" --result "DONE" --color GREEN
      log_event "info" "Created brolit symlink at ${brolit_bin}" "false"
    else
      display --indent 4 --text "- Failed to create symlink ${brolit_bin}" --result "FAIL" --color RED
      log_event "error" "Failed to create brolit symlink" "false"
    fi
  fi

  return 0

}

################################################################################
# Validate email format
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function validator_email_format() {

  local email="${1}"

  if [[ ! "${email}" =~ ^[A-Za-z0-9._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,63}$ ]]; then

    log_event "error" "Invalid email format for: ${email}" "false"

    return 1

  else

    return 0

  fi

}

################################################################################
# Clean up
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function cleanup() {

  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here

}

################################################################################
# Die
#
# Arguments:
#   ${1} = {msg}
#   ${2} = {code}
#
# Outputs:
#   ${code}
################################################################################

function die() {

  local msg="${1}"
  local code=${2-1} # default exit status 1

  log_break "true"
  log_event "critical" "${msg}" "true"

  exit "${code}"

}

################################################################################
# Get Ubuntu version
#
# Arguments:
#   None
#
# Outputs:
#   String with Ubuntu version number
################################################################################

function get_ubuntu_version() {

  lsb_release -d | awk -F"\t" '{print $2}' | awk -F " " '{print $2}' | awk -F "." '{print $1$2}'

}

################################################################################
# Array to checklist
#
# Arguments:
#   ${1} = {array}
#
# Outputs:
#   ${checklist_array}
################################################################################

function array_to_checklist() {

  local array="${1}"

  local i

  declare -a checklist_array

  i=0
  for option in ${array}; do

    checklist_array[i]=$option
    i=$((i + 1))
    checklist_array[i]=" "
    i=$((i + 1))
    checklist_array[i]=off
    i=$((i + 1))

  done

  export checklist_array

}

################################################################################
# File browser
#
# Arguments:
#   ${1} = ${menutitle}
#   ${2} = ${startdir}
#
# Outputs:
#   ${filename} and ${filepath}
################################################################################

function file_browser() {

  local menutitle="${1}"
  local startdir="${2}"

  local dir_list

  if [[ -z ${startdir} ]]; then
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "${startdir}"
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir="$(pwd)"
  if [[ "${curdir}" == "/" ]]; then # Check if you are at root folder
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select "${dir_list}" 3>&1 1>&2 2>&3)
  else # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select ../ BACK "${dir_list}" 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [[ $RET -eq 1 ]]; then # Check if User Selected Cancel
    return 1
  elif [[ $RET -eq 0 ]]; then
    if [[ -f "${selection}" ]]; then # Check if File Selected
      if (whiptail --title "Confirm Selection" --yesno "Selection : ${selection}\n" 0 0 \
        --yes-button "Confirm" \
        --no-button "Retry"); then

        # Return 1
        filename="${selection}"
        # Return 2
        filepath="${curdir}" # Return full filepath and filename as selection variables

      fi

    fi

  fi

}

################################################################################
# Directory browser
#
# Arguments:
#   ${1} = ${menutitle}
#   ${2} = ${startdir}
#
# Outputs:
#   $filename and $filepath
################################################################################

function directory_browser() {

  local menutitle="${1}"
  local startdir="${2}"

  local dir_list

  if [ -z "${startdir}" ]; then
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  else
    cd "${startdir}"
    dir_list=$(ls -lhp | awk -F ' ' ' { print $9 " " $5 } ')
  fi
  curdir=$(pwd)
  if [ "${curdir}" == "/" ]; then # Check if you are at root folder
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n$curdir" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select ${dir_list} 3>&1 1>&2 2>&3)
  else # Not Root Dir so show ../ BACK Selection in Menu
    selection=$(whiptail --title "${menutitle}" \
      --menu "Select a Folder or Tab Key\n${curdir}" 0 0 0 \
      --cancel-button Cancel \
      --ok-button Select ../ BACK ${dir_list} 3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then # Check if User Selected Cancel
    return 1
  elif [ $RET -eq 0 ]; then
    if [[ -d "${selection}" ]]; then # Check if Directory Selected
      whiptail --title "Confirm Selection" --yesno "${selection}" --yes-button "Confirm" --no-button "Retry" 10 60 3>&1 1>&2 2>&3
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # Return 1
        filename="${selection}"
        # Return 2
        filepath="${curdir}" # Return full filepath and filename as selection variables

      else
        return 1

      fi

    fi

  fi

}

################################################################################
# Get all directories from specific location
#
# Arguments:
#   ${1} = ${main_dir}
#
# Outputs:
#   String with directories
################################################################################

function get_all_directories() {

  local main_dir="${1}"

  # Check if we should follow symlinks from config
  local find_opts=""
  if [[ ${BACKUP_CONFIG_FOLLOW_SYMLINKS} == "true" ]]; then
    find_opts="-L"
    log_event "debug" "get_all_directories: Following symlinks (BACKUP_CONFIG_FOLLOW_SYMLINKS=true)" "false"
  else
    log_event "debug" "get_all_directories: Not following symlinks (BACKUP_CONFIG_FOLLOW_SYMLINKS=${BACKUP_CONFIG_FOLLOW_SYMLINKS})" "false"
  fi

  # -L follows symlinks, -not -path '*/.*' will ommit hidden directories
  first_level_dir="$(find ${find_opts} "${main_dir}" -maxdepth 1 -mindepth 1 -type d -not -path '*/.*' 2>&1 | sort)"

  # Debug logging
  if [[ -z "${first_level_dir}" ]]; then
    log_event "debug" "get_all_directories: No directories found in ${main_dir}" "false"
    # Try a simpler find to see what's there
    all_items="$(find ${find_opts} "${main_dir}" -maxdepth 1 -mindepth 1 2>&1)"
    log_event "debug" "get_all_directories: All items in ${main_dir}: ${all_items}" "false"
  else
    log_event "debug" "get_all_directories: Found directories: ${first_level_dir}" "false"
  fi

  # Return
  echo "${first_level_dir}"

}

################################################################################
# Sort backup files by date
#
# Arguments:
#   ${1} = ${files}
#
# Outputs:
#   Array with sorted files
################################################################################

function sort_files_by_date {

  local -a files=("$@")

  local -a sorted_files

  #log_event "debug" "Running: echo ${files[@]} | tr ' ' '\n' | sort -r -t_ -k3 | tr '\n' ' '" "false"

  sorted_files=($(echo "${files[@]}" | tr ' ' '\n' | sort -r -t_ -k3 | tr '\n' ' '))

  # Return
  echo "${sorted_files[@]}"

}

################################################################################
# Sort array alphabetically
#
# Arguments:
#   ${1} = ${files}
#
# Outputs:
#   Array with sorted files
################################################################################

function sort_array_alphabetically {

  local -a files=("$@")

  local -a sorted_files

  #log_event "debug" "Running: echo ${files[@]} | tr ' ' '\n' | sort | tr '\n' ' '" "false"

  sorted_files=($(echo "${files[@]}" | tr ' ' '\n' | sort | tr '\n' ' '))

  # Return
  echo "${sorted_files[@]}"

}

################################################################################
# Get size of an specific file
#
# Arguments:
#   ${1} = ${file}
#
# Outputs:
#   String with directories
################################################################################

function get_file_size() {

  local file="${1}"

  # Get file size
  backup_file_size="$(du --apparent-size -s -k "${file}" | awk '{ print $1 }' | awk '{printf "%.3f MiB %s\n", $1/1024, $2}')"

  file_size_result=$?
  if [[ ${file_size_result} -eq 0 ]]; then

    # Log
    log_event "info" "File size: ${backup_file_size}" "false"

    # Prepare string
    backup_file_size="$(string_remove_spaces "${backup_file_size}")"

    # Return
    echo "${backup_file_size}" && return 0

  else

    # Log
    log_event "error" "Something went wrong trying to get file size of: ${file}" "false"
    log_event "debug" "Last command executed: du --apparent-size -s -k \"${file}\" | awk '{ print $1 }' | awk '{printf \"%.3f MiB %s\n\", $1/1024, $2}'" "false"
    log_event "debug" "Output: ${file_size_result}" "false"

    return 1

  fi

}

################################################################################
# Copy files (with rsync)
#
# Arguments:
#   ${1} = ${source_path}
#   ${2} = ${destination_path}
#   ${3} = ${excluded_path} - Optional: Need to be a relative path
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function copy_files() {

  local source_path="${1}"
  local destination_path="${2}"
  local excluded_path="${3}"

  log_event "info" "Copying files from ${source_path} to ${destination_path}..." "false"

  if [[ -n ${excluded_path} ]]; then

    rsync -ax --exclude "${excluded_path}" "${source_path}" "${destination_path}" --quiet

  else

    rsync -ax "${source_path}" "${destination_path}" --quiet

  fi

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    display --indent 6 --text "- Copying files to ${destination_path}" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_previous_lines "2"
    display --indent 6 --text "- Copying files to ${destination_path}" --result "FAIL" --color RED

    return 1

  fi

}

################################################################################
# Move files
#
# Arguments:
#   $1= ${source_path}
#   ${2} = ${destination_path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function move_files() {

  local source_path="${1}"
  local destination_path="${2}"

  # Log
  display --indent 6 --text "- Moving files to ${destination_path}"
  log_event "info" "Moving files from ${source_path} to ${destination_path}..." "false"

  # Moving
  mv "${source_path}" "${destination_path}"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    # Log
    clear_previous_lines "1"
    log_event "info" "Files moved from ${source_path} to ${destination_path}" "false"
    display --indent 6 --text "- Moving files to ${destination_path}" --result "DONE" --color GREEN
    return 0

  else
    # Log
    clear_previous_lines "2"
    log_event "error" "Moving files from ${source_path} to ${destination_path} failed!" "false"
    display --indent 6 --text "- Moving files to ${destination_path}" --result "FAIL" --color RED
    return 1

  fi

}

################################################################################
# Calculates disk usage
#
# Arguments:
#   ${1} = ${disk_volume}
#
# Outputs:
#   An string with disk usage
################################################################################

function calculate_disk_usage() {

  local disk_volume="${1}"

  local disk_u

  # Need to use grep with -w to exact match of the main volume
  disk_u="$(df -h | grep -w "${disk_volume}" | awk '{print $5}')"

  log_event "info" "Disk usage of ${disk_volume}: ${disk_u}" "false"

  # Return
  echo "${disk_u}"

}

################################################################################
# Wait for a domain's DNS A record to propagate to a public resolver
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${expected_ip}
#   ${3} = ${max_wait_seconds} (optional, default 60)
#
# Outputs:
#   0 if propagated within the timeout, 1 otherwise.
################################################################################

function wait_for_dns_propagation() {

  local domain="${1}"
  local expected_ip="${2}"
  local max_wait_seconds="${3:-60}"

  local interval=5
  local waited=0
  local resolved_ip

  while [[ ${waited} -lt ${max_wait_seconds} ]]; do

    resolved_ip="$(dig +short "${domain}" @1.1.1.1 2>/dev/null | tail -1)"

    if [[ "${resolved_ip}" == "${expected_ip}" ]]; then
      log_event "info" "DNS propagation confirmed for ${domain} -> ${expected_ip} (waited ${waited}s)" "false"
      return 0
    fi

    sleep "${interval}"
    waited=$((waited + interval))

  done

  log_event "warning" "DNS propagation for ${domain} -> ${expected_ip} not confirmed after ${max_wait_seconds}s (last resolved: ${resolved_ip:-none})" "false"
  return 1

}

################################################################################
# Check if a specific port is in use
#
# Arguments:
#   ${1} = ${port}
#
# Outputs:
#   0 if port is in use, or 1 if not
################################################################################

function network_port_is_use() {

  local port="${1}"

  if ss -tlnH 2>/dev/null | grep -qP ":${port}\b"; then
    log_event "info" "Port ${port} is in use by another service." "false"
    return 0
  else
    log_event "info" "Port ${port} is not in use." "false"
    return 1
  fi

}

################################################################################
# Find next available port (port range for check)
#
# Arguments:
#   ${1} = ${port_start} - port range start
#   ${2} = ${port_end} - port range end
#
# Outputs:
#   Available port number, 1 on error.
################################################################################

function network_next_available_port() {

  local port_start="${1}"
  local port_end="${2}"

  local port
  local used_ports
  local excluded=""

  [[ -n "${DOCKER_EXCLUDED_PORTS}" ]] && excluded=",${DOCKER_EXCLUDED_PORTS},"

  log_event "debug" "Getting next available port from ${port_start} to ${port_end}" "false"

  used_ports="$(ss -tlnH 2>/dev/null | awk '{print $4}' | grep -oP ':\d+$' | sed 's/://' | sort -nu)"

  for port in $(seq "${port_start}" "${port_end}"); do

    if echo "${used_ports}" | grep -qx "${port}"; then
      continue
    fi

    if [[ -n "${excluded}" ]] && echo "${excluded}" | grep -q ",${port},"; then
      continue
    fi

    log_event "debug" "Available port: ${port}" "false"
    echo "${port}" && return 0

  done

  log_event "error" "No available port found in range ${port_start}-${port_end}" "false"
  return 1

}

################################################################################
# Check if a port is in the excluded ports list
#
# Arguments:
#   ${1} = ${port}
#
# Outputs:
#   0 if excluded, 1 if not excluded
################################################################################

function network_port_is_excluded() {

  local port="${1}"
  local excluded=""

  [[ -z "${DOCKER_EXCLUDED_PORTS}" ]] && return 1

  excluded=",${DOCKER_EXCLUDED_PORTS},"

  if echo "${excluded}" | grep -q ",${port},"; then
    log_event "debug" "Port ${port} is in the excluded list" "false"
    return 0
  fi

  return 1

}

################################################################################
# Count directories on a specific path
#
# Arguments:
#   ${1} = ${dir_path}
#
# Outputs:
#   number of directories
################################################################################

function count_directories_on_directory() {

  local dir_path="${1}"

  local dir_count

  dir_count="$(ls -l "${dir_path}" | grep -c ^d)"

  log_event "info" "Number of directories in ${dir_path}: ${dir_count}" "false"

  # Return
  echo "${dir_count}"

}

################################################################################
# Count files on a specific path
#
# Arguments:
#   ${1} = ${dir_path}
#
# Outputs:
#   number of files
################################################################################

function count_files_on_directory() {

  local dir_path="${1}"

  local dir_count

  dir_count="$(find "${dir_path}" -maxdepth 1 -type f | wc -l)"

  log_event "info" "Number of files in ${dir_path}: ${dir_count}" "false"

  # Return
  echo "${dir_count}"

}

################################################################################
# Remove spaces chars from string
#
# Arguments:
#   ${1} = ${string}
#
# Outputs:
#   string
################################################################################

function string_remove_spaces() {

  local string="${1}"

  # Return
  echo "${string//[[:blank:]]/}"

}

################################################################################
# Remove first and last quote (") from a string
#
# Arguments:
#   ${1} = ${string}
#
# Outputs:
#   string
################################################################################

function string_remove_quotes() {

  local string="${1}"

  local new_string

  new_string="$(sed -e 's/^"//' -e 's/"$//' <<<"$string")"

  # Return
  echo "${new_string}"

}

################################################################################
# Remove special chars from string
#
# Arguments:
#   ${1} = ${string}
#
# Outputs:
#   string
################################################################################

function string_remove_special_chars() {

  # From: https://stackoverflow.com/questions/23816264/remove-all-special-characters-and-case-from-string-in-bash
  #
  # The first tr deletes special characters. d means delete, c means complement (invert the character set).
  # So, -dc means delete all characters except those specified.
  # The \n and \r are included to preserve linux or windows style newlines, which I assume you want.
  # The second one translates uppercase characters to lowercase.
  # The third get rid of characters like \r \n or ^C.

  local string="${1}"

  # Return
  echo "${string}" | tr -dc ".[:alnum:]-\n\r" # Let '.' and '-' chars

}

################################################################################
# Remove new lines from array
#
# Arguments:
#   ${1} = ${string}
#
# Outputs:
#   string
################################################################################

function array_remove_newlines() {

  # Declare an empty array to store the cleaned up elements
  #local -a cleaned_array="${1}"
  local -a cleaned_array=("$@")

  # Loop through the original array and remove "\n" and "\r" characters from each element
  for element in "${@}"; do
    # Use the tr command to remove the "\n" and "\r" characters from each element
    cleaned_element=$(echo "${element}" | tr -d '\n\r')

    # Append the cleaned element to the new array
    cleaned_array+=("${cleaned_element}")
  done

  # Output the cleaned up array
  echo "${cleaned_array[@]}"
}

################################################################################
# Change directory ownership
#
# Arguments:
#   ${1} = ${user}
#   ${2} = ${group}
#   ${3} = ${path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function change_ownership() {

  local user="${1}"
  local group="${2}"
  local path="${3}"

  # Command
  chown -R "${user}":"${group}" "${path}"

  chown_result=$?
  if [[ ${chown_result} -eq 0 ]]; then

    # Log
    log_event "info" "Changing ownership of ${path} to ${user}:${group}" "false"
    log_event "debug" "Command executed: chown -R ${user}:${group} ${path}" "false"

    display --indent 6 --text "- Changing directory ownership" --result DONE --color GREEN

  else

    # Log
    log_event "error" "Changing ownership of ${path} to ${user}:${group}" "false"
    log_event "debug" "Command executed: chown -R ${user}:${group} ${path}" "false"

    clear_previous_lines "1"
    display --indent 6 --text "- Changing directory ownership" --result FAIL --color YELLOW

    return 1

  fi

}

################################################################################
# Prompt return or finish
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function prompt_return_or_finish() {

  log_break "true"

  while true; do

    echo -e "${YELLOW}${ITALIC} > Do you want to return to menu?${ENDCOLOR}"
    read -p "Please type 'y' or 'n'" yn

    case $yn in

    [Yy]*)
      break
      ;;

    [Nn]*)
      echo -e "${B_RED}Exiting script ...${ENDCOLOR}"
      exit 0
      ;;

    *)
      echo "Please answer yes or no."
      ;;

    esac

  done

  clear_previous_lines "2"

}

################################################################################
# Prompt return or finish
#
# Arguments:
#   ${1} = ${file_with_path}
#
# Outputs:
#   $file_name
################################################################################

function extract_filename_from_path() {

  local file_with_path="${1}"

  local file_name

  file_name="$(basename -- "${file_with_path}")"

  # Return
  echo "${file_name}"

}

################################################################################
# Collect tar exclude patterns from the variadic arguments of compress()
# and decompress().
#
# Accepts only complete "--exclude=PATTERN" arguments: anything else is
# dropped with a warning, so a caller bug can never inject arbitrary
# tar/du flags. Empty arguments (legacy callers pass "") are ignored.
#
# Arguments:
#   ${1} = ${exclude_args_ref} - nameref of the array to fill (reset first)
#   ${2}... = candidate exclude arguments
#
# Outputs:
#   Fills the array referenced by ${1} with valid "--exclude=PATTERN" items.
################################################################################

function _collect_exclude_args() {

  local -n exclude_args_ref="${1}"
  shift

  local arg
  exclude_args_ref=()
  for arg in "$@"; do
    [[ -n "${arg}" ]] || continue
    if [[ "${arg}" != "--exclude="* ]]; then
      log_event "warning" "Ignoring invalid exclude argument (expected --exclude=PATTERN): ${arg}" "false"
      continue
    fi
    exclude_args_ref+=("${arg}")
  done

}

################################################################################
# Extract compressed files
#
# Arguments:
#   ${1} = ${file_path} - File to uncompress or extract
#   ${2} = ${directory_to_extract} - Dir to uncompress file
#   ${3} = ${compress_type} - Optional: compress-program (ex: lbzip2)
#   ${4}... = ${exclude_args} - Optional: exclude patterns, one per argument
#          (ex: "--exclude=*.log" "--exclude=cache")
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: pv only if BROLIT_EXEC_TYPE == default

function decompress() {

  local file_path="${1}"
  local directory_to_extract="${2}"
  local compress_type="${3}"
  shift 3

  # Exclusions must arrive as separate arguments (one "--exclude=PATTERN"
  # each). Passing them concatenated in a single string used to make the
  # unquoted expansion below split patterns on spaces and glob them against
  # the current directory.
  local -a exclude_args=()
  _collect_exclude_args exclude_args "$@"

  # Get filename and file extension
  filename=$(basename -- "${file_path}")
  filename="${filename%.*}"

  # Log
  log_event "info" "Extracting compressed file: ${file_path}" "false"
  log_event "debug" "Compress type: ${compress_type}" "false"
  [[ ${#exclude_args[@]} -gt 0 ]] && log_event "debug" "Exclude parameters: ${exclude_args[*]}" "false"
  display --indent 6 --text "- Extracting compressed file"

  if [[ -f "${file_path}" ]]; then

    case "${file_path}" in

    *.tar.bz2)
      if [[ -n "${compress_type}" ]]; then
        pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}" --use-compress-program="${compress_type}" "${exclude_args[@]}"
      else
        pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}" "${exclude_args[@]}"
      fi
      ;;

    *.tar.gz)
      pigz -dc "${file_path}" | pv --width 70 | tar xf - -C "${directory_to_extract}" "${exclude_args[@]}"
      ;;

    *.bz2)
      pv --width 70 "${file_path}" | bunzip2 >"${directory_to_extract}/${filename}"
      ;;

    *.rar)
      if [[ ${#exclude_args[@]} -gt 0 ]]; then
        log_event "warning" "RAR format does not support exclude patterns via decompress()" "false"
      fi
      unrar x "${file_path}" "${directory_to_extract}" | pv -l >/dev/null
      ;;

    *.gz)
      pv --width 70 "${file_path}" | gunzip -C "${directory_to_extract}"
      ;;

    *.tar)
      pv --width 70 "${file_path}" | tar xf -C "${directory_to_extract}" "${exclude_args[@]}"
      ;;

    *.tbz2)
      pv --width 70 "${file_path}" | tar xjf -C "${directory_to_extract}" "${exclude_args[@]}"
      ;;

    *.tgz)
      pv --width 70 "${file_path}" | tar xzf -C "${directory_to_extract}" "${exclude_args[@]}"
      ;;

    *.xz)
      pv --width 70 "${file_path}" | tar xvf -C "${directory_to_extract}" "${exclude_args[@]}"
      ;;

    *.zip)
      if [[ ${#exclude_args[@]} -gt 0 ]]; then
        # Convert tar-style excludes to unzip format
        local -a unzip_exclude_args=()
        local pattern
        for pattern in "${exclude_args[@]}"; do
          # Extract pattern from --exclude=pattern format
          pattern="${pattern#--exclude=}"
          unzip_exclude_args+=(-x "${pattern}")
        done
        unzip -o "${file_path}" -d "${directory_to_extract}" "${unzip_exclude_args[@]}" | pv -l >/dev/null
      else
        unzip -o "${file_path}" -d "${directory_to_extract}" | pv -l >/dev/null
      fi
      ;;

    *.zst)
      pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}" --use-compress-program="${compress_type}" "${exclude_args[@]}"
      ;;

    *.Z)
      pv --width 70 "${file_path}" | uncompress "${directory_to_extract}"
      ;;

    *)
      log_event "error" "${file_path} cannot be extracted via decompress()" "false"
      display --indent 6 --text "- Extracting compressed file" --result "FAIL" --color RED
      display --indent 8 --text "${file_path} cannot be extracted" --tcolor RED
      return 1
      ;;

    esac

  else

    # Log
    log_event "error" "${file_path} is not a valid file" "false"
    clear_previous_lines "1"
    display --indent 6 --text "- Extracting compressed file" --result "FAIL" --color RED
    display --indent 8 --text "${file_path} is not a valid file" --tcolor RED
    return 1

  fi

  #exitstatus=$?
  if [[ ${PIPESTATUS[1]} -eq 0 ]]; then

    clear_previous_lines "2"

    log_event "info" "${file_path} extracted ok!" "false"
    display --indent 6 --text "- Extracting compressed file" --result "DONE" --color GREEN

    return 0

  else

    clear_previous_lines "2"

    log_event "error" "Error extracting ${file_path}" "false"
    display --indent 6 --text "- Extracting compressed file" --result "FAIL" --color RED

    return 1

  fi

}

################################################################################
# Backup progress reporting.
#
# Emits one machine readable line per progress event on stderr when
# BROLIT_PROGRESS=1. stderr is used on purpose: compress() returns the archive
# size on stdout and every caller captures it, so stdout must stay clean.
#
# Line format (one per event, sentinel first so consumers can classify and
# strip it):
#   [[BROLIT_PROGRESS]]{"v":1,"phase":"compress","pct":42,"detail":"example.com"}
#
# Arguments:
#   ${1} = phase: compress | upload | database | borg | transfer | restore | verify
#          (the last three are the stages of `migrate`, always without a percentage)
#   ${2} = percentage 0-100, or "-" when the phase cannot be measured
#   ${3} = optional detail; defaults to BROLIT_PROGRESS_DETAIL. It is reduced to
#          [A-Za-z0-9._-] and truncated to 255 characters, which keeps the JSON
#          valid and paths out. Callers must still pass a domain, never a
#          secret: sanitizing is not a secrecy guarantee.
#
# Outputs:
#   0 always.
################################################################################
function brolit_progress() {

  local phase="${1:-}"
  local pct="${2:--}"
  local detail="${3:-${BROLIT_PROGRESS_DETAIL:-}}"

  [[ "${BROLIT_PROGRESS:-0}" == "1" ]] || return 0
  [[ "${phase}" =~ ^(compress|upload|database|borg|transfer|restore|verify)$ ]] || return 0

  if [[ "${pct}" =~ ^[0-9]{1,3}$ ]]; then
    pct=$((10#${pct}))
    (( pct > 100 )) && pct=100
  else
    pct="null"
  fi

  detail="${detail//[^A-Za-z0-9._-]/}"
  detail="${detail:0:255}"

  printf '[[BROLIT_PROGRESS]]{"v":1,"phase":"%s","pct":%s,"detail":"%s"}\n' \
    "${phase}" "${pct}" "${detail}" >&2

  return 0
}

################################################################################
# Turn pv numeric output into progress events.
#
# With "-n -f", pv writes one integer percentage per line on stderr. Forwarding
# every line would flood the job log, so events are throttled: at least two
# points of change or three seconds since the last event, plus the last value
# actually observed.
#
# Arguments:
#   ${1} = phase
#   ${2} = optional detail
#
# Outputs:
#   0 always.
################################################################################
function brolit_progress_pv() {

  local phase="${1:-compress}"
  local detail="${2:-}"
  local line value last_value="" last_emitted=-1 last_time=0 now

  if [[ "${BROLIT_PROGRESS:-0}" != "1" ]]; then
    # Keep the pipe drained so the writer never blocks on a full buffer.
    cat >/dev/null
    return 0
  fi

  while IFS= read -r line; do
    # pv --numeric prints one integer percentage per line. Anything else is a
    # diagnostic (for example "pv: ...: No such file or directory") and must
    # stay visible instead of being swallowed together with the meter. The
    # 1-3 digit bound also keeps the arithmetic below from overflowing.
    if [[ ! "${line}" =~ ^[[:space:]]*[0-9]{1,3}[[:space:]]*$ ]]; then
      [[ -n "${line//[[:space:]]/}" ]] && printf '%s\n' "${line}" >&2
      continue
    fi
    value="${line//[^0-9]/}"
    value=$((10#${value}))
    (( value > 100 )) && value=100
    last_value="${value}"
    now="${EPOCHSECONDS:-$(date +%s)}"
    if (( last_emitted < 0 )) || (( value >= last_emitted + 2 )) || (( now - last_time >= 3 )); then
      brolit_progress "${phase}" "${value}" "${detail}"
      last_emitted="${value}"
      last_time="${now}"
    fi
  done

  # Close with the last value actually observed, never with an invented 100 and
  # never with a trailing non-numeric line: a truncated archive must not look
  # complete.
  if [[ -n "${last_value}" ]]; then
    brolit_progress "${phase}" "${last_value}" "${detail}"
  fi

  return 0
}

################################################################################
# pv wrapper for the compression pipeline.
#
# Arguments:
#   ${1} = ${detail}
#   ${2}... = pv arguments
#
# Outputs:
#   pv exit status (so PIPESTATUS stays meaningful).
################################################################################
function brolit_progress_pv_filter() {

  local detail="${1:-}"
  (( $# > 0 )) && shift

  if [[ "${BROLIT_PROGRESS:-0}" == "1" ]]; then
    pv --numeric --force "$@" 2> >(brolit_progress_pv compress "${detail}")
  else
    pv "$@"
  fi
}

################################################################################
# Turn a curl progress meter into upload progress events.
#
# dropbox_uploader.sh -p uses curl's --progress-bar, which writes
# "#######  42.5%" separated by carriage returns on stderr.
#
# Arguments:
#   ${1} = optional phase (default upload)
#   ${2} = optional detail
#
# Outputs:
#   0 always.
################################################################################
function brolit_progress_meter() {

  local phase="${1:-upload}"
  local detail="${2:-}"

  local line match value
  local last_emitted=-1

  if [[ "${BROLIT_PROGRESS:-0}" != "1" ]]; then
    cat >/dev/null
    return 0
  fi

  while IFS= read -r line; do
    match="$(printf '%s\n' "${line}" | grep -oE '[0-9]+([.][0-9]+)?%' | tail -n 1)"
    if [[ -z "${match}" ]]; then
      # Not a meter line: curl's own errors (--show-error) must stay visible.
      [[ -n "${line//[[:space:]]/}" ]] && printf '%s\n' "${line}" >&2
      continue
    fi
    match="${match%%%*}"
    value="${match%%.*}"
    [[ "${value}" =~ ^[0-9]{1,3}$ ]] || continue
    value=$((10#${value}))
    (( value > 100 )) && value=100

    # The meter never reports completion: only the caller knows whether the
    # upload and its final commit succeeded. This reader is used for simple,
    # single-request uploads only; chunked uploads have one meter per request
    # and retries, so they report phase boundaries instead of a false percentage.
    (( value > 99 )) && value=99

    if (( last_emitted < 0 )) || (( value >= last_emitted + 2 )); then
      brolit_progress "${phase}" "${value}" "${detail}"
      last_emitted="${value}"
    fi
  done < <(tr '\r' '\n')

  return 0
}

################################################################################
# Compress files or directories
#
# Arguments:
#   ${1} = ${file_path}
#   ${2} = ${to_backup} - Could be a file or a directory.
#   ${3} = ${file_output}
#   ${4}... = ${exclude_args} - Optional: tar exclude patterns, one
#          "--exclude=PATTERN" per argument. Never pass them concatenated
#          in a single string: unquoted expansion keeps literal quote
#          characters inside the patterns, tar matches nothing, and the
#          "excluded" content fills the disk (2026-11-08/11 outages).
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function compress() {

  local backup_base_dir="${1}"
  local to_backup="${2}"
  local file_output="${3}"
  shift 3

  local backup_file_size
  local compress_parameter
  local decompress_parameter
  local estimated_size
  local free_space
  local output_dir
  local -a pipeline_status

  # Exclusions as an array: one "--exclude=PATTERN" element per argument.
  local -a exclude_args=()
  _collect_exclude_args exclude_args "$@"

  # Only for better displaying
  [[ ${to_backup} == "." ]] && to_backup_string="$(basename "${backup_base_dir}")" || to_backup_string="${to_backup}"

  # Log
  display --indent 6 --text "- Compressing ${to_backup_string}"
  log_event "info" "Compressing ${to_backup_string} ..." "false"
  log_event "debug" "Compressing with ${#exclude_args[@]} exclusion pattern(s): ${exclude_args[*]:-none}" "false"

  # Prepare compress command
  if [[ -n ${BACKUP_CONFIG_COMPRESSION_CORES} && ${BACKUP_CONFIG_COMPRESSION_TYPE} == "lbzip2" ]]; then
    compress_parameter="-n ${BACKUP_CONFIG_COMPRESSION_CORES}"
    decompress_parameter="-n ${BACKUP_CONFIG_COMPRESSION_CORES}"
  fi
  ## Set the compression block size during compression
  ## Example: $ lbzip2 -1 filename
  if [[ -n ${BACKUP_CONFIG_COMPRESSION_LEVEL} ]]; then
    compress_parameter="${compress_parameter} -${BACKUP_CONFIG_COMPRESSION_LEVEL}"
  fi

  # Estimated size of what tar will actually read, using the same exclusion
  # patterns as the archive run: keeps the pv progress bar meaningful and
  # feeds the free-space guard below. Note du matches --exclude against the
  # walked paths while tar matches archive member names; bare glob patterns
  # (the config style) behave the same in both.
  estimated_size="$(du -sb "${exclude_args[@]}" "${backup_base_dir}/${to_backup}" 2>/dev/null | awk '{s+=$1} END {print s+0}')"
  if [[ ! "${estimated_size}" =~ ^[0-9]+$ ]] || (( estimated_size == 0 )); then
    # du failed or measured nothing: the guard below cannot evaluate. Keep
    # going (a broken du must not disable backups) but leave a trace in the
    # run log, and drop the pv size estimate.
    log_event "warning" "Could not estimate backup size for ${to_backup_string} (du returned: '${estimated_size}'). Free-space guard skipped." "false"
    estimated_size=0
  fi

  # Free-space guard: the archive is built on the temp directory, usually
  # the same disk as the data. A backup that does not fit fills the disk
  # and takes every unrelated service down (2026-11-08 and 2026-11-11
  # outages on tukiverse-apps01). A failed backup is cheaper than that.
  output_dir="$(dirname -- "${file_output}")"
  # Created here (not by the caller) so df can always resolve the path.
  mkdir -p "${output_dir}"
  free_space="$(df -P -B1 "${output_dir}" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ ! "${free_space}" =~ ^[0-9]+$ ]]; then
    log_event "warning" "Could not determine free space on ${output_dir}. Free-space guard skipped." "false"
  elif (( estimated_size > 0 && free_space < estimated_size * 12 / 10 )); then
    clear_previous_lines "1"
    display --indent 6 --text "- Compressing ${to_backup_string}" --result "FAIL" --color RED
    display --indent 8 --text "Not enough free space for the backup (needed: ${estimated_size} bytes, available: ${free_space} bytes)" --tcolor RED
    log_event "error" "Not enough free space to compress ${to_backup_string} into ${file_output}: estimated ${estimated_size} bytes, available ${free_space} bytes" "false"
    return 1
  fi

  # pv size argument (omit when the estimate is unknown or zero)
  local -a pv_args=(--width 70)
  (( estimated_size > 0 )) && pv_args+=(-s "${estimated_size}")

  # Phase detail for progress events: the project domain when the caller set
  # the context, otherwise whatever is being compressed (already restricted to
  # [A-Za-z0-9._-] by brolit_progress).
  local progress_detail="${BROLIT_PROGRESS_DETAIL:-${to_backup_string}}"

  brolit_progress compress 0 "${progress_detail}"

  if [[ ${BACKUP_CONFIG_FOLLOW_SYMLINKS} == "true" ]]; then
    ## -h will follow symlinks
    log_event "debug" "Running: ${TAR} -cf - --directory=\"${backup_base_dir}\" ${exclude_args[*]} -h \"${to_backup}\" | pv ${pv_args[*]} | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter} >\"${file_output}\"" "false"
    "${TAR}" -cf - --directory="${backup_base_dir}" "${exclude_args[@]}" -h "${to_backup}" | brolit_progress_pv_filter "${progress_detail}" "${pv_args[@]}" | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter} >"${file_output}"
  else
    log_event "debug" "Running: ${TAR} -cf - --directory=\"${backup_base_dir}\" ${exclude_args[*]} \"${to_backup}\" | pv ${pv_args[*]} | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter} >\"${file_output}\"" "false"
    "${TAR}" -cf - --directory="${backup_base_dir}" "${exclude_args[@]}" "${to_backup}" | brolit_progress_pv_filter "${progress_detail}" "${pv_args[@]}" | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter} >"${file_output}"
  fi

  # The tar pipeline result was previously ignored: with the compression
  # test disabled, a disk-full mid-archive still reported success and left
  # a truncated backup on disk.
  pipeline_status=("${PIPESTATUS[@]}")
  log_event "debug" "Pipeline status: tar=${pipeline_status[0]} pv=${pipeline_status[1]} ${BACKUP_CONFIG_COMPRESSION_TYPE}=${pipeline_status[2]}" "false"

  # GNU tar exits 1 for warnings (e.g. "file changed as we read it" on
  # live sites) and 2+ for fatal errors. Live projects that keep writing
  # during the nightly run would fail every single backup on exit 1, and a
  # 99%-consistent archive still beats no archive: the compression test
  # below validates the output either way. So exit 1 is logged as a
  # warning and the backup continues; tar >= 2 or a pv/compressor failure
  # is fatal and the partial output is removed. BROLIT_STRICT_TAR=1 is used
  # only for deletion-time mount snapshots, where tar 1 is fatal too.
  if [[ ${pipeline_status[1]} -ne 0 || ${pipeline_status[2]} -ne 0 || ${pipeline_status[0]} -ge 2 || ( ${pipeline_status[0]} -eq 1 && ${BROLIT_STRICT_TAR:-0} == "1" ) ]]; then

    # Delete the partial temp file so a failed run cannot fill the disk
    rm --force "${file_output}"

    clear_previous_lines "2"
    display --indent 6 --text "- Compressing ${to_backup_string}" --result "FAIL" --color RED
    display --indent 8 --text "Something went wrong making backup file: ${file_output}" --tcolor RED

    log_event "error" "Something went wrong making backup file: ${file_output}" "false"

    return 1

  elif [[ ${pipeline_status[0]} -eq 1 ]]; then

    log_event "warning" "tar reported warnings while compressing ${to_backup_string} (exit 1, e.g. files changed as they were read); keeping the archive" "false"

  fi

  # The archive was built: close the phase even when pv never printed 100.
  brolit_progress compress 100 "${progress_detail}"

  # Compress result
  if [[ ${BACKUP_CONFIG_COMPRESSION_TEST} == "true" ]]; then

    # Log
    clear_previous_lines "2"
    log_event "info" "Testing backup file: ${file_output}" "false"
    display --indent 6 --text "- Testing backup file"

    # Test backup with pv output
    pv --width 70 "${file_output}" | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${decompress_parameter} --test

    compress_result=$?

    # Clear output
    clear_previous_lines "2"

    if [[ ${compress_result} -eq 0 ]]; then

      # Get file size
      backup_file_size="$(get_file_size "${file_output}")"

      # Log
      log_event "info" "Backup file test finished ok." "false"

      # Return
      echo "${backup_file_size}" && return 0

    else

      # Log
      clear_previous_lines "2"

      # Delete the partial/corrupt temp file so it cannot fill the disk
      rm --force "${file_output}"

      display --indent 6 --text "- Compressing ${to_backup_string}" --result "FAIL" --color RED
      display --indent 8 --text "Something went wrong making backup file: ${file_output}" --tcolor RED

      log_event "error" "Something went wrong making backup file: ${file_output}" "false"
      log_event "debug" "Output: ${compress_result}" "false"

      return 1

    fi

  else

    # Get file size
    backup_file_size="$(get_file_size "${file_output}")"

    # Log
    clear_previous_lines "2"

    display --indent 6 --text "- Compressing ${to_backup_string}" --result "DONE" --color GREEN
    display --indent 6 --text "- Testing backup file" --result "SKIPPED" --color YELLOW

    log_event "info" "Backup file test skipped." "false"

    # Return
    echo "${backup_file_size}" && return 0

  fi

}

################################################################################
# Cron registry: every croneable Brolit task is described here, once. The
# non-interactive `cron-install` task and the interactive menu both read it, so
# a server gets the same line whichever way it was set up.
#
# There is deliberately no "borgmatic" kind: Borg runs inside backups_tasks.sh.
#
# Arguments:
#   none
#
# Outputs:
#   the kinds, one per line, in menu order.
################################################################################

function brolit_cron_kinds() {

  printf '%s\n' backups ui optimizer wordpress security uptime disk-cleanup

}

################################################################################
# Describe one croneable task. Sets CRON_SPEC_SCRIPT, CRON_SPEC_SCHEDULE,
# CRON_SPEC_LOCK, CRON_SPEC_TIMEOUT, CRON_SPEC_SUFFIX and CRON_SPEC_LABEL.
#
# Arguments:
#   ${1} = ${kind}
#
# Outputs:
#   0 if the kind exists, 1 otherwise.
################################################################################

function brolit_cron_kind_spec() {

  local kind="${1}"

  CRON_SPEC_SUFFIX=""
  CRON_SPEC_TIMEOUT="2h"

  case "${kind}" in
  backups)
    CRON_SPEC_LABEL="BACKUPS TASKS"
    CRON_SPEC_SCRIPT="backups_tasks.sh"
    CRON_SPEC_LOCK="backups_tasks"
    CRON_SPEC_SCHEDULE="45 00 * * *"
    # backups_tasks.sh drives borg/borgmatic against remote repos and can run
    # long; timeout reaps a stuck run (e.g. a hung SSH connection).
    CRON_SPEC_TIMEOUT="6h"
    ;;
  ui)
    CRON_SPEC_LABEL="BROLIT UI HELPER"
    CRON_SPEC_SCRIPT="brolit_ui_tasks.sh"
    CRON_SPEC_LOCK="ui_tasks"
    CRON_SPEC_SCHEDULE="*/30 * * * *"
    CRON_SPEC_TIMEOUT="25m"
    CRON_SPEC_SUFFIX=" > /dev/null"
    ;;
  optimizer)
    CRON_SPEC_LABEL="OPTIMIZER TASKS"
    CRON_SPEC_SCRIPT="optimizer_tasks.sh"
    CRON_SPEC_LOCK="optimizer_tasks"
    CRON_SPEC_SCHEDULE="45 04 * * *"
    ;;
  wordpress)
    CRON_SPEC_LABEL="WORDPRESS TASKS"
    CRON_SPEC_SCRIPT="wordpress_tasks.sh"
    CRON_SPEC_LOCK="wordpress_tasks"
    CRON_SPEC_SCHEDULE="45 23 * * *"
    ;;
  security)
    CRON_SPEC_LABEL="SECURITY TASKS"
    CRON_SPEC_SCRIPT="security_tasks.sh"
    CRON_SPEC_LOCK="security_tasks"
    CRON_SPEC_SCHEDULE="55 03 * * *"
    ;;
  uptime)
    CRON_SPEC_LABEL="UPTIME TASKS"
    CRON_SPEC_SCRIPT="uptime_tasks.sh"
    CRON_SPEC_LOCK="uptime_tasks"
    CRON_SPEC_SCHEDULE="45 22 * * *"
    ;;
  disk-cleanup)
    CRON_SPEC_LABEL="DISK CLEANUP TASKS"
    CRON_SPEC_SCRIPT="disk_cleanup_tasks.sh"
    CRON_SPEC_LOCK="disk_cleanup_tasks"
    CRON_SPEC_SCHEDULE="0 05 * * 0"
    ;;
  *)
    return 1
    ;;
  esac

  return 0

}

################################################################################
# Build the crontab line of a kind. flock -n skips a new run outright if the
# previous one is still alive instead of queuing behind it; timeout caps how
# long a single run can hold the lock.
#
# Arguments:
#   ${1} = ${schedule} - five cron fields or an @alias
#   ${2} = ${script_path} - absolute path of the script
#
# Outputs:
#   the full line on stdout. Needs brolit_cron_kind_spec to have run.
################################################################################

function brolit_cron_build_line() {

  local schedule="${1}"
  local script_path="${2}"

  printf '%s /usr/bin/flock -n /var/lock/brolit_%s.lock /usr/bin/timeout %s %s%s\n' \
    "${schedule}" "${CRON_SPEC_LOCK}" "${CRON_SPEC_TIMEOUT}" "${script_path}" "${CRON_SPEC_SUFFIX}"

}

################################################################################
# Make the root crontab carry exactly one canonical line for a kind.
#
# - No line for the script: append one (default schedule, or the given one).
# - A line for the same script under ANY path (/root/brolit-shell, an old
#   /opt release, ...): rewrite its command to this tree's script and the
#   standard wrapper. The schedule the operator chose is kept unless one is
#   given explicitly.
# - Already canonical: nothing changes.
# - A second line for the same script is reported and left alone.
# - Lines of other programs and comments are never touched.
# The crontab is backed up before it is rewritten and restored if the new one
# does not load. With DRY_RUN=true only the plan is printed.
#
# Arguments:
#   ${1} = ${kind} - see brolit_cron_kinds
#   ${2} = ${cron_expression} - optional, five fields; overrides the schedule
#
# Outputs:
#   0 if the crontab is (or, in a dry run, would be) canonical, 1 on error.
################################################################################

function brolit_cronjob_converge() {

  local kind="${1}"
  local cron_expression="${2:-}"

  local cron_file="/var/spool/cron/crontabs/root"

  if ! brolit_cron_kind_spec "${kind}"; then
    log_event "error" "cron-install: unknown kind '${kind}'" "false"
    return 1
  fi

  # Five whitespace-separated fields of cron characters only.
  if [[ -n "${cron_expression}" && ! "${cron_expression}" =~ ^[0-9*/,-]+([[:space:]]+[0-9*/,-]+){4}$ ]]; then
    log_event "error" "cron-install: invalid cron expression '${cron_expression}'" "false"
    display --indent 2 --text "- Cron expression" --result FAIL --color RED
    return 1
  fi

  local script_path="${BROLIT_MAIN_DIR}/cron/${CRON_SPEC_SCRIPT}"
  if [[ ! -f "${script_path}" ]]; then
    log_event "error" "cron-install: script not found: ${script_path}" "false"
    return 1
  fi

  if [[ ! -f "${cron_file}" && "${DRY_RUN:-false}" != "true" ]]; then
    log_event "info" "Cron file for root does not exist, creating ..." "false"
    touch "${cron_file}"
    /usr/bin/crontab "${cron_file}"
  fi

  local plan
  plan="$(mktemp)" || return 1

  local found=0 changed=0 line schedule desired
  while IFS= read -r line || [[ -n "${line}" ]]; do

    # The spool file starts with a three-line header that cron writes itself on
    # every install. Reading the spool directly would copy it into the new
    # crontab and cron would add another header on top: three more lines on
    # every rewrite. Drop it; cron puts its own back.
    if [[ "${line}" == "# DO NOT EDIT THIS FILE"* || "${line}" == "# ("*" installed on "* || "${line}" == "# (Cron version"* ]]; then
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*# || -z "${line//[[:space:]]/}" || "${line}" != *"/cron/${CRON_SPEC_SCRIPT}"* ]]; then
      printf '%s\n' "${line}" >>"${plan}"
      continue
    fi

    if [[ ${found} -eq 1 ]]; then
      log_event "warning" "cron-install: duplicate ${CRON_SPEC_SCRIPT} line left untouched: ${line}" "false"
      display --indent 4 --text "Duplicate ${CRON_SPEC_SCRIPT} line left untouched"
      printf '%s\n' "${line}" >>"${plan}"
      continue
    fi
    found=1

    if [[ -n "${cron_expression}" ]]; then
      schedule="${cron_expression}"
    elif [[ "${line}" =~ ^[[:space:]]*(@[a-z]+)[[:space:]] ]]; then
      schedule="${BASH_REMATCH[1]}"
    elif [[ "${line}" =~ ^[[:space:]]*(([^[:space:]]+[[:space:]]+){4}[^[:space:]]+)[[:space:]] ]]; then
      schedule="${BASH_REMATCH[1]}"
    else
      schedule="${CRON_SPEC_SCHEDULE}"
    fi

    desired="$(brolit_cron_build_line "${schedule}" "${script_path}")"
    [[ "${desired}" != "${line}" ]] && changed=1
    printf '%s\n' "${desired}" >>"${plan}"

  done < <(cat "${cron_file}" 2>/dev/null || true)

  if [[ ${found} -eq 0 ]]; then
    desired="$(brolit_cron_build_line "${cron_expression:-${CRON_SPEC_SCHEDULE}}" "${script_path}")"
    printf '%s\n' "${desired}" >>"${plan}"
    changed=1
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    echo "CRON_PLAN kind=${kind} changed=${changed} line=${desired}"
    rm -f -- "${plan}"
    return 0
  fi

  if [[ ${changed} -eq 0 ]]; then
    log_event "info" "cron-install: ${kind} already canonical" "false"
    display --indent 2 --text "- Cron job ${kind}" --result "UP TO DATE" --color GREEN
    rm -f -- "${plan}"
    return 0
  fi

  # Keep a copy of the previous crontab so any rewrite can be undone.
  local backup=""
  if [[ -s "${cron_file}" ]]; then
    mkdir -p -- "${BROLIT_MAIN_DIR}/log" 2>/dev/null
    # mktemp keeps two rewrites in the same second from overwriting the first
    # backup, which holds the crontab as it was before Brolit touched it.
    backup="$(mktemp "${BROLIT_MAIN_DIR}/log/crontab.bak-$(date +%Y%m%d-%H%M%S).XXXX")" || backup=""
    [[ -n "${backup}" ]] && { cp -- "${cron_file}" "${backup}" || backup=""; }
  fi

  cat "${plan}" >"${cron_file}"
  if ! /usr/bin/crontab "${cron_file}"; then
    log_event "error" "cron-install: new crontab did not load, restoring" "false"
    [[ -n "${backup}" ]] && cat "${backup}" >"${cron_file}" && /usr/bin/crontab "${cron_file}"
    rm -f -- "${plan}"
    return 1
  fi

  rm -f -- "${plan}"
  log_event "info" "cron-install: ${kind} -> ${desired} (previous crontab: ${backup:-none})" "false"
  display --indent 2 --text "- Cron job ${kind}" --result DONE --color GREEN
  return 0

}

################################################################################
# Non-interactive cron installation for a croneable task (used by
# `runner.sh --task cron-install --subtask <kind> [-tv "<cron expression>"]`).
# Idempotent and convergent, see brolit_cronjob_converge.
#
# Arguments:
#   ${1} = ${kind} - see brolit_cron_kinds
#   ${2} = ${cron_expression} - optional, 5 fields
#
# Outputs:
#   0 if the crontab carries the canonical line, 1 on invalid input or error.
################################################################################

function brolit_cronjob_install_task() {

  local kind="${1}"

  if [[ "${kind}" == "existing" ]]; then
    brolit_cronjob_converge_existing
    return $?
  fi

  brolit_cronjob_converge "${kind}" "${2:-}"

}

################################################################################
# Converge every croneable task the root crontab already schedules, and no
# other. This is what an update runs: it repoints and wraps the lines a server
# has without adding a cron the server never had.
#
# Arguments:
#   none
#
# Outputs:
#   0 if every present kind converged (or none is present), 1 if any failed.
################################################################################

function brolit_cronjob_converge_existing() {

  local cron_file="/var/spool/cron/crontabs/root"
  local kind rc=0

  [[ -f "${cron_file}" ]] || return 0

  while IFS= read -r kind; do
    brolit_cron_kind_spec "${kind}" || continue
    if grep -v '^[[:space:]]*#' "${cron_file}" | grep -qF "/cron/${CRON_SPEC_SCRIPT}"; then
      brolit_cronjob_converge "${kind}" || rc=1
    fi
  done < <(brolit_cron_kinds)

  return ${rc}

}

################################################################################
# SSH Keygen
#
# Arguments:
#   ${1} = ${keydir}
#
# Outputs:
#   $key
################################################################################

function brolit_ssh_keygen() {

  local keydir="${1}"

  if [[ -f "${keydir}/identity" ]]; then

    # Log
    log_event "warning" "A sshkey already exists, showing the content:" "false"
    display --indent 6 --text "- Generating ssh key" --result SKIPPED --color GREEN
    display --indent 8 --text "A sshkey already exists. Showing key:"

  else

    # Log
    log_event "info" "Generating ssh key" "false"

    mkdir "${keydir}"

    # Key generation
    ssh-keygen -b 2048 -f identity -t rsa -f "${keydir}/identity"

    # Create .ssh directory if not exists
    [[ ! -d "${HOME}/.ssh" ]] && mkdir "${HOME}/.ssh"

    # Copy credentials
    cat "${keydir}/identity.pub" >>~/.ssh/authorized_keys

    display --indent 6 --text "- Generating ssh key" --result DONE --color GREEN
    display --indent 8 --text "Generated key:"

  fi

  # Show identity content
  cat "${keydir}/identity"

  log_break "true"

}

################################################################################
# Brolit config menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function brolit_config_menu() {

  local whip_title
  local whip_description
  local config_options
  local chosen_option

  whip_title="BROLIT CONFIG"
  whip_description=" "

  config_options=(
    "1)" "CRON TASKS"
    "2)" "CONFIGURATION WIZARD"
    "3)" "SHOW CURRENT CONFIG"
  )

  while true; do

    chosen_option="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${config_options[@]}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # CRON TASKS
      [[ ${chosen_option} == *"1)"* ]] && menu_cron_script_tasks

      # CONFIGURATION WIZARD
      if [[ ${chosen_option} == *"2)"* ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/utils/config_wizard.sh
        source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
        config_wizard_menu
      fi

      # SHOW CURRENT CONFIG
      if [[ ${chosen_option} == *"3)"* ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/utils/config_wizard.sh
        source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
        config_wizard_show_current "${BROLIT_CONFIG_FILE}"
        read -n 1 -s -r -p "Press any key to continue"
      fi

    else

      return 0

    fi

  done

}

################################################################################
# Main menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function menu_main_options() {

  local whip_title       # whiptail var
  local whip_description # whiptail var
  local runner_options   # whiptail array options
  local chosen_type      # whiptail var

  whip_title="BROLIT-SHELL MAIN MENU"
  whip_description=" "

  runner_options=()

  # Project-oriented options (backup/restore/project/database/environment/
  # wp-cli) all operate on PROJECTS_PATH (/var/www), which doesn't exist on
  # a bare Proxmox VE hypervisor - only inside its guest VMs. Hide them there
  # instead of offering options that can only ever find nothing to act on.
  if ! proxmox_node_detect; then
    runner_options+=(
      "01)" "BACKUP OPTIONS"
      "02)" "RESTORE OPTIONS"
      "03)" "PROJECT MANAGER"
      "04)" "DATABASE MANAGER"
      "05)" "ENVIRONMENT MANAGER"
      "06)" "WP-CLI MANAGER"
    )
  fi

  runner_options+=(
    "07)" "CERTBOT MANAGER"
    "08)" "CLOUDFLARE MANAGER"
    "09)" "IT UTILS"
    "10)" "BROLIT CONFIG"
  )

  # Only offer Proxmox node tasks (e.g. provisioning an OpenResty gateway VM)
  # when actually running on a Proxmox VE hypervisor, not inside a guest VM.
  proxmox_node_detect && runner_options+=("11)" "PROXMOX TOOLS")

  # Site migration is project-oriented (operates on PROJECTS_PATH), so hide
  # it on a bare Proxmox VE hypervisor for the same reason as 01-06 above.
  ! proxmox_node_detect && runner_options+=("12)" "MIGRATE SITE (BETA)")

  while true; do

    chosen_type="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${runner_options[@]}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # BACKUP OPTIONS
      [[ ${chosen_type} == *"01"* ]] && backup_manager_menu

      # RESTORE OPTIONS
      [[ ${chosen_type} == *"02"* ]] && restore_manager_menu

      # PROJECT MANAGER
      [[ ${chosen_type} == *"03"* ]] && project_manager_menu

      # DATABASE MANAGER
      if [[ ${chosen_type} == *"04"* ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/utils/database_manager.sh
        source "${BROLIT_MAIN_DIR}/utils/database_manager.sh"

        database_manager_menu

      fi

      # ENVIRONMENT MANAGER
      if [[ ${chosen_type} == *"05"* ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/utils/environment_manager.sh
        source "${BROLIT_MAIN_DIR}/utils/environment_manager.sh"
        environment_manager_menu
      fi

      # WP-CLI MANAGER
      if [[ ${chosen_type} == *"06"* ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/utils/wpcli_manager.sh
        source "${BROLIT_MAIN_DIR}/utils/wpcli_manager.sh"

        log_section "WP-CLI Manager"
        wpcli_manager

      fi

      # CERTBOT MANAGER
      if [[ ${chosen_type} == *"07"* ]]; then

        if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

          # shellcheck source=${BROLIT_MAIN_DIR}/utils/certbot_manager.sh
          source "${BROLIT_MAIN_DIR}/utils/certbot_manager.sh"

          log_section "Certbot Manager"
          certbot_manager_menu

        else

          # Log
          display --indent 6 --text "- Certbot support is disabled. Enable it on brolit_conf.json" --tcolor YELLOW
          # Press any key to return to main menu
          read -n 1 -s -r -p "Press any key to continue"

        fi

      fi

      # CLOUDFLARE MANAGER
      if [[ ${chosen_type} == *"08"* ]]; then

        if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

          # shellcheck source=${BROLIT_MAIN_DIR}/utils/cloudflare_manager.sh
          source "${BROLIT_MAIN_DIR}/utils/cloudflare_manager.sh"

          log_section "Cloudflare Manager"
          cloudflare_manager_menu

        else

          # Log
          display --indent 6 --text "Cloudflare support is disabled. Configure the api key on brolit_conf.json" --tcolor YELLOW
          # Press any key to return to main menu
          read -n 1 -s -r -p "Press any key to continue"

        fi

      fi

      # IT UTILS
      [[ ${chosen_type} == *"09"* ]] && it_utils_menu

      # BROLIT CONFIG
      if [[ ${chosen_type} == *"10"* ]]; then
        brolit_config_menu
      fi

      # PROXMOX TOOLS
      if [[ ${chosen_type} == *"11"* ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/utils/proxmox_manager.sh
        source "${BROLIT_MAIN_DIR}/utils/proxmox_manager.sh"

        proxmox_manager_menu
      fi

      # MIGRATE SITE
      if [[ ${chosen_type} == *"12"* ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/utils/site_migration_manager.sh
        source "${BROLIT_MAIN_DIR}/utils/site_migration_manager.sh"

        site_migration_manager_menu
      fi

    else

      # Log
      echo ""
      echo -e "${B_RED}Exiting script ...${ENDCOLOR}"

      exit 0

    fi

  done

}

################################################################################
# First run menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function pkg_config_changes_detected() {

  local app_setup="${1}"
  local bypass_prompt="${2}"

  if [[ ${CHECKPKGS} == "false" ]]; then

    # Log
    display --indent 6 --text "- Detecting changes on ${app_setup} configuration" --result "SKIPPED" --color YELLOW
    log_event "debug" "Changes in brolit_conf.json for package ${app_setup} were detected, but CHECKPKGS is set to false." "false"

    return 1

  fi

  if [[ ${bypass_prompt} == "true" ]]; then

    # Log
    display --indent 6 --text "- Detecting changes on ${app_setup} configuration" --result "DONE" --color GREEN

    # shellcheck source=../utils/server_setup.sh
    source "${BROLIT_MAIN_DIR}/utils/server_setup.sh"

    # Check global to prevent running the script twice
    if [[ ${SERVER_PREPARED} == "false" ]]; then
      server_prepare
    fi

    server_app_setup "${app_setup}"

    return 0

  else

    local first_run_options
    local first_run_string
    local chosen_first_run_options

    first_run_string+="\n Changes in the brolit_conf.json where detected.\n"
    first_run_string+=" What do you want to do?:\n"
    first_run_string+="\n"

    first_run_options=(
      "01)" "RUN BROLIT SETUP"
    )

    chosen_first_run_options="$(whiptail --title "BROLIT SETUP" --menu "${first_run_string}" 20 78 10 "${first_run_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_first_run_options} == *"01"* ]]; then

        # shellcheck source=../utils/server_setup.sh
        source "${BROLIT_MAIN_DIR}/utils/server_setup.sh"

        # Check global to prevent running the script twice
        if [[ ${SERVER_PREPARED} == "false" ]]; then
          server_prepare
        fi

        server_app_setup "${app_setup}"

      fi

    else

      exit 1

    fi

  fi

}

################################################################################
# Menu for croned scripts
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function menu_cron_script_tasks() {

  local kind
  local label
  local runner_options=()
  local chosen_kind
  local scheduled_time

  while IFS= read -r kind; do
    brolit_cron_kind_spec "${kind}"
    runner_options+=("${kind}" "${CRON_SPEC_LABEL}")
  done < <(brolit_cron_kinds)

  chosen_kind="$(whiptail --title "CRONEABLE TASKS" --menu "\n" 20 78 10 "${runner_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    brolit_cron_kind_spec "${chosen_kind}"
    label="${CRON_SPEC_LABEL}"

    scheduled_time="$(whiptail_input "CRON ${label}" "Insert a cron expression for selected task:" "${CRON_SPEC_SCHEDULE}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      brolit_cronjob_converge "${chosen_kind}" "${scheduled_time}"

    fi

    prompt_return_or_finish
    menu_cron_script_tasks

  else

    return 0

  fi

}

################################################################################
# Show BROLIT help
#
# Arguments:
#   none
#
# Outputs:
#   String with help text

################################################################################
# NOTE: Task runner functions (flags_handler, tasks_handler, validation, etc.)
# have been moved to libs/task_runner.sh for better code organization.
# See libs/task_runner.sh for all task execution and validation logic.
################################################################################

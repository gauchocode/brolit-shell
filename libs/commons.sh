#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
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
  declare -g SCRIPT_V="3.3.6"

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

  ### chmod
  find ./ -name "*.sh" -exec chmod +x {} \;

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

  default_interface=$(ip route | awk '/default/ {print $5}')
  public_ip=$(ip addr show dev "${default_interface}" | awk '/inet / {print $2}' | cut -d'/' -f1)

  if [[ -z ${public_ip} ]]; then
    # Alternative method
    public_ip="$(curl --silent http://ipv4.icanhazip.com)"
  fi

  # Return
  echo "${public_ip}"

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

    MIN_V="$(echo "18.04" | awk -F "." '{print $1$2}')"
    DISTRO_V="$(get_ubuntu_version)"

    log_event "info" "Actual linux distribution: ${DISTRO} ${DISTRO_V}" "false"

    if [[ ! ${DISTRO_V} -ge ${MIN_V} ]]; then

      log_event "warning" "Ubuntu version must be 18.04 or 20.04! Use this script only for backup or restore purpose." "true"

      spinner_start "Script starts in 3 seconds ..."
      sleep 3
      spinner_stop $?

    else

      if [[ ${DISTRO} == "Pop!_OS" ]]; then

        log_event "warning" "BROLIT Shell has partial support for Pop!_OS, some features may not work as expected!" "true"

      fi

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

  # Define log name
  declare -g BROLIT_LOG_FILE
  declare -g BROLIT_EXEC_TYPE

  declare -g BROLIT_CONFIG_FILE=~/.brolit_conf.json

  local timestamp
  local path_log
  local log_name
  local path_reports

  # Log
  timestamp="$(date +%Y%m%d_%H%M%S)"
  path_log="${BROLIT_MAIN_DIR}/log"
  if [[ ! -d "${BROLIT_MAIN_DIR}/log" ]]; then
    mkdir "${BROLIT_MAIN_DIR}/log"
  fi
  # Reports
  path_reports="${BROLIT_MAIN_DIR}/reports"
  if [[ ! -d "${path_reports}" ]]; then
    mkdir "${path_reports}"
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

  # Clear Screen
  clear_screen

  # Log Start
  log_event "info" "BROLIT Shell start" "false"

  # Install required package to read configuration file
  package_install_if_not "jq"

  # Brolit configuration check
  brolit_configuration_file_check "${BROLIT_CONFIG_FILE}"
  brolit_configuration_setup_check "${BROLIT_CONFIG_FILE}"

  ### Welcome Message ###########################################################

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

  log_subsection "Bash Aliases"

  if [[ ! -f ~/.bash_aliases ]]; then
    cp "${BROLIT_MAIN_DIR}/aliases.sh" ~/.bash_aliases
    display --indent 2 --text "- Installing script aliases" --result "DONE" --color GREEN
    display --indent 4 --text "Please now run: source ~/.bash_aliases" --tcolor CYAN

  else

    display --indent 2 --text "- File .bash_aliases already exists" --color YELLOW

    timestamp="$(date +%Y%m%d_%H%M%S)"
    mv ~/.bash_aliases ~/.bash_aliases_bk-"${timestamp}"

    display --indent 2 --text "- Backup old aliases" --result "DONE" --color GREEN

    cp "${BROLIT_MAIN_DIR}/aliases.sh" ~/.bash_aliases

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      display --indent 2 --text "- Installing BROLIT aliases" --result "DONE" --color GREEN
      display --indent 4 --text "Please now run: source ~/.bash_aliases" --tcolor CYAN
      log_event "info" "BROLIT aliases installed" "false"

      return 0

    else

      display --indent 2 --text "- Installing BROLIT aliases" --result "FAIL" --color RED
      log_event "error" "Something installing BROLIT aliases" "false"

      return 1

    fi

  fi

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
#   $1= ${menutitle}
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
#   $1= ${menutitle}
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
#   $1= ${main_dir}
#
# Outputs:
#   String with directories
################################################################################

function get_all_directories() {

  local main_dir="${1}"

  # -not -path '*/.*' will ommit hidden directories
  first_level_dir="$(find "${main_dir}" -maxdepth 1 -mindepth 1 -type d -not -path '*/.*')"

  # Return
  echo "${first_level_dir}"

}

################################################################################
# Sort backup files by date
#
# Arguments:
#   $1= ${files}
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
#   $1= ${files}
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
#   $1= ${file}
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

    log_event "info" "File size: ${backup_file_size}" "false"

    # Prepare string
    backup_file_size="$(string_remove_spaces "${backup_file_size}")"

    # Return
    echo "${backup_file_size}" && return 0

  else

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
#   $1= ${source_path}
#   ${2} = ${destination_path}
#   $3= ${excluded_path} - Optional: Need to be a relative path
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
    #display --indent 6 --text "- Moving files to ${destination_path}" --result "DONE" --color GREEN
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

  local result

  result="$(lsof -i:"${port}")"

  if [[ -n ${result} ]]; then
    log_event "info" "Port ${port} is use by another service." "false"
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
#   0 if port is in use, or 1 if not
################################################################################

function network_next_available_port() {

  local port_start="${1}"
  local port_end="${2}"

  local port

  log_event "debug" "Getting next available port from ${port_start} to ${port_end}" "false"

  for port in $(seq "${port_start}" "${port_end}"); do

    echo -ne "\035" | telnet 127.0.0.1 "${port}" >/dev/null 2>&1
    if [[ $? -eq 1 ]]; then
      log_event "debug" "Available port: ${port}" "false"
      # Return
      echo "${port}" && return 0
    fi

  done

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
    display --indent 6 --text "- Changing directory ownership" --result FAIL --color RED

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
# Extract compressed files
#
# Arguments:
#   ${1} = ${file_path} - File to uncompress or extract
#   ${2} = ${directory_to_extract} - Dir to uncompress file
#   ${3} = ${compress_type} - Optional: compress-program (ex: lbzip2)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: pv only if BROLIT_EXEC_TYPE == default

function decompress() {

  local file_path="${1}"
  local directory_to_extract="${2}"
  local compress_type="${3}"

  # Get filename and file extension
  filename=$(basename -- "${file_path}")
  filename="${filename%.*}"

  # Log
  log_event "info" "Extracting compressed file: ${file_path}" "false"
  log_event "debug" "Compress type: ${compress_type}" "false"
  display --indent 6 --text "- Extracting compressed file"

  if [[ -f "${file_path}" ]]; then

    case "${file_path}" in

    *.tar.bz2)
      if [[ -n "${compress_type}" ]]; then
        pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}" --use-compress-program="${compress_type}"
      else
        pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}"
      fi
      ;;

    *.tar.gz)
      pigz -dc "${file_path}" | pv --width 70 | tar xf - -C "${directory_to_extract}"
      ;;

    *.bz2)
      pv --width 70 "${file_path}" | bunzip2 >"${directory_to_extract}/${filename}"
      ;;

    *.rar)
      unrar x "${file_path}" "${directory_to_extract}" | pv -l >/dev/null
      ;;

    *.gz)
      pv --width 70 "${file_path}" | gunzip -C "${directory_to_extract}"
      ;;

    *.tar)
      pv --width 70 "${file_path}" | tar xf -C "${directory_to_extract}"
      ;;

    *.tbz2)
      pv --width 70 "${file_path}" | tar xjf -C "${directory_to_extract}"
      ;;

    *.tgz)
      pv --width 70 "${file_path}" | tar xzf -C "${directory_to_extract}"
      ;;

    *.xz)
      pv --width 70 "${file_path}" | tar xvf -C "${directory_to_extract}"
      ;;

    *.zip)
      unzip -o "${file_path}" -d "${directory_to_extract}" | pv -l >/dev/null
      ;;

    *.zst)
      pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}" --use-compress-program="${compress_type}"
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
# Compress files or directories
#
# Arguments:
#   ${1} = ${file_path}
#   ${2} = ${to_backup} - Could be a file or a directory.
#   ${3} = ${file_output}
#   ${4} = ${exclude_parameters}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function compress() {

  local backup_base_dir="${1}"
  local to_backup="${2}"
  local file_output="${3}"
  local exclude_parameters="${4}"

  local backup_file_size
  local compress_parameter
  local decompress_parameter

  # Only for better displaying
  [[ ${to_backup} == "." ]] && to_backup_string="$(basename "${backup_base_dir}")" || to_backup_string="${to_backup}"

  # Log
  display --indent 6 --text "- Compressing ${to_backup_string}"
  log_event "info" "Compressing ${to_backup_string} ..." "false"

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

  if [[ ${BACKUP_CONFIG_FOLLOW_SYMLINKS} == "true" ]]; then
    ## -h will follow symlinks
    ### IMPORTANT: not add "" on ${exclude_parameters} or ${compress_parameter}
    ${TAR} -cf - --directory="${backup_base_dir}" ${exclude_parameters} -h "${to_backup}" | pv --width 70 -s "$(du -sb "${backup_base_dir}/${to_backup}" | awk '{print $1}')" | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter} >"${file_output}"
    log_event "debug" "Running: ${TAR} -cf - --directory=\"${backup_base_dir}\" ${exclude_parameters} -h \"${to_backup}\" | pv --width 70 -s \"$(du -sb "${backup_base_dir}/${to_backup}" | awk '{print $1}')\" | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter}>\"${file_output}\"" "false"

  else
    ${TAR} -cf - --directory="${backup_base_dir}" ${exclude_parameters} "${to_backup}" | pv --width 70 -s "$(du -sb "${backup_base_dir}/${to_backup}" | awk '{print $1}')" | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter} >"${file_output}"
    log_event "debug" "Running: ${TAR} -cf - --directory=\"${backup_base_dir}\" ${exclude_parameters} \"${to_backup}\" | pv --width 70 -s \"$(du -sb "${backup_base_dir}/${to_backup}" | awk '{print $1}')\" | ${BACKUP_CONFIG_COMPRESSION_TYPE} ${compress_parameter}>\"${file_output}\"" "false"
  fi

  # Compress result
  if [[ ${BACKUP_CONFIG_COMPRESSION_TEST} == "true" ]]; then

    # Log
    clear_previous_lines "2"
    log_event "info" "Testing backup file: ${file_output}" "false"
    display --indent 6 --text "- Testing backup file"

    # Test backup with pv output
    pv --width 70 "${file_output}" | ${BACKUP_CONFIG_COMPRESSION_TYPE} "${decompress_parameter}" --test

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
# Install script on crontab
#
# Arguments:
#   ${1} = ${script}
#   ${2} = ${scheduled_time}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function brolit_cronjob_install() {

  local script="${1}"
  local scheduled_time="${2}"

  local cron_file

  log_section "Cron Tasks"

  cron_file="/var/spool/cron/crontabs/root"

  if [[ ! -f ${cron_file} ]]; then

    log_event "info" "Cron file for root does not exist, creating ..." "false"

    touch "${cron_file}"
    /usr/bin/crontab "${cron_file}"

    log_event "info" "Cron file created"
    display --indent 2 --text "- Creating log file" --result DONE --color GREEN

  fi

  # Command
  grep -qi "${script}" "${cron_file}"

  grep_result=$?
  if [[ ${grep_result} -ne 0 ]]; then

    log_event "info" "Updating cron job for script: ${script}" "false"
    /bin/echo "${scheduled_time} ${script}" >>"${cron_file}"

    display --indent 2 --text "- Updating cron job" --result DONE --color GREEN

    return 0

  else
    log_event "warning" "Script already installed" "false"
    display --indent 2 --text "- Updating cron job" --result FAIL --color YELLOW
    display --indent 4 --text "Script already installed"

    return 1

  fi

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

  whip_title="BROLIT SHELL MENU"
  whip_description=" "

  runner_options=(
    "01)" "BACKUP OPTIONS"
    "02)" "RESTORE OPTIONS"
    "03)" "PROJECT CREATION"
    "04)" "MORE PROJECT UTILS"
    "05)" "DATABASE MANAGER"
    "06)" "WP-CLI MANAGER"
    "07)" "CERTBOT MANAGER"
    "08)" "CLOUDFLARE MANAGER"
    "09)" "IT UTILS"
    "10)" "CRON TASKS"
  )

  chosen_type="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${runner_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # BACKUP OPTIONS
    [[ ${chosen_type} == *"01"* ]] && backup_manager_menu

    # RESTORE OPTIONS
    [[ ${chosen_type} == *"02"* ]] && restore_manager_menu

    # CREATE NEW PROJECT
    [[ ${chosen_type} == *"03"* ]] && project_manager_menu_new_project_type_new_project

    # OTHERS PROJECT UTILS
    [[ ${chosen_type} == *"04"* ]] && project_manager_menu_new_project_type_utils

    # DATABASE MANAGER
    if [[ ${chosen_type} == *"05"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/utils/database_manager.sh
      source "${BROLIT_MAIN_DIR}/utils/database_manager.sh"

      database_manager_menu

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
        # Return to main menu
        menu_main_options

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
        # Return to main menu
        menu_main_options

      fi

    fi

    # IT UTILS
    [[ ${chosen_type} == *"09"* ]] && it_utils_menu

    # CRON SCRIPT TASKS
    [[ ${chosen_type} == *"10"* ]] && menu_cron_script_tasks

  else

    # Log
    echo ""
    echo -e "${B_RED}Exiting script ...${ENDCOLOR}"

    exit 0

  fi

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

  local runner_options
  local chosen_type
  local scheduled_time
  local suggested_cron

  runner_options=(
    "01)" "BACKUPS TASKS"
    "02)" "OPTIMIZER TASKS"
    "03)" "WORDPRESS TASKS"
    "04)" "SECURITY TASKS"
    "05)" "UPTIME TASKS"
    "06)" "BROLIT UI HELPER"
  )
  chosen_type="$(whiptail --title "CRONEABLE TASKS" --menu "\n" 20 78 10 "${runner_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_type} == *"01"* ]]; then

      # BACKUPS-TASKS
      suggested_cron="45 00 * * *" # Every day at 00:45 AM
      scheduled_time="$(whiptail_input "CRON BACKUPS-TASKS" "Insert a cron expression for selected task:" "${suggested_cron}")"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        brolit_cronjob_install "${BROLIT_MAIN_DIR}/cron/backups_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"02"* ]]; then

      # OPTIMIZER-TASKS
      suggested_cron="45 04 * * *" # Every day at 04:45 AM
      scheduled_time="$(whiptail_input "CRON OPTIMIZER-TASKS" "Insert a cron expression for selected task:" "${suggested_cron}")"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        brolit_cronjob_install "${BROLIT_MAIN_DIR}/cron/optimizer_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"03"* ]]; then

      # WORDPRESS-TASKS
      suggested_cron="45 23 * * *" # Every day at 23:45 AM
      scheduled_time="$(whiptail_input "CRON WORDPRESS-TASKS" "Insert a cron expression for selected task:" "${suggested_cron}")"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        brolit_cronjob_install "${BROLIT_MAIN_DIR}/cron/wordpress_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"04"* ]]; then

      # UPTIME-TASKS
      suggested_cron="55 03 * * *" # Every day at 22:45 AM
      scheduled_time="$(whiptail_input "CRON SECURITY-TASKS" "Insert a cron expression for selected task:" "${suggested_cron}")"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        brolit_cronjob_install "${BROLIT_MAIN_DIR}/cron/security_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"05"* ]]; then

      # UPTIME-TASKS
      suggested_cron="45 22 * * *" # Every day at 22:45 AM
      scheduled_time="$(whiptail_input "CRON UPTIME-TASKS" "Insert a cron expression for selected task:" "${suggested_cron}")"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        brolit_cronjob_install "${BROLIT_MAIN_DIR}/cron/uptime_tasks.sh" "${scheduled_time}"

      fi

    fi
    if [[ ${chosen_type} == *"06"* ]]; then

      # BROLIT HELPER
      suggested_cron="*/30 * * * *" # Every 30 minutes
      scheduled_time="$(whiptail_input "CRON BROLIT-HELPER" "Insert a cron expression for selected task:" "${suggested_cron}")"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        brolit_cronjob_install "${BROLIT_MAIN_DIR}/cron/brolit_ui_tasks.sh > /dev/null" "${scheduled_time}"

      fi

    fi

    prompt_return_or_finish
    menu_cron_script_tasks

  fi

  menu_main_options

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

function show_help() {

  log_section "Help Menu"

  echo -n "./runner.sh [TASK] [SUB-TASK]... [DOMAIN]...

  Options:
    -t, --task        Task to run:
                        project-backup
                        project-restore
                        project-install
                        cloudflare-api
    -st, --subtask    Sub-task to run:
                        from cloudflare-api: clear_cache, dev_mode
    -s  --site        Site path for tasks execution
    -d  --domain      Domain for tasks execution
    -pn --pname       Project Name
    -pt --ptype       Project Type (wordpress,laravel)
    -ps --pstate      Project Stage (prod,dev,test,stage)
    -q, --quiet       Quiet (no output)
    -v, --verbose     Output more information. (Items echoed to 'verbose')
    -d, --debug       Runs script in BASH debug mode (set -x)
    -h, --help        Display this help and exit
        --version     Output version information and exit

  "

}

################################################################################
# Tasks handler
#
# Arguments:
#   ${1} = ${task}
#
# Outputs:
#   global vars
################################################################################

function tasks_handler() {

  local task="${1}"

  case ${task} in

  backup)

    subtasks_backup_handler "${STASK}"

    exit
    ;;

  restore)

    subtasks_restore_handler "${STASK}"

    exit
    ;;

  project)

    project_tasks_handler "${STASK}" "${PROJECTS_PATH}"

    exit
    ;;

  project-install)

    project_install_tasks_handler "${FILE}" "${TYPE}"

    exit
    ;;

  database)

    database_tasks_handler "${STASK}" "${DBNAME}" "${DBSTAGE}" "${DBNAME_N}" "${DBUSER}" "${DBUSERPSW}"

    exit
    ;;

  cloudflare-api)

    cloudflare_tasks_handler "${STASK}" "${TVALUE}"

    exit
    ;;

  wpcli)

    wpcli_tasks_handler "${STASK}" "${TVALUE}"

    exit
    ;;

  aliases-install)

    install_script_aliases

    exit
    ;;

  ssh-keygen)

    if [[ -z ${STASK} ]]; then
      keydir=/root/pem
    fi
    brolit_ssh_keygen "${keydir}"

    exit
    ;;

  *)
    log_event "error" "INVALID TASK: ${TASK}" "true"
    #ExitFatal
    ;;

  esac

}

################################################################################
# Runner flags handler
#
# Arguments:
#   $*
#
# Outputs:
#   global vars
################################################################################

function flags_handler() {

  # GLOBALS

  ## OPTIONS
  declare -g ENV=""
  declare -g SLOG=""
  declare -g TASK=""
  declare -g STASK=""
  declare -g TVALUE=""
  declare -g DEBUG="false"

  ## PROJECT
  declare -g SITE=""
  declare -g DOMAIN=""
  declare -g PNAME=""
  declare -g PTYPE=""
  declare -g PSTATE=""

  ## DATABASE
  declare -g DBNAME=""
  declare -g DBNAME_N=""
  declare -g DBSTAGE=""
  declare -g DBUSER=""
  declare -g DBUSERPSW=""

  while [ $# -ge 1 ]; do

    case ${1} in

    # OPTIONS
    -h | -\? | --help)
      show_help # Display a usage synopsis
      exit
      ;;

    -d | --debug)
      DEBUG="true"
      export DEBUG
      ;;

    -e | --env)
      shift
      ENV="${1}"
      export ENV
      ;;

    -sl | --slog)
      shift
      SLOG="${1}"
      export SLOG
      ;;

    -t | --task)
      shift
      TASK="${1}"
      export TASK
      ;;

    -tf | --file)
      shift
      FILE="${1}"
      export FILE
      ;;

    -tt | --type)
      shift
      TYPE="${1}"
      export TYPE
      ;;

    -st | --subtask)
      shift
      STASK="${1}"
      export STASK
      ;;

    -tv | --task-value)
      shift
      TVALUE="${1}"
      export TVALUE
      ;;

    # PROJECT
    -s | --site)
      shift
      SITE="${1}"
      export SITE
      ;;

    -pn | --pname)
      shift
      PNAME="${1}"
      export PNAME
      ;;

    -pt | --ptype)
      shift
      PTYPE="${1}"
      export PTYPE
      ;;

    -ps | --pstate)
      shift
      PSTATE="${1}"
      export PSTATE
      ;;

    -do | --domain)
      shift
      DOMAIN="${1}"
      export DOMAIN
      ;;

    # DATABASE

    -db | --dbname)
      shift
      DBNAME="${1}"
      export DBNAME
      ;;

    -dbn | --dbname-new)
      shift
      DBNAME_N="${1}"
      export DBNAME_N
      ;;

    -dbs | --dbstage)
      shift
      DBSTAGE="${1}"
      export DBSTAGE
      ;;

    -dbu | --dbuser)
      shift
      DBUSER="${1}"
      export DBUSER
      ;;

    -dbup | --dbuser-psw)
      shift
      DBUSERPSW="${1}"
      export DBUSERPSW
      ;;

    *)
      echo "Invalid option: ${1}" >&2
      exit
      ;;

    esac

    shift

  done

  # Script initialization
  script_init "true"

  tasks_handler "${TASK}"

}

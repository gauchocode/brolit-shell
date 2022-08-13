#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc13
################################################################################
#
# Log and Display Helper: Log and display functions.
#
################################################################################

function _timestamp() {

  date +"%T"

}

################################################################################
# Private function to make spinner works
#
# Arguments:
#  $1 start/stop
#
#  on start: $2 display message
#  on stop : $2 process exit status
#            $3 spinner function pid (supplied from spinner_stop)
#
# Outputs:
#  nothing
################################################################################

function _spinner() {

  #local on_success="DONE"
  #local on_fail="FAIL"

  case $1 in

  start)

    # calculate the column where spinner and status msg will be displayed
    TEXT="${2}"
    INDENT=6
    LINESIZE=$(
      export LC_ALL=
      echo "${TEXT}" | wc -m | tr -d ' '
    )
    if [[ ${INDENT} -gt 0 ]]; then SPACES=$((62 - INDENT - LINESIZE)); fi
    if [[ ${SPACES} -lt 0 ]]; then SPACES=0; fi

    echo -e -n "\033[${INDENT}C${TEXT}${NORMAL}\033[${SPACES}C" >&2

    # start spinner
    i=1
    sp='\|/-'
    delay=${SPINNER_DELAY:-0.15}

    while :; do
      printf "\b${sp:i++%${#sp}:1}" >&2
      sleep "${delay}"
    done

    ;;

  stop)

    if [[ -z ${3} ]]; then
      # spinner is not running
      exit 1
    fi

    # Remove start spinner line
    echo "" >&2
    clear_previous_lines "1"

    kill "${3}" >/dev/null 2>&1

    ;;

  *)
    #invalid argument
    exit 1
    ;;

  esac

}

################################################################################
# Start spinner
#
# Arguments:
#   $1 = msg to display
#
# Outputs:
#   nothing
################################################################################

function spinner_start() {

  if [[ ${QUIET} == "true" || ${EXEC_TYPE} == "alias" ]]; then return 0; fi

  _spinner "start" "${1}" &

  # set global spinner pid
  _sp_pid=$!
  disown

}

################################################################################
# Stop spinner
#
# Arguments:
#  $1 = command exit status
#
# Outputs:
#  nothing
################################################################################

function spinner_stop() {

  if [[ ${QUIET} == "true" || ${EXEC_TYPE} == "alias" ]]; then return 0; fi

  _spinner "stop" "${1}" "${_sp_pid}"
  unset _sp_pid

}

################################################################################
# Write on log
#
# Arguments:
#  $1 = {log_type} (success, info, warning, error, critical)
#  $2 = {message}
#  $3 = {console_display} optional (true or false, default is false)
#  $4 = {status} optional (1 only if script execution ends)
#
# Outputs:
#  nothing
################################################################################

# TODO: refactor to something like these?
## log --message "- Testing project ${URL_TO_TEST}" --type "info" --display "false" --status "0"

function log_event() {

  local log_type="${1}"
  local message="${2}"
  local console_display="${3}"
  local status="${4}" #optional

  # Status 0 if empty
  [[ -z ${status} ]] && status="0"

  # Do not log
  [[ ${EXEC_TYPE} == "alias" ]] && return 0
  [[ ${EXEC_TYPE} == "external" && -z ${log_type} ]] && return 0
  [[ ${DEBUG} == "true" && ${log_type} == "debug" ]] && return 0

  # If is a BROLIT UI exec
  if [[ ${EXEC_TYPE} == "external" && -n ${log_type} ]]; then

    inner=$(
      jq -n --arg time "$(_timestamp)" \
        --arg message "${message}" \
        --arg log_type "${log_type}" \
        '$ARGS.named'
    )
    final=$(
      jq -n --arg status "${status}" \
        --argjson output "[$inner]" \
        '$ARGS.named'
    )

    if [[ ${status} == "1" ]]; then
      echo "${final}]" >>"${LOG}"
    else
      echo "${final}," >>"${LOG}"
    fi

    return 0

  fi

  case ${log_type} in

  success)
    echo "$(_timestamp) > SUCCESS: ${message}" >>"${LOG}"
    if [[ ${console_display} == "true" && ${QUIET} == "false" ]]; then
      echo -e "${B_GREEN} > ${message}${ENDCOLOR}" >&2
    fi
    ;;

  info)
    echo "$(_timestamp) > INFO: ${message}" >>"${LOG}"
    if [[ ${console_display} == "true" && ${QUIET} == "false" ]]; then
      echo -e "${B_CYAN} > ${message}${ENDCOLOR}" >&2
    fi
    ;;

  warning)
    echo "$(_timestamp) > WARNING: ${message}" >>"${LOG}"
    if [[ ${console_display} == "true" && ${QUIET} == "false" ]]; then
      echo -e "${YELLOW}${ITALIC} > ${message}${ENDCOLOR}" >&2
    fi
    ;;

  error)
    echo "$(_timestamp) > ERROR: ${message}" >>"${LOG}"
    if [[ ${console_display} == "true" && ${QUIET} == "false" ]]; then
      echo -e "${RED} > ${message}${ENDCOLOR}" >&2
    fi
    ;;

  critical)
    echo "$(_timestamp) > CRITICAL: ${message}" >>"${LOG}"
    if [[ ${console_display} == "true" && ${QUIET} == "false" ]]; then
      echo -e "${B_RED} > ${message}${ENDCOLOR}" >&2
    fi
    ;;

  debug)
    echo "$(_timestamp) > DEBUG: ${message}" >>"${LOG}"
    if [[ ${console_display} == "true" && ${QUIET} == "false" ]]; then
      echo -e "${B_MAGENTA} > ${message}${ENDCOLOR}" >&2
    fi
    ;;

  *)
    echo "$(_timestamp) > ${message}" >>"${LOG}"
    if [[ ${console_display} == "true" && ${QUIET} == "false" ]]; then
      echo -e "${CYAN}${B_DEFAULT} > ${message}${ENDCOLOR}" >&2
    fi
    ;;

  esac

}

################################################################################
# Break line on log
#
# Arguments:
#  $1 = {console_display} optional (true or false, emtpy equals false)
#
# Outputs:
#   nothing
################################################################################

function log_break() {

  local console_display="${1}"

  local log_break

  [[ ${QUIET} == "true" || ${EXEC_TYPE} != "default" ]] && return 0

  # Console Display
  if [[ ${console_display} == "true" ]]; then
    log_break="        ----------------------------------------------------          "
    echo -e "${MAGENTA}${B_DEFAULT}${log_break}${ENDCOLOR}" >&2
  fi

  # Write log file
  log_break="$(_timestamp) > ------------------------------------------------------------"
  echo "${log_break}" >>"${LOG}"

}

################################################################################
# Log section
#
# Arguments:
#  $1 = {message}
#
# Outputs:
#   nothing
################################################################################

function log_section() {

  local message="${1}"

  [[ ${QUIET} == "true" || ${EXEC_TYPE} != "default" ]] && return 0

  # Console Display
  echo "" >&2
  echo -e "[+] Performing Action: ${YELLOW}${B_DEFAULT}${message}${ENDCOLOR}" >&2
  #echo "--------------------------------------------------" >&2
  echo "—————————————————————————————————————————————————————————" >&2

  # Write log file
  echo "$(_timestamp) > ------------------------------------------------------------" >>"${LOG}"
  echo "$(_timestamp) > [+] Performing Action: ${message}" >>"${LOG}"
  echo "$(_timestamp) > ------------------------------------------------------------" >>"${LOG}"

}

################################################################################
# Log sub-section
#
# Arguments:
#  $1 = {message}
#
# Outputs:
#   nothing
################################################################################

function log_subsection() {

  local message="${1}"

  [[ ${QUIET} == "true" || ${EXEC_TYPE} != "default" ]] && return 0

  # Console Display
  echo "" >&2
  echo -e "    [·] ${CYAN}${B_DEFAULT}${message}${ENDCOLOR}" >&2
  echo "    —————————————————————————————————————————————————————" >&2

  # Write log file
  echo "$(_timestamp) > ------------------------------------------------------------" >>"${LOG}"
  echo "$(_timestamp) > [·] ${message}" >>"${LOG}"
  echo "$(_timestamp) > ------------------------------------------------------------" >>"${LOG}"

}

################################################################################
# Clear screen
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function clear_screen() {

  [[ ${QUIET} == "true" || ${EXEC_TYPE} != "default" ]] && return 0

  # Console Display
  echo -en "\ec" >&2

}

################################################################################
# Clear previous lines
#
# Arguments:
#   $1 = {lines}
#
# Outputs:
#   nothing
################################################################################

function clear_previous_lines() {

  local lines="${1}"

  [[ ${QUIET} == "true" || ${EXEC_TYPE} != "default" ]] && return 0

  # Loop starting $lines going down to 0
  for ((i = lines; i > 0; i--)); do

    tput cuu1 >&2
    tput el >&2

  done

}

################################################################################
# Display message on terminal
#
# Arguments:
#   --text, --color, --indent, --result, --tcolor, --tstyle
#
# Outputs:
#   nothing
################################################################################

function display() {

  INDENT=0
  TEXT=""
  RESULT=""
  TCOLOR=""
  TSTYLE=""
  COLOR=""
  SPACES=0

  [[ ${QUIET} == "true" || ${EXEC_TYPE} != "default" ]] && return 0

  while [ $# -ge 1 ]; do

    case $1 in

    --color)
      shift
      case $1 in
      GREEN) COLOR=${GREEN} ;;
      RED) COLOR=${RED} ;;
      WHITE) COLOR=${WHITE} ;;
      YELLOW) COLOR=${YELLOW} ;;
      MAGENTA) COLOR=${MAGENTA} ;;
      esac
      ;;

    --indent)
      shift
      INDENT="${1}"
      ;;

    --result)
      shift
      RESULT="${1}"
      ;;

    --tcolor)
      shift
      case $1 in
      GREEN) TCOLOR=${GREEN} ;;
      RED) TCOLOR=${RED} ;;
      WHITE) TCOLOR=${WHITE} ;;
      YELLOW) TCOLOR=${YELLOW} ;;
      MAGENTA) TCOLOR=${MAGENTA} ;;
      esac
      ;;

    --tstyle)
      shift
      case $1 in
      NORMAL) TSTYLE=${NORMAL} ;;
      BOLD) TSTYLE=${BOLD} ;;
      ITALIC) TSTYLE=${ITALIC} ;;
      UNDERLINED) TSTYLE=${UNDERLINED} ;;
      INVERTED) TSTYLE=${INVERTED} ;;
      esac
      ;;

    --text)
      shift
      TEXT="${1}"
      ;;

    *)
      log_event "critical" "Invalid parameter for 'display' function: $1" "true"
      exit 1
      ;;

    esac

    # Go to next parameter
    shift

  done

  if [[ -n "${TEXT}" ]]; then
  
    if [[ -z "${RESULT}" ]]; then
      RESULTPART=""
    else

      #if [[ ${EXEC_TYPE} == "default" ]]; then
      RESULTPART=" [ ${COLOR}${B_DEFAULT}${RESULT}${NORMAL} ]"
      #else
      #  RESULTPART=" [ ${RESULT} ]"
      #fi

    fi
    #SHOW=0
    #if [[ ${SHOW} -eq 0 ]]; then

    # Display:
    # - for full shells, count with -m instead of -c, to support language locale (older busybox does not have -m)
    # - wc needs LANG to deal with multi-bytes characters but LANG has been unset in include/consts
    TEXT_C="$(string_remove_color_chars "${TEXT}")"

    LINESIZE="$(
      export LC_ALL=
      echo "${TEXT_C}" | wc -m | tr -d ' '
    )"

    if [[ "${INDENT}" -gt 0 ]]; then SPACES=$((62 - INDENT - LINESIZE)); fi
    if [[ "${SPACES}" -lt 0 ]]; then SPACES=0; fi

    echo -e "\033[${INDENT}C${TCOLOR}${TSTYLE}${TEXT}${NORMAL}\033[${SPACES}C${RESULTPART}${DEBUGTEXT}" >&2

    #fi
  fi

}

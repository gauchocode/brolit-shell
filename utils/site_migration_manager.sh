#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.10
################################################################################
#
# Site Migration Manager: CLI subtask dispatch and interactive menu for
# migrating a Dockerized project from this server to a destination server.
#
################################################################################

################################################################################
# CLI subtask dispatch for the `migrate` task
#
# Arguments:
#   ${1} = ${subtask}
#   ${2} = ${domain}
#   ${3} = ${dest_host}
#   ${4} = ${dest_user}
#   ${5} = ${dest_port}
#   ${6} = ${dest_ssh_key}
#   ${7} = ${decommission_source}
#   ${8} = ${purge_volumes}
#   ${9} = ${bootstrap_dest_config}
#   ${10} = ${force}
#   ${11} = ${dest_path}
#   ${12} = ${transport} ("local" or "dropbox")
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function subtasks_migrate_handler() {

  local subtask="${1}"
  local domain="${2}"
  local dest_host="${3}"
  local dest_user="${4}"
  local dest_port="${5}"
  local dest_ssh_key="${6}"
  local decommission_source="${7}"
  local purge_volumes="${8}"
  local bootstrap_dest_config="${9}"
  local force="${10}"
  local dest_path="${11}"
  local transport="${12:-local}"

  case ${subtask} in

  site)
    migrate_site "${domain}" "${dest_host}" "${dest_user}" "${dest_port}" "${dest_ssh_key}" \
      "${decommission_source}" "${purge_volumes}" "${bootstrap_dest_config}" "${force}" "${dest_path}" "${transport}"
    ;;

  *)
    log_event "error" "Migrate: invalid subtask '${subtask}'" "true"
    return 1
    ;;

  esac

}

################################################################################
# Interactive site migration menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function site_migration_manager_menu() {

  local domain
  local dest_host
  local dest_user
  local dest_port
  local dest_ssh_key
  local decommission_source="false"
  local purge_volumes="false"
  local force="false"
  local confirm_decommission
  local transport

  log_section "Migrate Site"

  display --indent 2 --text "- Site migration currently supports Dockerized projects only" --tcolor YELLOW

  domain="$(whiptail --title "MIGRATE SITE" --inputbox "Domain to migrate:" 10 60 3>&1 1>&2 2>&3)"
  [[ -z ${domain} ]] && return 1

  dest_host="$(whiptail --title "MIGRATE SITE" --inputbox "Destination host/IP:" 10 60 3>&1 1>&2 2>&3)"
  [[ -z ${dest_host} ]] && return 1

  dest_user="$(whiptail --title "MIGRATE SITE" --inputbox "Destination SSH user:" 10 60 "root" 3>&1 1>&2 2>&3)"
  [[ -z ${dest_user} ]] && return 1

  dest_port="$(whiptail --title "MIGRATE SITE" --inputbox "Destination SSH port:" 10 60 "22" 3>&1 1>&2 2>&3)"
  [[ -z ${dest_port} ]] && dest_port="22"

  dest_ssh_key="$(whiptail --title "MIGRATE SITE" --inputbox "Path to SSH private key for destination:" 10 60 "~/.ssh/id_ed25519" 3>&1 1>&2 2>&3)"
  [[ -z ${dest_ssh_key} ]] && return 1
  dest_ssh_key="${dest_ssh_key/#\~/${HOME}}"

  if whiptail --title "MIGRATE SITE" --yesno "Destination path already exists? Overwrite it (--force)?" 10 60 --defaultno 3>&1 1>&2 2>&3; then
    force="true"
  fi

  if whiptail --title "MIGRATE SITE" --yesno "Transport: use direct rsync (faster, requires local backup storage enabled on both servers)?\n\nYES = local (rsync)\nNO = dropbox (reuses shared Dropbox account, slower, no local storage required)" 12 70 3>&1 1>&2 2>&3; then
    transport="local"
  else
    transport="dropbox"
  fi

  if whiptail --title "DECOMMISSION SOURCE" --yesno "After a VERIFIED migration, stop and remove the SOURCE project (Docker stack, files, nginx vhost, certificates)?\n\nThis is IRREVERSIBLE. Only the backup artifact will remain on this server.\n\nRecommended: answer NO here first, confirm the migrated site manually, then re-run with this option to clean up." 16 70 --defaultno 3>&1 1>&2 2>&3; then

    confirm_decommission="$(whiptail --title "CONFIRM DECOMMISSION" --inputbox "Type the domain (${domain}) again to confirm source decommissioning:" 10 60 3>&1 1>&2 2>&3)"

    if [[ ${confirm_decommission} == "${domain}" ]]; then
      decommission_source="true"

      if whiptail --title "PURGE VOLUMES" --yesno "Also delete the source project's Docker volumes (database data)?\n\nThis is IRREVERSIBLE DATA LOSS." 12 70 --defaultno 3>&1 1>&2 2>&3; then
        purge_volumes="true"
      fi
    else
      display --indent 2 --text "- Decommission confirmation did not match, skipping decommission" --tcolor YELLOW
    fi

  fi

  migrate_site "${domain}" "${dest_host}" "${dest_user}" "${dest_port}" "${dest_ssh_key}" \
    "${decommission_source}" "${purge_volumes}" "false" "${force}" "" "${transport}"

}

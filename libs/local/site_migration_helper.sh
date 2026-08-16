#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.10
################################################################################
#
# Site Migration Helper: orchestrates moving a Dockerized project from this
# server (source) to a destination server over SSH, reusing existing backup
# and restore logic on each end. Run only from the source server.
#
################################################################################

# Default path where brolit-shell is expected/installed on the destination.
declare -g MIGRATE_DEST_BROLIT_DIR="/root/brolit-shell"

################################################################################
# Private: run a command on the destination over SSH
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${remote_cmd}
#
# Outputs:
#   Remote command stdout/stderr; returns the remote command's exit code
################################################################################

function _migrate_ssh() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local remote_cmd="${5}"

  ssh -i "${dest_ssh_key}" -p "${dest_port}" \
    -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
    "${dest_user}@${dest_host}" -- "${remote_cmd}"

}

################################################################################
# Private: rsync a local path to a path on the destination over SSH
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${local_path}
#   ${6} = ${remote_path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _migrate_rsync_push() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local local_path="${5}"
  local remote_path="${6}"

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "mkdir -p '${remote_path}'"
  [[ $? -ne 0 ]] && return 1

  rsync --archive --compress --recursive \
    -e "ssh -i '${dest_ssh_key}' -p '${dest_port}' -o BatchMode=yes -o StrictHostKeyChecking=accept-new" \
    "${local_path}" "${dest_user}@${dest_host}:${remote_path}"

}

################################################################################
# Verify the requested domain is a Dockerized project (v1 scope)
#
# Arguments:
#   ${1} = ${domain}
#
# Outputs:
#   0 if it's a Docker project, 1 otherwise.
################################################################################

function migrate_check_docker_project() {

  local domain="${1}"

  local project_install_type

  if [[ ! -d "${PROJECTS_PATH}/${domain}" ]]; then
    log_event "error" "Migrate: project not found for domain ${domain}" "true"
    display --indent 6 --text "- Project ${domain}" --result "NOT FOUND" --color RED
    return 1
  fi

  project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${domain}")"

  if [[ ${project_install_type} != "docker"* ]]; then
    log_event "error" "Migrate: ${domain} is not a Docker project (install type: ${project_install_type}). Site migration currently supports Dockerized projects only." "true"
    display --indent 6 --text "- Docker project check" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Docker project check" --result "DONE" --color GREEN
  return 0

}

################################################################################
# Verify SSH connectivity to the destination
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#
# Outputs:
#   0 if reachable, 1 otherwise.
################################################################################

function migrate_check_ssh_connectivity() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"

  if [[ ! -f "${dest_ssh_key}" ]]; then
    log_event "error" "Migrate: SSH key not found: ${dest_ssh_key}" "true"
    display --indent 6 --text "- SSH key" --result "NOT FOUND" --color RED
    return 1
  fi

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "true"

  if [[ $? -ne 0 ]]; then
    log_event "error" "Migrate: cannot reach ${dest_user}@${dest_host}:${dest_port} over SSH" "true"
    display --indent 6 --text "- SSH connectivity to destination" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- SSH connectivity to destination" --result "DONE" --color GREEN
  return 0

}

################################################################################
# Verify Docker and Docker Compose are available on the destination
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#
# Outputs:
#   0 if present, 1 otherwise.
################################################################################

function migrate_check_dest_docker() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1"

  if [[ $? -ne 0 ]]; then
    log_event "error" "Migrate: destination is missing Docker or Docker Compose" "true"
    display --indent 6 --text "- Destination Docker/Compose" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Destination Docker/Compose" --result "DONE" --color GREEN
  return 0

}

################################################################################
# Verify (and if missing, bootstrap-install) brolit-shell on the destination
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#
# Outputs:
#   0 if brolit-shell is present (or was successfully bootstrapped), 1 on error.
################################################################################

function migrate_check_dest_brolit() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "[ -x '${MIGRATE_DEST_BROLIT_DIR}/runner.sh' ] && [ -f ~/.brolit_conf.json ]"

  if [[ $? -eq 0 ]]; then
    display --indent 6 --text "- Destination brolit-shell installation" --result "DONE" --color GREEN
    return 0
  fi

  log_event "warning" "Migrate: brolit-shell not found on destination, attempting bootstrap install" "false"
  display --indent 6 --text "- Destination brolit-shell installation" --result "MISSING" --color YELLOW

  migrate_bootstrap_dest_brolit "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}"

}

################################################################################
# Best-effort minimal bootstrap install of brolit-shell on the destination
#
# NOTE: this is a fallback path for a destination that has never run brolit.
# It only enables the webserver role — it does NOT configure DNS/SSL/backup
# credentials, which migrate_check_dest_dns_ssl_config()/migrate_check_dest_backup_local()
# will still require afterward. Not exercised by initial real-world validation
# against an already-provisioned destination (see tasks.md section 8).
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function migrate_bootstrap_dest_brolit() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"

  local remote_cmd
  remote_cmd="set -e; \
    if [ ! -d '${MIGRATE_DEST_BROLIT_DIR}' ]; then \
      git clone https://github.com/gauchocode/brolit-shell '${MIGRATE_DEST_BROLIT_DIR}'; \
    fi; \
    chmod +x '${MIGRATE_DEST_BROLIT_DIR}/runner.sh'; \
    if [ ! -f ~/.brolit_conf.json ]; then \
      cp '${MIGRATE_DEST_BROLIT_DIR}/config/brolit/brolit_conf.json' ~/.brolit_conf.json; \
      jq '.SERVER_CONFIG.config[0].webserver = \"enabled\"' ~/.brolit_conf.json > ~/.brolit_conf.json.tmp && mv ~/.brolit_conf.json.tmp ~/.brolit_conf.json; \
    fi"

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${remote_cmd}"

  if [[ $? -ne 0 ]]; then
    log_event "error" "Migrate: bootstrap install of brolit-shell on destination failed" "true"
    display --indent 6 --text "- Bootstrapping brolit-shell on destination" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Bootstrapping brolit-shell on destination" --result "DONE" --color GREEN
  return 0

}

################################################################################
# Verify the destination has DNS (Cloudflare) and SSL (certbot) configured,
# since the destination's own restore process depends on this to configure
# the vhost/DNS/SSL automatically. Optionally bootstraps Cloudflare config
# from the source's own config if requested.
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${bootstrap_dest_config} ("true"/"false")
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function migrate_check_dest_dns_ssl_config() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local bootstrap_dest_config="${5:-false}"

  local dest_cf_status
  local dest_certbot_status

  dest_cf_status="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "jq -r '.DNS.cloudflare[0].status // empty' ~/.brolit_conf.json 2>/dev/null")"
  dest_certbot_status="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "jq -r '.PACKAGES.certbot[0].status // empty' ~/.brolit_conf.json 2>/dev/null")"

  if [[ ${dest_cf_status} == "enabled" && ${dest_certbot_status} == "enabled" ]]; then
    display --indent 6 --text "- Destination DNS/SSL configuration" --result "DONE" --color GREEN
    return 0
  fi

  if [[ ${bootstrap_dest_config} != "true" ]]; then
    log_event "error" "Migrate: destination is missing Cloudflare/certbot configuration (cloudflare=${dest_cf_status:-disabled}, certbot=${dest_certbot_status:-disabled}). Configure it on the destination, or re-run with --bootstrap-dest-config." "true"
    display --indent 6 --text "- Destination DNS/SSL configuration" --result "FAIL" --color RED
    return 1
  fi

  log_event "warning" "Migrate: bootstrapping destination Cloudflare config from source (--bootstrap-dest-config)" "true"
  display --indent 6 --text "- Destination DNS/SSL configuration" --result "BOOTSTRAPPING" --color YELLOW

  if [[ ${SUPPORT_CLOUDFLARE_STATUS} != "enabled" ]]; then
    log_event "error" "Migrate: --bootstrap-dest-config requested, but source has no Cloudflare configuration to copy" "true"
    return 1
  fi

  local cf_config_json
  cf_config_json="$(jq -c '.DNS.cloudflare' "${BROLIT_CONFIG_FILE}")"

  local remote_cmd
  remote_cmd="jq --argjson cf '${cf_config_json}' '.DNS.cloudflare = \$cf' ~/.brolit_conf.json > ~/.brolit_conf.json.tmp && mv ~/.brolit_conf.json.tmp ~/.brolit_conf.json"

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${remote_cmd}"

  if [[ $? -ne 0 ]]; then
    log_event "error" "Migrate: failed to copy Cloudflare configuration to destination" "true"
    return 1
  fi

  log_event "info" "Migrate: copied DNS.cloudflare config section from source to destination ~/.brolit_conf.json" "true"

  if [[ ${dest_certbot_status} != "enabled" ]]; then
    log_event "error" "Migrate: destination still has certbot disabled; --bootstrap-dest-config only copies DNS/Cloudflare config, enable certbot on the destination manually" "true"
    return 1
  fi

  return 0

}

################################################################################
# Verify the destination has local backup storage enabled, which migrate uses
# as the hand-off point for the destination's own `restore -st from-storage`.
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#
# Outputs:
#   Prints "${dest_server_name}|${dest_backup_local_path}" on success.
#   Returns 0 if ok, 1 on error.
################################################################################

function migrate_check_dest_backup_local() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"

  local dest_local_status
  local dest_local_path
  local dest_server_name

  dest_local_status="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "jq -r '.BACKUPS.methods[0].local[0].status // empty' ~/.brolit_conf.json 2>/dev/null")"

  if [[ ${dest_local_status} != "enabled" ]]; then
    log_event "error" "Migrate: destination does not have local backup storage enabled (BACKUPS.methods.local), which migrate requires as the transfer hand-off point" "true"
    display --indent 6 --text "- Destination local backup storage" --result "FAIL" --color RED
    return 1
  fi

  dest_local_path="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "jq -r '.BACKUPS.methods[0].local[0].config[0].backup_path // empty' ~/.brolit_conf.json 2>/dev/null")"
  dest_server_name="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "hostname")"

  if [[ -z "${dest_local_path}" || -z "${dest_server_name}" ]]; then
    log_event "error" "Migrate: could not resolve destination backup path/server name" "true"
    display --indent 6 --text "- Destination local backup storage" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Destination local backup storage" --result "DONE" --color GREEN
  echo "${dest_server_name}|${dest_local_path}"
  return 0

}

################################################################################
# Resolve the destination project path for the domain
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${dest_path_override} (optional)
#
# Outputs:
#   ${dest_path}
################################################################################

function migrate_resolve_dest_path() {

  local domain="${1}"
  local dest_path_override="${2:-}"

  if [[ -n "${dest_path_override}" ]]; then
    echo "${dest_path_override}"
  else
    echo "${PROJECTS_PATH}/${domain}"
  fi

}

################################################################################
# Verify the destination project path does not already exist, unless forced
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${dest_path}
#   ${6} = ${force} ("true"/"false")
#
# Outputs:
#   0 if ok to proceed, 1 otherwise.
################################################################################

function migrate_check_dest_path_collision() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local dest_path="${5}"
  local force="${6:-false}"

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "[ -d '${dest_path}' ]"

  if [[ $? -eq 0 && ${force} != "true" ]]; then
    log_event "error" "Migrate: destination path already exists: ${dest_path} (use --force to overwrite)" "true"
    display --indent 6 --text "- Destination path collision check" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Destination path collision check" --result "DONE" --color GREEN
  return 0

}

################################################################################
# Capture the source project using existing Docker backup logic
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${transport} ("local" requires BACKUP_LOCAL_STATUS enabled on the
#          source; "dropbox" requires BACKUP_DROPBOX_STATUS enabled instead)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function migrate_capture_source() {

  local domain="${1}"
  local transport="${2:-local}"

  if [[ ${transport} == "local" && ${BACKUP_LOCAL_STATUS} != "enabled" ]]; then
    log_event "error" "Migrate: --transport local requires local backup storage enabled (BACKUPS.methods.local) on the source" "true"
    display --indent 6 --text "- Source local backup storage" --result "FAIL" --color RED
    return 1
  fi

  if [[ ${transport} == "dropbox" && ${BACKUP_DROPBOX_STATUS} != "enabled" ]]; then
    log_event "error" "Migrate: --transport dropbox requires Dropbox backup storage enabled on the source" "true"
    display --indent 6 --text "- Source Dropbox storage" --result "FAIL" --color RED
    return 1
  fi

  log_subsection "Migrate: Capture Source"

  backup_docker_project "${domain}" "site"
  local capture_result=$?

  if [[ ${capture_result} -ne 0 ]]; then
    log_event "error" "Migrate: capturing source project ${domain} failed" "true"
    display --indent 6 --text "- Source capture" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Source capture" --result "DONE" --color GREEN
  return 0

}

################################################################################
# Transfer the captured backup artifact tree to the destination, namespaced
# under the destination's own server name so its `restore -st from-storage`
# finds it exactly as if it had made the backup itself.
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${domain}
#   ${6} = ${dest_server_name}
#   ${7} = ${dest_backup_local_path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function migrate_transfer_artifact() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local domain="${5}"
  local dest_server_name="${6}"
  local dest_backup_local_path="${7}"

  local db_name
  db_name="$(project_get_configured_database "${PROJECTS_PATH}/${domain}" "$(project_get_type "${PROJECTS_PATH}/${domain}")" "$(project_get_install_type "${PROJECTS_PATH}/${domain}")")"

  local source_site_path="${BACKUP_LOCAL_CONFIG_BACKUP_PATH}/${SERVER_NAME}/projects-online/site/${domain}/"
  local dest_site_path="${dest_backup_local_path}/${dest_server_name}/projects-online/site/${domain}/"

  log_subsection "Migrate: Transfer Artifact"

  _migrate_rsync_push "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "${source_site_path}" "${dest_site_path}"

  if [[ $? -ne 0 ]]; then
    log_event "error" "Migrate: transferring site files artifact failed" "true"
    display --indent 6 --text "- Transfer site files" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Transfer site files" --result "DONE" --color GREEN

  if [[ -n "${db_name}" && -d "${BACKUP_LOCAL_CONFIG_BACKUP_PATH}/${SERVER_NAME}/projects-online/database/${db_name}" ]]; then

    local source_db_path="${BACKUP_LOCAL_CONFIG_BACKUP_PATH}/${SERVER_NAME}/projects-online/database/${db_name}/"
    local dest_db_path="${dest_backup_local_path}/${dest_server_name}/projects-online/database/${db_name}/"

    _migrate_rsync_push "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
      "${source_db_path}" "${dest_db_path}"

    if [[ $? -ne 0 ]]; then
      log_event "error" "Migrate: transferring database artifact failed" "true"
      display --indent 6 --text "- Transfer database" --result "FAIL" --color RED
      return 1
    fi

    display --indent 6 --text "- Transfer database" --result "DONE" --color GREEN

  else

    log_event "info" "Migrate: no database artifact found for ${domain} (db_name=${db_name}), skipping database transfer" "false"

  fi

  return 0

}

################################################################################
# Trigger a normal restore on the destination via SSH. Reuses the
# destination's own restore -st from-storage, which already handles files,
# database, port collisions, nginx vhost, DNS, and SSL. Does not reimplement
# any of that here.
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${domain}
#   ${6} = ${storage_method} ("local" or "dropbox" - forces which storage
#          method the destination's restore uses, matching --transport)
#
# For --transport dropbox, the backup was uploaded under this (source)
# server's own ${SERVER_NAME} namespace in the shared Dropbox account -
# not the destination's. --source-server tells the destination's restore
# to look there instead of its own ${SERVER_NAME}. Not needed for
# --transport local, since the rsync transfer already placed the artifact
# under the destination's own namespace.
#
# Outputs:
#   0 if the remote restore succeeded, 1 on error (propagates remote exit code).
################################################################################

function migrate_trigger_remote_restore() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local domain="${5}"
  local storage_method="${6:-local}"

  log_subsection "Migrate: Remote Restore"

  local remote_cmd="cd '${MIGRATE_DEST_BROLIT_DIR}' && ./runner.sh -t restore -st from-storage -D '${domain}' --storage-method '${storage_method}'"

  if [[ ${storage_method} == "dropbox" ]]; then
    remote_cmd="${remote_cmd} --source-server '${SERVER_NAME}'"
  fi

  _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${remote_cmd}"
  local restore_result=$?

  if [[ ${restore_result} -ne 0 ]]; then
    log_event "error" "Migrate: remote restore failed on destination (exit code ${restore_result})" "true"
    display --indent 6 --text "- Remote restore" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Remote restore" --result "DONE" --color GREEN
  return 0

}

################################################################################
# Verify the destination site responds, without depending on DNS propagation.
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${domain}
#
# Outputs:
#   0 if verified, 1 otherwise.
################################################################################

function migrate_verify_destination() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local domain="${5}"

  local dest_ip="${dest_host}"

  # If dest_host is a hostname rather than an IP, resolve the destination's
  # own public IP over SSH instead of relying on local DNS resolution.
  if ! [[ ${dest_host} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    dest_ip="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "curl -s https://api.ipify.org")"
  fi

  log_subsection "Migrate: Verify Destination"

  if [[ -z "${dest_ip}" ]]; then
    log_event "error" "Migrate: could not resolve destination IP for verification" "true"
    display --indent 6 --text "- Destination verification" --result "FAIL" --color RED
    return 1
  fi

  curl --silent --fail --max-time 15 --resolve "${domain}:443:${dest_ip}" "https://${domain}/" >/dev/null

  if [[ $? -eq 0 ]]; then
    display --indent 6 --text "- Destination verification (HTTPS)" --result "DONE" --color GREEN
    return 0
  fi

  curl --silent --fail --max-time 15 --resolve "${domain}:80:${dest_ip}" "http://${domain}/" >/dev/null

  if [[ $? -eq 0 ]]; then
    display --indent 6 --text "- Destination verification (HTTP only, SSL may not be ready yet)" --result "WARNING" --color YELLOW
    return 0
  fi

  log_event "error" "Migrate: destination did not respond for ${domain} at ${dest_ip}" "true"
  display --indent 6 --text "- Destination verification" --result "FAIL" --color RED
  return 1

}

################################################################################
# Decommission the source project. Only ever called after a verified-good
# migration and only when explicitly requested. Reuses project_delete(),
# which already stops containers, removes files/nginx/certs/config, and
# safely skips deleting the Cloudflare record if it no longer points here.
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${restore_result} (0/1 - exit code from migrate_trigger_remote_restore)
#   ${3} = ${verification_result} (0/1 - exit code from migrate_verify_destination)
#   ${4} = ${purge_volumes} ("true"/"false")
#
# Outputs:
#   0 if ok, 1 on error or if the guard refuses to run.
################################################################################

function migrate_decommission_source() {

  local domain="${1}"
  local restore_result="${2}"
  local verification_result="${3}"
  local purge_volumes="${4:-false}"

  # Defense in depth: refuse to run against an unverified migration,
  # independent of whatever gating the caller already did.
  if [[ ${restore_result} -ne 0 || ${verification_result} -ne 0 ]]; then
    log_event "error" "Migrate: refusing to decommission source for ${domain} — restore_result=${restore_result} verification_result=${verification_result}" "true"
    display --indent 6 --text "- Source decommission" --result "REFUSED" --color RED
    return 1
  fi

  log_subsection "Migrate: Decommission Source"

  local compose_file="${PROJECTS_PATH}/${domain}/docker-compose.yml"
  local volume_names=""

  if [[ ${purge_volumes} == "true" && -f "${compose_file}" ]]; then
    volume_names="$(docker compose -f "${compose_file}" config --volumes 2>/dev/null)"
  fi

  # project_delete() already: stops the docker stack, makes a final backup,
  # removes files/nginx vhost/certificates/project config, and only deletes
  # the Cloudflare record if it still points at this server's own IP (it
  # won't, once the destination's restore has repointed it).
  project_delete "${domain}" "true"
  local delete_result=$?

  if [[ ${delete_result} -ne 0 ]]; then
    log_event "error" "Migrate: source decommission failed for ${domain}" "true"
    display --indent 6 --text "- Source decommission" --result "FAIL" --color RED
    return 1
  fi

  if [[ ${purge_volumes} == "true" && -n "${volume_names}" ]]; then
    local vol
    for vol in ${volume_names}; do
      docker volume rm "${vol}" >/dev/null 2>&1
    done
    log_event "info" "Migrate: purged Docker volumes for ${domain}: ${volume_names}" "true"
  fi

  display --indent 6 --text "- Source decommission" --result "DONE" --color GREEN
  log_event "info" "Migrate: source ${domain} decommissioned; only the backup artifact remains in ${BROLIT_TMP_DIR}" "true"

  return 0

}

################################################################################
# Top-level orchestrator for `migrate site`
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${dest_host}
#   ${3} = ${dest_user}
#   ${4} = ${dest_port}
#   ${5} = ${dest_ssh_key}
#   ${6} = ${decommission_source} ("true"/"false")
#   ${7} = ${purge_volumes} ("true"/"false")
#   ${8} = ${bootstrap_dest_config} ("true"/"false")
#   ${9} = ${force} ("true"/"false")
#   ${10} = ${dest_path_override} (optional)
#   ${11} = ${transport} ("local" default - direct rsync, requires
#           BACKUPS.methods.local on both ends; "dropbox" - reuses an
#           already-configured shared Dropbox account, no rsync transfer)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function migrate_site() {

  local domain="${1}"
  local dest_host="${2}"
  local dest_user="${3}"
  local dest_port="${4:-22}"
  local dest_ssh_key="${5}"
  local decommission_source="${6:-false}"
  local purge_volumes="${7:-false}"
  local bootstrap_dest_config="${8:-false}"
  local force="${9:-false}"
  local dest_path_override="${10:-}"
  local transport="${11:-local}"

  local dest_path
  local dest_backup_fact
  local dest_server_name
  local dest_backup_local_path
  local restore_result=1
  local verification_result=1

  if [[ ${transport} != "local" && ${transport} != "dropbox" ]]; then
    log_event "error" "Migrate: invalid --transport '${transport}' (must be 'local' or 'dropbox')" "true"
    return 1
  fi

  log_section "Migrate Site: ${domain} -> ${dest_host} (transport: ${transport})"

  migrate_check_docker_project "${domain}" || return 1
  migrate_check_ssh_connectivity "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" || return 1
  migrate_check_dest_docker "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" || return 1
  migrate_check_dest_brolit "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" || return 1
  migrate_check_dest_dns_ssl_config "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${bootstrap_dest_config}" || return 1

  if [[ ${transport} == "local" ]]; then
    dest_backup_fact="$(migrate_check_dest_backup_local "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}")"
    [[ $? -ne 0 ]] && return 1
    dest_server_name="${dest_backup_fact%%|*}"
    dest_backup_local_path="${dest_backup_fact##*|}"
  fi

  dest_path="$(migrate_resolve_dest_path "${domain}" "${dest_path_override}")"
  migrate_check_dest_path_collision "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${dest_path}" "${force}" || return 1

  migrate_capture_source "${domain}" "${transport}" || return 1

  if [[ ${transport} == "local" ]]; then
    migrate_transfer_artifact "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
      "${domain}" "${dest_server_name}" "${dest_backup_local_path}" || return 1
  else
    log_event "info" "Migrate: --transport dropbox, skipping direct rsync transfer (backup_docker_project already uploaded to the shared Dropbox account)" "false"
  fi

  migrate_trigger_remote_restore "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${domain}" "${transport}"
  restore_result=$?

  if [[ ${restore_result} -eq 0 ]]; then
    migrate_verify_destination "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${domain}"
    verification_result=$?
  fi

  if [[ ${decommission_source} == "true" ]]; then
    migrate_decommission_source "${domain}" "${restore_result}" "${verification_result}" "${purge_volumes}"
  fi

  if [[ ${restore_result} -ne 0 || ${verification_result} -ne 0 ]]; then
    log_event "error" "Migrate: migration of ${domain} did not complete successfully; source left untouched" "true"
    return 1
  fi

  log_event "info" "Migrate: migration of ${domain} to ${dest_host} completed and verified" "true"
  return 0

}

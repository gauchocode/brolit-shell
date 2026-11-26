#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Site Migration Helper: orchestrates moving a Dockerized project from this
# server (source) to a destination server over SSH, reusing existing backup
# and restore logic on each end. Run only from the source server.
#
################################################################################

# Default path where brolit-shell is expected/installed on the destination.
declare -g MIGRATE_DEST_BROLIT_DIR="/root/brolit-shell"

# Migrate-owned local staging path for --transport local, entirely
# independent of .brolit_conf.json's BACKUPS.methods.local (see
# migrate_capture_source() for why). Same fixed path is used on both the
# source and the destination.
declare -g MIGRATE_LOCAL_STAGING_PATH_DEFAULT="/root/.brolit_migrate_staging"

# First brolit-shell release that can restore with the DNS and certificate steps
# deferred (BROLIT_DOMAIN_CONFIG_STAGE=defer, project finalize-domain/verify-local).
# An older destination would ignore the variable and point the domain at itself
# before the migration is verified, so it is refused up front.
declare -g MIGRATE_MIN_DEST_VERSION="3.15.9"
# With --dns-mode external the caller asks the destination for the certificate only
# (project finalize-certificate), which exists from 3.15.12.
declare -g MIGRATE_MIN_DEST_VERSION_EXTERNAL_DNS="3.15.12"

# State of the migration in progress, used to remove its staged captures when it
# ends (see migrate_site / migrate_cleanup_staging). Empty outside a migration.
declare -g MIGRATE_RUN_DOMAIN=""
declare -g MIGRATE_RUN_DEST_HOST=""
declare -g MIGRATE_RUN_DEST_USER=""
declare -g MIGRATE_RUN_DEST_PORT="22"
declare -g MIGRATE_RUN_DEST_SSH_KEY=""
declare -g MIGRATE_RUN_DEST_SERVER_NAME=""
declare -g MIGRATE_RUN_DB_NAME=""
# "1" while a termination signal may remove the staged captures: only the
# capture and transfer phases. During the remote restore the destination reads
# them, so a signal there must not delete anything.
declare -g MIGRATE_STAGING_SIGNAL_SAFE="0"

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
# Private: HTTP status code a destination answers for a domain
#
# Arguments:
#   ${1} = ${scheme} (http or https)
#   ${2} = ${port}
#   ${3} = ${domain}
#   ${4} = ${dest_ip}
#
# Outputs:
#   Three-digit status code, "000" when there was no answer at all.
################################################################################

function _migrate_probe_status() {

  local scheme="${1}"
  local port="${2}"
  local domain="${3}"
  local dest_ip="${4}"

  local status

  status="$(curl --silent --output /dev/null --max-time 15 --write-out '%{http_code}' \
    --resolve "${domain}:${port}:${dest_ip}" "${scheme}://${domain}/" 2>/dev/null)"

  [[ ${status} =~ ^[0-9]{3}$ ]] || status="000"

  echo "${status}"

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
# It only enables the webserver role — it does NOT configure DNS/SSL
# credentials, which migrate_check_dest_dns_ssl_config() will still require
# afterward. Not exercised by initial real-world validation against an
# already-provisioned destination (see tasks.md section 8).
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
# Verify the destination's brolit-shell can defer the DNS and certificate steps
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#
# Outputs:
#   0 if the destination release is at least MIGRATE_MIN_DEST_VERSION, 1 otherwise.
################################################################################

function migrate_check_dest_defer_support() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"

  local dest_version
  local lowest
  local min_version="${MIGRATE_MIN_DEST_VERSION}"
  [[ "${MIGRATE_DNS_MODE:-shell}" == "external" ]] && min_version="${MIGRATE_MIN_DEST_VERSION_EXTERNAL_DNS}"

  dest_version="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "grep -oP 'BROLIT_RELEASE_VERSION=\"\\K[0-9]+(\\.[0-9]+)*' '${MIGRATE_DEST_BROLIT_DIR}/release/version.env' 2>/dev/null | head -n 1")"

  if [[ -n ${dest_version} ]]; then
    lowest="$(printf '%s\n%s\n' "${dest_version}" "${min_version}" | sort -V | head -n 1)"
    if [[ ${lowest} == "${min_version}" ]]; then
      display --indent 6 --text "- Destination brolit-shell ${dest_version} (DNS switch after verification)" --result "DONE" --color GREEN
      return 0
    fi
  fi

  log_event "error" "Migrate: the destination runs brolit-shell ${dest_version:-unknown}; ${min_version} or newer is required so that the domain's DNS is switched only after the destination is verified. Update brolit-shell on the destination first." "true"
  display --indent 6 --text "- Destination brolit-shell version (needs ${min_version}+)" --result "FAIL" --color RED
  return 1

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
# Resolve the destination's hostname, used to namespace the migrate staging
# path exactly the way the destination's own restore -st from-storage will
# look for it (namespaced by ${SERVER_NAME} = $HOSTNAME, per libs/commons.sh).
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#
# Outputs:
#   ${dest_server_name}. Returns 0 if ok, 1 on error.
################################################################################

function migrate_get_dest_server_name() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"

  local dest_server_name
  dest_server_name="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "hostname")"

  if [[ -z "${dest_server_name}" ]]; then
    log_event "error" "Migrate: could not resolve destination server name" "true"
    return 1
  fi

  echo "${dest_server_name}"
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
# For --transport local, sets the MIGRATE_LOCAL_STAGING_PATH override (see
# storage_upload_backup() in libs/storage_controller.sh) so the backup is
# staged at a migrate-owned path instead of using BACKUPS.methods.local from
# .brolit_conf.json - this is deliberate: migrate must never depend on (or
# implicitly enable) the persistent local-backup config, since that would
# also make every regular/cron backup start writing local copies nobody
# asked for. For --transport dropbox, requires the real, already-configured
# Dropbox method (no override - this genuinely uses the shared account).
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${transport} ("local" or "dropbox")
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function migrate_capture_source() {

  local domain="${1}"
  local transport="${2:-local}"

  if [[ ${transport} == "dropbox" && ${BACKUP_DROPBOX_STATUS} != "enabled" ]]; then
    log_event "error" "Migrate: --transport dropbox requires Dropbox backup storage enabled on the source" "true"
    display --indent 6 --text "- Source Dropbox storage" --result "FAIL" --color RED
    return 1
  fi

  log_subsection "Migrate: Capture Source"

  if [[ ${transport} == "local" ]]; then
    declare -g MIGRATE_LOCAL_STAGING_PATH="${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}"
  fi

  # Cold copy: a bind-mounted database data directory is archived with its
  # database stopped (and started again right after), never while it runs.
  declare -g BROLIT_BACKUP_QUIESCE_DB=1
  brolit_job_control_mark_cancellable
  backup_docker_project "${domain}" "site"
  local capture_result=$?
  declare -g BROLIT_BACKUP_QUIESCE_DB=0
  backup_resume_project_databases || true

  MIGRATE_LOCAL_STAGING_PATH=""

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
# finds it exactly as if it had made the backup itself. Uses the fixed
# MIGRATE_LOCAL_STAGING_PATH_DEFAULT on both ends - independent of any
# BACKUPS.methods.local configuration.
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${domain}
#   ${6} = ${dest_server_name}
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

  local db_name
  db_name="$(project_get_configured_database "${PROJECTS_PATH}/${domain}" "$(project_get_type "${PROJECTS_PATH}/${domain}")" "$(project_get_install_type "${PROJECTS_PATH}/${domain}")")"

  MIGRATE_RUN_DB_NAME="${db_name}"

  local source_site_path="${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}/${SERVER_NAME}/projects-online/site/${domain}/"
  local dest_site_path="${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}/${dest_server_name}/projects-online/site/${domain}/"

  log_subsection "Migrate: Transfer Artifact"
  # Stage boundary for brolit-admin's live progress (no percentage).
  brolit_progress "transfer" "-" "${domain}"

  brolit_job_control_mark_cancellable
  _migrate_rsync_push "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "${source_site_path}" "${dest_site_path}"

  if [[ $? -ne 0 ]]; then
    log_event "error" "Migrate: transferring site files artifact failed" "true"
    display --indent 6 --text "- Transfer site files" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Transfer site files" --result "DONE" --color GREEN

  if [[ -n "${db_name}" && -d "${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}/${SERVER_NAME}/projects-online/database/${db_name}" ]]; then

    local source_db_path="${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}/${SERVER_NAME}/projects-online/database/${db_name}/"
    local dest_db_path="${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}/${dest_server_name}/projects-online/database/${db_name}/"

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

  brolit_job_control_mark_noncancellable || return 1

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local domain="${5}"
  local storage_method="${6:-local}"

  log_subsection "Migrate: Remote Restore"
  # Stage boundary for brolit-admin's live progress (no percentage).
  brolit_progress "restore" "-" "${domain}"

  # DNS records and the certificate are deferred: the domain keeps pointing at the
  # source until the destination has been verified (see migrate_switch_dns).
  local remote_cmd="cd '${MIGRATE_DEST_BROLIT_DIR}' && BROLIT_DOMAIN_CONFIG_STAGE=defer ./runner.sh -t restore -st from-storage -D '${domain}' --storage-method '${storage_method}'"

  if [[ ${storage_method} == "dropbox" ]]; then
    remote_cmd="${remote_cmd} --source-server '${SERVER_NAME}'"
  elif [[ ${storage_method} == "local" ]]; then
    remote_cmd="${remote_cmd} --local-staging-path '${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}'"
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
  local https_status
  local http_status

  # If dest_host is a hostname rather than an IP, resolve the destination's
  # own public IP over SSH instead of relying on local DNS resolution.
  if ! [[ ${dest_host} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    dest_ip="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "curl -s https://api.ipify.org")"
  fi

  log_subsection "Migrate: Verify Destination"
  # Stage boundary for brolit-admin's live progress (no percentage).
  brolit_progress "verify" "-" "${domain}"

  if [[ -z "${dest_ip}" ]]; then
    log_event "error" "Migrate: could not resolve destination IP for verification" "true"
    display --indent 6 --text "- Destination verification" --result "FAIL" --color RED
    return 1
  fi

  # Judge by the status code, never by `curl --fail`: --fail treats a 3xx as
  # success, so a stack that is down (HTTPS answers 502) used to pass through
  # the plain-HTTP redirect to HTTPS, and it rejects a 401/403 from a site that
  # is up but protected.
  https_status="$(_migrate_probe_status "https" "443" "${domain}" "${dest_ip}")"

  if [[ ${https_status} != "000" ]]; then
    if ((10#${https_status} < 500)); then
      display --indent 6 --text "- Destination verification (HTTPS ${https_status})" --result "DONE" --color GREEN
      return 0
    fi
    # TLS works and the site answers with a server error: it is down.
    log_event "error" "Migrate: destination answered HTTP ${https_status} for ${domain} at ${dest_ip}" "true"
    display --indent 6 --text "- Destination verification (HTTPS ${https_status})" --result "FAIL" --color RED
    return 1
  fi

  # No HTTPS answer at all (for example the certificate is not ready yet): plain
  # HTTP may stand in, but only when it serves the site itself. A redirect to the
  # HTTPS that just failed proves nothing.
  http_status="$(_migrate_probe_status "http" "80" "${domain}" "${dest_ip}")"

  if ((10#${http_status} >= 200 && 10#${http_status} < 300 || 10#${http_status} >= 400 && 10#${http_status} < 500)); then
    display --indent 6 --text "- Destination verification (HTTP only ${http_status}, SSL may not be ready yet)" --result "WARNING" --color YELLOW
    return 0
  fi

  # Neither door is conclusive from here (for example a guest behind a gateway has
  # no certificate before the DNS switch, and its plain HTTP only redirects). Ask
  # the destination about the stack itself; the front door is checked again after
  # the DNS switch, and the switch is undone if it fails.
  if _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
    "cd '${MIGRATE_DEST_BROLIT_DIR}' && ./runner.sh -t project -st verify-local -D '${domain}' >/dev/null 2>&1"; then
    display --indent 6 --text "- Destination verification (stack answers locally; front door is checked after the DNS switch)" --result "WARNING" --color YELLOW
    return 0
  fi

  log_event "error" "Migrate: destination did not serve ${domain} at ${dest_ip} (https=${https_status}, http=${http_status}) and its stack did not answer locally" "true"
  display --indent 6 --text "- Destination verification" --result "FAIL" --color RED
  return 1

}

################################################################################
# Put a domain's DNS record back to what it was before the switch
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${previous_content} (the A record's address before the switch)
#
# Outputs:
#   0 if restored, 1 otherwise.
################################################################################

function migrate_rollback_dns() {

  local domain="${1}"
  local previous_content="${2}"

  local root_domain

  if [[ ! ${previous_content} =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    log_event "error" "Migrate: no previous A record recorded for ${domain}; its DNS must be checked by hand" "true"
    display --indent 6 --text "- DNS rollback for ${domain}" --result "MANUAL" --color RED
    return 1
  fi

  root_domain="$(domain_get_root "${domain}")"

  if cloudflare_set_record "${root_domain}" "${domain}" "A" "false" "${previous_content}"; then
    log_event "warning" "Migrate: DNS of ${domain} restored to ${previous_content}" "true"
    display --indent 6 --text "- DNS rollback for ${domain} (${previous_content})" --result "DONE" --color YELLOW
    return 0
  fi

  log_event "error" "Migrate: could not restore the DNS of ${domain} to ${previous_content}" "true"
  display --indent 6 --text "- DNS rollback for ${domain}" --result "FAIL" --color RED
  return 1

}

################################################################################
# Point the domain at the destination, after the destination was verified
#
# Records the current A record first, runs the destination's finalize-domain
# (DNS records and certificate), then checks the front door again. If the DNS
# step fails, or the site no longer answers after the switch, the record is put
# back, so a failed migration never leaves the domain pointing at a broken site.
#
# Arguments:
#   ${1} = ${dest_user}
#   ${2} = ${dest_host}
#   ${3} = ${dest_port}
#   ${4} = ${dest_ssh_key}
#   ${5} = ${domain}
#
# Outputs:
#   0 if switched and answering, 1 otherwise (DNS rolled back when possible).
################################################################################

function migrate_switch_dns() {

  local dest_user="${1}"
  local dest_host="${2}"
  local dest_port="${3}"
  local dest_ssh_key="${4}"
  local domain="${5}"

  local root_domain
  local previous_content=""
  local dest_ip="${dest_host}"
  local https_status="000"
  local attempt

  log_subsection "Migrate: Switch DNS"
  # Stage boundary for brolit-admin's live progress (no percentage).
  brolit_progress "dns" "-" "${domain}"

  if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
    root_domain="$(domain_get_root "${domain}")"
    previous_content="$(cloudflare_get_record_details "${root_domain}" "${domain}" "content" 2>/dev/null)"
  else
    log_event "warning" "Migrate: Cloudflare is not configured on the source, so the previous DNS value cannot be recorded for a rollback" "true"
  fi

  # The DNS provider answers errors now and then (a record lookup that times out
  # reads as "not found", an "Unable to authenticate request" that passes on its
  # own). The step is idempotent (a record that is already right is skipped), so
  # it is tried a few times before the migration gives up and puts the DNS back.
  local finalize_ok=1
  local finalize_attempt
  for finalize_attempt in 1 2 3; do
    if _migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
      "cd '${MIGRATE_DEST_BROLIT_DIR}' && ./runner.sh -t project -st finalize-domain -D '${domain}' >/dev/null 2>&1"; then
      finalize_ok=0
      break
    fi
    log_event "warning" "Migrate: switching the DNS of ${domain} failed (attempt ${finalize_attempt} of 3)" "true"
    [[ ${finalize_attempt} -lt 3 ]] && sleep 20
  done

  if [[ ${finalize_ok} -ne 0 ]]; then
    log_event "error" "Migrate: switching the DNS of ${domain} to the destination failed" "true"
    display --indent 6 --text "- Switch DNS to the destination" --result "FAIL" --color RED
    migrate_rollback_dns "${domain}" "${previous_content}"
    return 1
  fi

  display --indent 6 --text "- Switch DNS to the destination" --result "DONE" --color GREEN

  # The certificate exists now (or the destination serves plain HTTP): check the
  # front door again, giving the new certificate and the route a moment.
  if ! [[ ${dest_host} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    dest_ip="$(_migrate_ssh "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "curl -s https://api.ipify.org")"
  fi

  for attempt in 1 2 3 4 5 6; do
    https_status="$(_migrate_probe_status "https" "443" "${domain}" "${dest_ip}")"
    if [[ ${https_status} != "000" ]] && ((10#${https_status} < 500)); then
      display --indent 6 --text "- Front door after the switch (HTTPS ${https_status})" --result "DONE" --color GREEN
      return 0
    fi
    [[ ${attempt} -lt 6 ]] && sleep 10
  done

  # No HTTPS: accept plain HTTP only when it serves the site itself.
  local http_status
  http_status="$(_migrate_probe_status "http" "80" "${domain}" "${dest_ip}")"
  if ((10#${http_status} >= 200 && 10#${http_status} < 300 || 10#${http_status} >= 400 && 10#${http_status} < 500)); then
    display --indent 6 --text "- Front door after the switch (HTTP only ${http_status}, certificate pending)" --result "WARNING" --color YELLOW
    return 0
  fi

  log_event "error" "Migrate: ${domain} does not answer at the destination after the DNS switch (https=${https_status}, http=${http_status}); restoring the DNS" "true"
  display --indent 6 --text "- Front door after the switch" --result "FAIL" --color RED
  migrate_rollback_dns "${domain}" "${previous_content}"
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
# Private: a name that is safe to use as a path component
#
# Arguments:
#   ${1} = ${name}
#
# Outputs:
#   0 if it is a plain name (letters, digits, dot, dash, underscore; no "..",
#   not starting with a dot), 1 otherwise.
################################################################################

function _migrate_staging_name_is_safe() {

  local name="${1:-}"

  [[ -n ${name} && ${name} =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && ${name} != *..* ]]

}

################################################################################
# Remove the captures a migration staged, on the source and on the destination
#
# The staging directory used to grow forever: each migration left its capture
# behind, on success and on cancel (15-17 GB on two servers after nine
# migrations, one capture alone 12 GB). Only this project's directories under
# the migrate staging root are removed, never the staging root itself, other
# projects' captures or anything outside it, and every path component is
# validated first. Best effort: a failure is logged, never fatal.
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${dest_user} (optional: without it only the source is cleaned)
#   ${3} = ${dest_host}
#   ${4} = ${dest_port}
#   ${5} = ${dest_ssh_key}
#   ${6} = ${dest_server_name}
#   ${7} = ${db_name} (optional)
#
# Outputs:
#   0 always when the arguments are valid, 1 when they are not.
################################################################################

function migrate_cleanup_staging() {

  local domain="${1:-}"
  local dest_user="${2:-}"
  local dest_host="${3:-}"
  local dest_port="${4:-22}"
  local dest_ssh_key="${5:-}"
  local dest_server_name="${6:-}"
  local db_name="${7:-}"

  local root="${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}"
  local path
  local remote_cmd
  local -a source_paths=()
  local -a dest_paths=()

  if [[ ${root} != /* || ${root} == "/" ]] || ! _migrate_staging_name_is_safe "${domain}"; then
    log_event "warning" "Migrate: not cleaning staging, unsafe staging root or domain" "false"
    return 1
  fi

  if _migrate_staging_name_is_safe "${SERVER_NAME:-}"; then
    source_paths+=("${root}/${SERVER_NAME}/projects-online/site/${domain}")
    if _migrate_staging_name_is_safe "${db_name}"; then
      source_paths+=("${root}/${SERVER_NAME}/projects-online/database/${db_name}")
    fi
  fi

  for path in "${source_paths[@]}"; do
    if [[ -d ${path} && ! -L ${path} ]]; then
      rm --recursive --force --one-file-system -- "${path}" 2>/dev/null \
        && log_event "info" "Migrate: removed staged capture ${path}" "false" \
        || log_event "warning" "Migrate: could not remove staged capture ${path}" "false"
    fi
  done

  if [[ -n ${dest_user} && -n ${dest_host} ]] && _migrate_staging_name_is_safe "${dest_server_name}"; then
    dest_paths+=("${root}/${dest_server_name}/projects-online/site/${domain}")
    if _migrate_staging_name_is_safe "${db_name}"; then
      dest_paths+=("${root}/${dest_server_name}/projects-online/database/${db_name}")
    fi
    remote_cmd="rm --recursive --force --one-file-system --"
    for path in "${dest_paths[@]}"; do
      remote_cmd="${remote_cmd} '${path}'"
    done
    # Bounded: this can run inside the grace period between TERM and KILL.
    timeout 10 bash -c "$(declare -f _migrate_ssh); _migrate_ssh \"\$@\"" _ \
      "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${remote_cmd}" >/dev/null 2>&1 \
      && log_event "info" "Migrate: removed the staged capture on the destination" "false" \
      || log_event "warning" "Migrate: could not remove the staged capture on the destination" "false"
  fi

  return 0

}

################################################################################
# Private: handler for TERM and INT during a migration
#
# Removes the staged captures when the phase allows it, then exits with the
# conventional status for the signal. A migration cancelled from Admin is TERMed
# during capture or transfer; it used to leave a partial capture behind.
#
# Arguments:
#   ${1} = ${exit_code} (143 for TERM, 130 for INT)
#
# Outputs:
#   None; exits the process.
################################################################################

function _migrate_on_signal() {

  local exit_code="${1:-143}"

  trap - TERM INT

  # A cancelled capture must not leave the site's database stopped.
  backup_resume_project_databases || true

  if [[ ${MIGRATE_STAGING_SIGNAL_SAFE} == "1" ]]; then
    migrate_cleanup_staging "${MIGRATE_RUN_DOMAIN}" "${MIGRATE_RUN_DEST_USER}" "${MIGRATE_RUN_DEST_HOST}" \
      "${MIGRATE_RUN_DEST_PORT}" "${MIGRATE_RUN_DEST_SSH_KEY}" "${MIGRATE_RUN_DEST_SERVER_NAME}" "${MIGRATE_RUN_DB_NAME}" || true
  fi

  exit "${exit_code}"

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

function _migrate_site_run() {

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
  local dest_server_name
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
  migrate_check_dest_defer_support "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" || return 1
  migrate_check_dest_dns_ssl_config "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${bootstrap_dest_config}" || return 1

  if [[ ${transport} == "local" ]]; then
    dest_server_name="$(migrate_get_dest_server_name "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}")"
    [[ $? -ne 0 ]] && return 1
    MIGRATE_RUN_DEST_SERVER_NAME="${dest_server_name}"
  fi

  dest_path="$(migrate_resolve_dest_path "${domain}" "${dest_path_override}")"
  migrate_check_dest_path_collision "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${dest_path}" "${force}" || return 1

  MIGRATE_STAGING_SIGNAL_SAFE="1"
  migrate_capture_source "${domain}" "${transport}" || return 1

  if [[ ${transport} == "local" ]]; then
    migrate_transfer_artifact "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" \
      "${domain}" "${dest_server_name}" || return 1
  else
    log_event "info" "Migrate: --transport dropbox, skipping direct rsync transfer (backup_docker_project already uploaded to the shared Dropbox account)" "false"
  fi

  # From here the destination reads the staged capture: a signal must not remove it.
  MIGRATE_STAGING_SIGNAL_SAFE="0"
  migrate_trigger_remote_restore "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${domain}" "${transport}"
  restore_result=$?

  if [[ ${restore_result} -eq 0 ]]; then
    migrate_verify_destination "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${domain}"
    verification_result=$?
  fi

  # The domain is pointed at the destination only now that it is verified, and only
  # by this shell when it owns the DNS. With --dns-mode external the caller (brolit-admin)
  # switches it with its own Cloudflare connection and asks the destination for the
  # certificate afterwards: this run ends here, DNS untouched.
  if [[ ${restore_result} -eq 0 && ${verification_result} -eq 0 ]]; then
    if [[ "${MIGRATE_DNS_MODE:-shell}" == "external" ]]; then
      log_subsection "Migrate: DNS left to the caller"
      log_event "info" "Migrate: ${domain} is verified at the destination; the DNS is switched by the caller (--dns-mode external)" "true"
      display --indent 6 --text "- Domain DNS (switched by the caller)" --result "DEFERRED" --color YELLOW
    else
      migrate_switch_dns "${dest_user}" "${dest_host}" "${dest_port}" "${dest_ssh_key}" "${domain}"
      verification_result=$?
    fi
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

################################################################################
# Migrate a Dockerized project to another server, then remove its staged captures
#
# Wraps _migrate_site_run (same arguments) so that the captures are removed on
# every way out: success, failure and, during capture or transfer, a TERM or INT
# such as the one Admin sends to cancel a migration. See migrate_cleanup_staging.
#
# Arguments:
#   Same as _migrate_site_run.
#
# Outputs:
#   The exit status of _migrate_site_run.
################################################################################

function migrate_site() {

  local run_result

  MIGRATE_RUN_DOMAIN="${1}"
  MIGRATE_RUN_DEST_HOST="${2}"
  MIGRATE_RUN_DEST_USER="${3}"
  MIGRATE_RUN_DEST_PORT="${4:-22}"
  MIGRATE_RUN_DEST_SSH_KEY="${5}"
  MIGRATE_RUN_DEST_SERVER_NAME=""
  MIGRATE_RUN_DB_NAME=""
  MIGRATE_STAGING_SIGNAL_SAFE="0"

  trap '_migrate_on_signal 143' TERM
  trap '_migrate_on_signal 130' INT

  _migrate_site_run "$@"
  run_result=$?

  trap - TERM INT

  migrate_cleanup_staging "${MIGRATE_RUN_DOMAIN}" "${MIGRATE_RUN_DEST_USER}" "${MIGRATE_RUN_DEST_HOST}" \
    "${MIGRATE_RUN_DEST_PORT}" "${MIGRATE_RUN_DEST_SSH_KEY}" "${MIGRATE_RUN_DEST_SERVER_NAME}" "${MIGRATE_RUN_DB_NAME}" || true

  MIGRATE_STAGING_SIGNAL_SAFE="0"

  return "${run_result}"

}

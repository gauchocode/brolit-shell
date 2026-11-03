#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agent - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Certbot Helper: Certbot functions.
#
# Ref: https://certbot.eff.org/docs/using.html#certbot-commands
#
################################################################################

################################################################################
# Get certbot method based on environment
#
# Arguments:
#  none
#
# Outputs:
#  Prints certbot method: "webroot" for OpenResty/Proxmox, "nginx" otherwise.
################################################################################

function certbot_get_method() {

  if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed 2>/dev/null; then
    echo "webroot"
  else
    echo "nginx"
  fi

}

################################################################################
# Get certbot webroot path
#
# Arguments:
#  none
#
# Outputs:
#  Prints webroot path for ACME challenges.
################################################################################

function certbot_get_webroot_path() {

  # Deliberately outside PROJECTS.path (/var/www): everything under /var/www
  # is treated as a project/domain directory by the rest of brolit (site
  # listing, backups, project delete, ...), and this is neither.
  echo "/etc/brolit/certbot-webroot"

}

################################################################################
# Install certbot webroot directory and OpenResty location block
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_setup_webroot() {

  local webroot_path
  webroot_path="$(certbot_get_webroot_path)"

  # Create webroot directory (0755 so the webserver user can traverse/read it)
  mkdir -p "${webroot_path}/.well-known/acme-challenge"
  chmod -R 755 "${webroot_path}"

  log_event "info" "Certbot webroot directory created at ${webroot_path}" "false"

  return 0

}

################################################################################
# Reload OpenResty after certbot renewal
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

################################################################################
# Execute certbot command on local machine or OpenResty VM
#
# Arguments:
#  $@ = certbot command and arguments
#
# Outputs:
#  Exit code of certbot command.
################################################################################

function _certbot_exec() {

  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then

    # Run certbot on OpenResty VM via SSH
    local remote_cmd
    remote_cmd="$(printf '%q ' "$@")"
    openresty_vm_exec "${remote_cmd}"

    return $?

  else

    # Run certbot locally
    "$@"

    return $?

  fi

}

################################################################################
# Get certbot command line for a given challenge type
#
# Arguments:
#  ${1} = ${challenge_type} (nginx|webroot|dns-cloudflare)
#  ${2} = ${email}
#  ${3} = ${domains}
#  ${4} = ${extra_flags} (optional)
#
# Outputs:
#  Prints the certbot command as a string.
################################################################################

function certbot_get_command() {

  local challenge_type="${1}"
  local email="${2}"
  local domains="${3}"
  local extra_flags="${4:-}"

  local cmd

  case "${challenge_type}" in

    "dns-cloudflare")
      local cloudflare_conf="/root/.cloudflare.conf"
      cmd="certbot certonly --dns-cloudflare --dns-cloudflare-credentials ${cloudflare_conf} --non-interactive --agree-tos -m ${email} -d ${domains} --preferred-challenges dns-01 ${extra_flags}"
      ;;

    "webroot")
      local webroot_path
      webroot_path="$(certbot_get_webroot_path)"
      cmd="certbot certonly --webroot -w ${webroot_path} --non-interactive --agree-tos -m ${email} -d ${domains} ${extra_flags}"
      ;;

    "nginx")
      cmd="certbot --nginx --non-interactive --agree-tos --redirect -m ${email} -d ${domains} ${extra_flags}"
      ;;

  esac

  echo "${cmd}"

}

################################################################################
# Check if a domain uses Cloudflare DNS
#
# Arguments:
#  ${1} = ${domain}
#
# Outputs:
#  0 if domain is on Cloudflare, 1 otherwise.
################################################################################

function certbot_domain_is_cloudflare() {

  local domain="${1}"

  local root_domain
  root_domain="$(domain_get_root "${domain}" 2>/dev/null)"

  if [[ "${SUPPORT_CLOUDFLARE_STATUS}" == "enabled" ]] && [[ -n "${SUPPORT_CLOUDFLARE_EMAIL}" ]] && [[ -n "${SUPPORT_CLOUDFLARE_API_KEY}" ]]; then

    if cloudflare_domain_exists "${root_domain}" 2>/dev/null; then
      return 0
    fi

  fi

  return 1

}

################################################################################
# Get certbot challenge type for a domain
#
# Arguments:
#  ${1} = ${domain}
#
# Outputs:
#  Prints challenge type: "dns-cloudflare", "webroot", or "nginx".
################################################################################

function certbot_get_challenge_type() {

  local domain="${1}"

  # OpenResty/Proxmox mode
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed 2>/dev/null; then

    # Check if domain is on Cloudflare → DNS challenge
    if certbot_domain_is_cloudflare "${domain}"; then
      echo "dns-cloudflare"
    else
      echo "webroot"
    fi

  else
    echo "nginx"
  fi

}

################################################################################
# Reload OpenResty after certbot renewal
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_reload_openresty() {

  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then

    openresty_vm_exec "/usr/local/openresty/bin/openresty -s reload"

    return $?

  elif openresty_is_installed 2>/dev/null; then

    /usr/local/openresty/bin/openresty -s reload

    return $?

  fi

  return 0

}

################################################################################
# Setup Cloudflare credentials on OpenResty VM
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_setup_cloudflare_vm() {

  if [[ "${PROXMOX_MODE}" != "enabled" ]] || [[ -z "${OPENRESTY_VM_IP}" ]]; then
    return 0
  fi

  if [[ "${SUPPORT_CLOUDFLARE_STATUS}" != "enabled" ]] || [[ -z "${SUPPORT_CLOUDFLARE_EMAIL}" ]]; then
    return 0
  fi

  local cloudflare_conf="/root/.cloudflare.conf"
  local tmp_conf="/tmp/cloudflare_conf_$$.conf"
  cat > "${tmp_conf}" << EOF
dns_cloudflare_email=${SUPPORT_CLOUDFLARE_EMAIL}
dns_cloudflare_api_key=${SUPPORT_CLOUDFLARE_API_KEY}
EOF

  openresty_vm_scp "${tmp_conf}" "${cloudflare_conf}"
  local result=$?
  rm -f "${tmp_conf}"

  if [[ ${result} -eq 0 ]]; then
    openresty_vm_exec "chmod 600 ${cloudflare_conf}"
    openresty_vm_exec "apt-get install -y -qq python3-certbot-dns-cloudflare 2>/dev/null" 2>/dev/null
    log_event "info" "Cloudflare credentials copied to OpenResty VM" "false"
    return 0
  else
    log_event "error" "Failed to copy Cloudflare credentials to OpenResty VM" "false"
    return 1
  fi

}

################################################################################
# Setup certbot webroot directory on OpenResty VM
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_setup_webroot_vm() {

  if [[ "${PROXMOX_MODE}" != "enabled" ]] || [[ -z "${OPENRESTY_VM_IP}" ]]; then
    return 0
  fi

  local webroot_path
  webroot_path="$(certbot_get_webroot_path)"

  openresty_vm_exec "mkdir -p ${webroot_path}/.well-known/acme-challenge && chmod -R 755 ${webroot_path}"
  log_event "info" "Certbot webroot directory created on OpenResty VM at ${webroot_path}" "false"

  return 0

}

################################################################################
# Get certbot account email
#
# Arguments:
#  none
#
# Outputs:
#  ${email} if ok, empty string on error.
################################################################################

function certbot_get_account_email() {

  local account_email
  local accounts_dir="/etc/letsencrypt/accounts"

  # Check if certbot is installed and has accounts
  if [[ ! -d "${accounts_dir}" ]]; then
    log_event "debug" "Certbot accounts directory not found" "false"
    echo ""
    return 1
  fi

  # Try to get email from account registration
  # The accounts directory structure is: /etc/letsencrypt/accounts/[server]/directory/[account_id]/
  account_email="$(find "${accounts_dir}" -name "regr.json" -type f -print0 -quit | xargs -0 cat 2>/dev/null | grep -oP '"mailto:\K[^"]+' | head -1)"

  if [[ -n "${account_email}" ]]; then
    log_event "debug" "Found certbot account email: ${account_email}" "false"
    echo "${account_email}"
    return 0
  else
    log_event "debug" "Could not find certbot account email" "false"
    echo ""
    return 1
  fi

}

################################################################################
# Update certbot account email
#
# Arguments:
#  ${1} = ${new_email}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_update_account_email() {

  local new_email="${1}"
  local certbot_result

  log_event "info" "Updating certbot account email to: ${new_email}" "false"
  display --indent 6 --text "- Updating certbot account email" --result "WORKING" --color YELLOW

  # Update certbot account email
  certbot update_account --email "${new_email}" --no-eff-email --non-interactive --quiet

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then

    clear_previous_lines "1"
    log_event "success" "Certbot account email updated to: ${new_email}" "false"
    display --indent 6 --text "- Updating certbot account email" --result "DONE" --color GREEN

    return 0

  else

    clear_previous_lines "1"
    log_event "error" "Failed to update certbot account email" "false"
    display --indent 6 --text "- Updating certbot account email" --result "FAIL" --color RED

    return 1

  fi

}

################################################################################
# Check and update certbot email if needed
#
# Arguments:
#  ${1} = ${configured_email}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_check_and_update_email() {

  local configured_email="${1}"
  local current_email

  # Get current certbot account email
  current_email="$(certbot_get_account_email)"

  # If we couldn't get current email, certbot is probably not configured yet
  if [[ -z "${current_email}" ]]; then
    log_event "debug" "No certbot account found, skipping email verification" "false"
    return 0
  fi

  # Check if configured email is empty
  if [[ -z "${configured_email}" ]]; then
    log_event "warning" "No email configured in .brolit_conf.json for certbot" "false"
    return 0
  fi

  # Compare emails
  if [[ "${current_email}" != "${configured_email}" ]]; then

    log_event "info" "Certbot email mismatch detected. Current: ${current_email}, Configured: ${configured_email}" "false"

    # Update certbot account email
    certbot_update_account_email "${configured_email}"

    return $?

  else

    log_event "debug" "Certbot account email is already up to date: ${current_email}" "false"
    return 0

  fi

}

################################################################################
# Install certificate with certbot
#
# Arguments:
#  ${1} = ${email}
#  ${2} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_install() {

  local email="${1}"
  local domains="${2}"

  local certbot_result
  local certbot_method
  certbot_method="$(certbot_get_method)"

  # Detect challenge type (use first domain)
  local first_domain
  first_domain="$(echo "${domains}" | awk '{print $1}')"
  local challenge_type
  challenge_type="$(certbot_get_challenge_type "${first_domain}")"

  # Setup environment for OpenResty VM if needed
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    certbot_setup_webroot_vm
    if [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_setup_cloudflare_vm
    fi
  else
    if [[ "${certbot_method}" == "webroot" ]]; then
      certbot_setup_webroot
    fi
  fi

  # Get certbot command
  local certbot_cmd
  certbot_cmd="$(certbot_get_command "${challenge_type}" "${email}" "${domains}" --quiet)"

  # Log
  log_event "debug" "Running: ${certbot_cmd}" "false"

  # Run certbot
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    openresty_vm_exec "${certbot_cmd}"
  else
    ${certbot_cmd}
  fi

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then

    # Log
    clear_previous_lines "1"
    log_event "info" "Certificate installation for ${domains} ok" "false"
    display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

    # Reload OpenResty if needed
    if [[ "${certbot_method}" == "webroot" ]] || [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_reload_openresty
    fi

    return 0

  else

    # Log
    clear_previous_lines "1"
    log_event "warning" "Certificate installation failed, trying force-install ..." "false"
    display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

    # Deleting old config
    certbot_certificate_delete_old_config "${domains}"

    # Retry with --expand too: a common reason the first attempt fails is
    # an existing cert that already covers a subset of ${domains} (e.g.
    # adding "www.example.com" to a cert that only had "example.com"),
    # which certbot refuses to touch without this flag.
    certbot_cmd="$(certbot_get_command "${challenge_type}" "${email}" "${domains}" "--quiet --expand")"

    # Running certbot again
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
      openresty_vm_exec "${certbot_cmd}"
    else
      ${certbot_cmd}
    fi

    certbot_result=$?
    if [[ ${certbot_result} -eq 0 ]]; then

      log_event "info" "Certificate installation for ${domains} ok" "false"
      display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

      # Reload OpenResty if needed
      if [[ "${certbot_method}" == "webroot" ]] || [[ "${challenge_type}" == "dns-cloudflare" ]]; then
        certbot_reload_openresty
      fi

      return 0

    else

      # Log
      clear_previous_lines "3"
      log_event "error" "Certificate installation for ${domains} failed!" "false"
      display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED
      display --indent 8 --text "Please check and then run:" --tcolor RED
      display --indent 8 --text "${certbot_cmd}" --tcolor RED

      return 1

    fi

  fi

}

################################################################################
# Delete old certificate config
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_delete_old_config() {

  local domains="${1}"

  for domain in ${domains}; do

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
      # Delete on OpenResty VM
      openresty_vm_exec "rm --recursive --force /etc/letsencrypt/archive/${domain}"
      openresty_vm_exec "rm --recursive --force /etc/letsencrypt/live/${domain}"
      openresty_vm_exec "rm --force /etc/letsencrypt/renewal/${domain}.conf"
    else
      # Delete locally
      if [[ -d "/etc/letsencrypt/archive/${domain}" ]]; then
        rm --recursive --force "/etc/letsencrypt/archive/${domain}"
        display --indent 6 --text "- Deleting /etc/letsencrypt/archive/${domain}" --result "DONE" --color GREEN
      fi
      if [[ -d "/etc/letsencrypt/live/${domain}" ]]; then
        rm --recursive --force "/etc/letsencrypt/live/${domain}"
        display --indent 6 --text "- Deleting /etc/letsencrypt/live/${domain}" --result "DONE" --color GREEN
      fi
      if [[ -f "/etc/letsencrypt/renewal/${domain}.conf" ]]; then
        rm --force "/etc/letsencrypt/renewal/${domain}.conf"
        display --indent 6 --text "- Deleting /etc/letsencrypt/renewal/${domain}.conf" --result "DONE" --color GREEN
      fi
    fi

  done

}

################################################################################
# Expand certificate
#
# Arguments:
#  ${1} = ${email}
#  ${2} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_expand() {

  local email="${1}"
  local domains="${2}"

  local certbot_result
  local certbot_method
  certbot_method="$(certbot_get_method)"

  # Detect challenge type (use first domain)
  local first_domain
  first_domain="$(echo "${domains}" | awk '{print $1}')"
  local challenge_type
  challenge_type="$(certbot_get_challenge_type "${first_domain}")"

  # Setup environment for OpenResty VM if needed
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    certbot_setup_webroot_vm
    if [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_setup_cloudflare_vm
    fi
  else
    if [[ "${certbot_method}" == "webroot" ]]; then
      certbot_setup_webroot
    fi
  fi

  # Get certbot command
  local certbot_cmd
  certbot_cmd="$(certbot_get_command "${challenge_type}" "${email}" "${domains}" "--expand --quiet")"

  # Log
  log_event "debug" "Running: ${certbot_cmd}" "false"

  # Run certbot
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    openresty_vm_exec "${certbot_cmd}"
  else
    ${certbot_cmd}
  fi

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then

    # Log
    log_event "info" "Certificate installation for ${domains} ok" "false"
    display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

    # Reload OpenResty if needed
    if [[ "${certbot_method}" == "webroot" ]] || [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_reload_openresty
    fi

    return 0

  else

    # Log
    clear_previous_lines "3"
    log_event "error" "Certificate installation for ${domains} failed!" "false"
    display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

    return 1

  fi

}

################################################################################
# Expand certificate
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_renew() {

  local domains="${1}"

  local certbot_result
  local certbot_method
  certbot_method="$(certbot_get_method)"

  # Detect challenge type (use first domain)
  local first_domain
  first_domain="$(echo "${domains}" | awk '{print $1}')"
  local challenge_type
  challenge_type="$(certbot_get_challenge_type "${first_domain}")"

  # Setup environment for OpenResty VM if needed
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    certbot_setup_webroot_vm
    if [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_setup_cloudflare_vm
    fi
  fi

  log_event "debug" "Running: certbot renew -d ${domains}" "false"

  # Certbot command
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    openresty_vm_exec "certbot renew -d ${domains}"
  else
    certbot renew -d "${domains}"
  fi

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then

    log_event "info" "Certificate renew for ${domains} ok" "false"
    display --indent 6 --text "- Certificate renew" --result "DONE" --color GREEN

    # Reload OpenResty if needed
    if [[ "${certbot_method}" == "webroot" ]] || [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_reload_openresty
    fi

    return 0

  else

    # Log
    clear_previous_lines "3"
    log_event "error" "Certificate renew for ${domains} failed!" "false"
    display --indent 6 --text "- Renew certificate on domains" --result "FAIL" --color RED
    display --indent 8 --text "Please check and then run:" --tcolor RED
    display --indent 8 --text "certbot --nginx -d ${domains}" --tcolor RED

    return 1

  fi

}

################################################################################
# Test certificate renew
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_renew_test() {

  local domains="${1}"

  local certbot_result

  # Detect challenge type (use first domain)
  local first_domain
  first_domain="$(echo "${domains}" | awk '{print $1}')"
  local challenge_type
  challenge_type="$(certbot_get_challenge_type "${first_domain}")"

  # Setup environment for OpenResty VM if needed
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    certbot_setup_webroot_vm
    if [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_setup_cloudflare_vm
    fi
  fi

  log_event "debug" "Running: certbot renew --dry-run -d ${domains}" "false"

  # Certbot command
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    openresty_vm_exec "certbot renew --dry-run -d ${domains}"
  else
    certbot renew --dry-run -d "${domains}"
  fi

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then

    log_event "info" "Certificate renew for ${domains} ok" "false"
    display --indent 6 --text "- Certificate renew" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_previous_lines "3"
    log_event "error" "Certificate renew for ${domains} failed!" "false"
    display --indent 6 --text "- Renew certificate on domains" --result "FAIL" --color RED
    display --indent 8 --text "Please check and then run:" --tcolor RED
    display --indent 8 --text "certbot --nginx -d ${domains}" --tcolor RED

    return 1

  fi

}

################################################################################
# Certificate force renew
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_force_renew() {

  local domains="${1}"
  local email="${2:-}"

  local certbot_result
  local certbot_method
  certbot_method="$(certbot_get_method)"

  # Detect challenge type (use first domain)
  local first_domain
  first_domain="$(echo "${domains}" | awk '{print $1}')"
  local challenge_type
  challenge_type="$(certbot_get_challenge_type "${first_domain}")"

  # Fallback email
  if [[ -z "${email}" ]]; then
    email="$(certbot_get_account_email)"
  fi
  if [[ -z "${email}" ]]; then
    email="${SUPPORT_CLOUDFLARE_EMAIL:-admin@example.com}"
  fi

  # Setup environment for OpenResty VM if needed
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    certbot_setup_webroot_vm
    if [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_setup_cloudflare_vm
    fi
  else
    if [[ "${certbot_method}" == "webroot" ]]; then
      certbot_setup_webroot
    fi
  fi

  # Get certbot command
  local certbot_cmd
  certbot_cmd="$(certbot_get_command "${challenge_type}" "${email}" "${domains}" "--force-renewal")"

  # Log
  log_event "debug" "Running: ${certbot_cmd}" "false"

  # Run certbot
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    openresty_vm_exec "${certbot_cmd}"
  else
    ${certbot_cmd}
  fi

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then

    log_event "info" "Certificate renew for ${domains} ok" "false"
    display --indent 6 --text "- Certificate renew" --result "DONE" --color GREEN

    # Reload OpenResty if needed
    if [[ "${certbot_method}" == "webroot" ]] || [[ "${challenge_type}" == "dns-cloudflare" ]]; then
      certbot_reload_openresty
    fi

    return 0

  else

    # Log
    clear_previous_lines "3"
    log_event "error" "Certificate renew for ${domains} failed!" "false"
    display --indent 6 --text "- Renew certificate on domains" --result "FAIL" --color RED
    display --indent 8 --text "Please check and then run:" --tcolor RED
    display --indent 8 --text "${certbot_cmd}" --tcolor RED

    return 1

  fi

}

################################################################################
# Certbot installer menu
#
# Arguments:
#  ${1} = ${email}
#  ${2} = ${domains}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function certbot_helper_installer_menu() {

  local email="${1}"
  local domains="${2}"

  local cb_installer_options
  local chosen_cb_installer_option
  local cb_warning_text
  local certbot_result
  local error
  local root_domain

  if [[ ${PACKAGES_CERTBOT_STATUS} != "enabled" ]]; then

    # Log
    log_event "warning" "Certbot is not enabled or installed" "false"
    display --indent 6 --text "- Certificate installation" --result "FAIL" --color RED
    display --indent 8 --text "Certbot is not enabled or installed" --tcolor RED

    return 1

  fi

  cb_installer_options=(
    "01)" "INSTALL WITH NGINX"
    "02)" "INSTALL WITH CLOUDFLARE"
  )

  chosen_cb_installer_option="$(whiptail --title "CERTBOT INSTALLER OPTIONS" --menu "Please choose an installation method:" 20 78 10 "${cb_installer_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_cb_installer_option} == *"01"* ]]; then

      # INSTALL_WITH_NGINX
      log_subsection "Certificate Installation with Certbot Nginx"

      certbot_certificate_install "${email}" "${domains}"

    fi

    if [[ ${chosen_cb_installer_option} == *"02"* ]]; then

      # INSTALL_WITH_CLOUDFLARE
      log_subsection "Certificate Installation with Certbot Cloudflare"

      # Step 1: Install certificate with nginx (creates cert + configures nginx)
      log_event "info" "Step 1: Installing certificate with nginx to configure nginx files" "false"
      display --indent 6 --text "- Installing certificate with nginx" --tcolor CYAN

      certbot_certificate_install "${email}" "${domains}"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        # Step 2: Regenerate certificate using Cloudflare (keeps nginx config from step 1)
        log_event "info" "Step 2: Regenerating certificate with Cloudflare DNS" "false"
        display --indent 6 --text "- Regenerating certificate with Cloudflare" --tcolor CYAN

        certbot_certonly_cloudflare "${email}" "${domains}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          # Loop through a comma-separated shell variable
          # Not messing with IFS, not calling external command
          # Ref: https://stackoverflow.com/questions/27702452/loop-through-a-comma-separated-shell-variable
          for domain in ${domains//,/ }; do

            root_domain=$(domain_get_root "${domain}")

            # Check if this is a nested subdomain (2+ levels deep)
            # Cloudflare Free plan *.domain only covers single-level subdomains
            local domain_prefix="${domain%."${root_domain}"}"
            local dot_count="${domain_prefix//[^.]}"
            local prefix_dots="${#dot_count}"

            if [[ ${prefix_dots} -ge 2 ]]; then
              log_event "info" "Skipping proxy for nested subdomain: ${domain} (${prefix_dots} levels deep)" "false"
              display --indent 6 --text "- Skipping proxy for nested subdomain: ${domain}" --tcolor CYAN
            else
              # Enable cf proxy on record
              if [[ "${root_domain}" != "${domain}" ]]; then
                cloudflare_update_record "${root_domain}" "${domain}" "CNAME" "true" "${root_domain}"
              else
                cloudflare_update_record "${root_domain}" "${domain}" "A" "true" "${SERVER_IP}"
              fi
              [[ $? -eq 1 ]] && error=true
            fi

          done

          # Changing SSL Mode for Cloudflare record
          [[ ${error} != true ]] && cloudflare_set_ssl_mode "${domain}" "full"

        else

          cb_warning_text+="\n Now you need to follow the next steps: \n"
          cb_warning_text+="1- Login to your Cloudflare account and select the domain we want to work. \n"
          cb_warning_text+="2- Go to de 'DNS' option panel and Turn ON the proxy Cloudflare setting over the domain/s \n"
          cb_warning_text+="3- Go to 'SSL/TLS' option panel and change the SSL setting from 'Flexible' to 'Full'. \n"

          whiptail_message "CERTBOT MANAGER" "${cb_warning_text}"

        fi

      else

        log_event "error" "Failed to install certificate with nginx, skipping Cloudflare regeneration" "false"
        display --indent 6 --text "- Certificate installation with nginx" --result "FAIL" --color RED

      fi

    fi

    prompt_return_or_finish

  fi

}

################################################################################
# Certbot install certificate auto (detects if Cloudflare is enabled)
#
# Arguments:
#  ${1} = ${email}
#  ${2} = ${domains}
#  ${3} = ${non_interactive} - (true/false) Optional parameter for non-interactive mode
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_install_auto() {

  local email="${1}"
  local domains="${2}"
  local non_interactive="${3:-false}"  # Optional parameter for non-interactive mode

  log_event "debug" "Cloudflare status: ${SUPPORT_CLOUDFLARE_STATUS}" "false"

  if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
    
    if [[ "${non_interactive}" == "true" ]]; then

      # Non-interactive mode: use Cloudflare method directly without menu
      log_event "info" "Non-interactive mode: using Cloudflare method automatically" "false"
      log_subsection "Certificate Installation with Certbot Cloudflare"

      # Guard: force proxy OFF before the HTTP-01 challenge (step 1), in case
      # the record already exists with proxy ON from a previous setup -
      # Cloudflare's proxy would otherwise intercept the challenge request
      # before it reaches this server. Re-enabled at the end on success.
      for domain in ${domains//,/ }; do
        root_domain=$(domain_get_root "${domain}")
        if [[ "${root_domain}" != "${domain}" ]]; then
          cloudflare_update_record "${root_domain}" "${domain}" "CNAME" "false" "${root_domain}" 2>/dev/null
        else
          cloudflare_update_record "${root_domain}" "${domain}" "A" "false" "${SERVER_IP}" 2>/dev/null
        fi
      done

      # Step 1: Install certificate with nginx
      display --indent 6 --text "- Installing certificate with nginx" --tcolor CYAN
      log_event "info" "Step 1: Installing certificate with nginx to configure nginx files" "false"

      certbot_certificate_install "${email}" "${domains}"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then
        
        # Step 2: Regenerate certificate using Cloudflare
        #clear_previous_lines "1"
        display --indent 6 --text "- Regenerating certificate with Cloudflare" --tcolor CYAN
        log_event "info" "Step 2: Regenerating certificate with Cloudflare DNS" "false"

        certbot_certonly_cloudflare "${email}" "${domains}"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then

          # Enable Cloudflare proxy on records (skip nested subdomains)
          for domain in ${domains//,/ }; do
            root_domain=$(domain_get_root "${domain}")

            # Check if this is a nested subdomain (2+ levels deep)
            local domain_prefix="${domain%."${root_domain}"}"
            local dot_count="${domain_prefix//[^.]}"
            local prefix_dots="${#dot_count}"

            if [[ ${prefix_dots} -ge 2 ]]; then
              log_event "info" "Skipping proxy for nested subdomain: ${domain} (${prefix_dots} levels deep)" "false"
              display --indent 6 --text "- Skipping proxy for nested subdomain: ${domain}" --tcolor CYAN
            else
              if [[ "${root_domain}" != "${domain}" ]]; then
                cloudflare_update_record "${root_domain}" "${domain}" "CNAME" "true" "${root_domain}"
              else
                cloudflare_update_record "${root_domain}" "${domain}" "A" "true" "${SERVER_IP}"
              fi
            fi
          done

          # Set SSL mode to full
          cloudflare_set_ssl_mode "${domain}" "full"

        fi

      fi

    else

      # Interactive mode: ask user which method to use
      log_event "info" "Cloudflare is enabled, asking user for installation method" "false"
      certbot_helper_installer_menu "${email}" "${domains}"
    fi

  else

    # Cloudflare is disabled, use nginx directly
    log_event "info" "Cloudflare is disabled, using nginx method" "false"
    certbot_certificate_install "${email}" "${domains}"

  fi

}

################################################################################
# Certbot install certificate with cloudflare
#
# Arguments:
#  ${1} = ${email}
#  ${2} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certonly_cloudflare() {

  # IMPORTANT: maybe we could create a certbot_cloudflare_certificate that runs first the nginx certbot
  # and then the certonly with cloudflare credentials

  # Ref: https://mangolassi.it/topic/18355/setup-letsencrypt-certbot-with-cloudflare-dns-authentication-ubuntu/2

  local email="${1}"
  local domains="${2}"

  local certbot_cmd
  local certbot_result
  local cloudflare_conf="/root/.cloudflare.conf"

  certbot_cmd="certbot certonly --dns-cloudflare --dns-cloudflare-credentials ${cloudflare_conf} --non-interactive --agree-tos -m ${email} -d ${domains} --preferred-challenges dns-01"

  log_event "debug" "Running: ${certbot_cmd}" "false"

  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    # Ensure Cloudflare credentials are present on the OpenResty VM
    certbot_setup_cloudflare_vm

    openresty_vm_exec "${certbot_cmd}"
    certbot_result=$?
  else
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials "${cloudflare_conf}" --non-interactive --agree-tos -m "${email}" -d "${domains}" --preferred-challenges dns-01
    certbot_result=$?
  fi

  if [[ ${certbot_result} -eq 0 ]]; then

    # Log
    clear_previous_lines "1"
    log_event "info" "Certificate installation for ${domains} ok" "false"
    display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_previous_lines "3"
    log_event "warning" "Certificate installation failed, trying force-install ..." "false"
    display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

    # Deleting old config
    certbot_certificate_delete_old_config "${domains}"

    # Running certbot again
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
      openresty_vm_exec "${certbot_cmd}"
    else
      certbot certonly --dns-cloudflare --dns-cloudflare-credentials "${cloudflare_conf}" -m "${email}" -d "${domains}" --preferred-challenges dns-01
    fi

    certbot_result=$?
    if [[ ${certbot_result} -eq 0 ]]; then

      # Log
      clear_previous_lines "1"
      log_event "info" "Certificate installation for ${domains} ok" "false"
      display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

      return 0

    else

      # Log
      clear_previous_lines "3"
      log_event "error" "Certificate installation for ${domains} failed!" "false"
      display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED
      display --indent 8 --text "Please check and then run:" --tcolor RED
      display --indent 8 --text "${certbot_cmd}" --tcolor RED

      return 1

    fi

  fi

}

################################################################################
# Run certbot certificates command on the right target
#
# Arguments:
#  ${@} = arguments to pass to certbot certificates
#
# Outputs:
#  certbot certificates output.
################################################################################

function certbot_certificates_output() {

  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    openresty_vm_exec "certbot certificates ${*}"
  else
    certbot certificates "${@}"
  fi

}

################################################################################
# Show certificates info
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#   certificates info.
################################################################################

function certbot_show_certificates_info() {

  log_event "debug" "Running: certbot certificates" "false"

  certbot_certificates_output

}

################################################################################
# Show certificates expiration date
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#   list with certificates expiration dates.
################################################################################

function certbot_show_domain_certificates_expiration_date() {

  local domains="${1}"

  log_event "debug" "Running: certbot certificates --cert-name ${domains}" "false"

  certbot_certificates_output --cert-name "${domains}" | grep 'Expiry' | cut -d ':' -f2 | cut -d ' ' -f2

}

################################################################################
# Resolve a domain's A records (space separated, empty when it does not exist).
# Kept separate so tests can override it without touching DNS.
#
# Arguments:
#   ${1} = domain
# Outputs:
#   IPv4 addresses or empty string.
################################################################################
function _certbot_domain_ipv4() {

    getent ahostsv4 "${1}" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' '

}

################################################################################
# Check whether an IPv4 address belongs to Cloudflare's published ranges.
#
# Arguments:
#   ${1} = IPv4 address
# Outputs:
#   "yes" or "no".
################################################################################
function _certbot_ip_is_cloudflare() {

    awk -v ip="${1}" 'BEGIN {
        n = split("173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22", ranges, " ")
        split(ip, o, "."); addr = (((o[1] * 256) + o[2]) * 256 + o[3]) * 256 + o[4]
        for (i = 1; i <= n; i++) {
            split(ranges[i], c, "/"); split(c[1], b, "."); bits = c[2]
            base = (((b[1] * 256) + b[2]) * 256 + b[3]) * 256 + b[4]
            size = 2 ^ (32 - bits)
            if (addr >= base && addr < base + size) { print "yes"; exit }
        }
        print "no"
    }'

}

################################################################################
# Public IPv4 of this server, used to detect sites that moved elsewhere.
# CERTBOT_TRIAGE_PUBLIC_IP overrides discovery (tests, NATed setups).
#
# Arguments:
#   none
# Outputs:
#   Public IPv4 or empty string when it cannot be determined.
################################################################################
function _certbot_public_ip() {

    local ip

    if [[ -n "${CERTBOT_TRIAGE_PUBLIC_IP:-}" ]]; then
        echo "${CERTBOT_TRIAGE_PUBLIC_IP}"
        return 0
    fi
    # Never trust the body of these services: an error page, a captive portal
    # or a plain-HTTP MITM would otherwise be compared against DNS and label
    # every resolved non-Cloudflare domain as "moved".
    ip="$(curl -4 -fsS --connect-timeout 3 --max-time 6 https://api.ipify.org 2>/dev/null \
        || curl -4 -fsS --connect-timeout 3 --max-time 6 https://ipv4.icanhazip.com 2>/dev/null || true)"
    [[ "${ip}" =~ ^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$ ]] || { echo ""; return 0; }
    echo "${ip}"

}

################################################################################
# Every IPv4 address this host answers on: the public one, addresses bound to
# interfaces, and SERVER_CONFIG.additional_ips (managed hosts may serve sites
# from a secondary address or behind an edge VM). Used so a vhost pointing at
# a legitimate local address is never reported as "moved".
#
# Arguments:
#   none
# Outputs:
#   Space-separated IPv4 addresses, one per line is not guaranteed; deduplicated.
################################################################################
function _certbot_local_ipv4() {

    {
        hostname -I 2>/dev/null | tr ' ' '\n'
        ip -4 -o addr show scope global 2>/dev/null | awk '{ print $4 }' | cut -d/ -f1
        echo "${SERVER_ADDITIONAL_IPS:-}" | tr ',;' '  ' | tr ' ' '\n'
    } | grep -Eo '^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$' | sort -u

}

################################################################################
# Classify a domain for the certificate report. A missing or expired origin
# certificate means very different things depending on where the domain lives:
#
#   nxdomain  - no A record at all: nothing to renew, candidate for cleanup.
#   cloudflare - fronted by Cloudflare: no origin certificate is required.
#   moved     - resolves to a different server than this one: stale vhost here.
#   ok        - anything else.
#
# Arguments:
#   ${1} = domain
# Outputs:
#   One of nxdomain, cloudflare, moved, ok.
################################################################################
function certbot_domain_triage() {

    local domain="${1}"
    local ips ip server_ip found local_ip local_ips

    ips="$(_certbot_domain_ipv4 "${domain}")"
    if [[ -z "${ips}" ]]; then
        # An AAAA-only host is alive, not dead: only report nxdomain when the
        # name resolves to nothing at all, otherwise the report would suggest
        # deleting a working site.
        if getent ahostsv6 "${domain}" >/dev/null 2>&1; then
            echo "ok"
            return 0
        fi
        echo "nxdomain"
        return 0
    fi

    for ip in ${ips}; do
        [[ "$(_certbot_ip_is_cloudflare "${ip}")" == "yes" ]] && { echo "cloudflare"; return 0; }
    done

    server_ip="$(_certbot_public_ip)"
    if [[ -n "${server_ip}" ]]; then
        # Secondary addresses and an edge VM are legitimate answers for a
        # vhost on this host; comparing only against the primary public IP
        # would report those sites as "moved".
        local_ips="${server_ip} $(_certbot_local_ipv4)"
        found="no"
        for ip in ${ips}; do
            for local_ip in ${local_ips}; do
                [[ "${ip}" == "${local_ip}" ]] && found="yes"
            done
        done
        [[ "${found}" == "no" ]] && { echo "moved"; return 0; }
    fi

    echo "ok"

}

################################################################################
# Get certificate state for a cert name
#
# Arguments:
#  ${1} = ${domains} - cert name to look up
#
# Outputs:
#   ${cert_days} as a positive integer when valid, "EXPIRED" when certbot
#   reports it as invalid/expired, empty when no such certificate exists.
#   Always returns 0: emptiness of stdout is the signal, and a non-zero
#   return would abort callers under `set -e` (v="$(f)" inherits f's status).
#
# Note: this used to be inline `grep 'VALID' | cut ...`, which also matched
# "(INVALID: EXPIRED)". The leftover "EXPIRED)" string then reached the
# caller arithmetic comparison, where a bareword evaluates to 0 and produced
# the meaningless "EXPIRED) days" label in the report.
################################################################################

function certbot_certificate_state() {

  local domains="${1}"

  local expiry_line
  local cert_state

  expiry_line="$(certbot_certificates_output --cert-name "${domains}" | grep 'Expiry Date' | head -n 1)"

  if [[ -z "${expiry_line}" ]]; then

    return 0

  fi

  # "(VALID: 35 days)" -> 35
  if [[ "${expiry_line}" == *"(VALID:"* ]]; then

    cert_state="$(sed -n 's/.*(VALID: \([0-9][0-9]*\).*/\1/p' <<<"${expiry_line}")"

    if [[ -n "${cert_state}" ]]; then

      echo "${cert_state}"

      return 0

    fi

  fi

  # "(INVALID: EXPIRED)"
  if [[ "${expiry_line}" == *"INVALID: EXPIRED"* ]]; then

    echo "EXPIRED"

  fi

  return 0

}

################################################################################
# Show certificates valid days
#
# Arguments:
#  ${1} = ${domains} - (domain.com,www.domain.com)
#
# Outputs:
#   ${cert_days} if ok, "EXPIRED" if the certificate expired, empty when
#   there is no certificate at all.
################################################################################

# TODO: Awful code, need a refactor
function certbot_certificate_valid_days() {

  local domain="${1}"

  local cert_days
  local root_domain
  local subdomain_part

  root_domain="$(domain_get_root "${domain}")"
  subdomain_part="$(domain_get_subdomain_part "${domain}")"

  cert_days="$(certbot_certificate_state "${domain}")"

  if [[ -z ${cert_days} ]]; then

    if [[ ${subdomain_part} == "www" ]]; then

      cert_days="$(certbot_certificate_state "${root_domain}")"

      if [[ -z "${cert_days}" ]]; then
        # New try with -0001
        cert_days="$(certbot_certificate_state "${root_domain}-0001")"

      fi

    else

      cert_days="$(certbot_certificate_state "www.${root_domain}")"

      if [[ -z ${cert_days} ]]; then
        cert_days="$(certbot_certificate_state "${domain}-0001")"

      fi

    fi

  fi

  if [[ "${cert_days}" == "EXPIRED" ]]; then
    log_event "info" "Certificate EXPIRED for ${domain}" "false"
  else
    log_event "info" "Certificate valid for: ${cert_days} days" "false"
  fi

  # Return
  echo "${cert_days}"

}

################################################################################
# Get certificate valid days
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#  ${cert_days} if ok, "no-cert" on error.
################################################################################

function certbot_certificate_get_valid_days() {

  local domain="${1}"

  local cert_days

  cert_days_output="$(certbot_certificates_output --domain "${domain}" 2>&1)"
  cert_days="$(echo "${cert_days_output}" | grep -Eo 'VALID: [0-9]+[0-9]' | cut -d ' ' -f 2)"

  if [[ -z ${cert_days} ]]; then

    # Return
    echo "no-cert"

    return 1

  else

    # Return
    echo "${cert_days}"

    return 0

  fi

}

################################################################################
# Delete certificate with certbot
#
# Arguments:
#  ${1} = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_delete() {

  local domains="${1}"

  if [[ -z ${domains} ]]; then

    #Run certbot delete wizard
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
      openresty_vm_exec "certbot delete"
    else
      certbot delete
    fi

  else

    local certbot_result

    # Check if certificate exist (use exact cert-name grep)
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
      certbot_result="$(openresty_vm_exec "certbot certificates 2>/dev/null | grep -E \"Certificate Name|Domains:.*\\b${domains}\\b\"")"
    else
      certbot_result="$(certbot certificates 2>/dev/null | grep -E "Certificate Name|Domains:.*\b${domains}\b")"
    fi

    if [[ -n ${certbot_result} ]]; then

      if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        openresty_vm_exec "certbot delete --cert-name ${domains} --quiet"
      else
        certbot delete --cert-name "${domains}" --quiet
      fi

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting certificate for ${domains}" --result "DONE" --color GREEN

        return 0

      else

        # Log
        clear_previous_lines "1"
        log_event "error" "Running: certbot delete --cert-name ${domains}" "false"
        display --indent 6 --text "- Deleting certificate for ${domains}" --result "FAIL" --color RED
        display --indent 8 --text "Please, read the log file" --tcolor RED

        return 1

      fi

    else

      # Log
      clear_previous_lines "1"
      log_event "info" "Certificate for domain: ${domains} not found." "false"
      display --indent 6 --text "- Deleting certificate for ${domains}" --result "SKIPPED" --color YELLOW
      display --indent 8 --text "No certificate found" --tcolor RED

      return 0

    fi

  fi

}

################################################################################
# Certbot ask domains
#
# Arguments:
#  none
#
# Outputs:
#  ${domains} if ok, 1 on error.
################################################################################

function certbot_helper_ask_domains() {

  local domains

  domains="$(whiptail_input "CERTBOT MANAGER" "Insert the domain and/or subdomains that you want to work with. Ex: gauchocode.com,www.gauchocode.com" "" )"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${domains}" && return 0

  else

    return 1

  fi

}

################################################################################
# Decide the label and severity for one domain's certificate state.
#
# Pure function: every network/API fact is an argument, so the three mail
# decisions (no certificate, expired, days remaining) can be tested offline.
# The caller gathers the inputs: cert_days from certbot, the triage from
# certbot_domain_triage, the Cloudflare SSL mode from
# certbot_cloudflare_ssl_mode and the operator's expectation from
# _certbot_cloudflare_ssl_expected.
#
# Cloudflare behaviour (decided with the operator): brolit never changes a
# zone's SSL mode on its own; cloudflare_set_ssl_mode stays a manual action.
# - flexible/off: the origin certificate is not used -> grey, no warning.
# - full/strict: the origin certificate IS used -> warning when missing, with
#   the expected mode called out when the operator pinned one.
# - unknown (no API credentials or API error): grey by default so an
#   unreachable API cannot produce daily noise; BROLIT_CERT_CF_UNKNOWN=warn
#   opts a deployment into warning.
#
# Arguments:
#   ${1} = cert_days (empty = no certificate, EXPIRED, or integer days)
#   ${2} = triage result (ok/nxdomain/moved/cloudflare/empty)
#   ${3} = has_vhost (true/false): nginx is configured to serve this domain
#   ${4} = cf_ssl_mode (empty when not queried; off/flexible/full/strict/unknown)
#   ${5} = cf_expected (empty, or the operator's expected SSL mode for the zone)
#
# Outputs:
#   "<color>|<warn 0|1>|<label text>"; color in grey|red|green|orange
################################################################################
function mail_certificate_label() {

    local cert_days="${1}" triage="${2}" has_vhost="${3}"
    local cf_ssl_mode="${4}" cf_expected="${5}"

    if [[ -z "${cert_days}" ]]; then
        # No certificate: only a real problem when this server is supposed to
        # serve the domain and TLS is not terminated upstream.
        if [[ "${has_vhost}" != "true" ]]; then
            echo "grey|0|no certificate"
            return 0
        fi
        case "${triage}" in
            nxdomain) echo "red|1|nxdomain"; return 0 ;;
            moved) echo "red|1|moved"; return 0 ;;
            cloudflare)
                case "${cf_ssl_mode}" in
                    ""|off|flexible)
                        # TLS is terminated at the edge; the origin certificate
                        # is not used, so this is expected, not a warning.
                        echo "grey|0|CF fronted"
                        ;;
                    full|strict)
                        # Full/strict mode pulls the origin certificate into
                        # the trust chain: a missing one breaks the site.
                        if [[ -n "${cf_expected}" && "${cf_ssl_mode}" != "${cf_expected}" ]]; then
                            echo "red|1|CF ${cf_ssl_mode} != ${cf_expected}"
                        else
                            echo "red|1|CF ${cf_ssl_mode}: origin cert required"
                        fi
                        ;;
                    unknown|*)
                        if [[ "${BROLIT_CERT_CF_UNKNOWN:-info}" == "warn" ]]; then
                            echo "red|1|CF mode unknown"
                        else
                            echo "grey|0|CF fronted"
                        fi
                        ;;
                esac
                return 0
                ;;
            *)
                echo "red|1|no certificate"
                return 0
                ;;
        esac
    fi

    if [[ "${cert_days}" == "EXPIRED" ]]; then
        # Expired always warns, Cloudflare or not: full/strict mode would
        # break the site, and direct hits reach the origin certificate.
        case "${triage}" in
            nxdomain) echo "red|1|nxdomain" ;;
            moved) echo "red|1|moved" ;;
            *) echo "red|1|EXPIRED" ;;
        esac
        return 0
    fi

    if (("${cert_days}" >= 14)); then
        echo "green|0|${cert_days} days"
    elif (("${cert_days}" >= 7)); then
        echo "orange|0|${cert_days} days"
    else
        echo "red|1|${cert_days} days"
    fi

}

################################################################################
# Operator expectation map for Cloudflare SSL modes, matched by zone suffix:
#   BROLIT_CLOUDFLARE_SSL_EXPECT="broobe.com=flexible example.com=full"
# A zone entry applies to the zone itself and every subdomain of it. Empty
# entries are ignored. The comparison happens per zone, not per host, because
# the SSL mode is a zone-level Cloudflare setting.
#
# Arguments:
#   ${1} = domain
# Outputs:
#   Expected mode, or empty when none is pinned for its zone.
################################################################################
function _certbot_cloudflare_ssl_expected() {

    local domain="${1}" entry zone mode

    for entry in ${BROLIT_CLOUDFLARE_SSL_EXPECT:-}; do
        zone="${entry%%=*}"
        mode="${entry#*=}"
        [[ -n "${zone}" && -n "${mode}" ]] || continue
        if [[ "${domain}" == "${zone}" || "${domain}" == *."${zone}" ]]; then
            echo "${mode}"
            return 0
        fi
    done

    return 1

}

################################################################################
# Quietly read the SSL/TLS mode of the zone in front of a domain:
# off/flexible/full/strict, or nothing when it cannot be determined (no API
# credentials, zone missing, API error). One API call per unique zone per
# run: the mail section iterates every project and they share few zones, and
# borgmatic's command substitutions fork subshells, so the cache travels in
# an exported scalar of "zone=mode" pairs.
#
# Arguments:
#   ${1} = domain
# Outputs:
#   The mode, or nothing on any failure. Never mutates the zone.
################################################################################
function certbot_cloudflare_ssl_mode() {

    local domain="${1}" zone cached pair mode zone_id result

    [[ -n "${domain}" ]] || return 1

    if ! declare -F _cloudflare_get_zone_id >/dev/null 2>&1; then
        # BROLIT_MAIN_DIR exists in the cron context; derive the repo root
        # from this file so the read also works from standalone callers.
        local helper_root="${BROLIT_MAIN_DIR:-}"
        if [[ -z "${helper_root}" ]]; then
            helper_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
        fi
        if [[ -n "${helper_root}" && -f "${helper_root}/libs/apps/cloudflare_helper.sh" ]]; then
            # shellcheck disable=SC1090
            source "${helper_root}/libs/apps/cloudflare_helper.sh" >/dev/null 2>&1
        fi
    fi
    declare -F _cloudflare_get_zone_id >/dev/null 2>&1 || return 1

    if [[ -z "${SUPPORT_CLOUDFLARE_EMAIL:-}" || -z "${SUPPORT_CLOUDFLARE_API_KEY:-}" ]]; then
        # The nightly mail does not load the DNS section (the loader also
        # writes ~/.cloudflare.conf and can abort), so read the credentials
        # straight from the config. A bad or missing config must degrade to
        # "not queried" (grey label), never abort the mail.
        local conf="${BROLIT_CONFIG_FILE:-/root/.brolit_conf.json}"
        if [[ -f "${conf}" ]] && command -v jq >/dev/null 2>&1; then
            if [[ "$(jq -r '.DNS.cloudflare[0].status // ""' "${conf}" 2>/dev/null)" == "enabled" ]]; then
                SUPPORT_CLOUDFLARE_EMAIL="$(jq -r '.DNS.cloudflare[0].config[0].email // ""' "${conf}" 2>/dev/null)"
                SUPPORT_CLOUDFLARE_API_KEY="$(jq -r '.DNS.cloudflare[0].config[0].api_key // ""' "${conf}" 2>/dev/null)"
            fi
        fi
    fi
    [[ -n "${SUPPORT_CLOUDFLARE_EMAIL:-}" && -n "${SUPPORT_CLOUDFLARE_API_KEY:-}" ]] || return 1

    zone="$(_certbot_cloudflare_zone_root "${domain}")"
    [[ -n "${zone}" ]] || return 1

    for cached in ${CERTBOT_CLOUDFLARE_SSL_MODE_CACHE:-}; do
        if [[ "${cached%%=*}" == "${zone}" ]]; then
            echo "${cached#*=}"
            return 0
        fi
    done

    # The helper logs via `display`, which writes to stdout; keep only the
    # 32-char hex zone id.
    zone_id="$(_cloudflare_get_zone_id "${zone}" 2>/dev/null | grep -E '^[a-f0-9]{32}$' | head -1)"
    [[ -n "${zone_id}" ]] || return 1
    result="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/settings/ssl" \
        -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
        -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
        -H "Content-Type: application/json")"
    mode="$(grep -Po '(?<="value":")[^"]*' <<<"${result}" | head -1)"
    [[ -n "${mode}" ]] || return 1

    CERTBOT_CLOUDFLARE_SSL_MODE_CACHE="${CERTBOT_CLOUDFLARE_SSL_MODE_CACHE} ${zone}=${mode}"
    export CERTBOT_CLOUDFLARE_SSL_MODE_CACHE
    echo "${mode}"
    return 0

}

################################################################################
# Private: derive the registrable zone of a domain against the Cloudflare
# API, walking the label hierarchy until a zone exists. Handles multi-level
# public suffixes (arqa.com.ar) without shipping a public-suffix list.
#
# Arguments:
#   ${1} = domain
# Outputs:
#   Zone root, or empty when none exists.
################################################################################
function _certbot_cloudflare_zone_root() {

    local domain="${1}" candidate zone_id

    [[ -n "${domain}" ]] || return 1

    candidate="${domain}"
    while [[ -n "${candidate}" ]]; do
        # `display` writes to stdout; only a 32-char hex id proves the zone
        # exists (a failure banner is not proof of a zone).
        zone_id="$(_cloudflare_get_zone_id "${candidate}" 2>/dev/null | grep -E '^[a-f0-9]{32}$' | head -1)"
        if [[ -n "${zone_id}" ]]; then
            echo "${candidate}"
            return 0
        fi
        [[ "${candidate}" == *.* ]] || break
        candidate="${candidate#*.}"
    done

    return 1

}

#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
#############################################################################
#
# Cockpit Installer
#
#   Refs:
#       https://www.linuxtechi.com/how-to-install-cockpit-on-ubuntu-20-04/
#
################################################################################

################################################################################
# Cockpit installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function cockpit_installer() {

    local cockpit_bin

    cockpit_bin="$(package_is_installed "cockpit")"

    if [[ -n ${cockpit_bin} ]]; then

        log_event "info" "Cockpit is already installed" "false"

        return 0

    else

        log_subsection "Cockpit Installer"

        # Package update
        package_update

        # Install cockpit
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit"

        # Install cockpit extensions from backports repository
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-bridge"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-networkmanager"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-sosreport"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-storaged"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-packagekit"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-system"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-podman"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-machines"
        package_install "-t ${UBUNTU_CODENAME}-backports cockpit-pcp"

        if [[ ${PACKAGES_COCKPIT_CONFIG_NGINX} == "enabled" ]]; then

            # Ref: https://github.com/cockpit-project/cockpit/wiki/Proxying-Cockpit-over-NGINX
            nginx_server_create "${PACKAGES_COCKPIT_CONFIG_SUBDOMAIN}" "cockpit" "single" "" "${PACKAGES_COCKPIT_CONFIG_PORT}"

            if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

                # Extract root domain
                root_domain="$(domain_get_root "${PACKAGES_COCKPIT_CONFIG_SUBDOMAIN}")"

                cloudflare_set_record "${root_domain}" "${PACKAGES_COCKPIT_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"
                
                if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
                    # Wait 2 seconds for DNS update
                    sleep 2
                    # Let's Encrypt
                    certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${PACKAGES_COCKPIT_CONFIG_SUBDOMAIN}"
                fi

            fi

        fi

        # Firewall config
        firewall_allow "9090"

        # Log
        log_event "info" "Cockpit should be running on port 9090" "false"
        display --indent 4 --text "Running on port 9090" --tcolor YELLOW

    fi

}

function cockpit_purge() {

    log_subsection "Cockpit Installer"

    # Log
    display --indent 6 --text "- Removing cockpit and libraries"
    log_event "info" "Removing cockpit and libraries ..." "false"

    # apt command
    package_purge "cockpit-dashboard"
    package_purge "cockpit-bridge"
    package_purge "cockpit-networkmanager"
    package_purge "cockpit-sosreport"
    package_purge "cockpit-storaged"
    package_purge "cockpit-packagekit"
    package_purge "cockpit-system"
    package_purge "cockpit-podman"

    package_purge "cockpit"

    # Log
    #clear_previous_lines "1"

    return $?

}

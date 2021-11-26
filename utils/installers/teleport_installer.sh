#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.5-beta
################################################################################

function teleport_installer() {

    # Download pubkey for Teleport
    curl https://deb.releases.teleport.dev/teleport-pubkey.asc | sudo apt-key add -

    # Adding Teleport repository
    add-apt-repository 'deb https://deb.releases.teleport.dev/ stable main'

    package_update

    package_install_if_not "teleport"

    # Enabling and Starting Teleport
    systemctl enable teleport.service
    systemctl start teleport.service

}

function teleport_configure() {

    local teleport_mode="$1"

    if [ "${teleport_mode}" == "server" ]; then

        # Firewall rule
        firewall_allow "80"
        firewall_allow "443"
        firewall_allow "3022"
        firewall_allow "3025"

        # Configure Teleport as a Server
        teleport configure --acme --acme-email="${PACKAGE_TELEPORT_EMAIL}" --cluster-name="${PACKAGE_TELEPORT_CLUSTERNAME}" -o file

        # Create admin user for Teleport
        tctl users add teleport-admin --roles=editor,access --logins=root

        display --indent 6 --text "Teleport is now configured. Please visit https://${PACKAGE_TELEPORT_CLUSTERNAME} to complete the setup." --tcolor GREEN

    else

        # Firewall rule
        firewall_allow "80"
        firewall_allow "443"
        firewall_allow "3022"

        # Step 1
        tsh login --proxy="${PACKAGE_TELEPORT_CLUSTERNAME}":443 --auth=local --user="${PACKAGE_TELEPORT_USER}"

        # Step 2
        tctl tokens add --type=node --ttl=1h

        # Configure Teleport as a Client
        teleport start --roles=node --token="${TCTL_TOKEN}" --ca-pin="${CA_PIN}" --auth-server="${PACKAGE_TELEPORT_CLUSTERNAME}":3025

    fi

}

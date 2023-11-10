#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
#############################################################################

function test_mail_certificates_section() {

    local email_subject
    local email_content
    
    log_subsection "Test: test_mail_certificates_section"

    mail_certificates_section

    CERT_MAIL="${BROLIT_TMP_DIR}/cert-${NOW}.mail"
    CERT_MAIL_VAR=$(<"${CERT_MAIL}")

    # Preparing email to send
    log_event "info" "Sending Email to ${NOTIFICATION_EMAIL_MAILA} ..." "false"

    email_subject="${STATUS_ICON_D} [${NOWDISPLAY}] - Cert Expiration Info on ${SERVER_NAME}"
    email_content="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${MAIL_FOOTER}"

    # Sending email notification
    mail_send_notification "${email_subject}" "${email_content}"

    clear_previous_lines "1"
    display --indent 6 --text "- test_mail_certificates_section" --result "DONE" --color WHITE

}

function test_mail_package_section() {

    log_subsection "Test: test_mail_package_section"

    # Compare package versions
    mail_package_status_section

    # Preparing email to send
    log_event "info" "Sending Email to ${NOTIFICATION_EMAIL_MAILA} ..." "false"

    email_subject="${EMAIL_STATUS} [${NOWDISPLAY}] Packages Status Info on ${SERVER_NAME}"
    email_content="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${MAIL_FOOTER}"

    # Sending email notification
    mail_send_notification "${email_subject}" "${email_content}"

    clear_previous_lines "1"
    display --indent 6 --text "- test_mail_package_section" --result "DONE" --color WHITE

}
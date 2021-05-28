#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.27
#############################################################################

function test_mail_cert_section() {

    local email_subject
    local email_content
    
    log_subsection "Test: test_mail_cert_section"

    mail_cert_section

    CERT_MAIL="${TMP_DIR}/cert-${NOW}.mail"
    CERT_MAIL_VAR=$(<"${CERT_MAIL}")

    # Preparing email to send
    log_event "info" "Sending Email to ${MAILA} ..." "false"

    email_subject="${STATUS_ICON_D} [${NOWDISPLAY}] - Cert Expiration Info on ${VPSNAME}"
    email_content="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${MAIL_FOOTER}"

    # Sending email notification
    mail_send_notification "${email_subject}" "${email_content}"

    clear_last_line
    display --indent 6 --text "- test_mail_cert_section" --result "DONE" --color WHITE

}

function test_mail_package_section() {

    log_subsection "Test: test_mail_package_section"

    # Compare package versions
    mail_package_status_section "${PKG_DETAILS}"
    PKG_MAIL="${TMP_DIR}/pkg-${NOW}.mail"
    PKG_MAIL_VAR=$(<"${PKG_MAIL}")

    # Preparing email to send
    log_event "info" "Sending Email to ${MAILA} ..." "false"

    email_subject="${EMAIL_STATUS} [${NOWDISPLAY}] Packages Status Info on ${VPSNAME}"
    email_content="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${MAIL_FOOTER}"

    # Sending email notification
    mail_send_notification "${email_subject}" "${email_content}"

    clear_last_line
    display --indent 6 --text "- test_mail_package_section" --result "DONE" --color WHITE

}
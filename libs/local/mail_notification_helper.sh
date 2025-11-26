#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
################################################################################

# Load email template engine
source "${BROLIT_MAIN_DIR}/libs/local/mail_template_engine.sh"

# Global array to track temporary mail files for cleanup
declare -ga MAIL_TEMP_FILES=()

# Trap to ensure cleanup on script exit
trap '_cleanup_mail_temp_files' EXIT ERR INT TERM

################################################################################
# Cleanup all tracked temporary mail files
#
# This function is called automatically via trap on EXIT/ERR/INT/TERM
################################################################################
function _cleanup_mail_temp_files() {
    if [[ ${#MAIL_TEMP_FILES[@]} -gt 0 ]]; then
        log_event "debug" "Cleaning up ${#MAIL_TEMP_FILES[@]} temporary mail files..." "false" 2>/dev/null || true
        for temp_file in "${MAIL_TEMP_FILES[@]}"; do
            if [[ -f "${temp_file}" ]]; then
                rm -f "${temp_file}" 2>/dev/null || true
            fi
        done
        MAIL_TEMP_FILES=()
    fi
}

################################################################################
# Create a temporary mail file and track it for cleanup
#
# Arguments:
#   ${1} = ${base_name} // Base name for the temp file (e.g., "server_info")
#
# Outputs:
#   Path to the created temporary file
################################################################################
function _create_temp_mail_file() {
    local base_name="${1}"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local temp_file="${BROLIT_TMP_DIR}/${base_name}-${timestamp}-$$.mail"

    # Track this file for cleanup
    MAIL_TEMP_FILES+=("${temp_file}")

    # Create empty file
    touch "${temp_file}" 2>/dev/null || {
        log_event "error" "Failed to create temporary mail file: ${temp_file}" "false"
        return 1
    }

    echo "${temp_file}"
}

# sendmail --help
#
# Required:
#    -f ADDRESS                from (sender) email address
#    * At least one recipient required via -t, -cc, or -bcc
#    * Message body required via -m, STDIN, or -o message-file=FILE
#
#  Others:
#    -t ADDRESS [ADDR ...]     to email address(es)
#    -u SUBJECT                message subject
#    -m MESSAGE                message body
#    -s SERVER[:PORT]          smtp mail relay, default is localhost:25
#    -S [SENDMAIL_PATH]        use local sendmail utility (default: /usr/bin/sendmail) instead of network MTA
#    -a   FILE [FILE ...]      file attachment(s)
#    -cc  ADDRESS [ADDR ...]   cc  email address(es)
#    -bcc ADDRESS [ADDR ...]   bcc email address(es)
#    -xu  USERNAME             username for SMTP authentication
#    -xp  PASSWORD             password for SMTP authentication
#    -b BINDADDR[:PORT]        local host bind address
#    -l LOGFILE                log to the specified file
#    -v                        verbosity, use multiple times for greater effect
#    -q                        be quiet (i.e. no STDOUT output)
#    -o NAME=VALUE             advanced options, for details try: --help misc
#        -o message-content-type=<auto|text|html>
#        -o message-file=FILE         -o message-format=raw
#        -o message-header=HEADER     -o message-charset=CHARSET
#        -o reply-to=ADDRESS          -o timeout=SECONDS
#        -o username=USERNAME         -o password=PASSWORD
#        -o tls=<auto|yes|no>         -o fqdn=FQDN
#

################################################################################
# Send email notification
#
# Arguments:
#   ${1} = ${email_subject}     // Email's subject
#   ${2} = ${email_content}     // Email's content (HTML or plain text)
#   ${3} = ${notification_type} // Optional: alert, warning, info, success (default: info)
#
# Outputs:
#   0 if ok, 1 on error.
#
# Notes:
#   - If email_content is plain text, it will be wrapped in a template based on notification_type
#   - If email_content is already HTML (starts with <), it will be sent as-is
#   - This provides parity with Telegram, Discord, and ntfy channels
################################################################################

function mail_send_notification() {

    local email_subject="${1}"
    local email_content="${2}"
    local notification_type="${3:-info}"  # Default to 'info' if not specified
    local from_email="${NOTIFICATION_EMAIL_FROM_EMAIL:-${NOTIFICATION_EMAIL_SMTP_USER}}"

    # If content is NOT already HTML, wrap it in a notification template
    # This allows simple text notifications to have proper formatting based on type
    if [[ ! "${email_content}" =~ ^[[:space:]]*\< ]]; then
        log_event "debug" "Email content is plain text, wrapping in notification-${notification_type} template" "false"

        # Try to render notification template
        local wrapped_content
        if wrapped_content="$(mail_template_render "notification-${notification_type}" \
            "title=${email_subject}" \
            "content=${email_content}" 2>/dev/null)"; then
            email_content="${wrapped_content}"
            log_event "debug" "Email content wrapped in ${notification_type} template" "false"
        else
            # Template not found, use content as-is but log warning
            log_event "warning" "Notification template 'notification-${notification_type}' not found, using plain content" "false"
        fi
    else
        log_event "debug" "Email content is already HTML, using as-is" "false"
    fi

    # Check SMTP config
    if [[ "${NOTIFICATION_EMAIL_SMTP_SERVER}" == "" ]] || [[ "${NOTIFICATION_EMAIL_SMTP_PORT}" == "" ]] || [[ "${NOTIFICATION_EMAIL_SMTP_USER}" == "" ]] || [[ "${NOTIFICATION_EMAIL_SMTP_UPASS}" == "" ]] || [[ "${NOTIFICATION_EMAIL_EMAIL_TO}" == "" ]]; then

        # Log
        log_event "warning" "SMTP config not found. Skipping email notification." "false"
        display --indent 6 --text "- Sending Email notification" --result "SKIP" --color YELLOW
        display --indent 8 --text "SMTP config not found. Skipping email notification."

        return 1

    fi

    # Log
    log_event "info" "Sending Email to ${NOTIFICATION_EMAIL_EMAIL_TO} ..." "false"
    log_event "debug" "Running: sendEmail -f \"${from_email}\" -t \"${NOTIFICATION_EMAIL_EMAIL_TO}\" -u \"${email_subject}\" -o message-content-type=html -m \"${email_content}\" -s \"${NOTIFICATION_EMAIL_SMTP_SERVER}:${NOTIFICATION_EMAIL_SMTP_PORT}\" -o tls=\"${NOTIFICATION_EMAIL_SMTP_TLS}\" -xu \"${NOTIFICATION_EMAIL_SMTP_USER}\" -xp \"${NOTIFICATION_EMAIL_SMTP_UPASS}\"" "false"

    # Sending email
    ## Use -l "/${SCRIPT}/sendemail.log" for custom log file
    sendEmail -f "${from_email}" -t "${NOTIFICATION_EMAIL_EMAIL_TO}" -u "${email_subject}" -o message-content-type=html -m "${email_content}" -s "${NOTIFICATION_EMAIL_SMTP_SERVER}:${NOTIFICATION_EMAIL_SMTP_PORT}" -o tls="${NOTIFICATION_EMAIL_SMTP_TLS}" -xu "${NOTIFICATION_EMAIL_SMTP_USER}" -xp "${NOTIFICATION_EMAIL_SMTP_UPASS}" 1>&2

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Remove tmp files
        _remove_mail_notifications_files

        # Log on success
        clear_previous_lines "1"
        log_event "info" "Email notification sent!"
        display --indent 6 --text "- Sending Email notification" --result "DONE" --color GREEN

        return 0

    else

        # Remove tmp files
        _remove_mail_notifications_files

        # Log on failure
        clear_previous_lines "1"
        log_event "info" "Something went wrong sending the email: '${email_subject}'" "false"
        display --indent 6 --text "- Sending Email notification" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Mail subject status.
#
# Arguments:
#   ${1} = ${status_d} // Database backup status
#   ${2} = ${status_f} // Files backup status
#   ${3} = ${status_s} // Server status
#   ${4} = ${status_c} // Certificates status
#   ${5} = ${outdated} // System Packages status
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_subject_status() {

    local status_d="${1}"
    local status_f="${2}"
    local status_s="${3}"
    local status_c="${4}"
    local outdated="${5}"
    local status_b="${6}"  # Borg backup status

    local status

    # Check for errors in any backup method
    if [[ ${status_d} == 1 ]] || [[ ${status_f} == 1 ]] || [[ ${status_s} == 1 ]] || [[ ${status_c} == 1 ]] || [[ ${status_b} == 1 ]]; then
        status="⛔ ERROR"

    else
        if [[ "${outdated}" = true ]] || [[ "${status_c}" == *"WARNING"* ]]; then
            status="⚠ WARNING"

        else
            status="🟢"

        fi
    fi

    # Return
    echo "${status}"

}

function _remove_mail_notifications_files() {

    # Call the new cleanup function
    _cleanup_mail_temp_files

    log_event "debug" "Email temporary files removed!" "false"

}

################################################################################
# Mail server status section.
#
# Arguments:
#   ${1} = ${server_status}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_server_status_section() {

    local server_status="${1}"

    local disk_u
    local disk_u_ns
    local casted_disk_u_ns
    local server_status_icon

    # Disk Usage
    disk_u="$(calculate_disk_usage "${MAIN_VOL}")"

    # Extract % to compare
    disk_u_ns="$(echo "${disk_u}" | cut -f1 -d'%')"

    # Cast to int
    casted_disk_u_ns=$(printf '%d' "${disk_u_ns:-0}" 2>/dev/null || echo "0")

    if [[ ${casted_disk_u_ns} -gt 45 ]]; then
        server_status="WARNING"
        server_status_icon="⚠"
    else
        server_status="OK"
        server_status_icon="✅"
    fi

    # Create temporary file with tracking
    local mail_file
    if ! mail_file="$(_create_temp_mail_file "server_info-${NOW}")"; then
        log_event "error" "Failed to create temporary mail file for server status section" "false"
        return 1
    fi

    # Render template with new engine
    local rendered_html
    if ! rendered_html="$(mail_template_render "server_info" \
        "server_status=${server_status}" \
        "server_status_icon=${server_status_icon}" \
        "server_ipv4=${SERVER_IP}" \
        "server_ipv6=${SERVER_IPv6:-}" \
        "disk_usage=${disk_u}")"; then
        log_event "error" "Failed to render server status template" "false"
        return 1
    fi

    # Write to file
    echo "${rendered_html}" > "${mail_file}" || {
        log_event "error" "Failed to write server status section to ${mail_file}" "false"
        return 1
    }

    log_event "debug" "Server status section created: ${mail_file}" "false"

    return 0

}

################################################################################
# Mail packages status section.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_package_status_section() {

    local pkg_details
    local pkg_status
    local pkg_status_icon

    # Check for important packages updates
    pkg_details=$(mail_package_section "${PACKAGES[@]}") # ${PACKAGES[@]} is a Global array with packages names

    # If not empty, system is outdated
    if [[ -n "${pkg_details}" ]]; then
        pkg_status="OUTDATED_PACKAGES"
        pkg_status_icon="⚠"
    else
        pkg_status="OK"
        pkg_status_icon="✅"
    fi

    # Create temporary file with tracking
    local mail_file
    if ! mail_file="$(_create_temp_mail_file "packages-${NOW}")"; then
        log_event "error" "Failed to create temporary mail file for packages section" "false"
        return 1
    fi

    # Render template with new engine
    local rendered_html
    if ! rendered_html="$(mail_template_render "packages" \
        "packages_status=${pkg_status}" \
        "packages_status_icon=${pkg_status_icon}" \
        "packages_status_details=${pkg_details}")"; then
        log_event "error" "Failed to render packages template" "false"
        return 1
    fi

    # Write to file
    echo "${rendered_html}" > "${mail_file}" || {
        log_event "error" "Failed to write packages section to ${mail_file}" "false"
        return 1
    }

    log_event "debug" "Packages section created: ${mail_file}" "false"

    return 0

}

################################################################################
# Mail files backup section.
#
# Arguments:
#   ${1} = ${PACKAGES} // Packages to be updated
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_package_section() {

    local -n PACKAGES="${1}"

    local package
    local package_version_installed
    local package_version_candidate

    for package in "${PACKAGES[@]}"; do

        package_version_installed="$(apt-cache policy "${package}" | grep Installed | cut -d ':' -f 2)"

        if [[ ${package_version_installed} = "(none)" ]] && [[ ${package} = "mysql-server" ]]; then
            package="mariadb-server"
            package_version_installed="$(apt-cache policy "${package}" | grep Installed | cut -d ':' -f 2)"
        fi

        package_version_candidate="$(apt-cache policy "${package}" | grep Candidate | cut -d ':' -f 2)"

        if [[ ${package_version_installed} != "${package_version_candidate}" ]]; then

            # Return
            echo "<div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">${package} ${package_version_installed} -> ${package_version_candidate}</div>"

        fi

    done

}

################################################################################
# Mail certificates section.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_certificates_section() {

    local domain
    local all_sites
    local cert_days
    local email_cert_line
    local email_cert_new_line
    local email_cert_domain
    local email_cert_days
    local email_cert_days_container
    local email_cert_end_line
    local cert_status_icon
    local status_certs="OK"

    # Initialize
    cert_status_icon="✅"
    email_cert_line=""

    all_sites="$(get_all_directories "${PROJECTS_PATH}")"

    for site in ${all_sites}; do

        domain="$(basename "${site}")"

        # Check blacklist ${IGNORED_PROJECTS_LIST}
        if [[ "${IGNORED_PROJECTS_LIST}" != *"${domain}"* ]]; then

            log_event "info" "Getting certificate info for: ${domain}" "false"

            # Change global
            BK_FL_ARRAY_INDEX="$((BK_FL_ARRAY_INDEX + 1))"

            email_cert_new_line="<div style=\"float:left;width:100%\">"
            email_cert_domain="<div>${domain}"

            cert_days="$(certbot_certificate_valid_days "${domain}")"

            if [[ -z "${cert_days}" ]]; then
                # GREY LABEL - No certificate
                email_cert_days_container=" <span style=\"color:white;background-color:#5d5d5d;border-radius:12px;padding:0 5px 0 5px;\">"
                email_cert_days="${email_cert_days_container} no certificate"
                cert_status_icon="⚠️"
                status_certs="WARNING"

            else
                # Certificate found - color based on days remaining
                if (("${cert_days}" >= 14)); then
                    # GREEN LABEL
                    email_cert_days_container=" <span style=\"color:white;background-color:#27b50d;border-radius:12px;padding:0 5px 0 5px;\">"
                elif (("${cert_days}" >= 7)); then
                    # ORANGE LABEL
                    email_cert_days_container=" <span style=\"color:white;background-color:#df761d;border-radius:12px;padding:0 5px 0 5px;\">"
                else
                    # RED LABEL
                    email_cert_days_container=" <span style=\"color:white;background-color:#df1d1d;border-radius:12px;padding:0 5px 0 5px;\">"
                    cert_status_icon="⚠️"
                    status_certs="WARNING"
                fi

                email_cert_days="${email_cert_days_container}${cert_days} days"
            fi

            email_cert_end_line="</span></div></div>"
            email_cert_line="${email_cert_line}${email_cert_new_line}${email_cert_domain}${email_cert_days}${email_cert_end_line}"

        fi

    done

    # Create temporary file with tracking
    local mail_file
    if ! mail_file="$(_create_temp_mail_file "certificates-${NOW}")"; then
        log_event "error" "Failed to create temporary mail file for certificates section" "false"
        return 1
    fi

    # Render template with new engine
    local rendered_html
    if ! rendered_html="$(mail_template_render "certificates" \
        "certificates_status=${status_certs}" \
        "certificates_status_icon=${cert_status_icon}" \
        "certificates_list=${email_cert_line}")"; then
        log_event "error" "Failed to render certificates template" "false"
        return 1
    fi

    # Write to file
    echo "${rendered_html}" > "${mail_file}" || {
        log_event "error" "Failed to write certificates section to ${mail_file}" "false"
        return 1
    }

    log_event "debug" "Certificates section created: ${mail_file}" "false"

    return 0

}

################################################################################
# Mail backup section.
#
# Arguments:
#   ${1} = ${error_msg}
#   ${2} = ${error_type}
#   ${3} = ${backup_type}
#   ${4} = ${backuped_list}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_backup_section() {

    local error_msg="${1}"
    local error_type="${2}"
    local backup_type="${3}"

    # Move args to array
    shift 3
    local backuped_list=("$@")

    local bk_name
    local bk_size
    local backup_status
    local backup_status_icon
    local section_content
    local files_inc
    local files_inc_buff
    local files_inc_line_p1
    local files_inc_line_p2
    local files_inc_line_p3
    local files_inc_line_p4
    local files_label_d_end

    # Log
    log_event "debug" "Preparing mail ${backup_type} backup section ..." "false"
    log_event "debug" "error_msg=${error_msg}" "false"
    log_event "debug" "error_type=${error_type}" "false"
    log_event "debug" "backup_type=${backup_type}" "false"

    if [[ ${error_msg} != "none" ]]; then
        backup_status="ERROR"
        backup_status_icon="⛔"
        section_content="<b>${backup_type} backup with errors:<br />${error_type}<br /><br />Please check log file.</b> <br />"

    else
        backup_status="OK"
        backup_status_icon="✅"
        section_content=""
        files_inc=""

        for backup_file in "${backuped_list[@]}"; do

            bk_name="$(echo "${backup_file}" | cut -d ";" -f1)"
            bk_size="$(echo "${backup_file}" | cut -d ";" -f2)"

            log_event "debug" "backup_file=${backup_file}" "false"
            log_event "debug" "bk_name=${bk_name}" "false"
            log_event "debug" "bk_size=${bk_size}" "false"

            # File list section
            files_inc_line_p1="<div class=\"backup-details-line\">"
            files_inc_line_p2="<span style=\"margin-right:5px;\">${bk_name}</span>"
            files_inc_line_p3="<span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">${bk_size}</span>"
            files_inc_line_p4="</div>"

            files_inc_buff="${files_inc}"
            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_buff}"

        done

        files_label_d_end="</div>"
        section_content="${files_inc}${files_label_d_end}"

    fi

    # Create temporary file with tracking
    local mail_file
    if ! mail_file="$(_create_temp_mail_file "${backup_type}-bk-${NOW}")"; then
        log_event "error" "Failed to create temporary mail file for ${backup_type} backup section" "false"
        return 1
    fi

    # Render template with new engine
    local rendered_html
    if ! rendered_html="$(mail_template_render "backup_${backup_type}" \
        "backup_status=${backup_status}" \
        "backup_status_icon=${backup_status_icon}" \
        "backup_list=${section_content}")"; then
        log_event "error" "Failed to render ${backup_type} backup template" "false"
        return 1
    fi

    # Write to file
    echo "${rendered_html}" > "${mail_file}" || {
        log_event "error" "Failed to write ${backup_type} backup section to ${mail_file}" "false"
        return 1
    }

    log_event "debug" "${backup_type} backup section created: ${mail_file}" "false"

    return 0

}

################################################################################
# Mail footer.
#
# Arguments:
#   ${1} = ${script_v}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_footer() {

    local script_v="${1}"

    local mail_footer

    local email_template="default"

    html_footer="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/footer-tpl.html")"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_footer="$(echo "${html_footer}" | sed -e 's|{{brolit_version}}|'"${script_v}"'|g')"

    # Write e-mail parts files
    echo "${mail_footer}" >"${BROLIT_TMP_DIR}/footer-${NOW}.mail"

}

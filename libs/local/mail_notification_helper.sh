#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2-beta
################################################################################

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
# Mail subject status.
#
# Arguments:
#   ${1} = ${email_subject} // Email's subject
#   ${2} = ${email_content} // Email's content
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mail_send_notification() {

    local email_subject="${1}"
    local email_content="${2}"

    # Log
    log_event "info" "Sending Email to ${NOTIFICATION_EMAIL_MAILA} ..." "false"
    log_event "debug" "Running: sendEmail -f \"${NOTIFICATION_EMAIL_SMTP_USER}\" -t \"${NOTIFICATION_EMAIL_MAILA}\" -u \"${email_subject}\" -o message-content-type=html -m \"${email_content}\" -s \"${NOTIFICATION_EMAIL_SMTP_SERVER}:${NOTIFICATION_EMAIL_SMTP_PORT}\" -o tls=\"${NOTIFICATION_EMAIL_SMTP_TLS}\" -xu \"${NOTIFICATION_EMAIL_SMTP_USER}\" -xp \"${NOTIFICATION_EMAIL_SMTP_UPASS}\"" "false"

    # Sending email
    ## Use -l "/${SCRIPT}/sendemail.log" for custom log file
    sendEmail -f ${NOTIFICATION_EMAIL_SMTP_USER} -t "${NOTIFICATION_EMAIL_MAILA}" -u "${email_subject}" -o message-content-type=html -m "${email_content}" -s "${NOTIFICATION_EMAIL_SMTP_SERVER}:${NOTIFICATION_EMAIL_SMTP_PORT}" -o tls="${NOTIFICATION_EMAIL_SMTP_TLS}" -xu "${NOTIFICATION_EMAIL_SMTP_USER}" -xp "${NOTIFICATION_EMAIL_SMTP_UPASS}" 1>&2

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

    local status

    if [[ ${status_d} == 1 ]] || [[ ${status_f} == 1 ]] || [[ ${status_s} == 1 ]] || [[ ${status_c} == 1 ]]; then
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

    rm --force "${BROLIT_TMP_DIR}/*.mail"

    # Remove one per line only for better readibility
    #rm --force "${BROLIT_TMP_DIR}/cert-${NOW}.mail"
    #rm --force "${BROLIT_TMP_DIR}/pkg-${NOW}.mail"
    #rm --force "${BROLIT_TMP_DIR}/files-bk-${NOW}.mail"
    #rm --force "${BROLIT_TMP_DIR}/configuration-bk-${NOW}.mail"
    #rm --force "${BROLIT_TMP_DIR}/databases-bk-${NOW}.mail"

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
    local content
    local body

    local email_template="default"

    # Disk Usage
    disk_u="$(calculate_disk_usage "${MAIN_VOL}")"

    # Extract % to compare
    disk_u_ns="$(echo "${disk_u}" | cut -f1 -d'%')"

    # Cast to int
    casted_disk_u_ns=$(int() { printf '%d' "${disk_u_ns:-}" 2>/dev/null || :; })

    if [[ ${casted_disk_u_ns} -gt 45 ]]; then

        server_status="WARNING"
        server_status_icon="⚠"
        #server_status_color="#fb2f2f"

    else

        server_status="OK"
        server_status_icon="✅"
        #server_status_color="#503fe0"

    fi

    html_server_info_details="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/server_info-tpl.html")"

    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_status}}/${server_status}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_status_icon}}/${server_status_icon}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_ipv4}}/${SERVER_IP}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_ipv6}}/${SERVER_IPv6}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{disk_usage}}/${disk_u}/g")"

    # Write e-mail parts files
    echo "${html_server_info_details}" >"${BROLIT_TMP_DIR}/server_info-${NOW}.mail"

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

    # TODO: config support
    local email_template="default"

    # Check for important packages updates
    pkg_details=$(mail_package_section "${PACKAGES[@]}") # ${PACKAGES[@]} is a Global array with packages names

    #if not empty, system is outdated
    if [[ ${pkg_details} != "" ]]; then

        #OUTDATED_PACKAGES=true
        #pkg_color="#b51c1c"
        pkg_status="OUTDATED_PACKAGES"
        pkg_status_icon="⚠"

    else

        #pkg_color='#503fe0'
        pkg_status="OK"
        pkg_status_icon="✅"

    fi

    html_pkg_details="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/packages-tpl.html")"

    html_pkg_details="$(echo "${html_pkg_details}" | sed -e 's|{{packages_status}}|'"${pkg_status}"'|g')"
    html_pkg_details="$(echo "${html_pkg_details}" | sed -e 's|{{packages_status_icon}}|'"${pkg_status_icon}"'|g')"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    html_pkg_details="$(echo "${html_pkg_details}" | sed -e 's|{{packages_status_details}}|'"${pkg_details}"'|g')"

    # Write e-mail parts files
    echo "${html_pkg_details}" >"${BROLIT_TMP_DIR}/packages-${NOW}.mail"

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

    local email_template="default"

    local domain
    local all_sites
    local cert_days
    local email_cert_line
    local email_cert_new_line
    local cert_status_icon
    local status_certs="OK"

    # TODO: config support
    local email_template="default"

    # Changing locals
    cert_status_icon="✅"
    #cert_status_color="#503fe0"
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

            if [[ ${cert_days} == "" ]]; then
                # GREY LABEL
                email_cert_days_container=" <span style=\"color:white;background-color:#5d5d5d;border-radius:12px;padding:0 5px 0 5px;\">"
                email_cert_days="${email_cert_days_container} no certificate"
                cert_status_icon="⚠️"
                #cert_status_color="red"
                status_certs="WARNING"

            else #certificate found

                if (("${cert_days}" >= 14)); then
                    # GREEN LABEL
                    email_cert_days_container=" <span style=\"color:white;background-color:#27b50d;border-radius:12px;padding:0 5px 0 5px;\">"
                else
                    if (("${cert_days}" >= 7)); then
                        # ORANGE LABEL
                        email_cert_days_container=" <span style=\"color:white;background-color:#df761d;border-radius:12px;padding:0 5px 0 5px;\">"
                    else
                        # RED LABEL
                        email_cert_days_container=" <span style=\"color:white;background-color:#df1d1d;border-radius:12px;padding:0 5px 0 5px;\">"
                        cert_status_icon="⚠️"
                        #cert_status_color="red"
                        status_certs="WARNING"
                    fi

                fi
                email_cert_days="${email_cert_days_container}${cert_days} days"

            fi

            email_cert_end_line="</span></div></div>"
            email_cert_line="${email_cert_line}${email_cert_new_line}${email_cert_domain}${email_cert_days}${email_cert_end_line}"

        fi

    done

    body="${email_cert_line}"

    mail_certificates_html="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/certificates-tpl.html")"

    mail_certificates_html="$(echo "${mail_certificates_html}" | sed -e 's|{{certificates_status}}|'"${status_certs}"'|g')"
    mail_certificates_html="$(echo "${mail_certificates_html}" | sed -e 's|{{certificates_status_icon}}|'"${cert_status_icon}"'|g')"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_certificates_html="$(echo "${mail_certificates_html}" | sed -e 's|{{certificates_list}}|'"${body}"'|g')"

    # Return
    echo "${mail_certificates_html}" >"${BROLIT_TMP_DIR}/certificates-${NOW}.mail"

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

    shift 3
    local backuped_list="$@"

    #local count
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

    local mail_backup_html

    # TODO: config support
    local email_template="default"

    # Log
    log_event "debug" "Preparing mail ${backup_type} backup section ..." "false"
    log_event "debug" "error_msg=${error_msg}" "false"
    log_event "debug" "error_type=${error_type}" "false"
    log_event "debug" "backup_type=${backup_type}" "false"
    log_event "debug" "backuped_list=${backuped_list}" "false"

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

    # Log
    log_event "debug" "Using template: ${BROLIT_MAIN_DIR}/templates/emails/${email_template}/backup_${backup_type}-tpl.html" "false"

    mail_backup_html="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/backup_${backup_type}-tpl.html")"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_backup_html="$(echo "${mail_backup_html}" | sed -e 's|{{backup_status}}|'"${backup_status}"'|g')"
    mail_backup_html="$(echo "${mail_backup_html}" | sed -e 's|{{backup_status_icon}}|'"${backup_status_icon}"'|g')"
    mail_backup_html="$(echo "${mail_backup_html}" | sed -e 's|{{backup_list}}|'"${section_content}"'|g')"

    # Write e-mail parts files
    echo "${mail_backup_html}" >"${BROLIT_TMP_DIR}/${backup_type}-bk-${NOW}.mail"

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

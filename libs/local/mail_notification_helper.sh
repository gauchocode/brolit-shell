#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.63
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

function mail_send_notification() {

    # $1 = ${email_subject} // Email's subject
    # $2 = ${email_content} // Email's content

    local email_subject=$1
    local email_content=$2

    # Log
    log_event "info" "Sending Email to ${MAILA} ..." "false"
    log_event "debug" "Running: sendEmail -f \"${SMTP_U}\" -t \"${MAILA}\" -u \"${email_subject}\" -o message-content-type=html -m \"${email_content}\" -s \"${SMTP_SERVER}:${SMTP_PORT}\" -o tls=\"${SMTP_TLS}\" -xu \"${SMTP_U}\" -xp \"${SMTP_P}\"" "false"

    # Sending email
    ## Use -l "/${SCRIPT}/sendemail.log" for custom log file
    sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${email_subject}" -o message-content-type=html -m "${email_content}" -s "${SMTP_SERVER}:${SMTP_PORT}" -o tls="${SMTP_TLS}" -xu "${SMTP_U}" -xp "${SMTP_P}" 1>&2

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "info" "Email sent!" "false"

    else

        # Log
        log_event "info" "Something went wrong sending the email: '${email_subject}'" "false"

        return 1

    fi

}

function mail_subject_status() {

    # $1 = ${status_d} // Database backup status
    # $2 = ${status_f} // Files backup status
    # $3 = ${status_s} // Server status
    # $4 = ${status_c} // Certificates status
    # $5 = ${outdated} // System Packages status

    local status_d=$1
    local status_f=$2
    local status_s=$3
    local status_c=$4
    local outdated=$5

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

function remove_mail_notifications_files() {

    # Remove one per line only for better readibility
    rm --force "${TMP_DIR}/cert-${NOW}.mail"
    rm --force "${TMP_DIR}/pkg-${NOW}.mail"
    rm --force "${TMP_DIR}/file-bk-${NOW}.mail"
    rm --force "${TMP_DIR}/config-bk-${NOW}.mail"
    rm --force "${TMP_DIR}/db-bk-${NOW}.mail"

    log_event "info" "Email temporary files removed!" "false"

}

function mail_server_status_section() {

    #declare -g STATUS_SERVER # Global to check section status

    local server_status=$1

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

    html_server_info_details="$(cat "${SFOLDER}/templates/emails/${email_template}/server_info-tpl.html")"

    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_status}}/${server_status}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_status_icon}}/${server_status_icon}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_ipv4}}/${SERVER_IP}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{server_ipv6}}/${SERVER_IPv6}/g")"
    html_server_info_details="$(echo "${html_server_info_details}" | sed -e "s/{{disk_usage}}/${disk_u}/g")"

    # Write e-mail parts files
    echo "${html_server_info_details}" >"${TMP_DIR}/server_info-${NOW}.mail"

}

function mail_package_status_section() {

    local pkg_details
    #local pkg_color
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

    html_pkg_details="$(cat "${SFOLDER}/templates/emails/${email_template}/packages-tpl.html")"

    html_pkg_details="$(echo "${html_pkg_details}" | sed -e 's|{{packages_status}}|'"${pkg_status}"'|g')"
    html_pkg_details="$(echo "${html_pkg_details}" | sed -e 's|{{packages_status_icon}}|'"${pkg_status_icon}"'|g')"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    html_pkg_details="$(echo "${html_pkg_details}" | sed -e 's|{{packages_status_details}}|'"${pkg_details}"'|g')"

    # Write e-mail parts files
    echo "${html_server_info_details}" >"${TMP_DIR}/packages-${NOW}.mail"

}

function mail_package_section() {

    # $1 = ${PACKAGES} // Packages to be updated

    local -n PACKAGES=$1

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

function mail_certificates_section() {

    local email_template="default"

    local domain
    local all_sites
    local cert_days
    local email_cert_line
    local email_cert_new_line
    local cert_status_icon
    #local cert_status_color
    local files_label

    # Changing global
    declare -g STATUS_CERTS="OK"

    # TODO: config support
    local email_template="default"

    # Changing locals
    cert_status_icon="✅"
    #cert_status_color="#503fe0"
    files_label="<b>Sites certificate expiration days:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
    email_cert_line=""

    # This fix avoid getting the first parent directory, maybe we could find a better solution
    local k="skip"

    all_sites="$(get_all_directories "${SITES}")"

    for site in ${all_sites}; do

        if [ "${k}" != "skip" ]; then

            domain="$(basename "${site}")"

            # Check blacklist ${BLACKLISTED_SITES}
            if [[ "${BLACKLISTED_SITES}" != *"${domain}"* ]]; then

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
                    STATUS_CERTS="WARNING"

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
                            STATUS_CERTS="WARNING"
                        fi

                    fi
                    email_cert_days="${email_cert_days_container}${cert_days} days"

                fi

                email_cert_end_line="</span></div></div>"
                email_cert_line="${email_cert_line}${email_cert_new_line}${email_cert_domain}${email_cert_days}${email_cert_end_line}"

            fi
        else
            k=""

        fi

    done

    body="${email_cert_line}"

    mail_certificates_html="$(cat "${SFOLDER}/templates/emails/${email_template}/certificates-tpl.html")"

    mail_certificates_html="$(echo "${mail_certificates_html}" | sed -e 's|{{certificates_status}}|'"${STATUS_CERTS}"'|g')"
    mail_certificates_html="$(echo "${mail_certificates_html}" | sed -e 's|{{certificates_status_icon}}|'"${cert_status_icon}"'|g')"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_certificates_html="$(echo "${mail_certificates_html}" | sed -e 's|{{certificates_list}}|'"${body}"'|g')"

    # Return
    echo "${mail_certificates_html}" >"${TMP_DIR}/certificates-${NOW}.mail"

}

function mail_files_backup_section() {

    # Global array ${BACKUPED_LIST[@]}
    # Global array ${BK_FL_SIZES[@]}

    local error_msg=$1
    local error_type=$2
    local -n backuped_files_list=$3
    local -n backuped_files_sizes_list=$4

    local status_backup_files

    local content
    local files_inc_line_p1
    local files_inc_line_p2
    local files_inc_line_p3
    local files_inc_line_p4
    local files_inc_line_p5
    local bk_fl_size

    # Log
    #printf 'backuped_files_list: %q\n' "${backuped_files_list[@]}" >>"${LOG}"
    #printf 'backuped_files_sizes_list: %q\n' "${backuped_files_sizes_list[@]}" >>"${LOG}"
    #log_event "debug" "error_msg=$error_msg" "false"
    #log_event "debug" "error_type=$error_type" "false"

    # TODO: config support
    local email_template="default"

    if [[ ${error_msg} != "" ]]; then

        status_backup_files="ERROR"
        status_icon_f="⛔"
        content="<b>Files backup error: ${error_type}<br />Please check log file.</b> <br />"

    else

        status_backup_files="OK"
        status_icon_f="✅"
        content=""
        files_inc=""

        count=0

        for backup_file in "${backuped_files_list[@]}"; do

            # Remove spaces from string
            backup_file="$(string_remove_spaces "${backup_file}")"

            bk_fl_size="${backuped_files_sizes_list[$count]}"

            # HTML lines
            files_inc_line_p1="<div class=\"backup-details-line\">"
            files_inc_line_p2="<span style=\"margin-right:5px;\">${backup_file}</span>"
            files_inc_line_p3="<span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">${bk_fl_size}</span>"
            files_inc_line_p4="</div>"
            files_inc_line_p5="${files_inc}"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_end="</div>"

        if [[ ${DUP_BK} == true ]]; then
            DBK_SIZE="$(du -hs "${DUP_ROOT}" | cut -f1)"
            dbk_size_label="Duplicity Backup size: <b>${DBK_SIZE}</b><br /><b>Duplicity Backup includes:</b><br />${DUP_FOLDERS}"

        fi

        # Final HTML section
        content="${files_inc}${files_label_end}${dbk_size_label}"

    fi

    mail_backup_files_html="$(cat "${SFOLDER}/templates/emails/${email_template}/backup_files-tpl.html")"

    mail_backup_files_html="$(echo "${mail_backup_files_html}" | sed -e 's|{{files_backup_status}}|'"${status_backup_files}"'|g')"
    mail_backup_files_html="$(echo "${mail_backup_files_html}" | sed -e 's|{{files_backup_status_icon}}|'"${status_icon_f}"'|g')"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_backup_files_html="$(echo "${mail_backup_files_html}" | sed -e 's|{{files_backup_list}}|'"${content}"'|g')"

    # Write e-mail parts files
    echo "${mail_backup_files_html}" >"${TMP_DIR}/file-bk-${NOW}.mail"

}

function mail_config_backup_section() {

    local error_msg=$1
    local error_type=$2
    local -n backuped_config_list=$3
    local -n backuped_config_sizes_list=$4

    local count
    local status_icon_f
    local content
    local body
    local count files_inc
    local files_inc_line_p1
    local files_inc_line_p2
    local files_inc_line_p3
    local files_inc_line_p4
    local files_inc_line_p5
    local bk_scf_size

    # TODO: config support
    local email_template="default"

    if [[ ${error_msg} != "" ]]; then

        status_backup_files='ERROR'
        status_icon_f="⛔"
        content="<b>Config backup error:<br />${error_msg}<br />Please check log file for more information.</b><br />"

    else

        status_backup_files="OK"
        status_icon_f="✅"
        content=""
        files_inc=""

        count=0

        for backup_line in "${backuped_config_list[@]}"; do

            bk_scf_size="${backuped_config_sizes_list[$count]}"

            files_inc_line_p1="<div class=\"backup-details-line\">"
            files_inc_line_p2="<span style=\"margin-right:5px;\">${backup_line}</span>"
            files_inc_line_p3="<span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">${bk_scf_size}</span>"
            files_inc_line_p4="</div>"
            files_inc_line_p5="${files_inc}"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_end="</div>"

        content="${files_inc}${files_label_end}"

    fi

    mail_backup_configs_html="$(cat "${SFOLDER}/templates/emails/${email_template}/backup_configs-tpl.html")"

    mail_backup_configs_html="$(echo "${mail_backup_configs_html}" | sed -e 's|{{configs_backup_status}}|'"${status_backup_files}"'|g')"
    mail_backup_configs_html="$(echo "${mail_backup_configs_html}" | sed -e 's|{{configs_backup_status_icon}}|'"${status_icon_f}"'|g')"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_backup_configs_html="$(echo "${mail_backup_configs_html}" | sed -e 's|{{configs_backup_list}}|'"${content}"'|g')"

    # Write e-mail parts files
    echo "${mail_backup_configs_html}" >"${TMP_DIR}/config-bk-${NOW}.mail"

}

function mail_databases_backup_section() {

    local error_msg=$1
    local error_type=$2
    local -n backuped_databases_list=$3
    local -n backuped_databases_sizes_list=$4

    local count
    local bk_db_size

    local backup_status
    local status_icon

    # TODO: config support
    local email_template="default"

    log_event "debug" "Preparing mail databases backup section ..." "false"

    #printf 'backuped_databases_list: %q\n' "${backuped_databases_list[@]}" >>"${LOG}"
    #printf 'backuped_databases_sizes_list: %q\n' "${backuped_databases_sizes_list[@]}" >>"${LOG}"
    #log_event "debug" "error_msg=$error_msg" "false"
    #log_event "debug" "error_type=$error_type" "false"

    if [[ ${error_msg} != "" ]]; then

        backup_status="ERROR"
        status_icon="⛔"
        content="<b>Database backup with errors:<br />${error_type}<br /><br />Please check log file.</b> <br />"

    else

        backup_status="OK"
        status_icon="✅"
        content=""
        files_inc=""

        count=0

        for backup_file in "${backuped_databases_list[@]}"; do

            bk_db_size=${backuped_databases_sizes_list[$count]}

            files_inc_line_p1="<div class=\"backup-details-line\">"
            files_inc_line_p2="<span style=\"margin-right:5px;\">${backup_file}</span>"
            files_inc_line_p3="<span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">${bk_db_size}</span>"
            files_inc_line_p4="</div>"
            files_inc_line_p5="${files_inc}"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_d_end="</div>"

        content="${files_inc}${files_label_d_end}"

    fi

    mail_backup_databases_html="$(cat "${SFOLDER}/templates/emails/${email_template}/backup_databases-tpl.html")"

    mail_backup_databases_html="$(echo "${mail_backup_databases_html}" | sed -e 's|{{databases_backup_status}}|'"${backup_status}"'|g')"
    mail_backup_databases_html="$(echo "${mail_backup_databases_html}" | sed -e 's|{{databases_backup_status_icon}}|'"${status_icon}"'|g')"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_backup_databases_html="$(echo "${mail_backup_databases_html}" | sed -e 's|{{databases_backup_list}}|'"${content}"'|g')"

    # Write e-mail parts files
    echo "${mail_backup_databases_html}" >"${TMP_DIR}/db-bk-${NOW}.mail"

}

function mail_footer() {

    # $1 = ${SCRIPT_V}

    local script_v=$1

    local mail_footer

    local email_template="default"

    html_footer="$(cat "${SFOLDER}/templates/emails/${email_template}/footer-tpl.html")"

    # Ref: https://stackoverflow.com/questions/7189604/replacing-html-tag-content-using-sed/7189726
    mail_footer="$(echo "${html_footer}" | sed -e 's|{{brolit_version}}|'"${script_v}"'|g')"

    # Write e-mail parts files
    echo "${mail_footer}" >"${TMP_DIR}/footer-${NOW}.mail"

}

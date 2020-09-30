#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.4
################################################################################

send_mail_notification() {

    # $1 = ${email_subject}
    # $2 = ${email_content}

    local email_subject=$1
    local email_content=$2

    log_event "debug" "Running: sendEmail -f ${SMTP_U} -t ${MAILA} -u ${email_subject} -o message-content-type=html -m ${EMAIL_CONTENT} -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P}" "false"

    # We could use -l "/var/log/sendemail.log" for custom log file
    sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${email_subject}" -o message-content-type=html -m "${email_content}" -s "${SMTP_SERVER}:${SMTP_PORT}" -o tls="${SMTP_TLS}" -xu "${SMTP_U}" -xp "${SMTP_P}" 1>&2

}

mail_subject_status() {

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

    if [[ "${status_d}" == *"ERROR"* ]] || [[ "${status_f}" == *"ERROR"* ]] || [[ "${status_s}" == *"ERROR"* ]] || [[ "${status_c}" == *"ERROR"* ]]; then
        status="⛔ ERROR"

    else
        if [[ "${outdated}" = true ]]; then
            status="⚠ WARNING"

        else
            status="✅ OK"

        fi
    fi

    # Return
    echo "${status}"

}

remove_mail_notifications_files() {

    log_event "info" "Removing notifications temp files ..." "false"

    # Remove one per line only for better readibility
    rm -f "${BAKWP}/cert-${NOW}.mail" 
    rm -f "${BAKWP}/pkg-${NOW}.mail"
    rm -f "${BAKWP}/file-bk-${NOW}.mail"
    rm -f "${BAKWP}/config-bk-${NOW}.mail"
    rm -f "${BAKWP}/db-bk-${NOW}.mail"

    log_event "info" "Temp files removed" "false"

}

mail_server_status_section() {

    # $1 = ${IP}
    # $2 = ${disk_u}

    local IP=$1

    declare -g STATUS_SERVER     # Global to check section status

    local disk_u 
    local disk_u_ns
    local status_s_icon
    local status_s_color
    local header_open1
    local header_open2
    local header_open3
    local header_text
    local header_close
    local body_open
    local content
    local body_close
    local srv_body
    local body

    ### Disk Usage
    disk_u=$(calculate_disk_usage "${MAIN_VOL}")

    # Extract % to compare
    disk_u_ns=$(echo "${disk_u}" | cut -f1 -d'%')

    # Cast to int
    casted_disk_u_ns=$(int(){ printf '%d' "${disk_u_ns:-}" 2>/dev/null || :; })

    if [[ "${casted_disk_u_ns}" -gt 45 ]]; then
        # Changing global
        STATUS_SERVER="WARNING"

        # Changing locals
        status_s_icon="⚠"
        status_s_color="#fb2f2f"

    else
        # Changing global
        STATUS_SERVER="OK"

        # Changing locals
        status_s_icon="✅"
        status_s_color="#503fe0"
        
    fi

    header_open1="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:"
    header_open2="${status_s_color}"
    header_open3=";padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_text="Server Status: ${STATUS_SERVER} ${status_s_icon}"
    header_close="</div>"
    header="${header_open1}${header_open2}${header_open3}${header_text}${header_close}"

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;\">"
    content="<b>Server IP: ${IP}</b><br /><b>Disk usage: ${disk_u}</b><br />"
    body_close="</div></div>"
    srv_body="${body_open}${content}${body_close}"

    body="${header}${srv_body}"

    # Return
    echo "${body}"

}

mail_package_status_section() {

    local pkg_details
    local pkg_color
    local pkg_status
    local pkg_status_icon
    local pkg_header
    local header_open
    local header_open1
    local header_open2
    local body_open
    local body_close
    local pkg_body

    # Check for important packages updates
    pkg_details=$(mail_package_section "${PACKAGES[@]}") # ${PACKAGES[@]} is a Global array with packages names

    #if not empty, system is outdated
    if [ "${pkg_details}" != "" ]; then
        
        OUTDATED_PACKAGES=true

        pkg_color="#b51c1c"
        pkg_status="OUTDATED_PACKAGES"
        pkg_status_icon="⚠"
    else
        pkg_color='#503fe0'
        pkg_status="OK"
        pkg_status_icon="✅"

    fi

    header_open1="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:"
    header_open2=";padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_open="${header_open1}${pkg_color}${header_open2}"
    header_text="Packages Status: ${pkg_status} ${pkg_status_icon}"
    header_close="</div>"

    body_open="$(mail_section_start)"
    pkg_details="<div>${pkg_details}</div>"
    body_close="$(mail_section_end)"

    pkg_header="${header_open}${header_text}${header_close}"
    pkg_body="${pkg_header}${body_open}${pkg_details}${body_close}"

    # Write e-mail parts files
    echo "${pkg_body}" >"${BAKWP}/pkg-${NOW}.mail"

}

mail_package_section() {

    # $1 = ${PACKAGES}

    local -n PACKAGES=$1

    local package 
    local package_version_installed 
    local package_version_candidate

    for package in "${PACKAGES[@]}"; do

        package_version_installed="$(apt-cache policy "${package}" | grep Installed | cut -d ':' -f 2)"
        if [ "${package_version_installed}" = "(none)" ] && [ "${package}" = "mysql-server" ];then
            package="mariadb-server"
            package_version_installed="$(apt-cache policy "${package}" | grep Installed | cut -d ':' -f 2)"
        fi

        package_version_candidate=$(apt-cache policy "${package}" | grep Candidate | cut -d ':' -f 2)

        if [ "${package_version_installed}" != "${package_version_candidate}" ]; then

            # Return
            echo "<div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">${package} ${package_version_installed} -> ${package_version_candidate}</div>"

        fi

    done

}

mail_cert_section() {

    local domain
    local all_sites
    local cert_days
    local email_cert_line
    local email_cert_new_line
    local email_cert_header_open
    local email_cert_header_text
    local email_cert_header_close
    local header_open1
    local header_open2
    local cert_status_icon

    # Changing global
    declare -g STATUS_CERTS="OK"

    # Changing locals
    cert_status_icon="✅"        
    cert_status_color="#503fe0"
    files_label="<b>Sites certificate expiration days:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
    email_cert_line=""

    # This fix avoid getting the first parent directory, maybe we could find a better solution
    k="skip"

    all_sites=$(get_all_directories "${SITES}")

    for site in ${all_sites}; do

        if [ "${k}" != "skip" ]; then

            domain=$(basename "${site}")

            # Check blacklist ${SITES_BL}
            if [[ "${SITES_BL}" != *"${domain}"* ]]; then

                log_event "info" "Getting certificate info for: ${domain}" "false"

                BK_FL_ARRAY_INDEX=$((BK_FL_ARRAY_INDEX + 1))

                email_cert_new_line="<div style=\"float:left;width:100%\">"
                email_cert_domain="<div>${domain}"
                
                cert_days=$(certbot_certificate_valid_days "${domain}")
                
                if [ "${cert_days}" == "" ]; then
                    # GREY LABEL
                    email_cert_days_container=" <span style=\"color:white;background-color:#5d5d5d;border-radius:12px;padding:0 5px 0 5px;\">"
                    email_cert_days="${email_cert_days_container} no certificate"
                    cert_status_icon="⚠️"
                    cert_status_color="red"
                    STATUS_CERTS="Warning"
                
                else #certificate found

                    if (( "${cert_days}" >= 14 )); then
                        # GREEN LABEL
                        email_cert_days_container=" <span style=\"color:white;background-color:#27b50d;border-radius:12px;padding:0 5px 0 5px;\">"
                    else
                        if (( "${cert_days}" >= 7 )); then
                            # ORANGE LABEL
                            email_cert_days_container=" <span style=\"color:white;background-color:#df761d;border-radius:12px;padding:0 5px 0 5px;\">"
                        else
                            # RED LABEL
                            email_cert_days_container=" <span style=\"color:white;background-color:#df1d1d;border-radius:12px;padding:0 5px 0 5px;\">"
                            cert_status_icon="⚠️"
                            cert_status_color="red"
                            STATUS_CERTS="Warning"
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

    files_label_end="</div>"

    header_open1="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:white;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:"
    header_open2=";padding:5px 0 10px 10px;width:100%;height:30px\">"
    email_cert_header_open="${header_open1}${cert_status_color}${header_open2}"
    email_cert_header_text="Certificates on server: ${STATUS_CERTS} ${cert_status_icon}"
    email_cert_header_close="</div>"

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;\">"
    body_close="</div></div>"

    header="${email_cert_header_open}${email_cert_header_text}${email_cert_header_close}"
    body="${body_open}${files_label}${email_cert_line}${files_label_end}${body_close}"
    #body="${body_open}${CONTENT}${files_label}${email_cert_line}${files_label_end}${body_close}"

    # Write e-mail parts files
    echo "${header}" >"${BAKWP}/cert-${NOW}.mail"
    echo "${body}" >>"${BAKWP}/cert-${NOW}.mail"

}

mail_filesbackup_section() {

    # $1 = ${BACKUPED_LIST[@]}
    # $2 = ${BK_FL_SIZES}
    # $3 = ${ERROR}
    # $4 = ${ERROR_TYPE}

    local -n BACKUPED_LIST=$1
    local -n BK_FL_SIZES=$2
    local ERROR=$3
    local ERROR_TYPE=$4

    declare -g STATUS_BACKUP_FILES

    local header
    local body
    local header_open1
    local header_open2
    local header_open
    local header_text
    local header_close
    local body_open
    local body_close

    local backup_type

    backup_type='Files'

    if [ "$ERROR" = true ]; then

        # Changing global
        STATUS_BACKUP_FILES="ERROR"

        # Changing locals
        status_icon_f="💩"        
        content="<b>${backup_type} Backup Error: ${ERROR_TYPE}<br />Please check log file.</b> <br />"
        COLOR="red"

    else

        # Changing global
        STATUS_BACKUP_FILES="OK"

        # Changing locals
        status_icon_f="✅"
        content=""
        COLOR="#503fe0"
        SIZE_LABEL=""
        files_label="<b>Backup files includes:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
        FILES_INC=""

        count=0

        for backup_file in "${BACKUPED_LIST[@]}"; do
                     
            BK_FL_SIZE="${BK_FL_SIZES[$count]}"

            FILES_INC_LINE_P1="<div><span style=\"margin-right:5px;\">"
            FILES_INC_LINE_P2="${FILES_INC}${backup_file}"
            FILES_INC_LINE_P3="</span> <span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">"
            FILES_INC_LINE_P4="${BK_FL_SIZE}"
            FILES_INC_LINE_P5="</span></div>"

            FILES_INC="${FILES_INC_LINE_P1}${FILES_INC_LINE_P2}${FILES_INC_LINE_P3}${FILES_INC_LINE_P4}${FILES_INC_LINE_P5}"

            count=$((count + 1))

        done

        files_label_end="</div>"

        if [ "${DUP_BK}" = true ]; then
            DBK_SIZE=$(du -hs "${DUP_ROOT}" | cut -f1)
            DBK_SIZE_LABEL="Duplicity Backup size: <b>${DBK_SIZE}</b><br /><b>Duplicity Backup includes:</b><br />${DUP_FOLDERS}"

        fi

    fi

    # Header
    header_open1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    header_open2=';padding:5px 0 10px 10px;width:100%;height:30px">'
    header_open="${header_open1}${COLOR}${header_open2}"
    header_text="Files Backup: ${STATUS_BACKUP_FILES} ${status_icon_f}"
    header_close="</div>"

    # Body
    body_open='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
    body_close="</div></div>"

    #MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

    header="${header_open}${header_text}${header_close}"
    body="${body_open}${content}${SIZE_LABEL}${files_label}${FILES_INC}${files_label_end}${DBK_SIZE_LABEL}${body_close}"
    #footer="${FOOTEROPEN}${SCRIPTSTRING}${FOOTERCLOSE}"

    # Write e-mail parts files
    echo "${header}" >"${BAKWP}/file-bk-${NOW}.mail"
    echo "${body}" >>"${BAKWP}/file-bk-${NOW}.mail"
    #echo "${footer}" >>"${BAKWP}/file-bk-${NOW}.mail"

}

mail_configbackup_section() {

    # $1 = ${BACKUPED_SCF_LIST[@]}
    # $2 = ${BK_FL_SIZES}
    # $3 = ${ERROR}
    # $4 = ${ERROR_TYPE}

    local -n BACKUPED_SCF_LIST=$1
    local -n BK_SCF_SIZES=$2
    local ERROR=$3
    local ERROR_TYPE=$4

    local count
    local status_icon_f
    local content
    local color
    local header
    local body
    local count files_inc 
    local files_inc_line_p1 
    local files_inc_line_p2 
    local files_inc_line_p3 
    local files_inc_line_p4 
    local files_inc_line_p5 
    local bk_scf_size
    local header_open1
    local header_open2
    local header_open

    local backup_type

    backup_type="Config"

    if [ "${ERROR}" = true ]; then

        # Changing global
        STATUS_BACKUP_FILES='ERROR'

        # Changing locals
        status_icon_f="💩"        
        content="<b>${backup_type} Backup Error: ${ERROR_TYPE}<br />Please check log file.</b> <br />"
        color="red"

    else

        # Changing global
        STATUS_BACKUP_FILES="OK"

        # Changing locals
        status_icon_f="✅"
        content=""
        color="#503fe0"
        SIZE_LABEL=""
        files_label="<b>Backup files includes:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
        files_inc=""

        count=0

        for backup_line in "${BACKUPED_SCF_LIST[@]}"; do
                     
            bk_scf_size="${BK_SCF_SIZES[$count]}"

            files_inc_line_p1="<div><span style=\"margin-right:5px;\">"
            files_inc_line_p2="${files_inc}${backup_line}"
            files_inc_line_p3="</span><span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">"
            files_inc_line_p4="${bk_scf_size}"
            files_inc_line_p5="</span></div>"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_end="</div>"

    fi

    header_open1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    header_open2=';padding:5px 0 10px 10px;width:100%;height:30px">'
    header_open="${header_open1}${color}${header_open2}"
    header_text="Config Backup: ${STATUS_BACKUP_FILES} ${status_icon_f}"
    header_close="</div>"

    body_open='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
    body_close="</div></div>"

    #MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

    header="${header_open}${header_text}${header_close}"
    body="${body_open}${content}${SIZE_LABEL}${files_label}${files_inc}${files_label_end}${DBK_SIZE_LABEL}${body_close}"
    #FOOTER="${FOOTEROPEN}${SCRIPTSTRING}${FOOTERCLOSE}"

    # Write e-mail parts files
    echo "${header}" >"${BAKWP}/config-bk-${NOW}.mail"
    echo "${body}" >>"${BAKWP}/config-bk-${NOW}.mail"
    #echo "${FOOTER}" >>"${BAKWP}/config-bk-${NOW}.mail"

}

mail_mysqlbackup_section() {

    # $1 = ${BACKUPED_DB_LIST}
    # $2 = ${BK_DB_SIZES}
    # $3 = ${ERROR}
    # $4 = ${ERROR_TYPE}

    local -n BACKUPED_DB_LIST=$1
    local -n BK_DB_SIZES=$2
    local ERROR=$3
    local ERROR_TYPE=$4

    local count
    local bk_db_size
    local status_icon
    local header_open1
    local header_open2
    local header_open
    local header_text
    local header_close
    local body_open
    local body_close

    local backup_type

    declare -g STATUS_BACKUP_DBS

    backup_type="Database"

    if [ "${ERROR}" = true ]; then
        # Changing global
        STATUS_BACKUP_DBS="ERROR"

        # Changing locals
        status_icon="💩"
        content="<b>${backup_type} Backup with errors:<br />${ERROR_TYPE}<br /><br />Please check log file.</b> <br />"
        color="#b51c1c"

    else
        # Changing global
        STATUS_BACKUP_DBS="OK"

        # Changing locals
        status_icon="✅"
        content=""
        color="#503fe0"
        SIZE_D=""
        files_label_D="<b>Backup files includes:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
        files_inc=""

        count=0

        for backup_file in "${BACKUPED_DB_LIST[@]}"; do

            bk_db_size="${BK_DB_SIZES[$count]}"

            files_inc_line_p1="<div><span style=\"margin-right:5px;\">"
            files_inc_line_p2="${files_inc}${backup_file}"
            files_inc_line_p3="</span> <span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">"
            files_inc_line_p4="${bk_db_size}"
            files_inc_line_p5="</span></div>"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_D_END="</div>"

    fi

    header_open1="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:"
    header_open2=";padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_open="${header_open1}${color}${header_open2}"
    header_text="Database Backup: ${STATUS_BACKUP_DBS} ${status_icon}"
    header_close="</div>"

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;\">"
    body_close="</div>"

    header="${header_open}${header_text}${header_close}"
    body="${body_open}${content}${SIZE_D}${files_label_D}${files_inc}${files_label_D_END}${body_close}"

    # Write e-mail parts files
    echo "${header}" >"${BAKWP}/db-bk-${NOW}.mail"
    echo "${body}" >>"${BAKWP}/db-bk-${NOW}.mail"

}

mail_section_start() {

    local body_open

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;\">"

    # Return
    echo "${body_open}"

}

mail_section_end() {

    local body_close

    body_close="</div>"

    # Return
    echo "${body_close}"

}

mail_footer() {

    # $1 = ${SCRIPT_V}

    local script_v=$1

    local footer_open
    local script_string
    local footer_close
    local html_close
    local mail_footer

    footer_open="<div style=\"font-size:10px;float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px\"><a href=\"https://www.broobe.com/web-mobile-development/?utm_source=linux-script&utm_medium=email&utm_campaign=landing_it\" style=\"color: #503fe0;font-weight: bold;font-style: italic;\">"
    script_string="LEMP UTILS SCRIPT Version: ${script_v} by BROOBE"
    footer_close="</a></div></div>"

    html_close="$(mail_html_end)"

    mail_footer="${footer_open}${script_string}${footer_close}${html_close}"

    # Return
    echo "${mail_footer}"

}

mail_html_start() {

    local html_open

    html_open="<html><body>"

    # Return
    echo "${html_open}"

}

mail_html_end() {

    local html_close

    html_close="</body></html>"

    # Return
    echo "${html_close}"

}

#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.16
################################################################################

function send_mail_notification() {

    # $1 = ${email_subject} // Email's subject
    # $2 = ${email_content} // Email's content

    local email_subject=$1
    local email_content=$2

    log_event "debug" "Running: sendEmail -f ${SMTP_U} -t ${MAILA} -u ${email_subject} -o message-content-type=html -m ${EMAIL_CONTENT} -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P}"

    # We could use -l "/var/log/sendemail.log" for custom log file
    sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${email_subject}" -o message-content-type=html -m "${email_content}" -s "${SMTP_SERVER}:${SMTP_PORT}" -o tls="${SMTP_TLS}" -xu "${SMTP_U}" -xp "${SMTP_P}" 1>&2

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

    if [[ "${status_d}" == *"ERROR"* ]] || [[ "${status_f}" == *"ERROR"* ]] || [[ "${status_s}" == *"ERROR"* ]] || [[ "${status_c}" == *"ERROR"* ]]; then
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
    rm -f "${TMP_DIR}/cert-${NOW}.mail" 
    rm -f "${TMP_DIR}/pkg-${NOW}.mail"
    rm -f "${TMP_DIR}/file-bk-${NOW}.mail"
    rm -f "${TMP_DIR}/config-bk-${NOW}.mail"
    rm -f "${TMP_DIR}/db-bk-${NOW}.mail"

    log_event "info" "Email temporary files removed!"

}

function mail_server_status_section() {

    # $1 = ${IP}        // Server's IP
    # $2 = ${disk_u}    // Server's disk utilization

    local IP=$1

    declare -g STATUS_SERVER     # Global to check section status

    local disk_u 
    local disk_u_ns
    local status_s_icon
    local status_s_color
    local header_open
    local header_text
    local header_close
    local body_open
    local content
    local body_close
    local srv_header
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

    header_open="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:${status_s_color};padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_text="Server Status: ${STATUS_SERVER} ${status_s_icon}"
    header_close="</div>"
    srv_header="${header_open}${header_text}${header_close}"

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;\">"
    body_content="<b>Server IP: ${IP}</b><br /><b>Disk usage: ${disk_u}</b><br />"
    body_close="</div></div>"
    srv_body="${body_open}${body_content}${body_close}"

    body="${srv_header}${srv_body}"

    # Return
    echo "${body}"

}

function mail_package_status_section() {

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
    if [[ ${pkg_details} != "" ]]; then
        # Changing global
        OUTDATED_PACKAGES=true

        pkg_color="#b51c1c"
        pkg_status="OUTDATED_PACKAGES"
        pkg_status_icon="⚠"
    else
        pkg_color='#503fe0'
        pkg_status="OK"
        pkg_status_icon="✅"

    fi

    header_open="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:${pkg_color};padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_text="Packages Status: ${pkg_status} ${pkg_status_icon}"
    header_close="</div>"

    body_open="$(mail_section_start)"
    pkg_details="<div>${pkg_details}</div>"
    body_close="$(mail_section_end)"

    pkg_header="${header_open}${header_text}${header_close}"
    pkg_body="${pkg_header}${body_open}${pkg_details}${body_close}"

    # Write e-mail parts files
    echo "${pkg_body}" >"${TMP_DIR}/pkg-${NOW}.mail"

}

function mail_package_section() {

    # $1 = ${PACKAGES} // Packages to be updated

    local -n PACKAGES=$1

    local package 
    local package_version_installed 
    local package_version_candidate

    for package in "${PACKAGES[@]}"; do

        package_version_installed="$(apt-cache policy "${package}" | grep Installed | cut -d ':' -f 2)"
        if [[ ${package_version_installed} = "(none)" ]] && [[ ${package} = "mysql-server" ]];then
            package="mariadb-server"
            package_version_installed="$(apt-cache policy "${package}" | grep Installed | cut -d ':' -f 2)"
        fi

        package_version_candidate=$(apt-cache policy "${package}" | grep Candidate | cut -d ':' -f 2)

        if [[ "${package_version_installed}" != "${package_version_candidate}" ]]; then

            # Return
            echo "<div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">${package} ${package_version_installed} -> ${package_version_candidate}</div>"

        fi

    done

}

function mail_cert_section() {

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
    local cert_status_color
    local files_label

    # Changing global
    declare -g STATUS_CERTS="OK"

    # Changing locals
    cert_status_icon="✅"        
    cert_status_color="#503fe0"
    files_label="<b>Sites certificate expiration days:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
    email_cert_line=""

    # This fix avoid getting the first parent directory, maybe we could find a better solution
    local k="skip"

    all_sites=$(get_all_directories "${SITES}")

    for site in ${all_sites}; do

        if [ "${k}" != "skip" ]; then

            domain=$(basename "${site}")

            # Check blacklist ${SITES_BL}
            if [[ "${SITES_BL}" != *"${domain}"* ]]; then

                log_event "info" "Getting certificate info for: ${domain}" "false"

                # Change global
                BK_FL_ARRAY_INDEX=$((BK_FL_ARRAY_INDEX + 1))

                email_cert_new_line="<div style=\"float:left;width:100%\">"
                email_cert_domain="<div>${domain}"
                
                cert_days=$(certbot_certificate_valid_days "${domain}")
                
                if [[ ${cert_days} == "" ]]; then
                    # GREY LABEL
                    email_cert_days_container=" <span style=\"color:white;background-color:#5d5d5d;border-radius:12px;padding:0 5px 0 5px;\">"
                    email_cert_days="${email_cert_days_container} no certificate"
                    cert_status_icon="⚠️"
                    cert_status_color="red"
                    STATUS_CERTS="WARNING"
                
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
    echo "${header}" >"${TMP_DIR}/cert-${NOW}.mail"
    echo "${body}" >>"${TMP_DIR}/cert-${NOW}.mail"

}

function mail_filesbackup_section() {

    # $1 = ${ERROR}
    # $2 = ${ERROR_TYPE}

    # Global array ${BACKUPED_LIST[@]}
    # Global array ${BK_FL_SIZES[@]}

    local ERROR=$1
    local ERROR_TYPE=$2

    declare -g STATUS_BACKUP_FILES

    local backup_type
    local color
    local content
    local header
    local body
    local header_open1
    local header_open2
    local header_open
    local header_text
    local header_close
    local body_open
    local body_close
    local files_inc_line_p1
    local files_inc_line_p2
    local files_inc_line_p3
    local files_inc_line_p4
    local files_inc_line_p5
    local bk_fl_size

    backup_type='Files'

    if [[ ${ERROR} = true ]]; then

        # Changing global
        STATUS_BACKUP_FILES="ERROR"

        # Changing locals
        status_icon_f="⛔"        
        content="<b>${backup_type} Backup Error: ${ERROR_TYPE}<br />Please check log file.</b> <br />"
        color="red"

    else

        # Changing global
        STATUS_BACKUP_FILES="OK"

        # Changing locals
        status_icon_f="✅"
        content=""
        color="#503fe0"
        size_label=""
        files_label="<b>Backup files includes:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
        files_inc=""

        count=0

        for backup_file in "${BACKUPED_LIST[@]}"; do
                     
            bk_fl_size="${BK_FL_SIZES[$count]}"

            files_inc_line_p1="<div class=\"backup-details-line\">"
            files_inc_line_p2="<span style=\"margin-right:5px;\">${backup_file}</span>"
            files_inc_line_p3="<span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">${bk_fl_size}</span>"
            files_inc_line_p4="</div>"
            files_inc_line_p5="${files_inc}"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_end="</div>"

        if [[ "${DUP_BK}" = true ]]; then
            DBK_SIZE=$(du -hs "${DUP_ROOT}" | cut -f1)
            dbk_size_label="Duplicity Backup size: <b>${DBK_SIZE}</b><br /><b>Duplicity Backup includes:</b><br />${DUP_FOLDERS}"

        fi

    fi

    # Header
    header_open1="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:"
    header_open2=";padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_open="${header_open1}${color}${header_open2}"
    header_text="Files Backup: ${STATUS_BACKUP_FILES} ${status_icon_f}"
    header_close="</div>"

    # Body
    body_open='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
    body_close="</div></div>"

    #MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

    header="${header_open}${header_text}${header_close}"
    body="${body_open}${content}${size_label}${files_label}${files_inc}${files_label_end}${dbk_size_label}${body_close}"
    #footer="${FOOTEROPEN}${SCRIPTSTRING}${FOOTERCLOSE}"

    # Write e-mail parts files
    echo "${header}" >"${TMP_DIR}/file-bk-${NOW}.mail"
    echo "${body}" >>"${TMP_DIR}/file-bk-${NOW}.mail"
    #echo "${footer}" >>"${TMP_DIR}/file-bk-${NOW}.mail"

}

function mail_config_backup_section() {

    # $1 = ${ERROR}
    # $2 = ${ERROR_TYPE}

    # Global array ${BACKUPED_SCF_LIST[@]}
    # Global array ${BK_SCF_SIZES}

    local ERROR=$1
    local ERROR_TYPE=$2

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
        status_icon_f="⛔"        
        content="<b>${backup_type} Backup Error: ${ERROR_TYPE}<br />Please check log file.</b> <br />"
        color="red"

    else

        # Changing global
        STATUS_BACKUP_FILES="OK"

        # Changing locals
        status_icon_f="✅"
        content=""
        color="#503fe0"
        size_label=""
        files_label="<b>Backup files includes:</b><br /><div style=\"color:#000;font-size:12px;line-height:24px;padding-left:10px;\">"
        files_inc=""

        count=0

        for backup_line in "${BACKUPED_SCF_LIST[@]}"; do
                     
            bk_scf_size="${BK_SCF_SIZES[$count]}"

            files_inc_line_p1="<div class=\"backup-details-line\">"
            files_inc_line_p2="<span style=\"margin-right:5px;\">${backup_line}</span>"
            files_inc_line_p3="<span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">${bk_scf_size}</span>"
            files_inc_line_p4="</div>"
            files_inc_line_p5="${files_inc}"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_end="</div>"

    fi

    header_open1="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:"
    header_open2=";padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_open="${header_open1}${color}${header_open2}"
    header_text="Config Backup: ${STATUS_BACKUP_FILES} ${status_icon_f}"
    header_close="</div>"

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;\">"
    body_close="</div></div>"

    #MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

    header="${header_open}${header_text}${header_close}"
    body="${body_open}${content}${size_label}${files_label}${files_inc}${files_label_end}${dbk_size_label}${body_close}"
    #FOOTER="${FOOTEROPEN}${SCRIPTSTRING}${FOOTERCLOSE}"

    # Write e-mail parts files
    echo "${header}" >"${TMP_DIR}/config-bk-${NOW}.mail"
    echo "${body}" >>"${TMP_DIR}/config-bk-${NOW}.mail"
    #echo "${FOOTER}" >>"${TMP_DIR}/config-bk-${NOW}.mail"

}

function mail_mysqlbackup_section() {

    # $1 = ${ERROR}
    # $2 = ${ERROR_TYPE}

    # Global array ${BACKUPED_DB_LIST}
    # Global array ${BK_DB_SIZES}

    local ERROR=$1
    local ERROR_TYPE=$2

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

    if [[ ${ERROR} = true ]]; then
        # Changing global
        STATUS_BACKUP_DBS="ERROR"

        # Changing locals
        status_icon="⛔"
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

            bk_db_size=${BK_DB_SIZES[$count]}

            files_inc_line_p1="<div class=\"backup-details-line\">"
            files_inc_line_p2="<span style=\"margin-right:5px;\">${backup_file}</span>"
            files_inc_line_p3="<span style=\"background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;\">${bk_db_size}</span>"
            files_inc_line_p4="</div>"
            files_inc_line_p5="${files_inc}"

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        files_label_d_end="</div>"

    fi

    header_open1="<div style=\"float:left;width:100%\"><div style=\"font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:"
    header_open2=";padding:5px 0 10px 10px;width:100%;height:30px\">"
    header_open="${header_open1}${color}${header_open2}"
    header_text="Database Backup: ${STATUS_BACKUP_DBS} ${status_icon}"
    header_close="</div>"

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;\">"
    body_close="</div>"

    header="${header_open}${header_text}${header_close}"
    body="${body_open}${content}${SIZE_D}${files_label_D}${files_inc}${files_label_d_end}${body_close}"

    # Write e-mail parts files
    echo "${header}" >"${TMP_DIR}/db-bk-${NOW}.mail"
    echo "${body}" >>"${TMP_DIR}/db-bk-${NOW}.mail"

}

function mail_section_start() {

    local body_open

    body_open="<div style=\"color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;\">"

    # Return
    echo "${body_open}"

}

function mail_section_end() {

    local body_close

    body_close="</div>"

    # Return
    echo "${body_close}"

}

function mail_footer() {

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

function mail_html_start() {

    local html_open

    html_open="<html><body>"

    # Return
    echo "${html_open}"

}

function mail_html_end() {

    local html_close

    html_close="</body></html>"

    # Return
    echo "${html_close}"

}

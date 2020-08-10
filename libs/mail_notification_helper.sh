#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
#source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/certbot_helper.sh
source "${SFOLDER}/libs/certbot_helper.sh"

################################################################################

send_mail_notification() {

    # $1 = ${email_subject}
    # $2 = ${email_content}

    local email_subject=$1
    local email_content=$2

    log_event "info" "Running: sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${email_subject}" -o message-content-type=html -m "${EMAIL_CONTENT}" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P}" "true"

    # We could use -l "/var/log/sendemail.log" for custom log file
    sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${email_subject}" -o message-content-type=html -m "${email_content}" -s "${SMTP_SERVER}:${SMTP_PORT}" -o tls="${SMTP_TLS}" -xu "${SMTP_U}" -xp "${SMTP_P}"

}

mail_subject_status() {

    # $1 = ${status_d} // Database backup status
    # $2 = ${status_f} // Files backup status
    # $3 = ${status_s} // Server status
    # $4 = ${outdated} // System Packages status

    local status_d=$1
    local status_f=$2
    local status_s=$3
    local outdated=$4

    local status

    if [[ "${status_d}" == *"ERROR"* ]] || [[ "${status_f}" == *"ERROR"* ]] || [[ "${status_s}" == *"ERROR"* ]]; then
        status="⛔ ERROR"
        #STATUS_ICON="⛔"
    else
        if [[ "${outdated}" = true ]]; then
            status="⚠ WARNING"
            #STATUS_ICON="⚠"
        else
            status="✅ OK"
            #STATUS_ICON="✅"
        fi
    fi

    # Return
    echo "${status}"

}

remove_mail_notifications_files() {

    log_event "info" "Removing notifications temp files ..." "true"

    # Remove one per line only for better readibility
    rm -f "${BAKWP}/cert-${NOW}.mail" 
    rm -f "${BAKWP}/pkg-${NOW}.mail"
    rm -f "${BAKWP}/file-bk-${NOW}.mail"
    rm -f "${BAKWP}/config-bk-${NOW}.mail"
    rm -f "${BAKWP}/db-bk-${NOW}.mail"

    log_event "info" "Temp files removed" "true"

}

mail_server_status_section() {

    # $1 = ${IP}
    # $2 = ${disk_u}

    local IP=$1

    local disk_u disk_u_ns

    ### Disk Usage
    disk_u=$(calculate_disk_usage "${MAIN_VOL}")

    # Extract % to compare
    disk_u_ns=$(echo "${disk_u}" | cut -f1 -d'%')

    if [ "${disk_u_ns}" -gt "45" ]; then
        # Changing global
        STATUS_S='WARNING'

        # Changing locals
        STATUS_S_ICON="⚠"
        STATUS_S_COLOR='#fb2f2f'

    else
        # Changing global
        STATUS_S='OK'

        # Changing locals
        STATUS_S_ICON="✅"
        STATUS_S_COLOR='#503fe0'
        
    fi

    SRV_HEADEROPEN_1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    SRV_HEADEROPEN_2=${STATUS_S_COLOR}
    SRV_HEADEROPEN_3=';padding:5px 0 10px 10px;width:100%;height:30px">'
    SRV_HEADERTEXT="Server Status: ${STATUS_S} ${STATUS_S_ICON}"
    SRV_HEADERCLOSE='</div>'
    SRV_HEADER=${SRV_HEADEROPEN_1}${SRV_HEADEROPEN_2}${SRV_HEADEROPEN_3}${SRV_HEADERTEXT}${SRV_HEADERCLOSE}

    SRV_BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
    SRV_CONTENT="<b>Server IP: ${IP}</b><br /><b>Disk usage: ${disk_u}</b><br />"
    SRV_BODYCLOSE='</div></div>'
    SRV_BODY=${SRV_BODYOPEN}${SRV_CONTENT}${SRV_BODYCLOSE}

    BODY_SRV=${SRV_HEADER}${SRV_BODY}

    # Return
    echo "${BODY_SRV}"

}

mail_package_status_section() {

    local pkg_details

    # Check for important packages updates
    pkg_details=$(mail_package_section "${PACKAGES[@]}") # ${PACKAGES[@]} is a Global array with packages names

    #if not empty, system is outdated
    if [ "${pkg_details}" != "" ]; then
        
        OUTDATED=true

        PKG_COLOR='#b51c1c'
        PKG_STATUS='OUTDATED'
        PKG_STATUS_ICON="⚠"
    else
        PKG_COLOR='#503fe0'
        PKG_STATUS='OK'
        PKG_STATUS_ICON="✅"
    fi

    PKG_HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    PKG_HEADEROPEN2=';padding:5px 0 10px 10px;width:100%;height:30px">'
    PKG_HEADEROPEN=${PKG_HEADEROPEN1}${PKG_COLOR}${PKG_HEADEROPEN2}
    PKG_HEADERTEXT="Packages Status: ${PKG_STATUS} ${PKG_STATUS_ICON}"
    PKG_HEADERCLOSE='</div>'

    PKG_BODYOPEN=$(mail_section_start)
    
    pkg_details='<div>'${pkg_details}'</div>'

    PKG_BODYCLOSE=$(mail_section_end)

    PKG_HEADER=${PKG_HEADEROPEN}${PKG_HEADERTEXT}${PKG_HEADERCLOSE}

    BODY_PKG=${PKG_HEADER}${PKG_BODYOPEN}${pkg_details}${PKG_BODYCLOSE}

    # Write e-mail parts files
    echo "${BODY_PKG}" >"${BAKWP}/pkg-${NOW}.mail"

}

mail_package_section() {

    # $1 = ${PACKAGES}

    local -n PACKAGES=$1

    for pk in "${PACKAGES[@]}"; do

        PK_VI=$(apt-cache policy "${pk}" | grep Installed | cut -d ':' -f 2)
        PK_VC=$(apt-cache policy "${pk}" | grep Candidate | cut -d ':' -f 2)

        if [ "${PK_VI}" != "${PK_VC}" ]; then

            # Return
            echo "${pk} ${PK_VI} -> ${PK_VC}"

        fi

    done

}

mail_cert_section() {

    local domain all_sites cert_days email_cert_line email_cert_new_line

#    # Changing global
#    STATUS_CERT="OK"
#
#    # Changing locals
#    STATUS_ICON_CERT="✅"        
    CONTENT=""
    COLOR='#503fe0'
    SIZE_LABEL=""
    FILES_LABEL='<b>Sites certificate expiration days:</b><br /><div style="color:#000;font-size:12px;line-height:24px;padding-left:10px;">'
    email_cert_line=""

    # This fix avoid getting the first parent directory, maybe we could find a better solution
    k="skip"

    all_sites=$(get_all_directories "${SITES}")

    for site in ${all_sites}; do

        if [ "${k}" != "skip" ]; then

            domain=$(basename "${site}")

            # Check blacklist ${SITES_BL}
            if [[ "${SITES_BL}" != *"${domain}"* ]]; then

                log_event "info" "Getting certificate info for: ${domain}" "true"

                #make_files_backup "site" "${SITES}" "${FOLDER_NAME}"
                BK_FL_ARRAY_INDEX=$((BK_FL_ARRAY_INDEX + 1))

                email_cert_new_line='<div style="float:left;width:100%">'
                email_cert_domain='<div>'"${domain}"
                
                cert_days=$(certbot_certificate_valid_days "${domain}")
                
                if [ "${cert_days}" == "" ]; then
                    # GREY LABEL
                    email_cert_days_container=' <span style="color:white;background-color:#5d5d5d;border-radius:12px;padding:0 5px 0 5px;">'
                    email_cert_days="${email_cert_days_container} no certificate"
                
                else #certificate found

                    if (( "${cert_days}" >= 14 )); then
                        # GREEN LABEL
                        email_cert_days_container=' <span style="color:white;background-color:#27b50d;border-radius:12px;padding:0 5px 0 5px;">'
                    else
                        if (( "${cert_days}" >= 7 )); then
                            # ORANGE LABEL
                            email_cert_days_container=' <span style="color:white;background-color:#df761d;border-radius:12px;padding:0 5px 0 5px;">'
                        else
                            # RED LABEL
                            email_cert_days_container=' <span style="color:white;background-color:#df1d1d;border-radius:12px;padding:0 5px 0 5px;">'
                        fi

                    fi
                    email_cert_days="${email_cert_days_container}${cert_days} days"

                fi

                email_cert_end_line="</span></div></div>"
                email_cert_line=${email_cert_line}${email_cert_new_line}${email_cert_domain}${email_cert_days}${email_cert_end_line}
            
            fi
        else
            k=""

        fi

    done

    FILES_LABEL_END='</div>'

    HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    HEADEROPEN2=';padding:5px 0 10px 10px;width:100%;height:30px">'
    email_cert_header_open="${HEADEROPEN1}${COLOR}${HEADEROPEN2}"
    email_cert_header_text="Certificates on server: ${STATUS_F} ${STATUS_ICON_F}"
    email_cert_header_close='</div>'

    BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
    BODYCLOSE='</div></div>'

    HEADER="${email_cert_header_open}${email_cert_header_text}${email_cert_header_close}"
    BODY="${BODYOPEN}${CONTENT}${FILES_LABEL}${email_cert_line}${FILES_LABEL_END}${BODYCLOSE}"

    # Write e-mail parts files
    echo "${HEADER}" >"${BAKWP}/cert-${NOW}.mail"
    echo "${BODY}" >>"${BAKWP}/cert-${NOW}.mail"

}

mail_filesbackup_section() {

    # $1 - ${BACKUPED_LIST[@]}
    # $2 - ${BK_FL_SIZES}
    # $3 - ${ERROR}
    # $4 - ${ERROR_TYPE}

    local -n BACKUPED_LIST=$1
    local -n BK_FL_SIZES=$2
    local ERROR=$3
    local ERROR_TYPE=$4

    BK_TYPE="Files"

    if [ "$ERROR" = true ]; then

        # Changing global
        STATUS_F="ERROR"

        # Changing locals
        STATUS_ICON_F="💩"        
        CONTENT="<b>${BK_TYPE} Backup Error: ${ERROR_TYPE}<br />Please check log file.</b> <br />"
        COLOR='red'

    else

        # Changing global
        STATUS_F="OK"

        # Changing locals
        STATUS_ICON_F="✅"        
        CONTENT=""
        COLOR='#503fe0'
        SIZE_LABEL=""
        FILES_LABEL='<b>Backup files includes:</b><br /><div style="color:#000;font-size:12px;line-height:24px;padding-left:10px;">'
        FILES_INC=""

        COUNT=0

        for backup_file in "${BACKUPED_LIST[@]}"; do
                     
            BK_FL_SIZE=${BK_FL_SIZES[$COUNT]}

            FILES_INC_LINE_P1='<div><span style="margin-right:5px;">'
            FILES_INC_LINE_P2="${FILES_INC}${backup_file}"
            FILES_INC_LINE_P3='</span> <span style="background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;">'
            FILES_INC_LINE_P4=${BK_FL_SIZE}
            FILES_INC_LINE_P5='</span></div>'

            FILES_INC="${FILES_INC_LINE_P1}${FILES_INC_LINE_P2}${FILES_INC_LINE_P3}${FILES_INC_LINE_P4}${FILES_INC_LINE_P5}"

            COUNT=$((COUNT + 1))

        done

        FILES_LABEL_END='</div>'

        if [ "${DUP_BK}" = true ]; then
            DBK_SIZE=$(du -hs "${DUP_ROOT}" | cut -f1)
            DBK_SIZE_LABEL="Duplicity Backup size: <b>${DBK_SIZE}</b><br /><b>Duplicity Backup includes:</b><br />${DUP_FOLDERS}"

        fi

    fi

    HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    HEADEROPEN2=';padding:5px 0 10px 10px;width:100%;height:30px">'
    HEADEROPEN=${HEADEROPEN1}${COLOR}${HEADEROPEN2}
    HEADERTEXT="Files Backup: ${STATUS_F} ${STATUS_ICON_F}"
    HEADERCLOSE='</div>'

    BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
    BODYCLOSE='</div></div>'

    #MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

    HEADER=${HEADEROPEN}${HEADERTEXT}${HEADERCLOSE}
    BODY=${BODYOPEN}${CONTENT}${SIZE_LABEL}${FILES_LABEL}${FILES_INC}${FILES_LABEL_END}${DBK_SIZE_LABEL}${BODYCLOSE}
    FOOTER=${FOOTEROPEN}${SCRIPTSTRING}${FOOTERCLOSE}

    # Write e-mail parts files
    echo "${HEADER}" >"${BAKWP}/file-bk-${NOW}.mail"
    echo "${BODY}" >>"${BAKWP}/file-bk-${NOW}.mail"
    echo "${FOOTER}" >>"${BAKWP}/file-bk-${NOW}.mail"

}

mail_configbackup_section() {

    # $1 = ${BACKUPED_LIST[@]}
    # $2 = ${BK_FL_SIZES}
    # $3 = ${ERROR}
    # $4 = ${ERROR_TYPE}

    local -n BACKUPED_SCF_LIST=$1
    local -n BK_SCF_SIZE=$2
    local ERROR=$3
    local ERROR_TYPE=$4

    local count files_inc files_inc_line_p1 files_inc_line_p2 files_inc_line_p3 files_inc_line_p4 files_inc_line_p5 bk_scf_size

    BK_TYPE="Config"

    if [ "$ERROR" = true ]; then

        # Changing global
        STATUS_F="ERROR"

        # Changing locals
        STATUS_ICON_F="💩"        
        CONTENT="<b>${BK_TYPE} Backup Error: ${ERROR_TYPE}<br />Please check log file.</b> <br />"
        COLOR='red'

    else

        # Changing global
        STATUS_F="OK"

        # Changing locals
        STATUS_ICON_F="✅"        
        CONTENT=""
        COLOR='#503fe0'
        SIZE_LABEL=""
        FILES_LABEL='<b>Backup files includes:</b><br /><div style="color:#000;font-size:12px;line-height:24px;padding-left:10px;">'
        files_inc=""

        count=0

        for backup_line in "${BACKUPED_SCF_LIST[@]}"; do
                     
            bk_scf_size=${BK_SCF_SIZES[$count]}

            files_inc_line_p1='<div><span style="margin-right:5px;">'
            files_inc_line_p2="${files_inc}${backup_line}"
            files_inc_line_p3='</span><span style="background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;">'
            files_inc_line_p4="${bk_scf_size}"
            files_inc_line_p5='</span></div>'

            files_inc="${files_inc_line_p1}${files_inc_line_p2}${files_inc_line_p3}${files_inc_line_p4}${files_inc_line_p5}"

            count=$((count + 1))

        done

        FILES_LABEL_END='</div>'

    fi

    HEADEROPEN1='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    HEADEROPEN2=';padding:5px 0 10px 10px;width:100%;height:30px">'
    HEADEROPEN=${HEADEROPEN1}${COLOR}${HEADEROPEN2}
    HEADERTEXT="Config Backup: ${STATUS_F} ${STATUS_ICON_F}"
    HEADERCLOSE='</div>'

    BODYOPEN='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px;width:100%;">'
    BODYCLOSE='</div></div>'

    #MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

    HEADER=${HEADEROPEN}${HEADERTEXT}${HEADERCLOSE}
    BODY=${BODYOPEN}${CONTENT}${SIZE_LABEL}${FILES_LABEL}${files_inc}${FILES_LABEL_END}${DBK_SIZE_LABEL}${BODYCLOSE}
    FOOTER=${FOOTEROPEN}${SCRIPTSTRING}${FOOTERCLOSE}

    # Write e-mail parts files
    echo "${HEADER}" >"${BAKWP}/config-bk-${NOW}.mail"
    echo "${BODY}" >>"${BAKWP}/config-bk-${NOW}.mail"
    echo "${FOOTER}" >>"${BAKWP}/config-bk-${NOW}.mail"

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

    BK_TYPE="Database"

    if [ "${ERROR}" = true ]; then
        # Changing global
        STATUS_D="ERROR"

        # Changing locals
        STATUS_ICON_D="💩"
        CONTENT_D="<b>${BK_TYPE} Backup with errors:<br />${ERROR_TYPE}<br /><br />Please check log file.</b> <br />"
        COLOR_D='#b51c1c'

    else
        # Changing global
        STATUS_D="OK"

        # Changing locals
        STATUS_ICON_D="✅"
        CONTENT_D=""
        COLOR_D='#503fe0'
        SIZE_D=""
        FILES_LABEL_D='<b>Backup files includes:</b><br /><div style="color:#000;font-size:12px;line-height:24px;padding-left:10px;">'
        FILES_INC_D=""

        COUNT=0

        for backup_file in "${BACKUPED_DB_LIST[@]}"; do

            BK_DB_SIZE=${BK_DB_SIZES[$COUNT]}

            FILES_INC_D_LINE_P1='<div><span style="margin-right:5px;">'
            FILES_INC_D_LINE_P2="${FILES_INC_D}${backup_file}"
            FILES_INC_D_LINE_P3='</span> <span style="background:#1da0df;border-radius:12px;padding:2px 7px;font-size:11px;color:white;">'
            FILES_INC_D_LINE_P4="${BK_DB_SIZE}"
            FILES_INC_D_LINE_P5='</span></div>'

            FILES_INC_D="${FILES_INC_D_LINE_P1}${FILES_INC_D_LINE_P2}${FILES_INC_D_LINE_P3}${FILES_INC_D_LINE_P4}${FILES_INC_D_LINE_P5}"

            COUNT=$((COUNT + 1))

        done

        FILES_LABEL_D_END='</div>'

    fi

    HEADEROPEN1_D='<div style="float:left;width:100%"><div style="font-size:14px;font-weight:bold;color:#FFF;float:left;font-family:Verdana,Helvetica,Arial;line-height:36px;background:'
    HEADEROPEN2_D=';padding:5px 0 10px 10px;width:100%;height:30px">'
    HEADEROPEN_D="${HEADEROPEN1_D}${COLOR_D}${HEADEROPEN2_D}"
    HEADERTEXT_D="Database Backup: ${STATUS_D} ${STATUS_ICON_D}"
    HEADERCLOSE_D='</div>'

    BODYOPEN_D='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'
    BODYCLOSE_D='</div>'

    HEADER_D=${HEADEROPEN_D}${HEADERTEXT_D}${HEADERCLOSE_D}
    BODY_D=${BODYOPEN_D}${CONTENT_D}${SIZE_D}${FILES_LABEL_D}${FILES_INC_D}${FILES_LABEL_D_END}${BODYCLOSE_D}

    # Write e-mail parts files
    echo "${HEADER_D}" >"${BAKWP}/db-bk-${NOW}.mail"
    echo "${BODY_D}" >>"${BAKWP}/db-bk-${NOW}.mail"

}

mail_section_start() {

    local body_open

    body_open='<div style="color:#000;font-size:12px;line-height:32px;float:left;font-family:Verdana,Helvetica,Arial;background:#D8D8D8;padding:10px 0 0 10px;width:100%;">'

    # Return
    echo "${body_open}"

}

mail_section_end() {

    local body_close

    body_close='</div>'

    # Return
    echo "${body_close}"

}

mail_footer() {

    # $1 = ${SCRIPT_V}

    local script_v=$1

    local footer_open script_string footer_close html_close mail_footer

    footer_open='<div style="font-size:10px;float:left;font-family:Verdana,Helvetica,Arial;text-align:right;padding-right:5px;width:100%;height:20px"><a href="https://www.broobe.com/web-mobile-development/?utm_source=linux-script&utm_medium=email&utm_campaign=landing_it" style="color: #503fe0;font-weight: bold;font-style: italic;">'
    script_string="LEMP UTILS SCRIPT Version: ${script_v} by BROOBE"
    footer_close='</a></div></div>'

    html_close=$(mail_html_end)

    mail_footer=${footer_open}${script_string}${footer_close}${html_close}

    # Return
    echo "${mail_footer}"

}

mail_html_start() {

    local html_open

    html_open='<html><body>'

    # Return
    echo "${html_open}"

}

mail_html_end() {

    local html_close

    html_close='</body></html>'

    # Return
    echo "${html_close}"

}

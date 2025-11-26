#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
################################################################################
#
# Email Template Engine: Centralized template rendering and assembly
#
################################################################################

################################################################################
# Load and process email template with variable substitution
#
# Arguments:
#   $1 - Template name (e.g., "server_info")
#   $2+ - Key=value pairs for substitution
#
# Returns:
#   0 on success, 1+ on error
#
# Outputs:
#   Processed HTML to stdout
#
# Example:
#   mail_template_render "server_info" \
#       "server_name=production" \
#       "server_ip=192.168.1.10" \
#       "disk_usage=45%"
################################################################################
function mail_template_render() {
    local template_name="${1}"
    shift

    # Get template set from environment or default
    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local template_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${template_name}-tpl.html"

    # Validate template exists
    if [[ ! -f "${template_path}" ]]; then
        log_event "error" "Email template not found: ${template_path}" "false"

        # Try fallback to default template set if we're using a custom one
        if [[ "${template_set}" != "default" ]]; then
            log_event "warning" "Trying fallback to default template set..." "false"
            template_path="${BROLIT_MAIN_DIR}/templates/emails/default/${template_name}-tpl.html"

            if [[ ! -f "${template_path}" ]]; then
                log_event "error" "Fallback template not found: ${template_path}" "false"
                return 1
            fi
        else
            return 1
        fi
    fi

    # Load template content
    local template_content
    template_content="$(cat "${template_path}" 2>/dev/null)" || {
        log_event "error" "Failed to read template: ${template_path}" "false"
        return 1
    }

    # Replace variables using sed
    local result="${template_content}"
    local key value pair

    for pair in "$@"; do
        # Split on first '=' only
        key="${pair%%=*}"
        value="${pair#*=}"

        # Escape special characters in value for sed
        # This prevents issues with slashes, ampersands, etc.
        value="$(echo "${value}" | sed 's/[&/\]/\\&/g')"

        # Replace all occurrences of {{key}} with value
        result="$(echo "${result}" | sed "s|{{${key}}}|${value}|g")"
    done

    # Output the processed template
    echo "${result}"

    return 0
}

################################################################################
# Render template with environment variables (using envsubst)
#
# Arguments:
#   $1 - Template name
#
# Environment:
#   All variables to substitute must be exported
#   EMAIL_TEMPLATE_SET - Template set to use (default: "default")
#
# Returns:
#   0 on success, 1+ on error
#
# Example:
#   export SERVER_NAME="production"
#   export SERVER_IP="192.168.1.10"
#   mail_template_render_env "server_info"
################################################################################
function mail_template_render_env() {
    local template_name="${1}"
    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local template_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${template_name}-tpl.html"

    # Validate template exists
    if [[ ! -f "${template_path}" ]]; then
        log_event "error" "Email template not found: ${template_path}" "false"

        # Try fallback to default
        if [[ "${template_set}" != "default" ]]; then
            template_path="${BROLIT_MAIN_DIR}/templates/emails/default/${template_name}-tpl.html"
            if [[ ! -f "${template_path}" ]]; then
                return 1
            fi
        else
            return 1
        fi
    fi

    # Check if envsubst is available
    if command -v envsubst >/dev/null 2>&1; then
        # Use envsubst for replacement (more efficient for many variables)
        envsubst < "${template_path}"
    else
        # Fallback: just output the template as-is
        log_event "warning" "envsubst not available, template variables not replaced" "false"
        cat "${template_path}"
    fi

    return 0
}

################################################################################
# Assemble complete email from multiple section files
#
# Arguments:
#   $1 - Output file path
#   $2 - Main template name (without -tpl.html suffix)
#   $3+ - Section file paths to include
#
# Returns:
#   0 on success, 1+ on error
#
# Example:
#   mail_template_assemble "/tmp/email.html" "main" \
#       "/tmp/server_info.mail" \
#       "/tmp/packages.mail" \
#       "/tmp/footer.mail"
#
# How it works:
#   1. Loads the main template (e.g., main-tpl.html)
#   2. For each section file, reads its content
#   3. Replaces {{section_name}} placeholders with section content
#   4. Removes any unused placeholders
#   5. Writes final result to output file
################################################################################
function mail_template_assemble() {
    local output_file="${1}"
    local main_template="${2}"
    shift 2
    local sections=("$@")

    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local main_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${main_template}-tpl.html"

    # Validate main template exists
    if [[ ! -f "${main_path}" ]]; then
        log_event "error" "Main email template not found: ${main_path}" "false"

        # Try fallback
        if [[ "${template_set}" != "default" ]]; then
            main_path="${BROLIT_MAIN_DIR}/templates/emails/default/${main_template}-tpl.html"
            if [[ ! -f "${main_path}" ]]; then
                log_event "error" "Fallback main template not found: ${main_path}" "false"
                return 1
            fi
        else
            return 1
        fi
    fi

    # Load main template
    local result
    result="$(cat "${main_path}" 2>/dev/null)" || {
        log_event "error" "Failed to read main template: ${main_path}" "false"
        return 1
    }

    # Replace section placeholders
    local section_name section_content
    for section_file in "${sections[@]}"; do
        if [[ -f "${section_file}" ]]; then
            # Extract section name from filename (remove path and .mail extension)
            section_name="$(basename "${section_file}" .mail)"

            # Read section content
            section_content="$(cat "${section_file}" 2>/dev/null)" || {
                log_event "warning" "Failed to read section file: ${section_file}" "false"
                continue
            }

            # Escape special characters for sed
            section_content="$(echo "${section_content}" | sed 's/[&/\]/\\&/g')"

            # Replace placeholder with content
            result="$(echo "${result}" | sed "s|{{${section_name}}}|${section_content}|g")"
        else
            log_event "debug" "Section file not found (skipping): ${section_file}" "false"
        fi
    done

    # Remove all unused placeholders (anything still in {{...}} format)
    result="$(echo "${result}" | sed 's|{{[^}]*}}||g')"

    # Write result to output file
    echo "${result}" > "${output_file}" 2>/dev/null || {
        log_event "error" "Failed to write assembled email to: ${output_file}" "false"
        return 1
    }

    log_event "debug" "Email template assembled successfully: ${output_file}" "false"

    return 0
}

################################################################################
# Validate that a template exists
#
# Arguments:
#   $1 - Template name
#   $2 - Template set (optional, defaults to EMAIL_TEMPLATE_SET or "default")
#
# Returns:
#   0 if template exists, 1 if not found
################################################################################
function mail_template_exists() {
    local template_name="${1}"
    local template_set="${2:-${EMAIL_TEMPLATE_SET:-default}}"
    local template_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${template_name}-tpl.html"

    if [[ -f "${template_path}" ]]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Get list of available templates in a template set
#
# Arguments:
#   $1 - Template set (optional, defaults to EMAIL_TEMPLATE_SET or "default")
#
# Outputs:
#   List of template names (one per line, without -tpl.html suffix)
################################################################################
function mail_template_list() {
    local template_set="${1:-${EMAIL_TEMPLATE_SET:-default}}"
    local template_dir="${BROLIT_MAIN_DIR}/templates/emails/${template_set}"

    if [[ ! -d "${template_dir}" ]]; then
        log_event "warning" "Template directory not found: ${template_dir}" "false"
        return 1
    fi

    # List all *-tpl.html files and remove the suffix
    find "${template_dir}" -maxdepth 1 -name "*-tpl.html" -type f 2>/dev/null | \
        sed 's|.*/||; s|-tpl\.html$||' | \
        sort
}

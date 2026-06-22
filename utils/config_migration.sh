#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
################################################################################
#
# Config Migration: Smart merge between brolit config versions.
#
################################################################################

################################################################################
# Private: legacy field mappings for migration
#
# Arguments:
#   none
#
# Outputs:
#   CONFIG_FIELD_MIGRATIONS associative array
################################################################################

function _config_migration_load_legacy_mappings() {

    declare -gA CONFIG_FIELD_MIGRATIONS

    # Format: CONFIG_FIELD_MIGRATIONS["new_field"]="old_field"
    # Add migrations here when fields are renamed between versions
    CONFIG_FIELD_MIGRATIONS["NOTIFICATIONS.email[].config[].email_to"]="NOTIFICATIONS.email[].config[].maila"

}

################################################################################
# Check if config migration is needed
#
# Arguments:
#   ${1} = ${config_file}
#
# Outputs:
#   Sets MIGRATION_NEEDED, CURRENT_VERSION, TARGET_VERSION
#   0 if migration needed, 1 if not
################################################################################

function config_migration_check() {

    local config_file="${1}"

    local config_template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    MIGRATION_NEEDED="false"
    CURRENT_VERSION=""
    TARGET_VERSION=""

    if [[ ! -f "${config_file}" ]]; then
        return 1
    fi

    if [[ ! -f "${config_template}" ]]; then
        log_event "error" "Config template not found: ${config_template}" "false"
        return 1
    fi

    CURRENT_VERSION="$(json_read_field "${config_file}" "BROLIT_SETUP.config[].version")"
    TARGET_VERSION="$(json_read_field "${config_template}" "BROLIT_SETUP.config[].version")"

    if [[ -z "${CURRENT_VERSION}" ]]; then
        log_event "error" "Could not read version from config file" "false"
        return 1
    fi

    if [[ -z "${TARGET_VERSION}" ]]; then
        log_event "error" "Could not read version from config template" "false"
        return 1
    fi

    if [[ "${CURRENT_VERSION}" != "${TARGET_VERSION}" ]]; then
        MIGRATION_NEEDED="true"
        return 0
    fi

    return 1

}

################################################################################
# Calculate diff between current config and template
#
# Arguments:
#   ${1} = ${config_file}
#   ${2} = ${config_template}
#
# Outputs:
#   Sets MIGRATION_FIELDS_ADDED, MIGRATION_FIELDS_REMOVED arrays
################################################################################

function config_migration_diff() {

    local config_file="${1}"
    local config_template="${2}"

    # Globals
    declare -ga MIGRATION_FIELDS_ADDED=()
    declare -ga MIGRATION_FIELDS_REMOVED=()

    local config_keys
    local template_keys

    # Get top-level keys from both files
    config_keys="$(jq -r 'keys[]' "${config_file}" 2>/dev/null)"
    template_keys="$(jq -r 'keys[]' "${config_template}" 2>/dev/null)"

    # Find keys in template but not in config (new fields)
    while IFS= read -r key; do
        if ! echo "${config_keys}" | grep -qx "${key}"; then
            MIGRATION_FIELDS_ADDED+=("${key}")
        fi
    done <<< "${template_keys}"

    # Find keys in config but not in template (removed fields)
    while IFS= read -r key; do
        if ! echo "${template_keys}" | grep -qx "${key}"; then
            MIGRATION_FIELDS_REMOVED+=("${key}")
        fi
    done <<< "${config_keys}"

    # Check for renamed fields via legacy mappings
    _config_migration_load_legacy_mappings

    export MIGRATION_FIELDS_ADDED MIGRATION_FIELDS_REMOVED

}

################################################################################
# Show migration diff to user
#
# Arguments:
#   ${1} = ${config_file}
#   ${2} = ${config_template}
#
# Outputs:
#   Whiptail with diff summary
#   0 if user accepts, 1 if user declines
################################################################################

function config_migration_show_diff() {

    local config_file="${1}"
    local config_template="${2}"

    local current_version
    local target_version
    local diff_message=""

    current_version="$(json_read_field "${config_file}" "BROLIT_SETUP.config[].version")"
    target_version="$(json_read_field "${config_template}" "BROLIT_SETUP.config[].version")"

    # Calculate diff
    config_migration_diff "${config_file}" "${config_template}"

    # Build message
    diff_message+="Config version: ${current_version} -> ${target_version}\n\n"

    if [[ ${#MIGRATION_FIELDS_ADDED[@]} -gt 0 ]]; then
        diff_message+="New sections to add:\n"
        for field in "${MIGRATION_FIELDS_ADDED[@]}"; do
            diff_message+="  + ${field}\n"
        done
        diff_message+="\n"
    fi

    if [[ ${#MIGRATION_FIELDS_REMOVED[@]} -gt 0 ]]; then
        diff_message+="Sections removed (will be kept for compatibility):\n"
        for field in "${MIGRATION_FIELDS_REMOVED[@]}"; do
            diff_message+="  - ${field}\n"
        done
        diff_message+="\n"
    fi

    # Check for legacy field migrations
    local legacy_count=0
    for new_field in "${!CONFIG_FIELD_MIGRATIONS[@]}"; do
        local old_field="${CONFIG_FIELD_MIGRATIONS[${new_field}]}"
        local old_value
        old_value="$(json_read_field "${config_file}" "${old_field}" 2>/dev/null)"
        if [[ -n "${old_value}" && "${old_value}" != "null" ]]; then
            ((legacy_count++))
        fi
    done

    if [[ ${legacy_count} -gt 0 ]]; then
        diff_message+="Fields to migrate (renamed):\n"
        diff_message+="  ~ ${legacy_count} field(s) will be renamed\n\n"
    fi

    diff_message+="A backup will be created before migration.\n"
    diff_message+="\nDo you want to proceed with the migration?"

    # Show whiptail
    whiptail_message_with_skip_option "Config Migration" "${diff_message}"
    return $?

}

################################################################################
# Smart merge between current config and template
#
# Arguments:
#   ${1} = ${config_file}
#   ${2} = ${config_template}
#
# Outputs:
#   Updates config_file in place
#   0 if ok, 1 on error
################################################################################

function config_migration_merge() {

    local config_file="${1}"
    local config_template="${2}"

    local temp_file
    temp_file="$(mktemp)"

    local new_version

    # Start with a copy of the current config
    cp "${config_file}" "${temp_file}"

    # Get new version from template
    new_version="$(json_read_field "${config_template}" "BROLIT_SETUP.config[].version")"

    # Merge: use template as base, overlay current values
    # This preserves all current values and adds new fields from template
    local merged_config
    merged_config="$(jq -s '.[0] * .[1]' "${config_template}" "${temp_file}" 2>/dev/null)"

    if [[ -n "${merged_config}" ]]; then
        echo "${merged_config}" > "${temp_file}"
    fi

    # Handle legacy field migrations
    _config_migration_load_legacy_mappings

    for new_field in "${!CONFIG_FIELD_MIGRATIONS[@]}"; do

        local old_field="${CONFIG_FIELD_MIGRATIONS[${new_field}]}"

        # Check if old field has a value
        local old_value
        old_value="$(jq -r "if .${old_field} then .${old_field} else empty end" "${temp_file}" 2>/dev/null)"

        if [[ -n "${old_value}" && "${old_value}" != "null" && "${old_value}" != "" ]]; then

            # Check if new field already exists and is empty
            local new_value
            new_value="$(jq -r "if .${new_field} then .${new_field} else empty end" "${temp_file}" 2>/dev/null)"

            if [[ -z "${new_value}" || "${new_value}" == "null" || "${new_value}" == "" ]]; then
                # Migrate: copy old value to new field
                local old_value_json
                old_value_json="$(jq ".${old_field}" "${temp_file}")"

                local migrated
                migrated="$(jq --argjson val "${old_value_json}" --arg nf "${new_field}" \
                    'setpath($nf; $val)' "${temp_file}" 2>/dev/null)"

                if [[ -n "${migrated}" ]]; then
                    echo "${migrated}" > "${temp_file}"
                fi
            fi

        fi

    done

    # Update version
    local updated_config
    updated_config="$(jq --arg ver "${new_version}" \
        '.BROLIT_SETUP.config[0].version = $ver' "${temp_file}")"

    if [[ -n "${updated_config}" ]]; then
        echo "${updated_config}" > "${temp_file}"
    fi

    # Validate result
    if jq . "${temp_file}" > /dev/null 2>&1; then
        cp "${temp_file}" "${config_file}"
        rm -f "${temp_file}"
        return 0
    else
        log_event "error" "Migration produced invalid JSON" "false"
        rm -f "${temp_file}"
        return 1
    fi

}

################################################################################
# Apply config migration
#
# Arguments:
#   ${1} = ${config_file}
#
# Outputs:
#   Creates backup, applies merge, validates
#   0 if ok, 1 on error
################################################################################

function config_migration_apply() {

    local config_file="${1}"

    local config_template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"
    local backup_file="${config_file}.bak.$(date +%Y%m%d_%H%M%S)"

    # Create backup
    cp "${config_file}" "${backup_file}"

    log_event "info" "Config backup created: ${backup_file}" "false"
    display --indent 6 --text "- Creating config backup" --result "DONE" --color GREEN
    display --indent 8 --text "Backup: ${backup_file}" --tcolor CYAN

    # Apply merge
    config_migration_merge "${config_file}" "${config_template}"
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Verify version was updated
        local new_version
        new_version="$(json_read_field "${config_file}" "BROLIT_SETUP.config[].version")"

        display --indent 6 --text "- Config migrated to version ${new_version}" --result "DONE" --color GREEN
        log_event "info" "Config migrated from ${CURRENT_VERSION} to ${new_version}" "false"

        return 0

    else

        # Restore from backup on failure
        cp "${backup_file}" "${config_file}"
        log_event "error" "Migration failed, restored from backup" "false"
        display --indent 6 --text "- Migration failed, restoring backup" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Main migration handler - checks and applies if needed
#
# Arguments:
#   ${1} = ${config_file}
#
# Outputs:
#   0 if migration was applied or not needed
#   1 if migration declined or failed
################################################################################

function config_migration_handler() {

    local config_file="${1}"

    config_migration_check "${config_file}"
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Migration needed
        display --indent 6 --text "- Config version outdated" --result "OUTDATED" --color YELLOW

        # Show diff and ask user
        config_migration_show_diff "${config_file}" "${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then

            # User accepted
            config_migration_apply "${config_file}"
            return $?

        else

            # User declined
            display --indent 6 --text "- Migration declined by user" --result "SKIPPED" --color YELLOW
            return 1

        fi

    fi

    return 0

}

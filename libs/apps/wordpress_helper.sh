#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2
################################################################################
#
# WordPress Helper: Perform wordpress actions.
#
################################################################################

################################################################################
# Download Wordpress from official repository
#
# Arguments:
#  ${1} = destination_path
#  ${2} = wp_version (latest, 6.0.3, 6.0.2, etc) - Optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function wp_download() {

  local destination_path=${1}
  local wp_version=${2}

  if [[ -z ${wp_version} || ${wp_version} == "latest" ]]; then

    # Download latest version
    ${CURL} "https://wordpress.org/latest.tar.gz" >"${destination_path}/wordpress.tar.gz"

  else

    # Download specific version
    ${CURL} "https://wordpress.org/wordpress-${wp_version}.tar.gz" >"${destination_path}/wordpress.tar.gz"

  fi

  curl_output=$?
  if [[ ${curl_output} -eq 0 ]]; then

    log_event "debug" "WordPress ${wp_version} downloaded OK." "false"
    display --indent 6 --text "- Downloading WordPress ${wp_version}" --result "DONE" --color GREEN

    return 0

  else

    log_event "error" "Downloading WordPress ${wp_version}" "false"
    log_event "debug" "Command executed: ${CURL} -O https://wordpress.org/wordpress-${wp_version}.tar.gz" "false"
    display --indent 6 --text "- Downloading WordPress ${wp_version}" --result "FAIL" --color RED

    return 1

  fi

}

################################################################################
# Check if is a WordPress project
#
# Arguments:
#  ${1} = project directory
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function wp_project() {

  local project_dir="${1}"

  local install_type

  log_event "info" "Checking if ${project_dir} is a WordPress project ..." "false"

  # Check if it has wp-config.php
  if [[ -f "${project_dir}/wp-config.php" ]]; then

    install_type="default"
    log_event "info" "${project_dir} is a ${install_type} WordPress project" "false"

    # Return
    echo "${install_type}" && return 0

  else

    if [[ -f "${project_dir}/wordpress/wp-config.php" ]]; then

      install_type="docker"
      log_event "info" "${project_dir} is a ${install_type} WordPress project" "false"

      # Return
      echo "${install_type}" && return 0

    else

      log_event "info" "${project_dir} is not a WordPress project" "false"

      return 1

    fi

  fi

}

################################################################################
# WordPress config path
#
# Arguments:
#  ${1} = ${dir_to_search}
#
# Outputs:
#  String with wp-config path
################################################################################

function wp_config_path() {

  local dir_to_search="${1}"

  local find_output

  if [[ -n "${dir_to_search}" && -d "${dir_to_search}" ]]; then

    # Log
    log_event "info" "Searching WordPress Installation on directory: ${dir_to_search}" "false"

    # Find where wp-config.php is
    find_output="$(find "${dir_to_search}" -name "wp-config.php" | sed 's|/[^/]*$||')"

    if [[ -z ${find_output} ]]; then

      # Log
      log_event "warning" "No WordPress Installation found on directory: ${dir_to_search}" "false"

      return 1

    fi

    # If found more thant one directory, print the first one
    if [[ $(echo "${find_output}" | wc -l) -gt 1 ]]; then

      # Log
      display --indent 6 --text "- Searching WordPress Installation" --result "WARNING" --color YELLOW
      display --indent 8 --text "More than one WordPress installation found on directory" --tcolor YELLOW
      log_event "warning" "Found more than one WordPress Installation on directory: ${dir_to_search}" "false"

      # Print the first one
      echo "${find_output}" | head -n 1

      return 0

    else

      if [[ $(echo "${find_output}" | wc -l) -eq 1 ]]; then

        # Log
        log_event "info" "Found WordPress Installation on directory: ${dir_to_search}" "false"
        log_event "info" "Config file found at: ${find_output}" "false"

        # Return
        echo "${find_output}" && return 0

      fi

    fi

  else

    return 1

  fi

}

################################################################################
# Get WordPress config option
#
# Arguments:
#  ${1} = ${project_dir}
#  ${2} = ${wp_option}
#
# Outputs:
#  ${wp_value} if ok, 1 on error.
################################################################################

function wp_config_get_option() {

  local wp_project_dir="${1}"
  local wp_option="${2}"

  local wp_value

  # Check if wp-config.php exists
  [[ ! -f "${wp_project_dir}/wp-config.php" ]] && return 1

  log_event "info" "Reading config option value in ${wp_project_dir}/wp-config.php" "false"

  # Update wp-config.php
  wp_value="$(cat "${wp_project_dir}/wp-config.php" | grep "${wp_option}" | cut -d \' -f 4)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 && -n ${wp_value} ]]; then

    # Log
    log_event "info" "Reading '${wp_option}' value from wp-config: ${wp_value}" "false"
    display --indent 6 --text "- Reading ${wp_option} value from wp-config.php" --result "DONE" --color GREEN

    # Return
    echo "${wp_value}" && return 0

  else

    # Log
    log_event "error" "Reading '${wp_option}' value from wp-config." "false"
    log_event "debug" "Output: ${wp_value}" "false"
    display --indent 6 --text "- Getting wp-config.php option" --result "FAIL" --color RED
    display --indent 8 --text "Please read the log file" --tcolor RED

    return 1

  fi

}

################################################################################
# Private: Set/Update WordPress config option.
#
# Description: This function should only be used by project functions.
#
# Arguments:
#  ${1} = ${wp_config_file}
#  ${2} = ${wp_option}
#  ${3} = ${wp_value}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function _wp_config_set_option() {

  local wp_config_file="${1}"
  local wp_option="${2}"
  local wp_value="${3}"

  # Check if wp_config_file exists
  [[ ! -f ${wp_config_file} ]] && return 1

  # Update wp-config.php
  log_event "info" "Changing config parameters on ${wp_config_file}" "false"

  sed_output="$(sed -i "/${wp_option}/s/'[^']*'/'${wp_value}'/2" "${wp_config_file}")"

  sed_result=$?
  if [[ ${sed_result} -eq 0 ]]; then

    # Log
    log_event "info" "Setting ${wp_option}=${wp_value}" "false"
    display --indent 6 --text "- Setting ${wp_option} on wp-config.php" --result "DONE" --color GREEN
    #display --indent 8 --text "Value: ${wp_value}" --tcolor GREEN

    return 0

  else

    # Log
    log_event "error" "Setting ${wp_option} option with value: ${wp_value}" "false"
    log_event "debug" "Output: ${sed_output}" "false"
    display --indent 6 --text "- Setting ${wp_option} on wp-config.php" --result "FAIL" --color RED
    display --indent 8 --text "Please read the log file" --tcolor RED

    return 1

  fi

}

################################################################################
# Change WordPress directory permissions
#
# Arguments:
#  ${1} = ${wordpress_dir}
#
# Outputs:
#  None
################################################################################

function wp_change_permissions() {

  local wordpress_dir="${1}"

  # Change ownership
  change_ownership "www-data" "www-data" "${wordpress_dir}"

  find "${wordpress_dir}" -type d -exec chmod g+s {} \;

  if [[ -d "${wordpress_dir}/wp-content" ]]; then

    # Change directory permissions rwxr-xr-x
    find "${wordpress_dir}" -type d -exec chmod 755 {} \;
    # Change file permissions rw-r--r--
    find "${wordpress_dir}" -type f -exec chmod 644 {} \;

  fi

  log_event "info" "Permissions changes for: ${wordpress_dir}" "false"
  display --indent 6 --text "- Setting default permissions on WordPress" --result "DONE" --color GREEN

}

################################################################################
# Replace string on WordPress database (without wp-cli)
#
# Arguments:
#  ${1} = ${db_prefix}
#  ${2} = ${target_db}
#
# Outputs:
#  None
################################################################################

# Ref multisite: https://multilingualpress.org/docs/wordpress-multisite-database-tables/
#
#UPDATE ${db_prefix}${blog_id}_blogs SET domain='${domain}' WHERE blog_id='1';
#UPDATE ${db_prefix}${blog_id}_blogs SET domain='${domain}' WHERE blog_id='2';
#
#UPDATE ${db_prefix}options SET option_value='${new_URL}' WHERE option_id='1';
#UPDATE ${db_prefix}options SET option_value='${new_URL}' WHERE option_id='2';
#
#UPDATE ${db_prefix}${blog_id}_site SET domain='${domain}' WHERE id='1'; #${domain} instead of ${new_URL}
#
#UPDATE ${db_prefix}${blog_id}_sitemeta SET meta_value='${new_URL}' WHERE meta_id='14';
#
#UPDATE ${db_prefix}${blog_id}_options SET option_value='${new_URL}' WHERE option_id='1';
#UPDATE ${db_prefix}${blog_id}_options SET option_value='${new_URL}' WHERE option_id='2';

function wp_replace_string_on_database() {

  local db_prefix="${1}"
  local target_db="${2}"
  local existing_URL="${3}"
  local new_URL="${4}"

  local chosen_db
  #local databases

  if [[ -z "${db_prefix}" ]]; then

    db_prefix="$(whiptail_input "WordPress DB Prefix" "Please insert the WordPress Database Prefix. Example: wp_" "")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_event "info" "Setting db prefix: '${db_prefix}'" "false"

    else

      return 1

    fi

  fi

  if [[ -z ${target_db} ]]; then

    chosen_db="$(mysql_ask_database_selection)"

  else
    chosen_db="${target_db}"

  fi

  if [[ -n "${existing_URL}" && -n "${new_URL}" ]]; then

    #mysql_database_export "${chosen_db}" "false" "${chosen_db}_bk_before_replace_urls.sql"

    # Queries
    SQL0="USE ${chosen_db};"
    SQL1="UPDATE ${db_prefix}options SET option_value = replace(option_value, '${existing_URL}', '${new_URL}') WHERE option_name = 'home' OR option_name = 'siteurl';"
    SQL2="UPDATE ${db_prefix}posts SET post_content = replace(post_content, '${existing_URL}', '${new_URL}');"
    SQL3="UPDATE ${db_prefix}posts SET guid = replace(guid, '${existing_URL}', '${new_URL}');"
    SQL4="UPDATE ${db_prefix}postmeta SET meta_value = replace(meta_value,'${existing_URL}','${new_URL}');"
    SQL5="UPDATE ${db_prefix}usermeta SET meta_value = replace(meta_value, '${existing_URL}','${new_URL}');"
    SQL6="UPDATE ${db_prefix}links SET link_url = replace(link_url, '${existing_URL}','${new_URL}');"
    SQL7="UPDATE ${db_prefix}comments SET comment_content = replace(comment_content , '${existing_URL}','${new_URL}');"

    log_event "info" "Replacing URLs in database ${chosen_db} ..." "false"

    "${MYSQL_ROOT}" -e "${SQL0}${SQL1}${SQL2}${SQL3}${SQL4}${SQL5}${SQL6}${SQL7}"

    exitstatus=$?
    if [[ $exitstatus -eq 0 ]]; then

      # Log
      log_event "info" "Search and replace finished ok" "false"
      display --indent 6 --text "- Running search and replace" --result "DONE" --color GREEN
      display --indent 8 --text "${existing_URL} was replaced by ${new_URL}" --tcolor YELLOW

      return 0

    else

      # Log
      log_event "error" "Something went wrong running search and replace!" "false"
      display --indent 6 --text "- Running search and replace" --result "FAIL" --color RED

      return 1

    fi

  fi

}

################################################################################
# Ask string to replace on WordPress database
#
# Arguments:
#  ${1} = ${wp_path}
#  ${2} = ${project_install_type}
#
# Outputs:
#  None
################################################################################

# TODO: need rethink this function
function wp_ask_url_search_and_replace() {

  local wp_path="${1}"
  local project_install_type="${2}"

  local project_name
  local existing_URL
  local new_URL

  log_subsection "WP Replace URLs"

  if [[ -z ${existing_URL} ]]; then

    existing_URL="$(whiptail_input "URL To Change" "Insert the URL you want to change, including http:// or https://" "")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ -z ${new_URL} ]]; then

        new_URL="$(whiptail_input "New URL" "Insert the new URL , including http:// or https://" "")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          # Create temporary folder for backups
          [[ ! -d "${BROLIT_TMP_DIR}/backups" ]] && mkdir -p "${BROLIT_TMP_DIR}/backups"

          project_name="$(basename "${wp_path}")"

          [[ -z ${project_install_type} ]] && project_install_type="$(project_get_install_type "${wp_path}")"

          # Backup database
          wpcli_export_database "${wp_path}" "${project_install_type}" "${BROLIT_TMP_DIR}/backups/${project_name}_bk_before_search_and_replace.sql"

          # Run search and replace
          wpcli_search_and_replace "${wp_path}" "${project_install_type}" "${existing_URL}" "${new_URL}"

          exitstatus=$?
          # If wp-cli method fails, it will try to replace via SQL Query
          if [[ ${exitstatus} -eq 1 ]]; then

            # Get database and database prefix from wp-config.php
            db_prefix="$(cat "${wp_path}"/wp-config.php | grep "\$table_prefix" | cut -d \' -f 2)"
            target_db="$(sed -n "s/define( *'DB_NAME', *'\([^']*\)'.*/\1/p" "${wp_path}"/wp-config.php)"

            # Run search and replace
            wp_replace_string_on_database "${db_prefix}" "${target_db}" "${existing_URL}" "${new_URL}"

          fi

        else

          display --indent 6 --text "- Configuring search and replace" --result "SKIPPED" --color YELLOW

        fi

      fi

    else

      display --indent 6 --text "- Configuring search and replace" --result "SKIPPED" --color YELLOW

    fi

  fi

}

function wordpress_select_project_to_work_with() {

  local wordpress_projects="${1}"

  # Get length of ${wordpress_projects} array
  len=${#wordpress_projects[@]}

  if [[ $len != 1 ]]; then

    local chosen_wordpress_project

    chosen_wordpress_project="$(whiptail --title "Project Selection" --menu "Select the project you want to work with:" 20 78 10 $(for x in ${wordpress_projects}; do echo "${x} [X]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_event "info" "Working with ${chosen_wordpress_project}" "false"

      # Return
      echo "${chosen_wordpress_project}" && return 0

    else

      log_event "debug" "Project selection skipped" "false"

      return 1

    fi

  else

    # Return
    echo "${wordpress_projects}" && return 0

  fi

}

#!/usr/bin/env bash
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
# Description: Scheduled Borg exactly-once routing regressions.
################################################################################

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
BROLIT_MAIN_DIR="$(cd "${TEST_LOADER_DIR}/.." &>/dev/null && pwd -P)"
export BROLIT_MAIN_DIR

# shellcheck disable=SC1090
source "${BROLIT_MAIN_DIR}/libs/local/backup_helper.sh"

################################################################################
# Run scheduled Borg routing regressions with isolated command fixtures.
#
# Arguments:
#  none
#
# Outputs:
#  Failure details on stderr. Returns nonzero when any assertion fails.
################################################################################

function test_borg_scheduled_routing() (

  set -u

  local test_tmp
  local config_dir
  local projects_dir
  local calls_file
  local failed=0
  local aggregate_result=0
  local -a failed_labels=()
  local -a status_lines=()
  local -A handled_configs=()

  test_tmp="$(mktemp -d "${TMPDIR:-/tmp/opencode}/borg-routing.XXXXXX")"
  trap "rm -rf -- '${test_tmp}'" EXIT
  config_dir="${test_tmp}/borgmatic.d"
  projects_dir="${test_tmp}/projects"
  calls_file="${test_tmp}/calls"
  mkdir -p "${config_dir}" "${projects_dir}/project-one" "${projects_dir}/empty-alias"
  touch "${projects_dir}/project-one/content" "${config_dir}/project-one.yml" "${config_dir}/database-only.yml"
  : > "${calls_file}"

  export BROLIT_BORGMATIC_CONFIG_DIR="${config_dir}"
  export PROJECTS_PATH="${projects_dir}"
  BORG_REPO_UNAVAILABLE=0
  BORG_FIRST_FAILURE_REASON=""

  ################################################################################
  # Fixture logging; arguments ignored; outputs nothing.
  ################################################################################
  function log_event() { :; }
  ################################################################################
  # Fixture display; arguments ignored; outputs nothing.
  ################################################################################
  function display() { :; }
  ################################################################################
  # Fixture notification; arguments ignored; outputs nothing.
  ################################################################################
  function send_notification() { :; }
  ################################################################################
  # Fixture initialization; records config and succeeds.
  # Arguments: config path. Outputs: none.
  ################################################################################
  function borg_initialize_for_backup() {
    local config_file="${1}"
    printf 'init:%s\n' "$(basename "${config_file}")" >> "${calls_file}"
  }
  ################################################################################
  # Fixture resolver; arguments: none. Outputs fake command name.
  ################################################################################
  function _borgmatic_resolve_cmd() { echo "fake_borgmatic"; }
  ################################################################################
  # Fixture timeout; drops duration and executes remaining fixture command.
  ################################################################################
  function timeout() {
    local duration="${1}"
    shift
    [[ -n "${duration}" ]] || return 1
    "$@"
  }
  ################################################################################
  # Fixture borgmatic; records the config passed after --config.
  ################################################################################
  function fake_borgmatic() {
    local config_option="${1}"
    local config_file="${2}"
    [[ "${config_option}" == "--config" ]] || return 1
    printf 'run:%s\n' "$(basename "${config_file}")" >> "${calls_file}"
  }

  backup_borgmatic_config_once "${config_dir}/project-one.yml" "project-one" || failed=1
  handled_configs["${config_dir}/project-one.yml"]=1
  backup_unhandled_borgmatic_configs handled_configs aggregate_result failed_labels status_lines

  [[ "$(grep -c '^run:project-one.yml$' "${calls_file}")" -eq 1 ]] || {
    echo "FAILED: project config did not execute exactly once" >&2
    failed=1
  }
  [[ "$(grep -c '^run:database-only.yml$' "${calls_file}")" -eq 1 ]] || {
    echo "FAILED: standalone config did not execute exactly once" >&2
    failed=1
  }

  check_borgmatic_config_coverage || {
    echo "FAILED: empty alias was incorrectly treated as missing coverage" >&2
    failed=1
  }

  grep -Fq 'BORG_HANDLED_CONFIGS["${PROJECT_CONFIG}"]=1' "${BROLIT_MAIN_DIR}/cron/backups_tasks.sh" || {
    echo "FAILED: scheduled routing does not mark project configs handled" >&2
    failed=1
  }
  if grep -Fq 'backup_all_files_with_borg' "${BROLIT_MAIN_DIR}/cron/backups_tasks.sh"; then
    echo "FAILED: scheduled cron still invokes the duplicate directory-wide pass" >&2
    failed=1
  fi

  # A trailing slash must normalize to the same handled key and never rerun
  # the project config during the standalone sweep.
  : > "${calls_file}"
  export BROLIT_BORGMATIC_CONFIG_DIR="${config_dir}/"
  handled_configs=(["${config_dir}/project-one.yml"]=1)
  aggregate_result=0
  failed_labels=()
  status_lines=()
  backup_unhandled_borgmatic_configs handled_configs aggregate_result failed_labels status_lines
  [[ "$(grep -c '^run:project-one.yml$' "${calls_file}" || true)" -eq 0 ]] || {
    echo "FAILED: trailing slash caused duplicate project execution" >&2
    failed=1
  }
  [[ "$(grep -c '^run:database-only.yml$' "${calls_file}")" -eq 1 ]] || {
    echo "FAILED: standalone config was not preserved with trailing slash" >&2
    failed=1
  }

  # Symlinked top-level configs execute and count toward project coverage.
  rm -f "${config_dir}/project-one.yml" "${config_dir}/database-only.yml"
  touch "${test_tmp}/linked.yml"
  ln -s "${test_tmp}/linked.yml" "${config_dir}/project-one.yml"
  check_borgmatic_config_coverage || {
    echo "FAILED: valid symlinked config was treated as zero coverage" >&2
    failed=1
  }

  return ${failed}

)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_borg_scheduled_routing || exit 1
  echo "Scheduled Borg routing tests passed"
fi

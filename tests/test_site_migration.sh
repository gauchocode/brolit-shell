#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.10
#############################################################################

function test_site_migration_functions() {

  test_migrate_check_docker_project
  test_migrate_resolve_dest_path
  test_migrate_check_dest_path_collision
  test_migrate_decommission_source_guard

}

function test_migrate_check_docker_project() {

  log_subsection "Test: migrate_check_docker_project"

  local test_projects_path
  test_projects_path="$(mktemp -d)"
  local saved_projects_path="${PROJECTS_PATH}"
  PROJECTS_PATH="${test_projects_path}"

  # Non-Docker project (no docker-compose file)
  mkdir -p "${test_projects_path}/host.example.com"
  if ! migrate_check_docker_project "host.example.com" >/dev/null 2>&1; then
    display --indent 6 --text "- migrate_check_docker_project: rejects non-Docker project" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_check_docker_project: rejects non-Docker project" --result "FAIL" --color RED
  fi

  # Docker project
  mkdir -p "${test_projects_path}/docker.example.com"
  touch "${test_projects_path}/docker.example.com/docker-compose.yml"
  if migrate_check_docker_project "docker.example.com" >/dev/null 2>&1; then
    display --indent 6 --text "- migrate_check_docker_project: accepts Docker project" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_check_docker_project: accepts Docker project" --result "FAIL" --color RED
  fi

  # Unknown domain
  if ! migrate_check_docker_project "unknown.example.com" >/dev/null 2>&1; then
    display --indent 6 --text "- migrate_check_docker_project: rejects unknown domain" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_check_docker_project: rejects unknown domain" --result "FAIL" --color RED
  fi

  PROJECTS_PATH="${saved_projects_path}"
  rm --recursive --force "${test_projects_path}"

}

function test_migrate_resolve_dest_path() {

  log_subsection "Test: migrate_resolve_dest_path"

  local saved_projects_path="${PROJECTS_PATH}"
  PROJECTS_PATH="/var/www"

  local resolved
  resolved="$(migrate_resolve_dest_path "example.com" "")"
  if [[ ${resolved} == "/var/www/example.com" ]]; then
    display --indent 6 --text "- migrate_resolve_dest_path: default mirrors PROJECTS_PATH" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_resolve_dest_path: default mirrors PROJECTS_PATH (got ${resolved})" --result "FAIL" --color RED
  fi

  resolved="$(migrate_resolve_dest_path "example.com" "/custom/path")"
  if [[ ${resolved} == "/custom/path" ]]; then
    display --indent 6 --text "- migrate_resolve_dest_path: override is respected" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_resolve_dest_path: override is respected (got ${resolved})" --result "FAIL" --color RED
  fi

  PROJECTS_PATH="${saved_projects_path}"

}

function test_migrate_check_dest_path_collision() {

  log_subsection "Test: migrate_check_dest_path_collision"

  # Stub ssh: a bash function shadows the `ssh` binary for this shell.
  # It simulates the destination path existing (exit 0) regardless of command.
  function ssh() { return 0; }

  if migrate_check_dest_path_collision "u" "h" "22" "/tmp/fake_key" "/var/www/example.com" "false" >/dev/null 2>&1; then
    display --indent 6 --text "- migrate_check_dest_path_collision: fails closed without --force" --result "FAIL" --color RED
  else
    display --indent 6 --text "- migrate_check_dest_path_collision: fails closed without --force" --result "PASS" --color WHITE
  fi

  if migrate_check_dest_path_collision "u" "h" "22" "/tmp/fake_key" "/var/www/example.com" "true" >/dev/null 2>&1; then
    display --indent 6 --text "- migrate_check_dest_path_collision: proceeds with --force" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_check_dest_path_collision: proceeds with --force" --result "FAIL" --color RED
  fi

  unset -f ssh

}

function test_migrate_decommission_source_guard() {

  log_subsection "Test: migrate_decommission_source (guard)"

  local called="false"
  function project_delete() { called="true"; return 0; }

  # Non-zero restore result must refuse, regardless of verification result
  called="false"
  migrate_decommission_source "example.com" "1" "0" "false" >/dev/null 2>&1
  if [[ ${called} == "false" ]]; then
    display --indent 6 --text "- migrate_decommission_source: refuses on failed restore" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_decommission_source: refuses on failed restore" --result "FAIL" --color RED
  fi

  # Non-zero verification result must refuse
  called="false"
  migrate_decommission_source "example.com" "0" "1" "false" >/dev/null 2>&1
  if [[ ${called} == "false" ]]; then
    display --indent 6 --text "- migrate_decommission_source: refuses on failed verification" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_decommission_source: refuses on failed verification" --result "FAIL" --color RED
  fi

  # Both zero: proceeds (project_delete gets called)
  called="false"
  migrate_decommission_source "example.com" "0" "0" "false" >/dev/null 2>&1
  if [[ ${called} == "true" ]]; then
    display --indent 6 --text "- migrate_decommission_source: proceeds on verified success" --result "PASS" --color WHITE
  else
    display --indent 6 --text "- migrate_decommission_source: proceeds on verified success" --result "FAIL" --color RED
  fi

  unset -f project_delete

}

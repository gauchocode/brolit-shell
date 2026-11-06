#!/usr/bin/env bash
# Regression tests for the conservative Compose deletion gate. No real Docker
# daemon, storage, or project resources are accessed.

source "$(dirname "${BASH_SOURCE[0]}")/../libs/local/project_helper.sh"

function test_compose_delete_safety() {
  local tmp events test_install_type test_project_type failed=0
  tmp="$(mktemp -d)"
  events="${tmp}/events"
  PROJECTS_PATH="${tmp}/projects"
  mkdir -p "${PROJECTS_PATH}/site"
  : > "${events}"
  function log_section() { :; }
  function log_subsection() { :; }
  function log_event() { printf '%s\n' "$*" >> "${events}"; }
  function display() { :; }
  function project_get_type() { printf '%s\n' "${test_project_type}"; }
  function docker_compose_stop() { echo stop >> "${events}"; }
  function docker_compose_rm() { echo remove >> "${events}"; }
  function backup_project() { echo backup >> "${events}"; return "${test_backup_rc:-1}"; }
  function storage_move() { echo move >> "${events}"; return "${test_storage_rc:-1}"; }
  function storage_create_dir() { :; }
  function project_get_configured_database() { :; }
  function project_get_configured_database_user() { :; }
  function project_get_configured_database_engine() { echo mysql; }
  function clear_previous_lines() { :; }

  local name location detected expected
  test_project_type=wordpress
  mkdir -p "${PROJECTS_PATH}/site/nested"
  for location in "${PROJECTS_PATH}/site" "${PROJECTS_PATH}/site/nested"; do
    for name in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
      : > "${location}/${name}"
      : > "${events}"
      detected="$(project_get_install_type "${PROJECTS_PATH}/site")"
      expected=default
      [[ ${name} == docker-compose.* ]] && expected=docker-compose
      if [[ ${detected} != "${expected}" ]]; then echo "FAIL: ${name} classified as ${detected}"; failed=1; fi
      if project_delete site true; then echo "FAIL: deletion allowed for ${location}/${name}"; failed=1; fi
      if project_delete_files site; then echo "FAIL: direct deletion allowed for ${location}/${name}"; failed=1; fi
      if grep -Eq '^(stop|remove|backup|move)$' "${events}" || [[ ! -f "${location}/${name}" ]]; then
        echo "FAIL: deletion changed ${location}/${name}"; failed=1
      fi
      if ! grep -q 'coverage is not verified' "${events}"; then echo "FAIL: missing coverage diagnostic for ${name}"; failed=1; fi
      rm -- "${location}/${name}"
    done
  done

  # Test both real deletion entry points, not just the filename helper. These
  # locations and variants are not classified as Docker by the legacy type
  # detector, so the deletion guard must independently catch them.
  local hint
  mkdir -p "${PROJECTS_PATH}/site/.hidden/deep" "${PROJECTS_PATH}/site/a/b/c"
  for hint in ".hidden/docker-compose.yml" ".hidden/deep/compose.yaml" \
              "a/b/c/docker-compose.prod.yml" "a/b/c/compose-staging.yaml"; do
    : > "${PROJECTS_PATH}/site/${hint}"
    : > "${events}"
    if project_delete site true; then echo "FAIL: deletion allowed for ${hint}"; failed=1; fi
    if project_delete_files site; then echo "FAIL: direct deletion allowed for ${hint}"; failed=1; fi
    if grep -Eq '^(stop|remove|backup|move)$' "${events}" || [[ ! -f "${PROJECTS_PATH}/site/${hint}" ]]; then
      echo "FAIL: deletion changed ${hint}"; failed=1
    fi
    rm -- "${PROJECTS_PATH}/site/${hint}"
  done

  # Custom Compose filenames cannot be identified reliably by filename, but
  # an explicit COMPOSE_FILE in any .env is an unambiguous reason to block.
  printf 'SECRET=do-not-log\nexport COMPOSE_FILE=custom-stack.yml\n' > "${PROJECTS_PATH}/site/.hidden/deep/.env"
  printf 'services:\n  app:\n    image: example\n' > "${PROJECTS_PATH}/site/.hidden/deep/custom-stack.yml"
  : > "${events}"
  if project_delete site true || project_delete_files site; then echo 'FAIL: COMPOSE_FILE allowed deletion'; failed=1; fi
  if grep -Eq '^(stop|remove|backup|move)$|do-not-log' "${events}"; then echo 'FAIL: COMPOSE_FILE guard leaked or changed state'; failed=1; fi
  rm -- "${PROJECTS_PATH}/site/.hidden/deep/.env"
  rm -- "${PROJECTS_PATH}/site/.hidden/deep/custom-stack.yml"

  ln -s missing "${PROJECTS_PATH}/site/.hidden/compose.yml"
  : > "${events}"
  if project_delete site true || project_delete_files site; then echo 'FAIL: Compose symlink allowed deletion'; failed=1; fi
  if grep -Eq '^(stop|remove|backup|move)$' "${events}"; then echo 'FAIL: Compose symlink changed state'; failed=1; fi
  rm -- "${PROJECTS_PATH}/site/.hidden/compose.yml"

  # Failed traversal and unreadable/dangling .env must not be treated as clear.
  : > "${events}"
  if ( function find() { return 2; }; project_delete site true ); then echo 'FAIL: failed scan allowed deletion'; failed=1; fi
  if ( function find() { return 2; }; project_delete_files site ); then echo 'FAIL: failed scan allowed direct deletion'; failed=1; fi
  ln -s missing "${PROJECTS_PATH}/site/.hidden/.env"
  if project_delete site true || project_delete_files site; then echo 'FAIL: unreadable dotenv allowed deletion'; failed=1; fi
  if grep -Eq '^(stop|remove|backup|move)$' "${events}"; then echo 'FAIL: uncertain scan changed state'; failed=1; fi
  rm -- "${PROJECTS_PATH}/site/.hidden/.env"
  mkfifo "${PROJECTS_PATH}/site/.hidden/.env"
  if project_delete site true || project_delete_files site; then echo 'FAIL: non-regular dotenv allowed deletion'; failed=1; fi
  rm -- "${PROJECTS_PATH}/site/.hidden/.env"

  # With the real install-type detector and no Compose hints, retain the
  # existing non-Docker behavior (mocks prevent actual removal).
  printf '# COMPOSE_FILE=example\nAPP=normal\n' > "${PROJECTS_PATH}/site/.hidden/.env"
  : > "${events}"
  if project_delete site true; then echo 'FAIL: failed ordinary backup accepted'; failed=1; fi
  if ! grep -q '^backup$' "${events}"; then echo 'FAIL: normal project blocked before backup'; failed=1; fi
  if project_delete_files site; then echo 'FAIL: failed storage move accepted'; failed=1; fi
  if ! grep -q '^move$' "${events}"; then echo 'FAIL: normal project blocked before storage move'; failed=1; fi
  rm -- "${PROJECTS_PATH}/site/.hidden/.env"
  mkdir -p "${PROJECTS_PATH}/ordinary"
  : > "${PROJECTS_PATH}/ordinary/content"
  test_storage_rc=0
  if ! project_delete_files ordinary || [[ -e "${PROJECTS_PATH}/ordinary" ]]; then echo 'FAIL: ordinary direct deletion did not complete'; failed=1; fi
  test_storage_rc=1

  # Exercise explicit Docker and unknown types separately from real detection.
  function project_get_install_type() { printf '%s\n' "${test_install_type}"; }
  for test_install_type in docker docker-compose; do
    : > "${events}"
    if project_delete site true; then echo "FAIL: Docker deletion succeeded"; failed=1; fi
    if project_delete_files site; then echo "FAIL: direct Docker deletion succeeded"; failed=1; fi
    if grep -Eq '^(stop|remove|backup|move)$' "${events}" || [[ ! -d "${PROJECTS_PATH}/site" ]]; then
      echo "FAIL: blocked deletion changed project state"; failed=1
    fi
    if ! grep -q 'coverage is not verified' "${events}"; then echo "FAIL: missing coverage diagnostic"; failed=1; fi
  done

  : > "${events}"
  test_install_type=""
  if project_delete site true; then echo "FAIL: unknown installation type accepted"; failed=1; fi
  if grep -Eq '^(stop|remove|backup|move)$' "${events}"; then echo "FAIL: unknown type changed state"; failed=1; fi

  : > "${events}"
  test_install_type=default
  if project_delete site true; then echo "FAIL: failed non-Docker backup accepted"; failed=1; fi
  if ! grep -q '^backup$' "${events}"; then echo "FAIL: non-Docker deletion did not reach existing backup"; failed=1; fi
  : > "${events}"
  test_backup_rc=2
  if project_delete site true; then echo "FAIL: nonzero backup accepted"; failed=1; fi
  if grep -q '^move$' "${events}"; then echo "FAIL: deletion continued after nonzero backup"; failed=1; fi
  if project_delete_files site; then echo "FAIL: failed storage move accepted"; failed=1; fi
  if ! grep -q '^move$' "${events}" || [[ ! -d "${PROJECTS_PATH}/site" ]]; then echo "FAIL: non-Docker deletion did not preserve existing behavior"; failed=1; fi
  rm -rf -- "${tmp}"
  return "${failed}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_compose_delete_safety
fi

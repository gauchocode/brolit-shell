#!/usr/bin/env bash
# Deleting a Docker project takes its stack down before removing the files: the
# files alone left the containers running (Admin delete of a migrated site).
# A stack that cannot be taken down keeps its files. No real Docker is used.

source "$(dirname "${BASH_SOURCE[0]}")/../libs/local/project_helper.sh" >/dev/null 2>&1

function test_project_delete_stops_stack() {
  local tmp calls failed=0
  tmp="$(mktemp -d)"; calls="${tmp}/calls"; : > "${calls}"
  PROJECTS_PATH="${tmp}/projects"
  mkdir -p "${PROJECTS_PATH}/shop" "${PROJECTS_PATH}/plain" "${tmp}/bin"
  cat > "${tmp}/bin/docker" <<'FAKE'
#!/usr/bin/env bash
echo "docker $*" >> "${FAKE_CALLS}"
[[ "${FAKE_DOWN_RC:-0}" != 0 && " $* " == *" down "* ]] && exit 1
exit 0
FAKE
  chmod +x "${tmp}/bin/docker"
  export FAKE_CALLS="${calls}" PATH="${tmp}/bin:${PATH}"

  function log_section() { :; }; function log_subsection() { :; }; function log_event() { :; }
  function display() { :; }; function clear_previous_lines() { :; }
  function project_get_type() { echo wordpress; }
  function project_get_install_type() { [[ "${1}" == *"/shop" ]] && echo docker-compose || echo default; }
  function project_compose_deletion_safe() { return 0; }
  function storage_create_dir() { :; }; function storage_move() { return 0; }
  function copy_files() { :; }

  export FAKE_DOWN_RC=0
  project_delete_files shop
  if [[ -e "${PROJECTS_PATH}/shop" ]]; then echo "FAIL: files kept after a clean down"; failed=1; fi
  if ! grep -q "down --remove-orphans" "${calls}" || ! grep -q "project-directory ${PROJECTS_PATH}/shop" "${calls}"; then echo "FAIL: stack not taken down from the project directory: $(cat "${calls}")"; failed=1; fi
  if grep -q -- " -v\| --volumes" "${calls}"; then echo "FAIL: volumes removed"; failed=1; fi
  echo "PASS: a Docker project's stack is taken down, then its files removed"

  mkdir -p "${PROJECTS_PATH}/shop"; : > "${calls}"
  export FAKE_DOWN_RC=1
  if project_delete_files shop; then echo "FAIL: deletion succeeded although the stack stayed up"; failed=1; fi
  [[ -d "${PROJECTS_PATH}/shop" ]] || { echo "FAIL: files removed although the stack stayed up"; failed=1; }
  echo "PASS: a stack that cannot be taken down keeps its files"

  : > "${calls}"; export FAKE_DOWN_RC=0
  project_delete_files plain
  if grep -q "docker" "${calls}"; then echo "FAIL: docker used for a non-Docker project"; failed=1; fi
  [[ -e "${PROJECTS_PATH}/plain" ]] && { echo "FAIL: plain project kept"; failed=1; }
  echo "PASS: a non-Docker project never touches docker"

  rm -rf "${tmp}"
  return ${failed}
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_project_delete_stops_stack || exit 1
  echo "All tests completed"
fi

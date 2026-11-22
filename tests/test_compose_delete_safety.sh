#!/usr/bin/env bash
# Regression tests for the conservative Compose deletion gate. No real Docker
# daemon, storage, or project resources are accessed.

source "$(dirname "${BASH_SOURCE[0]}")/../libs/local/project_helper.sh"

function test_compose_delete_safety() {
  local tmp events test_install_type test_project_type failed=0
  local saved_path="${PATH}"
  tmp="$(mktemp -d)"
  events="${tmp}/events"
  PROJECTS_PATH="${tmp}/projects"
  mkdir -p "${PROJECTS_PATH}/site"

  # Hermetic docker: the gate inspects the daemon, so every case runs against a
  # fake binary driven by a mode file instead of the host's Docker.
  FAKE_DOCKER_MODE="${tmp}/docker-mode"
  mkdir -p "${tmp}/bin"
  cat > "${tmp}/bin/docker" <<'FAKE'
#!/usr/bin/env bash
mode="$(cat "${FAKE_DOCKER_MODE:-/dev/null}" 2>/dev/null || printf 'clean')"
case "${1:-}" in
  ps)
    [[ "${mode}" == "broken" ]] && exit 1
    if [[ "${mode}" == "containers" ]]; then
      printf '%s\n' "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    fi
    exit 0
    ;;
  volume)
    [[ "${mode}" == "broken" ]] && exit 1
    if [[ "${mode}" == "volume" ]]; then
      shift
      [[ "${1:-}" == "ls" ]] && printf '%s\n' "site_data"
    fi
    exit 0
    ;;
  inspect)
    [[ "${mode}" == "broken" ]] && exit 1
    if [[ "${mode}" == "containers" ]]; then
      printf '{"id":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","project":"site","working_dir":"%s/projects/site","mounts":[{"Type":"bind","Source":"%s/projects/site/uploads","Destination":"/var/www/uploads"}]}\n' "${FAKE_PROJECTS_PATH}" "${FAKE_PROJECTS_PATH}"
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
FAKE
  chmod +x "${tmp}/bin/docker"
  printf 'clean' > "${FAKE_DOCKER_MODE}"
  PATH="${tmp}/bin:${PATH}"
  FAKE_PROJECTS_PATH="${PROJECTS_PATH}"
  export FAKE_DOCKER_MODE FAKE_PROJECTS_PATH PATH

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
      if [[ ${name} == docker-compose.* ]]; then
        # A Docker project with no uncovered persistent mount is deletable: the
        # gate lets it reach the mocked backup and storage move.
        if project_delete site true; then echo "FAIL: deletion succeeded with a failing backup for ${location}/${name}"; failed=1; fi
        if ! grep -q '^backup$' "${events}"; then echo "FAIL: Docker deletion blocked before backup for ${location}/${name}"; failed=1; fi
        if project_delete_files site; then echo "FAIL: direct deletion succeeded with a failing storage move for ${location}/${name}"; failed=1; fi
        if ! grep -q '^move$' "${events}"; then echo "FAIL: Docker deletion blocked before storage move for ${location}/${name}"; failed=1; fi
        if grep -Eq '^(stop|remove)$' "${events}" || [[ ! -f "${location}/${name}" ]]; then
          echo "FAIL: deletion changed ${location}/${name}"; failed=1
        fi
      else
        if project_delete site true; then echo "FAIL: deletion allowed for ${location}/${name}"; failed=1; fi
        if project_delete_files site; then echo "FAIL: direct deletion allowed for ${location}/${name}"; failed=1; fi
        if grep -Eq '^(stop|remove|backup|move)$' "${events}" || [[ ! -f "${location}/${name}" ]]; then
          echo "FAIL: deletion changed ${location}/${name}"; failed=1
        fi
        if ! grep -q 'coverage is not verified' "${events}"; then echo "FAIL: missing coverage diagnostic for ${name}"; failed=1; fi
      fi
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
    # A project with a running container bound to a directory inside the
    # project: the real production shape. Covered by the files backup, so the
    # gate lets it through to the mocked backup and storage move.
    mkdir -p "${PROJECTS_PATH}/site/uploads"
    : > "${events}"
    printf 'containers' > "${FAKE_DOCKER_MODE}"
    if project_delete site true; then echo "FAIL: Docker deletion succeeded with a failing backup"; failed=1; fi
    if ! grep -q '^backup$' "${events}"; then echo "FAIL: container with an in-project bind blocked before backup"; failed=1; fi
    if grep -q 'coverage is not verified' "${events}"; then echo "FAIL: covered container reported as uncovered"; failed=1; fi
    : > "${events}"
    if project_delete_files site; then echo "FAIL: direct Docker deletion succeeded with a failing storage move"; failed=1; fi
    if ! grep -q '^move$' "${events}"; then echo "FAIL: container with an in-project bind blocked before storage move"; failed=1; fi
    printf 'clean' > "${FAKE_DOCKER_MODE}"

    # Clean project: nothing persistent outside the project directory, so the
    # gate allows the deletion and it reaches the (mocked, failing) backup.
    : > "${events}"
    printf 'clean' > "${FAKE_DOCKER_MODE}"
    if project_delete site true; then echo "FAIL: Docker deletion succeeded with a failing backup"; failed=1; fi
    if ! grep -q '^backup$' "${events}"; then echo "FAIL: clean Docker project blocked before backup"; failed=1; fi
    if grep -Eq '^(stop|remove)$' "${events}"; then echo "FAIL: blocked deletion changed project state"; failed=1; fi
    : > "${events}"
    if project_delete_files site; then echo "FAIL: direct Docker deletion succeeded with a failing storage move"; failed=1; fi
    if ! grep -q '^move$' "${events}"; then echo "FAIL: clean Docker project blocked before storage move"; failed=1; fi

    # Leftover volume in the project namespace: blocked before any change.
    : > "${events}"
    printf 'volume' > "${FAKE_DOCKER_MODE}"
    if project_delete site true; then echo "FAIL: Docker deletion with an uncovered volume succeeded"; failed=1; fi
    if project_delete_files site; then echo "FAIL: direct Docker deletion with an uncovered volume succeeded"; failed=1; fi
    if grep -Eq '^(stop|remove|backup|move)$' "${events}" || [[ ! -d "${PROJECTS_PATH}/site" ]]; then
      echo "FAIL: volume-blocked deletion changed project state"; failed=1
    fi
    if ! grep -q 'coverage is not verified' "${events}"; then echo "FAIL: missing coverage diagnostic"; failed=1; fi
    if ! grep -q 'volume-namespace' "${events}"; then echo "FAIL: uncovered volume not named in the diagnostic"; failed=1; fi

    # A failed inspection is uncertain and must block.
    : > "${events}"
    printf 'broken' > "${FAKE_DOCKER_MODE}"
    if project_delete site true || project_delete_files site; then echo "FAIL: broken inspection allowed Docker deletion"; failed=1; fi
    if grep -Eq '^(stop|remove|backup|move)$' "${events}"; then echo "FAIL: broken inspection changed project state"; failed=1; fi
  done
  printf 'clean' > "${FAKE_DOCKER_MODE}"

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
  # Never leak the fake docker into the caller's PATH (the suite runs every
  # test in the same shell).
  PATH="${saved_path}"
  return "${failed}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_compose_delete_safety
fi

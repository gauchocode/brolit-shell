#!/usr/bin/env bash
# Verifies the guards that stop brolit-shell from purging or reinstalling Docker
# over an unhealthy package manager or a Docker that is in use:
#   package_dpkg_state          installed / absent / broken from dpkg abbreviations
#   package_manager_is_healthy  dpkg --audit must be empty
#   docker_purge                refuses while containers run
#   docker_apply_configuration  never purges or reinstalls a half-installed docker-ce
# dpkg, docker, service, rm and the logging helpers are replaced, so nothing on the
# machine is touched (no root needed).
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
CALLS="${TMP}/calls"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Replacements first, then the real functions.
log_event() { :; }
log_subsection() { :; }
display() { :; }
dpkg-query() { printf '%s' "${FAKE_ABBREV-}"; [[ -n "${FAKE_ABBREV-}" ]]; }
dpkg() { [[ "${1:-}" == "--audit" ]] && printf '%s' "${FAKE_AUDIT-}"; return 0; }
docker() {
  case "${1:-}" in
  info) return "${FAKE_DOCKER_INFO_RC:-0}" ;;
  ps) for ((i = 0; i < ${FAKE_RUNNING:-0}; i++)); do echo "container$i"; done ;;
  esac
}
package_purge() { echo "purge ${1}" >>"${CALLS}"; }
service() { echo "service $*" >>"${CALLS}"; }
rm() { echo "rm $*" >>"${CALLS}"; }          # never delete anything for real

{
  sed -n '/^function package_dpkg_state() {/,/^}/p;/^function package_manager_is_healthy() {/,/^}/p' "${ROOT_DIR}/libs/local/packages_helper.sh"
  sed -n '/^function docker_purge() {/,/^}/p;/^function docker_apply_configuration() {/,/^}/p' "${ROOT_DIR}/utils/installers/docker_installer.sh"
} >"${TMP}/fns.sh"
# shellcheck disable=SC1091
source "${TMP}/fns.sh"

calls() { cat "${CALLS}" 2>/dev/null | tr '\n' '|'; }
reset() { : >"${CALLS}"; unset FAKE_ABBREV FAKE_AUDIT FAKE_RUNNING FAKE_DOCKER_INFO_RC BROLIT_ALLOW_DOCKER_PURGE; }

# --- package_dpkg_state -------------------------------------------------------
state_of() { FAKE_ABBREV="${1}" package_dpkg_state docker-ce; }
for abbr in "ii " "hi "; do [[ "$(state_of "${abbr}")" == "installed" ]] || fail "'${abbr}' must be installed"; done
for abbr in "" "un " "rc " "pn "; do [[ "$(state_of "${abbr}")" == "absent" ]] || fail "'${abbr}' must be absent, got $(state_of "${abbr}")"; done
for abbr in "iU " "iF " "iH " "iW " "it " "iHR" "ri " "iUR"; do [[ "$(state_of "${abbr}")" == "broken" ]] || fail "'${abbr}' must be broken, got $(state_of "${abbr}")"; done

# --- package_manager_is_healthy -----------------------------------------------
FAKE_AUDIT="" package_manager_is_healthy || fail "an empty dpkg --audit must be healthy"
FAKE_AUDIT=$'The following packages have been unpacked but not yet configured.\n docker-ce' package_manager_is_healthy && fail "a non-empty dpkg --audit must be unhealthy"

# --- docker_purge: never while containers run ---------------------------------
reset; FAKE_RUNNING=3 docker_purge && fail "purge must refuse with running containers"
[[ -z "$(calls)" ]] || fail "a refused purge must not run anything: $(calls)"

reset; FAKE_RUNNING=3 BROLIT_ALLOW_DOCKER_PURGE=true docker_purge || fail "the explicit override must allow the purge"
grep -q "^purge docker-ce$" "${CALLS}" || fail "override: docker-ce not purged"
[[ "$(grep -c '^purge ' "${CALLS}")" == "9" ]] || fail "override: all nine packages are purged, got $(grep -c '^purge ' "${CALLS}")"

reset; FAKE_RUNNING=0 docker_purge || fail "purge with no containers must proceed"
grep -q "^purge docker-ce$" "${CALLS}" || fail "no containers: docker-ce not purged"

reset; FAKE_DOCKER_INFO_RC=1 FAKE_RUNNING=5 docker_purge || fail "a stopped daemon has nothing running to protect"
grep -q "^purge docker-ce$" "${CALLS}" || fail "stopped daemon: docker-ce not purged"

reset; ( unset -f docker; PATH=/nonexistent; docker_purge ) || fail "no docker CLI: purge must proceed"
grep -q "^purge docker-ce$" "${CALLS}" || fail "no docker CLI: docker-ce not purged"

# --- docker_apply_configuration ----------------------------------------------
docker_installer() { echo "install" >>"${CALLS}"; }

reset; FAKE_ABBREV="ii " docker_apply_configuration enabled || fail "enabled and installed must be a no-op success"
[[ -z "$(calls)" ]] || fail "enabled and installed must do nothing: $(calls)"

# The incident: docker-ce unpacked but not configured, Docker enabled, containers running.
reset; FAKE_ABBREV="iU " FAKE_RUNNING=14 docker_apply_configuration enabled && fail "a half-installed docker-ce must make it decline"
[[ -z "$(calls)" ]] || fail "a half-installed docker-ce must not be purged, reinstalled or restarted: $(calls)"

reset; FAKE_ABBREV="iU " FAKE_RUNNING=0 docker_apply_configuration enabled && fail "a half-installed docker-ce must decline even with nothing running"
[[ -z "$(calls)" ]] || fail "nothing may run: $(calls)"

reset; FAKE_ABBREV="" docker_apply_configuration enabled || fail "enabled and absent must install"
[[ "$(calls)" == *"purge docker-ce"*"|install|service docker restart|" ]] || fail "absent: purge, install, restart in order, got: $(calls)"

reset; FAKE_ABBREV="un " FAKE_RUNNING=2 docker_apply_configuration enabled && fail "absent but containers running: the purge refuses, so nothing may be installed over it"
[[ "$(calls)" != *install* && "$(calls)" != *service* ]] || fail "refused purge must stop the reinstall: $(calls)"

reset; FAKE_ABBREV="ii " FAKE_RUNNING=4 docker_apply_configuration disabled && fail "disabled with containers running must refuse to purge"
[[ -z "$(calls)" ]] || fail "disabled with containers running must do nothing: $(calls)"

reset; FAKE_ABBREV="ii " FAKE_RUNNING=0 docker_apply_configuration disabled || fail "disabled with nothing running purges"
grep -q "^purge docker-ce$" "${CALLS}" || fail "disabled and idle: docker-ce must be purged"

echo "package safety tests passed"

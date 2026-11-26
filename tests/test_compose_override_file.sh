#!/usr/bin/env bash
# `docker compose -f docker-compose.yml` ignores docker-compose.override.yml, which
# compose loads on its own when no -f is given: a site whose override adds a
# healthcheck, a port or an env var ran without it (containers `unhealthy`).
# docker_compose_run adds the override that goes with the base file. The docker
# binary is faked and records its arguments.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/apps/docker_helper.sh" >/dev/null 2>&1

function test_compose_override_file() {
  local tmp failed=0 got
  tmp="$(mktemp -d)"; mkdir -p "${tmp}/bin" "${tmp}/p"
  printf '#!/usr/bin/env bash\necho "$*" >> "${FAKE_CALLS}"\n' > "${tmp}/bin/docker"; chmod +x "${tmp}/bin/docker"
  export FAKE_CALLS="${tmp}/calls" PATH="${tmp}/bin:${PATH}"

  check() { # <label> <base file> <override to create> <expected args>
    : > "${FAKE_CALLS}"; rm -f "${tmp}"/p/*
    : > "${tmp}/p/${2}"; [[ -n "${3}" ]] && : > "${tmp}/p/${3}"
    docker_compose_run "${tmp}/p/${2}" up --detach
    got="$(cat "${FAKE_CALLS}")"
    local want="compose ${4} up --detach"; want="${want//@/${tmp}/p/}"
    if [[ "${got}" == "${want}" ]]; then echo "PASS: ${1}"; else echo "FAIL: ${1}: '${got}' != '${want}'"; failed=1; fi
  }

  check "docker-compose.yml + override.yml" docker-compose.yml docker-compose.override.yml "-f @docker-compose.yml -f @docker-compose.override.yml"
  check "docker-compose.yml + override.yaml" docker-compose.yml docker-compose.override.yaml "-f @docker-compose.yml -f @docker-compose.override.yaml"
  check "compose.yaml + compose.override.yml" compose.yaml compose.override.yml "-f @compose.yaml -f @compose.override.yml"
  check "no override: the base file alone" docker-compose.yml "" "-f @docker-compose.yml"
  check "an override of another stem is not used" docker-compose.yml compose.override.yml "-f @docker-compose.yml"
  check "a custom file name is used alone, as before" docker-compose.prod.yml docker-compose.override.yml "-f @docker-compose.prod.yml"

  rm -rf "${tmp}"
  return ${failed}
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_compose_override_file || exit 1
  echo "All tests completed"
fi

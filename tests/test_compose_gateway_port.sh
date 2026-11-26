#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# On a Proxmox guest in gateway mode the OpenResty gateway reaches a project at
# http://<internal address>:<port>. A compose file written for a server with its
# own nginx publishes that port on loopback only: the stack answered locally and
# the gateway timed out (jumpnetcorp.com.ar, 2026-11-26), so the migration
# failed its front-door check and rolled its DNS back.
#
# Pinned here: the project's web port gets a second entry on the internal address;
# databases and admin tools bound to loopback stay private; an entry already
# there is not duplicated (idempotent); outside gateway mode nothing changes; a
# result that compose cannot read is discarded. docker and ip are faked.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/apps/docker_helper.sh" >/dev/null 2>&1

function tcg_fakes() {

    local dir="${1}" docker_rc="${2:-0}"
    mkdir -p "${dir}/bin"
    cat > "${dir}/bin/ip" <<'FAKE'
#!/usr/bin/env bash
echo "1.1.1.1 via 10.2.0.1 dev ens18 src 10.2.0.104 uid 0"
FAKE
    cat > "${dir}/bin/docker" <<FAKE
#!/usr/bin/env bash
exit ${docker_rc}
FAKE
    chmod +x "${dir}/bin/ip" "${dir}/bin/docker"

}

function test_compose_gateway_port() {

    local failed=0 tmp
    tmp="$(mktemp -d)"
    function log_event() { :; }
    tcg_fakes "${tmp}"
    export PROXMOX_MODE="enabled" OPENRESTY_VM_IP="10.2.0.105"

    # 1. the loopback web port gets an internal twin, right before it
    cat > "${tmp}/a.yml" <<'YML'
services:
  nginx:
    ports:
        - '127.0.0.1:${WP_PORT}:80'
    networks:
      - internal
  mysql:
    ports:
      - "127.0.0.1:3306:3306"
  phpmyadmin:
    ports:
      - 127.0.0.1:${PHPMYADMIN_PORT}:80
YML
    PATH="${tmp}/bin:${PATH}" docker_compose_expose_on_internal_ip "${tmp}/a.yml"
    if grep -qxF "        - '10.2.0.104:\${WP_PORT}:80'" "${tmp}/a.yml" && grep -qxF "        - '127.0.0.1:\${WP_PORT}:80'" "${tmp}/a.yml"; then
        echo "PASS: the web port is published on the internal address, loopback kept"
    else echo "FAIL: web port: $(grep -n 'WP_PORT' "${tmp}/a.yml")"; failed=1; fi

    if ! grep -q "10.2.0.104:3306" "${tmp}/a.yml"; then echo "PASS: a database port stays on loopback"; else echo "FAIL: exposed the database"; failed=1; fi

    if ! grep -q "10.2.0.104:\${PHPMYADMIN_PORT}" "${tmp}/a.yml"; then echo "PASS: an admin tool on container port 80 (its own port variable) stays on loopback"; else echo "FAIL: exposed an admin tool"; failed=1; fi

    # 2. idempotent
    cp "${tmp}/a.yml" "${tmp}/a.once.yml"
    PATH="${tmp}/bin:${PATH}" docker_compose_expose_on_internal_ip "${tmp}/a.yml"
    cmp -s "${tmp}/a.yml" "${tmp}/a.once.yml" && echo "PASS: running it again changes nothing" || { echo "FAIL: not idempotent"; failed=1; }

    # 3. a site that was already edited by hand (the exito case) is left alone
    cat > "${tmp}/exito.yml" <<'YML'
services:
  nginx:
    ports:
      - '10.2.0.104:${WP_PORT}:80'
      - '127.0.0.1:${WP_PORT}:80'
YML
    cp "${tmp}/exito.yml" "${tmp}/exito.before"
    PATH="${tmp}/bin:${PATH}" docker_compose_expose_on_internal_ip "${tmp}/exito.yml"
    cmp -s "${tmp}/exito.yml" "${tmp}/exito.before" && echo "PASS: a compose file already published on the internal address is untouched" || { echo "FAIL: duplicated an existing entry"; failed=1; }

    # 4. a literal port counts only when the .env names it as the web port; one already open to every interface is left as is
    printf 'WP_PORT=8081\n' > "${tmp}/.env"
    cat > "${tmp}/b.yml" <<'YML'
services:
  web:
    ports:
      - "127.0.0.1:8081:80"
  admin:
    ports:
      - "127.0.0.1:8090:80"
  other:
    ports:
      - "8082:80"
YML
    PATH="${tmp}/bin:${PATH}" docker_compose_expose_on_internal_ip "${tmp}/b.yml"
    grep -qxF '      - "10.2.0.104:8081:80"' "${tmp}/b.yml" && ! grep -q "10.2.0.104:8082" "${tmp}/b.yml" && ! grep -q "10.2.0.104:8090" "${tmp}/b.yml" \
        && echo "PASS: the .env web port is handled; another literal port and an all-interfaces port are left as is" || { echo "FAIL: literal ports: $(cat "${tmp}/b.yml")"; failed=1; }

    # 5. outside gateway mode nothing happens
    cat > "${tmp}/c.yml" <<'YML'
services:
  nginx:
    ports:
      - '127.0.0.1:${WP_PORT}:80'
YML
    cp "${tmp}/c.yml" "${tmp}/c.before"
    PROXMOX_MODE="disabled" PATH="${tmp}/bin:${PATH}" docker_compose_expose_on_internal_ip "${tmp}/c.yml"
    cmp -s "${tmp}/c.yml" "${tmp}/c.before" && echo "PASS: outside gateway mode the file is not changed" || { echo "FAIL: changed a file outside gateway mode"; failed=1; }
    OPENRESTY_VM_IP="" PATH="${tmp}/bin:${PATH}" docker_compose_expose_on_internal_ip "${tmp}/c.yml"
    cmp -s "${tmp}/c.yml" "${tmp}/c.before" && echo "PASS: without a gateway address the file is not changed" || { echo "FAIL: changed without a gateway"; failed=1; }

    # 6. a result compose rejects is discarded
    tcg_fakes "${tmp}/bad" 1
    cp "${tmp}/c.before" "${tmp}/d.yml"
    PATH="${tmp}/bad/bin:${PATH}" docker_compose_expose_on_internal_ip "${tmp}/d.yml"
    cmp -s "${tmp}/d.yml" "${tmp}/c.before" && echo "PASS: an edit that compose cannot read is discarded" || { echo "FAIL: kept an invalid edit"; failed=1; }

    mkdir -p "${tmp}/bin-ip"; cp "${tmp}/bin/ip" "${tmp}/bin-ip/ip"
    # 7. validated the way the project is read: from its own directory (real docker, when available)
    if docker compose version >/dev/null 2>&1; then
        local real="${tmp}/real"; mkdir -p "${real}"
        # A bind mount defined by a variable of the .env is what made the file invalid
        # when it was checked from /tmp (jumpnetcorp: "invalid spec: :/var/lib/mysql").
        printf 'WP_PORT=83\nMYSQL_DATA_DIR=./mysql_data\n' > "${real}/.env"
        cat > "${real}/docker-compose.yml" <<'YML'
services:
  nginx:
    image: nginx:alpine
    ports:
      - '127.0.0.1:${WP_PORT}:80'
  mysql:
    image: mariadb:11
    volumes:
      - ${MYSQL_DATA_DIR}:/var/lib/mysql
YML
        PATH="${tmp}/bin-ip:${PATH}" docker_compose_expose_on_internal_ip "${real}/docker-compose.yml"
        if grep -q "10.2.0.104:\${WP_PORT}:80" "${real}/docker-compose.yml"; then
            echo "PASS: with real docker compose the edit is kept (the .env is read from the project directory)"
        else echo "FAIL: real docker compose rejected the edit: $(cat "${real}/docker-compose.yml")"; failed=1; fi
    else
        echo "SKIP: docker compose is not available here"
    fi

    # 8. wired into the build
    awk '/^function docker_compose_build/,/^}/' "${TEST_LOADER_DIR}/../libs/apps/docker_helper.sh" | grep -q "docker_compose_expose_on_internal_ip" \
        && echo "PASS: docker_compose_build calls it before building" || { echo "FAIL: not wired into the build"; failed=1; }

    rm -rf "${tmp}"
    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "Gateway mode publishes the web port on the internal address"
    echo "========================================="
    test_compose_gateway_port || exit 1
    echo "All tests completed"
fi

# Docker Port Collision Handling - Improvement Plan

## Context

When a Docker project is restored from backup, `docker_setup_configuration()` checks whether the port from `.env` is in use and searches for an alternative. The current system works but has performance, reliability, and usability deficiencies that worsen during batch restore (multiple projects restored sequentially).

### Functions involved

| Function | File | Role |
|---|---|---|
| `network_port_is_use()` | `libs/commons.sh:1089` | Check whether a port is in use (uses `lsof`) |
| `network_next_available_port()` | `libs/commons.sh:1118` | Find the next free port (uses `telnet`) |
| `docker_setup_configuration()` | `libs/local/restore_backup_helper.sh:2210` | Configure `.env` and bring up containers |
| `restore_project_backup()` | `libs/local/restore_backup_helper.sh:549` | Orchestrate full restore |
| `restore_backup_from_storage_batch()` | `libs/local/restore_backup_helper.sh:1429` | Batch restore of multiple projects |

## Identified problems

### P1: `network_next_available_port()` uses `telnet` (slow and unreliable)

**File:** `libs/commons.sh:1118`

```bash
echo -ne "\035" | telnet 127.0.0.1 "${port}" >/dev/null 2>&1
```

- Makes a full TCP connection attempt for each port (timeout if filtered).
- `telnet` may not be installed on all base images.
- For an 81-350 range, in the worst case it makes 269 connection attempts.
- If the port is filtered (not refused), the timeout blocks for several seconds.

**Solution:** Replace with `ss` or `lsof`, which query the kernel directly without opening connections.

```bash
function network_next_available_port() {
    local port_start="${1}"
    local port_end="${2}"

    local port
    local used_ports

    used_ports="$(ss -tlnH | awk '{print $4}' | grep -oP ':\d+$' | sort -u)"

    for port in $(seq "${port_start}" "${port_end}"); do
        if ! echo "${used_ports}" | grep -q ":${port}$"; then
            echo "${port}" && return 0
        fi
    done

    return 1
}
```

**Impact:** From ~30s (telnet with timeouts) to <1s.

---

### P2: `network_port_is_use()` uses `lsof` without optimization

**File:** `libs/commons.sh:1089`

```bash
result="$(lsof -i:"${port}")"
```

- `lsof` without `-P -n` performs reverse DNS resolution (slow).
- Does not filter only LISTEN (includes ESTABLISHED, TIME_WAIT, etc.).
- Stores the result in a variable that is not used for anything other than the check.

**Solution:**

```bash
function network_port_is_use() {
    local port="${1}"

    if ss -tlnH | grep -qP ":${port}\b"; then
        log_event "info" "Port ${port} is in use." "false"
        return 0
    else
        log_event "info" "Port ${port} is not in use." "false"
        return 1
    fi
}
```

**Note:** Unify both functions to use `ss` consistently. `ss` is available on all modern distros (it ships with `iproute2`).

---

### P3: No re-verification before `docker compose up`

**File:** `libs/local/restore_backup_helper.sh:2270`

The current flow:

```
1. Check port → assign in .env
2. docker_compose_build (which does up --detach --build)
```

Between step 1 and 2, an external process could have taken the port. Docker would fail with a cryptic bind error.

**Solution:** Add a verification immediately before the `up`, and if the bind fails, reassign the port automatically.

```bash
# In docker_setup_configuration(), before the build:
if network_port_is_use "${backup_port}"; then
    new_port="$(network_next_available_port "81" "350")"
    # update .env with new_port
fi

if ! docker_compose_build "..."; then
    # If it failed due to port, retry with a new port
    if docker_logs_contain_port_error "${project_name}"; then
        new_port="$(network_next_available_port "81" "350")"
        # update .env and retry
    fi
fi
```

---

### P4: Hardcoded port in `docker_setup_configuration()`

**File:** `libs/local/restore_backup_helper.sh:2251, 2306`

```bash
new_port="$(network_next_available_port "81" "350")"
```

The 81-350 range is hardcoded. It should come from configuration.

**Solution:** Add to `.brolit_conf.json`:

```json
{
    "DOCKER": {
        "port_range_start": "81",
        "port_range_end": "350"
    }
}
```

And read it from `brolit_configuration_manager.sh` as global variables `DOCKER_PORT_RANGE_START` and `DOCKER_PORT_RANGE_END`.

---

### P5: No logging of port assignments

When 10 projects are restored in batch, there is no way to see which port was assigned to each one after the process.

**Solution:** Log each assignment to the event log and show a summary table at the end of the batch.

In `restore_backup_from_storage_batch()`, add to the summary:

```
Batch Restore Summary
  - Total: 5
  - Successful: 5
  - Port assignments:
    - site1.example.com → port 81
    - site2.example.com → port 82
    - site3.example.com → port 83
```

---

### P6: `docker_setup_configuration()` mixes responsibilities

The function handles `.env` configuration + port checking + container build. For batch restore it would be useful to do only the configuration without bringing up containers, and bring them all up at the end in parallel.

**Solution (future):** Split into:
- `docker_configure_env()` — only modifies `.env` and assigns port
- `docker_build_and_up()` — does build + up

This would allow in batch restore: configure all `.env` files first, verify there are no collisions between them, and then bring up the containers.

---

## Implementation plan

### Phase 1: Replace telnet with ss (P1 + P2)

**Priority:** High
**Files:** `libs/commons.sh`
**Risk:** Low (ss is on every distro with iproute2)

1. Rewrite `network_next_available_port()` using `ss`
2. Rewrite `network_port_is_use()` using `ss`
3. Add fallback to `lsof` if `ss` is not available
4. Test with occupied and free ports

### Phase 2: Re-verification before the up (P3)

**Priority:** Medium
**Files:** `libs/local/restore_backup_helper.sh`
**Risk:** Low

1. Add port check immediately before `docker_compose_build`
2. If the port was taken, reassign and update `.env`
3. Add helper `docker_logs_contain_port_error()` to detect bind errors in Docker logs

### Phase 3: Configurable port (P4)

**Priority:** Medium
**Files:** `libs/local/restore_backup_helper.sh`, `utils/brolit_configuration_manager.sh`, config template
**Risk:** Low

1. Add `DOCKER` section to the config JSON
2. Load variables in `brolit_configuration_manager.sh`
3. Replace hardcoded `"81" "350"` with the variables

### Phase 4: Logging of assignments (P5)

**Priority:** Low
**Files:** `libs/local/restore_backup_helper.sh`
**Risk:** Low

1. Track port assignments during batch restore
2. Show table in the final summary
3. Include in the notification

### Phase 5: Separate configuration from build (P6)

**Priority:** Low (future)
**Files:** `libs/local/restore_backup_helper.sh`
**Risk:** Medium (refactoring)

1. Extract `docker_configure_env()` from `docker_setup_configuration()`
2. Extract `docker_build_and_up()`
3. Update callers (restore, borg restore, install)
4. Enable parallel up in batch restore

---

## Notes

- `ss` is part of `iproute2`, installed by default on Debian/Ubuntu.
- `ss -tlnH` shows TCP ports in LISTEN state, without resolving names (-n), without header (-H).
- The 81-350 range was chosen to avoid conflicts with well-known ports (0-80) and common services (443, 3306, 5432, 8080, etc.).

# Database Restore Flow Redesign

## Context

When restoring a database-only backup for Docker projects, the current flow has several
bugs and UX problems. The database import falls back to the host MySQL client instead of
using `docker exec` against the running container, and the user interaction order is
illogical.

## Problems Identified

### P1: `grep PROJECT_NAME` matches `COMPOSE_PROJECT_NAME`

**File:** `libs/local/restore_backup_helper.sh:2120`

```bash
docker_project_name="$(grep PROJECT_NAME "${docker_env_file}" | cut -d '=' -f2)"
```

A typical Docker `.env` file contains both:

```
COMPOSE_PROJECT_NAME=prod_wasabi_stack     # matches!
PROJECT_NAME=wasabi_prod                   # matches!
```

`grep PROJECT_NAME` returns **two lines**, so `docker_project_name` becomes
`"prod_wasabi_stack\nwasabi_prod"` (with embedded newline). The container name then
becomes `"prod_wasabi_stack\nwasabi_prod_mysql"`, which breaks `docker exec`.

**Fix:** Use anchored pattern `grep '^PROJECT_NAME='` to match only the exact variable.

### P2: Illogical user interaction order

**File:** `libs/local/restore_backup_helper.sh:2076-2111`

```
1. Parse stage from database name (broken)
2. Ask user for stage
3. Ask user for project name
4. Decompress backup
5. Ask "Is this associated to an existing project?"
```

Stage and project name are asked **before** knowing whether the user will select an
existing project. If they do select one, the previously entered values are either
ignored or used incorrectly.

**Fix:** Move the "associated to existing project?" question to step 1, and only ask for
stage/name in the "new project" branch.

### P3: Stage/name parsing logic is broken

**File:** `libs/local/restore_backup_helper.sh:2077-2082`

```bash
suffix=${chosen_project%_*}                  # "wasabi_prod" → "wasabi"
project_stage="$(project_ask_stage "${suffix}")"  # suggests "wasabi" as stage (wrong)
possible_project_name=${chosen_project%$suffix}   # "wasabi_prod" → no change
```

For input `wasabi_prod`:
- Suffix extraction gives `wasabi` (assumes `_prod` is the stage suffix)
- Stage suggestion shows `wasabi` instead of `prod`
- Project name extraction fails (no trailing `wasabi` in `wasabi_prod`)

**Fix:** Remove the parsing entirely. Derive information from the selected project when
available, or ask the user in the new-project branch.

### P4: `MYSQL_USER` and `MYSQL_PASSWORD` read from `.env` but unused

**File:** `libs/local/restore_backup_helper.sh:2122-2123`

```bash
docker_mysql_user="$(grep MYSQL_USER "${docker_env_file}" | cut -d '=' -f2)"
docker_mysql_user_pass="$(grep MYSQL_PASSWORD "${docker_env_file}" | cut -d '=' -f2)"
```

These variables are read from the `.env` file but never passed to `database_import()`.
The credentials are fetched directly from the running container via
`docker exec printenv MYSQL_USER` inside `mysql_database_import()`.

**Fix:** Remove these unused reads.

### P5: `project_stage` unused in `restore_backup_database()`

**File:** `libs/local/restore_backup_helper.sh:1899`

```bash
local project_stage="${2}"  # parameter is declared but never used in the function body
```

The value is accepted but never referenced. Carried over from older code.

**Note:** Not fixed in this change, but noted for future cleanup.

## Previous fixes (already applied)

These were identified and fixed before the flow redesign:

1. **`libs/database_controller.sh:197`** — `mysql_database_import()` received hardcoded
   `"false"` as `container_name` instead of the actual `container_name` parameter.
2. **`libs/local/restore_backup_helper.sh:2135-2137`** — MySQL container name was never
   built (only PostgreSQL was handled).

## Implementation Plan

### Step 1: Redesign `restore_backup_project_database()`

**File:** `libs/local/restore_backup_helper.sh`

New flow:

```
restore_backup_project_database()
│
├── 1. Decompress backup file
│
├── 2. "Associated to an existing project?"
│   │
│   ├── YES ──► Browse project directory
│   │           ├── Detect install_type
│   │           │
│   │           ├── Docker:
│   │           │   ├── Read .env (anchored grep)
│   │           │   ├── Build container_name
│   │           │   └── database_import() with container
│   │           │
│   │           └── Host:
│   │               ├── Read project config
│   │               └── restore_backup_database()
│   │
│   └── NO  ──► Ask stage + project name
│               ├── Generate credentials
│               └── restore_backup_database()
```

### Step 2: Anchor grep patterns

**File:** `libs/local/restore_backup_helper.sh`

Change `grep PROJECT_NAME` to `grep '^PROJECT_NAME='` and apply the same to
`MYSQL_DATABASE`, `MYSQL_USER`, and `MYSQL_PASSWORD`.

### Step 3: Remove dead `.env` reads

**File:** `libs/local/restore_backup_helper.sh`

Remove `docker_mysql_user` and `docker_mysql_user_pass` reads since they are never
consumed by the Docker import path.

## Files affected

| File | Changes |
|------|---------|
| `libs/local/restore_backup_helper.sh` | Restructure function, anchor grep, remove dead code |
| `libs/database_controller.sh` | Already fixed (pass `container_name`) |

## Test scenarios

1. **Docker project, database-only restore, existing project:**
   - Select server → database type → pick backup → say "yes" to existing project
   - Select project dir → docker-compose detected
   - Verify `docker exec -i <container> mysql -u<user> -p<pass> < db.sql` is executed

2. **Host project, database-only restore, existing project:**
   - Same flow but project is host-based
   - Verify host mysql import is used

3. **Database-only restore, new project:**
   - Say "no" to existing project → enter stage and name
   - Verify credentials are generated and import succeeds

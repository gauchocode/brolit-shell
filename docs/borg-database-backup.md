# Database backups with Borg

Servers where Borg is the only backup method have no other way to hold a database
dump. This feature backs up every database of the server into Borg, consistently,
and says in the report what is covered and what is not. Design and decisions:
`docs/plan/active/2026-11-borg-database-protection.md` in brolit-admin.

## When it runs

`BACKUPS.config[0].databases.borg` in `/root/.brolit_conf.json`:

| Value | Behaviour |
|---|---|
| `auto` (default, also when the key is absent) | In use only when Borg is the only method that can hold a dump, i.e. Dropbox, SFTP and Local are all disabled. Servers that also use one of them keep dumping through it, untouched. |
| `enabled` | In use on this server whatever the other methods are. |
| `disabled` | Never. |

## What it does every night

1. If borgmatic is older than 2.0.8 it is raised (`pipx upgrade borgmatic`), once, logged.
2. The shell builds the **inventory** of the server: database services of Compose projects, other
   running database containers, and the MySQL/MariaDB installed on the host.
3. Every database is resolved to a state (below) and the configs are converged:
   `/etc/borgmatic.d/databases/<project>.yml` for the databases of a project and
   `/etc/borgmatic.d/databases/standalone-<source>-<database>.yml` for each standalone one.
   A config is only written when borgmatic accepts it; the previous one stays otherwise.
   Configs that are no longer expected are moved to `/etc/borgmatic.d/databases/.retired/`, never deleted.
4. After the files backups, each database config is run through the same path as every other config
   (repository initialisation, network retries, stale-lock handling, classified failure reason).

The dump runs inside the container (`utils/borg/db_exec.sh`): the superuser credential is read by the
container from its own environment and never reaches the host.

## Who owns a database

Evidence, strongest first: **structure** (the compose working directory, or a data bind mount inside the
project), a **recorded decision**, **file references** (`.env`, `wp-config.php`, compose files), then
liveness and name similarity, which never decide alone. Only structure and decisions link automatically; a
file reference links only if exactly one project names the database and exactly one source holds that name.

| State | Meaning | Dumped |
|---|---|---|
| `linked` | Belongs to a project | Yes, in the project's database config |
| `standalone` | Its own config, no project | Yes |
| `held` | Pending a decision, large (`BROLIT_DB_HELD_MIN_MB`, 2048) and without writes since the engine started (at least `BROLIT_DB_DORMANT_MIN_UPTIME`, 4 h) | **No**, until someone decides |
| `ignored` | Decided not to back it up | No |

A database nobody can place is **pending**: it is dumped as standalone (unless held) and reported so a person
decides. Decisions live in the server configuration:

```json
"BACKUPS": { "config": [ { "databases": { "borg": "auto", "decisions": [
  { "source": "host", "database": "old_copy", "decision": "ignore" },
  { "source": "host", "database": "shop", "decision": "link", "project": "shop.example.com" },
  { "source": "castinera-staging_mariadb", "database": "stage", "decision": "standalone" }
] } } ] } }
```

`source` is `host`, a container name, or `<project>/<service>` for a Compose service.

## Restoring

List what an archive holds:

```bash
borgmatic list -c /etc/borgmatic.d/databases/<project>.yml --archive latest
# run/user/0/borgmatic/<engine>_databases/<container or localhost>/<database>
```

Restore with borgmatic. **This writes into the server the config points at, which is the live one**:

```bash
borgmatic restore -c /etc/borgmatic.d/databases/<project>.yml --archive latest --database <name>
```

To rehearse (or to recover into another container) copy the config and point the client command at the
target, for MariaDB `mariadb_command: "<shell>/utils/borg/db_exec.sh client mariadb <target container>"`
(`mysql` for MySQL, `psql_command` and `pg_restore_command` with `postgres` for PostgreSQL), then compare
table counts, row counts and `CHECKSUM TABLE` with the source. Restore a MySQL 8 dump into MySQL 8, not
MariaDB (collations differ). On a server being recovered the PostgreSQL restore creates the database when
it is missing.

## Reading the report

- "Database Backup": per database `Borg: <project>`, `Borg: standalone`, `HELD, decision pending`,
  `IGNORED`, or `NOT BACKED UP, engine not supported`. It is an error only when the configuration step
  failed (borgmatic too old and not raisable, or a rendered config rejected).
- "Borg Backup": one line per config, `<project> (database)`. A failing dump is the class `database_dump`
  and does not affect the files backup of the same project.

## Limits of this release

- PostgreSQL on the host is not supported (no server of the fleet has one). Engines borgmatic cannot dump
  here (ClickHouse, MongoDB, ...) are reported as unsupported, never ignored silently. Redis, Valkey and
  Memcached are treated as caches, MinIO as files.
- Databases on another host (host and port from a project's environment) are not covered yet.
- Minimum borgmatic 2.0.8 (verified on 2.0.8, 2.1.10 and 2.2.0).
- The database repositories keep daily 7, weekly 4, monthly 6, yearly 1; making it configurable by
  organization, server and project is planned (`2026-11-backup-retention-policies.md`).

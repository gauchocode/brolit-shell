## Running tasks without menu

```
Options:
    -t, --task         Task to run:
                         backup
                         restore
                         project-install
                         cloudflare-api
    -st, --subtask     Sub-task to run:
                         for backup: all, files, databases
                         for cloudflare-api: clear_cache, dev_mode
    -tv, --tvalue      Task aditional value
    -nd, --new-domain  New domain (for restore with clone to different domain)
    -rd, --redirect-domains  Comma-separated redirect domains (for openresty create-route)
    -sm, --storage-method  Force a specific storage method (dropbox|local|borg)
                       for restore -st from-storage / migrate, instead of the
                       default auto-priority (Dropbox > Local > Borg)
    --source-server    Look under this server name's namespace in storage
                       instead of this server's own hostname (for restore
                       -st from-storage; used internally by migrate
                       --transport dropbox)
    --local-staging-path  Use this path instead of BACKUPS.methods.local's
                       configured backup_path, skipping the "local storage
                       enabled" check entirely (for restore -st from-storage
                       with --storage-method local; used internally by
                       migrate --transport local, which never depends on or
                       enables the persistent local backup config)
    --transport        Transport for migrate: "local" (default, direct rsync,
                       requires BACKUPS.methods.local on both servers) or
                       "dropbox" (reuses an already-configured shared Dropbox
                       account, no local storage required, slower)
    --dest-host        Destination server host/IP (for migrate)
    --dest-user        Destination server SSH user (for migrate)
    --dest-port        Destination server SSH port (for migrate, default 22)
    --dest-ssh-key     Path to the SSH private key for the destination (for migrate)
    --dest-path        Override the destination project path (for migrate, optional)
    --decommission-source  After a verified migration, stop and remove the source
                       project (Docker stack, files, nginx vhost, certs). IRREVERSIBLE.
                       Docker volumes are preserved unless --purge-volumes is also passed.
    --purge-volumes    Combined with --decommission-source, also deletes the source
                       project's Docker volumes. IRREVERSIBLE DATA LOSS.
    --bootstrap-dest-config  If the destination is missing Cloudflare/certbot config,
                       copy the Cloudflare config section from this server to the
                       destination (for migrate)
    --force            Overwrite an existing destination path (for migrate)
    -s,  --site        Site path for tasks execution
    -d,  --domain      Domain for tasks execution
    -pn, --pname       Project Name
    -pt, --ptype       Project Type (wordpress,laravel)
    -ps, --pstate      Project Stage (prod,dev,test,stage)
    -q,  --quiet       Quiet (no output)
    -v,  --verbose     Output more information. (Items echoed to 'verbose')
    -d,  --debug       Runs script in BASH debug mode (set -x)
    -h,  --help        Display this help and exit
         --version     Output version information and exit
```

## Some examples

### Backup

#### Backup All (files, config and databases)

```
./runner.sh --task "backup" --subtask "all"
```

#### Backup Files

```
./runner.sh --task "backup" --subtask "files"
```

#### Backup Server Config Files

```
./runner.sh --task "backup" --subtask "server-config"
```

#### Backup Databases (NOT IMPLEMENTED YET)

```
./runner.sh --task "backup" --subtask "databases"
```

#### Backup Project

```
./runner.sh --task "backup" --subtask "project" --domain "example.domain.com"
```

### Project Utils

#### Create WordPress Project

```
./runner.sh --task "project" --subtask "install" --ptype "wordpress" --domain "example.domain.com" --pname "project_name" --pstate "prod"
```

#### Delete Project

```
./runner.sh --task "project" --subtask "delete" --domain "example.domain.com"
```

#### Restore a Files Backup (NOT IMPLEMENTED YET)

```
./runner.sh --task "restore" --subtask "files" --link "linkt_to_compressed_backup.tar.gz" --domain "example.domain.com" --pname "project_name" --pstate "prod"
```

#### Restore a Database Backup (NOT IMPLEMENTED YET)

```
./runner.sh --task "restore" --subtask "database" --link "linkt_to_compressed_backup.tar.gz" --domain "example.domain.com" --pname "project_name" --pstate "prod"
```

#### Restore a Project Backup (NOT IMPLEMENTED YET)

```
./runner.sh --task "restore" --subtask "project" --domain "example.domain.com" --pname "project_name" --pstate "prod"
```

#### Restore a Project Backup from Storage (clone to new domain)

```
./runner.sh --task "restore" --subtask "from-storage" --domain "example.domain.com" --task-value "2026-06-09" --new-domain "staging.example.com"
```

### Database Manager

#### List all databases

```
./runner.sh --task "database" --subtask "list_db" --dbstage "all"
```

#### Create database

```
./runner.sh --task "database" --subtask "create_db" --dbname "broobe_test"
```

#### Delete database

```
./runner.sh --task "database" --subtask "delete_db" --dbname "broobe_test"
```

### Cloudflare API

#### Clear Cloudflare Cache

```
./runner.sh --task "cloudflare-api" --subtask "clear_cache" --domain "gauchocode.com"
```

#### Enable Dev Mode

```
./runner.sh --task "cloudflare-api" --subtask "dev_mode" --task-value "on" --domain "gauchocode.com" 
```

#### Change SSL Mode
##### Values: off, valid values: off, flexible, full, strict

```
./runner.sh --task "cloudflare-api" --subtask "ssl_mode" --task-value "full" --domain "gauchocode.com" 
```

### WP-CLI API

#### Install WP Plugin
##### Values: plugins-slugs or link with zip file
##### Examples: "wordpress-seo", "post-smtp", "https://link.to.zip"

```
./runner.sh --task "wpcli" --subtask "plugin-install" --task-value "post-smtp" --domain "gauchocode.com"
```

#### Activate WP Plugin

```
./runner.sh --task "wpcli" --subtask "plugin-activate" --task-value "post-smtp" --domain "gauchocode.com"
```

#### Deactivate WP Plugin

```
./runner.sh --task "wpcli" --subtask "plugin-deactivate" --task-value "post-smtp" --domain "gauchocode.com"
```

#### Update WP Plugin

```
./runner.sh --task "wpcli" --subtask "plugin-update" --task-value "post-smtp" --domain "gauchocode.com"
```

#### Get WP Plugin version

```
./runner.sh --task "wpcli" --subtask "plugin-version" --task-value "post-smtp" --domain "gauchocode.com"
```

#### Clear WP Rocket Cache

```
./runner.sh --task "wpcli" --subtask "clear-cache" --domain "gauchocode.com"
```

#### Activate WP Rocket Cache

```
./runner.sh --task "wpcli" --subtask "cache-activate" --domain "gauchocode.com" 
```

#### Deactivate WP Rocket Cache

```
./runner.sh --task "wpcli" --subtask "cache-deactivate" --domain "gauchocode.com" 
```

#### Verify WP Installation

```
./runner.sh --task "wpcli" --subtask "verify-installation" --domain "gauchocode.com" 
```

#### Update WP Installation

```
./runner.sh --task "wpcli" --subtask "core-update" --domain "gauchocode.com" 
```

#### Search and Replace URLs (NOT IMPLEMENTED YET)

```
./runner.sh --task "wpcli" --subtask "search-replace" --path "/path/to/wordpress" --old "https://old.domain.com" --new "https://new.domain.com"
```

### Site Migration

Migrates a **Dockerized** project from this server (source) to a destination server, over SSH. Run only from the source. Requires brolit-shell on the destination (installed/bootstrapped automatically if missing) with local backup storage, Cloudflare, and certbot configured there, since the destination's own `restore -st from-storage` handles the vhost, DNS, and SSL steps automatically.

#### Migrate a site (verify only, source untouched)

```
./runner.sh --task "migrate" --subtask "site" --domain "example.com" \
  --dest-host "10.2.0.200" --dest-user "root" --dest-ssh-key "~/.ssh/id_ed25519"
```

#### Migrate a site and decommission the source once verified

```
./runner.sh --task "migrate" --subtask "site" --domain "example.com" \
  --dest-host "10.2.0.200" --dest-user "root" --dest-ssh-key "~/.ssh/id_ed25519" \
  --decommission-source
```

Recommended usage is two-phase: run once without `--decommission-source`, manually confirm the migrated site on the destination, then re-run with `--decommission-source --force` to clean up the source. `--purge-volumes` (only meaningful with `--decommission-source`) additionally deletes the source project's Docker volumes and should only be used once you're certain the migration is correct - it is irreversible data loss.

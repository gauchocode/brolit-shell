## Running tasks without menu

```
Options:
    -t, --task        Task to run:
                        backup
                        restore
                        project-install
                        cloudflare-api
    -st, --subtask    Sub-task to run:
                        for backup: all, files, databases
                        for cloudflare-api: clear_cache, dev_mode
    -s  --site        Site path for tasks execution
    -d  --domain      Domain for tasks execution
    -pn --pname       Project Name
    -pt --ptype       Project Type (wordpress,laravel)
    -ps --pstate      Project State (prod,dev,test,stage)
    -q, --quiet       Quiet (no output)
    -v, --verbose     Output more information. (Items echoed to 'verbose')
    -d, --debug       Runs script in BASH debug mode (set -x)
    -h, --help        Display this help and exit
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

### Project Utils

#### Create WordPress Project (NOT IMPLEMENTED YET)

```
./runner.sh --task "project" --subtask "install" --ptype "wordpress" --domain "example.domain.com" --pname "project_name" --pstate "prod"
```

#### Delete Project (NOT IMPLEMENTED YET)

```
./runner.sh --task "project" --subtask "delete" --domain "example.domain.com" --pname "project_name"
```

#### Restore a Files Backup (NOT IMPLEMENTED YET)

```
./runner.sh --task "restore" --subtask "files" --link "linkt_to_compressed_backup.tar.gz" --domain "example.domain.com" --pname "project_name"
```

#### Restore a Database Backup (NOT IMPLEMENTED YET)

```
./runner.sh --task "restore" --subtask "database" --link "linkt_to_compressed_backup.tar.gz" --domain "example.domain.com" --pname "project_name"
```

### WP-CLI

#### Search and Replace URLs (NOT IMPLEMENTED YET)

```
./runner.sh --task "wp-cli" --subtask "replace-urls" --path "/path/to/wordpress" --old "https://old.domain.com" --new "https://new.domain.com"
```

### Cloudflare API

#### Clear Cloudflare Cache

```
./runner.sh --task "cloudflare-api" --subtask "clear_cache" --domain "broobe.com"
```
#### Enable Dev Mode

```
./runner.sh --task "cloudflare-api" --subtask "dev_mode" --domain "broobe.com"
```
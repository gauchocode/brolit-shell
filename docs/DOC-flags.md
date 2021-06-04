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
    -s,  --site        Site path for tasks execution
    -d,  --domain      Domain for tasks execution
    -pn, --pname       Project Name
    -pt, --ptype       Project Type (wordpress,laravel)
    -ps, --pstate      Project State (prod,dev,test,stage)
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

### Project Utils

#### Create WordPress Project

```
./runner.sh --task "project-install" --ptype "wordpress" --domain "example.domain.com" --pname "project_name" --pstate "prod"
```

#### Delete Project

```
./runner.sh --task "project-delete" --domain "example.domain.com"
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

### Cloudflare API

#### Clear Cloudflare Cache

```
./runner.sh --task "cloudflare-api" --subtask "clear_cache" --domain "broobe.com"
```

#### Enable Dev Mode

```
./runner.sh --task "cloudflare-api" --subtask "dev_mode" --task-value "on" --domain "broobe.com" 
```

#### Change SSL Mode
##### Values: off, valid values: off, flexible, full, strict

```
./runner.sh --task "cloudflare-api" --subtask "ssl_mode" --task-value "full" --domain "broobe.com" 
```

### WP-CLI API

#### Install WP Plugin
##### Values: plugins-slugs or link with zip file
##### Examples: "wordpress-seo", "post-smtp", "https://link.to.zip"

```
./runner.sh --task "wpcli" --subtask "plugin-install" --task-value "post-smtp" --domain "broobe.com"
```

#### Activate WP Plugin

```
./runner.sh --task "wpcli" --subtask "plugin-activate" --task-value "post-smtp" --domain "broobe.com"
```

#### Deactivate WP Plugin

```
./runner.sh --task "wpcli" --subtask "plugin-deactivate" --task-value "post-smtp" --domain "broobe.com"
```

#### Clear WP Rocket Cache

```
./runner.sh --task "wpcli" --subtask "clear-cache" --domain "broobe.com"
```

#### Activate WP Rocket Cache

```
./runner.sh --task "wpcli" --subtask "cache-activate" --domain "broobe.com" 
```

#### Deactivate WP Rocket Cache

```
./runner.sh --task "wpcli" --subtask "cache-deactivate" --domain "broobe.com" 
```

#### Verify WP Installation

```
./runner.sh --task "wpcli" --subtask "verify-installation" --domain "broobe.com" 
```

#### Update WP Installation

```
./runner.sh --task "wpcli" --subtask "core-update" --domain "broobe.com" 
```

#### Search and Replace URLs (NOT IMPLEMENTED YET)

```
./runner.sh --task "wpcli" --subtask "search-replace" --path "/path/to/wordpress" --old "https://old.domain.com" --new "https://new.domain.com"
```
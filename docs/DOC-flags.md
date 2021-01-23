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

#### Backup Files

```
./runner.sh --task "backup" --subtask "files"
```

#### Backup Serer Config Files

```
./runner.sh --task "backup" --subtask "server-config"
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
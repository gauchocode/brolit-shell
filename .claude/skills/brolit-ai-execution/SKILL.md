# Brolit Shell — AI Execution Skill

## Description

Guide AI assistants through brolit operations without interactive prompts. Use this skill when executing brolit commands programmatically or when the user requests automation.

## Purpose

Enable AI assistants to execute brolit operations (backup, restore, database management, etc.) via CLI without requiring terminal interaction or whiptail menus.

## Workflow

### Step 1: Understand the Request

Map user request to brolit task:

| User Request | Brolit Command |
|---|---|
| "backup site X" | `./runner.sh -t backup -st project -D X` |
| "backup all" | `./runner.sh -t backup -st full-report` |
| "restore site X" | `./runner.sh -t restore -st from-storage -D X` |
| "restore from file" | `./runner.sh -t restore -st from-local -D X -tf /path/to/backup.tar.gz` |
| "list databases" | `./runner.sh -t database -st list_db` |
| "export database" | `./runner.sh -t database -st export_db -db DBNAME` |
| "check server" | `./runner.sh -t server-status` |
| "check certificates" | `./runner.sh -t server-status -st certs` |
| "scan for malware" | `./runner.sh -t security-scan` |

### Step 2: Validate Prerequisites

```bash
# Check brolit is installed
ls -la /usr/local/bin/brolit

# Check running as root
whoami

# Check config exists
cat ~/.brolit_conf.json | jq .SERVER_NAME

# Check backup method enabled
cat ~/.brolit_conf.json | jq .BACKUPS
```

### Step 3: Execute with Error Handling

```bash
# Always capture output
output=$(./runner.sh -t backup -st project -D example.com 2>&1)
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  echo "Error (exit code: $exit_code): $output"
  # Suggest fix based on error
fi
```

### Step 4: Verify Result

```bash
# For backup: check backup location
ls -la /path/to/backups/

# For restore: check site
curl -I https://example.com

# For database: list databases
./runner.sh -t database -st list_db
```

## Common Commands Reference

### Backup Operations

```bash
# Single project
./runner.sh -t backup -st project -D example.com

# All databases
./runner.sh -t backup -st databases

# Server config
./runner.sh -t backup -st server-config

# Full backup with report
./runner.sh -t backup -st full-report
```

### Restore Operations

```bash
# From storage (latest)
./runner.sh -t restore -st from-storage -D example.com

# From storage (specific date)
./runner.sh -t restore -st from-storage -D example.com -tv 2026-06-09

# From local file
./runner.sh -t restore -st from-local -D example.com -tf /path/to/backup.tar.gz

# From URL
./runner.sh -t restore -st from-url -D example.com -tf https://example.com/backup.tar.gz

# From Borg
./runner.sh -t restore -st from-borg -D example.com
```

### Database Operations

```bash
# List databases
./runner.sh -t database -st list_db

# Export database
./runner.sh -t database -st export_db -db mydb_prod

# Import database
./runner.sh -t database -st import_db -db mydb_prod -tf /path/to/dump.sql

# Create database
./runner.sh -t database -st create_db -db mydb_new

# Delete database
./runner.sh -t database -st delete_db -db mydb_old
```

### Server Operations

```bash
# Full status
./runner.sh -t server-status

# Disk usage
./runner.sh -t server-status -st disk

# SSL certificates
./runner.sh -t server-status -st certs

# Security scan
./runner.sh -t security-scan

# Disk cleanup
./runner.sh -t disk-cleanup -st all
```

## Error Handling

### Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| "Missing required parameters" | Missing `-D` flag | Add `-D domain.com` |
| "Invalid subtask" | Wrong `-st` value | Check valid subtasks with `--help` |
| "Permission denied" | Not running as root | Run with `sudo` |
| "Config not found" | Missing `~/.brolit_conf.json` | Run server setup first |
| "Domain not found" | Project doesn't exist | Verify domain in `/var/www/` |
| "Backup file not found" | Invalid file path | Check path with `ls -la` |

### Error Output Format

```bash
# Capture both stdout and stderr
output=$(./runner.sh -t backup -st project -D example.com 2>&1)
exit_code=$?

# Parse output for errors
if echo "$output" | grep -q "ERROR\|FAIL"; then
  echo "Operation failed"
  echo "$output" | grep -A5 "ERROR\|FAIL"
fi
```

## Important Notes

- Script **MUST run as root** (enforced by `_check_root`)
- CLI mode skips banner and clear_screen automatically
- For Docker projects, brolit auto-detects containers
- Notifications sent automatically on errors and important events
- Database operations auto-detect engine (MySQL/PostgreSQL) unless `-de` specified

## Verification Checklist

After executing any operation:

1. [ ] Check exit code is 0
2. [ ] Verify output doesn't contain ERROR/FAIL
3. [ ] For backup: confirm files exist in backup location
4. [ ] For restore: verify site responds with `curl -I`
5. [ ] For database: verify with `./runner.sh -t database -st list_db`
6. [ ] Check logs if available: `ls -la /var/log/brolit/`

## Usage Examples

### Example 1: Backup a Site

```bash
# User: "backup example.com"
output=$(./runner.sh -t backup -st project -D example.com 2>&1)
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  echo "Backup completed successfully"
  echo "$output" | tail -5
else
  echo "Backup failed with exit code: $exit_code"
  echo "$output" | grep -A3 "ERROR"
fi
```

### Example 2: Restore from File

```bash
# User: "restore example.com from /tmp/backup.tar.gz"
output=$(./runner.sh -t restore -st from-local -D example.com -tf /tmp/backup.tar.gz 2>&1)
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  echo "Restore completed successfully"
  # Verify site
  curl -I https://example.com
else
  echo "Restore failed with exit code: $exit_code"
  echo "$output" | grep -A3 "ERROR"
fi
```

### Example 3: List and Export Database

```bash
# List databases
./runner.sh -t database -st list_db

# Export specific database
./runner.sh -t database -st export_db -db mydb_prod
```

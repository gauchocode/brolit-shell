# Changelog

## Unreleased

### Added

- **`--new-domain` / `-nd` flag** for `restore` task: allows restoring a backup to a different domain (clone). Supported with `from-storage` subtask. Usage: `runner.sh -t restore -st from-storage -D example.com -tv 2026-06-09 -nd newdomain.com`
- `subtasks_restore_handler` now accepts and passes `new_domain` to `restore_backup_from_storage_cli` (which already supported it internally).

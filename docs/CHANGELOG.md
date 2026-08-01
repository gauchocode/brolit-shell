# Changelog

## Unreleased

### Added

- **`--new-domain` / `-nd` flag** for `restore` task: allows restoring a backup to a different domain (clone). Supported with `from-storage` subtask. Usage: `runner.sh -t restore -st from-storage -D example.com -tv 2026-06-09 -nd newdomain.com`
- `subtasks_restore_handler` now accepts and passes `new_domain` to `restore_backup_from_storage_cli` (which already supported it internally).
- **Proxmox VE node support**: `proxmox_provision_openresty_vm()` (`libs/local/proxmox_helper.sh`) provisions a dedicated OpenResty gateway VM end to end from the hypervisor - creates it via `qm`, waits for SSH, installs brolit-shell + OpenResty, sets up a dedicated SSH keypair, registers a persistent NAT rule, and points the node's own config at the new VM. Reachable from the main menu as **PROXMOX TOOLS** (menu 11) whenever `proxmox_node_detect()` finds the script is running on a Proxmox VE hypervisor.
- When running on a Proxmox node, the main menu now hides the project-oriented entries (backup/restore/project/database/environment/wp-cli manager) since they operate on `PROJECTS_PATH`, which doesn't exist on the bare hypervisor.
- `certbot_helper.sh` is now Proxmox-aware end to end: `certbot_get_challenge_type()` picks DNS-01 (Cloudflare) or webroot per domain, and `certbot_certificate_install()` runs certbot on the gateway VM (via `openresty_vm_exec`) rather than locally.
- OpenResty gateway VM management now uses SSH-key-based auth exclusively (`openresty_get_ssh_key`, `openresty_vm_ssh_key_setup`) instead of password/sshpass fallback.

### Fixed

- `json_read_field()` (`libs/local/json_helper.sh`) returned the literal string `"null"` for missing/absent JSON fields (a plain `jq -r` quirk), which callers' `[[ -z ]]` guards couldn't catch. Found because it silently wrote `allow null;` into a generated OpenResty config, corrupting it. Now returns an empty string via `// empty`.
- `routes.lua`'s `create_route()` symlinked `sites-enabled/<domain>` with no extension, but `nginx.conf`'s `include sites-enabled/*.conf` only matches `.conf` files - routes were written and reported success but were silently never loaded into the running config. Symlinks now carry the `.conf` suffix throughout (`create_route`, `delete_route`, `list_routes`, `get_route`).
- Certbot's ACME webroot moved from `/var/www/certbot` to `/etc/brolit/certbot-webroot` - the former broke brolit's convention that every directory under `PROJECTS.path` is a project/domain (site listing, backup, and delete code all assume this).

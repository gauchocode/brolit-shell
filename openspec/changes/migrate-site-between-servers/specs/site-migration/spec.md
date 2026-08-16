## ADDED Requirements

### Requirement: Migrate is restricted to Dockerized projects
The system SHALL, before performing any other action, verify that the requested domain's project install type is Docker-based (the same check `backup_docker_project()` uses). If the project is not Dockerized, the system SHALL exit non-zero with a message stating that site migration currently supports Dockerized projects only, and SHALL NOT start any backup, SSH connection, or remote operation.

#### Scenario: Domain is a host/classic (non-Docker) project
- **WHEN** an operator runs `runner.sh -t migrate -st site -D example.com` for a project whose install type is not Docker
- **THEN** the system exits non-zero with a message stating Docker-only support, and performs no backup or SSH connection

#### Scenario: Domain is a Dockerized project
- **WHEN** an operator runs `migrate site` for a domain whose install type is Docker-based
- **THEN** the system proceeds to destination pre-flight checks

### Requirement: Migrate validates destination reachability before any other remote action
The system SHALL, using the SSH credentials supplied via `--dest-host`, `--dest-user`, `--dest-port`, and `--dest-ssh-key`, verify SSH connectivity to the destination before creating a backup or checking anything else remotely. The system SHALL exit non-zero with a clear message if the destination is unreachable or authentication fails.

#### Scenario: Destination unreachable over SSH
- **WHEN** `--dest-host` does not respond over SSH within a reasonable timeout
- **THEN** the system exits non-zero with an SSH-connectivity error, and performs no backup

### Requirement: Migrate requires (or bootstraps) brolit-shell and its DNS/SSL config on the destination
The system SHALL verify, over SSH, that the destination has brolit-shell installed with the webserver role enabled, and that `SUPPORT_CLOUDFLARE_STATUS` and `PACKAGES_CERTBOT_STATUS` are enabled with non-empty credentials in the destination's `.brolit_conf.json`, since the destination's own restore process depends on this to configure DNS and SSL automatically. If brolit-shell is not installed, the system SHALL install it and generate a minimal configuration with the webserver role enabled. If brolit-shell is installed but Cloudflare/certbot configuration is missing, the system SHALL exit non-zero with an actionable message UNLESS `--bootstrap-dest-config` is passed, in which case the system SHALL copy the relevant Cloudflare configuration section from the source's own `.brolit_conf.json` to the destination and log exactly what was copied.

#### Scenario: Destination already fully configured
- **WHEN** the destination has brolit-shell installed with webserver, Cloudflare, and certbot configuration all present
- **THEN** the system proceeds directly to backup and transfer without installing or modifying anything on the destination

#### Scenario: Destination missing brolit-shell entirely
- **WHEN** the destination has no brolit-shell installation
- **THEN** the system clones brolit-shell and generates a minimal configuration with the webserver role enabled, then re-checks Cloudflare/certbot configuration

#### Scenario: Destination has brolit-shell but missing DNS/SSL config, no bootstrap flag
- **WHEN** the destination has brolit-shell installed but `SUPPORT_CLOUDFLARE_STATUS` or `PACKAGES_CERTBOT_STATUS` is not enabled, and `--bootstrap-dest-config` was not passed
- **THEN** the system exits non-zero with a message identifying the missing configuration, and performs no backup or transfer

#### Scenario: Destination has brolit-shell but missing DNS/SSL config, bootstrap flag passed
- **WHEN** the destination is missing Cloudflare/certbot configuration and `--bootstrap-dest-config` was passed
- **THEN** the system copies the source's Cloudflare configuration section to the destination's `.brolit_conf.json`, logs what was copied, and proceeds

### Requirement: Migrate validates destination path collisions before overwriting
The system SHALL check whether the destination's project path for the domain already exists. If it exists and `--force` was not passed, the system SHALL exit non-zero without transferring or modifying anything at that path.

#### Scenario: Destination path already exists, no force flag
- **WHEN** the resolved destination path already exists on the destination server, without `--force`
- **THEN** the system exits non-zero with a message indicating the destination path already exists, and performs no transfer

#### Scenario: Destination path already exists, force flag passed
- **WHEN** `--force` is passed and the resolved destination path already exists
- **THEN** the system proceeds with the migration and allows the subsequent restore to overwrite the existing path

### Requirement: Migrate captures the source project using existing Docker backup logic
The system SHALL use `backup_docker_project()` unmodified to produce the files-and-database artifact on the source server.

#### Scenario: Successful capture
- **WHEN** all pre-flight checks pass
- **THEN** the system produces a local backup artifact via `backup_docker_project()`

### Requirement: Migrate supports an explicit transport choice
The system SHALL accept a `--transport` option with value `local` (default) or `dropbox`. For `local`, the system SHALL stage and transfer the artifact via direct rsync using a fixed, migrate-owned staging path (identical on both servers, independent of any `.brolit_conf.json` value) and force the destination's restore to use the `local` storage method against that same path, WITHOUT reading, requiring, or depending on `BACKUPS.methods.local` being enabled anywhere - regular/cron backups must never be affected by using this transport. For `dropbox`, the system SHALL verify `BACKUPS.methods.dropbox` is enabled on the source, SHALL NOT perform any direct rsync transfer (relying on the capture step's normal upload-to-all-enabled-methods behavior), and SHALL force the destination's restore to use the `dropbox` storage method. The system SHALL reject any other value.

#### Scenario: Local transport works regardless of BACKUPS.methods.local
- **WHEN** `--transport local` (or the default) is used and `BACKUPS.methods.local` is disabled on both the source and destination
- **THEN** the system still captures, transfers, and restores successfully, using its own fixed staging path, and does not enable or modify `BACKUPS.methods.local` on either server

#### Scenario: Dropbox transport missing Dropbox storage
- **WHEN** `--transport dropbox` is used and the source does not have `BACKUPS.methods.dropbox` enabled
- **THEN** the system exits non-zero before capturing any backup

#### Scenario: Dropbox transport skips direct transfer
- **WHEN** `--transport dropbox` is used and capture succeeds
- **THEN** the system does not attempt any rsync transfer and proceeds directly to triggering the remote restore with `--storage-method dropbox`

#### Scenario: Invalid transport value
- **WHEN** `--transport` is passed a value other than `local` or `dropbox`
- **THEN** the system exits non-zero before capturing any backup

### Requirement: Migrate transfers the artifact (when using local transport) and triggers a normal restore on the destination
For `--transport local`, the system SHALL transfer the backup artifact to the destination using `rsync` over SSH, placed into the destination's own local backup storage path structure (namespaced under the destination's own server name). For `--transport dropbox`, no direct transfer is performed (see the transport requirement above). In both cases, after capture (and transfer, if applicable) succeeds, the system SHALL trigger the destination's own `runner.sh -t restore -st from-storage --storage-method <transport>` over SSH for the domain, and SHALL NOT reimplement file placement, database import, port-collision handling, nginx vhost creation, DNS updates, or SSL issuance itself — all of that SHALL be performed by the destination's existing restore logic (`restore -st from-local` is insufficient for this, as it only restores files with no database or DNS/SSL/vhost configuration).

#### Scenario: Transfer and remote restore succeed
- **WHEN** the artifact transfers successfully and the destination's restore command exits 0
- **THEN** the system proceeds to verification

#### Scenario: Transfer fails
- **WHEN** the SSH transfer is interrupted or fails
- **THEN** the system exits non-zero, does not trigger any remote restore, and leaves the source untouched

#### Scenario: Remote restore fails
- **WHEN** the transfer succeeds but the destination's restore command exits non-zero
- **THEN** the system reports the remote restore failure, does not proceed to decommissioning under any circumstance, and leaves the source untouched

### Requirement: Migrate never mutates the source unless decommissioning is explicitly requested and the destination is verified
The system SHALL NOT stop, delete, modify, or disable the source project's containers, files, database, or configuration at any point, UNLESS `--decommission-source` was passed AND the destination's remote restore exited 0 AND destination verification (per the following requirement) passed. If either the restore or the verification failed, the system SHALL leave the source completely untouched regardless of whether `--decommission-source` was passed.

#### Scenario: Migration fails before decommission is reached
- **WHEN** `migrate site --decommission-source` is run but the remote restore or verification fails
- **THEN** the source project's containers, files, database, and configuration remain unchanged

#### Scenario: Decommission flag not passed
- **WHEN** `migrate site` completes successfully without `--decommission-source`
- **THEN** the source project's containers, files, database, and configuration remain unchanged

### Requirement: Migrate verifies the destination site after restore
The system SHALL, after a successful remote restore, verify the destination responds correctly: at minimum via an HTTP(S) request resolved directly against the destination's IP (bypassing DNS propagation delay), and SHALL report the verification result clearly. A failed verification SHALL block decommissioning even if `--decommission-source` was passed.

#### Scenario: Destination verified
- **WHEN** the destination responds successfully when queried directly by IP after restore
- **THEN** the system reports the migration as verified and, if requested, proceeds to decommissioning

#### Scenario: Destination verification fails
- **WHEN** the destination does not respond successfully after restore
- **THEN** the system reports the verification failure clearly and does not proceed to decommissioning under any circumstance

### Requirement: Migrate decommissions the source only when explicitly requested, leaving only the backup artifact
When `--decommission-source` is passed and destination verification passed, the system SHALL, on the source: stop the project's Docker Compose stack, remove the project's nginx vhost configuration and reload nginx, remove the project's local SSL certificate files, remove the project directory, and de-register the project from the source's `.brolit_conf.json`. The system SHALL preserve Docker named volumes belonging to the project UNLESS `--purge-volumes` is also passed. The only artifact remaining on the source after decommissioning SHALL be the backup file already produced during capture, left in brolit's tmp/backup folder.

#### Scenario: Decommission without volume purge
- **WHEN** `migrate site --decommission-source` completes with a verified destination
- **THEN** the source's containers are stopped, its nginx vhost and SSL certificate files and project directory are removed, its `.brolit_conf.json` entry is removed, its Docker named volumes are preserved, and the backup artifact remains in brolit's tmp/backup folder

#### Scenario: Decommission with volume purge
- **WHEN** `migrate site --decommission-source --purge-volumes` completes with a verified destination
- **THEN** the same cleanup occurs as above, and the project's Docker named volumes are also removed

### Requirement: Migrate accepts destination SSH credentials only as per-invocation parameters
The system SHALL accept destination SSH connection details (`--dest-host`, `--dest-user`, `--dest-port`, `--dest-ssh-key`) only as CLI flags for the current invocation (or equivalent interactive prompts), and SHALL NOT persist them in `.brolit_conf.json` or any other configuration file.

#### Scenario: Credentials used only for the current run
- **WHEN** an operator runs `migrate site` with destination SSH flags
- **THEN** the system uses those values only for that invocation and does not write them to any configuration file

### Requirement: Migration supports both CLI and interactive modes
The system SHALL expose `migrate site` both as a non-interactive CLI subtask (`runner.sh -t migrate -st site ...`) and as a whiptail menu entry consistent with existing interactive menus, prompting for the domain, destination SSH details, and decommission options when run interactively.

#### Scenario: CLI invocation
- **WHEN** an operator runs `runner.sh -t migrate -st site -D example.com --dest-host ... --dest-user ... --dest-ssh-key ...` with all required flags
- **THEN** the migration runs non-interactively and returns a machine-readable exit code

#### Scenario: Interactive invocation
- **WHEN** an operator runs `runner.sh` with no flags and selects the site migration option from the menu
- **THEN** the system prompts (via whiptail) for the domain, destination SSH details, and whether to decommission the source, then performs the same migration logic as the CLI path

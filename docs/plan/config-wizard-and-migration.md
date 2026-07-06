# Plan: Configuration Wizard + Smart Config Migration

## Context

Currently, brolit-shell has a configuration file (`~/.brolit_conf.json`) that is loaded from `config/brolit/brolit_conf.json` as a template. When the file does not exist, the template is copied and the user is told to edit it manually. When the version does not match, it simply fails with an error. There is no way to migrate configurations between versions.

**Current problems:**
- `brolit_configuration_file_check()` in `utils/brolit_configuration_manager.sh:2063` only copies the template and fails
- There is no interactive wizard to generate the configuration
- There is no way to migrate between versions without losing existing values

## Feature 1: Quick Configuration Wizard

### New file: `utils/config_wizard.sh`

### Functions

#### 1. `config_wizard_menu()`
Main wizard menu using whiptail.

Options:
- 1: Quick configuration (preset)
- 2: Advanced configuration (section by section)
- 3: View current configuration
- 4: Exit

#### 2. `config_wizard_apply_preset()`
Apply a predefined preset. Each preset is a script that generates values for the template sections.

**Available presets:**

| Preset | Description | Enabled packages |
|--------|-------------|------------------|
| `wordpress` | Complete WordPress server | nginx, php, mysql/mariadb, redis, certbot |
| `docker` | Docker server | docker, portainer |
| `minimal` | Base configuration only | None (only SERVER_CONFIG) |
| `monitoring` | Monitoring stack | netdata |

Flow:
1. Show preset menu
2. Ask for minimal data (timezone, certbot email if applicable)
3. Generate config based on template + preset values
4. Save to `~/.brolit_conf.json`

#### 3. `config_wizard_advanced()`
Section-by-section configuration using whiptail.

**Sections:**
1. **Server** - timezone, roles (webserver/database)
2. **Base packages** - nginx, php (version, extensions), mysql/mariadb/postgres, redis
3. **Backups** - method (sftp/borg/local/dropbox), retention, compression
4. **Notifications** - email, telegram, discord, ntfy
5. **DNS** - Cloudflare
6. **Security** - firewall (ufw), fail2ban
7. **Monitoring** - netdata, cockpit
8. **Docker** - docker, portainer, portainer-agent

Each section:
- Shows whiptail_input for text fields
- Shows whiptail_selection_menu for options
- Validates required fields before continuing
- Allows skipping sections

#### 4. `config_wizard_show_current()`
Shows the current configuration in a readable format (formatted with `jq .`).

### Base template

`config/brolit/brolit_conf.json` is used as the base. The wizard:
1. Copies the template
2. Overwrites values according to preset or user input
3. Updates the version in `BROLIT_SETUP.config[].version`

## Feature 2: Smart Config Migration

### New file: `utils/config_migration.sh`

### Functions

#### 1. `config_migration_check()`
Detects whether migration is necessary.

```
Arguments:
  ${1} = config_file (path to installed config)

Returns:
  0 = migration needed
  1 = no migration needed
  Sets globals: MIGRATION_NEEDED, CURRENT_VERSION, TARGET_VERSION
```

Compares `BROLIT_SETUP.config[].version` of the installed config vs template.

#### 2. `config_migration_diff()`
Calculates differences between current config and template.

```
Arguments:
  ${1} = config_file (current)
  ${2} = config_template (new)

Outputs:
  Global arrays:
  - MIGRATION_FIELDS_ADDED: new fields in template
  - MIGRATION_FIELDS_REMOVED: fields removed from template
  - MIGRATION_FIELDS_RENAMED: renamed fields (legacy mapping)
```

Uses `jq` to compare JSON structures recursively.

#### 3. `config_migration_merge()`
Smart merge of configurations.

```
Arguments:
  ${1} = config_file (current)
  ${2} = config_template (new)

Outputs:
  Resulting config (updates config_file in-place)
```

Algorithm:
1. Copy current config as base
2. For each field in template:
   - If it exists in current: preserve value
   - If it is new: add with template value
   - If it was renamed (legacy mapping): migrate value
3. Update version

#### 4. `config_migration_apply()`
Applies the complete migration.

```
Arguments:
  ${1} = config_file

Steps:
  1. Create backup: ${config_file}.bak.$(date +%Y%m%d)
  2. Run config_migration_merge()
  3. Validate result with jq
  4. Update version
```

#### 5. `config_migration_show_diff()`
Shows differences to the user with whiptail.

```
Arguments:
  ${1} = config_file (current)
  ${2} = config_template (new)

Outputs:
  Whiptail showing:
  - New fields (added automatically)
  - Removed fields (kept for compatibility)
  - Renamed fields (migrated)
```

### Legacy Mapping

To handle renamed fields between versions:

```bash
declare -A CONFIG_FIELD_MIGRATIONS=(
    ["NOTIFICATIONS.email[].config[].maila"]="NOTIFICATIONS.email[].config[].email_to"
    # Add more migrations here as needed
)
```

The `config_migration_merge()` function queries this array to migrate values automatically.

## Files to Modify

### `utils/brolit_configuration_manager.sh`

Modify `brolit_configuration_file_check()` (line 2063):

```bash
# BEFORE:
if [[ ${brolit_installed_config_version} != "${brolit_release_config_version}" ]]; then
    log_event "error" "Brolit config version outdated! Please regenerate config file." "false"
    display --indent 6 --text "- Checking Brolit config version" --result "WARNING" --color YELLOW
    display --indent 8 --text "Brolit config version outdated!"
    exit 1
fi

# AFTER:
if [[ ${brolit_installed_config_version} != "${brolit_release_config_version}" ]]; then
    log_event "warning" "Brolit config version outdated" "false"
    display --indent 6 --text "- Checking Brolit config version" --result "OUTDATED" --color YELLOW
    
    # Offer migration
    source "${BROLIT_MAIN_DIR}/utils/config_migration.sh"
    config_migration_check "${server_config_file}"
    
    if [[ ${MIGRATION_NEEDED} == "true" ]]; then
        config_migration_show_diff "${server_config_file}" "${brolit_config_template}"
        
        if whiptail_message_with_skip_option "Config Migration" "Do you want to migrate to the new version?"; then
            config_migration_apply "${server_config_file}"
            display --indent 6 --text "- Config migrated successfully" --result "DONE" --color GREEN
        else
            display --indent 6 --text "- Migration skipped" --result "WARNING" --color YELLOW
            exit 1
        fi
    fi
fi
```

Also modify the section where the config does not exist (line 2084):

```bash
# BEFORE: only copy template
cp "${brolit_config_template}" "${server_config_file}"
log_event "critical" "Please, edit brolit_conf.json first, and then run the script again." "true"
exit 1

# AFTER: offer wizard
source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
if whiptail_message_with_skip_option "BROLIT Setup" "Config file not found. Do you want to run the configuration wizard?"; then
    config_wizard_menu
else
    # Fallback: copy template
    cp "${brolit_config_template}" "${server_config_file}"
    log_event "critical" "Please, edit brolit_conf.json first, and then run the script again." "true"
    exit 1
fi
```

### `libs/commons.sh`

Add option to main menu in `menu_main_options()` (line 1867):

```bash
runner_options=(
    "01)" "BACKUP OPTIONS"
    "02)" "RESTORE OPTIONS"
    "03)" "PROJECT MANAGER"
    "04)" "DATABASE MANAGER"
    "05)" "ENVIRONMENT MANAGER"
    "06)" "WP-CLI MANAGER"
    "07)" "CERTBOT MANAGER"
    "08)" "CLOUDFLARE MANAGER"
    "09)" "IT UTILS"
    "10)" "CRON TASKS"
    "11)" "CONFIGURATION WIZARD"    # NEW
)
```

And the corresponding handler:

```bash
# CONFIGURATION WIZARD
if [[ ${chosen_type} == *"11"* ]]; then
    source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
    config_wizard_menu
fi
```

### `libs/task_runner.sh`

Add `--wizard` flag in `flags_handler()` (after line 833):

```bash
-wiz | --wizard)
    TASK="config-wizard"
    ;;
```

Add case in `tasks_handler()`:

```bash
config-wizard)
    source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
    config_wizard_menu
    exit 0
    ;;
```

## File Structure

```
utils/
├── config_wizard.sh              # NEW - Configuration wizard
├── config_migration.sh           # NEW - Migration system
└── brolit_configuration_manager.sh  # MODIFIED - integrate migration

libs/
├── commons.sh                    # MODIFIED - add menu option
└── task_runner.sh                # MODIFIED - add --wizard flag
```

## Implementation Order

1. **`utils/config_migration.sh`** (high priority - needed before the wizard)
   - `config_migration_check()`
   - `config_migration_diff()`
   - `config_migration_merge()`
   - `config_migration_apply()`
   - `config_migration_show_diff()`

2. **`utils/config_wizard.sh`**
   - `config_wizard_menu()`
   - `config_wizard_apply_preset()`
   - `config_wizard_advanced()`
   - `config_wizard_show_current()`

3. **Integration**
   - Modify `brolit_configuration_file_check()` in `utils/brolit_configuration_manager.sh`
   - Add "11) CONFIGURATION WIZARD" option to menu in `libs/commons.sh`
   - Add `--wizard` flag to CLI in `libs/task_runner.sh`

4. **Tests**
   - `tests/test_config_migration.sh`
   - `tests/test_config_wizard.sh`

## Validation

- Verify that generated configs are valid: `jq . ~/.brolit_conf.json`
- Migration test: create old version config, migrate, verify result
- Preset test: generate config with each preset, verify required fields
- Legacy mapping test: verify that renamed fields are migrated correctly

## Usage Flow

### New user
1. Runs `./runner.sh`
2. No config exists → wizard is offered
3. Chooses preset or advanced
4. Config is generated with correct values
5. Brolit starts normally

### Version update
1. Runs `./runner.sh` (or `./runner.sh --wizard`)
2. Detects outdated version
3. Shows diff between current config and new template
4. User accepts migration
5. Backup is created and merge is applied
6. Brolit starts with updated config

### CLI usage
```bash
# Open wizard directly
./runner.sh --wizard

# Or via task
./runner.sh -t config-wizard
```

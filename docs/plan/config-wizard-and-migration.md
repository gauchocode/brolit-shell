# Plan: Wizard de Configuración + Migración Inteligente de Config

## Contexto

Actualmente, brolit-shell tiene un archivo de configuración (`~/.brolit_conf.json`) que se carga desde `config/brolit/brolit_conf.json` como template. Cuando el archivo no existe, se copia el template y se le dice al usuario que lo edite manualmente. Cuando la versión no coincide, simplemente falla con un error. No existe forma de migrar configuraciones entre versiones.

**Problemas actuales:**
- `brolit_configuration_file_check()` en `utils/brolit_configuration_manager.sh:2063` solo copia el template y falla
- No hay wizard interactivo para generar la configuración
- No hay forma de migrar entre versiones sin perder valores existentes

## Feature 1: Wizard de Configuración Rápida

### Archivo nuevo: `utils/config_wizard.sh`

### Funciones

#### 1. `config_wizard_menu()`
Menú principal del wizard con whiptail.

Opciones:
- 1: Configuración rápida (preset)
- 2: Configuración avanzada (sección por sección)
- 3: Ver configuración actual
- 4: Salir

#### 2. `config_wizard_apply_preset()`
Aplicar preset predefinido. Cada preset es un script que genera valores para las secciones del template.

**Presets disponibles:**

| Preset | Descripción | Paquetes habilitados |
|--------|-------------|---------------------|
| `wordpress` | Servidor WordPress completo | nginx, php, mysql/mariadb, redis, certbot |
| `docker` | Servidor Docker | docker, portainer |
| `minimal` | Solo configuración base | Ninguno (solo SERVER_CONFIG) |
| `monitoring` | Stack de monitoreo | netdata |

Flujo:
1. Mostrar menú de presets
2. Pedir datos mínimos (timezone, email certbot si aplica)
3. Generar config basada en template + valores del preset
4. Guardar en `~/.brolit_conf.json`

#### 3. `config_wizard_advanced()`
Configuración sección por sección usando whiptail.

**Secciones:**
1. **Servidor** - timezone, roles (webserver/database)
2. **Paquetes base** - nginx, php (version, extensions), mysql/mariadb/postgres, redis
3. **Backups** - método (sftp/borg/local/dropbox), retención, compresión
4. **Notificaciones** - email, telegram, discord, ntfy
5. **DNS** - Cloudflare
6. **Seguridad** - firewall (ufw), fail2ban
7. **Monitoreo** - netdata, cockpit
8. **Docker** - docker, portainer, portainer-agent

Cada sección:
- Muestra whiptail_input para campos de texto
- Muestra whiptail_selection_menu para opciones
- Valida campos requeridos antes de continuar
- Permite saltar secciones

#### 4. `config_wizard_show_current()`
Muestra la configuración actual de forma legible (formateada con `jq .`).

### Template base

Se usa `config/brolit/brolit_conf.json` como base. El wizard:
1. Copia el template
2. Sobrescribe valores según preset o input del usuario
3. Actualiza la versión en `BROLIT_SETUP.config[].version`

## Feature 2: Migración Inteligente de Config

### Archivo nuevo: `utils/config_migration.sh`

### Funciones

#### 1. `config_migration_check()`
Detecta si migración es necesaria.

```
Arguments:
  ${1} = config_file (path al config instalado)

Returns:
  0 = necesita migración
  1 = no necesita migración
  Sets globals: MIGRATION_NEEDED, CURRENT_VERSION, TARGET_VERSION
```

Compara `BROLIT_SETUP.config[].version` del config instalado vs template.

#### 2. `config_migration_diff()`
Calcula diferencias entre config actual y template.

```
Arguments:
  ${1} = config_file (actual)
  ${2} = config_template (nuevo)

Outputs:
  Arrays globales:
  - MIGRATION_FIELDS_ADDED: campos nuevos en template
  - MIGRATION_FIELDS_REMOVED: campos eliminados del template
  - MIGRATION_FIELDS_RENAMED: campos renombrados (legacy mapping)
```

Usa `jq` para comparar estructuras JSON recursivamente.

#### 3. `config_migration_merge()`
Merge inteligente de configuraciones.

```
Arguments:
  ${1} = config_file (actual)
  ${2} = config_template (nuevo)

Outputs:
  Config resultante (actualiza config_file in-place)
```

Algoritmo:
1. Copia config actual como base
2. Para cada campo en template:
   - Si existe en actual: preservar valor
   - Si es nuevo: agregar con valor del template
   - Si fue renombrado (legacy mapping): migrar valor
3. Actualizar versión

#### 4. `config_migration_apply()`
Aplica la migración completa.

```
Arguments:
  ${1} = config_file

Steps:
  1. Crear backup: ${config_file}.bak.$(date +%Y%m%d)
  2. Ejecutar config_migration_merge()
  3. Validar resultado con jq
  4. Actualizar versión
```

#### 5. `config_migration_show_diff()`
Muestra diferencias al usuario con whiptail.

```
Arguments:
  ${1} = config_file (actual)
  ${2} = config_template (nuevo)

Outputs:
  Whiptail mostrando:
  - Campos nuevos (agregados automáticamente)
  - Campos eliminados (se mantienen por compatibilidad)
  - Campos renombrados (migrados)
```

### Legacy Mapping

Para manejar campos renombrados entre versiones:

```bash
declare -A CONFIG_FIELD_MIGRATIONS=(
    ["NOTIFICATIONS.email[].config[].maila"]="NOTIFICATIONS.email[].config[].email_to"
    # Agregar más migraciones aquí según sea necesario
)
```

La función `config_migration_merge()` consulta este array para migrar valores automáticamente.

## Archivos a Modificar

### `utils/brolit_configuration_manager.sh`

Modificar `brolit_configuration_file_check()` (línea 2063):

```bash
# ANTES:
if [[ ${brolit_installed_config_version} != "${brolit_release_config_version}" ]]; then
    log_event "error" "Brolit config version outdated! Please regenerate config file." "false"
    display --indent 6 --text "- Checking Brolit config version" --result "WARNING" --color YELLOW
    display --indent 8 --text "Brolit config version outdated!"
    exit 1
fi

# DESPUÉS:
if [[ ${brolit_installed_config_version} != "${brolit_release_config_version}" ]]; then
    log_event "warning" "Brolit config version outdated" "false"
    display --indent 6 --text "- Checking Brolit config version" --result "OUTDATED" --color YELLOW
    
    # Ofrecer migración
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

También modificar la sección donde no existe el config (línea 2084):

```bash
# ANTES: solo copia template
cp "${brolit_config_template}" "${server_config_file}"
log_event "critical" "Please, edit brolit_conf.json first, and then run the script again." "true"
exit 1

# DESPUÉS: ofrecer wizard
source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
if whiptail_message_with_skip_option "BROLIT Setup" "Config file not found. Do you want to run the configuration wizard?"; then
    config_wizard_menu
else
    # Fallback: copiar template
    cp "${brolit_config_template}" "${server_config_file}"
    log_event "critical" "Please, edit brolit_conf.json first, and then run the script again." "true"
    exit 1
fi
```

### `libs/commons.sh`

Agregar opción al menú principal en `menu_main_options()` (línea 1867):

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
    "11)" "CONFIGURATION WIZARD"    # NUEVO
)
```

Y el handler correspondiente:

```bash
# CONFIGURATION WIZARD
if [[ ${chosen_type} == *"11"* ]]; then
    source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
    config_wizard_menu
fi
```

### `libs/task_runner.sh`

Agregar flag `--wizard` en `flags_handler()` (después de línea 833):

```bash
-wiz | --wizard)
    TASK="config-wizard"
    ;;
```

Agregar caso en `tasks_handler()`:

```bash
config-wizard)
    source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
    config_wizard_menu
    exit 0
    ;;
```

## Estructura de Archivos

```
utils/
├── config_wizard.sh              # NUEVO - Wizard de configuración
├── config_migration.sh           # NUEVO - Sistema de migración
└── brolit_configuration_manager.sh  # MODIFICADO - integrar migración

libs/
├── commons.sh                    # MODIFICADO - agregar opción al menú
└── task_runner.sh                # MODIFICADO - agregar flag --wizard
```

## Orden de Implementación

1. **`utils/config_migration.sh`** (prioridad alta - se necesita antes del wizard)
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

3. **Integración**
   - Modificar `brolit_configuration_file_check()` en `utils/brolit_configuration_manager.sh`
   - Agregar opción "11) CONFIGURATION WIZARD" al menú en `libs/commons.sh`
   - Agregar flag `--wizard` al CLI en `libs/task_runner.sh`

4. **Tests**
   - `tests/test_config_migration.sh`
   - `tests/test_config_wizard.sh`

## Validación

- Verificar que configs generadas son válidas: `jq . ~/.brolit_conf.json`
- Test de migración: crear config versión vieja, migrar, verificar resultado
- Test de presets: generar config con cada preset, verificar campos requeridos
- Test de legacy mapping: verificar que campos renombrados se migran correctamente

## Flujo de Uso

### Nuevo usuario
1. Ejecuta `./runner.sh`
2. No existe config → se ofrece wizard
3. Elige preset o avanzado
4. Se genera config con valores correctos
5. Brolit inicia normalmente

### Actualización de versión
1. Ejecuta `./runner.sh` (o `./runner.sh --wizard`)
2. Detecta versión desactualizada
3. Muestra diff entre config actual y nuevo template
4. Usuario acepta migración
5. Se crea backup y se aplica merge
6. Brolit inicia con config actualizada

### Uso CLI
```bash
# Abrir wizard directamente
./runner.sh --wizard

# O via task
./runner.sh -t config-wizard
```

# Fix CLI Parameters — Execution Plan

**Fecha:** 2026-06-09
**Reporte base:** `docs/reports/2026-06-09-cli-parameter-review.md`
**Estado:** Pending

---

## Overview

Corregir bugs criticos y mejorar robustez del sistema de parametros CLI de brolit-shell. 13 tareas en 4 fases, ~6-7hs estimadas.

---

## Fase 1: Bugs Criticos (C1-C4)

### T1. Fix flag `-d` duplicado (C1)

**Archivo:** `libs/task_runner.sh`

- Linea 45 (`show_help`): cambiar `-d --domain` a `-D --domain` (coincidir con `-do` ya usado en parser)
- Lineas 49-50: eliminar `-q, --quiet` y `-v, --verbose` del help (no implementados)
- Linea 53: implementar case `--version` en `flags_handler`
- Actualizar `show_help()` con lista completa de tasks: `backup`, `restore`, `project`, `project-install`, `database`, `cloudflare-api`, `wpcli`, `ssh-keygen`, `disk-cleanup`, `aliases-install`
- Linea 597: cambiar `exit` por `exit 1` en `*)` catch-all

**Verificacion:** `bash -n libs/task_runner.sh`, `./runner.sh --help`, `./runner.sh --version`

### T2. Fix word-splitting en `$*` (C2)

**Archivo:** `runner.sh:38`

```bash
# Antes:
flags_handler $*

# Despues:
flags_handler "$@"
```

**Verificacion:** `bash -n runner.sh`

### T3. Agregar validacion de DBNAME para backup databases (C3)

**Archivo:** `libs/task_runner.sh` — case `backup)`, antes del `databases)` handler

Agregar validacion:

```bash
databases)
    validate_required_params "backup-databases" "DBNAME"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
```

**Verificacion:** `./runner.sh -t backup -st databases` sin `-db` → debe fallar con error de missing params

### T4. Quitar `install` de subtasks validos de project (C4)

**Archivo:** `libs/task_runner.sh:266`

```bash
# Antes:
validate_task_and_subtask "project" "${STASK}" "delete install"

# Despues:
validate_task_and_subtask "project" "${STASK}" "delete"
```

**Verificacion:** `./runner.sh -t project -st install` → error de subtask invalido

---

## Fase 2: Fixes de Parameters Routing (S2, S3, S4)

### T5. Unificar nombres de subtasks en database_manager (S3)

**Archivos:** `libs/task_runner.sh:303`, `utils/database_manager.sh:762-840`

Opcion recomendada: alinear handler con validador.

En `task_runner.sh` actualizar lista:
```bash
validate_task_and_subtask "database" "${STASK}" \
    "list_db create_db delete_db rename_db import_db export_db \
     list_db_user create_db_user delete_db_user change_db_user_psw"
```

En `database_tasks_handler` renombrar cases para coincidir:
- `create_db_user` → ya existe, solo agregar a validacion
- `delete_db_user` → ya existe, solo agregar a validacion
- `change_db_user_psw` → ya existe, solo agregar a validacion
- `list_db_user` → ya existe, solo agregar a validacion

Agregar validaciones de params para los subtasks nuevos:
```bash
list_db_user)
    # no params needed
    ;;
create_db_user)
    validate_required_params "database-create-user" "DBUSER"
    ;;
delete_db_user)
    validate_required_params "database-delete-user" "DBUSER"
    ;;
change_db_user_psw)
    validate_required_params "database-change-psw" "DBUSER" "DBUSERPSW"
    ;;
```

**Verificacion:** Probar cada subtask por CLI

### T6. Pasar DOMAIN explicitamente a cloudflare_tasks_handler (S2)

**Archivo:** `libs/task_runner.sh:357`

```bash
# Antes:
execute_task_with_error_handling "cloudflare-${STASK}" "cloudflare_tasks_handler" "${STASK}" "${TVALUE}"

# Despues:
execute_task_with_error_handling "cloudflare-${STASK}" "cloudflare_tasks_handler" "${STASK}" "${DOMAIN}" "${TVALUE}"
```

**Archivo:** `utils/cloudflare_manager.sh:761`

```bash
function cloudflare_tasks_handler() {
    local subtask="${1}"
    local domain="${2}"
    local tvalue="${3}"
    # usar ${domain} y ${tvalue} en vez de globals
}
```

**Verificacion:** `./runner.sh -t cloudflare-api -st clear_cache -do example.com`

### T7. Pasar parametros completos a project_tasks_handler (S4)

**Archivo:** `libs/task_runner.sh:284`

```bash
# Antes:
execute_task_with_error_handling "project-${STASK}" "project_tasks_handler" "${STASK}" "${PROJECTS_PATH}"

# Despues:
execute_task_with_error_handling "project-${STASK}" "project_tasks_handler" "${STASK}" "${PROJECTS_PATH}" "${PTYPE}" "${DOMAIN}" "${PNAME}" "${PSTATE}"
```

**Verificacion:** `./runner.sh -t project -st delete -do example.com` → DOMAIN llega al handler

---

## Fase 3: Mejoras de Robustez (S1, S5, S7, S8)

### T8. Implementar `--version` y limpiar help (S5)

**Archivo:** `libs/task_runner.sh`

- Agregar en `flags_handler` case:
  ```bash
  --version)
      echo "BROLIT Shell v${SCRIPT_V}"
      exit 0
      ;;
  ```
- Actualizar `show_help()` con lista completa de tasks y subtasks

**Verificacion:** `./runner.sh --version`, `./runner.sh --help`

### T9. Explicitar tasks sin subtask (S1)

**Archivo:** `libs/task_runner.sh`

Agregar comentario en cada task que no requiere subtask en `tasks_handler`:
```bash
aliases-install)
    # No subtask required
    ...
```

### T10. Mover chmod fuera del hot path (S7)

**Archivo:** `runner.sh:21`

Mover `chmod +x ...` dentro de `_check_scripts_permissions()` en `commons.sh`.

**Verificacion:** `bash -n runner.sh`

### T11. Reemplazar recursion por loop en menu_main_options (S8)

**Archivo:** `libs/commons.sh:1830`

Envolver en `while true; do ... done` con break en el else (cancel).

**Verificacion:** Ejecutar `./runner.sh` sin args, navegar menus, cancelar.

---

## Fase 4: Tech Debt (S6, S9)

### T12. Dinamizar BROLIT_MAIN_DIR en brolit_lite.sh (S6)

**Archivo:** `brolit_lite.sh:2229`

```bash
# Antes:
declare -g BROLIT_MAIN_DIR="/root/brolit-shell"

# Despues:
declare -g BROLIT_MAIN_DIR
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
```

**Verificacion:** `bash -n brolit_lite.sh`

### T13. Crear tests de CLI (S9)

**Archivo nuevo:** `tests/test_task_runner.sh`

Contenido:
- Test cada combinacion task/subtask valida (mock)
- Test rechazo de tasks/subtasks invalidos
- Test validacion de parametros requeridos
- Test word-splitting con valores con espacios
- Test `--help`, `--version`, flags invalidos

**Verificacion:** `./tests/tests_suite.sh`

---

## Dependencias

```
Fase 1:  T1  T2  T3  T4          (paralelos, sin dependencias)
Fase 2:  T5  →  T6  →  T7        (secuenciales)
Fase 3:  T8  T9  T10  T11        (paralelos)
Fase 4:  T12 → T13               (T13 al final, valida todo)
```

## Estimacion

| Fase | Tareas | Tiempo |
|---|---|---|
| Fase 1 (Criticos) | T1-T4 | 2-3hs |
| Fase 2 (Routing) | T5-T7 | 1.5hs |
| Fase 3 (Robustez) | T8-T11 | 1.5hs |
| Fase 4 (Tech Debt) | T12-T13 | 1.5hs |
| **Total** | **13 tareas** | **~6-7hs** |

## Verificacion general post-implementacion

1. `bash -n` sobre todos los archivos modificados
2. `./runner.sh --help` — verificar salida completa y correcta
3. `./runner.sh --version` — verificar output
4. `./runner.sh -t backup -st databases` — debe fallar sin `-db`
5. `./runner.sh -t project -st install` — debe rechazar subtask
6. `./runner.sh -t cloudflare-api -st clear_cache -do example.com` — verificar routing
7. `./runner.sh -t project -st delete -do example.com` — verificar DOMAIN llega al handler
8. `./tests/tests_suite.sh` — suite completa

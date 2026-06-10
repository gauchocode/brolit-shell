# New CLI Commands for Automation

**Fecha:** 2026-06-09
**Criterio:** Automatizacion (brolit-ui, scripts, cron)
**Estado:** In Progress
**Issue:** BLIT-176

---

## Overview

Agregar 6 nuevos comandos CLI + scaffold para facilitar la adicion futura de comandos. Todas las funciones base ya existen, solo se necesita routing en task_runner.

## Estimacion: ~25 min

---

## T0. Scaffold: Convencion para nuevos tasks

- Documentar el patron de 3 pasos en `show_help()` o comentario en `tasks_handler`
- Patron: 1) validar subtask, 2) validar params, 3) rutear al handler
- Archivo: `libs/task_runner.sh`

## T1. certbot — SSL certificate management

- Subtasks: `install`, `expand`, `force-renew`, `delete`, `list`, `test-renew`
- Funciones base en `libs/apps/certbot_helper.sh`:
  - `certbot_certificate_install "${domain}" "${email}"`
  - `certbot_certificate_expand "${domain}"`
  - `certbot_certificate_force_renew "${domain}"`
  - `certbot_certificate_delete "${domain}"`
  - `certbot_show_certificates_info`
  - `certbot_certificate_renew_test`
- Handler: implementar `certbot_tasks_handler` en `utils/certbot_manager.sh`
- Params: `-D` domain (excepto `list` y `test-renew`)

## T2. database export/import — Completar subtasks documentados

- Subtasks: `export_db`, `import_db`
- Funciones base en `libs/apps/mysql_helper.sh`:
  - `mysql_database_export`
  - `mysql_database_import`
- Params: `-db` dbname, `-D` domain (path), `-tf` file (import)

## T3. restore — Completar stubs

- Subtasks: `from-local`, `from-storage`, `from-url`, `from-borg`
- Funciones base en `libs/local/restore_backup_helper.sh`:
  - `restore_backup_from_local`
  - `restore_backup_from_storage`
  - `restore_backup_from_public_url`
  - `restore_backup_with_borg`
- Params: `-D` domain, `-tf` file/path, `-tv` backup_date

## T4. project online/offline — Cambiar estado nginx

- Subtasks: `online`, `offline`
- Funcion base: `nginx_server_change_status "${domain}" "${status}"`
- Llamar directamente sin pasar por `project_change_status` (interactivo)
- Params: `-D` domain

## T5. wpcli search-replace — Fix case comentado

- Descomentar e implementar case en `wpcli_tasks_handler`
- Params: `-D` domain, `-tv` "old_url,new_url"

## T6. project regen-nginx — Regenerar config nginx

- Subtask: `regen-nginx`
- Wrapper no-interactivo que llame a las funciones de bajo nivel
- Params: `-D` domain, `-pt` project_type

---

## Dependencias

```
T0 (scaffold) → todo lo demas
T2, T5 (fixes existentes) → independientes
T1 (certbot) → independiente
T4 → T6 (ambos usan nginx)
T3 (restore, mas complejo) → ultimo
```

## Verificacion

1. `bash -n` sobre todos los archivos modificados
2. Test de cada nuevo subtask con flags validos/invalidos
3. `./runner.sh --help` muestra todos los tasks nuevos

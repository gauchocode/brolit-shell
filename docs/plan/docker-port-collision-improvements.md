# Docker Port Collision Handling - Plan de Mejoras

## Context

Cuando se restaura un proyecto Docker desde backup, `docker_setup_configuration()` verifica si el puerto del `.env` está en uso y busca uno alternativo. El sistema actual funciona pero tiene deficiencias de performance, confiabilidad y usabilidad que se agravan en batch restore (múltiples proyectos restaurados secuencialmente).

### Funciones involucradas

| Función | Archivo | Rol |
|---|---|---|
| `network_port_is_use()` | `libs/commons.sh:1089` | Check si un puerto está en uso (usa `lsof`) |
| `network_next_available_port()` | `libs/commons.sh:1118` | Busca próximo puerto libre (usa `telnet`) |
| `docker_setup_configuration()` | `libs/local/restore_backup_helper.sh:2210` | Configura `.env` y levanta containers |
| `restore_project_backup()` | `libs/local/restore_backup_helper.sh:549` | Orquesta restauración completa |
| `restore_backup_from_storage_batch()` | `libs/local/restore_backup_helper.sh:1429` | Batch restore de múltiples proyectos |

## Problemas identificados

### P1: `network_next_available_port()` usa `telnet` (lento e inconfiable)

**Archivo:** `libs/commons.sh:1118`

```bash
echo -ne "\035" | telnet 127.0.0.1 "${port}" >/dev/null 2>&1
```

- Hace un intento de conexión TCP completo por cada puerto (timeout si está filtrado).
- `telnet` puede no estar instalado en todas las imágenes base.
- Para un rango 81-350, en el peor caso hace 269 intentos de conexión.
- Si el puerto está filtrado (no refused), el timeout bloquea varios segundos.

**Solución:** Reemplazar con `ss` o `lsof`, que consultan el kernel directamente sin abrir conexiones.

```bash
function network_next_available_port() {
    local port_start="${1}"
    local port_end="${2}"

    local port
    local used_ports

    used_ports="$(ss -tlnH | awk '{print $4}' | grep -oP ':\d+$' | sort -u)"

    for port in $(seq "${port_start}" "${port_end}"); do
        if ! echo "${used_ports}" | grep -q ":${port}$"; then
            echo "${port}" && return 0
        fi
    done

    return 1
}
```

**Impacto:** De ~30s (telnet con timeouts) a <1s.

---

### P2: `network_port_is_use()` usa `lsof` sin optimizar

**Archivo:** `libs/commons.sh:1089`

```bash
result="$(lsof -i:"${port}")"
```

- `lsof` sin `-P -n` hace resolución DNS inversa (lento).
- No filtra solo LISTEN (incluye ESTABLISHED, TIME_WAIT, etc.).
- Guarda resultado en variable que no se usa para nada más que el check.

**Solución:**

```bash
function network_port_is_use() {
    local port="${1}"

    if ss -tlnH | grep -qP ":${port}\b"; then
        log_event "info" "Port ${port} is in use." "false"
        return 0
    else
        log_event "info" "Port ${port} is not in use." "false"
        return 1
    fi
}
```

**Nota:** Unificar ambas funciones para usar `ss` consistentemente. `ss` está disponible en todas las distros modernas (viene con `iproute2`).

---

### P3: No hay re-verificación antes del `docker compose up`

**Archivo:** `libs/local/restore_backup_helper.sh:2270`

El flujo actual:

```
1. Chequear puerto → asignar en .env
2. docker_compose_build (que hace up --detach --build)
```

Entre paso 1 y 2, un proceso externo podría haber tomado el puerto. Docker fallaría con un error críptico de bind.

**Solución:** Agregar una verificación inmediatamente antes del `up`, y si falla el bind, reasignar puerto automáticamente.

```bash
# En docker_setup_configuration(), antes del build:
if network_port_is_use "${backup_port}"; then
    new_port="$(network_next_available_port "81" "350")"
    # actualizar .env con new_port
fi

if ! docker_compose_build "..."; then
    # Si falló por puerto, reintentar con puerto nuevo
    if docker_logs_contain_port_error "${project_name}"; then
        new_port="$(network_next_available_port "81" "350")"
        # actualizar .env y reintentar
    fi
fi
```

---

### P4: Puerto hardcoded en `docker_setup_configuration()`

**Archivo:** `libs/local/restore_backup_helper.sh:2251, 2306`

```bash
new_port="$(network_next_available_port "81" "350")"
```

El rango 81-350 está hardcodeado. Debería salir de la configuración.

**Solución:** Agregar al `.brolit_conf.json`:

```json
{
    "DOCKER": {
        "port_range_start": "81",
        "port_range_end": "350"
    }
}
```

Y leerlo desde `brolit_configuration_manager.sh` como variables globales `DOCKER_PORT_RANGE_START` y `DOCKER_PORT_RANGE_END`.

---

### P5: Sin logging de asignaciones de puerto

Cuando se restauran 10 proyectos en batch, no hay forma de ver qué puerto se le asignó a cada uno después del proceso.

**Solución:** Loguear cada asignación en el evento log y mostrar tabla resumen al final del batch.

En `restore_backup_from_storage_batch()`, agregar al summary:

```
Batch Restore Summary
  - Total: 5
  - Successful: 5
  - Port assignments:
    - site1.example.com → port 81
    - site2.example.com → port 82
    - site3.example.com → port 83
```

---

### P6: `docker_setup_configuration()` mezcla responsabilidades

La función maneja configuración del `.env` + chequeo de puertos + build de containers. Para el batch restore sería útil poder hacer solo la configuración sin levantar containers, y levantarlos todos al final en paralelo.

**Solución (futuro):** Separar en:
- `docker_configure_env()` — solo modifica `.env` y asigna puerto
- `docker_build_and_up()` — hace build + up

Esto permitiría en batch restore: configurar todos los `.env` primero, verificar que no haya colisiones entre ellos, y luego levantar containers.

---

## Plan de implementación

### Fase 1: Reemplazar telnet por ss (P1 + P2)

**Prioridad:** Alta
**Archivos:** `libs/commons.sh`
**Riesgo:** Bajo (ss está en todas las distros con iproute2)

1. Reescribir `network_next_available_port()` usando `ss`
2. Reescribir `network_port_is_use()` usando `ss`
3. Agregar fallback a `lsof` si `ss` no está disponible
4. Testear con puertos ocupados y libres

### Fase 2: Re-verificación antes del up (P3)

**Prioridad:** Media
**Archivos:** `libs/local/restore_backup_helper.sh`
**Riesgo:** Bajo

1. Agregar check de puerto inmediatamente antes de `docker_compose_build`
2. Si el puerto fue tomado, reasignar y actualizar `.env`
3. Agregar helper `docker_logs_contain_port_error()` para detectar errores de bind en los logs de Docker

### Fase 3: Puerto configurable (P4)

**Prioridad:** Media
**Archivos:** `libs/local/restore_backup_helper.sh`, `utils/brolit_configuration_manager.sh`, config template
**Riesgo:** Bajo

1. Agregar sección `DOCKER` al config JSON
2. Cargar variables en `brolit_configuration_manager.sh`
3. Reemplazar hardcoded `"81" "350"` por las variables

### Fase 4: Logging de asignaciones (P5)

**Prioridad:** Baja
**Archivos:** `libs/local/restore_backup_helper.sh`
**Riesgo:** Bajo

1. Trackear asignaciones de puerto durante batch restore
2. Mostrar tabla en el summary final
3. Incluir en la notificación

### Fase 5: Separar configuración de build (P6)

**Prioridad:** Baja (futuro)
**Archivos:** `libs/local/restore_backup_helper.sh`
**Riesgo:** Medio (refactoring)

1. Extraer `docker_configure_env()` de `docker_setup_configuration()`
2. Extraer `docker_build_and_up()`
3. Actualizar callers (restore, borg restore, install)
4. Habilitar parallel up en batch restore

---

## Notas

- `ss` es parte de `iproute2`, instalado por defecto en Debian/Ubuntu.
- `ss -tlnH` muestra puertos TCP en estado LISTEN, sin resolver nombres (-n), sin header (-H).
- El rango 81-350 se eligió para evitar conflicto con puertos well-known (0-80) y servicios comunes (443, 3306, 5432, 8080, etc.).

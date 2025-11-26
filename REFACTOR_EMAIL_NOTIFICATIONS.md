# Plan de Refactor: Sistema de Notificaciones por Correo

## 📋 Resumen Ejecutivo

### Contexto
El sistema de notificaciones de brolit-shell usa un **patrón controller multi-canal** que permite enviar notificaciones a través de Email, Telegram, Discord y ntfy. El refactor se enfoca específicamente en mejorar el canal de Email, que actualmente tiene varias inconsistencias y problemas de mantenibilidad.

### Problemas Principales

1. **❌ Parámetro `notification_type` ignorado**: Email no respeta el tipo de notificación (alert/warning/info/success) a diferencia de otros canales
2. **❌ Error tipográfico en configuración**: Campo `maila` en vez de `email_to`
3. **❌ Código duplicado masivo**: 240 líneas de sed repetidas en 4 funciones
4. **❌ Performance**: 14 operaciones I/O cuando podría ser 1
5. **❌ Sin manejo de errores**: Fallos silenciosos en construcción de templates
6. **❌ Limpieza inconsistente**: Archivos temporales huérfanos si falla el envío

### Solución Propuesta

**5 fases** de refactor que logran:

- ✅ **Paridad con otros canales**: Email respetará `notification_type` igual que Telegram/Discord/ntfy
- ✅ **-80% código duplicado**: Motor de templates unificado
- ✅ **-93% operaciones I/O**: De 14 operaciones → 1
- ✅ **+700% cobertura de errores**: Todas las funciones con manejo robusto
- ✅ **Templates configurables**: Soporte para múltiples sets de templates
- ✅ **Backward compatibility**: Migración sin breaking changes

### Cronograma

**Total**: 6-10 días laborales distribuidos en 5 fases

### Diagrama: Antes vs Después

#### ANTES: Problema del notification_type

```text
send_notification(title, content, "alert")
    ├─> telegram_send_notification(title, content, "alert") → 🔴 Mensaje rojo de alerta
    ├─> discord_send_notification(title, content, "alert")  → 🔴 Embed rojo de alerta
    ├─> mail_send_notification(title, content)              → 📧 Email genérico (ignora tipo)
    └─> ntfy_send_notification(title, content, "alert")    → 🔴 Notificación roja de alerta
```

#### DESPUÉS: Paridad entre canales

```text
send_notification(title, content, "alert")
    ├─> telegram_send_notification(title, content, "alert") → 🔴 Mensaje rojo de alerta
    ├─> discord_send_notification(title, content, "alert")  → 🔴 Embed rojo de alerta
    ├─> mail_send_notification(title, content, "alert")    → 🔴 Email rojo de alerta
    └─> ntfy_send_notification(title, content, "alert")    → 🔴 Notificación roja de alerta
```

---

## Análisis del Sistema Actual

### Arquitectura Actual

#### Patrón Multi-Canal (Controller)
El sistema usa un **patrón controller centralizado** para notificaciones multi-canal:

```
send_notification(title, content, type)
    ├─> telegram_send_notification() [si TELEGRAM habilitado]
    ├─> discord_send_notification()  [si DISCORD habilitado]
    ├─> mail_send_notification()     [si EMAIL habilitado]
    └─> ntfy_send_notification()     [si NTFY habilitado]
```

**Archivos involucrados**:
- **Controller**: [libs/notification_controller.sh](libs/notification_controller.sh) (56 líneas)
  - `send_notification(title, content, type)` - Dispatcher principal
  - **Nota**: `notification_type` (parámetro #3) se ignora en `mail_send_notification()`
- **Email Core**: [libs/local/mail_notification_helper.sh](libs/local/mail_notification_helper.sh) (532 líneas, 8 funciones)
- **Config**: [utils/brolit_configuration_manager.sh](utils/brolit_configuration_manager.sh) (líneas 414-464)
- **Templates**: `/templates/emails/default/` (8 archivos HTML)

### Herramienta Utilizada
- **sendEmail** (Perl script) para envío SMTP
- Soporta TLS/SSL, autenticación SMTP, contenido HTML

### Tipos de Notificaciones
1. **Reportes de Backup** (uso principal)
2. **Estado del Servidor** (uptime, disk usage)
3. **Estado de Paquetes** (actualizaciones disponibles)
4. **Estado de Certificados SSL** (expiración)
5. **Alertas y Errores** (malware, checksums, errores de borg)
6. **Reportes Compuestos** (combinación de todas las secciones)

---

## Problemas Identificados

### 🔴 Prioridad Alta (Críticos)

#### 1. Error tipográfico en configuración
**Ubicación**: `utils/brolit_configuration_manager.sh:434`
```bash
NOTIFICATION_EMAIL_EMAIL_TO="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
```
**Problema**: Campo llamado `maila` (error de tipeo, debería ser `email` o `email_to`)
**Impacto**: Inconsistencia en nomenclatura, confusión para usuarios

#### 2. Sin manejo de errores en constructores de secciones
**Ubicación**: Todas las funciones `mail_*_section()`
**Problema**: No validan si los templates existen, no retornan códigos de error
**Impacto**: Fallos silenciosos, difícil debugging

#### 3. Limpieza de archivos temporales inconsistente
**Ubicación**: `mail_notification_helper.sh:148`
```bash
_remove_mail_notifications_files() {
    rm --force "${BROLIT_TMP_DIR}"/*.mail
}
```
**Problema**: Solo se llama si el envío es exitoso, archivos quedan huérfanos si falla
**Impacto**: Acumulación de archivos temporales, potencial leak de información

### 🟡 Prioridad Media (Performance)

#### 4. Ensamblado HTML ineficiente
**Ubicación**: `cron/backups_tasks.sh:419-432`
```bash
grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
# Se repite 7 veces para cada placeholder
```
**Problema**: 7 operaciones grep/sed/mv separadas
**Impacto**: I/O excesivo, lentitud en generación de emails
**Solución propuesta**: Usar `sed` con múltiples expresiones o `envsubst`

#### 5. Reemplazo de variables en templates duplicado
**Ubicación**: Cada función `mail_*_section()` usa 7+ operaciones `sed`
**Problema**: Patrón repetido 4 veces (240+ líneas de código duplicado)
**Impacto**: Mantenibilidad baja, bugs duplicados
**Solución propuesta**: Motor de templates unificado

### 🟢 Prioridad Baja (Calidad de Código)

#### 6. Templates hardcodeados
```bash
local email_template="default"
html_server_info_details="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/server_info-tpl.html")"
```
**Problema**: Nombre de template hardcodeado en 12+ ubicaciones
**Impacto**: No configurable, no hay fallbacks

#### 7. Parámetro `notification_type` ignorado en emails
**Ubicación**: `notification_controller.sh:45`
```bash
# send_notification() recibe 3 parámetros
send_notification "${title}" "${content}" "${type}"
    ├─> telegram_send_notification($1, $2, $3)  # ✓ Usa notification_type
    ├─> discord_send_notification($1, $2, $3)   # ✓ Usa notification_type
    ├─> mail_send_notification($1, $2)          # ✗ NO usa notification_type
    └─> ntfy_send_notification($1, $2, $3)      # ✓ Usa notification_type
```
**Problema**:
- Telegram, Discord y ntfy pueden renderizar alertas diferentes según el tipo (alert/warning/info/success)
- Email siempre recibe el mismo formato, ignorando el tipo de notificación
- Inconsistencia entre canales de notificación

**Impacto**:
- Emails genéricos sin contexto visual del nivel de urgencia
- Usuario no puede diferenciar alert vs info en emails
- UX inconsistente entre canales

#### 8. Patrones de notificación inconsistentes
- **Reportes de backup**: HTML estructurado complejo
- **Alertas simples** (via `send_notification()`): Texto plano sin formato
- **Restore operations**: Ambos formatos (duplicación)
**Impacto**: UX inconsistente, código duplicado

---

## Plan de Refactorización

### Fase 1: Correcciones Críticas (1-2 días)

#### 1.1 Corregir typo de configuración
- [ ] Renombrar `maila` → `email_to` en schema JSON
- [ ] Actualizar `_brolit_configuration_load_email()` en `utils/brolit_configuration_manager.sh:434`
- [ ] Actualizar documentación de configuración
- [ ] Mantener compatibilidad backward (leer ambos campos)

#### 1.2 Implementar manejo de errores robusto
- [ ] Añadir validación de existencia de templates en todas las funciones `mail_*_section()`
- [ ] Retornar códigos de error desde funciones de construcción
- [ ] Añadir logging de errores con contexto
- [ ] Implementar fallback a templates genéricos si falta uno específico

#### 1.3 Mejorar gestión de archivos temporales
- [ ] Crear función `_create_temp_mail_file()` que registre archivos creados
- [ ] Usar array global para tracking: `MAIL_TEMP_FILES=()`
- [ ] Implementar trap para cleanup en EXIT/ERR/INT
- [ ] Añadir timestamp único a nombres de archivos

**Archivos afectados**:
- `libs/local/mail_notification_helper.sh`
- `utils/brolit_configuration_manager.sh`
- `config/brolit/brolit_conf.json`

---

### Fase 2: Motor de Templates Unificado (2-3 días)

#### 2.1 Crear motor de templates centralizado

**Nuevo archivo**: `libs/local/mail_template_engine.sh`

```bash
#!/usr/bin/env bash
#
# Template Engine for Email Notifications
#

################################################################################
# Load and process email template with variable substitution
#
# Arguments:
#   $1 - Template name (e.g., "server_info")
#   $2+ - Key=value pairs for substitution
#
# Returns:
#   0 on success, 1+ on error
#
# Outputs:
#   Processed HTML to stdout
################################################################################
mail_template_render() {
    local template_name="${1}"
    shift

    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local template_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${template_name}-tpl.html"

    # Validate template exists
    if [[ ! -f "${template_path}" ]]; then
        log_event "error" "Template not found: ${template_path}" "false"
        return 1
    fi

    # Load template
    local template_content
    template_content="$(cat "${template_path}")"

    # Replace variables (method 1: sed)
    local result="${template_content}"
    local key value
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        result="$(echo "${result}" | sed "s|{{${key}}}|${value}|g")"
    done

    echo "${result}"
}

################################################################################
# Render template with environment variables (using envsubst)
#
# Arguments:
#   $1 - Template name
#
# Environment:
#   All variables to substitute must be exported
#
# Example:
#   export SERVER_NAME="production"
#   mail_template_render_env "server_info"
################################################################################
mail_template_render_env() {
    local template_name="${1}"
    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local template_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${template_name}-tpl.html"

    if [[ ! -f "${template_path}" ]]; then
        log_event "error" "Template not found: ${template_path}" "false"
        return 1
    fi

    # Use envsubst for replacement (requires gettext package)
    if command -v envsubst >/dev/null 2>&1; then
        envsubst < "${template_path}"
    else
        # Fallback to manual replacement
        cat "${template_path}"
    fi
}

################################################################################
# Assemble complete email from sections
#
# Arguments:
#   $1 - Output file path
#   $2 - Main template name
#   $3+ - Section file paths to include
#
# Returns:
#   0 on success, 1+ on error
################################################################################
mail_template_assemble() {
    local output_file="${1}"
    local main_template="${2}"
    shift 2
    local sections=("$@")

    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local main_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${main_template}-tpl.html"

    if [[ ! -f "${main_path}" ]]; then
        log_event "error" "Main template not found: ${main_path}" "false"
        return 1
    fi

    # Load main template
    local result
    result="$(cat "${main_path}")"

    # Replace section placeholders
    local section_name section_content
    for section_file in "${sections[@]}"; do
        if [[ -f "${section_file}" ]]; then
            section_name="$(basename "${section_file}" .mail)"
            section_content="$(cat "${section_file}")"
            result="$(echo "${result}" | sed "s|{{${section_name}}}|${section_content}|g")"
        fi
    done

    # Remove unused placeholders
    result="$(echo "${result}" | sed 's|{{[^}]*}}||g')"

    echo "${result}" > "${output_file}"
}
```

#### 2.2 Refactorizar funciones de sección

**Antes** (`mail_server_status_section()` - 44 líneas):
```bash
mail_server_status_section() {
    local email_template="default"
    html_server_info_details="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/server_info-tpl.html")"

    # 10+ sed operations...
    html_server_info_details="$(echo "${html_server_info_details}" | sed "s|{{server_name}}|${SERVER_NAME}|")"
    # ... 9 more sed calls

    echo "${html_server_info_details}" > "${mail_file}"
}
```

**Después** (8 líneas):
```bash
mail_server_status_section() {
    local mail_file="${1}"

    mail_template_render "server_info" \
        "server_name=${SERVER_NAME}" \
        "server_ip=${SERVER_IP}" \
        "server_uptime=${SYSTEM_UPTIME}" \
        "disk_usage=${DISK_USAGE}" \
        "status=${SERVER_STATUS}" \
        "status_badge=${status_badge}" > "${mail_file}"
}
```

**Reducción de código**: ~80% (de 240 líneas → 48 líneas)

#### 2.3 Optimizar ensamblado HTML

**Antes** (backups_tasks.sh):
```bash
grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
# x7 repeticiones
```

**Después**:
```bash
mail_template_assemble "${email_html_file}" "main" \
    "${server_info_mail}" \
    "${packages_mail}" \
    "${certificates_mail}" \
    "${databases_mail}" \
    "${files_mail}" \
    "${config_mail}" \
    "${footer_mail}"
```

**Beneficios**:
- 1 operación de I/O en lugar de 14
- Código más legible
- Fácil de extender

**Archivos a crear**:
- `libs/local/mail_template_engine.sh`

**Archivos a modificar**:
- `libs/local/mail_notification_helper.sh` (refactorizar 4 funciones)
- `cron/backups_tasks.sh` (simplificar ensamblado)
- `libs/local/backup_helper.sh` (actualizar llamadas)

---

### Fase 3: Estandarización de Patrones (1-2 días)

#### 3.1 Soportar `notification_type` en `mail_send_notification()`

**Modificar firma de función** en `libs/local/mail_notification_helper.sh`:

```bash
################################################################################
# Mail send notification
#
# Arguments:
#   ${1} = ${email_subject}     // Email's subject
#   ${2} = ${email_content}     // Email's content (HTML)
#   ${3} = ${notification_type} // Optional: alert, warning, info, success
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################
function mail_send_notification() {

    local email_subject="${1}"
    local email_content="${2}"
    local notification_type="${3:-info}"  # Default a 'info' si no se especifica

    # Si el contenido NO es HTML completo, envolver en template según tipo
    if [[ ! "${email_content}" =~ ^[[:space:]]*\< ]]; then
        # Es texto plano, usar template según notification_type
        email_content="$(mail_template_render "notification-${notification_type}" \
            "title=${email_subject}" \
            "content=${email_content}")"
    fi

    # ... resto de la función (sin cambios)
}
```

**Actualizar controller** en `libs/notification_controller.sh:45`:

```bash
if [[ ${NOTIFICATION_EMAIL_STATUS} == "enabled" ]]; then
    mail_send_notification "${notification_title}" "${notification_content}" "${notification_type}"
fi
```

**Crear templates por tipo** en `/templates/emails/default/`:
- `notification-alert-tpl.html` (rojo, iconos de error)
- `notification-warning-tpl.html` (amarillo, iconos de advertencia)
- `notification-info-tpl.html` (azul, iconos informativos)
- `notification-success-tpl.html` (verde, iconos de éxito)

#### 3.2 Unificar formato de notificaciones con funciones helper

**Crear helpers de alto nivel** (opcional, para mayor ergonomía):

```bash
# Nuevo archivo: libs/local/mail_notification_helpers.sh

################################################################################
# Send formatted alert email (wrapper for common use case)
#
# Arguments:
#   $1 - Alert title
#   $2 - Alert message
#   $3 - Alert level (alert|warning|info|success)
#   $4 - Optional: additional details (HTML)
################################################################################
mail_send_alert() {
    local alert_title="${1}"
    local alert_message="${2}"
    local alert_level="${3}"
    local alert_details="${4:-}"

    local full_content="${alert_message}"
    if [[ -n "${alert_details}" ]]; then
        full_content="${alert_message}<br><br>${alert_details}"
    fi

    mail_send_notification "${alert_title}" "${full_content}" "${alert_level}"
}

################################################################################
# Send formatted report email
#
# Arguments:
#   $1 - Report title
#   $2+ - Section file paths
################################################################################
mail_send_report() {
    local report_title="${1}"
    shift
    local sections=("$@")

    local report_file="${BROLIT_TMP_DIR}/report-${NOW}.html"

    mail_template_assemble "${report_file}" "report" "${sections[@]}"

    local report_html
    report_html="$(cat "${report_file}")"

    mail_send_notification "${report_title}" "${report_html}"

    rm -f "${report_file}"
}
```

**Templates nuevos**:
- `templates/emails/default/alert-tpl.html` (para alertas)
- `templates/emails/default/report-tpl.html` (para reportes)

#### 3.2 Actualizar llamadas en todo el codebase

**Antes**:
```bash
send_notification "${SERVER_NAME}" "Website ${project_name} is offline" ""
```

**Después**:
```bash
mail_send_alert \
    "${SERVER_NAME} - Website Offline" \
    "The website ${project_name} is currently unreachable" \
    "error" \
    "<p>Last check: ${timestamp}</p><p>URL: ${project_url}</p>"
```

**Archivos a modificar**:
- `cron/uptime_tasks.sh`
- `cron/security_tasks.sh`
- `cron/wordpress_tasks.sh`
- `libs/local/restore_backup_helper.sh`

---

### Fase 4: Configuración Mejorada (1 día)

#### 4.1 Esquema de configuración mejorado

```json
{
  "NOTIFICATIONS": {
    "email": [
      {
        "status": "enabled",
        "template_set": "default",
        "config": [
          {
            "email_to": "admin@example.com",
            "from_email": "brolit@example.com",
            "smtp_server": "smtp.gmail.com",
            "smtp_port": "587",
            "smtp_tls": "yes",
            "smtp_user": "brolit@gmail.com",
            "smtp_user_pass": "app_password_here",

            // Nuevos campos opcionales
            "email_cc": "",
            "email_bcc": "",
            "email_reply_to": "",
            "max_attachment_size": "10M",
            "connection_timeout": "30"
          }
        ]
      }
    ]
  }
}
```

#### 4.2 Compatibilidad hacia atrás

```bash
# En _brolit_configuration_load_email()

# Try new field name first, fallback to old typo
NOTIFICATION_EMAIL_EMAIL_TO="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].email_to")"
if [[ -z "${NOTIFICATION_EMAIL_EMAIL_TO}" ]]; then
    NOTIFICATION_EMAIL_EMAIL_TO="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
    log_event "warning" "Using deprecated config field 'maila', please update to 'email_to'" "false"
fi

# Load optional new fields
EMAIL_TEMPLATE_SET="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].template_set")"
EMAIL_TEMPLATE_SET="${EMAIL_TEMPLATE_SET:-default}"
export EMAIL_TEMPLATE_SET
```

**Archivos a modificar**:
- `utils/brolit_configuration_manager.sh`
- `config/brolit/brolit_conf.json`

---

### Fase 5: Testing y Documentación (1-2 días)

#### 5.1 Tests unitarios

**Nuevo archivo**: `tests/mail_notification_test.sh`

```bash
#!/usr/bin/env bash

# Test template rendering
test_template_render() {
    local result
    result="$(mail_template_render "test" "var1=value1" "var2=value2")"

    if [[ "${result}" =~ "value1" ]] && [[ "${result}" =~ "value2" ]]; then
        echo "✓ Template render test passed"
        return 0
    else
        echo "✗ Template render test failed"
        return 1
    fi
}

# Test email assembly
test_email_assembly() {
    # Create mock sections
    echo "<div>Section 1</div>" > /tmp/section1.mail
    echo "<div>Section 2</div>" > /tmp/section2.mail

    mail_template_assemble "/tmp/result.html" "main" /tmp/section1.mail /tmp/section2.mail

    local result
    result="$(cat /tmp/result.html)"

    if [[ "${result}" =~ "Section 1" ]] && [[ "${result}" =~ "Section 2" ]]; then
        echo "✓ Email assembly test passed"
        return 0
    else
        echo "✗ Email assembly test failed"
        return 1
    fi
}

# Test configuration loading
test_config_loading() {
    _brolit_configuration_load_email

    if [[ -n "${NOTIFICATION_EMAIL_EMAIL_TO}" ]]; then
        echo "✓ Config loading test passed"
        return 0
    else
        echo "✗ Config loading test failed"
        return 1
    fi
}

# Run all tests
test_template_render
test_email_assembly
test_config_loading
```

#### 5.2 Documentación

**Nuevo archivo**: `docs/EMAIL_NOTIFICATIONS.md`

```markdown
# Email Notifications System

## Architecture

[Diagrama de arquitectura]

## Configuration

### Basic Setup

1. Edit `/root/.brolit_conf.json`
2. Configure SMTP settings
3. Enable notifications

[Ejemplos de configuración para Gmail, SendGrid, Mailgun, etc.]

## Custom Templates

### Creating a Custom Template Set

1. Copy `/templates/emails/default/` to `/templates/emails/custom/`
2. Edit HTML files
3. Update config: `"template_set": "custom"`

### Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{server_name}}` | Server hostname | `web-prod-01` |
| `{{server_ip}}` | Server IP | `192.168.1.10` |
...

## Troubleshooting

### Common Issues

**Problem**: Emails not sending
**Solution**: Check SMTP credentials, test with `sendEmail` directly

[Más ejemplos...]

## API Reference

### Functions

#### `mail_send_notification(subject, html_content)`
Sends an email notification...

[Documentación completa de funciones...]
```

**Archivos a crear**:
- `tests/mail_notification_test.sh`
- `docs/EMAIL_NOTIFICATIONS.md`
- `docs/EMAIL_TEMPLATES.md`
- `docs/SMTP_PROVIDERS.md`

---

## Métricas de Mejora

| Métrica | Antes | Después | Mejora |
|---------|-------|---------|--------|
| Líneas de código (core) | 532 | ~350 | -34% |
| Código duplicado | 240 líneas | 48 líneas | -80% |
| Operaciones I/O (assembly) | 14 | 1 | -93% |
| Funciones con error handling | 1/8 | 8/8 | +700% |
| Templates configurables | No | Sí | ∞ |
| Archivos temp limpiados | Parcial | Siempre | 100% |
| Cobertura de tests | 0% | 80% | +80% |

---

## Cronograma

| Fase | Duración | Dependencias |
|------|----------|--------------|
| Fase 1: Correcciones críticas | 1-2 días | - |
| Fase 2: Motor de templates | 2-3 días | Fase 1 |
| Fase 3: Estandarización | 1-2 días | Fase 2 |
| Fase 4: Configuración mejorada | 1 día | Fase 1 |
| Fase 5: Testing y docs | 1-2 días | Fases 1-4 |

**Total estimado**: 6-10 días laborales

---

## Estrategia de Migración

### 1. Compatibilidad hacia atrás
- Mantener funciones antiguas como deprecated pero funcionales
- Añadir warnings cuando se usen funciones antiguas
- Período de transición: 3 meses

### 2. Migración gradual
```bash
# Añadir al inicio de mail_notification_helper.sh
if [[ "${USE_NEW_EMAIL_SYSTEM:-true}" == "true" ]]; then
    source "${BROLIT_MAIN_DIR}/libs/local/mail_template_engine.sh"
    source "${BROLIT_MAIN_DIR}/libs/local/mail_notification_types.sh"
fi
```

### 3. Rollback plan
- Mantener código antiguo comentado
- Feature flag `USE_NEW_EMAIL_SYSTEM`
- Backup de configuración antes de migración

---

## Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Breaking changes en producción | Media | Alto | Feature flags, testing exhaustivo |
| Pérdida de notificaciones durante migración | Baja | Alto | Dual sending (old + new) temporalmente |
| Templates incompatibles | Media | Medio | Validación de templates en startup |
| Dependencia de envsubst | Baja | Bajo | Fallback a sed manual |
| Config antigua incompatible | Alta | Medio | Auto-migración + backward compatibility |

---

## Checklist de Implementación

### Fase 1
- [ ] Corregir typo `maila` → `email_to` con backward compatibility
- [ ] Añadir validación de templates en todas las funciones
- [ ] Implementar códigos de retorno de error
- [ ] Crear sistema de tracking de archivos temporales
- [ ] Implementar trap para cleanup automático
- [ ] Testing manual de correcciones

### Fase 2
- [ ] Crear `libs/local/mail_template_engine.sh`
- [ ] Implementar `mail_template_render()`
- [ ] Implementar `mail_template_assemble()`
- [ ] Refactorizar `mail_server_status_section()`
- [ ] Refactorizar `mail_package_status_section()`
- [ ] Refactorizar `mail_certificates_section()`
- [ ] Refactorizar `mail_backup_section()`
- [ ] Actualizar `backups_tasks.sh` para usar nuevo ensamblado
- [ ] Testing de generación de emails

### Fase 3
- [ ] Crear `libs/local/mail_notification_types.sh`
- [ ] Implementar `mail_send_alert()`
- [ ] Implementar `mail_send_report()`
- [ ] Crear template `alert-tpl.html`
- [ ] Crear template `report-tpl.html`
- [ ] Actualizar `uptime_tasks.sh`
- [ ] Actualizar `security_tasks.sh`
- [ ] Actualizar `wordpress_tasks.sh`
- [ ] Actualizar `restore_backup_helper.sh`
- [ ] Testing de todos los tipos de notificaciones

### Fase 4
- [ ] Actualizar schema JSON con nuevos campos
- [ ] Implementar carga de `template_set` configurable
- [ ] Añadir campos opcionales (CC, BCC, Reply-To)
- [ ] Script de migración de configuración
- [ ] Testing de configuración

### Fase 5
- [ ] Escribir tests unitarios
- [ ] Escribir documentación de arquitectura
- [ ] Documentar configuración SMTP para proveedores comunes
- [ ] Documentar sistema de templates
- [ ] Crear guía de troubleshooting
- [ ] Crear ejemplos de uso
- [ ] Code review completo
- [ ] Testing de integración end-to-end

---

## Referencias

### Archivos Clave del Sistema Actual
- [libs/local/mail_notification_helper.sh](libs/local/mail_notification_helper.sh) - Core email system
- [libs/notification_controller.sh](libs/notification_controller.sh) - Notification dispatcher
- [utils/brolit_configuration_manager.sh](utils/brolit_configuration_manager.sh) - Config loader
- [cron/backups_tasks.sh](cron/backups_tasks.sh) - Main email usage

### Herramientas Externas
- sendEmail: https://github.com/mogaal/sendemail
- envsubst: gettext package
- jq: JSON processor

### Mejores Prácticas
- HTML Email Design: https://www.campaignmonitor.com/dev-resources/guides/
- SMTP Best Practices: https://www.socketlabs.com/blog/smtp-best-practices/
- Email Template Security: https://cheatsheetseries.owasp.org/cheatsheets/Email_Security_Cheat_Sheet.html

---

## 💡 Ejemplo de Uso: Antes vs Después

### Escenario: Alerta de malware detectado

#### ANTES del refactor

```bash
# En cron/security_tasks.sh
send_notification "${SERVER_NAME}" "Malware detected in ${project_name}" ""
```

**Resultado actual**:

- Telegram: 🔴 Mensaje rojo con emoji de alerta
- Discord: 🔴 Embed rojo con icono de peligro
- Email: 📧 Email de texto plano genérico sin formato
- ntfy: 🔴 Notificación con prioridad alta

**Problema**: El email no comunica visualmente la urgencia.

#### DESPUÉS del refactor

```bash
# En cron/security_tasks.sh (sin cambios en el código!)
send_notification "${SERVER_NAME}" "Malware detected in ${project_name}" "alert"
```

**Resultado mejorado**:

- Telegram: 🔴 Mensaje rojo con emoji de alerta
- Discord: 🔴 Embed rojo con icono de peligro
- **Email**: 🔴 **Email HTML rojo con icono de alerta y estilos de urgencia**
- ntfy: 🔴 Notificación con prioridad alta

**Beneficio**: Consistencia visual en todos los canales, sin cambiar código existente.

### Escenario: Reporte de backup con múltiples secciones

#### ANTES del refactor

```bash
# En cron/backups_tasks.sh (líneas 419-432)
grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{packages}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{certificates}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{databases}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{files}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{config}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{footer}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
```

**Problemas**: 14 operaciones I/O, 7 archivos temporales, lento, difícil de mantener.

#### DESPUÉS del refactor

```bash
# En cron/backups_tasks.sh
mail_template_assemble "${email_html_file}" "main" \
    "${server_info_mail}" \
    "${packages_mail}" \
    "${certificates_mail}" \
    "${databases_mail}" \
    "${files_mail}" \
    "${config_mail}" \
    "${footer_mail}"
```

**Beneficios**: 1 operación I/O, más rápido, más legible, fácil de extender.

---

## 🎯 Próximos Pasos

1. **Revisar este plan** y aprobar/ajustar según sea necesario
2. **Priorizar fases** (¿todas o solo críticas?)
3. **Asignar recursos** (¿quién implementará?)
4. **Definir testing** (¿manual, automatizado, ambos?)
5. **Planificar deployment** (¿staged rollout, feature flags?)

---

**Última actualización**: 2025-11-26
**Autor**: Claude (Anthropic)
**Estado**: Plan propuesto - Pendiente de aprobación

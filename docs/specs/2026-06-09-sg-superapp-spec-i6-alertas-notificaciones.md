# SPEC I6 - Alertas y Notificaciones

**Fecha:** 2026-06-09  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I6  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**SPECs relacionadas:**  
- `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i5-cursos-acreditaciones.md`  
**Estado:** Revisada y aprobada para planificacion I6  

---

## 1. Proposito

Implementar un centro de alertas y notificaciones interno para el piloto Talento Humano, operable por rol, con trazabilidad de lectura/gestion y con capacidad de generar alertas desde eventos ya disponibles en I2, I4 e I5.

I6 debe convertir los datos y eventos del piloto en una bandeja accionable para Talento Humano, Operaciones y Gerencia, sin depender de WhatsApp, integraciones externas ni bloqueo automatico de turnos.

---

## 2. Alcance

### Incluido

- Notificaciones personales.
- Notificaciones por rol.
- Contador visible junto al perfil/shell.
- Bandeja de notificaciones por usuario autenticado.
- Marcar como leida.
- Archivar.
- Borrar o descartar logicamente cuando aplique.
- Trazabilidad de gestion: usuario, accion, fecha y resultado.
- Alertas por vencimiento de cursos/acreditaciones usando reglas I5.
- Alertas por cargas de importacion con errores.
- Alertas por certificaciones generadas/aprobadas.
- Correo a Talento Humano si SMTP esta disponible.
- Fallback exportable si SMTP no esta disponible.

### Fuera de alcance

- WhatsApp.
- Notificaciones a guardas como usuarios finales.
- Push notifications moviles.
- Integracion HELIZA.
- Integracion nomina.
- Bloqueo automatico de programacion de turnos.
- Motor de novedades completo.
- IA avanzada o priorizacion predictiva.
- Cambio de stack o instalacion de dependencias no aprobadas.

---

## 3. Actores

### Administrador

Consulta, depura y valida reglas operativas de notificacion. Puede ver la trazabilidad y apoyar soporte.

### Talento Humano

Gestiona alertas de cursos/acreditaciones, cargas con error y certificaciones. Atiende, lee, archiva y exporta resumen cuando el correo no este disponible.

### Operaciones / Consulta

Consulta alertas de habilitacion/cumplimiento relevantes para servicio, sin editar datos maestros ni reglas.

### Gerencia / Consulta

Consulta notificaciones e indicadores ejecutivos del piloto, sin editar reglas ni datos TH.

---

## 4. Conceptos De Dominio

### Notificacion

Campos minimos:

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| target_type | Si | `USER` o `ROLE` |
| target_key | Si | username o codigo de rol |
| title | Si | Texto breve |
| body | Si | Detalle operativo |
| severity | Si | `INFO`, `WARNING`, `CRITICAL` |
| source_module | Si | `IMPORTS`, `CERTIFICATES`, `TRAINING`, `SYSTEM` |
| source_type | Si | Tipo de evento origen |
| source_id | No | Identificador del registro origen |
| status | Si | `UNREAD`, `READ`, `ARCHIVED`, `DISMISSED` |
| action_url | No | Ruta interna de la SPA |
| created_at | Si | Fecha/hora de creacion |
| read_at | No | Fecha/hora de lectura |
| managed_at | No | Fecha/hora de gestion |
| managed_by | No | Usuario que gestiono |

### Evento De Notificacion

Registro de trazabilidad cada vez que una notificacion cambia de estado.

Campos minimos:

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| notification_id | Si | Notificacion asociada |
| actor_username | Si | Usuario que ejecuto la accion |
| event_type | Si | `CREATED`, `READ`, `ARCHIVED`, `DISMISSED`, `EXPORTED`, `EMAIL_ATTEMPTED`, `EMAIL_SENT`, `EMAIL_FAILED` |
| detail | No | JSON o texto estructurado |
| created_at | Si | Fecha/hora del evento |

### Resumen Exportable

Archivo o respuesta descargable con alertas filtradas por fecha, severidad, modulo y estado. Debe servir como fallback operativo cuando SMTP no este disponible.

---

## 5. Fuentes De Alerta

### Cursos y acreditaciones

Usa los estados calculados de I5:

- `VENCIDO` genera severidad `CRITICAL`.
- `CRITICO` genera severidad `CRITICAL`.
- `PREVENTIVO` genera severidad `WARNING`.
- `INFORMATIVO` genera severidad `INFO`.
- `AL_DIA` no genera alerta.

Reglas:

1. La regla de estado viene de I5 y no se duplica como texto manual.
2. Solo requisitos activos generan alertas.
3. Requisitos obligatorios para servicio deben marcar claramente impacto operativo.
4. `NO_HABILITADO` sigue siendo indicador, no bloqueo automatico.

### Importaciones

Genera alerta cuando:

- una carga queda `CON_ERRORES`;
- hay registros `ERRONEO`;
- hay registros `DUPLICADO`;
- hay registros `INCOMPLETO` que requieren decision de Talento Humano.

### Certificaciones laborales

Genera notificacion cuando:

- una certificacion se genera;
- una certificacion queda aprobada/generada;
- una certificacion se anula.

---

## 6. Flujos Esperados

### 6.1 Consultar Bandeja

1. Usuario autenticado entra al portal.
2. El shell muestra contador de no leidas.
3. Usuario abre la bandeja.
4. El sistema lista notificaciones personales y del rol del usuario.
5. Usuario filtra por estado, severidad o modulo.

### 6.2 Gestionar Notificacion

1. Usuario selecciona una notificacion.
2. Usuario marca como leida o archiva.
3. El sistema actualiza estado y registra evento de gestion.
4. Si la notificacion tiene ruta interna, el usuario puede navegar al modulo origen.

### 6.3 Generar Alertas De Vencimiento

1. Sistema evalua requisitos de cursos/acreditaciones activos.
2. Sistema genera o actualiza notificaciones para estados `VENCIDO`, `CRITICO`, `PREVENTIVO` e `INFORMATIVO`.
3. Sistema evita duplicar alertas activas para el mismo empleado/tipo/estado.
4. Sistema registra trazabilidad.

### 6.4 Fallback Exportable

1. TH filtra alertas.
2. TH exporta resumen.
3. Sistema genera archivo descargable.
4. Sistema registra evento `EXPORTED`.

### 6.5 Correo Si SMTP Esta Disponible

1. Administrador/TH valida configuracion SMTP disponible.
2. Sistema intenta envio de resumen a Talento Humano.
3. Sistema registra `EMAIL_SENT` o `EMAIL_FAILED`.
4. Si falla o no hay SMTP, el flujo operativo sigue con bandeja interna y exportacion.

---

## 7. Pantallas Esperadas

### 7.1 Bandeja De Notificaciones

Debe incluir:

- contador de no leidas;
- filtros por estado, severidad y modulo origen;
- listado compacto;
- detalle de notificacion;
- accion marcar como leida;
- accion archivar;
- acceso a ruta interna cuando exista.

### 7.2 Panel De Alertas TH

Debe incluir:

- alertas de cursos/acreditaciones por vencimiento;
- alertas de cargas con errores;
- alertas de certificaciones;
- exportacion de resumen;
- estado de intento de correo si aplica.

### 7.3 Consulta Operaciones/Gerencia

Debe incluir:

- lectura de alertas relevantes;
- sin acciones de configuracion;
- sin edicion de datos TH;
- estilo administrativo dark/gold.

---

## 8. Permisos

| Accion | Administrador | Talento Humano | Gerencia/Consulta | Operaciones/Consulta |
|--------|---------------|----------------|-------------------|----------------------|
| Ver bandeja propia/rol | Si | Si | Si | Si |
| Ver contador | Si | Si | Si | Si |
| Marcar como leida | Si | Si | Si | Si |
| Archivar propia/rol | Si | Si | Si | Si |
| Generar alertas manualmente | Si | Si | No | No |
| Exportar resumen | Si | Si | Si | Si |
| Configurar/intentar correo | Si | Si | No | No |
| Ver trazabilidad | Si | Si | Consulta limitada | Consulta limitada |

---

## 9. Reglas Funcionales

1. Toda notificacion debe pertenecer a `USER` o `ROLE`.
2. Solo usuarios autenticados ven notificaciones.
3. Usuarios ven notificaciones personales y las dirigidas a su rol.
4. Marcar como leida debe registrar `read_at` y evento.
5. Archivar debe registrar `managed_at`, `managed_by` y evento.
6. No se borran fisicamente notificaciones con trazabilidad funcional.
7. Alertas de cursos/acreditaciones reutilizan umbrales I5.
8. No se generan alertas para requisitos `AL_DIA`.
9. El sistema evita duplicar alertas activas para el mismo origen.
10. Importaciones con errores generan alerta para TH.
11. Certificaciones generadas/aprobadas/anuladas generan notificacion.
12. Correo no es dependencia bloqueante; si no hay SMTP, debe existir fallback exportable.
13. Operaciones y Gerencia consultan sin configurar reglas.
14. Toda gestion de notificacion deja auditoria o evento trazable.
15. La UI respeta `docs/DESIGN.md`.

---

## 10. Dependencias

I6 depende de:

- I1 para login, roles, permisos, shell y notificaciones base.
- I2 para importaciones y errores.
- I4 para certificaciones generadas/anuladas.
- I5 para cursos/acreditaciones, estados calculados y habilitacion.
- `docs/TECNOLOGIA.md` para definir correo como opcional con fallback.

---

## 11. Criterios De Aceptacion

I6 se considera aceptado cuando:

1. Existen notificaciones personales y por rol.
2. El contador de no leidas refleja bandeja personal/rol.
3. La bandeja lista notificaciones por usuario autenticado.
4. La bandeja filtra por estado, severidad y modulo.
5. Marcar como leida actualiza estado y trazabilidad.
6. Archivar actualiza estado y trazabilidad.
7. ADMIN/TH generan alertas de vencimiento desde reglas I5.
8. El sistema genera severidad correcta para VENCIDO/CRITICO/PREVENTIVO/INFORMATIVO.
9. No se generan alertas para AL_DIA.
10. No se duplican alertas activas del mismo origen.
11. Importaciones con error generan alerta para TH.
12. Certificaciones generadas/aprobadas/anuladas generan notificacion.
13. TH puede exportar resumen de alertas.
14. SMTP, si existe, registra intento y resultado.
15. Sin SMTP, el fallback exportable mantiene operacion.
16. Operaciones consulta alertas relevantes sin editar datos TH.
17. Gerencia consulta alertas relevantes sin editar datos TH.
18. Permisos backend protegen gestion/configuracion.
19. UI respeta estilo administrativo dark/gold.
20. Eventos de notificacion quedan listos para I7 dashboard/auditoria.

---

## 12. Pruebas Esperadas

Las verificaciones deben cubrir:

- persistencia de notificaciones y eventos;
- permisos por rol;
- listado, filtros y contador;
- marcar como leida;
- archivar;
- generacion de alertas I5 por vencimiento;
- deduplicacion de alertas;
- alertas de importaciones;
- alertas de certificaciones;
- exportacion fallback;
- intento SMTP con registro de exito/fallo si se configura;
- build backend;
- build frontend.

---

## 13. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| SMTP no disponible | Medio | Fallback exportable obligatorio |
| Usuarios esperan WhatsApp | Alto | Mantener fuera de alcance y documentarlo |
| Alertas duplicadas generan ruido | Alto | Clave de deduplicacion por modulo/tipo/origen/estado |
| Bandeja se vuelve demasiado generica | Medio | Filtrar por modulo, severidad y estado |
| Gerencia/Operaciones intentan gestionar datos TH | Medio | Permisos backend y UI de consulta |
| Jobs en Windows Server 2012 requieren decision operativa | Medio | Permitir generacion manual y dejar job programado como tarea compatible |

---

## 14. Preguntas Abiertas

No hay preguntas bloqueantes para planificar I6.

Decisiones cerradas:

1. WhatsApp queda fuera de I6.
2. Correo/SMTP es opcional y no bloquea la operacion.
3. Fallback exportable es obligatorio.
4. Las reglas de vencimiento vienen de I5.
5. `NO_HABILITADO` sigue siendo indicador, no bloqueo automatico.
6. Operaciones/Gerencia consultan sin editar.

---

## 15. Estado De La SPEC I6

Esta SPEC queda aprobada como contrato funcional de Alertas y Notificaciones. La implementacion queda autorizada solo mediante el plan I6 aprobado.

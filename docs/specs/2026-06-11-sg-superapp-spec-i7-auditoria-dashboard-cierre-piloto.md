# SPEC I7 - Auditoria, Dashboard y Cierre Piloto

**Fecha:** 2026-06-11  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I7  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**SPECs relacionadas:**  
- `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i5-cursos-acreditaciones.md`  
- `docs/specs/2026-06-09-sg-superapp-spec-i6-alertas-notificaciones.md`  
**Estado:** Revisada y aprobada para planificacion I7  

---

## 1. Proposito

Cerrar el piloto Talento Humano con una capa visible de auditoria, dashboard gerencial y evidencia ejecutiva para decidir escalamiento.

I7 no reabre funcionalidades cerradas en I1-I6. Su funcion es consolidar trazabilidad, indicadores, lectura por perfil, preparacion de demo y reporte de cierre piloto usando los datos, permisos y eventos ya construidos.

---

## 2. Alcance

### Incluido

- Dashboard comun con widgets por perfil.
- Indicadores de certificaciones laborales.
- Indicadores de cursos/acreditaciones y habilitacion de servicio.
- Indicadores de importaciones y calidad de datos.
- Indicadores de alertas/notificaciones.
- Consulta de auditoria transversal.
- Registro consultable de eventos relevantes del piloto.
- Preparacion de demo funcional.
- Reporte de cierre piloto.
- Backlog priorizado para la siguiente fase.
- Vista de `Novedades` como `Proximamente / En diseno` si no queda ya suficientemente visible.

### Fuera De Alcance

- Reabrir reglas funcionales de I1-I6 salvo defecto bloqueante demostrado.
- Implementar modulo completo de novedades.
- Implementar WhatsApp.
- Integrar HELIZA.
- Integrar nomina.
- Implementar analitica predictiva o IA avanzada.
- Implementar bloqueo automatico de asignaciones o turnos.
- Cambiar stack, despliegue o dependencias base.
- Crear guardas/empleados como usuarios del portal.

---

## 3. Actores

### Administrador

Consulta salud del piloto, usuarios, permisos, cargas, auditoria amplia y configuracion relevante. Puede apoyar validacion de demo y cierre.

### Talento Humano

Consulta indicadores operativos de certificaciones, cursos/acreditaciones, importaciones, alertas y auditoria funcional de sus procesos.

### Operaciones / Consulta

Consulta indicadores de habilitacion, puestos de servicio y restricciones visibles para operacion, sin editar datos TH.

### Gerencia / Consulta

Consulta dashboard ejecutivo, trazabilidad resumida, valor del piloto y backlog priorizado, sin acciones operativas.

### Sponsor / Evaluador Del Piloto

Revisa reporte de cierre, demo y recomendaciones de escalamiento.

---

## 4. Conceptos De Dominio

### Widget De Dashboard

Unidad visual de indicador o resumen operativo.

Campos esperados:

| Campo | Regla |
|-------|-------|
| id | Identificador estable |
| title | Titulo visible |
| scope | `EXECUTIVE`, `TH`, `OPERATIONS`, `ADMIN`, `SYSTEM` |
| metric | Valor principal |
| trend | Opcional; variacion o lectura cualitativa |
| severity | `INFO`, `WARNING`, `CRITICAL`, `SUCCESS` |
| action_url | Ruta interna opcional |
| visible_to_roles | Roles autorizados |

### Evento De Auditoria

Registro consultable de una accion relevante del piloto.

Campos esperados:

| Campo | Regla |
|-------|-------|
| id | Identificador interno |
| occurred_at | Fecha/hora del evento |
| actor_username | Usuario o `SYSTEM` |
| actor_role | Rol efectivo cuando aplique |
| module | Modulo origen |
| action | Accion funcional |
| entity_type | Tipo de entidad afectada |
| entity_id | Identificador de entidad si existe |
| summary | Texto breve para consulta |
| detail | JSON o texto estructurado |

### Reporte De Cierre Piloto

Artefacto documental que resume alcance construido, evidencia, riesgos, backlog y recomendacion de siguiente fase.

---

## 5. Fuentes De Indicadores

I7 debe consolidar datos de:

- usuarios, roles y permisos de I1;
- empleados, importaciones y errores de I2;
- puestos y asignaciones de I3;
- certificaciones y snapshots de I4;
- cursos/acreditaciones y estados calculados de I5;
- notificaciones, alertas y eventos de I6.

No debe duplicar reglas de negocio ya existentes; los widgets deben consultar o reutilizar servicios/contratos actuales.

---

## 6. Flujos Esperados

### 6.1 Consultar Dashboard Por Perfil

1. Usuario autenticado entra al portal.
2. El sistema identifica rol/permisos.
3. El dashboard muestra solo widgets autorizados.
4. Usuario puede navegar desde widgets a modulos origen cuando exista ruta.
5. Gerencia ve indicadores ejecutivos sin acciones de edicion.

### 6.2 Consultar Auditoria

1. Usuario autorizado abre auditoria.
2. Sistema lista eventos con filtros por modulo, accion, actor y rango de fechas.
3. Usuario revisa resumen y detalle.
4. Permisos limitan alcance de consulta por rol.

### 6.3 Preparar Demo

1. Se verifica que los flujos principales I1-I6 sigan disponibles.
2. Se documenta guion de demo por perfil.
3. Se valida dashboard, auditoria y cierre.
4. Se registra evidencia de verificacion.

### 6.4 Cerrar Piloto

1. Se ejecuta suite integral de I7.
2. Se genera reporte de cierre piloto.
3. Se registra backlog priorizado.
4. Se documentan riesgos residuales.
5. Se define recomendacion de escalamiento.

---

## 7. Pantallas Esperadas

### 7.1 Dashboard

Debe incluir:

- layout compacto dark/gold;
- widgets por perfil;
- indicadores ejecutivos visibles para Gerencia;
- indicadores operativos para TH;
- indicadores de consulta para Operaciones;
- indicadores de plataforma para Administrador;
- enlaces internos cuando aplique.

### 7.2 Auditoria

Debe incluir:

- filtros por modulo, accion, actor y fecha;
- tabla compacta de eventos;
- detalle estructurado;
- restricciones por rol;
- lectura sin edicion para Gerencia/Operaciones.

### 7.3 Cierre Piloto

Puede ser documental y/o pantalla interna simple. Debe consolidar:

- alcance construido;
- evidencias de verificacion;
- riesgos residuales;
- backlog recomendado;
- siguiente decision ejecutiva.

---

## 8. Permisos

| Accion | Administrador | Talento Humano | Gerencia/Consulta | Operaciones/Consulta |
|--------|---------------|----------------|-------------------|----------------------|
| Ver dashboard propio | Si | Si | Si | Si |
| Ver widgets ejecutivos | Si | Consulta limitada | Si | Consulta limitada |
| Ver widgets TH | Si | Si | Consulta limitada | Consulta limitada |
| Ver widgets operaciones | Si | Consulta limitada | Consulta limitada | Si |
| Consultar auditoria amplia | Si | No | Consulta limitada | No |
| Consultar auditoria funcional TH | Si | Si | Consulta limitada | No |
| Consultar auditoria operativa | Si | Consulta limitada | Consulta limitada | Si |
| Editar auditoria | No | No | No | No |
| Generar reporte de cierre | Si | Si | Consulta | Consulta |

---

## 9. Reglas Funcionales

1. Dashboard debe respetar permisos y rol efectivo.
2. Ningun widget debe exponer acciones no autorizadas.
3. Los indicadores deben basarse en datos persistidos o contratos existentes.
4. Auditoria no debe permitir editar ni borrar eventos.
5. Eventos de auditoria deben incluir actor, accion, modulo y fecha.
6. Gerencia y Operaciones consultan sin modificar datos TH.
7. El reporte de cierre debe separar alcance construido, riesgos y backlog.
8. I7 no cambia reglas cerradas de certificaciones, cursos, importaciones ni notificaciones.
9. `Novedades` permanece como futuro/diseno, no modulo funcional.
10. La demo debe poder ejecutarse sin integraciones externas.

---

## 10. Reglas No Funcionales

- Mantener compatibilidad con Windows Server 2012.
- Mantener React SPA + backend .NET + PostgreSQL.
- No agregar dependencias sin actualizar `docs/TECNOLOGIA.md`.
- Mantener UX administrativa, compacta y dark/gold.
- Evitar dashboards decorativos; todo widget debe ayudar a decision o seguimiento.
- Mantener consultas eficientes y acotadas por filtros.
- No depender de SMTP, internet ni servicios externos para cerrar I7.

---

## 11. Criterios De Aceptacion

1. Dashboard muestra widgets segun rol/permisos.
2. Administrador ve salud de plataforma, usuarios, cargas y trazabilidad.
3. Talento Humano ve certificaciones, cursos/acreditaciones, importaciones y alertas.
4. Operaciones ve habilitacion/no habilitacion y puestos/asignaciones relevantes.
5. Gerencia ve indicadores ejecutivos de valor del piloto.
6. Widgets no exponen acciones fuera de permisos.
7. Indicadores de certificaciones cuentan generadas/aprobadas/anuladas segun datos existentes.
8. Indicadores de cursos/acreditaciones reflejan `VENCIDO`, `CRITICO`, `PREVENTIVO`, `INFORMATIVO` y `AL_DIA`.
9. Indicadores de importacion reflejan validos, incompletos, duplicados, erroneos y cargas con errores.
10. Indicadores de notificaciones reflejan no leidas, severidad y gestion.
11. Auditoria lista eventos con fecha, actor, modulo, accion y entidad.
12. Auditoria filtra por modulo.
13. Auditoria filtra por actor.
14. Auditoria filtra por rango de fechas.
15. Auditoria respeta restricciones por rol.
16. Eventos existentes de importacion, certificacion y notificacion quedan consultables o representados.
17. Demo checklist cubre flujos I1-I7.
18. Reporte de cierre piloto registra alcance construido y evidencia de verificacion.
19. Backlog priorizado para siguiente fase queda documentado.
20. Riesgos residuales y recomendacion de escalamiento quedan documentados.

---

## 12. Pruebas Esperadas

- Verificacion backend de dashboard por rol.
- Verificacion backend de auditoria y filtros.
- Verificacion de seguridad por rol para widgets y auditoria.
- Verificacion frontend de dashboard y componentes esperados.
- Verificacion frontend de auditoria.
- Verificacion documental de demo, reporte y backlog.
- Build backend limpio.
- Build frontend limpio.
- Intento de `graphify update .` si la herramienta esta disponible.

---

## 13. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Datos demo insuficientes para indicadores | Medio | Usar seeds/mocks controlados y documentar supuestos de demo |
| Auditoria historica parcial por incrementos previos | Medio | Consolidar eventos existentes y documentar limites de cobertura |
| Dashboard se vuelve decorativo | Medio | Exigir trazabilidad de cada widget a decision operativa o ejecutiva |
| Reapertura de alcance I1-I6 | Alto | Tratar defectos como bugs puntuales; cambios de alcance requieren nueva SPEC |
| Consulta pesada sobre PostgreSQL | Medio | Filtros obligatorios, rangos razonables e indices si se justifican |
| `graphify` no disponible | Bajo | Intentar y documentar fallo sin bloquear cierre |

---

## 14. Decision De Entrada A Implementacion

I7 puede pasar a planificacion e implementacion incremental cuando exista plan aprobado con tareas verificables.

Retake inicial autorizado: Task 1 del plan I7, contratos backend de dashboard por rol.

# Handoff - S&G Super App Piloto TH / SDD Specs

**Fecha:** 2026-05-21  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Objetivo de continuidad:** retomar mañana desde la metodologia SDD y continuar con `SPEC I5 - Cursos y Acreditaciones`.

## Contexto Del Proyecto

S&G aprobo iniciar un piloto de Talento Humano con dos quick wins:

- Certificaciones laborales.
- Alertas de vencimiento de cursos y acreditaciones.

La decision rectora es que el piloto nace como **S&G Super App desde el dia 1**, no como scripts aislados. Es un portal interno administrativo con login, roles, datos maestros, trazabilidad, dashboard y notificaciones.

Servidor de aplicaciones confirmado: **Windows Server 2012**.

## Metodologia Aprobada

Se adopto **Spec-Driven Development (SDD), nivel Spec-Anchored**, tomando como ejemplo los artefactos de ProyectoContratosSED y el PDF de SDD.

Jerarquia documental vigente:

1. `docs/CONSTITUTION.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TECNOLOGIA.md`
4. `docs/DESIGN.md`
5. PRD vigente en `docs/prd/`
6. SPEC activa en `docs/specs/`
7. Plan en `docs/plans/`
8. Codigo fuente

Regla clave: no se implementa codigo sin SPEC aprobada y plan.

## Estructura Base Creada

- `README.md`
- `docs/CONSTITUTION.md`
- `docs/ARCHITECTURE.md`
- `docs/TECNOLOGIA.md`
- `docs/DESIGN.md`
- `docs/prd/`
- `docs/specs/`
- `docs/plans/`
- `Prototipos/`

`docs/DESIGN.md` es la autoridad visual. `Prototipos/` contiene prototipos, pantallas, mockups y capturas.

## Artefactos De Producto Y Presentacion

- PRD refinado:
  `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`

- HTML para stakeholders:
  `SG_PRD_Piloto_TH_SuperApp_v1.html`

- SPEC marco:
  `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md`

## Incrementos Definidos

| Incremento | Alcance | Estado |
|-----------|---------|--------|
| I0 | Descubrimiento tecnico e infraestructura | SPEC + plan operativo |
| I1 | Portal base | SPEC cerrada funcionalmente |
| I2 | Datos maestros e importacion | SPEC cerrada funcionalmente |
| I3 | Puestos de servicio y asignaciones | SPEC cerrada funcionalmente |
| I4 | Certificaciones laborales | SPEC cerrada funcionalmente |
| I5 | Cursos y acreditaciones | Pendiente |
| I6 | Alertas y notificaciones | Pendiente |
| I7 | Auditoria, dashboard y cierre piloto | Pendiente |

## I0 - Estado

Archivos:

- `docs/specs/2026-05-21-sg-superapp-spec-i0-descubrimiento-tecnico-infraestructura.md`
- `docs/plans/2026-05-21-sg-superapp-i0-descubrimiento-tecnico-plan.md`
- `docs/plans/i0-ficha-tecnica-servidor.md`
- `docs/plans/i0-matriz-decision-stack.md`

I0 esta listo para levantamiento con administrador del servidor. No esta cerrado porque faltan evidencias reales:

- Windows Server 2012 o 2012 R2.
- 32/64 bits.
- IIS.
- permisos de administrador.
- motor de base de datos.
- SMTP/correo.
- acceso a internet.
- rutas de PDFs/backups.

Mientras I0 no cierre, se pueden escribir SPECs funcionales, pero no elegir stack ni implementar.

## I1 - Portal Base / Decisiones Cerradas

Archivo:

- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`

Decisiones cerradas:

- Roles fijos en MVP.
- Administrador asigna roles existentes, no crea nuevos roles.
- Sesion expira por inactividad.
- Tiempo recomendado: 30 minutos.
- Politica minima de contrasenas obligatoria.
- Login inicial con usuario/contrasena local hasta que I0 defina alternativa.
- Dashboard I1 con estados vacios y textos de modulo pendiente, no datos simulados.

## I2 - Datos Maestros e Importacion / Decisiones Cerradas

Archivo:

- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`

Decisiones cerradas:

- Registros incompletos quedan solo en errores.
- No se importan incompletos como borrador.
- `tipo_identificacion` default CC.
- Permitir CE para cedula de extranjeria.
- Errores se corrigen en archivo fuente y se recarga.
- Salario base obligatorio para crear empleado.
- Gerencia puede ver detalle salarial.
- Operaciones no ve detalle salarial en MVP salvo autorizacion posterior.

## I3 - Puestos De Servicio y Asignaciones / Decisiones Cerradas

Archivo:

- `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`

Decisiones cerradas:

- Talento Humano y Administrador pueden crear puestos.
- Cliente sera texto libre en MVP.
- Maestro de clientes queda futuro.
- Se permite asignar empleados/guardas y personal administrativo, diferenciando por cargo.
- Motivo de finalizacion de asignacion es opcional en MVP.
- Operaciones no puede solicitar cambio de puesto dentro del MVP.

## I4 - Certificaciones Laborales / Decisiones Cerradas

Archivo:

- `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`

Decisiones cerradas:

- Solo Talento Humano genera certificaciones en MVP.
- Administrador configura firmantes, pero no genera certificaciones.
- Anulacion exige motivo obligatorio.
- Variables manuales se registran con desglose por concepto.
- Certificacion activa solo muestra variables si TH las ingresa.
- Toda certificacion generada debe tener numero consecutivo unico por trazabilidad.

## Referencias Reales Usadas

- `Referencias/Matriz de Cursos y Acreditaciones para IA.xlsx`
- `Referencias/Novedades de Personal Diaras RRHH - OP-GERENCIA 2026 copia.xlsx`
- `Referencias/CERT LUIS CARLOS YOLIS CORREA 2.pdf`
- `Referencias/membrete actual CERT RETIRADO ORLANDO ESTEBAN CADENA LONDOÑO 3.pdf`
- `Talento Humano.xlsx`
- `Talento Humano(Sheet1).csv`

Hallazgos relevantes:

- Cursos/acreditaciones requiere multiples tipos por empleado, historico de renovaciones y estado calculado.
- Certificaciones tiene dos flujos base: activo y retirado.
- Novedades queda como modulo futuro, pero se modela como evento transversal.
- Los Excel tienen datos incompletos, `#N/A`, fechas faltantes y campos mezclados; por eso la prevalidacion es obligatoria.

## Siguiente Paso Exacto

Continuar con:

`SPEC I5 - Cursos y Acreditaciones`

Debe cubrir:

- tipos de curso/acreditacion;
- multiples requisitos por empleado;
- historico de renovaciones;
- fecha de realizacion;
- fecha de vencimiento;
- estados calculados;
- umbrales: vencido, critico, preventivo, informativo, al dia;
- habilitado/no habilitado para servicio;
- soporte documental opcional;
- permisos por rol;
- dependencia con I2;
- criterios de aceptacion;
- pruebas esperadas;
- preguntas abiertas para cerrar con usuario.

Decisiones ya tomadas para I5:

- Manejar varios tipos de curso/acreditacion por empleado.
- Mantener historico de renovaciones.
- Estado actual calculado desde vigencias.
- Umbrales:
  - vencido: fecha menor a hoy;
  - critico: 0 a 15 dias;
  - preventivo: 16 a 30 dias;
  - informativo: 31 a 60 dias;
  - al dia: mas de 60 dias.
- Si curso/acreditacion esta vencido, guarda queda No habilitado para servicio.
- No bloquear programacion de turnos en MVP.
- Operaciones puede ver restriccion, pero no editar.

## Instrucciones Del Proyecto

`AGENTS.md` indica:

- leer `graphify-out/GRAPH_REPORT.md` antes de arquitectura/codigo;
- despues de modificar codigo, correr `graphify update .`.

Durante esta sesion, `graphify update .` fallo repetidamente porque `graphify` no esta disponible en PATH.

## Skills Sugeridas Para Retomar

- `superpowers:brainstorming` si se siguen cerrando decisiones funcionales.
- `superpowers:writing-plans` cuando una SPEC este lista para plan.
- `spreadsheets:Spreadsheets` si se profundiza la matriz de cursos/acreditaciones.
- `pdf` si se revisan o ajustan certificados.
- `handoff` al cerrar otra sesion.

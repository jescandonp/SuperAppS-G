# I9 — piloto funcional con datos reales anonimizados

Fecha: 2026-08-31
Fuente de datos: `Artefactos Consultoria/Datos Prueba - Nuevo Planeador` (4 PDF de programación real de
septiembre 2026 + `PUESTOS PRUEBA 2026.xlsx` con el roster de guardas).
Alcance: `SIMULATED` / `MVP_TEST`, esquema `sg_i9_pruebas`. No afirma politica institucional ni opera
sobre datos productivos.

> Este documento registra el primer piloto funcional con datos operativos reales (anonimizados) que
> el checklist de demo y el criterio de aceptacion #10 de la SPEC dejaban pendiente. No cierra el MVP:
> ver seccion 4 para los hallazgos que quedan abiertos, incluido uno nuevo (4.1) mas severo que los ya
> documentados en el reporte de cierre del 2026-08-17.

## 1. Que se cargo

Cuatro sitios reales de septiembre 2026, con su roster real anonimizado antes de tocar cualquier base
de datos (ver seccion 2) y el patron de turno tomado literalmente de la cabecera de cada PDF:

| Sitio (PDF) | Codigo interno | Plantilla | Puestos concurrentes | Guardas en roster | Cobertura lograda |
|---|---|---|---|---|---|
| C.R ICONIK 68 | `ICONIK-68` | 2X2 | 6 | 20 (18 guarda + 1 relevante + 1 sin distinguir coordinador) | 360/360 (100%) |
| CR VIENA | `VIENA` | 2X2 | 2 | 6 guarda | 120/120 (100%) |
| LIFE 72 | `LIFE-72` | 2X2 | 2 | 10 guarda + 1 relevante | 120/120 (100%) |
| GRATAMIRA II | `GRATAMIRA-II` | 4X4 (nueva, solo piloto) | 2 | 4 guarda | 64/120 (53%) |

Proyecto: `PILOTO-NUEVO-PLANEADOR` ("Piloto Nuevo Planeador - Septiembre 2026"), periodo 2026-09-01 a
2026-09-30. Los turnos requeridos y las asignaciones (720 en total, 664 `ASIGNADA` / 56 `VACANTE`) se
calcularon con aritmetica modular determinista sobre el ciclo real de cada plantilla (mismo insumo que
`ShiftCycleProjector` usa en produccion), con un desfase por empleado para escalonar la cuadrilla como
en un roster real. Script: [`scripts/dev/sql/i9-piloto-real-anonimizado.sql`](../../scripts/dev/sql/i9-piloto-real-anonimizado.sql),
generado por un script de anonimizacion que no se incluye en el repo porque su unico insumo es el xlsx
con datos personales. Lanzador: [`scripts/dev/Sembrar-I9PilotoReal.ps1`](../../scripts/dev/Sembrar-I9PilotoReal.ps1).

Verificado en la base (`schedule_versions.id=5`, v1, `PROPUESTA`): 720 filas en `schedule_assignments`,
distribuidas exactamente como en la tabla de arriba.

## 2. Como se anonimizo

El xlsx trae nombre completo, cedula y celular reales de 41 personas. Antes de escribir una sola fila
en `sg_i9_pruebas` se generaron identificadores sinteticos (`PILOTO-<SITIO>-<NN>`, `Guarda <SITIO> <NN>`
/ `Relevante <SITIO> <NN>`). El mapeo real→sintetico se escribio *solo* en el scratchpad de la sesion
que lo genero, nunca en este repositorio ni en ningun commit. El SQL versionado no contiene PII.

Esto cumple la restriccion ya documentada en
[`docs/demo/2026-07-29-sg-superapp-i9-demo-checklist.md`](../demo/2026-07-29-sg-superapp-i9-demo-checklist.md)
("sin datos personales reales"), que un piloto con el roster tal cual habria contradicho.

## 3. Plantilla 4X4 — hipotesis local, no catalogo oficial

GRATAMIRA II opera en la practica un ciclo "4x4" que no existe en el catalogo aprobado
([`db/seeds/010_i9_shift_templates.sql`](../../db/seeds/010_i9_shift_templates.sql) solo define
2X2/4X2/6X1). Para incluir este sitio en el piloto se agrego `4X4-PILOTO` (`4 dias, 4 noches, 4
descansos`, extendiendo el mismo estilo que ya tiene 4X2) **exclusivamente en el esquema de pruebas**,
con `mandatory_by_default=FALSE` y nombre que declara explicitamente que es una hipotesis de trabajo.
El catalogo oficial (`010_i9_shift_templates.sql`) no se toco: cualquier plantilla real necesita la
misma aprobacion Legal/Operaciones que ya rige 2X2/4X2/6X1 segun la SPEC seccion 4.

## 4. Hallazgos

### 4.1 — Nuevo, mas severo que los 11 ya documentados en el reporte de cierre: "Generar propuesta" no genera nada, y una segunda pulsacion oculta datos reales

El boton **Generar propuesta** (`POST /api/portal/scheduling/projects/{id}/proposals`) unicamente crea
una fila vacia en `schedule_versions` (estado `PROPUESTA`, `source_snapshot='{}'`). No lee
`position_coverage_rules`, no crea `required_shifts`, no asigna empleados y no corre ninguna regla. La
generacion deterministica que describe la SPEC seccion 1 ("genere propuestas deterministicas y
explicables") vive en un endpoint separado y sin usar:
`POST /api/portal/scheduling/recommendations/generate`, respaldado por `SchedulingRecommendationEngine`
y `PostgresPortalRepository.PersistScheduleRecommendationAsync` — pero requiere que el llamador ya
aporte los `required_shifts` (que tampoco tiene endpoint de creacion) y los veredictos de regla ya
persistidos por candidato. El cliente web (`apps/sg-superapp-web/src/services/portalApi.ts`) nunca llama
a `/recommendations/generate`; solo llama a `/proposals`.

**Verificado en vivo, no solo por lectura de codigo:** con el proyecto piloto ya cargado con 720
asignaciones reales (92% de cobertura), pulsar "Generar propuesta" en la interfaz real creo una
`schedule_versions` nueva (v2, id=6) vacia — `COBERTURA 0%`, `VACANTES 0`, matriz sin filas — mientras
que v1 (id=5, con los 720 datos reales) sigue intacta en la base pero queda **oculta**: la consulta por
proyecto+periodo que usa la pantalla normal siempre trae la version de numero mas alto
(`order by sv.version_number desc limit 1` en `QueryScheduleAsync`). Sin saber el `versionId` exacto,
un usuario no tiene manera de volver a ver v1 desde la interfaz.

Se confirmo ademas que **no existe ninguna via en la interfaz para cargar una version ya existente sin
pulsar "Generar propuesta"**: `SchedulingPage.tsx` solo llena su estado `proposal` desde la respuesta de
`generate()` (que crea version) o del modo `?demo=scheduling`; no hay ninguna llamada a
`GET /api/portal/scheduling/projects/{id}/schedules/{periodo}` ni a
`GET /api/portal/scheduling/proposals/{versionId}` en todo el cliente web, y `App.tsx` no define ninguna
ruta con `versionId`. Se probo tambien llamar `GET /api/portal/scheduling/proposals/5` directamente
(con el token de sesion real, fuera de la interfaz): responde `200` con los metadatos correctos
(`versionNumber:1`, `status:PROPUESTA`) pero **sin el campo `assignments`** — el objeto que devuelve
`GetScheduleVersionAsync`/`QueryScheduleAsync` no incluye las asignaciones, así que aunque hubiera una
pantalla que apuntara a `versionId=5`, hoy no tendria con que pintar la matriz. Los 720 registros solo
son visibles por consulta SQL directa a `schedule_assignments`.

Esto es mas severo que el punto 4 del reporte de cierre (el modo `?demo=scheduling` fabrica resultados
localmente): aqui no hace falta ningun modo demo. Cualquier usuario con permiso `SCHEDULING/GENERATE`
que pulse el boton una segunda vez sobre un proyecto con datos reales los sepulta detras de una version
vacia, sin aviso ni confirmacion, y hoy no hay manera de recuperarlos desde la interfaz aunque se
conozca el `versionId`. Recomendacion: antes de habilitar generacion real, (a) cablear
`/recommendations/generate` al boton, con su prerequisito de `required_shifts`, o (b) como minimo,
advertir explicitamente antes de crear una version nueva cuando la anterior tiene asignaciones.

### 4.2 — GRATAMIRA II: el PDF real usa a alguien que no esta en el roster

El PDF de GRATAMIRA (`Guardas: 5`) incluye a **JAVIER SUAREZ FERIA** trabajando el turno de septiembre,
pero esa persona no aparece en ninguna fila de `PUESTOS PRUEBA 2026.xlsx`. El roster solo tiene 4
personas para ese sitio. El piloto se sembro con las 4 reales; la vacante estructural que arroja el
53% de cobertura (ver seccion 1) es coherente con esta ausencia: con 4 guardas rotando un ciclo 4x4 que
exige 2 personas simultaneas de dia y 2 de noche, la cuadrilla real necesitaria a esa quinta persona (o
una plantilla distinta) para cerrar sin vacantes — exactamente lo que el piloto hace visible.

### 4.3 — LIFE 72: mas nomina que la que el PDF dice necesitar

El PDF fija `Guardas: 6`, pero el roster tiene 10 personas en `NOMINA LIFE 72` (mas 1 relevante). El
piloto uso las 10; por eso cubre el 100% sin vacantes con margen. No es un defecto del piloto: es una
discrepancia real entre la nomina vigente y el encabezado impreso en la programacion de septiembre, que
vale la pena que Operaciones revise (rotacion de personal no reflejada en el PDF, o el PDF cuenta solo
"activos" bajo otro criterio).

### 4.4 — `position_coverage_rules` es una fila por puesto+plantilla+vigencia, no una por franja

El primer intento de siembra insertaba una fila de cobertura para el turno diurno y otra para el
nocturno; la segunda caia siempre en `ON CONFLICT DO NOTHING` por la restriccion unica
`uq_position_coverage_rules_period (position_id, template_id, effective_from)`. No es un bug: el modelo
ya asume que la plantilla (via `shift_template_steps`) codifica dia/noche/descanso, y que la cobertura
solo necesita declarar cantidad requerida y vigencia una vez por puesto. El script final quedo con una
sola fila por sitio (franja 08:00–20:00 como referencia).

### 4.5 — Metricas de version quedan en 0 cuando se siembra por SQL

`schedule_versions.coverage_percent` y `.vacancy_count` solo se recalculan dentro de
`RefreshScheduleMetricsAsync`, invocado por las rutas de mutacion normales (ajustar asignacion, aprobar
excepcion, etc.). Como el piloto se sembro con SQL directo (igual que el escenario minimo del
lanzador), esas columnas quedan en 0 aunque `schedule_assignments` tenga los 720 registros reales. Es
consistente con como ya funciona el escenario de dos empleados; se documenta para que nadie lea
`COBERTURA 0%` en la version v1 como si realmente no tuviera datos.

## 5. Que valida este piloto (y que no)

**Valida:** que el catalogo de plantillas, `service_positions`, `employees` y
`schedule_assignments`/`required_shifts` sostienen datos multi-sitio y multi-plantilla reales (no solo
el par de empleados de juguete); que el flujo de autenticacion, el shell del portal y el selector de
proyecto/periodo funcionan con un proyecto real de principio a fin; y que el concepto de vacante visible
(SPEC seccion 2) se puede observar con un caso real (GRATAMIRA).

**No valida:** el motor de generacion deterministica en si (no esta cableado, ver 4.1), ni la matriz
D/N/X/VACANTE de la interfaz contra este proyecto, ni el recorrido completo de aprobar/publicar/exportar
del checklist de demo sobre datos reales. **No queda pendiente "repetirlo apuntando a versionId=5"**:
se confirmo que ese camino no existe hoy en la interfaz ni en la forma en que la API responde (ver
4.1) — hace falta desarrollo antes de poder intentarlo, no solo repetir el piloto.

## 6. Proximos pasos sugeridos

1. Decidir con Operaciones/Juridica si el patron `4X4-PILOTO` aqui usado (4 dias, 4 noches, 4 descansos)
   es el que realmente se opera en GRATAMIRA, antes de proponerlo para el catalogo oficial.
2. Resolver 4.1 antes de cualquier prueba funcional adicional con datos reales. Esto requiere trabajo de
   desarrollo, no solo configuracion: (a) que `GetScheduleVersionAsync`/`QueryScheduleAsync` incluyan
   `assignments` en su respuesta, (b) una forma de cargar una version existente en la interfaz sin pasar
   por `generate()` (ruta con `versionId`, o que el selector de proyecto/periodo detecte y ofrezca la
   version mas reciente en vez de solo crear una nueva), y (c) cablear la generacion real
   (`/recommendations/generate`) o, como minimo, advertir antes de crear una version vacia sobre un
   proyecto que ya tiene asignaciones.
3. Una vez resuelto el punto 2, repetir el recorrido del checklist de demo sobre el proyecto piloto
   (matriz, comparacion, excepciones, aprobacion, publicacion, exportacion) con datos reales en vez del
   escenario de dos empleados.
4. Trasladar los hallazgos 4.2 y 4.3 a Operaciones para que confirmen si el roster o el PDF estan
   desactualizados.

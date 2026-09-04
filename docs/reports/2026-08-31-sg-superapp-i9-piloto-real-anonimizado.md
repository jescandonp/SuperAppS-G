# I9 — piloto funcional con datos reales anonimizados

Fecha: 2026-08-31
Fuente de datos: `Artefactos Consultoria/Datos Prueba - Nuevo Planeador` (4 PDF de programación real de
septiembre 2026 + `PUESTOS PRUEBA 2026.xlsx` con el roster de guardas).
Alcance: `SIMULATED` / `MVP_TEST`, esquema `sg_i9_pruebas`. No afirma politica institucional ni opera
sobre datos productivos.

> **Actualizacion 2026-09-01 — M1 resuelto.** El hallazgo 4.1 (abajo) tenia dos partes: la version vacia
> que "Generar propuesta" crea (era un problema aparte, mas grande — ver M2 abajo, ya en curso) y que
> **la interfaz no podia mostrar ninguna version existente, ni siquiera recien generada**, porque
> `ScheduleWorkflowResponse` nunca incluyo `assignments`/`exceptions`. Esa segunda parte ya esta
> corregida: `PostgresPortalRepository.QueryScheduleAsync` ahora las trae, `SchedulingPage.tsx` carga la
> version existente del proyecto/periodo sin pasar por "Generar propuesta", y se agrego una confirmacion
> antes de crear una version nueva sobre una que ya tiene asignaciones. Verificado en vivo contra este
> mismo proyecto piloto (matriz completa de septiembre, 30 dias, D/N/VACANTE correctos) y con el nuevo
> verificador `scripts/dev/Verify-SgSuperAppI9ScheduleVisibility.ps1` (`I9 SCHEDULE VISIBILITY PASS 16`).
> Commit `cf50cc1`. Detalle completo en la seccion 4.1.
>
> **Actualizacion 2026-09-01 — M2 resuelto.** "Generar propuesta" ahora expande `required_shifts` de
> verdad desde `position_coverage_rules` (server-side, determinista, dentro de la misma transaccion que
> crea la version) y deja un cupo `VACANTE` con razon `CANDIDATES_NOT_EVALUATED` por cada turno
> requerido — todavia no asigna a nadie (eso es M3/M4: evaluar candidatos contra las siete reglas y
> rankearlos), pero ya no crea una version literalmente vacia cuando hay cobertura configurada. Solo se
> expande la cobertura `ACTIVO`, vigente para cada fecha, de puestos `ACTIVO`, con `weekday_scope`
> exactamente `'TODOS'` (un ambito semanal parcial no tiene convencion definida en ningun lugar de este
> codebase — se omite en vez de adivinarse, ver seccion 4.6). Se ensancho ademas la restriccion unica de
> `position_coverage_rules` (`db/migrations/009_i9_scheduling.sql`) para admitir una fila de franja
> diurna y otra nocturna por puesto/plantilla/vigencia — antes la segunda quedaba descartada en
> silencio por `ON CONFLICT DO NOTHING`, que era la causa real del hallazgo 4.4 (abajo, ahora obsoleto).
> Verificado con `scripts/dev/Verify-SgSuperAppI9RequiredShiftsExpansion.ps1` (`PASS 14`).
>
> **Actualizacion 2026-09-02 — M3 resuelto.** "Generar propuesta" ahora evalua candidatos reales contra
> las siete reglas por cada turno requerido: por cada cupo `VACANTE` que M2 genera, resuelve el pool de
> candidatos (`employee_position_assignments`, tabla real de I3), calcula `facts` de datos ya
> persistidos (horas trabajadas, turno previo real, traslapes con otras versiones vivas, secuencia real
> de la plantilla) y persiste veredictos reales via el mismo mecanismo que ya usaba
> `POST /rules/evaluate` (`SchedulingRuleEvaluator.Evaluate` + `PersistEvaluationsAsync`, sin tocarlos).
> R04 (novedades) y R06 (requisitos) se envian con arreglos vacios a proposito — no existe integracion
> real con I2/I5/I6 todavia — y el veredicto resultante es `_UNVERIFIED`/`_MISSING`, nunca cumplimiento
> fabricado. Verificado en dos niveles: inspeccion manual directa de `scheduling_rule_evaluations` contra
> un escenario con un candidato con descanso real insuficiente (salio `I9-R02 EXCEPTION_REQUIRED`, no
> `COMPLIANT`) y con el nuevo verificador `scripts/dev/Verify-SgSuperAppI9CandidateEvaluation.ps1`
> (`PASS 10`), mas regresion confirmada de M1 y M2 (`PASS 16` y `PASS 14` respectivamente, sin cambios).
>
> **Hallazgo real, ya resuelto (2026-09-02):** al generar por primera vez una propuesta real para el
> proyecto piloto, `scheduling_rule_evaluations` quedaba en cero filas — el unico perfil `MVP_TEST`
> activo estaba sembrado con `scope_code='PROJECT-A'` (el escenario de juguete), y el piloto no tenia
> perfil propio; M3 se rehusaba correctamente a evaluar sin uno, en vez de presumir nada. Se agrego
> `I9-PILOTO-SIMULATED`, un perfil `MVP_TEST` propio para `PILOTO-NUEVO-PLANEADOR` (sembrado en
> `scripts/dev/sql/i9-piloto-real-anonimizado.sql`), reusando **exactamente los mismos parametros R01-R07
> ya marcados `SIMULATED_DEMO_NOT_INSTITUTIONAL` y aprobados para MVP_TEST** en el perfil de `PROJECT-A`
> — no se invento ningun umbral nuevo, solo se amplio su alcance. Los catalogos de novedades (R04),
> matriz de traslados (R05) y requisitos de puesto (R06) se dejaron vacios a proposito (no hay catalogo
> real para los 4 sitios todavia; ver el parrafo de abajo).
>
> Verificado en vivo, extremo a extremo: con el perfil activo (7 reglas), generar una propuesta real de
> 2 dias sobre los 4 sitios del piloto produjo **1092 evaluaciones reales sobre 39 candidatos reales**,
> con veredictos variados y explicables — no un resultado uniforme fabricado:
>
> | Regla | Resultado | Lectura |
> |---|---|---|
> | R01 (jornada) | 156 `BLOCKED` | Todos los turnos configurados duran 12h (mas que las 8h ordinarias); el perfil exige acuerdo escrito para superar la jornada ordinaria, y como `writtenAgreement` no tiene fuente real hoy (se envia `false`, honesto), todos bloquean por falta de ese acuerdo — un hallazgo real de negocio, no un error de calculo. |
> | R02 (descanso) | 122 `COMPLIANT`, 34 `EXCEPTION_REQUIRED` | Distincion real segun el historial de turnos de cada candidato. |
> | R03 (traslapes) | 111 `COMPLIANT`, 45 `BLOCKED` | Deteccion real de cruces con otras versiones vivas. |
> | R04 (novedades) | 156 `WARNING` | Catalogo vacio a proposito → no verificado, nunca cumplimiento fabricado. |
> | R05 (traslados) | 156 `COMPLIANT` | Sin turno previo en el periodo evaluado → atajo `_SAME_POSITION`, correcto. |
> | R06 (requisitos) | 156 `WARNING` | Catalogo vacio a proposito → no verificado. |
> | R07 (plantilla) | 156 `BLOCKED` | Los guardas reales rotan escalonados; comparados contra una unica secuencia sin escalonar (limitacion conocida, ver seccion 4.3 del plan de M3), la desviacion es real y esperada. |
>
> Falta todavia: que Operaciones/Legal revisen si estos parametros MVP_TEST (pensados como demo) deben
> convertirse en la politica real para estos 4 sitios, y construir la integracion real de novedades
> (R04) y requisitos (R06) con I2/I5/I6 antes de que esas dos reglas dejen de salir `WARNING` siempre.
>
> **Actualizacion 2026-09-03 — M4 resuelto (con un hallazgo real importante).** "Generar propuesta" ahora
> rankea a los candidatos reales que M3 evalua y persiste la asignacion real (o la vacante real, con su
> motivo) via `SchedulingRecommendationEngine.Generate` + `PersistScheduleRecommendationAsync` — piezas
> que ya existian y ya estaban probadas de forma aislada (`Verify-SgSuperAppI9MvpGeneration.ps1`, 13
> escenarios); M4 solo les da entrada real: por cada candidato evaluado, `Continuity` (`1` si trabajo real
> el dia calendario inmediatamente anterior, si no `0`) y `Equity` (`1/(1+n)`, `n` = turnos `ASIGNADA`
> reales que ya tiene en el periodo) se calculan de datos ya persistidos; `AdditionalHours`,
> `DistancePenalty` y `PublishedScheduleChange` se dejan en `0` porque no existe hoy una fuente real de
> horas acumuladas fuera del periodo, distancia ni republicacion previa — hueco de datos documentado, no
> un valor inventado. `ExpandRequiredShiftsAsync` (M2) ya no siembra el cupo `VACANTE` placeholder: la
> vacante real (con motivo real) la escribe el motor.
>
> **Hallazgo real (no un defecto de M4, un hueco de datos con consecuencia visible):** con los parametros
> `SIMULATED_DEMO_NOT_INSTITUTIONAL` ya aprobados, **I9-R04 sale `WARNING` para el 100% de las
> evaluaciones reales** porque `BuildCandidateFactsAsync` envia `noveltyEvaluations=[]` a proposito (no
> hay ninguna fuente real de novedades de personal todavia — nunca se inventa disponibilidad), y
> `SchedulingEligibilityService` proyecta `WARNING` como bloqueante ("un turno sin verificar no acredita
> nada"). Consecuencia real: **hoy nadie puede terminar `ASIGNADA` via "Generar propuesta"**, sin importar
> cuanto mejore el ranking — todo turno requerido queda `VACANTE`. Verificado en vivo sobre el piloto real
> (`schedule_versions.id=4`, periodo 2026-09-02/03, 4 sitios): 48 turnos requeridos, **48 `VACANTE`, 0
> `ASIGNADA`**, con motivos reales y diferenciados (48/48 citan `I9_R04_UNVERIFIED`; 46/48 citan ademas
> `I9_R02_EXCEPTION_REQUIRED` por descanso real insuficiente; 44/48 citan `I9_R01_WRITTEN_AGREEMENT_REQUIRED`),
> y 1092 evaluaciones reales persistidas (mismo numero que M3 ya habia reportado, ahora alimentando el
> ranking real).
>
> **Correccion importante (2026-09-03, tras investigar):** la frase original de esta actualizacion decia
> "aunque R01/R07 tambien bloquean casi todo, R04 es el unico...". Eso era inexacto en dos frentes,
> corregidos abajo: (1) "I2" **no es** el modulo de novedades — I2 es "Datos Maestros e Importacion"
> (`docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`); "Novedades" es, segun
> `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md` seccion 4, un **modulo
> estrategico futuro sin numero de incremento asignado y explicitamente fuera del MVP** ("no se
> implementaran en MVP: ... conexion con programacion de turnos"). No existe ninguna tabla de novedades
> de RRHH en el esquema (`db/migrations` no tiene `novelties`/`absences`/`incapacities` ni equivalente) —
> construir esa integracion real hoy estaria fuera del alcance ya decidido del MVP, no es una tarea de
> ingenieria pendiente. (2) R01 y R07 no bloqueaban "casi todo": bloqueaban el **100%**, igual que R04 —
> ver la tabla de la actualizacion original arriba (`R01 156 BLOCKED`, `R07 156 BLOCKED`, ambos de 156).
>
> **Actualizacion 2026-09-03 — R07 corregido (bug real, no una limitacion de rotacion).** Al investigar
> por que R07 bloqueaba el 100% se encontro que **no era por rotacion escalonada** (como se penso en M3):
> `BuildCandidateFactsAsync` armaba `expectedCells`/`proposedCells` con los campos `{cell,expected}` /
> `{cell,proposed}`, pero `SchedulingTemplateDeviationRule.TryReadCells` exige
> `{employeeId,date,cell,shiftCode}` — el desajuste de forma hacia que la regla nunca llegara a comparar
> nada, y devolviera `BLOCKED I9_R07_INVALID_INPUT` siempre que hubiera plantilla real. Corregido:
> ahora se envian los campos correctos. Verificado en vivo sobre el mismo piloto real (version nueva,
> mismo periodo): **R07 pasa de `156 BLOCKED / 156` a `78 COMPLIANT` + `78 EXCEPTION_REQUIRED` (50/50)** —
> una comparacion real y variada, coherente con que la cuadrilla real rota escalonada (mitad coincide con
> la secuencia esperada, mitad se aparta en una fase, exactamente el patron real de un roster escalonado).
> El resultado final del piloto **no cambio** (sigue en 48 `VACANTE` / 0 `ASIGNADA`) porque R01, R04 y R06
> siguen bloqueando el 100% de forma independiente — pero R07 ya no es parte del problema, y su resultado
> ahora es honesto y explicable en vez de una falla estructural disfrazada de "limitacion de dominio".
> Verificado con `Verify-SgSuperAppI9CandidateRanking.ps1` (`PASS 15`), y regresion confirmada de
> `Verify-SgSuperAppI9CandidateEvaluation.ps1` (`PASS 10`) y `Verify-SgSuperAppI9RequiredShiftsExpansion.ps1`
> (`PASS 14`).
>
> **Los tres bloqueos reales que quedan, todos al 100% y todos decisiones de negocio/producto, no tareas
> de ingenieria pendientes:**
> - **R01 (jornada):** los turnos reales de 12h superan la jornada ordinaria (8h) y no hay fuente real de
>   `writtenAgreement`; bloquea sin excepcion salvo que exista un acuerdo escrito real o el umbral se
>   redefina para este tipo de turno.
> - **R04 (novedades):** sin fuente real (modulo "Novedades" fuera del MVP, ver arriba); bloquea sin
>   excepcion mientras no exista una fuente real de novedades, o se decida deshabilitar la regla para
>   perfiles MVP_TEST (el esquema ya soporta `enabled=false` por regla y perfil).
> - **R06 (requisitos):** sin catalogo real de requisitos por puesto para los 4 sitios del piloto (el
>   catalogo demo solo cubre `POSITION-1` de juguete); bloquea sin excepcion mientras no exista un
>   catalogo real o se decida deshabilitarlo igual que R04.
>
> Ninguna de las tres se resuelve escribiendo mas codigo sin antes una decision de Operaciones/Legal —
> ver el punto 7 de la seccion 6.
>
> **Dos correcciones reales encontradas al construir el verificador de M4** (ninguna estaba en el plan
> aprobado, ambas se corrigieron antes de dar M4 por terminado):
> 1. Un proyecto sin perfil de reglas `ACTIVE` configurado quedaba **sin ninguna fila de
>    `schedule_assignments`** (ni `VACANTE`) — la garantia de M2 de que todo turno requerido queda visible
>    se habia roto al quitar el placeholder. Se corrigio: sin perfil, cada turno sigue recibiendo una
>    `VACANTE` real con motivo `RULE_PROFILE_UNCONFIGURED`, nunca un veredicto de reglas inventado.
> 2. Un turno con `required_quantity>1` (varios cupos concurrentes del mismo puesto/horario) solo
>    generaba **una** fila de asignacion, no `N` — el motor de ranking (ya existente, ya probado) no
>    modela "cupos" como concepto propio. Se corrigio generando `N` entradas independientes hacia el
>    motor por turno; se documenta como limitacion heredada que un mismo candidato podria ganar dos cupos
>    hermanos del mismo turno (el freno es el mismo descuento por acumulacion que ya usa el motor entre
>    turnos distintos, no una exclusion dura) — redisenar el motor para exclusividad dura queda fuera de
>    alcance de M4.
>
> Verificado con el nuevo `scripts/dev/Verify-SgSuperAppI9CandidateRanking.ps1` (`PASS 14`, dos candidatos
> con historial real distinto mas un puesto sin candidatos reales, confirmando que un turno con cero
> candidatos sigue llegando al motor con `Candidates=[]` en vez de desaparecer), mas regresion confirmada
> de M1, M2 y M3 (`Verify-SgSuperAppI9ScheduleVisibility.ps1`, `Verify-SgSuperAppI9RequiredShiftsExpansion.ps1`
> actualizado para el nuevo motivo real, y `Verify-SgSuperAppI9CandidateEvaluation.ps1`, sin cambios de
> fondo).
>
> **Actualizacion 2026-09-03 — R04/R06 deshabilitados para MVP_TEST (decision del usuario), y una
> segunda salvaguarda encontrada al aplicarla.** El usuario aprobo explicitamente deshabilitar R04 y R06
> para el perfil `I9-PILOTO-SIMULATED` (sin fuente real de ninguna de las dos, ver arriba), en vez de
> dejarlas bloqueando indefinidamente. Implementarlo requirio dos cambios reales, no uno:
> 1. `SchedulingRuleEvaluator`: una regla `enabled=false` ahora produce `NOT_APPLICABLE` (nunca acredita
>    cumplimiento, pero tampoco bloquea por si sola), en vez de `WARNING` (que
>    `SchedulingEligibilityService` siempre proyectaba como bloqueante — asi que "deshabilitar" antes
>    nunca desbloqueaba nada, solo cambiaba el texto del motivo). Documentado en el codigo como la misma
>    salvaguarda anti-"aprobar por omision" aplicada de otra forma: la decision de excluir la regla queda
>    en el perfil versionado y auditable, nunca en un valor vacio.
> 2. **Segunda salvaguarda independiente, encontrada solo al verificar en vivo (no por lectura de
>    codigo):** `SchedulingRuleProfileValidator.Validate` exigia que **las siete reglas estuvieran
>    `enabled=true`** para que un perfil fuera siquiera cargable — con R04/R06 deshabilitados,
>    `LoadActiveAsync` lanzaba una excepcion y la generacion caia al mismo `RULE_PROFILE_UNCONFIGURED`
>    de un proyecto sin perfil. Se corrigio para exigir presencia (exactamente una entrada por cada una
>    de las siete reglas, sin duplicados, ninguna faltante), no habilitacion.
>
> Se sembro `I9-PILOTO-SIMULATED` v3 (`scripts/dev/sql/i9-piloto-rule-profile-v2-r04-r06-disabled.sql` —
> v2 quedo con un `effective_from` incorrecto en el primer intento, corregido a v3 sobre este esquema;
> el script del repo ya nace correcto para instalaciones nuevas) con los mismos parametros R01-R07 ya
> aprobados, salvo R04 y R06 en `enabled=FALSE`. **Verificado en vivo sobre el piloto real**
> (`schedule_versions.id=8`, mismo periodo): R04 y R06 pasan de `WARNING` a `NOT_APPLICABLE` en las 156
> evaluaciones de cada una, y R07 (ya corregido) sigue variado (78 `COMPLIANT` / 78
> `EXCEPTION_REQUIRED`) — pero **el resultado final sigue en 0 `ASIGNADA` de 48 turnos**, porque
> **I9-R01 (jornada) bloquea el 100% por si solo** (turnos reales de 12h sin fuente real de acuerdo
> escrito) y el usuario no aprobo deshabilitar esa regla — es la unica de las cuatro que queda como
> decision de negocio genuinamente pendiente, no una limitacion tecnica. Verificado sin regresion con
> `Verify-SgSuperAppI9R07.ps1` (`PASS 20`), `Verify-SgSuperAppI9R04R06.ps1` (`PASS 55`, incluye el
> recorrido completo `LoadActiveAsync`+`Validate` sobre PostgreSQL real), `Verify-SgSuperAppI9R03R05.ps1`
> (`PASS 35`), `Verify-SgSuperAppI9MvpGeneration.ps1` (`PASS 13`), `Verify-SgSuperAppI9Eligibility.ps1` y
> `Verify-SgSuperAppI9MvpWorkflow.ps1` (`PASS 65`).
>
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

### 4.1 — "Generar propuesta" no genera nada, y una segunda pulsacion oculta datos reales

**Estado: la parte de visibilidad (M1) esta corregida desde 2026-09-01; la generacion en si sigue sin
implementar (M2-M5), ver actualizacion al inicio del documento.**

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

### 4.4 — `position_coverage_rules` solo admitia una franja horaria por puesto+plantilla+vigencia (OBSOLETO, corregido en M2)

**Estado: corregido 2026-09-01.** El primer intento de siembra insertaba una fila de cobertura para el
turno diurno y otra para el nocturno; la segunda caia siempre en `ON CONFLICT DO NOTHING` por la
restriccion unica `uq_position_coverage_rules_period (position_id, template_id, effective_from)`. En su
momento se penso que no era un bug (que el modelo asumia que la cobertura solo necesitaba una franja de
referencia). Al implementar M2 quedo claro que si era un bug real: un puesto con rotacion 24h
necesita ambas franjas para que la expansion de turnos requeridos cubra el dia completo, y la
restriccion se lo impedia sin avisar. Se ensancho a
`UNIQUE (position_id, template_id, effective_from, starts_at)` en
`db/migrations/009_i9_scheduling.sql`; el piloto ahora siembra ambas franjas por sitio.

### 4.6 — `weekday_scope` no tiene ninguna convencion definida en el codebase

Al implementar M2 (expandir `required_shifts` desde `position_coverage_rules`) se confirmo por busqueda
exhaustiva que **ningun lugar del codigo, las migraciones o la documentacion define el formato de
`weekday_scope`** — solo existe una restriccion de "no vacio". El piloto usa `'TODOS'` porque los 4
sitios operan 24/7, y la expansion de M2 solo procesa cobertura con `weekday_scope='TODOS'` exactamente
(cualquier otro valor se omite en vez de adivinarse). Si Operaciones necesita cobertura de solo algunos
dias de la semana (turnos de oficina, por ejemplo), hace falta definir y documentar esa convencion antes
de que M2 pueda expandirla — no es una limitacion tecnica, es una decision de producto pendiente.

### 4.5 — Metricas de version quedan en 0 cuando se siembra por SQL

`schedule_versions.coverage_percent` y `.vacancy_count` solo se recalculan dentro de
`RefreshScheduleMetricsAsync`, invocado por las rutas de mutacion normales (ajustar asignacion, aprobar
excepcion, etc.). Como el piloto se sembro con SQL directo (igual que el escenario minimo del
lanzador), esas columnas quedan en 0 aunque `schedule_assignments` tenga los 720 registros reales. Es
consistente con como ya funciona el escenario de dos empleados; se documenta para que nadie lea
`COBERTURA 0%` en la version v1 como si realmente no tuviera datos.

## 5. Que valida este piloto (y que no)

**Valida:** que el catalogo de plantillas (incluida 4X4, ya oficial), `service_positions`, `employees` y
`schedule_assignments`/`required_shifts` sostienen datos multi-sitio y multi-plantilla reales (no solo
el par de empleados de juguete); que el flujo de autenticacion, el shell del portal y el selector de
proyecto/periodo funcionan con un proyecto real de principio a fin; que el concepto de vacante visible
(SPEC seccion 2) se puede observar con un caso real (GRATAMIRA); y, desde la correccion M1, **que la
matriz D/N/X/VACANTE real se puede ver en la interfaz real** (30 dias de septiembre, 4 sitios,
verificado en vivo) sin pasar por `?demo=scheduling`.

Desde M2, tambien valida que **"Generar propuesta" expande cobertura real** (`required_shifts` desde
`position_coverage_rules`, con sus VACANTE explicitas) en vez de crear una version literalmente vacia.

Desde M3, tambien valida que el mecanismo de evaluacion de candidatos contra las siete reglas funciona
con datos reales (turno previo real, horas reales, traslapes reales) **sobre los 4 sitios reales del
piloto**, no solo sobre un escenario anonimo: con el perfil `I9-PILOTO-SIMULATED` activo (ver
actualizacion al inicio del documento), 1092 evaluaciones reales sobre 39 candidatos reales, con
veredictos variados y explicables por regla.

Desde M4, tambien valida que el ranking real (`SchedulingRecommendationEngine` + hechos reales de
continuidad/equidad) esta cableado de punta a punta sobre los 4 sitios reales del piloto.

Tambien valida, tras la correccion del 2026-09-03, que **R07 (desviacion de plantilla) ya compara la
secuencia real contra lo propuesto** en vez de fallar siempre por un desajuste de forma en los hechos:
sobre el mismo piloto real, 78 de 156 evaluaciones salen `COMPLIANT` y 78 `EXCEPTION_REQUIRED` — un
resultado variado y explicable (mitad de la cuadrilla coincide con la secuencia esperada, mitad se
aparta en una fase, coherente con una rotacion real escalonada), no un bloqueo estructural.

Tambien valida, tras la decision del usuario del 2026-09-03 de deshabilitar R04 y R06 para
`I9-PILOTO-SIMULATED`, que un perfil puede excluir explicitamente una regla sin fuente real de datos
(`NOT_APPLICABLE`, nunca cumplimiento fabricado) y que el sistema deja de bloquear por esas dos reglas
en concreto — verificado en vivo: R04 y R06 pasan de `WARNING` (156/156) a `NOT_APPLICABLE` (156/156).

**No valida:** que un candidato real pueda terminar `ASIGNADA` hoy — el resultado real y honesto sigue
siendo **0 `ASIGNADA` de 48 turnos requeridos**, porque **I9-R01 bloquea el 100% por si solo** (turnos
reales de 12h sin fuente real de acuerdo escrito) y esa es la unica de las cuatro reglas que el usuario
no aprobo deshabilitar — sigue siendo una decision de negocio genuinamente pendiente (ver seccion 6), no
una limitacion tecnica; ni el recorrido completo de aprobar/publicar/exportar del checklist de demo
sobre datos reales (mismo bloqueo: ningun candidato pasa hoy el gate de "toda regla decidida" que exige
aprobar/publicar, correctamente, dado el estado real de los datos).

## 6. Proximos pasos sugeridos

1. ~~Decidir con Operaciones/Juridica si el patron 4x4 (4 dias, 4 noches, 4 descansos) es el que
   realmente se opera en GRATAMIRA~~ — **hecho**: aprobado por el usuario el 2026-09-01 y promovido a
   `db/seeds/010_i9_shift_templates.sql` como `4X4`, catalogo oficial.
2. ~~Resolver la visibilidad de una version existente en la interfaz~~ — **hecho (M1)**: ver la
   actualizacion al inicio de este documento.
3. ~~M2: expandir `required_shifts` desde `position_coverage_rules` dentro de la generacion~~ —
   **hecho**: ver actualizacion al inicio del documento. Requirio ademas ensanchar la restriccion
   unica de `position_coverage_rules` (hallazgo 4.4, ahora obsoleto) y dejar sin definir el soporte de
   `weekday_scope` parcial (hallazgo 4.6, decision de producto pendiente).
4. ~~M3: ensamblar los `facts` reales que cada regla R01-R07 necesita para poder llamar
   `POST /rules/evaluate` por candidato antes de rankear~~ — **hecho**: ver actualizacion al inicio del
   documento.
5. ~~Definir un perfil de reglas `MVP_TEST` propio para `PILOTO-NUEVO-PLANEADOR`~~ — **hecho**: perfil
   `I9-PILOTO-SIMULATED`, mismos parametros demo ya aprobados que `PROJECT-A`, sin catalogos de
   novedades/requisitos/traslados (vacios a proposito).
6. ~~M4: calcular scoring real (continuidad, equidad, horas acumuladas, distancia) y rankear/asignar
   candidatos de verdad~~ — **hecho**: ver actualizacion al inicio del documento. Verificado en vivo
   sobre el piloto real que el resultado honesto era 0 `ASIGNADA` de 48 turnos, porque R01, R04 y R06
   bloqueaban el 100% de forma independiente — el hallazgo mas importante que dejo M4.
7. ~~Corregir R07 (desviacion de plantilla)~~ — **hecho (2026-09-03)**: no era rotacion escalonada sin
   modelar, era un desajuste de forma en los hechos (`BuildCandidateFactsAsync` enviaba
   `{cell,expected}`/`{cell,proposed}` en vez de `{employeeId,date,cell,shiftCode}`). Corregido y
   verificado: ahora compara de verdad (78/156 `COMPLIANT`, 78/156 `EXCEPTION_REQUIRED` sobre el piloto
   real).
8. ~~Deshabilitar R04 y R06 para `I9-PILOTO-SIMULATED`~~ — **hecho (2026-09-03, decision del usuario)**:
   sin fuente real de novedades ("Novedades" fuera de alcance del MVP,
   `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md` seccion 4) ni de requisitos
   por puesto para estos 4 sitios. Requirio dos cambios reales (`SchedulingRuleEvaluator`: disabled=
   `NOT_APPLICABLE` en vez de `WARNING`; `SchedulingRuleProfileValidator`: exige presencia de las siete
   reglas, no habilitacion) — ver actualizacion al inicio del documento. Verificado en vivo: R04/R06
   pasan a `NOT_APPLICABLE` (156/156 cada una), sin regresion en R01-R03/R05/R07.
9. **Decision de Operaciones/Legal sobre R01, el unico bloqueo real que queda:** ¿existe o se puede
   generar un acuerdo escrito real para los turnos de 12h de estos sitios, o el umbral de jornada
   ordinaria del perfil demo debe ajustarse para este tipo de operacion? Mientras no se decida, el
   resultado honesto de "Generar propuesta" sobre el piloto real sigue siendo 0 `ASIGNADA` de 48 —
   ya no por tres motivos independientes, solo por este uno.
10. M5: una vez tomada esa decision, repetir este piloto dejando que el motor asigne de verdad,
    comparando contra los 4 PDF. Solo entonces cablear el resultado real al boton "Generar propuesta"
    como flujo por defecto sin advertencias adicionales.
11. Una vez resuelto M5, repetir el recorrido del checklist de demo sobre el proyecto piloto (matriz,
    comparacion, excepciones, aprobacion, publicacion, exportacion) con datos reales en vez del escenario
    de dos empleados.
12. Trasladar los hallazgos 4.2, 4.3 y 4.6 a Operaciones: 4.2/4.3 para que confirmen si el roster o el
    PDF estan desactualizados; 4.6 para que definan si hace falta cobertura de dias parciales y, si es
    asi, en que formato.

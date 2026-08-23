# SPEC I9 - Cierre Tecnico Del MVP De Reglas De Programacion

> Estado: **PROPUESTA_PARA_REVISION**
> Fecha: 2026-08-17
> Alcance: cierre tecnico del MVP I9 mediante reglas R01 a R07 configurables,
> explicables, auditadas y verificadas con datos simulados.
> Base: `docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md`.
> Autoridad de avance: confirmacion explicita del usuario el 2026-08-17.

## 1. Supuestos Explicitos

1. El usuario cuenta con libertad expresa para completar el desarrollo del MVP.
2. Las decisiones funcionales aprobadas para I9-R01 a I9-R07 son la fuente del
   comportamiento del MVP.
3. Los catalogos, codigos y matrices institucionales aun no disponibles se
   reemplazan durante desarrollo y pruebas por configuracion simulada,
   versionada, identificable y sustituible.
4. La configuracion simulada puede recorrer el workflow completo del MVP,
   incluida publicacion de prueba y exportacion, pero no habilita produccion.
5. Las observaciones de las areas se incorporaran como cambios versionados
   durante la fase de pruebas; nunca se reescriben snapshots historicos.
6. Se conserva .NET 6, PostgreSQL, React 18, TypeScript y las dependencias
   existentes; no se agrega un motor externo de reglas.

## 2. Objetivo

Completar el MVP de programacion asistida para que Operaciones pueda configurar
un perfil de reglas, generar propuestas deterministicas, entender cada
resultado, resolver excepciones, aprobar, publicar y exportar una programacion
de prueba con trazabilidad completa.

El MVP se considera tecnicamente cerrado cuando las siete reglas se ejecutan en
los puntos obligatorios, los bloqueos absolutos no admiten excepcion, las
excepciones aprobables no se reutilizan, los datos simulados son visibles y la
suite hermetica reproduce el flujo integral.

## 3. Usuarios Y Resultado Esperado

- **Operaciones:** configura, genera, ajusta, solicita excepciones y revisa
  explicaciones.
- **Director de Operaciones:** aprueba excepciones con
  `SCHEDULING/APPROVE_EXCEPTION`.
- **Talento Humano:** registra la validacion de requisitos R06 en el escenario
  simulado.
- **Aprobador/Publicador:** ejecuta acciones humanas explicitas y auditadas.
- **Equipo de pruebas:** sustituye parametros simulados por nuevas versiones sin
  modificar resultados historicos.

## 4. Alcance Funcional

### 4.1 Incluido

- perfiles de reglas versionados por origen, vigencia y alcance;
- datos simulados iniciales para R01 a R07;
- evaluacion en generacion, edicion manual, aprobacion y publicacion;
- resultados `COMPLIANT`, `BLOCKED`, `EXCEPTION_REQUIRED`, `WARNING` y
  `NOT_APPLICABLE`;
- excepciones por regla, asignacion y snapshot exacto;
- invalidacion de excepciones cuando cambia cualquier dato evaluado;
- explicaciones, mensajes, auditoria y snapshots de parametros;
- indicador visible `DATOS SIMULADOS - MVP` en UI y exportaciones;
- suite hermetica con fixtures anonimos y prueba de doble ejecucion;
- recorrido responsive y funcional en 320, 768, 1024 y 1440 px.

### 4.2 Fuera De Alcance

- activacion productiva de perfiles `SIMULATED`;
- presentacion de datos simulados como politica institucional;
- calculo de nomina, recargos o control de asistencia;
- trafico en tiempo real, rutas dinamicas u optimizacion matematica avanzada;
- aprobacion o publicacion autonoma;
- integraciones obligatorias nuevas con sistemas externos;
- uso de datos personales reales en fixtures o evidencia.

## 5. Estados Y Contratos De Configuracion

### 5.1 Perfil De Reglas

Cada perfil conserva:

- `profileCode`, `version` y `origin` (`SIMULATED` o `INSTITUTIONAL`);
- `environmentScope` (`MVP_TEST` o `PRODUCTION`);
- `effectiveFrom`, `effectiveTo`, `status` (`DRAFT`, `ACTIVE`, `RETIRED`);
- parametros JSON por `ruleCode` I9-R01 a I9-R07;
- catalogos/matrices asociados, creador, fecha y evidencia de aprobacion;
- checksum deterministico del contenido ejecutable.

Solo puede existir una version `ACTIVE` por codigo, alcance, ambiente y periodo.
Un perfil activo es inmutable; corregirlo crea una version nueva. Un perfil
`SIMULATED` solo puede tener alcance `MVP_TEST`.

### 5.2 Gate De Produccion

La aplicacion debe rechazar el uso de un perfil `SIMULATED` cuando el ambiente o
la solicitud indiquen `PRODUCTION`. El rechazo ocurre antes de generar y no se
puede convertir en excepcion. En `MVP_TEST`, el mismo perfil permite recorrer
todo el workflow y marca propuesta, auditoria y exportacion como simuladas.

### 5.3 Resultado De Regla

Cada evaluacion produce como minimo:

- regla y version del perfil;
- proyecto, periodo, puesto, turno, asignacion y `employeeId` cuando aplique;
- resultado, severidad, codigo de mensaje y explicacion;
- parametros y hechos usados, sin PII;
- `scopeHash` deterministico;
- si admite excepcion y el estado de esa excepcion;
- fecha y correlacion de auditoria.

## 6. Comportamiento De I9-R01 A I9-R07

| Regla | Configuracion inicial del MVP | Resultado obligatorio |
|---|---|---|
| I9-R01 Jornada maxima | 8 h/dia y 42 h/semana ordinarias; 12 h/dia y 60 h/semana maximas; marca de acuerdo escrito para superar jornada ordinaria; mas de 10 y hasta 12 h requiere aprobacion | Mas de 12 h/dia o 60 h/semana: `BLOCKED`. Falta de acuerdo requerido: `BLOCKED`. Mas de 10 y hasta 12 h: `EXCEPTION_REQUIRED` |
| I9-R02 Descanso minimo | Umbral preventivo de 12 horas; motivos aprobados R02; `OTHER` exige descripcion | Descanso menor: `EXCEPTION_REQUIRED`; no impide generar, impide aprobar/publicar hasta resolver |
| I9-R03 Cruces | Intervalos semiabiertos `[inicio, fin)` sobre borradores vigentes y programaciones aprobadas | Solapamiento real: `BLOCKED`; intervalos adyacentes: `COMPLIANT`; R03 tiene prioridad sobre R05 |
| I9-R04 Novedades | Mapeo simulado inicial `INC`, `V`, `A`, `TA`; `D/N/X` no son novedades; desconocido es `UNVERIFIED` | Bloqueantes vigentes: `BLOCKED`; aprobables: `EXCEPTION_REQUIRED`; desconocido: `WARNING` que impide aprobar/publicar hasta resolver o versionar el mapeo |
| I9-R05 Traslado | Matriz simulada direccional por proyecto/puesto, minutos enteros y combinaciones prohibidas | Prohibida: `BLOCKED`; tiempo insuficiente o fila ausente: `EXCEPTION_REQUIRED`; nunca se asume cero |
| I9-R06 Requisitos | Catalogo y evaluaciones anonimas simuladas; vigencia durante todo el turno; subsanabilidad explicita | Faltante, vencido o no verificado: `EXCEPTION_REQUIRED`; informativo solo si esta configurado con responsable y plazo |
| I9-R07 Plantilla | Plantillas 2X2, 4X2 y 6X1; motivos aprobados R07; comparacion por version/anclaje/celda | Diferencia: `EXCEPTION_REQUIRED`; coincidencia: `COMPLIANT`; cambio posterior invalida aprobacion |

### 6.1 Precedencia

1. Un `BLOCKED` nunca se degrada por otra regla ni por una excepcion aprobada.
2. R03 prevalece sobre cualquier tratamiento de traslado R05.
3. Una configuracion invalida o ausente no acredita cumplimiento.
4. Las excepciones R02/R04/R05/R06/R07 cubren solo el `scopeHash` evaluado.
5. Aprobar o publicar exige cero bloqueos y cero excepciones pendientes,
   rechazadas, vencidas o desactualizadas.

## 7. Flujo Funcional

1. Operaciones selecciona proyecto, periodo y perfil activo.
2. El backend valida ambiente, vigencia y completitud del perfil.
3. La generacion construye hechos anonimos y evalua R01 a R07.
4. Un candidato bloqueado no se asigna; si no existe otro candidato queda una
   vacante explicada.
5. Un resultado aprobable crea o vincula una excepcion pendiente sin ocultar la
   asignacion propuesta.
6. Una edicion manual recalcula todas las reglas afectadas y el `scopeHash`.
7. Aprobar una excepcion registra permiso, actor, motivo, decision y snapshot.
8. Aprobar/publicar la version vuelve a evaluar el estado; una decision obsoleta
   no cuenta.
9. La version publicada es inmutable y conserva perfil, parametros, hechos,
   resultados y marca de simulacion.

## 8. Modelo De Persistencia

La migracion de cierre debe converger instalaciones parciales e incorporar:

- `scheduling_rule_profiles`: identidad, version, origen, ambiente, vigencia,
  estado, checksum y auditoria;
- `scheduling_rule_profile_entries`: una entrada JSONB por regla, validada y
  versionada;
- `scheduling_rule_evaluations`: resultado, mensaje, hechos/parametros,
  `scope_hash`, asignacion y perfil;
- ampliacion de `schedule_exceptions` con `rule_code`, `evaluation_id`,
  `scope_hash`, motivo catalogado, decision y auditoria;
- referencia del perfil y marca simulada en `schedule_versions` y sus snapshots.

No se guardan nombres, documentos, correos o telefonos en evaluaciones. Se usan
identificadores existentes y snapshots minimizados.

## 9. API

### 9.1 Configuracion

```text
GET  /api/portal/scheduling/rule-profiles
GET  /api/portal/scheduling/rule-profiles/{id}
POST /api/portal/scheduling/rule-profiles
POST /api/portal/scheduling/rule-profiles/{id}/activate
POST /api/portal/scheduling/rule-profiles/{id}/retire
POST /api/portal/scheduling/rules/evaluate
```

Configurar exige `SCHEDULING/CONFIGURE`; consultar/evaluar respeta `VIEW` o
`GENERATE`. Activar perfiles `INSTITUTIONAL` para produccion queda fuera de este
MVP y debe fallar de forma segura.

### 9.2 Workflow Existente

Generacion, edicion, excepciones, aprobacion, publicacion, reprogramacion y
exportacion mantienen sus rutas. Las respuestas agregan `ruleProfile`,
`simulated`, resumen de resultados y bloqueos/pendientes.

Los errores conservan codigo, mensaje y razones de negocio; no exponen SQL,
stack traces ni PII.

## 10. Interfaz

- selector del perfil activo para el proyecto/periodo;
- badge persistente `DATOS SIMULADOS - MVP` cuando corresponda;
- resumen por regla y resultado;
- detalle explicable por guarda/turno sin mostrar PII adicional;
- acciones de excepcion solo por capacidad;
- aprobar/publicar deshabilitado con razones visibles;
- revalidacion visible despues de edicion manual;
- tabla en escritorio y lista accesible en pantallas menores a 900 px;
- `aria-live`, `aria-label`, caption y navegacion por teclado.

El color nunca es el unico indicador de estado.

## 11. Comandos

```powershell
# Contratos y reglas por tarea
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9MvpRules.ps1

# Integracion hermetica
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Integration.ps1

# Documentacion
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Docs.ps1

# Backend
& 'C:\tmp\dotnet6\dotnet.exe' build apps/sg-superapp-api/sg-superapp-api.csproj

# Frontend
& 'C:\Program Files\nodejs\npm.cmd' --prefix apps/sg-superapp-web run build
```

## 12. Estructura Del Proyecto

```text
db/migrations/                 Persistencia versionada y convergente
db/seeds/                      Perfil y catalogos simulados del MVP
db/tests/                      Contratos SQL e idempotencia
apps/sg-superapp-api/Domain/   Hechos, resultados y modelos de reglas
apps/sg-superapp-api/Services/ Evaluacion, configuracion e integracion
apps/sg-superapp-api/Endpoints Frontera HTTP y permisos
apps/sg-superapp-web/src/      Cliente, tipos y presentacion accesible
scripts/dev/                   Verificadores TDD y suite hermetica
docs/reports/                  Evidencia y cierre del MVP
```

## 13. Estilo De Codigo

- tipos inmutables para hechos y resultados;
- codigos de regla/mensaje en mayuscula estable;
- fechas y horas mediante `DateOnly`, `TimeOnly` y `DateTimeOffset`;
- funciones de evaluacion deterministicas sin acceso directo a red o reloj;
- repositorios responsables de persistencia, no de decidir reglas;
- validacion fail-closed para configuracion incompleta.

Ejemplo:

```csharp
public sealed record RuleEvaluation(
    string RuleCode,
    string Outcome,
    bool ExceptionAllowed,
    string MessageCode,
    string ScopeHash);
```

## 14. Estrategia De Pruebas

1. RED/GREEN por contrato, regla y workflow.
2. Casos aprobados R02-T01..T16, R03-T01..T15, R04-T01..T24,
   R05-T01..T20, R06-T01..T23 y R07-T01..T23.
3. R01 cubre fronteras 8/10/12 h y 42/60 h, acuerdo y excepcion.
4. Pruebas de precedencia, `scopeHash`, invalidacion y no reutilizacion.
5. Pruebas negativas de perfil incompleto, superpuesto y simulado en produccion.
6. Doble ejecucion de migracion/seed y generacion idempotente.
7. Suite hermetica PostgreSQL/API sin datos reales.
8. Build .NET/Vite y recorrido visual responsive.

## 15. Limites De Ejecucion

### Siempre

- TDD antes de cada cambio funcional;
- fixtures anonimos y marca simulada visible;
- snapshot y auditoria de toda decision;
- revalidacion en edicion, aprobacion y publicacion;
- pruebas y build antes de cada commit.

### Requiere Nueva Aprobacion

- activar produccion;
- incorporar datos reales o PII;
- agregar dependencias externas;
- cambiar umbrales o precedencia aprobados;
- ampliar el MVP a nomina, asistencia o rutas dinamicas.

### Nunca

- tratar `PENDIENTE` como valor por defecto;
- permitir que una excepcion eluda un bloqueo absoluto;
- reutilizar aprobaciones con otro `scopeHash`;
- modificar una version publicada o sus snapshots;
- presentar configuracion simulada como institucional.

## 16. Criterios De Aceptacion

1. R01 a R07 producen resultados deterministas y explicables.
2. Todos los casos funcionales aprobados y las fronteras R01 pasan.
3. Bloqueos absolutos nunca admiten excepcion.
4. Excepciones aprobables impiden aprobar/publicar hasta resolverse.
5. Cambiar hechos, parametros o alcance invalida la aprobacion anterior.
6. El perfil simulado se ejecuta en `MVP_TEST` y se rechaza en `PRODUCTION`.
7. UI, auditoria y exportaciones identifican inequívocamente los datos simulados.
8. La suite hermetica y los builds concluyen sin errores.
9. El recorrido responsive no presenta overflow de pagina ni acciones sin
   explicacion.
10. El usuario revisa el recorrido final y autoriza el cierre del MVP.

## 17. Preguntas Abiertas

No hay preguntas bloqueantes para preparar el plan. Los valores simulados se
documentaran como fixtures tecnicos y se reemplazaran mediante nuevas versiones
cuando las areas entreguen ajustes durante las pruebas.

La implementacion solo comienza despues de la aprobacion explicita de esta SPEC
y del plan tecnico asociado.

## Resultados reales de la implementacion

Ejecutado el 2026-08-23 sobre la rama `codex/i9-scheduling-gate0`. La evidencia por verificador,
las decisiones de diseno que sostienen el MVP y los puntos abiertos estan en
[`docs/reports/2026-08-17-sg-superapp-i9-mvp-closure.md`](../reports/2026-08-17-sg-superapp-i9-mvp-closure.md).

La puerta global `Verify-SgSuperAppI9MvpRules.ps1` reporta `I9 MVP RULES PASS`, y la suite hermetica
`Verify-SgSuperAppI9MvpIntegration.ps1` reporta `I9 MVP INTEGRATION PASS 34` cubriendo las siete
reglas evaluadas por HTTP, el rechazo de `PRODUCTION`, la doble ejecucion, la precedencia y la
invalidacion por edicion.

Esta SPEC sigue describiendo un alcance `SIMULATED` / `MVP_TEST`. El cierre del MVP no se declara
aqui: depende de la autorizacion explicita del usuario y de los puntos abiertos del reporte de
cierre.

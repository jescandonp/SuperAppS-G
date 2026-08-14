# I9-R06 - Parametros, Mensajes Y Casos De Prueba

> Estado: **PROPUESTA_PARA_VALIDACION_NO_EJECUTABLE**
> Fecha: 2026-08-14
> Regla: cursos, acreditaciones y requisitos exigidos por el puesto.
> Evidencia: criterio base aprobado por el usuario; parametros detallados pendientes de aprobacion.

## Criterios Base Ya Aprobados

- cada requisito se configura por puesto, proyecto y vigencia;
- ningun incumplimiento bloquea la generacion de la propuesta;
- un requisito faltante, vencido o no verificado crea una excepcion `PENDIENTE`
  que impide aprobar o publicar;
- un requisito subsanable puede ser informativo solo mediante configuracion
  explicita y versionada;
- la ausencia de informacion nunca acredita cumplimiento; y
- la evaluacion conserva requisito, vigencia, evidencia, subsanacion, decision
  y auditoria.

## Parametros Propuestos Para Aprobacion

1. **Categorias canonicas:** `COURSE`, `ACCREDITATION`, `CERTIFICATION`,
   `LICENSE_OR_PERMIT` y `OTHER_REQUIREMENT`. Son categorias internas; los
   codigos reales de I3/I5 permanecen pendientes.
2. **Alcance:** cada requisito pertenece a puesto, proyecto o contrato y tiene
   version y vigencia. No se aplica globalmente salvo configuracion explicita.
3. **Vigencia durante el turno:** el requisito debe estar vigente desde el
   inicio hasta el fin completo del turno asignado.
4. **Estados de evaluacion:** `COMPLIANT`, `MISSING`, `EXPIRED`, `UNVERIFIED` e
   `INFORMATIVE_REMEDIABLE`. Un estado desconocido se trata como `UNVERIFIED`.
5. **Sin periodo de gracia universal:** toda tolerancia debe estar declarada en
   la version del requisito con unidad, valor, fuente y vigencia.
6. **Ruta de aprobacion propuesta:** Talento Humano valida el dato y la
   subsanabilidad; el Director de Operaciones aprueba la excepcion que permite
   aprobar o publicar mediante `SCHEDULING/APPROVE_EXCEPTION`.
7. **Subsanable informativo:** requiere clasificacion explicita, responsable de
   subsanacion y fecha limite. No equivale a cumplimiento ni se reutiliza.
8. **Excepcion no reutilizable:** cubre solo guarda, requisito, puesto, turno y
   version evaluados. Cualquier cambio revalida I9-R06.
9. **Prioridad:** una excepcion I9-R06 nunca elude bloqueos absolutos de otras
   reglas ni convierte evidencia ausente en evidencia valida.
10. **Modo de desarrollo:** desactivada o en advertencia mientras no existan
    catalogos I3/I5 mapeados, fuente/version institucional, TDD y evidencia.

## Mensajes Funcionales Propuestos

| Codigo | Condicion | Severidad | Mensaje al usuario | Accion disponible |
|---|---|---|---|---|
| I9-R06-OK | Todos los requisitos acreditados y vigentes | CUMPLE | El guarda cumple los requisitos configurados para el puesto y el turno. | Continuar |
| I9-R06-MISSING | Requisito obligatorio ausente | EXCEPCION_PENDIENTE | Falta un requisito exigido por el puesto. La propuesta puede conservarse, pero requiere validacion y aprobacion. | Ver requisito / Solicitar aprobacion / Reasignar |
| I9-R06-EXPIRED | Requisito vencido antes o durante el turno | EXCEPCION_PENDIENTE | Un requisito no permanece vigente durante todo el turno. | Ver vigencia / Solicitar aprobacion / Reasignar |
| I9-R06-UNVERIFIED | Evidencia o estado no verificado | EXCEPCION_PENDIENTE | No fue posible verificar un requisito. La ausencia de informacion no acredita cumplimiento. | Verificar / Solicitar aprobacion / Reasignar |
| I9-R06-REMEDIABLE | Requisito configurado como subsanable informativo | ADVERTENCIA_TRAZABLE | El requisito debe subsanarse dentro del plazo configurado. | Ver responsable y fecha limite |
| I9-R06-INCOMPLETE | Configuracion incompleta | ADVERTENCIA | El requisito no tiene todos los parametros necesarios y no puede decidir cumplimiento. | Completar catalogo |
| I9-R06-PENDING | Excepcion sin decision | PENDIENTE_APROBACION | La programacion no puede aprobarse ni publicarse hasta resolver la excepcion. | Validar en Talento Humano / Aprobar o rechazar en Operaciones |
| I9-R06-REJECTED | Excepcion rechazada | NO_APROBABLE | La excepcion del requisito fue rechazada. Reasigna o subsana antes de continuar. | Ver decision / Reasignar |
| I9-R06-APPROVED | Excepcion aprobada | CUMPLE_CON_EXCEPCION | La excepcion fue autorizada exclusivamente para esta asignacion. | Continuar y conservar auditoria |

## Casos De Prueba Propuestos

| Caso | Preparacion | Resultado esperado |
|---|---|---|
| R06-T01 | Todos los requisitos vigentes durante el turno | CUMPLE |
| R06-T02 | Requisito obligatorio faltante | Genera propuesta y excepcion PENDIENTE; bloquea aprobar/publicar |
| R06-T03 | Requisito vencido antes de iniciar | Excepcion PENDIENTE |
| R06-T04 | Requisito vence durante el turno | Excepcion PENDIENTE; no se considera vigente |
| R06-T05 | Requisito vence exactamente al finalizar el turno | CUMPLE usando intervalo de vigencia semiabierto compatible con el fin |
| R06-T06 | Estado o evidencia no verificado | Excepcion PENDIENTE; nunca acredita cumplimiento |
| R06-T07 | Codigo fuente desconocido | UNVERIFIED; no aproxima por nombre o semejanza |
| R06-T08 | Requisito explicitamente subsanable e informativo | Advertencia trazable; exige responsable y fecha limite |
| R06-T09 | Subsanable sin responsable | Configuracion invalida; no permite tratarlo como informativo |
| R06-T10 | Subsanable sin fecha limite | Configuracion invalida; no permite tratarlo como informativo |
| R06-T11 | Requisito no marcado subsanable | Faltante/vencido/no verificado crea excepcion PENDIENTE |
| R06-T12 | Talento Humano valida evidencia | Registra validacion; no sustituye aprobacion operativa |
| R06-T13 | Director de Operaciones aprueba excepcion validada | Permite continuar solo para la asignacion evaluada |
| R06-T14 | Director de Operaciones intenta aprobar sin validacion TH | Rechaza flujo; excepcion permanece pendiente |
| R06-T15 | Rol sin permiso intenta aprobar | Acceso denegado |
| R06-T16 | Se reutiliza aprobacion en otro turno o requisito | Rechaza reutilizacion |
| R06-T17 | Cambia guarda, puesto, turno o version | Invalida decision anterior y reevalua I9-R06 |
| R06-T18 | Catalogo tiene dos versiones activas superpuestas | Configuracion invalida; no decide cumplimiento |
| R06-T19 | No existe requisito configurado para el puesto | Advertencia de catalogo incompleto; no presume cumplimiento |
| R06-T20 | Tolerancia no configurada | No aplica periodo de gracia universal |
| R06-T21 | Excepcion R06 aprobada y existe bloqueo absoluto R01/R03/R05 | Mantiene el bloqueo absoluto |
| R06-T22 | Snapshot historico tras cambio de catalogo | Conserva requisitos, estados, vigencias, fuentes y version evaluados |
| R06-T23 | Regla en modo advertencia durante desarrollo | No decide cumplimiento productivo ni cierra Gate 2 |

## Evidencia Por Evaluacion

- guarda, turno, puesto, proyecto o contrato;
- requisito canonico, codigo fuente y categoria;
- fuente, version, vigencia y estado recibido;
- evidencia consultada y resultado de verificacion;
- clasificacion de subsanabilidad, responsable y fecha limite;
- validacion de Talento Humano;
- motivo, aprobador, decision y fecha de la excepcion; y
- resultado, mensaje, snapshot y correlacion de auditoria.

## Decisiones Pendientes De Aprobacion

1. confirmar la ruta Talento Humano valida / Director de Operaciones aprueba;
2. confirmar vigencia obligatoria durante todo el turno;
3. confirmar categorias canonicas y ausencia de periodo de gracia universal;
4. confirmar condiciones del requisito subsanable informativo; y
5. aprobar los nueve mensajes y veintitres casos de prueba.

## Condicion De Aprobacion

Este documento es una propuesta para validacion. Su aprobacion funcional no
activa I9-R06 ni cierra Gate 2. La regla requiere catalogos reales I3/I5,
mapeos institucionales, fuente/version, implementacion mediante TDD, ejecucion
satisfactoria de pruebas y evidencia antes de proponerse como ejecutable.

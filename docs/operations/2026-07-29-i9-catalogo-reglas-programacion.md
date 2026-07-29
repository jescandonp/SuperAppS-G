# Catalogo I9 De Reglas De Programacion

> Estado: **BORRADOR_NO_EJECUTABLE**
> Fecha: 2026-07-29
> Uso: levantamiento y validacion conjunta; no autoriza codigo ni ejecucion

## Evidencia De Roles Validadores

Fuente aportada por el usuario: organigrama S&G, codigo `GH-DE-01`, fecha
`24/07/2025`, version 4. En este artefacto son visibles los roles Director de
Operaciones, Director de Talento Humano y Asesor Juridico.

El organigrama identifica los roles responsables de la ruta de validacion, pero
no constituye aprobacion ni firma, no identifica aqui a las personas titulares
y no permite inferir ninguna decision. Los tres roles conservan estado
`Pendiente`.

## Regla De Uso

Cada fila requiere fuente, version, severidad, parametros y firmas. Los valores
legales numericos se diligencian solo con validacion de Juridico. Un campo
pendiente invalida la regla como entrada del motor.

| ID | Familia | Proposito verificable | Fuente/parametro pendiente | Severidad propuesta | Evidencia esperada | Estado |
|---|---|---|---|---|---|---|
| I9-R01 | Jornada maxima | Impedir o advertir que la carga acumulada exceda el limite aplicable | Norma/politica, periodo de calculo y valor por validar | Pendiente de firma | Snapshot de turnos y acumulado | BORRADOR_NO_EJECUTABLE |
| I9-R02 | Descanso minimo | Validar intervalo entre fin e inicio de turnos consecutivos | Norma/politica y valor por validar | Pendiente de firma | Turnos anterior y propuesto | BORRADOR_NO_EJECUTABLE |
| I9-R03 | Cruces | Bloquear solapamientos temporales del mismo guarda | Definicion operativa de bordes y traslados | BLOQUEANTE propuesto | Intervalos comparados | BORRADOR_NO_EJECUTABLE |
| I9-R04 | Novedades | Excluir o advertir indisponibilidad por novedad vigente | Tipos, estados y prioridad por validar | Pendiente de firma | Novedad fuente y vigencia | BORRADOR_NO_EJECUTABLE |
| I9-R05 | Ubicacion | Evaluar compatibilidad territorial y tiempo de traslado | Zonas y criterio operativo por validar | Pendiente de firma | Puestos, zonas y fuente | BORRADOR_NO_EJECUTABLE |
| I9-R06 | Requisitos | Verificar cursos, acreditaciones y condiciones del puesto | Catalogo I3/I5 y tratamiento por validar | Pendiente de firma | Requisito y habilitacion | BORRADOR_NO_EJECUTABLE |
| I9-R07 | Desviacion de plantilla | Detectar cambios frente al ciclo aprobado y exigir motivo | Tolerancias y autorizador por validar | SUBSANABLE propuesto | Plantilla, celda y motivo | BORRADOR_NO_EJECUTABLE |

## Campos Obligatorios Por Regla Antes De Activarla

- identificador y version;
- fuente juridica, politica o contractual;
- fecha de vigencia;
- alcance por contrato/proyecto;
- severidad aprobada;
- parametros exactos y unidad;
- mensaje explicable;
- responsable de excepcion;
- evidencia de pruebas de borde;
- firmas de Operaciones, Talento Humano y Juridico.

## Ruta Y Firmas De Validacion

| Rol validador | Estado | Nombre | Cargo | Decision | Observaciones | Fecha | Evidencia/firma |
|---|---|---|---|---|---|---|---|
| Director de Operaciones | Pendiente | Pendiente | Director de Operaciones | Pendiente | Pendiente | Pendiente | Pendiente |
| Director de Talento Humano | Pendiente | Pendiente | Director de Talento Humano | Pendiente | Pendiente | Pendiente | Pendiente |
| Asesor Juridico | Pendiente | Pendiente | Asesor Juridico | Pendiente | Pendiente | Pendiente | Pendiente |

Hasta completar estas firmas, el catalogo conserva estado
`BORRADOR_NO_EJECUTABLE`; el Gate 0 permanece En revision.

Acta para diligenciamiento:
`docs/operations/2026-07-29-i9-acta-validacion-gate0.md`.

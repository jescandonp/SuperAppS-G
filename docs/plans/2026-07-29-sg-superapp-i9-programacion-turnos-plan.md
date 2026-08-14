# Execution Log I9 - Gate 0 - Programacion Asistida De Turnos

> Tipo: **Execution log documental de Gate 0**
> Estado general: **Gate 0 cerrado - Tasks 2 a 12 completadas - Task 13 en ejecucion**
> Gate 0: **Cerrado**
> Fecha de apertura: 2026-07-29
> SPEC: `docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md`
> Plan tecnico: `docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan.md`
> Hito: SPEC aprobada el 2026-07-29 por el usuario, patrocinador funcional.

## Alcance Del Log

Este artefacto registra la apertura documental de I9. No sustituye el plan
tecnico exacto
`docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan.md`.
Estado del plan tecnico: **APROBADO COMO HOJA DE RUTA DOCUMENTAL**.
Estado de ejecucion: **TASK 12 COMPLETADA - TASK 13 EN EJECUCION**.

Las tres condiciones de Gate 0 estan satisfechas desde el 2026-07-29: SPEC
aprobada, catalogo aprobado para parametrizacion y cierre ejecutivo explicito.
El catalogo no es ejecutable por el motor mientras sus campos obligatorios
permanezcan incompletos o sin validar.

El catalogo conserva estado `APROBADO_PARA_PARAMETRIZACION`; las decisiones constan como
`Aprobada`. Gate 0 permanece cerrado; Tasks 2, 3, 4, 5, 6 y 7 estan
completadas junto con Tasks 8, 9, 10, 11 y 12. Task 13 esta en ejecucion.

## Ruta De Validacion Del Catalogo

La fuente aportada por el usuario es el organigrama S&G codigo `GH-DE-01`, fecha
`24/07/2025`, version 4. El organigrama identifica como roles relevantes al
Director de Operaciones, Director de Talento Humano y Asesor Juridico, pero no
constituye aprobacion ni firma y no soporta inferir nombres o decisiones.

La validacion se registra en
`docs/operations/2026-07-29-i9-acta-validacion-gate0.md`. Jorge Guzman valida
Operaciones; Carolina Rodriguez Russi valida Talento Humano y Juridica; Camilo
Piedrahita, Gerente General, realiza el cierre ejecutivo.

## Estado De Gates

| Gate / Retake | Estado | Condiciones cumplidas / proxima condicion |
|---|---|---|
| Gate 0 - autoridad documental | Cerrado | Catalogo aprobado para parametrizacion y firmado; no ejecutable; cierre ejecutivo registrado |
| Gate 1 / Tasks 2-4 - persistencia/configuracion | Completado | Persistencia, ciclos y CRUD de configuracion verificados bajo SDD/TDD |
| Gate 2 - reglas/motor | Bloqueado | Proxima condicion: completar y validar parametros de las 7 reglas |
| Gate 3 - workflow/seguridad | Bloqueado | Proxima condicion: cerrar Gate 2 |
| Gate 4 - exportaciones/UI | Bloqueado | Proxima condicion: cerrar Gate 3 |
| Gate 5 - piloto/cierre | Bloqueado | Proxima condicion: cerrar Gate 4 |

## Task 1 - Gate 0 Documental

Estado: **Cerrado**.

- [x] Verificador documental creado y RED observado.
- [x] Constitucion, Arquitectura, Tecnologia y Design alineados con I9.
- [x] SPEC formal creada.
- [x] SPEC aprobada el 2026-07-29 por el usuario/patrocinador funcional.
- [x] Catalogo juridico-operativo `APROBADO_PARA_PARAMETRIZACION`.
- [x] Validacion Operaciones: Jorge Guzman.
- [x] Validacion Talento Humano y Juridica: Carolina Rodriguez Russi.
- [x] Cierre ejecutivo: Camilo Piedrahita, Gerente General.

## Avance Tecnico Autorizado

Tasks 2, 3 y 4 se completaron con sus verificaciones. El usuario aprobo el
2026-08-11 la enmienda del modelo persistente requerida para coberturas,
disponibilidad y requisitos de puesto. La Task 4 fue completada con CRUD,
permisos y auditoria; Task 5 fue completada con elegibilidad explicable. Esta
actualizacion no habilita reglas normativas ni inicia Task 6.

## Evidencia TDD Documental

- RED esperado: `I9 DOCS FAIL` por decisiones y artefactos ausentes.
- GREEN requerido: `I9 DOCS PASS` con estados documentales coherentes.
- Verificador: `scripts/dev/Verify-SgSuperAppI9Docs.ps1`.

### Replay RED reproducible con verificador final

Base verificada: commit `baaf482`. Se uso `git archive`; no se creo ni modifico
ningun worktree registrado.

```powershell
$redRoot = Join-Path $env:TEMP ('sg-i9-red-baaf482-' + [guid]::NewGuid().ToString('N'))
$archivePath = "$redRoot.zip"
New-Item -ItemType Directory -Path $redRoot
git archive --format=zip --output=$archivePath baaf482
Expand-Archive -LiteralPath $archivePath -DestinationPath $redRoot
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Docs.ps1 -RepositoryRoot $redRoot
```

Resultado observado el 2026-07-29: `I9 DOCS FAIL`, exit code `1`, **38
faltantes exactos**:

1. `CONSTITUTION`: tabla I9.
2. `CONSTITUTION`: control humano.
3. `CONSTITUTION`: prohibicion de aprobacion/publicacion autonoma.
4. `CONSTITUTION`: jerarquia de `docs/operations/`.
5. `CONSTITUTION`: subordinacion del catalogo a las autoridades SDD.
6. `CONSTITUTION`: catalogo como fuente de parametros operativos, no ejecutable
   hasta completar y validar sus campos obligatorios.
7. `CONSTITUTION`: prohibicion de contradecir autoridades superiores.
8. `CONSTITUTION`: enlace al plan tecnico exacto.
9. `CONSTITUTION`: plan aprobado como hoja de ruta documental.
10. `CONSTITUTION`: separacion entre autorizacion y comienzo de Task 2.
11. `CONSTITUTION`: trazabilidad de las tres condiciones de Gate 0.
12. `CONSTITUTION`: retake tecnico autorizado y no iniciado.
13. `ARCHITECTURE`: modulo Programacion asistida de turnos.
14. `ARCHITECTURE`: `PlantillaDeTurno`.
15. `ARCHITECTURE`: `VersionDeProgramacion`.
16. `ARCHITECTURE`: `ExcepcionDeProgramacion`.
17. `ARCHITECTURE`: integracion I2-I3-I5-I6-I7.
18. `TECNOLOGIA`: motor heuristico deterministico.
19. `TECNOLOGIA`: `.NET 6`.
20. `TECNOLOGIA`: MVP sin dependencia externa.
21. `DESIGN`: Enterprise Sentinel.
22. `DESIGN`: referencia `Prototipos/stitch_ecosistema_digital_unificado/sentinel_enterprise/DESIGN.md`.
23. `DESIGN`: `#003366`.
24. `DESIGN`: `#FFC700`.
25. `DESIGN`: `#F8F9FA`.
26. `DESIGN`: `#FFFFFF`.
27. `DESIGN`: `#E1E4E8`.
28. `DESIGN`: radios 4px-8px.
29. `DESIGN`: Montserrat/sans para jerarquia.
30. `DESIGN`: Arial/Inter-compatible para datos.
31. `DESIGN`: prohibicion de landing/decoracion sin valor operativo.
32. `DESIGN`: matriz mensual.
33. `DESIGN`: plantillas.
34. `DESIGN`: comparacion.
35. `DESIGN`: excepciones.
36. SPEC I9 ausente.
37. Execution log I9 ausente.
38. Catalogo de reglas I9 ausente.

La copia usada para esta observacion fue
`C:\Users\jmep2\AppData\Local\Temp\sg-i9-red-baaf482-ba354d86c487418c992c1186b721c7e0`.

### Pruebas negativas del estado GREEN

Se crearon tres copias temporales independientes del estado GREEN y se ejecuto
el verificador final con `-RepositoryRoot` despues de una mutacion por caso:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Docs.ps1 -RepositoryRoot <raiz-caso>
```

Resultados reales observados el 2026-07-29:

| Caso mutado | Raiz temporal | Resultado | Exit | Controles activados |
|---|---|---|---:|---:|
| Task 2 iniciada prematuramente | Copia temporal aislada | `I9 DOCS FAIL` | 1 | 1 |
| Gate 0 revertido a abierto | Copia temporal aislada | `I9 DOCS FAIL` | 1 | 1 |
| Catalogo en borrador o inconsistente | Copia temporal aislada | `I9 DOCS FAIL` | 1 | 1 |
| Mapeo o evidencia documental alterados | Copia temporal aislada | `I9 DOCS FAIL` | 1 | 1 |
| Regla incompleta marcada `APROBADO_EJECUTABLE` | Copia temporal aislada | `I9 DOCS FAIL` | 1 | 2 |

Las mutaciones no tocaron el repositorio ni crearon worktrees registrados.

## Retake

Task 6 queda completada con persistencia de propuestas, versiones, turnos
requeridos, asignaciones, excepciones y corridas. Una version `PUBLICADA` y sus
asignaciones son inmutables; solo puede existir una version publicada por
proyecto y periodo. El commit tecnico es `d1cfa8f` y la verificacion hermetica
termino con `I9 PERSISTENCE PASS` en Windows PowerShell 5.1 y PowerShell 7.

### Cierre Task 7

Task 7 queda completada con motor heuristico deterministico, score ponderado,
desempate estable por empleado, actualizacion acumulada de carga, vacantes
explicitas y razones de ranking. La corrida persiste estados, snapshots y
asignaciones; el reintento con la misma clave retorna la corrida existente.
El commit tecnico es `0759678`. El dataset fijo produjo seis resultados, cinco
asignaciones y una vacante con `I9 RECOMMENDATIONS PASS`; el build termino con
cero advertencias y cero errores.

### Cierre Task 8

Task 8 queda completada con workflow transaccional de propuesta, ajuste manual,
excepcion documentada, aprobacion, publicacion, reemplazo controlado y auditoria.
El commit tecnico es `ef77715`. La prueba aislada verifico `I9 WORKFLOW PASS` e
`I9 SECURITY PASS`, incluido rechazo 401/403, conflicto por version esperada,
vacante aceptada preservada y detalle `selfManaged`. Persistencia termino con
`I9 PERSISTENCE PASS`; el build concluyo con cero advertencias y cero errores.

### Cierre Task 9

Task 9 queda completada con reprogramacion deterministica `MINIMUM_IMPACT` y
`GLOBAL`, metricas comparables, persistencia idempotente y cuatro categorias de
notificacion deduplicadas segun condiciones existentes. El commit tecnico es
`6a31fad`. El verificador aislado y la compilacion terminaron en verde; la
regresion disponible registro `I9 PERSISTENCE PASS`.

### Cierre Task 10

Task 10 queda completada con exportaciones de versiones publicadas a PDF y
Excel, filtros por puesto y guarda, nombres trazables y auditoria
`SCHEDULE_EXPORTED`. El commit tecnico es `7e3313a`. La prueba integral aislada
valido cabecera y cierre del PDF, estructura OpenXML del XLSX, metadatos de
cliente, proyecto, periodo, version, estado y responsable, y dos eventos de
auditoria; termino con `I9 EXPORTS PASS`. El build concluyo con cero
advertencias y cero errores.

### Cierre Task 11

Task 11 queda completada con contratos TypeScript de programacion, cliente API
para capacidades, configuracion, workflow, reprogramacion y exportaciones, y un
endpoint backend que calcula capacidades desde permisos persistidos, sin
inferirlas por rol. El commit tecnico es `f62b047`. El verificador termino con
`I9 FRONTEND API PASS`; los builds Vite y .NET concluyeron sin errores y el
backend sin advertencias.

### Cierre Task 12

Task 12 queda completada con la ruta de programacion, plantillas 2x2, 4x2 y
6x1, matriz semantica D/N/X/VACANTE, detalle explicable, comparacion de
escenarios, excepciones con motivo obligatorio, acciones por capacidades y
presentacion responsive Sentinel. El commit tecnico es `6f1ed01`. El ciclo TDD
registro RED por componentes ausentes y GREEN `I9 UI PASS`; el contrato de API
frontend termino `I9 FRONTEND API PASS` y el build Vite concluyo sin errores.

El modo demostrativo esta identificado y no representa datos reales. El
recorrido autenticado en navegador quedo pendiente para Task 13: la API local
respondio, pero el navegador integrado reporto `Failed to fetch` al iniciar
sesion y no permitio verificar visualmente los cuatro viewports. Esta limitacion
no se presenta como evidencia visual superada.

Task 13 esta en ejecucion y no cerrada. Gate 2 continua bloqueado hasta
completar y validar los parametros del catalogo; esta implementacion no vuelve
ejecutables las siete reglas normativas pendientes. Los verificadores nominales
I6/I7 del plan no existen en este checkout; esta ausencia preexistente queda
registrada y no se reemplaza por evidencia inferida. `graphify update .` no se
ejecuto porque el comando no esta instalado en el entorno.

### Apertura Task 13

Task 13 queda **EN EJECUCION - NO CERRADA** desde el 2026-08-12. Se prepararon
el checklist de demostracion y la linea base sin inventar valores. La primera
suite integral obtuvo ocho verificadores I9 en PASS y cuatro en FAIL. Tras
aplicar las migraciones locales faltantes, los retakes continuaron bloqueados
por fixtures/estado operativo: exportacion sin version publicada (404),
reprogramacion sin version elegible (409), generacion de seguridad con error
500 y workflow sin snapshot esperado.

Gate 5 permanece abierto. Los cuatro recorridos tecnicos requerian un retake
hermetico; adicionalmente, se deben ejecutar los viewports y aportar el historico
anonimizado para medir la linea base. No se crea handoff de MVP cerrado mientras
estas condiciones sigan pendientes.

### Retake Tecnico Task 13

El 2026-08-12 se incorporo y ejecuto una suite hermetica sobre un esquema
PostgreSQL temporal y una API local aislada. Configuracion, elegibilidad,
recomendaciones, ciclos, workflow, seguridad, reprogramacion y exportaciones
terminaron en PASS; tambien pasaron documentos, contrato frontend, persistencia
aislada, interfaz y las compilaciones .NET/Vite. La suite verifico deduplicacion
de notificaciones y auditoria de PDF/Excel, y elimino los datos anonimizados de
prueba al finalizar.

Con este retake quedan resueltos los cuatro bloqueos tecnicos de fixtures/estado
operativo registrados al abrir la tarea. Task 13 continua **EN EJECUCION - NO
CERRADA**: faltan el recorrido visual humano en 320, 768, 1024 y 1440 px, el
historico anonimizado y la medicion de la linea base. Tampoco se consideran
ejecutables las siete reglas normativas mientras sus parametros no hayan sido
completados y validados. `graphify update .` fue intentado y agoto 30 segundos
sin producir salida; el grafo no se declara actualizado.

### Historico Simulado Y Aprobacion Visual

El 2026-08-13 el usuario aprobo expresamente la validacion visual y aporto
`BOTANIKA JULIO.pdf` y `BOTANIKA AGOSTO.pdf` como historico con datos simulados.
La aprobacion se registra como evidencia humana, no como medicion automatizada.

Los PDF tienen contenido visual identico y ambos estan rotulados julio de 2026;
ademas, el encabezado declara 15 guardas mientras la grilla contiene 16 filas.
Por trazabilidad solo se consolido un periodo: 496 celdas, 157 turnos D, 156 N,
165 descansos X, 8 ausencias A, 8 incapacidades INC, una vacacion V y un turno
adicional TA. No se reprodujeron nombres del documento fuente.

Task 13 permanece **EN EJECUCION - NO CERRADA**. La validacion visual y la
recepcion del historico simulado ya no son pendientes; faltan confirmar las
inconsistencias de fuente, ejecutar la propuesta I9 sobre datos estructurados,
comparar sus metricas y completar/validar los parametros de las siete reglas
antes de declararlas ejecutables. En esta actualizacion se intento nuevamente
`graphify update .`, pero el comando no esta instalado o disponible en PATH.

### Parametrizacion I9-R01

El 2026-08-13 el usuario aprobo I9-R01 Jornada maxima con condicion juridica.
Quedaron definidos 8 horas diarias y 42 semanales como jornada ordinaria, y
maximos sectoriales de 12 horas diarias y 60 semanales sujetos a acuerdo escrito.
La regla permanece no ejecutable hasta que Juridico resuelva el tratamiento del
limite general posterior a 10 horas diarias frente a la regla especial de
vigilancia. La aprobacion de I9-R01 no aprueba I9-R02 a I9-R07.

### Parametrizacion I9-R02

El 2026-08-13 el usuario aprobo I9-R02 con un umbral preventivo S&G de 12
horas, sin convertirlo en bloqueo de generacion. Un intervalo menor crea una
excepcion pendiente: la propuesta puede generarse, pero no aprobarse ni
publicarse hasta contar con motivo y aprobacion auditada de una persona con
permiso `SCHEDULING/APPROVE_EXCEPTION`. I9-R02 permanece no ejecutable hasta
completar mensajes, pruebas de borde y evidencia institucional. Esta decision no
aprueba I9-R03 a I9-R07.

### Parametrizacion I9-R03

El 2026-08-13 el usuario aprobo I9-R03 con tratamiento mixto. El solapamiento
temporal real del mismo guarda es bloqueo absoluto sin excepcion. La frontera
adyacente no es solapamiento; cuando intervienen puestos distintos, un posible
conflicto de traslado genera excepcion pendiente y no permite aprobar/publicar
hasta validar I9-R05 y obtener aprobacion auditada. I9-R03 permanece no
ejecutable hasta completar sus pruebas e integracion con I9-R05. Esta decision
no aprueba I9-R04 a I9-R07.

### Parametrizacion I9-R04

El 2026-08-13 el usuario aprobo la clasificacion de novedades de I9-R04.
Incapacidad, vacaciones, licencias/calamidad, suspension/retiro y ausencia
confirmada vigentes son bloqueos absolutos. Ausencia pendiente, induccion o
capacitacion coincidente y turno adicional son excepciones aprobables. Disponible
no bloquea; descuento o sancion son informativos salvo indisponibilidad formal.
La regla permanece no ejecutable hasta mapear los codigos reales, completar
mensajes, pruebas y evidencia institucional. Esta decision no aprueba I9-R05 a
I9-R07.

### Parametrizacion I9-R05

El 2026-08-13 el usuario aprobo I9-R05 con una matriz versionada de traslados
por proyecto o contrato, sin definir tiempos universales. El intervalo
disponible debe cubrir el tiempo requerido; si es insuficiente o falta el valor,
se crea una excepcion pendiente que no bloquea la propuesta, pero impide su
aprobacion/publicacion hasta ser autorizada y auditada. Una combinacion
expresamente prohibida es bloqueo absoluto. Trafico en tiempo real y rutas
dinamicas quedan fuera del MVP. I9-R05 permanece no ejecutable hasta cargar y
validar la matriz real, completar pruebas e integrarla con I9-R03. Esta decision
no aprueba I9-R06 ni I9-R07.

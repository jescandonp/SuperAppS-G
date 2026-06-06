# S&G Super App I2 - Datos Maestros e Importacion - Plan De Implementacion

**Fecha base:** 2026-06-03  
**Ultima revision:** 2026-06-04  
**Incremento:** I2 - Datos Maestros e Importacion  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Estado del plan:** Revisado y aprobado  
**Fecha de aprobacion:** 2026-06-04  
**Gate actual:** Gate 0 y Tasks 1-3 cerrados; implementacion autorizada desde Task 4  

## 1. Objetivo

Implementar el maestro inicial de empleados/guardas y el flujo controlado de importacion Excel/CSV para que Talento Humano pueda prevalidar fuentes, importar exclusivamente registros validos, consultar errores, mantener datos laborales y salariales, y dejar auditoria reutilizable para incrementos posteriores.

I2 termina cuando los criterios de aceptacion de la SPEC I2 estan cubiertos y verificados. No termina solo con listado de empleados o prevalidacion parcial.

## 2. Documentos Rectores

Orden de autoridad aplicable:

1. `docs/CONSTITUTION.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TECNOLOGIA.md`
4. `docs/DESIGN.md`
5. `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`
6. `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`
7. Este plan
8. Codigo fuente

## 3. Gates SDD

### Gate 0 - Revision documental

- [x] SPEC I2 revisada y aprobada el 2026-06-04.
- [x] Plan I2 completo revisado y aprobado el 2026-06-04.
- [x] Decisiones tecnicas del plan aceptadas.
- [x] Alcance fuera de I2 confirmado.

Gate 0 cerrado el 2026-06-04. La implementacion puede continuar desde Task 1 y debe ejecutarse en el orden aprobado.

### Gate por tarea

Cada tarea requiere:

- trazabilidad a criterios de aceptacion;
- archivos y contratos definidos;
- verificacion ejecutable definida antes de editar codigo;
- resultado y riesgos registrados en el execution log.

### Gate de cierre I2

- [ ] Criterios de aceptacion 1-15 cubiertos.
- [ ] Pruebas funcionales y de permisos ejecutadas.
- [ ] Riesgos residuales documentados.
- [ ] SPEC, plan y documentos operativos actualizados.
- [ ] Retake point hacia I3 definido.

## 4. Alcance

### Incluido

- maestro de empleados/guardas;
- estados laborales activo y retirado;
- datos laborales basicos;
- salario base versionado;
- listado, filtros y detalle;
- edicion manual controlada;
- carga Excel `.xlsx` y CSV;
- deteccion y previsualizacion de mapeo de columnas;
- prevalidacion antes de importar;
- clasificacion de validos, incompletos, duplicados y erroneos;
- persistencia temporal estructurada de filas prevalidada;
- confirmacion para importar solo validos;
- cancelacion de carga prevalidada;
- historial, errores y exportacion CSV de errores;
- auditoria de cargas, importaciones y cambios manuales;
- permisos diferenciados para TH, Administrador, Gerencia y Operaciones.

### Fuera de alcance

- maestro normalizado de puestos y asignaciones historicas, I3;
- certificaciones laborales, I4;
- cursos y acreditaciones completos, I5;
- alertas, I6;
- integraciones HELIZA y nomina;
- correccion de errores dentro del portal antes de importar;
- merge automatico de duplicados;
- cargas programadas;
- guardas como usuarios.

## 5. Estado De Entrada

I1 esta tecnicamente cerrada y provee:

- React SPA y shell por modulos;
- backend .NET 6 y API REST;
- PostgreSQL local;
- autenticacion inicial y roles;
- permisos base de modulos;
- auditoria transversal inicial;
- scripts de inicializacion y arranque local.

Existe codigo I2 adelantado antes de la aprobacion de este plan. Se considera evidencia/prototipo sujeto a revision, no autoridad del plan. Debe validarse contra este documento y corregirse o descartarse durante las tareas correspondientes.

## 6. Decisiones Tecnicas Propuestas Para Aprobacion

| Area | Decision propuesta |
|------|--------------------|
| Formatos | Soportar CSV y `.xlsx`; `.xls` queda fuera de I2 |
| Lectura CSV | Parser estructurado del backend, con soporte inicial para coma y punto y coma |
| Lectura XLSX | Libreria .NET compatible con `net6.0`, seleccionada y fijada antes de Task 5 |
| Limite de archivo | 10 MB por carga, configurable |
| Almacenamiento del archivo | No conservar archivo original en MVP; procesar stream y conservar nombre, resumen, mapeo, filas normalizadas y errores |
| Persistencia prevalidada | Guardar lote, mapeo y filas normalizadas en staging para permitir confirmar importacion sin releer archivo |
| Retencion staging | Conservar filas del lote para trazabilidad durante el piloto; politica de purga queda para operacion posterior |
| Llave funcional | `tipo_identificacion + numero_identificacion`; default de tipo `CC` |
| Duplicado en base | No importar ni actualizar automaticamente; clasificar duplicado |
| Importacion | Solo filas clasificadas `VALIDO`, mediante confirmacion explicita de TH |
| Transaccion | Importacion de validos en una transaccion por lote |
| Salario inicial | Obligatorio; vigencia desde indicada en carga o fecha de carga |
| Salario vigente | Una sola vigencia abierta por empleado; restriccion garantizada en persistencia |
| Correccion de errores | Fuera del portal; corregir fuente y crear nueva carga |
| Exportacion de errores | CSV descargable |
| Edicion manual | Endpoint y UI exclusivos de TH; cada campo cambiado genera auditoria |
| Seguridad | Autorizacion real del lado servidor para consulta, salario, carga, importacion y edicion |

## 7. Modelo De Datos Objetivo

### Entidades principales

- `employees`
  - identidad funcional, datos laborales, estado y fuente;
- `employee_salary_history`
  - salario versionado y vigencias;
- `import_batches`
  - ciclo de vida y conteos de una carga;
- `import_column_mappings`
  - encabezado original, campo destino y estado del mapeo;
- `import_batch_rows`
  - fila normalizada, clasificacion y payload prevalidado;
- `import_batch_errors`
  - errores por fila/campo;
- `employee_change_log`
  - cambios manuales por campo;
- `audit_log`
  - eventos transversales de carga, cancelacion, importacion y edicion.

### Estados de carga

| Estado | Significado | Transiciones permitidas |
|--------|-------------|-------------------------|
| `PREVALIDANDO` | Archivo recibido y en procesamiento | `PREVALIDADA`, `CON_ERRORES`, `RECHAZADA` |
| `PREVALIDADA` | Todas las filas son validas | `IMPORTADA`, `CANCELADA` |
| `CON_ERRORES` | Hay validos y/o errores revisables | `IMPORTADA`, `CANCELADA` |
| `RECHAZADA` | Archivo o encabezados no procesables | Final |
| `IMPORTADA` | Valididos confirmados y persistidos | Final |
| `CANCELADA` | Usuario cancelo antes de importar | Final |

### Clasificacion de filas

- `VALIDO`
- `INCOMPLETO`
- `DUPLICADO`
- `ERRONEO`

Una fila tiene una unica clasificacion final, aunque conserve multiples errores. Prioridad: `DUPLICADO`, `INCOMPLETO`, `ERRONEO`, `VALIDO`.

## 8. Contratos API Objetivo

### Consulta de empleados

- `GET /api/portal/employees`
- `GET /api/portal/employees/{employeeId}`
- `PATCH /api/portal/employees/{employeeId}`

### Salario

- `GET /api/portal/employees/{employeeId}/salaries`
- `POST /api/portal/employees/{employeeId}/salaries`

### Importaciones

- `POST /api/portal/imports/prevalidate`
- `GET /api/portal/imports`
- `GET /api/portal/imports/{batchId}`
- `GET /api/portal/imports/{batchId}/mapping`
- `GET /api/portal/imports/{batchId}/rows`
- `GET /api/portal/imports/{batchId}/errors`
- `GET /api/portal/imports/{batchId}/errors/export`
- `POST /api/portal/imports/{batchId}/confirm`
- `POST /api/portal/imports/{batchId}/cancel`

Los contratos concretos DTO, codigos HTTP y errores deben quedar definidos en la tarea correspondiente antes de implementar endpoints.

## 9. Matriz De Permisos I2

| Capacidad | ADMIN | TH | GERENCIA | OPERACIONES |
|-----------|-------|----|----------|-------------|
| Consultar listado empleados | Si | Si | Si | Si |
| Consultar detalle laboral | Si | Si | Si | Si |
| Consultar salario | Si | Si | Si | No |
| Editar empleado | No por defecto | Si | No | No |
| Editar salario | No por defecto | Si | No | No |
| Prevalidar carga | Consulta/auditoria | Si | No | No |
| Confirmar/cancelar carga | No por defecto | Si | No | No |
| Consultar historial y errores | Si | Si | Resumen | No |
| Exportar errores | Si | Si | No | No |

La matriz debe materializarse en permisos backend; ocultar acciones en UI no reemplaza autorizacion.

## 10. Plan De Tareas

### Task 0 - Cerrar Gate Documental

**Objetivo:** aprobar el contrato antes de retomar codigo.

**Acciones:**

- [x] Revisar y aprobar SPEC I2.
- [x] Revisar y aprobar este plan.
- [x] Confirmar decisiones tecnicas propuestas.
- [x] Registrar fecha de aprobacion.

**Verificacion:** SPEC y plan indican estado aprobado.

**Criterios relacionados:** todos.

---

### Task 1 - Auditar Implementacion Adelantada Contra Plan

**Objetivo:** determinar que codigo existente cumple, que debe corregirse y que debe retirarse.

**Archivos a revisar:**

- `db/migrations/002_employee_master.sql`
- `db/seeds/002_employee_master_seed.sql`
- `db/seeds/003_import_batches_seed.sql`
- `apps/sg-superapp-api/Contracts/Portal/`
- `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
- `apps/sg-superapp-api/Services/EmployeeCsvPrevalidationService.cs`
- `apps/sg-superapp-web/src/features/employees/`
- `apps/sg-superapp-web/src/features/imports/`

**Acciones:**

- [x] Crear matriz cumple/no cumple por requisito.
- [x] Identificar deuda estructural: staging, estados, permisos, auditoria y Excel.
- [x] Definir cambios necesarios antes de continuar.

**Verificacion:** matriz de auditoria registrada en execution log.

**Criterios relacionados:** 1-15.

---

### Task 2 - Completar Persistencia I2

**Objetivo:** dejar modelo relacional completo y consistente.

**Acciones:**

- [x] Ajustar maestro de empleados y restricciones funcionales.
- [x] Garantizar una sola vigencia salarial abierta por empleado.
- [x] Completar estados de carga.
- [x] Crear mapeos y filas staging.
- [x] Crear indices y restricciones de integridad.
- [x] Definir migracion incremental idempotente.
- [x] Actualizar script de inicializacion DB.

**Verificacion:**

- migraciones aplican desde DB limpia;
- migraciones aplican sobre DB I1 existente;
- restricciones rechazan duplicados y vigencias invalidas.

**Criterios relacionados:** 5, 6, 7, 8, 9, 10.

---

### Task 3 - Completar Seguridad Y Permisos I2

**Objetivo:** hacer cumplir la matriz de permisos del lado servidor.

**Acciones:**

- [x] Definir permisos I2 por accion.
- [x] Asociar usuario autenticado real a solicitudes.
- [x] Proteger salario, carga, importacion, cancelacion y edicion.
- [x] Ocultar acciones no permitidas en UI.

**Verificacion:**

- pruebas por rol para consulta, salario, carga y edicion;
- Gerencia y Operaciones reciben rechazo al editar;
- Operaciones no recibe salario.

**Criterios relacionados:** 12, 13, 14.

---

### Task 4 - Completar Consulta Y Edicion De Empleados

**Objetivo:** entregar listado, detalle, salario e historial de cambios.

**Acciones:**

- [x] Completar filtros por nombre, identificacion, estado, cargo y completitud.
- [x] Completar detalle laboral.
- [x] Mostrar salario segun permiso.
- [x] Mostrar historial basico de cambios.
- [x] Implementar edicion manual controlada para TH.
- [x] Versionar cambios de salario.
- [x] Registrar auditoria por campo.

**Verificacion:**

- pruebas de filtros;
- edicion valida;
- rechazo de edicion invalida;
- auditoria con valor anterior y nuevo;
- salario versionado sin solapamiento.

**Criterios relacionados:** 1, 2, 10, 11, 12, 13, 14.

---

### Task 5 - Implementar Lectura Y Mapeo Excel/CSV

**Objetivo:** recibir fuentes soportadas y permitir revisar el mapeo antes de prevalidar.

**Acciones:**

- [x] Seleccionar y registrar libreria `.xlsx` compatible.
- [x] Implementar lectura CSV y `.xlsx`.
- [x] Validar extension, contenido y limite de archivo.
- [x] Detectar encabezados y aliases conocidos.
- [x] Persistir mapeo propuesto.
- [x] Mostrar previsualizacion del mapeo.
- [x] Rechazar archivos sin estructura minima.

**Verificacion:**

- CSV con coma;
- CSV con punto y coma;
- `.xlsx` valido;
- archivo vacio;
- archivo excedido;
- encabezados desconocidos;
- extension no soportada.

**Criterios relacionados:** 3, 4, 5.

---

### Task 6 - Implementar Motor Completo De Prevalidacion

**Objetivo:** clasificar y persistir filas sin crear empleados.

**Acciones:**

- [x] Normalizar valores.
- [x] Aplicar default `CC` y permitir `CE`.
- [x] Validar identificacion, nombre, estado, cargo, fechas y salario.
- [x] Inferir estado solo bajo reglas aprobadas.
- [x] Detectar duplicados internos y contra maestro.
- [x] Validar retiro posterior a ingreso.
- [x] Persistir filas staging y errores.
- [x] Calcular resumen consistente.

**Verificacion:** cubrir todos los casos de pruebas esperadas de la SPEC antes de importar.

**Criterios relacionados:** 4, 5, 8, 9, 10.

---

### Task 7 - Implementar Revision, Exportacion Y Cancelacion

**Objetivo:** permitir que TH decida con informacion completa antes de persistir empleados.

**Acciones:**

- [x] Mostrar resumen y filas por clasificacion.
- [x] Consultar errores por fila/campo.
- [x] Exportar errores CSV.
- [x] Cancelar carga prevalidada.
- [x] Impedir confirmar cargas rechazadas, canceladas o importadas.
- [x] Auditar cancelacion.

**Verificacion:**

- exportacion coincide con errores;
- cancelacion cambia estado y bloquea importacion;
- historial conserva resumen.

**Criterios relacionados:** 5, 6, 8.

---

### Task 8 - Implementar Confirmacion E Importacion De Validos

**Objetivo:** persistir exclusivamente filas validas tras confirmacion de TH.

**Acciones:**

- [x] Mostrar confirmacion explicita con conteos.
- [x] Importar solo staging `VALIDO`.
- [x] Crear empleado y salario inicial en transaccion.
- [x] No importar incompletos, duplicados ni erroneos.
- [x] Marcar lote `IMPORTADA`.
- [x] Auditar resultado y conteos.
- [x] Evitar doble confirmacion.

**Verificacion:**

- lote mixto importa solo validos;
- salarios quedan vigentes;
- doble confirmacion rechazada;
- rollback ante fallo transaccional.

**Criterios relacionados:** 7, 9, 10.

---

### Task 9 - Completar UI I2

**Objetivo:** entregar flujo administrativo completo alineado con `docs/DESIGN.md`.

**Pantallas:**

- listado y detalle de empleados;
- edicion manual;
- carga y mapeo;
- resumen de prevalidacion;
- filas y errores;
- confirmacion/cancelacion;
- historial de cargas.

**Acciones:**

- [x] Validar estados de carga, vacios, errores y progreso.
- [x] Aplicar acciones y datos segun rol.
- [x] Verificar escritorio y movil.
- [ ] Evitar datos simulados en flujo funcional.

**Verificacion:** build frontend y recorrido funcional por rol.

**Criterios relacionados:** 1-8, 11-15.

---

### Task 10 - Verificacion Integral Y Cierre I2

**Objetivo:** demostrar cumplimiento completo de la SPEC.

**Acciones:**

- [x] Ejecutar pruebas backend.
- [x] Ejecutar build frontend.
- [x] Ejecutar flujo end-to-end con CSV y `.xlsx`.
- [x] Ejecutar pruebas de permisos.
- [x] Validar auditoria.
- [x] Revisar criterios de aceptacion 1-15.
- [x] Registrar riesgos residuales.
- [x] Actualizar graphify con `graphify update .` cuando la herramienta este disponible.
- [x] Definir retake point I3.

**Verificacion:** matriz final de aceptacion con evidencia ejecutable.

## 11. Matriz De Trazabilidad

| Criterio SPEC | Tareas |
|---------------|--------|
| 1. Listado empleados | 2, 3, 4, 9, 10 |
| 2. Detalle empleado | 3, 4, 9, 10 |
| 3. Carga Excel/CSV | 3, 5, 9, 10 |
| 4. Prevalidacion previa | 5, 6, 10 |
| 5. Resumen de carga | 2, 6, 9, 10 |
| 6. Cancelar carga | 7, 9, 10 |
| 7. Importar validos | 8, 9, 10 |
| 8. Consultar errores | 6, 7, 9, 10 |
| 9. Evitar duplicados | 2, 6, 8, 10 |
| 10. Salario obligatorio y vigente | 2, 4, 6, 8, 10 |
| 11. Ediciones auditadas | 2, 4, 10 |
| 12. Gerencia ve salario | 3, 4, 9, 10 |
| 13. Operaciones sin salario | 3, 4, 9, 10 |
| 14. Consulta sin edicion | 3, 4, 9, 10 |
| 15. UI respeta diseño | 9, 10 |

## 12. Estrategia De Pruebas

### Persistencia

- migraciones limpias e incrementales;
- restricciones de identificacion;
- vigencias salariales;
- estados y transiciones de carga;
- atomicidad de importacion.

### Prevalidacion

- registros validos;
- identificacion vacia y `#N/A`;
- duplicados internos y existentes;
- estado desconocido;
- fechas invalidas o inconsistentes;
- salario vacio, negativo o no numerico;
- cargo nuevo;
- CSV y `.xlsx`;
- encabezados conocidos y desconocidos.

### Seguridad

- TH puede cargar, importar y editar;
- ADMIN consulta historial/auditoria;
- Gerencia consulta salario sin editar;
- Operaciones consulta sin salario y sin editar;
- solicitudes no autorizadas rechazadas por backend.

### UI

- estados vacios;
- errores de API;
- resumen y detalle;
- cancelacion y confirmacion;
- filtros;
- responsive;
- build de produccion.

## 13. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Plan y codigo divergieron por implementacion anticipada | Alto | Task 1 obligatoria antes de continuar |
| Fuentes reales con encabezados variables | Alto | Mapeo persistido y revisable |
| Duplicados ambiguos | Alto | No actualizar ni fusionar automaticamente |
| Perdida de filas validas entre prevalidacion e importacion | Alto | Persistir staging normalizado |
| Salarios solapados | Alto | Restriccion DB y servicio transaccional |
| Exposicion salarial a Operaciones | Alto | Proyecciones y autorizacion backend por rol |
| Archivo malicioso o excesivo | Alto | Limite, formatos permitidos y procesamiento controlado |
| Dependencia `.xlsx` incompatible | Medio | Prueba de compatibilidad antes de adoptar libreria |
| `graphify` no disponible localmente | Bajo | Registrar bloqueo y ejecutar al habilitar herramienta |

## 14. Decisiones Pendientes De Aprobacion

1. Aprobar formatos CSV + `.xlsx`, excluyendo `.xls`.
2. Aprobar limite configurable inicial de 10 MB.
3. Aprobar no conservar archivo original, pero si staging normalizado y mapeo.
4. Aprobar que ADMIN consulte, pero TH sea el unico rol operativo de carga/edicion.
5. Aprobar que duplicados contra maestro no actualicen automaticamente.
6. Aprobar exportacion de errores exclusivamente en CSV.
7. Seleccionar libreria concreta para `.xlsx` durante Task 5 antes de implementarla.

## 15. Registro De Desviacion SDD

Antes de completar y aprobar este plan se adelantaron migraciones, endpoints y UI parcial de empleados/importaciones. Esto incumplio la regla de la Constitucion que exige SPEC revisada/aprobada y plan completo antes de implementar.

Medida correctiva:

- implementacion pausada;
- SPEC actualizada a estado de revision;
- plan completo preparado para revision;
- codigo adelantado tratado como prototipo sujeto a auditoria en Task 1;
- no continuar implementacion hasta cerrar Gate 0.

## 16. Execution Log

### 2026-06-04 - Gate 0 cerrado

- SPEC I2 validada y aprobada.
- Plan I2 revisado y aprobado.
- Decisiones tecnicas propuestas y alcance fuera de I2 aceptados.
- Implementacion autorizada desde Task 1: auditar la implementacion adelantada contra la SPEC y el plan aprobados.
- La evidencia previa se conserva como antecedente en la seccion de desviacion SDD y sera evaluada formalmente en Task 1.

### 2026-06-04 - Task 1 auditoria de implementacion adelantada

Task 1 cerrada. La implementacion adelantada se acepta como prototipo parcial y debe corregirse en las tareas aprobadas antes de considerarse funcionalidad I2 terminada.

#### Matriz cumple/no cumple

| Area / requisito aprobado | Estado | Evidencia actual | Brecha / tarea correctiva |
|---------------------------|--------|------------------|---------------------------|
| Maestro `employees` | Parcial | `002_employee_master.sql` crea datos laborales base | Llave unica solo usa numero, no `tipo + numero`; reglas de retiro y normalizacion incompletas. Task 2 |
| Salario versionado | Parcial | Existe `employee_salary_history` y consulta del ultimo salario | No garantiza una sola vigencia abierta ni evita solapamientos. Task 2 |
| Estados completos de carga | No cumple | Solo `PREVALIDADA`, `IMPORTADA`, `RECHAZADA`, `CON_ERRORES` | Faltan `PREVALIDANDO`, `CANCELADA` y transiciones controladas. Task 2 |
| Mapeo persistido y revisable | No cumple | Alias de encabezados resueltos solo en memoria | Falta `import_column_mappings`, contrato API y UI. Tasks 2 y 5 |
| Filas staging normalizadas | No cumple critico | La prevalidacion guarda conteos y errores | Se pierden filas validas; no puede confirmarse importacion sin releer archivo. Tasks 2 y 6 |
| Errores por fila/campo | Parcial | Existe `import_batch_errors` y endpoint de consulta | Falta exportacion CSV y vinculacion con fila staging. Tasks 2 y 7 |
| Auditoria de cargas | No cumple | Existe `audit_log` transversal de I1 | Prevalidacion y cargas no escriben eventos de auditoria. Tasks 2, 7 y 8 |
| Auditoria de edicion manual | Estructura parcial | Existe `employee_change_log` | No existen endpoints, servicio ni UI de edicion. Task 4 |
| Consulta y filtros de empleados | Parcial | Listado filtra nombre/identificacion, estado y cargo | Falta filtro de completitud, permisos y pruebas. Tasks 3 y 4 |
| Detalle laboral | Parcial | Endpoint y UI muestran datos laborales | No muestra historial de cambios; siempre expone salario. Tasks 3 y 4 |
| Seguridad por rol | No cumple critico | Seeds solo definen permisos `VIEW` generales | Endpoints no autentican ni autorizan; UI usa `admin.sg`; Operaciones puede recibir salario y cualquier cliente puede prevalidar. Task 3 |
| Edicion exclusiva TH | No cumple | No implementada | Crear contratos, autorizacion, servicio, auditoria y UI. Tasks 3 y 4 |
| Lectura CSV | Parcial | Parser estructurado acepta coma/punto y coma | Limite fijo 5 MB contradice plan de 10 MB configurable; no persiste mapeo ni filas. Tasks 5 y 6 |
| Lectura `.xlsx` | No cumple | No implementada | Seleccionar libreria compatible e implementar con pruebas. Task 5 |
| Validaciones de identificacion | Parcial | Requerido, `#N/A`, duplicado interno y contra DB | No procesa/default `CC`, no permite/mappea `CE` como dato de fila. Task 6 |
| Validaciones de estado laboral | Parcial | Acepta `ACTIVO`/`RETIRADO` | Falta inferencia aprobada y contexto de fuente. Task 6 |
| Validaciones de fechas | Parcial | Valida parseo y exige retiro para retirado | No valida retiro posterior a ingreso; exige ingreso para todos sin diferenciar regla. Task 6 |
| Validaciones de salario | Parcial | Exige valor numerico no negativo | No persiste salario de staging ni vigencia propuesta. Tasks 2 y 6 |
| Clasificacion unica de fila | Parcial | Calcula conteos por prioridad | No persiste clasificacion ni payload de fila. Tasks 2 y 6 |
| Revision de resumen/errores | Parcial | UI muestra historial, conteos y errores | Falta detalle de filas por clasificacion, mapeo y permisos. Tasks 7 y 9 |
| Cancelacion de carga | No cumple | No existe contrato ni estado | Implementar transicion, autorizacion y auditoria. Task 7 |
| Exportacion de errores | No cumple | No existe endpoint ni UI | Implementar CSV descargable. Task 7 |
| Confirmacion/importacion de validos | No cumple | No existe staging ni endpoint | Implementar transaccion por lote y prevenir doble confirmacion. Task 8 |
| UI empleados/importaciones | Parcial | Existen vistas funcionales iniciales | Falta edicion, mapeo, filas, confirmacion, cancelacion, permisos y validacion responsive. Task 9 |
| Pruebas automatizadas | No cumple critico | No hay proyectos/suites propios de pruebas | Crear pruebas antes de cada cambio siguiendo TDD desde Task 2. Tasks 2-10 |
| Scripts DB | Parcial | Inicializador ejecuta migraciones/seeds actuales | Debe incorporar migracion incremental completa y verificaciones limpia/existente. Task 2 |

#### Deuda estructural priorizada

1. Persistir mapeo y filas staging normalizadas para no perder los registros validos entre prevalidacion y confirmacion.
2. Incorporar seguridad/autorizacion real por rol antes de exponer salario, cargas o edicion.
3. Completar restricciones y estados del modelo relacional, especialmente vigencia salarial y ciclo de carga.
4. Crear infraestructura de pruebas automatizadas y ejecutar cambios posteriores con TDD.
5. Completar `.xlsx`, cancelacion, exportacion, confirmacion/importacion y edicion manual.

#### Decision de continuidad

- No retirar el prototipo adelantado completo; se conservara y corregira contra pruebas porque cubre parcialmente consulta, CSV e historial.
- No ampliar UI ni endpoints funcionales antes de completar Task 2 y Task 3.
- Task 2 inicia con TDD sobre persistencia: primero pruebas/verificaciones fallidas para estados, staging, llave funcional y vigencia salarial; despues migracion incremental y ajustes de inicializacion.

### 2026-06-04 - Task 2 persistencia I2 completada

- Se siguio ciclo TDD para el contrato de persistencia:
  - RED inicial valido: `Verify-SgSuperAppI2Persistence.ps1` fallo por ausencia de `import_column_mappings`;
  - GREEN: migracion incremental `003_i2_persistence_completion.sql` aplicada y contrato aprobado.
- Se cambio la llave funcional de empleados a indice unico `(identification_type, identification_number)`.
- Se agrego restriccion de una sola vigencia salarial abierta por empleado.
- Se completaron estados de carga: `PREVALIDANDO`, `PREVALIDADA`, `CON_ERRORES`, `RECHAZADA`, `IMPORTADA`, `CANCELADA`.
- Se crearon `import_column_mappings` e `import_batch_rows` para mapeo y staging normalizado.
- Se vincularon errores opcionalmente con filas staging mediante `import_batch_row_id`.
- Se actualizaron indices e inicializacion DB.
- Verificaciones:
  - `Verify-SgSuperAppI2Persistence.ps1`: correcto sobre DB existente;
  - migracion `003_i2_persistence_completion.sql`: reejecutable correctamente;
  - `Verify-SgSuperAppI2PersistenceClean.ps1`: correcto desde esquema limpio aislado;
  - pruebas de comportamiento confirman llave funcional, salario abierto unico y estados aprobados.
- Retake point: Task 3, completar seguridad y permisos I2 antes de ampliar UI o endpoints funcionales.

### 2026-06-04 - Task 3 seguridad y permisos I2 completada

- Se siguieron ciclos TDD sobre la matriz de seguridad:
  - RED: `GET /api/portal/imports` respondia `200` sin sesion;
  - GREEN: endpoints I2 sin sesion responden `401`;
  - RED ampliado: la consulta de empleados por rol expuso parametros Npgsql nulos sin tipo y respuestas interrumpidas;
  - GREEN ampliado: matriz completa de roles y proyeccion salarial validada.
- Se agrego `app_sessions` con tokens opacos almacenados como hash SHA-256, expiracion y revocacion preparada.
- Login real crea una sesion y rechaza usuarios inactivos.
- Middleware de sesion resuelve el usuario autenticado desde `Authorization: Bearer`.
- Los permisos se validan desde `role_permissions` del lado servidor.
- Se agregaron usuarios controlados de TH, Gerencia y Operaciones para verificacion local.
- Matriz materializada:
  - ADMIN consulta empleados, salario, historial y errores; no prevalidada;
  - TH consulta salario y opera prevalidacion/cargas;
  - GERENCIA consulta empleados, salario y resumen de cargas sin errores operativos;
  - OPERACIONES consulta empleados sin salario y no accede a cargas.
- El backend ignora `uploadedBy` enviado por cliente y usa el usuario autenticado.
- El frontend persiste y envia Bearer token; la accion de prevalidacion solo se muestra para TH.
- Se corrigio el tipado explicito de filtros Npgsql nulos detectado por la suite.
- Verificaciones:
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 errores;
  - frontend `npm run build`: correcto;
  - migracion y seed de seguridad: reejecutables.
- Retake point: Task 4, completar consulta y edicion de empleados mediante TDD.

### 2026-06-04 - Task 4 ciclo 1 filtro de completitud

- Se inicio Task 4 con TDD sobre el listado de empleados:
  - RED valido: `Verify-SgSuperAppI2EmployeeFilters.ps1` demostro que `completeness=INCOMPLETO` era ignorado y devolvia registros completos;
  - GREEN: el endpoint, repositorio y UI soportan filtro `COMPLETO`/`INCOMPLETO`.
- El listado muestra el estado de completitud derivado de `record_status`.
- La verificacion usa un empleado incompleto temporal y limpia el dato al finalizar.
- Verificaciones:
  - `Verify-SgSuperAppI2EmployeeFilters.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto.
- Task 4 permanece abierta.
- Retake point: siguiente ciclo TDD para detalle con historial basico de cambios.

### 2026-06-04 - Task 4 ciclo 2 detalle e historial basico

- Se continuo Task 4 con TDD sobre el detalle de empleado:
  - la primera ejecucion detecto un defecto preexistente: el detalle cortaba la respuesta porque .NET 6 no serializaba `DateOnly`;
  - se corrigio el contrato para exponer fechas ISO `yyyy-MM-dd`, compatibles con el frontend;
  - RED funcional: el detalle no exponia el cambio temporal registrado en `employee_change_log`;
  - GREEN: el detalle incluye hasta 50 cambios recientes con usuario, fecha, campo, valor anterior y valor nuevo.
- La UI muestra historial basico y estado vacio cuando no existen cambios.
- Verificaciones:
  - `Verify-SgSuperAppI2EmployeeHistory.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeFilters.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto.
- Task 4 permanece abierta.
- Retake point: siguiente ciclo TDD para edicion manual valida exclusiva de TH y rechazo por otros roles.

### 2026-06-04 - Task 4 ciclo 3 edicion laboral exclusiva de TH

- Se continuo Task 4 con TDD sobre edicion manual y permisos:
  - RED valido: `PUT /api/portal/employees/{id}` no existia y respondia `405`;
  - GREEN: TH puede editar nombre, cargo y observaciones; ADMIN, GERENCIA y OPERACIONES reciben `403`.
- La actualizacion laboral se ejecuta en una transaccion y registra una fila de `employee_change_log` por cada campo modificado, usando el usuario autenticado real.
- La UI muestra el formulario de edicion exclusivamente para TH.
- Verificaciones:
  - `Verify-SgSuperAppI2EmployeeEditing.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeHistory.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeFilters.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto.
- Task 4 permanece abierta.
- Retake point: siguiente ciclo TDD para completar campos laborales editables y versionado salarial sin solapamiento.

### 2026-06-04 - Task 4 completada

- Se cerro Task 4 con TDD sobre campos laborales completos, rechazo invalido y versionado salarial:
  - RED: estado laboral, fechas, motivo, contrato y salario eran ignorados por el endpoint;
  - GREEN: la actualizacion transaccional persiste y audita todos los campos laborales editables aprobados;
  - RED adicional: retiro anterior al ingreso rompia la respuesta;
  - GREEN adicional: las reglas laborales y salariales invalidas responden `400` y revierten la transaccion.
- Los cambios de salario cierran la vigencia abierta el dia anterior a la nueva vigencia y crean una unica vigencia abierta nueva.
- Se audita `base_salary_amount` con valor anterior y nuevo.
- La UI TH incluye campos laborales completos y salario con fecha de vigencia.
- Verificaciones finales Task 4:
  - `Verify-SgSuperAppI2EmployeeSalaryVersioning.ps1`: correcto, incluyendo rechazo invalido y ausencia de solapamiento;
  - `Verify-SgSuperAppI2EmployeeEditing.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeHistory.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeFilters.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto.
- Task 4 cerrada.
- Retake point: Task 5, seleccionar y registrar libreria `.xlsx` compatible antes de implementar lectura y mapeo Excel/CSV.

### 2026-06-04 - Task 5 ciclo 1 seleccion OpenXML y adaptador XLSX

- Se selecciono y fijo `DocumentFormat.OpenXml 3.0.2` para lectura `.xlsx`.
- Criterios de seleccion:
  - compatible y compilado correctamente con `net6.0`;
  - no requiere Microsoft Excel instalado ni automatizacion COM;
  - permite lectura directa del formato Open XML en el backend.
- Se agrego un adaptador que lee la primera hoja XLSX y reutiliza el parser/prevalidador tabular existente.
- El endpoint y la UI aceptan `.csv` y `.xlsx`; `.xls` permanece fuera de alcance.
- Se corrigio el limite de archivo de 5 MB a los 10 MB aprobados.
- Ciclo TDD de robustez:
  - RED: un archivo `.xlsx` corrupto cortaba la respuesta;
  - GREEN: un archivo `.xlsx` corrupto responde `400` controlado.
- Verificaciones:
  - backend `dotnet build`: correcto con OpenXML, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - rechazo de XLSX corrupto: correcto con HTTP `400`.
- Task 5 permanece abierta.
- Retake point: crear fixtures CSV/XLSX validos, extraer encabezados y persistir/previsualizar el mapeo propuesto.

### 2026-06-04 - Task 5 ciclo 2 mapeo persistido y previsualizable

- Se definio el contrato de mapeo por encabezado con:
  - encabezado fuente;
  - campo destino;
  - estado `MAPPED` o `UNMAPPED`;
  - posicion original.
- El parser CSV genera el mapeo propuesto a partir de aliases conocidos.
- `SaveImportPrevalidationAsync` persiste el mapeo dentro de la misma transaccion del lote.
- Se agrego endpoint protegido para consultar mapeos por lote.
- La UI muestra la previsualizacion del mapeo en el detalle de carga.
- Ciclo TDD:
  - RED: el lote se creaba pero `GET /api/portal/imports/{id}/mappings` respondia `404`;
  - GREEN: un CSV fixture persiste siete encabezados, seis `MAPPED` y uno `UNMAPPED`, consultables por API.
- Verificaciones:
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - verificaciones acumuladas Task 4: correctas;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto.
- Task 5 permanece abierta.
- Retake point: verificar fixture `.xlsx` valido y completar matriz de archivo vacio, excedido, encabezados desconocidos y extension no soportada.

### 2026-06-04 - Task 5 completada

- Se cerro Task 5 con una matriz reproducible de formatos y rechazos.
- Ciclo TDD final:
  - RED: un CSV con todos los encabezados desconocidos era aceptado y creaba lote;
  - GREEN: CSV y XLSX sin estructura minima de empleados responden `400` antes de persistir.
- Se genero un fixture XLSX valido basado en ZIP/XML OpenXML, sin depender de Microsoft Excel instalado.
- Verificaciones finales Task 5:
  - CSV con coma: correcto;
  - CSV con punto y coma: correcto;
  - XLSX valido: correcto;
  - archivo vacio: rechazado con `400`;
  - archivo mayor a 10 MB: rechazado con `400`;
  - encabezados desconocidos: rechazados con `400`;
  - extension no soportada: rechazada con `400`;
  - `Verify-SgSuperAppI2ImportFormats.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - verificaciones acumuladas Task 4: correctas;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto.
- Task 5 cerrada.
- Retake point: Task 6, implementar motor completo de prevalidacion y persistir filas normalizadas en staging.

### 2026-06-04 - Task 6 ciclo 1 filas staging y errores vinculados

- Se inicio Task 6 con TDD sobre un lote mixto:
  - RED: la prevalidacion creaba lote y errores, pero no persistia filas en `import_batch_rows`;
  - GREEN: cada fila se persiste con clasificacion unica, identificacion, payload normalizado y payload fuente.
- Prioridad de clasificacion materializada:
  - `DUPLICADO`;
  - `INCOMPLETO`;
  - `ERRONEO`;
  - `VALIDO`.
- Los errores quedan vinculados a su fila staging mediante `import_batch_row_id`.
- La persistencia de lote, filas, errores y mapeos ocurre en una unica transaccion.
- La prueba confirma que prevalidar no crea empleados.
- Verificaciones:
  - `Verify-SgSuperAppI2PrevalidationStaging.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportFormats.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 6 permanece abierta.
- Retake point: siguiente ciclo TDD para default `CC`, soporte `CE` y normalizacion completa de valores.

### 2026-06-04 - Task 6 ciclo 2 tipo de identificacion y normalizacion

- Se continuo Task 6 con TDD sobre tipo de identificacion y payloads:
  - RED: todas las filas staging se persistian como `CC` y un tipo no permitido quedaba `VALIDO`;
  - GREEN: el alias `tipo_documento`/`tipo_identificacion` se mapea, el tipo ausente usa default `CC`, `CE` se acepta y otros tipos quedan `ERRONEO`.
- Los valores normalizados recortan espacios y convierten tipo de identificacion y estado laboral a mayusculas.
- `source_payload` conserva los valores fuente sin recortar para trazabilidad.
- Se retiro el check `CC`/`CE` exclusivamente de `import_batch_rows`, porque staging debe conservar tipos invalidos; la restriccion permanece en `employees`.
- Verificaciones:
  - `Verify-SgSuperAppI2PrevalidationNormalization.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStaging.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportFormats.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 6 permanece abierta.
- Retake point: siguiente ciclo TDD para identificacion vacia/`#N/A` y duplicados internos/contra maestro usando llave funcional `tipo + numero`.

### 2026-06-04 - Task 6 ciclo 3 identificacion y duplicados funcionales

- Se continuo Task 6 con TDD sobre identificacion y duplicados:
  - RED: la deteccion comparaba solo numero y marcaba como duplicados registros `CC`/`CE` distintos;
  - GREEN: duplicados internos y contra maestro usan la llave funcional canonica `tipo_identificacion + numero_identificacion`.
- El default `CC` participa correctamente en la llave funcional.
- Identificacion vacia y `#N/A` se clasifican `INCOMPLETO`.
- Un mismo numero con tipos `CC` y `CE` no se considera duplicado.
- Verificaciones:
  - `Verify-SgSuperAppI2PrevalidationIdentification.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationNormalization.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStaging.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportFormats.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 6 permanece abierta.
- Retake point: siguiente ciclo TDD para inferencia aprobada de estado y retiro posterior a ingreso.

### 2026-06-04 - Task 6 ciclo 4 inferencia de estado y coherencia de fechas

- Se continuo Task 6 con TDD sobre estado laboral y fechas:
  - RED: estados vacios quedaban `INCOMPLETO` y un retiro anterior al ingreso era aceptado;
  - GREEN: estado vacio sin retiro infiere `ACTIVO`; con fecha de retiro infiere `RETIRADO`.
- Estados no reconocidos permanecen `ERRONEO`.
- Una fecha de retiro anterior al ingreso genera error estructurado `FECHA_INCONSISTENTE`.
- Conforme a la SPEC, retiro igual al ingreso es permitido porque solo se prohibe una fecha anterior.
- `normalized_payload` conserva el estado efectivo inferido y `source_payload` conserva el valor original vacio.
- Se amplio idempotentemente el check de `import_batch_errors.error_type` para persistir `FECHA_INCONSISTENTE`.
- Verificaciones:
  - `Verify-SgSuperAppI2PrevalidationStatusDates.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationIdentification.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationNormalization.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStaging.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportFormats.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 6 permanece abierta.
- Retake point: siguiente ciclo TDD para salario vacio, negativo/no numerico, normalizacion salarial y resumen consistente con staging.

### 2026-06-04 - Task 6 completada

- Se cerro Task 6 con TDD sobre salario y resumen:
  - RED: salarios validos formateados conservaban texto monetario no canonico en staging;
  - GREEN: salarios validos se normalizan con cultura invariante y dos decimales.
- Salario vacio queda `INCOMPLETO`; salario negativo o no numerico queda `ERRONEO`.
- Los conteos persistidos del lote coinciden con las clasificaciones de `import_batch_rows`.
- Matriz completa de prevalidacion cubierta:
  - normalizacion trazable;
  - default `CC`, soporte `CE` y rechazo de otros tipos;
  - identificaciones incompletas;
  - duplicados internos y contra maestro por llave funcional;
  - inferencia de estado;
  - fechas parseables y retiro no anterior al ingreso;
  - salario obligatorio, numerico y no negativo;
  - filas staging, errores vinculados y resumen consistente.
- Verificaciones finales Task 6:
  - `Verify-SgSuperAppI2PrevalidationSalarySummary.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStatusDates.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationIdentification.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationNormalization.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStaging.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportFormats.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 6 cerrada.
- Retake point: Task 7, implementar revision, exportacion CSV de errores y cancelacion mediante TDD.

### 2026-06-04 - Task 7 ciclo 1 consulta de filas staging

- Se inicio Task 7 con TDD sobre revision de filas:
  - RED: `GET /api/portal/imports/{batchId}/rows` no existia y respondia `404`;
  - GREEN: el endpoint devuelve filas staging tipadas y permite filtrar por `VALIDO`, `INCOMPLETO`, `DUPLICADO` o `ERRONEO`.
- El contrato expone identificacion, clasificacion, `normalizedPayload` y `sourcePayload`.
- Se reutilizo el permiso detallado `IMPORTS/VIEW_ERRORS`:
  - ADMIN y TH consultan filas;
  - GERENCIA y OPERACIONES reciben `403`;
  - solicitudes anonimas reciben `401`.
- Clasificaciones no soportadas responden `400`.
- Verificaciones:
  - `Verify-SgSuperAppI2ImportRows.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationSalarySummary.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStaging.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 7 permanece abierta.
- Retake point: siguiente ciclo TDD para exportacion CSV protegida de errores.

### 2026-06-04 - Task 7 ciclo 2 exportacion CSV de errores

- Se continuo Task 7 con TDD sobre exportacion:
  - RED: `GET /api/portal/imports/{batchId}/errors/export` no existia y respondia `404`;
  - GREEN: el endpoint descarga CSV UTF-8 con encabezados, fila, campo, tipo, mensaje y valor original.
- La exportacion usa los errores persistidos como unica fuente de verdad y conserva el mismo orden del endpoint JSON.
- El generador aplica escape CSV a comas, comillas y saltos de linea.
- Se reutilizo `IMPORTS/VIEW_ERRORS`: ADMIN y TH exportan; GERENCIA, OPERACIONES y anonimos quedan bloqueados.
- Verificaciones:
  - `Verify-SgSuperAppI2ImportErrorExport.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportRows.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationSalarySummary.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 7 permanece abierta.
- Retake point: siguiente ciclo TDD para cancelacion de carga prevalidada, bloqueo por estado y auditoria.

### 2026-06-04 - Task 7 ciclo 3 cancelacion y auditoria

- Se continuo Task 7 con TDD sobre cancelacion:
  - RED: `POST /api/portal/imports/{batchId}/cancel` no existia y respondia `404`;
  - GREEN: TH puede cancelar lotes `PREVALIDADA` o `CON_ERRORES`.
- La operacion bloquea la fila del lote, actualiza estado y registra auditoria dentro de una misma transaccion.
- Cancelacion repetida y estados finales responden `409`; lote inexistente responde `404`.
- Se materializo la matriz aprobada:
  - TH cancela mediante `IMPORTS/MANAGE`;
  - ADMIN, GERENCIA y OPERACIONES reciben `403`;
  - solicitudes anonimas reciben `401`.
- Auditoria registra `IMPORT_CANCELLED`, entidad `IMPORT_BATCH`, usuario real y estado anterior.
- Verificaciones:
  - `Verify-SgSuperAppI2ImportCancellation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportErrorExport.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportRows.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 7 permanece abierta solo por el guard de confirmacion sobre estados finales, que se materializara junto al endpoint de confirmacion en Task 8 para evitar logica muerta.
- Retake point: Task 8 ciclo 1, confirmacion explicita y guard de estados; al cerrarlo, cerrar formalmente Task 7.

### 2026-06-04 - Tasks 7 y 8 completadas

- Se inicio Task 8 con TDD sobre confirmacion/importacion:
  - RED: `POST /api/portal/imports/{batchId}/confirm` no existia y respondia `404`;
  - GREEN: TH confirma lotes `PREVALIDADA` o `CON_ERRORES` e importa exclusivamente filas staging `VALIDO`.
- La confirmacion ejecuta en una unica transaccion:
  - bloqueo del lote;
  - lectura de filas validas;
  - creacion de empleados;
  - creacion de salario inicial vigente;
  - cambio del lote a `IMPORTADA`;
  - auditoria `IMPORT_CONFIRMED` con conteo importado.
- Filas `INCOMPLETO`, `DUPLICADO` y `ERRONEO` no crean empleados.
- Salario inicial usa la fecha de ingreso como vigencia inicial y fuente `IMPORT`.
- Confirmacion repetida, lote cancelado y otros estados finales responden `409`; lote inexistente responde `404`.
- Solo TH opera confirmacion mediante `IMPORTS/MANAGE`; otros roles quedan bloqueados.
- El guard de confirmacion pendiente completa formalmente Task 7.
- Verificaciones:
  - `Verify-SgSuperAppI2ImportConfirmation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportCancellation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportErrorExport.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportRows.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationSalarySummary.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Tasks 7 y 8 cerradas.
- Retake point: Task 9, completar UI I2 para filas, errores, exportacion, confirmacion y cancelacion.

### 2026-06-04 - Task 9 ciclo 1 flujo UI de importaciones

- Se completo la integracion UI del flujo de importaciones con los endpoints verificados:
  - consulta y filtro de filas staging por clasificacion;
  - visualizacion de errores y descarga CSV;
  - confirmacion y cancelacion explicitas con mensajes y refresco del lote;
  - estados `PREVALIDANDO`, `PREVALIDADA`, `CON_ERRORES`, `IMPORTADA` y `CANCELADA`.
- La matriz de acciones queda materializada en UI:
  - ADMIN y TH pueden exportar errores;
  - solo TH puede confirmar o cancelar lotes prevalidables;
  - estados finales no muestran acciones de gestion.
- Verificaciones:
  - frontend `npm run build`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - `Verify-SgSuperAppI2ImportConfirmation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportCancellation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportErrorExport.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportRows.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto.
- Task 9 permanece abierta por recorrido visual de estados vacios/errores y verificacion escritorio/movil.
- Retake point: Task 9 ciclo 2, verificar visualmente por rol y ajustar responsive/estados antes de Task 10.

### 2026-06-04 - Task 9 ciclo 2 matriz visual por rol y estados

- Se ajusto la pantalla de importaciones para reflejar la matriz backend:
  - ADMIN y TH consultan historial, filas, mapeos y errores;
  - TH conserva prevalidacion, confirmacion y cancelacion;
  - ADMIN puede exportar errores, pero no gestionar lotes;
  - GERENCIA consulta historial sin detalle tecnico de filas/errores;
  - OPERACIONES queda bloqueado visualmente del modulo.
- Se diferenciaron chips de estado para `PREVALIDANDO`, `PREVALIDADA`, `CON_ERRORES`, `IMPORTADA`, `CANCELADA` y `RECHAZADA`.
- Se corrigieron estados vacios/texto del detalle de filas prevalidadas.
- Verificacion HTTP de matriz:
  - `admin.sg`: imports `200`, rows `200`;
  - `th.sg`: imports `200`, rows `200`;
  - `gerencia.sg`: imports `200`, rows `403`;
  - `operaciones.sg`: imports `403`, rows `403`.
- Verificaciones:
  - frontend `npm run build`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores;
  - `Verify-SgSuperAppI2ImportConfirmation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportCancellation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportErrorExport.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportRows.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto.
- Limitacion: no se completo recorrido real en navegador desktop/movil porque Playwright no esta instalado y el plugin Node fallo por sandbox Windows; Vite solo arranco fuera del sandbox.
- Se acepta cierre tecnico de Task 9 con build frontend, inspeccion responsive, matriz HTTP por rol y riesgo residual documentado para recorrido visual manual.
- Task 9 cerrada tecnicamente.
- Retake point: Task 10, verificacion integral y cierre I2.

### 2026-06-04 - Task 10 verificacion integral y cierre tecnico I2

- Se ejecuto la suite completa `scripts/dev/Verify-SgSuperAppI2*.ps1` con API activa:
  - `Verify-SgSuperAppI2EmployeeEditing.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeFilters.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeHistory.ps1`: correcto;
  - `Verify-SgSuperAppI2EmployeeSalaryVersioning.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportCancellation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportConfirmation.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportErrorExport.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportFormats.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportMappings.ps1`: correcto;
  - `Verify-SgSuperAppI2ImportRows.ps1`: correcto;
  - `Verify-SgSuperAppI2Persistence.ps1`: correcto;
  - `Verify-SgSuperAppI2PersistenceClean.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationIdentification.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationNormalization.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationSalarySummary.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStaging.ps1`: correcto;
  - `Verify-SgSuperAppI2PrevalidationStatusDates.ps1`: correcto;
  - `Verify-SgSuperAppI2Security.ps1`: correcto.
- Builds finales:
  - frontend `npm run build`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Matriz de aceptacion SPEC I2:
  - 1 listado de empleados/guardas: cubierto por `Verify-SgSuperAppI2EmployeeFilters.ps1`;
  - 2 detalle de empleado/guarda: cubierto por `Verify-SgSuperAppI2EmployeeHistory.ps1`;
  - 3 carga Excel/CSV: cubierto por `Verify-SgSuperAppI2ImportFormats.ps1`;
  - 4 prevalidacion antes de importar: cubierto por scripts de prevalidacion y confirmacion;
  - 5 resumen de carga: cubierto por `Verify-SgSuperAppI2PrevalidationSalarySummary.ps1`;
  - 6 cancelacion de carga prevalidada: cubierto por `Verify-SgSuperAppI2ImportCancellation.ps1`;
  - 7 importacion de validos: cubierto por `Verify-SgSuperAppI2ImportConfirmation.ps1`;
  - 8 errores consultables: cubierto por `Verify-SgSuperAppI2ImportRows.ps1` y `Verify-SgSuperAppI2ImportErrorExport.ps1`;
  - 9 duplicados por identificacion: cubierto por `Verify-SgSuperAppI2PrevalidationIdentification.ps1`;
  - 10 salario obligatorio y vigencia: cubierto por `Verify-SgSuperAppI2EmployeeSalaryVersioning.ps1` y `Verify-SgSuperAppI2PrevalidationSalarySummary.ps1`;
  - 11 auditoria de ediciones: cubierto por `Verify-SgSuperAppI2EmployeeEditing.ps1`;
  - 12 Gerencia consulta detalle salarial: cubierto por `Verify-SgSuperAppI2Security.ps1`;
  - 13 Operaciones consulta empleados sin detalle salarial: cubierto por `Verify-SgSuperAppI2Security.ps1`;
  - 14 Gerencia y Operaciones sin edicion: cubierto por `Verify-SgSuperAppI2Security.ps1`;
  - 15 UI respeta `docs/DESIGN.md`: cubierto por build frontend, dark/gold administrativo, componentes densos, matriz visual por rol y riesgo residual de recorrido manual.
- Riesgos residuales:
  - no hay recorrido real desktop/movil automatizado por falta de Playwright y fallo del plugin Node en sandbox Windows;
  - `graphify update .` no puede ejecutarse porque `graphify` no esta instalado;
  - hay cambios acumulados sin commit y `AGENTS.md` contiene cambio externo no gestionado en esta ejecucion.
- Task 10 cerrada tecnicamente.
- Retake point I3: leer `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`, validar alcance y crear plan SDD I3 antes de implementar.

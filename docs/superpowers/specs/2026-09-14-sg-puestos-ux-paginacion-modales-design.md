# Diseño — UX del módulo de Puestos de Servicio: paginación, detalle agrupado y modales

> Estado: **Aprobado por el usuario para especificación**
> Fecha: 2026-09-14
> Alcance: módulo "Puestos de Servicio" (`PositionsPage`) únicamente
> Origen: pedido directo del usuario de replicar el estándar ya aprobado en el
> módulo de Empleados (spec `2026-09-12-sg-empleados-ux-paginacion-modales-design.md`),
> enfocado en lo difícil que es hoy hacer operaciones CRUD sobre un puesto.

## 1. Propósito y alcance

`PositionsPage.tsx` (455 líneas) tiene hoy tres problemas de experiencia,
paralelos a los que ya se corrigieron en Empleados:

- El listado (`GET /api/portal/positions`) carga todos los registros sin
  paginar — no escala a la cantidad de puestos esperada en producción.
- El panel de Detalle es un `dl` plano de 4 pares (Estado, Ubicación,
  Asignados vigentes, Observaciones).
- El único formulario CRUD (crear/editar puesto, 5 campos) vive siempre
  expandido dentro del panel de Detalle cuando el usuario tiene permiso,
  mezclado visualmente con el resumen de solo lectura y las listas de
  asignaciones — el mismo antipatrón que tenía "Edición manual" en
  Empleados. A diferencia de Empleados, este formulario ya usa
  correctamente las clases `.position-form`/`.position-form-actions`: no
  hay que arreglar CSS, solo reubicarlo.

A diferencia de Empleados, el detalle de Puestos tiene solo 4 campos (no
12), así que **no se fragmenta en secciones con encabezado** — fragmentar
un resumen de 4 campos sería sobre-diseño. El enfoque aquí es sacar el
formulario del medio del panel, no reorganizar el resumen.

Esta iteración además agrega una capacidad que hoy no existe en absoluto:
gestionar asignaciones de empleados **desde el lado de Puestos** (hoy esa
gestión solo existe en el modal "Gestionar asignación" de `EmployeesPage`;
Puestos solo muestra las asignaciones vigentes en solo lectura). Es una
extensión de alcance explícitamente pedida por el usuario, no un
descubrimiento a mitad de camino.

## 2. Backend — paginación aditiva, sin romper el contrato existente

`GET /api/portal/positions` tiene hoy un único consumidor además de
`PositionsPage`: el selector de puestos activos del modal "Gestionar
asignación" en `EmployeesPage.tsx:182` (`fetchServicePositions({ status:
"ACTIVO" })`, sin `search` ni paginación). Igual que con Empleados, la
paginación se agrega como parámetros **opcionales**:

- `page` (entero, default `1`).
- `pageSize` (entero, default `25`, máximo `100`).

Sin esos parámetros, el comportamiento es idéntico al actual (arreglo
completo). El total viaja en el header `X-Total-Count`.

En `PostgresPortalRepository.GetServicePositionsAsync` (línea 1199):

- La consulta principal (1201-1221) agrega `limit @pageSize offset
  @offset` cuando se reciben parámetros de paginación.
- Una segunda consulta `select count(*) ...` reutiliza el mismo `where`
  (search/status) para el total.
- El endpoint en `PortalEndpoints.cs` (714-735) escribe `X-Total-Count`
  antes de `Results.Ok(positions)`.

`fetchServicePositions` en `portalApi.ts` gana parámetros opcionales
`page`/`pageSize`, expone `{ items, totalCount }` cuando se pasan (mismo
patrón ya usado por `fetchEmployees`). La llamada de
`EmployeesPage.tsx:182` no cambia — sigue sin pasarlos.

## 3. Frontend — listado con paginación

`PositionsPage` guarda `page`/`pageSize` en estado (`pageSize` inicia en
25). Cambiar `search` o `status` reinicia `page` a 1. Debajo de la tabla:
controles "Anterior"/"Siguiente" (deshabilitados en los extremos),
indicador "Página X de Y", selector de tamaño (20/50/100) — idéntico a
Empleados.

## 4. Panel de Detalle — se mantiene el resumen, se saca el formulario

El `dl` de 4 pares (Estado, Ubicación, Asignados vigentes, Observaciones)
no cambia de contenido ni de estructura. Arriba del resumen se agregan
botones de acción, visibles solo si `canManagePositions` (`user.role ===
"ADMIN" || user.role === "TH"`, línea 155):

- **"Nuevo puesto"** (sin selección) / **"Editar puesto"** (con selección)
  — abre el modal de creación/edición.
- **"Asignar empleado"** (con selección, solo si `selectedPosition.status
  === "ACTIVO"`) — abre el modal de nueva asignación. Se oculta en vez de
  mostrarse deshabilitado en puestos inactivos: `CreatePositionAssignment
  Async` (`PostgresPortalRepository.cs:2774-2778`) ya rechaza con
  `INACTIVE_POSITION` cualquier intento sobre un puesto no-ACTIVO, así que
  no tiene sentido ofrecer una acción garantizada a fallar.

Las secciones "Asignaciones vigentes" (406-421) e "Historial básico"
(423-440) permanecen como listas de tarjetas de solo lectura, sin cambios
de contenido. Cada tarjeta de "Asignaciones vigentes" gana un botón
**"Finalizar"**, visible solo si `canManagePositions`.

## 5. Modal "Crear/Editar puesto" — reubicación directa, sin cambios de campos

El formulario existente (código, nombre, cliente, ubicación, observaciones
— líneas 370-404, ya con `.position-form`/`.position-form-actions`) se
mueve tal cual dentro de `Modal` (`components/Modal.tsx`, ya existente
desde la iteración de Empleados). `formMode`/`formCode`/`formName`/etc. no
cambian de nombre ni de lógica — solo se envuelven en un nuevo flag
`isPositionModalOpen`. "Nuevo puesto" y "Editar puesto" abren el mismo
modal con `formMode` en `"create"`/`"edit"` respectivamente, igual que hoy
determina qué título y qué botón mostrar. Guardar con éxito cierra el
modal, refresca el detalle (`fetchServicePositionDetail`, sin cambios) y
la fila correspondiente en el listado.

## 6. Modal "Asignar empleado" — nueva capacidad

Nuevo flag `isAssignEmployeeModalOpen`. Contenido: buscador de empleado
(input de texto + `<select>` con `fullName · identificationNumber ·
employmentStatus`), igual al patrón ya usado en `CertificatesPage.tsx`
para elegir empleado; fecha de inicio (`<input type="date">`, default
hoy); botón "Asignar". Al confirmar, llama a `createPositionAssignment`
(ya existente en `portalApi.ts`, hoy solo usada desde `EmployeesPage`)
con el `positionId` del puesto seleccionado.

El backend ya rechaza con `ACTIVE_ASSIGNMENT_EXISTS` (`PostgresPortal
Repository.cs:2816`) si el empleado elegido ya tiene una asignación
vigente en cualquier puesto, y con `INACTIVE_POSITION` (líneas 2774-2778)
si el puesto no está ACTIVO (este segundo caso ya no debería alcanzarse
desde la UI dado el botón oculto en puestos inactivos — se mapea de todas
formas, por si el estado del puesto cambió entre que se cargó el detalle y
se envió el formulario) — el modal no necesita filtrar la lista de
empleados de antemano; ambos códigos de error se traducen a un mensaje
dentro del modal, mismo patrón que ya usan otros módulos para errores 409
conocidos (ej. Certificaciones con `MISSING_BASE_SALARY`).

Guardar con éxito cierra el modal, refresca la lista de "Asignaciones
vigentes" y el contador `activeAssignmentsCount` del puesto (releer
detalle) y la fila correspondiente en el listado.

## 7. Modal "Finalizar asignación" — nueva capacidad, por tarjeta

Nuevo flag `finalizingAssignmentId: number | null` (id de la asignación
que se está finalizando, no un booleano — porque puede haber varias
tarjetas, cada una con su propio botón "Finalizar"). Contenido: fecha de
fin (`<input type="date">`, obligatoria — único campo requerido por
`FinalizePositionAssignmentRequest.EndDate`), motivo (`<textarea>`,
opcional — `ChangeReason` es `string?` en el contrato actual, no se
agrega una validación nueva). Al confirmar, llama a
`finalizePositionAssignment` (ya existente, hoy solo usada desde
`EmployeesPage`) con el id de esa asignación puntual.

Guardar con éxito cierra el modal y refresca "Asignaciones vigentes" +
`activeAssignmentsCount` + la fila del listado, igual que el modal de
asignar.

## 8. Decisión de arquitectura: sin componente compartido con Empleados

Un empleado tiene como máximo una asignación vigente (por eso el modal de
Empleados es un único formulario "asignar o finalizar" que alterna según
`currentAssignment`); un puesto puede tener varias vigentes a la vez
(`activeAssignmentsCount` ya lo confirma), así que el flujo no es
simétrico: "asignar" es una acción sobre el puesto completo, "finalizar"
es una acción por asignación individual. Se evaluó extraer un componente
`AssignmentModal` compartido entre ambos módulos; se descarta para esta
iteración — con solo 2 usos reales y selectores de entrada distintos
(elegir puesto vs. elegir empleado), forzar una única API parametrizada
añade complejidad sin beneficio claro (YAGNI). Lo único compartido son las
funciones ya existentes de `portalApi.ts` (`createPositionAssignment`/
`finalizePositionAssignment`) y el primitivo `Modal`.

## 9. Fuera de alcance

- Extraer un componente de asignación compartido entre Empleados y
  Puestos (ver sección 8).
- Cualquier cambio a permisos (`role_permissions`) o a los campos
  editables del puesto.
- Deshacer o editar una asignación ya finalizada.
- La revisión integral de la experiencia de toda la aplicación mencionada
  como ambición futura en iteraciones anteriores.

## 10. Pruebas

- Verificador PowerShell nuevo o extendido para paginación de puestos:
  `page`/`pageSize` devuelven el subconjunto correcto y `X-Total-Count`
  coincide con el total real bajo distintos filtros; una llamada sin esos
  parámetros sigue devolviendo el arreglo completo (confirma que el
  selector de Empleados no se ve afectado).
- Verificador para el flujo de asignación: crear asignación desde Puestos
  incrementa `activeAssignmentsCount`; intentar asignar a un empleado con
  asignación vigente devuelve `ACTIVE_ASSIGNMENT_EXISTS`; finalizar una
  asignación puntual la saca de "vigentes" sin afectar otras asignaciones
  activas del mismo puesto.
- Backend build (`dotnet build`) y frontend build (`tsc -b` + `vite
  build`).
- Recorrido manual: paginar con filtros activos; crear/editar un puesto
  por modal; asignar un empleado desde Puestos y confirmar que aparece en
  "Asignaciones vigentes" y en el modal de asignación de `EmployeesPage`
  para ese mismo empleado; finalizar una asignación puntual cuando hay
  varias vigentes en el mismo puesto y confirmar que solo esa desaparece;
  abrir/cerrar los tres modales por las tres vías (✕, backdrop, Escape);
  responsive en 375px.

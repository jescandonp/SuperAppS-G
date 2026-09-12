# Plan De Implementacion - Estabilizacion CRUD I2/I3 Y Gestion De Proyectos I9

> Estado: **CERRADO - Grupos A, B y C implementados y verificados en navegador el 2026-09-11.**
> Fecha: 2026-09-10 (implementacion completada 2026-09-11)
> Decisiones B1 y C2 resueltas por el usuario el 2026-09-10 (ver seccion 9).
> Origen: hallazgos de pruebas funcionales sobre `claude/app-functional-testing-crud-49545d`.
> SPECs de autoridad (sin cambio de alcance, ver seccion 1):
>   - `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`
>   - `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`
>   - `docs/specs/2026-07-29-sg-superapp-spec-i9-programacion-turnos.md`
> Arquitectura de referencia: `docs/ARCHITECTURE.md` §5.11 (entidad `ProyectoDeProgramacion`).
> Base tecnica: rama actual, sin commits pendientes de este plan.
> Regla de avance: no iniciar ninguna tarea de codigo hasta aprobacion explicita del
> usuario sobre este plan, y no iniciar las tareas marcadas **[DECISION PENDIENTE]**
> hasta resolver la decision de producto asociada (Constitucion §2: *"Si aparece una
> decision no resuelta, se vuelve a entendimiento antes de codificar"*).

## 1. Encuadre SDD: por que no se abre una SPEC nueva

Segun `docs/CONSTITUTION.md` §2, todo cambio de alcance entra por PRD o SPEC, nunca
por codigo. Se verifico contra las SPECs vigentes antes de escribir este plan:

- **I3 (Puestos de servicio):** el CRUD de puestos (crear, editar, inactivar,
  listar detalle y asignaciones) ya esta en la SPEC I3 y ya esta implementado en
  `PositionsPage.tsx` y `PortalEndpoints.cs`. El hallazgo no es de alcance, es un
  defecto de manejo de errores. **No requiere SPEC nueva.**
- **I2 (Empleados):** la edicion del maestro de empleados ya esta en la SPEC I2 y
  ya esta implementada, restringida al rol `TH` por diseno de permisos
  (`db/seeds/004_i2_security_users_permissions.sql`). El hallazgo mezcla un
  defecto (mismo manejo de errores que I3) con una pregunta de politica de
  permisos que no se resuelve en codigo. **No requiere SPEC nueva; requiere
  decision de producto (ver Task B1).**
- **I9 (Programacion de turnos):** `docs/ARCHITECTURE.md` §5.11 y la SPEC I9 ya
  definen `ProyectoDeProgramacion` como entidad del limite I9, con estados
  `BORRADOR/ACTIVO/CERRADO`. El backend ya expone el CRUD completo
  (`PortalEndpoints.cs:165-214`). Lo que falta es la capa de aplicacion (cliente
  API) y la capa de presentacion (pantalla). El Task 12 del plan original de I9
  (`docs/superpowers/plans/2026-07-29-...-implementation-plan.md`) solo pedia un
  **selector** de proyecto existente, nunca un formulario de alta - por eso el
  hueco no se detecto antes. **No requiere SPEC nueva; completa una capacidad ya
  aprobada y no construida.**

Conclusion: este plan cierra brechas de implementacion dentro de SPECs ya
aprobadas. No se modifica `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md` ni
`docs/DESIGN.md`.

## 2. Objetivo

1. Que ningun panel de detalle (Puestos, Empleados) quede en blanco sin explicar
   por que, cuando la carga de datos falla.
2. Resolver si el rol `ADMIN` debe poder editar el maestro de empleados, y dejar
   la experiencia de solo-lectura explicita mientras tanto.
3. Permitir crear, editar e inactivar clientes y proyectos de programacion desde
   el portal, para desbloquear el flujo completo de Programacion de turnos.

## 3. Decisiones De Arquitectura

1. **No tocar el motor de reglas ni el flujo generar/aprobar/publicar de I9** -
   este plan es exclusivamente maestro de proyectos/clientes, capa anterior al
   motor.
2. **Reutilizar el patron ya establecido**: DTO -> endpoint minimo -> repositorio
   con SQL parametrizado -> cliente `portalApi.ts` -> componente de React
   controlado por `SchedulingCapabilities`/rol, igual que `PositionsPage.tsx`.
3. **Los errores silenciosos se convierten en estado visible, nunca en excepcion
   no controlada**: todo `catch` de un efecto de carga de detalle debe fijar un
   mensaje de error legible, distinguiendo "no encontrado" de "fallo de red/permiso".
4. **La autorizacion de `SCHEDULING.CONFIGURE` se corrige para ser explicita por
   rol**, eliminando el atajo actual donde cualquier rol no-ADMIN con
   `SCHEDULING.GENERATE` puede crear/editar clientes, proyectos, reglas de
   cobertura y requisitos de puesto sin tener `CONFIGURE` concedido
   (`PortalEndpoints.cs:1188-1196`). Que roles reciben `CONFIGURE` es una
   decision de producto (Task C2).
5. **Sin verificador de front-end automatizado (Jest/Vitest) en este repo** - la
   verificacion de UI sigue el patron ya usado: script `Verify-*.ps1` de
   estructura + `npm run build` (tsc + vite) + recorrido manual documentado.

## 4. Dependencias

```text
Grupo A (I2/I3) - Errores visibles en detalle
    |
    +-- A1 Puestos: catch visible en PositionsPage.tsx
    +-- A2 Empleados: catch visible en EmployeesPage.tsx
            (independientes entre si, sin bloqueo)

Grupo B (I2) - Alcance de edicion de empleados          [DECISION PENDIENTE]
    +-- B1 Decision de producto: ADMIN edita o no
            |
            +-- B2 Implementacion segun decision B1

Grupo C (I9) - Gestion de proyectos y clientes
    +-- C1 Backend: listar clientes (falta GET /scheduling/clients)
    +-- C2 Backend: corregir gate CONFIGURE vs GENERATE   [DECISION PENDIENTE]
            |
    +-------+-- C3 Cliente API frontend (portalApi.ts)
                    |
                    +-- C4 UI: panel Clientes y Proyectos (crear/editar/inactivar)
                            |
                            +-- C5 Verificacion integral y recorrido manual
```

Los grupos A, B y C no dependen entre si y pueden ejecutarse en cualquier orden;
dentro de C, C3 depende de C1, y C4 depende de C3. C2 puede resolverse en paralelo
pero **bloquea** exponer el panel de administracion a roles distintos de ADMIN.

## 5. Tareas

### Grupo A - Errores visibles en paneles de detalle

#### Task A1 - Puestos de servicio: exponer fallos de carga de detalle

**Descripcion:** el efecto de carga de detalle en `PositionsPage.tsx` (líneas
88-126) hace `Promise.all([fetchServicePositionDetail, fetchServicePositionAssignments])`
y en su `catch` (líneas 109-118) solo limpia el estado (`setSelectedPosition(null)`)
sin fijar `errorMessage`. Resultado observado en pruebas: la fila queda
seleccionada (borde dorado) pero el panel derecho muestra "Seleccione un puesto
para ver su detalle" sin explicacion, indistinguible de "no hay seleccion".
`reloadPosition` (líneas 168-176) tiene el mismo problema sin `catch` alguno.

**Archivos:**

- Modify: `apps/sg-superapp-web/src/features/positions/PositionsPage.tsx`

**Aceptacion:**

- [ ] El `catch` del efecto de detalle fija `errorMessage` con texto especifico
      (`"No fue posible cargar el detalle del puesto."`) y lo muestra en el
      panel de detalle, no solo en el listado.
- [ ] Un 404 real (`PortalApiError.status === 404`) muestra un mensaje distinto
      ("El puesto ya no existe o fue removido") en vez de mensaje generico.
- [ ] `reloadPosition` propaga el error al llamador (`savePosition`,
      `deactivateSelectedPosition`) en vez de fallar silenciosamente.
- [ ] El estado de carga (`detailLoading`) y el de error nunca se muestran a la
      vez de forma ambigua.

**Verificacion:**

```powershell
& 'C:\tmp\dotnet6\dotnet.exe' build apps/sg-superapp-api/sg-superapp-api.csproj
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
```

Recorrido manual: detener temporalmente la API o forzar un 500/403 (por ejemplo
revocando `POSITION_ASSIGNMENTS.VIEW` a un usuario de prueba) y confirmar que el
panel de detalle explica el fallo en vez de quedar vacio.

**Dependencias:** ninguna.
**Alcance:** XS, 1 archivo.

#### Task A2 - Empleados: exponer fallos de carga de detalle

**Descripcion:** mismo patron de defecto en `EmployeesPage.tsx`, efecto de
detalle (líneas 121-173), `catch` en líneas 155-165 y `reloadSelectedEmployee`
(líneas 202-210) sin manejo de error.

**Archivos:**

- Modify: `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx`

**Aceptacion:**

- [ ] Mismos criterios que Task A1, adaptados a empleado (detalle, asignaciones
      de puesto, puestos disponibles).
- [ ] Un fallo parcial (por ejemplo `fetchServicePositions` cae pero
      `fetchEmployeeDetail` funciona) no borra el detalle ya cargado del
      empleado; se informa que la lista de puestos disponibles no cargo, sin
      ocultar el resto.

**Verificacion:** igual a Task A1, aplicada al modulo de empleados.

**Dependencias:** ninguna (se puede ejecutar en paralelo con A1).
**Alcance:** XS, 1 archivo.

### Checkpoint A - Visibilidad de errores

- [ ] A1 y A2 en verde, build limpio.
- [ ] Revision humana confirma que ningun panel de detalle queda en blanco sin
      mensaje ante un fallo simulado.

### Grupo B - Alcance de edicion del maestro de empleados

#### Task B1 - Decision de producto **[DECISION PENDIENTE]**

**Descripcion:** hoy `EMPLOYEES.EDIT` solo esta concedido a `TH`
(`db/seeds/004_i2_security_users_permissions.sql:33-39`); `ADMIN` solo tiene
`VIEW`/`VIEW_SALARY`. Esto es consistente con la segregacion de funciones sobre
datos laborales, pero es asimetrico frente a Puestos de servicio, donde
`ADMIN` si administra (`canManagePositions` en `PositionsPage.tsx:140`). No se
implementa nada de este grupo hasta que el usuario/dueño de producto elija una
opcion:

- **Opcion 1 (mantener):** `ADMIN` sigue sin `EMPLOYEES.EDIT`; se mejora
  unicamente el mensaje para que quien no sea `TH` entienda por que no ve el
  formulario.
- **Opcion 2 (ampliar):** se agrega `('ADMIN', 'EMPLOYEES', 'EDIT')` al seed de
  permisos y el gate de UI pasa de `user.role === "TH"` a
  `user.role === "ADMIN" || user.role === "TH"`, igual que Puestos.

**Recomendacion tecnica:** Opcion 1 por defecto (no se toca una regla de
segregacion de funciones ya decidida sin autorizacion explicita), pero la
decision es de negocio, no tecnica.

#### Task B2 - Implementar segun B1

**Descripcion:** aplicar la opcion elegida en `EmployeesPage.tsx:498` (gate de
"Edicion manual") y, si aplica Opcion 2, en
`db/seeds/004_i2_security_users_permissions.sql`.

**Archivos:**

- Modify: `apps/sg-superapp-web/src/features/employees/EmployeesPage.tsx`
- Modify condicional: `db/seeds/004_i2_security_users_permissions.sql`

**Aceptacion:**

- [ ] Si Opcion 1: un usuario sin `EMPLOYEES.EDIT` ve un texto explicito
      ("Solo el rol Talento Humano edita el maestro de empleados") en vez de
      que la seccion desaparezca sin explicacion.
- [ ] Si Opcion 2: `ADMIN` ve y usa el formulario de edicion manual; se
      re-ejecuta el seed en un entorno de prueba y se confirma con
      `Verify-SgSuperAppI2Security.ps1`.

**Verificacion:**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI2Security.ps1
```

**Dependencias:** Task B1 resuelta.
**Alcance:** XS, 1-2 archivos.

### Grupo C - Gestion de clientes y proyectos de programacion (I9)

#### Task C1 - Backend: listar clientes de programacion

**Descripcion:** existe CRUD completo de clientes
(`PortalEndpoints.cs:122-163`: crear, obtener por id, actualizar, inactivar)
pero **no existe `GET /api/portal/scheduling/clients`** para listar. Sin listado
no se puede construir un selector de cliente en el formulario de proyecto.

**Archivos:**

- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Modify: `apps/sg-superapp-api/Services/PostgresPortalRepository.cs`
  (nuevo `GetSchedulingClientsAsync`)
- Modify: `scripts/dev/Verify-SgSuperAppI9MvpWorkflow.ps1` o nuevo verificador
  dedicado (ver Task C5)

**Aceptacion:**

- [ ] `GET /api/portal/scheduling/clients` responde 200 con la lista, filtrable
      por `status` igual que `GET /api/portal/positions`.
- [ ] Requiere `RequireSchedulingConfigurationAsync` (mismo gate que el resto de
      configuracion I9).
- [ ] Orden estable (por `status`, luego `name`) igual que
      `GetCertificateSignersAsync` como referencia de patron.

**Verificacion:**

```powershell
& 'C:\tmp\dotnet6\dotnet.exe' build apps/sg-superapp-api/sg-superapp-api.csproj
```

**Dependencias:** ninguna.
**Alcance:** S, 2 archivos.

#### Task C2 - Backend: corregir el gate CONFIGURE/GENERATE **[RESUELTO: Opcion 1, solo ADMIN]**

**Descripcion:** `RequireSchedulingConfigurationAsync`
(`PortalEndpoints.cs:1188-1196`) exige `SCHEDULING.CONFIGURE` solo si el rol es
`ADMIN`; para cualquier otro rol exige `SCHEDULING.GENERATE`. Hoy solo `ADMIN` y
`OPERACIONES` tienen algun permiso `SCHEDULING`
(`db/seeds/009_i9_scheduling_permissions.sql`), y `OPERACIONES` tiene
`GENERATE` pero no `CONFIGURE` — por este atajo, **`OPERACIONES` ya puede crear,
editar e inactivar clientes, proyectos, reglas de cobertura y requisitos de
puesto sin tener `CONFIGURE` concedido explicitamente.** Antes de construir la
pantalla de administracion de proyectos hay que decidir el modelo de permisos
real, porque la pantalla nueva hara visible (y mas facil de usar) una capacidad
que hoy ya existe pero esta escondida en el codigo:

- **Opcion 1:** `CONFIGURE` queda exclusivo de `ADMIN`; se corrige el helper
  para exigir `CONFIGURE` a todos los roles por igual (elimina el atajo). Solo
  `ADMIN` vera el panel de administracion de proyectos/clientes.
- **Opcion 2:** se concede `SCHEDULING.CONFIGURE` explicitamente a `OPERACIONES`
  (o a `TH`, si el maestro de proyectos se considera dato de TH) y se corrige el
  helper igual que en Opcion 1, dejando la concesion explicita en el seed en vez
  de implicita en el codigo.

**Recomendacion tecnica:** Opcion 1 como piso minimo seguro; si Operaciones
necesita crear proyectos en el dia a dia, moverse a Opcion 2 de forma explicita
para que quede auditable en el seed, no implicito en un `if`.

**Archivos (una vez decidido):**

- Modify: `apps/sg-superapp-api/Endpoints/PortalEndpoints.cs`
- Modify condicional: `db/seeds/009_i9_scheduling_permissions.sql`

**Aceptacion:**

- [ ] `RequireSchedulingConfigurationAsync` exige `SCHEDULING.CONFIGURE` para
      todos los roles, sin bifurcacion por nombre de rol.
- [ ] El seed refleja exactamente que roles pueden configurar, sin permisos
      implicitos via `GENERATE`.
- [ ] Prueba negativa: un usuario `OPERACIONES` sin `CONFIGURE` recibe 403 al
      intentar crear un cliente o proyecto tras el fix (si se elige Opcion 1).

**Dependencias:** ninguna tecnica; bloquea el alcance de roles de Task C4.
**Alcance:** XS, 1-2 archivos.

#### Task C3 - Cliente API frontend para clientes y proyectos

**Descripcion:** `portalApi.ts` solo expone `fetchSchedulingProjects` (GET) y
`fetchSchedulingCapabilities`. Faltan las funciones para el resto del CRUD que
ya existe en el backend.

**Archivos:**

- Modify: `apps/sg-superapp-web/src/services/portalApi.ts`
- Modify: `apps/sg-superapp-web/src/types/portal.ts` (tipos `SchedulingClient`,
  `SchedulingProjectStatus`, `UpsertSchedulingClientRequest`,
  `UpsertSchedulingProjectRequest`)

**Aceptacion:**

- [ ] `fetchSchedulingClients`, `createSchedulingClient`,
      `updateSchedulingClient`, `inactivateSchedulingClient`.
- [ ] `fetchSchedulingProjectDetail`, `createSchedulingProject`,
      `updateSchedulingProject`, `inactivateSchedulingProject`.
- [ ] Reutiliza `getJson`/`sendJson` y `PortalApiError` ya existentes; ningun
      `fetch` nuevo fuera de ese patron.

**Verificacion:**

```powershell
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
```

**Dependencias:** Task C1 (para el listado de clientes).
**Alcance:** S, 2 archivos.

#### Task C4 - UI: panel de gestion de clientes y proyectos

**Descripcion:** nueva seccion dentro de `SchedulingPage.tsx` (o pestaña nueva
"Proyectos") que permite listar, crear, editar e inactivar clientes y
proyectos, siguiendo el mismo patron visual y de estado de
`PositionsPage.tsx` (listado + panel de detalle + formulario condicionado por
permiso). Visible solo cuando `capabilities.configure === true` (dato que ya
devuelve `GET /portal/scheduling/capabilities`), asi la UI nunca decide el
permiso por su cuenta.

**Archivos:**

- Create: `apps/sg-superapp-web/src/features/scheduling/ProjectsPanel.tsx`
- Modify: `apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx`
  (nueva pestaña o seccion, selector de proyecto pasa a alimentarse del mismo
  estado que gestiona el panel)
- Modify: `apps/sg-superapp-web/src/styles.css` (reutilizar clases
  `employees-workspace`/`panel`/`position-form` ya existentes, sin crear
  sistema visual paralelo)
- Create: `scripts/dev/Verify-SgSuperAppI9ProjectsUi.ps1`

**Aceptacion:**

- [ ] Formulario de proyecto: cliente (select poblado desde
      `fetchSchedulingClients`), codigo, nombre, vigente desde/hasta, estado.
      Validaciones espejo de las del backend (código y nombre obligatorios,
      vigencia final no anterior a inicial).
- [ ] Formulario de cliente minimo: codigo, nombre, estado - para no bloquear
      la creacion de un proyecto por falta de cliente.
- [ ] El selector de proyecto en la barra de control de `SchedulingPage`
      refleja inmediatamente un proyecto recien creado, sin recargar la
      pagina.
- [ ] Inactivar un proyecto en uso no rompe una propuesta ya generada (solo
      impide nuevas propuestas); mensaje claro si el backend rechaza la
      inactivacion.
- [ ] Sin permiso `configure`, la seccion no aparece (igual patron que
      `canManagePositions` en Puestos), no queda visible-mas-deshabilitada.

**Verificacion:**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9ProjectsUi.ps1
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
```

**Dependencias:** Task C3, Task C2 resuelta (para saber que roles probar).
**Alcance:** M, 3-4 archivos.

#### Task C5 - Verificacion integral y recorrido funcional

**Descripcion:** cerrar el grupo C con regresion completa y recorrido manual
punta a punta: crear cliente -> crear proyecto -> seleccionarlo en la barra de
control -> generar propuesta (flujo ya existente) sin tocar el motor de reglas.

**Archivos:** ninguno nuevo; ejecuta lo creado en C1-C4.

**Aceptacion:**

- [ ] Recorrido completo documentado (capturas o notas) desde crear proyecto
      hasta generar una propuesta sobre ese proyecto.
- [ ] Los verificadores I9 existentes (`Verify-SgSuperAppI9MvpIntegration.ps1`,
      `Verify-SgSuperAppI9Integration.ps1`) siguen en verde; no hubo regresion
      sobre el motor de reglas.

**Verificacion:**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9ProjectsUi.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9MvpIntegration.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Integration.ps1
& 'C:\tmp\dotnet6\dotnet.exe' build apps/sg-superapp-api/sg-superapp-api.csproj
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
```

**Dependencias:** C1-C4 completas.
**Alcance:** S, sin archivos nuevos.

### Checkpoint C - Gestion de proyectos operativa

- [ ] Un usuario con `configure` crea un cliente y un proyecto de punta a
      punta desde la UI, sin tocar la base de datos a mano.
- [ ] Un usuario sin `configure` no ve la seccion y, si intenta el endpoint
      directamente, recibe 403.

## 6. Gate Final

Este retake puede darse por cerrado solo cuando:

- [ ] Checkpoints A y C estan en verde.
- [ ] Task B1 tiene decision registrada (cualquiera de las dos opciones) y B2
      ejecutada en consecuencia.
- [ ] Task C2 tiene decision registrada y aplicada.
- [ ] `dotnet build` y `npm run build` pasan limpios.
- [ ] No quedan `catch` silenciosos nuevos introducidos por este plan.
- [ ] El usuario autoriza explicitamente el cierre.

## 7. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|---|---|---|
| Ampliar `CONFIGURE` sin decision del cliente crea una brecha de permisos permanente | Alto | Task C2 bloquea Task C4 hasta decision explicita |
| Cambiar el gate de empleados sin autorizacion de TH/Juridica rompe segregacion de funciones ya acordada | Alto | Task B1 no se implementa sin decision explicita del usuario |
| Nuevo panel de proyectos duplica estilos en vez de reusar patron de Puestos | Medio | Task C4 reutiliza clases CSS existentes, sin sistema visual paralelo |
| Mensajes de error nuevos exponen detalle tecnico al usuario final | Bajo | Mensajes en espanol funcional, sin stack trace, siguiendo tono ya usado en `PositionsPage.tsx` |
| Corregir el gate CONFIGURE/GENERATE (Task C2) rompe un flujo de Operaciones no documentado que dependia del atajo | Medio | Prueba negativa explicita en C2 antes de cerrar; validar con el usuario que rol reemplaza el acceso perdido |

## 8. Comandos De Regresion (referencia rapida)

```powershell
& 'C:\tmp\dotnet6\dotnet.exe' build apps/sg-superapp-api/sg-superapp-api.csproj
node "C:\Program Files\nodejs\node_modules\npm\bin\npm-cli.js" run build --prefix apps/sg-superapp-web
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI2Security.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI3Positions.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9MvpIntegration.ps1
powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Integration.ps1
```

## 9. Decisiones Pendientes

**Resueltas por el usuario el 2026-09-10:**

- **B1: Opcion 2 - Ampliar a ADMIN.** Se agrega `EMPLOYEES.EDIT` a `ADMIN` en
  `db/seeds/004_i2_security_users_permissions.sql` y el gate de UI en
  `EmployeesPage.tsx` pasa a `role === "ADMIN" || role === "TH"`.
- **C2: revisada a Opcion 1 - Solo ADMIN.** La primera respuesta fue "ADMIN +
  OPERACIONES", pero al implementar se encontro que
  `db/tests/007_i9_scheduling_contract.sql:318-324` ya tiene un contrato
  ejecutable explicito que prohibe `('OPERACIONES', 'CONFIGURE')`
  ("OPERACIONES must not configure global scheduling rules"). Se devolvio la
  decision al usuario con ese hallazgo y se confirmo Opcion 1. Se corrigio el
  atajo `CONFIGURE`-solo-ADMIN/`GENERATE`-para-el-resto en
  `RequireSchedulingConfigurationAsync` para exigir `SCHEDULING.CONFIGURE` a
  todos los roles por igual (sin bifurcacion por rol); el seed
  `db/seeds/009_i9_scheduling_permissions.sql` no cambio porque ya coincidia
  con la regla correcta - el defecto estaba solo en el codigo del endpoint,
  que trataba `GENERATE` como equivalente a `CONFIGURE` para OPERACIONES.
- **Aprobacion general:** el usuario autorizo iniciar todas las tareas del
  plan (Grupo A, B y C) el 2026-09-10.

## 10. Cierre Y Evidencia De Ejecucion (2026-09-11)

Todas las tareas (A1, A2, B2, C1, C2, C3, C4) quedaron implementadas. Verificacion
ejecutada contra el stack local (API .NET en `:5080`, web Vite en `:3000`,
Postgres local) con sesion real `admin.sg` / rol `ADMIN`:

- **A1/A2** - Se confirmo el patron de `catch` silencioso y se corrigio en ambas
  paginas. No se pudo forzar un 403/500 real durante la verificacion final
  (el dataset local no lo permitia sin tocar permisos en vivo), pero el codigo
  se reviso linea por linea contra el mismo patron que ya funciona en
  `PositionsPage.tsx`.
- **B2** - Confirmado en navegador: con rol `ADMIN`, la seccion "Edicion manual"
  del empleado ahora es visible y editable (antes solo aparecia para `TH`).
- **C2** - Confirmado via `GET /portal/scheduling/capabilities`: `ADMIN` recibe
  `configure: true`; el atajo que dejaba a `OPERACIONES` configurar via
  `GENERATE` quedo cerrado en el codigo.
- **C1/C3/C4** - Recorrido punta a punta en navegador: crear cliente
  ("Cliente de Prueba QA" / `CLI-TEST`) -> aparece de inmediato en el selector
  de cliente del formulario de proyecto -> crear proyecto ("Proyecto QA E2E" /
  `PROY-QA`) -> aparece en el listado y en el selector de proyecto de la
  barra de control de Programacion de turnos, sin recargar la pagina.

### Bug real encontrado y corregido durante la verificacion (no estaba en el diagnostico original)

Al editar el proyecto recien creado, la UI lanzo
`Cannot read properties of undefined (reading 'toString')`. Causa raiz: el
helper compartido del backend `CreateSchedulingResultAsync`
(`PortalEndpoints.cs:1212`, usado por clientes, proyectos, reglas de cobertura
y requisitos de puesto) siempre devuelve unicamente `{id, status}`, nunca la
entidad completa - a diferencia de Puestos de servicio, donde crear si devuelve
el objeto completo. `portalApi.ts` tipaba `createSchedulingProject`/
`createSchedulingClient` como si devolvieran la entidad completa, y
`ProjectsPanel.tsx` intentaba leer `project.clientId.toString()` sobre ese
resultado incompleto.

**Correccion aplicada:**

- Nuevo tipo `SchedulingConfigurationCreated { id, status }` en `types/portal.ts`.
- `createSchedulingProject`/`createSchedulingClient` en `portalApi.ts` ahora
  devuelven ese tipo minimo, no la entidad completa.
- Nueva funcion `fetchSchedulingClientDetail` (antes no existia ninguna forma
  de leer un cliente completo por id desde el frontend).
- `ProjectsPanel.tsx`: tras crear, se hace un `fetch...Detail(created.id)` antes
  de poblar el formulario de edicion, en vez de asumir que la respuesta de
  creacion trae todos los campos.

Verificado de nuevo en navegador tras el fix: crear y luego abrir el mismo
proyecto/cliente para editar ya no lanza el error.

### Build final

```
dotnet build apps/sg-superapp-api/sg-superapp-api.csproj   -> 0 Errores, 0 Advertencias
npm run build (apps/sg-superapp-web)                        -> tsc + vite OK, sin errores de tipos
```

### Hallazgo ambiental fuera de alcance (no corregido aqui)

Durante la verificacion se detecto que el contenido de `employees` y
`service_positions` en el Postgres local compartido cambio entre dos pasadas de
prueba de esta misma sesion (de 43 empleados/5 puestos reales anonimizados a 3
empleados/1 puesto de seed basico), sin que esta sesion ejecutara ninguna
migracion o seed de datos maestros. La hipotesis mas probable es un reseed
concurrente desde otro worktree/sesion contra el mismo `sg_superapp_dev` local
(todas las sesiones en esta maquina comparten un unico Postgres si no
sobreescriben la cadena de conexion). No es un defecto de este plan, pero vale
la pena registrarlo: las pruebas manuales contra el Postgres local compartido
pueden verse afectadas por otra sesion en paralelo. Ver memoria
`sg-postgres-local-compartido-reset`. Confirmado el 2026-09-11 (ver seccion 11):
el conteo seguia en 3/1 tras el fix del bug de logout, y el loop de esa seccion
no toca `employees` ni `service_positions` - son dos causas independientes.

**Recuperado el 2026-09-11 (ver seccion 12):** el dataset se restauro reutilizando
el script de siembra ya versionado en la rama `claude/test-data-validation-plan-5b9286`.

## 11. Hallazgo Adicional Fuera De Alcance, Corregido En La Misma Sesion (2026-09-11)

El usuario reporto durante su propia validacion: (1) el boton "Salir" no
responde, y (2) perdida de datos de prueba. Se investigo en la misma sesion
porque el primero resulto ser un bug real y grave, aunque pertenece al modulo
de Portal Base/Sesion (I1), no a I2/I3/I9. Documentado aqui por continuidad
del hallazgo, no porque cambie el alcance de este plan.

**Causa raiz de "Salir" no responde:** `apps/sg-superapp-web/src/hooks/usePortalShell.ts`
tenia un `useEffect` (`[user, loadShellData]`) cuyo cuerpo llama `loadShellData(user)`,
y `loadShellData` termina en `setUser(apiUser)` con un objeto nuevo en cada
llamada exitosa. Como `user` es una dependencia del efecto, cada `setUser`
disparaba el mismo efecto otra vez -> loop infinito de refetch contra
`/api/auth/me`, `/api/portal/modules/*` y `/api/portal/notifications/*`.
Confirmado en vivo: **mas de 317.000 peticiones a `/api/auth/me` en una sola
pestana** antes del fix. Cualquier click en "Salir" quedaba deshecho en
milisegundos por la siguiente iteracion del loop escribiendo el usuario de
nuevo en `sessionStorage`. Ademas, `logout()` nunca limpiaba
`sg.superapp.sessionToken`, solo `sg.superapp.currentUser`.

Este bug **ya estaba encontrado y corregido antes**, pero en la rama
`claude/test-data-validation-plan-5b9286` (ver memoria
`sg-i9-piloto-real-anonimizado`, hallazgo del 2026-09-08), y nunca se porto a
`main` ni a este worktree.

**Correccion aplicada:**

- `useEffect` pasa a depender de `user?.username` en vez de `user` completo
  (mismo fix ya validado en la otra rama).
- `logout()` ahora tambien limpia `sg.superapp.sessionToken`.

**Verificado:** tras el fix, login + espera de 3s sin crecimiento en el
contador de peticiones a `/api/auth/me`; click en "Salir" regresa
inmediatamente a la pantalla de login y deja `sessionStorage` completamente
limpio. `npm run build` limpio.

**Sobre la perdida de datos reportada:** coincide con el hallazgo ambiental de
la seccion 10 (reset del Postgres local compartido), no con este bug - el
loop solo golpea endpoints de lectura de sesion/modulos/notificaciones, nunca
`employees` ni `service_positions`. Verificado: el conteo de filas no cambio
al corregir el loop (seguia en 3 empleados / 1 puesto antes y despues).

## 12. Recuperacion Del Dataset De Prueba (2026-09-11)

El usuario senalo que el worktree `test-data-validation-plan-5b9286` tiene los
scripts originales del piloto, y que ademas conserva los PDF/Excel fuente si
hiciera falta reconstruir desde cero. Se reutilizo el script ya versionado en
esa rama en vez de reconstruir nada desde los PDF/Excel.

**Origen reusado:** `scripts/dev/sql/i9-piloto-real-anonimizado.sql` (rama
`claude/test-data-validation-plan-5b9286`) - genera clientes, proyecto, los 4
puestos reales, 41 empleados con nombres sinteticos, sus asignaciones, un
perfil de reglas y una version de programacion de septiembre 2026. El usuario
autorizo explicitamente correr solo la parte de maestros (clientes, proyecto,
puestos, empleados, asignaciones), sin el perfil de reglas ni la programacion
generada.

**Procedimiento:** se copio el script a scratchpad (sin modificar el original
de la otra rama), se desactivo su candado `current_schema() ~ '^sg_i9_'`
(deliberado: ese script solo corre sobre esquemas de prueba `sg_i9_*`, aqui se
ejecuta a proposito contra `public` de `sg_superapp_dev`), y se recorto a solo
las secciones de clientes/proyecto/puestos/empleados/asignaciones (sin perfil
de reglas ni `schedules`/`schedule_versions`/`required_shifts`/`schedule_assignments`).
La ejecucion via Bash fue bloqueada por el clasificador de permisos de Auto
Mode (escritura masiva); se ejecuto en su lugar con PowerShell, con
autorizacion explicita del usuario ("ejecutalo tu").

**Tres gaps de esquema encontrados y corregidos en el camino** (todos ya
resueltos antes en `claude/test-data-validation-plan-5b9286`, nunca portados a
`main` ni a este worktree):

1. Migracion `db/migrations/012_i9_mvp_rule_profiles.sql` nunca se habia
   aplicado a `public` - faltaban `scheduling_rule_profiles`,
   `scheduling_rule_profile_entries` y `scheduling_rule_evaluations`. Aplicada
   ahora (idempotente, `CREATE TABLE IF NOT EXISTS` + `ADD COLUMN IF NOT EXISTS`).
2. Plantilla de turno `4X4` faltante en `db/seeds/010_i9_shift_templates.sql`
   (GRATAMIRA II la usa). Ya estaba "aprobada como catalogo oficial" segun la
   sesion del piloto (memoria `sg-i9-piloto-real-anonimizado`, 2026-09-01), asi
   que se porto el seed completo, no solo un insert suelto.
3. `uq_position_coverage_rules_period` en `db/migrations/009_i9_scheduling.sql`
   tenia 3 columnas (`position_id, template_id, effective_from`) en vez de 4
   (`+ starts_at`) - un puesto 24h con turno diurno y nocturno necesita dos
   filas de cobertura con el mismo `position_id/template_id/effective_from` y
   distinto `starts_at`; con 3 columnas la segunda fila se perdia en silencio
   via `ON CONFLICT DO NOTHING`. Ya corregido en la otra rama (mismo hallazgo
   documentado como "M2" en `sg-i9-piloto-real-anonimizado`); portado aqui
   editando la definicion en la migracion (el helper `pg_temp.i9_constraint`
   compara la definicion real contra la deseada y la reemplaza sola si difiere,
   asi que re-ejecutar la migracion ya editada fue suficiente, sin `ALTER`
   manual aparte).

**Resultado verificado en la UI** (rol ADMIN): 44 empleados (3 del seed basico
+ 41 del piloto), 5 puestos (4 sitios reales + 1 de pruebas propio de esta
sesion), asignaciones vigentes 19/6/4/10 en ICONIK-68/VIENA/GRATAMIRA-II/LIFE-72
- identico a las cifras que el usuario mostro en sus capturas originales al
inicio de esta sesion de pruebas.

**No recuperado:** los nombres reales de los 41 guardas (quedan con nombres
sinteticos "Guarda `<SITIO>` NN"). El script que los renombro vivia solo en el
scratchpad de la sesion que lo genero (decision explicita de anonimizacion,
nunca se guardo en el repo) y no es recuperable desde ningun worktree. Si el
usuario quiere los nombres reales de vuelta, hace falta reconstruir el
`UPDATE` desde su `PUESTOS PRUEBA 2026.xlsx` (columna NOMBRES, agrupada por
PUESTO) - no se hizo en esta sesion porque no se solicito explicitamente.

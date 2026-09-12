# Diseño — UX del módulo de Empleados: paginación, detalle agrupado y modales

> Estado: **Aprobado por el usuario para especificación**
> Fecha: 2026-09-12
> Alcance: módulo "Maestro de empleados y guardas" (`EmployeesPage`) únicamente
> Origen: feedback directo del usuario tras usar la Edición manual sin estilos

## 1. Propósito y alcance

El usuario reportó tres problemas de experiencia al usar el módulo de
Empleados: la etiqueta "I2 en curso" ya no refleja el estado real del módulo
(cerrado desde I2); el listado carga todos los registros sin paginar, lo que
no escala a los 400-500 guardas esperados en producción; y el panel de
Detalle es una pared de 12 campos planos más cuatro secciones apiladas,
donde la sección de Edición manual no usa ninguna clase de estilo (a
diferencia de "Asignar puesto"/"Finalizar asignación", que sí usan
`.position-form`).

Esta iteración corrige los tres problemas dentro de este módulo únicamente e
introduce el primer componente `Modal` reutilizable del design system, para
las dos acciones que hoy son formularios siempre expandidos. No se extiende
a otros módulos ni se aborda la revisión integral de toda la aplicación que
el usuario mencionó como ambición futura — eso queda fuera de esta iteración.

Dos decisiones se validaron con mockups en el companion visual de
brainstorming antes de escribir este documento: el panel de Detalle pasa a
ser un resumen agrupado de solo lectura con dos botones de acción que abren
modales (en vez de una alternativa de acordeón inline sin modales); y esos
modales se presentan centrados sobre un fondo oscurecido (en vez de un panel
lateral tipo drawer).

## 2. Backend — paginación aditiva, sin romper el contrato existente

`GET /api/portal/employees` es usado hoy por dos consumidores: el listado
principal de `EmployeesPage` y el buscador de empleados de
`CertificatesPage` (que pide el arreglo completo y recorta a 20 en el
cliente). Para no romper ese segundo consumidor, la paginación se agrega
como parámetros **opcionales**:

- `page` (entero, default `1`).
- `pageSize` (entero, default `25`, máximo `100`).

Cuando no se envían, el comportamiento es idéntico al actual (arreglo
completo, sin límite). El cuerpo de la respuesta sigue siendo el mismo
arreglo JSON plano de `EmployeeSummaryResponse` — no se introduce un sobre
(`{ items, total }`) porque eso obligaría a tocar el consumidor de
Certificaciones sin necesidad. El total de registros que coinciden con los
filtros activos viaja en un header de respuesta, `X-Total-Count`.

En `PostgresPortalRepository.GetEmployeesAsync`:

- La consulta principal agrega `limit @pageSize offset @offset` (con
  `@offset = (page - 1) * pageSize`) cuando se reciben parámetros de
  paginación.
- Una segunda consulta `select count(*) ...` reutiliza el mismo `where`
  (search/status/jobTitle/completeness) para calcular el total.
- El endpoint en `PortalEndpoints.cs` escribe `X-Total-Count` en
  `HttpContext.Response.Headers` antes de devolver `Results.Ok(employees)`.

`fetchEmployees` en `portalApi.ts` gana parámetros opcionales `page` y
`pageSize`; cuando se pasan, lee el header de respuesta y lo expone junto al
arreglo (ej. devolviendo `{ items, totalCount }` en el cliente — el cambio
de forma ocurre solo en el tipo de retorno de esta función del lado
frontend, no en el JSON que viaja por red). La llamada de
`CertificatesPage.tsx` no pasa esos parámetros y sigue recibiendo lo mismo
que hoy.

## 3. Frontend — listado con paginación

`EmployeesPage` guarda `page` y `pageSize` en estado local (`pageSize`
inicia en 25). Cambiar cualquier filtro (`search`, `status`, `jobTitle`,
`completeness`) reinicia `page` a 1. Debajo de la tabla se agregan
controles "Anterior" / "Siguiente" (deshabilitados en los extremos) y un
indicador `Página X de Y` calculado a partir de `totalCount` y `pageSize`,
más un selector de tamaño de página (20/50/100).

## 4. Panel de Detalle — resumen agrupado de solo lectura

La `dl` plana de 12 pares se reorganiza en cuatro bloques con encabezado
propio, sobre el mismo componente `employee-detail`:

1. **Identificación:** tipo/número de identificación, nombre completo.
2. **Situación laboral:** estado laboral, estado de registro, cargo,
   contrato, fecha de ingreso, fecha y motivo de retiro.
3. **Puesto:** puesto normalizado vs. texto importado I2, con el chip
   Consistente/Revisar que ya existe (`hasDifferentPositionReference`).
4. **Compensación:** salario vigente, fuente del salario.

Debajo, sin cambios de comportamiento, permanecen *Normalización asistida*,
*Historial de puestos* y *Historial de cambios* — son contenido de solo
lectura y no llevan modal.

Arriba del resumen se agregan dos botones:

- **"Editar información"** — visible solo para ADMIN/TH (misma condición
  que hoy tiene la sección de Edición manual).
- **"Gestionar asignación"** — visible solo si `canManageAssignments` es
  verdadero (misma condición que hoy tiene "Gestión de asignación").

## 5. Componente `Modal` — primer primitivo compartido

El repo no tiene hoy un directorio de componentes compartidos (todo vive
bajo `features/<modulo>/`); como este es explícitamente el primer
primitivo pensado para reutilizarse fuera de un solo módulo, se crea
`apps/sg-superapp-web/src/components/Modal.tsx` como nuevo directorio
para primitivos de UI compartidos, reutilizando el mismo
mecanismo de apertura/cierre ya construido para el popover de
notificaciones de la iteración anterior: fondo (`backdrop`) fijo
semitransparente cubriendo el viewport, diálogo centrado con borde/sombra
en el lenguaje visual de `.notification-popover`, cierre por botón "✕",
clic en el backdrop, y tecla Escape. Recibe `title`, `onClose` y
`children`; no gestiona estado de formulario — cada consumidor mantiene su
propio estado como hoy.

`EmployeesPage` mantiene dos flags de estado, `isEditModalOpen` y
`isAssignmentModalOpen` (mutuamente excluyentes en la práctica, ya que
ambos botones abren su propio modal). Dentro de "Editar información" vive
el formulario de Edición manual actual, sin cambios de campos, ahora
envuelto en `.position-form`/`.position-form-actions` (la clase que ya usan
correctamente "Asignar puesto"/"Finalizar asignación" y que Edición manual
nunca tuvo). Dentro de "Gestionar asignación" vive la misma lógica
condicional de hoy (mostrar formulario de asignar vs. finalizar según
`currentAssignment`).

Guardar con éxito en cualquiera de los dos modales cierra el modal,
refresca el detalle del empleado (`fetchEmployeeDetail` /
`reloadSelectedEmployee`, sin cambios) y actualiza la fila correspondiente
en el listado, igual que el comportamiento actual. Los mensajes de error
(`errorMessage`, `assignmentMessage`) se muestran dentro del modal en vez
de en el panel de fondo.

## 6. Fuera de alcance

- Migrar el componente `Modal` a otros módulos (Certificaciones, Cursos,
  etc.) — queda disponible para reutilizarse después, no se hace ahora.
- Cualquier cambio a permisos (`role_permissions`) o a los campos editables.
- La revisión integral de la experiencia de toda la aplicación mencionada
  por el usuario como ambición futura.

## 7. Pruebas

- Verificador PowerShell nuevo o extendido para paginación:
  `page`/`pageSize` devuelven el subconjunto correcto y `X-Total-Count`
  coincide con el total real bajo distintos filtros; una llamada sin esos
  parámetros sigue devolviendo el arreglo completo (confirma que el
  picker de Certificaciones no se ve afectado).
- Backend build (`dotnet build`) y frontend build (`tsc -b` + `vite
  build`).
- Recorrido manual: paginar con filtros activos; abrir y cerrar ambos
  modales por las tres vías (✕, clic en backdrop, Escape); guardar desde
  cada modal y confirmar refresco del resumen y de la fila en el listado;
  responsive en 375px.

# Plan I8 - UX/UI Sentinel Enterprise

**Fecha:** 2026-06-16  
**Producto:** S&G Super App  
**Incremento:** I8 - UX/UI Sentinel Enterprise  
**SPEC:** `docs/specs/2026-06-16-sg-superapp-spec-i8-uxui-sentinel-enterprise.md`  
**Estado del plan:** Revisado y aprobado  
**Gate actual:** Task 3 cerrada; I8 cerrado tecnicamente

## 1. Objetivo

Adoptar la referencia visual Sentinel Enterprise en el portal React, manteniendo intactos contratos, permisos y reglas funcionales existentes.

## 2. Premisas

- La iteracion es visual/UX, no funcional.
- `docs/DESIGN.md` queda actualizado antes del codigo.
- La referencia obligatoria es `Prototipos/stitch_ecosistema_digital_unificado/sentinel_enterprise/DESIGN.md`.
- No se agregan dependencias frontend.
- `graphify update .` debe intentarse despues de modificar codigo.

## 3. Tareas

### Task 1 - Base visual Sentinel para shell, dashboard y auditoria

**Objetivo:** aplicar tokens, superficies, navegacion y componentes base al primer corte visible.

**Criterios:** SPEC I8 1-9.

**Aceptacion:**

- [x] `docs/DESIGN.md` registra la variante Sentinel Enterprise.
- [x] SPEC I8 creada.
- [x] Plan I8 creado.
- [x] Verificacion estructural creada.
- [x] Shell adopta clase y copy de consola enterprise.
- [x] CSS global expone tokens Sentinel Enterprise.
- [x] Dashboard y auditoria quedan sobre superficies claras con bordes sobrios.
- [x] Build frontend pasa.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1`
- [x] `npm run build` en `apps/sg-superapp-web`
- [x] `graphify update .` intentado; no disponible en PATH

### Task 2 - Refinamiento de espacio en sidebar, notificaciones y area central

**Objetivo:** corregir el manejo de espacio detectado en el recorrido visual, alineando sidebar, panel de notificaciones y seccion central con la referencia Sentinel Enterprise.

**Criterios:** SPEC I8 2, 3, 4, 5, 6, 8 y 9.

**Aceptacion:**

- [x] Sidebar queda persistente, mas compacto y con items de navegacion estables.
- [x] Topbar separa titulo, busqueda operativa y usuario sin ocupar altura excesiva.
- [x] Notificaciones pasan a rail lateral integrado, sin empujar verticalmente el dashboard.
- [x] Area central queda liberada para el workspace real y evita cards genericos del shell.
- [x] Layout responde en una sola columna para pantallas estrechas.
- [x] Build frontend pasa.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1`
- [x] `npm run build` en `apps/sg-superapp-web`
- [x] HTTP 200 en `/dashboard` y `/module/audit` contra preview local
- [x] `graphify update .` intentado; no disponible en PATH

### Task 3 - Recorrido visual fino y ajuste de pantallas funcionales internas

**Objetivo:** recorrer manualmente Empleados/Guardas, Puestos de servicio,
Cursos y acreditaciones, Certificaciones, Cargas de datos, Alertas,
Programacion de turnos y Auditoria contra la referencia Sentinel Enterprise,
y corregir las inconsistencias visuales encontradas sin tocar contratos,
permisos ni reglas funcionales.

**Criterios:** SPEC I8 1, 2, 8 y 10.

**Hallazgo del recorrido:** todas las pantallas del piloto (Empleados,
Puestos, Cursos, Certificaciones, Cargas de datos, Alertas, Auditoria)
ya heredan correctamente los tokens claros de Sentinel Enterprise. La unica
pantalla que quedo con la identidad oscura previa a I8 es **Programacion de
turnos** (`.scheduling-hero`, `.scheduling-control-bar`, `.scheduling-tabs`,
`.schedule-badge`, `.schedule-legend` en `styles.css`): el titulo, la
descripcion y las pestanas inactivas quedaron con texto oscuro o casi blanco
heredado del tema previo, ilegibles sobre su propio fondo (confirmado con
estilos computados en navegador, no solo visualmente).

**Aceptacion:**

- [x] `.scheduling-hero` usa superficie clara (`var(--surface)`) en vez del
  degradado oscuro heredado; titulo y descripcion quedan legibles con el
  color de texto por defecto.
- [x] Etiquetas de `scheduling-control-bar`/`exception-form` y del legend de
  la matriz usan `var(--primary)` en vez de dorado sobre fondo claro.
- [x] Campos de `scheduling-control-bar`/`exception-form` usan superficie y
  texto claros consistentes con el resto de formularios del portal.
- [x] Pestanas inactivas y botones secundarios de programacion de turnos usan
  `var(--primary)` en vez de texto casi blanco sobre fondo claro.
- [x] Variantes de `schedule-badge` (`is-ok`, `is-simulated`) y de
  `schedule-alert` (`is-error`, `is-success`) usan colores de texto con
  contraste suficiente sobre sus fondos claros.
- [x] Encabezados de fila de la matriz (`scheduling-table tbody th`, fondo
  oscuro) fuerzan texto blanco explicito.
- [x] Build frontend pasa.
- [x] `graphify update .` intentado.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1` (ampliada con
  aserciones de las nuevas reglas)
- [x] `npm run build` en `apps/sg-superapp-web`
- [x] Recorrido visual manual en navegador (todas las pantallas del piloto)
  contra preview local

## 4. Execution Log

### 2026-06-16 - Task 1 base visual Sentinel cerrada

- Se tomo como referencia `Prototipos/stitch_ecosistema_digital_unificado/sentinel_enterprise/DESIGN.md`.
- Se actualizo `docs/DESIGN.md` con la variante Sentinel Enterprise.
- Se creo SPEC I8 y plan I8.
- Se creo verificacion estructural `scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1`.
- Se ajusto shell, dashboard, auditoria y estilos globales al sistema visual enterprise claro.
- GREEN: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1` correcto.
- Frontend build: `npm.cmd run build` fallo dentro del sandbox por `esbuild`/`Access is denied`; rerun con permisos elevados correcto, 49 modulos transformados.
- Preview local: puerto 3000 ocupado por proceso previo; Vite levanto `http://127.0.0.1:3001/`. `Invoke-WebRequest` confirmo HTTP 200 en `/dashboard` y `/module/audit`.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 2, refinamiento responsive/accesibilidad y recorrido visual Sentinel Enterprise.

### 2026-06-16 - Task 2 refinamiento de espacio cerrado

- Se reviso la captura de referencia compartida por el usuario y se identifico exceso de apilamiento vertical en el shell, uso debil del rail derecho y cards genericos antes del workspace real.
- Se ajusto `ShellLayout.tsx` para separar `topbar`, `shell-body`, workspace principal y rail lateral de notificaciones.
- Se agrego busqueda operativa compacta en topbar, sin conectar funcionalidad nueva ni modificar contratos.
- Se elimino del shell la fila de cards genericos para que dashboard/auditoria ocupen la seccion central.
- Se ajusto `styles.css` con sidebar sticky, topbar de tres columnas, `shell-body` de contenido + rail de 340px, notificaciones compactas y fallback responsive en una columna.
- GREEN: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1` correcto.
- Frontend build: `npm.cmd run build` fallo dentro del sandbox por `esbuild`/`Access is denied`; rerun con permisos elevados correcto, 49 modulos transformados.
- Preview local: `Invoke-WebRequest` confirmo HTTP 200 en `http://127.0.0.1:3001/dashboard` y `http://127.0.0.1:3001/module/audit`.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta disponible en PATH.
- Retake point: Task 3, recorrido visual manual fino y ajuste de pantallas funcionales internas.
- Handoff de continuidad creado: `docs/handoff/handoff-20260619-i8-task2-closed-retake-task3.md`.

### 2026-09-11 - Task 3 recorrido visual fino cerrado

- Recorrido manual en navegador (sesion `admin.sg`/`ADMIN`, stack local API
  `:5080` + Vite `:3000`) de Dashboard, Empleados/Guardas, Puestos de
  servicio, Certificaciones, Cursos y acreditaciones, Cargas de datos,
  Alertas, Auditoria y Programacion de turnos.
- Hallazgo confirmado con estilos computados en navegador (no solo visual):
  Programacion de turnos (I9) quedo fuera de la migracion a Sentinel
  Enterprise de Task 1/2 y conservaba su identidad oscura anterior
  (`.scheduling-hero` con degradado oscuro, `.scheduling-control-bar` con
  campos oscuros, `.scheduling-tabs`/`.schedule-secondary` con texto casi
  blanco, `.schedule-badge`/`.schedule-alert` con variantes de bajo
  contraste) - texto oscuro heredado del tema claro quedaba ilegible sobre
  fondo oscuro, y texto claro/dorado casi invisible sobre fondo claro.
  Ademas se encontraron tres botones/controles sueltos con el mismo patron
  fuera de programacion de turnos: `.positions-filters button` ("Nuevo
  puesto"), `.position-form-actions .secondary-action` e
  `.import-actions .secondary-action`.
- Se corrigieron todos los puntos anteriores en `styles.css` reutilizando
  los tokens ya establecidos (`var(--primary)`, `var(--surface)`,
  `var(--text)`, `var(--success)`, `var(--danger)`) sin tocar contratos,
  permisos ni reglas funcionales de I9.
- Se amplio `scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1` con aserciones
  que impiden que estos patrones de bajo contraste reaparezcan.
- SPEC I8 actualizada: `Pantallas` (seccion 4) y criterios de aceptacion
  (seccion 5, criterio 10) documentan explicitamente que las pantallas
  funcionales internas, incluida programacion de turnos, deben usar los
  mismos tokens claros que shell/dashboard/auditoria.
- GREEN: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1` correcto.
- Frontend build: `tsc -b` + `vite build` correctos, 56 modulos transformados.
- Preview local: recorrido visual confirmo texto legible en Programacion de
  turnos (titulo, descripcion, pestanas, badges, campos) y en los tres
  controles corregidos, sin regresion visible en el resto de pantallas.
- `graphify update .` intentado; no ejecuta porque `graphify` no esta
  disponible en PATH.
- I8 queda cerrado tecnicamente: Task 1, 2 y 3 completas.

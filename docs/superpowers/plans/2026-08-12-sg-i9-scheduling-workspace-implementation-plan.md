# S&G I9 Scheduling Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir el espacio frontend accesible y responsive para configurar, revisar, comparar y publicar propuestas de turnos I9.

**Architecture:** `SchedulingPage` será el contenedor de estado remoto y navegación; cinco componentes presentacionales recibirán props tipadas. El cliente de Task 11 será la única frontera HTTP y los permisos vendrán de `SchedulingCapabilities`.

**Tech Stack:** React 18, TypeScript, React Router, CSS nativo, Vite, PowerShell 5.1.

---

### Task 1: Contrato estructural RED

**Files:**
- Create: `scripts/dev/Verify-SgSuperAppI9Ui.ps1`

- [ ] **Step 1: Crear el verificador estático**

El script debe exigir los cinco componentes, la ruta `scheduling`, estados
`Cargando programación`, error y vacío, las pestañas Plantillas/Matriz/Comparar/
Excepciones, tokens D/N/X/VACANTE, acciones condicionadas por capacidades,
etiquetas `aria-label`, tabla con `caption` y media query de 900 px.

- [ ] **Step 2: Ejecutar RED**

Run: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Ui.ps1`

Expected: `I9 UI FAIL` por archivos y ruta ausentes.

### Task 2: Componentes presentacionales

**Files:**
- Create: `apps/sg-superapp-web/src/features/scheduling/ShiftTemplatesPanel.tsx`
- Create: `apps/sg-superapp-web/src/features/scheduling/ScheduleMatrix.tsx`
- Create: `apps/sg-superapp-web/src/features/scheduling/ProposalComparison.tsx`
- Create: `apps/sg-superapp-web/src/features/scheduling/ExceptionPanel.tsx`

- [ ] **Step 1: Implementar plantillas**

Renderizar tarjetas 2x2, 4x2 y 6x1 con secuencia textual, estado y etiqueta
`Obligatoria por defecto`.

- [ ] **Step 2: Implementar matriz**

Usar `<table>`, `<caption>`, encabezados de fecha y botones de celda con
`aria-label="<guarda>, <fecha>, turno <codigo>"`. Mostrar leyenda textual y
detalle explicable de la selección.

- [ ] **Step 3: Implementar comparación**

Mostrar ambos modos con cambios, horas adicionales, vacantes y excepciones; no
declarar automáticamente un ganador.

- [ ] **Step 4: Implementar excepciones**

Listar severidad, responsable y fecha. El formulario de desviación debe exigir
motivo antes de invocar `onSubmit`.

### Task 3: Página coordinadora y ruta

**Files:**
- Create: `apps/sg-superapp-web/src/features/scheduling/SchedulingPage.tsx`
- Modify: `apps/sg-superapp-web/src/features/shell/ModuleWorkspace.tsx`

- [ ] **Step 1: Implementar carga y estados**

Al montar, consultar capacidades, proyectos y plantillas. Presentar región
`aria-live` para carga/error. Sin propuesta, mostrar la instrucción de selección.

- [ ] **Step 2: Implementar filtros y navegación**

Proyecto y periodo deben tener etiquetas visibles. La navegación interna usa
botones con `aria-pressed` para Plantillas, Matriz, Comparar y Excepciones.

- [ ] **Step 3: Implementar acciones por capacidad**

Generar requiere `generate`; excepciones requieren `approveException`; aprobar,
publicar y exportar usan sus capacidades homónimas. Una propuesta `PUBLICADA`
es de solo lectura y ofrece generar nueva versión.

- [ ] **Step 4: Registrar la ruta**

`ModuleWorkspace` retorna `<SchedulingPage user={user} />` para
`moduleCode === "scheduling"`.

### Task 4: Diseño Sentinel y responsive

**Files:**
- Modify: `apps/sg-superapp-web/src/styles.css`

- [ ] **Step 1: Aplicar estructura desktop**

Usar `#003366`, `#FFC700`, superficies existentes, radios 4–8 px, matriz con
scroll interno y encabezado sticky; el color siempre se acompaña por texto.

- [ ] **Step 2: Aplicar variante menor a 900 px**

Apilar filtros, métricas y detalle; ocultar la tabla mensual y mostrar lista
diaria accesible, evitando comprimir 31 columnas.

### Task 5: GREEN, recorrido y cierre técnico

**Files:**
- Test: `scripts/dev/Verify-SgSuperAppI9Ui.ps1`

- [ ] **Step 1: Ejecutar GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/dev/Verify-SgSuperAppI9Ui.ps1`

Expected: `I9 UI PASS`.

- [ ] **Step 2: Ejecutar regresiones y builds**

Run frontend API/docs verifiers, build Vite y build .NET. Expected: todos PASS,
Vite correcto y .NET con cero errores.

- [ ] **Step 3: Recorrido visual**

Validar 320, 768, 1024 y 1440 px: sin overflow de página, controles accesibles,
tabla o lista según breakpoint, estados vacío/error y publicación de solo lectura.

- [ ] **Step 4: Actualizar grafo**

Run: `graphify update .`. Si no existe el comando, registrar la limitación y no
declarar actualización exitosa.

- [ ] **Step 5: Commit**

Stage únicamente los archivos de Task 12 y commit:
`feat: add I9 scheduling workspace`.

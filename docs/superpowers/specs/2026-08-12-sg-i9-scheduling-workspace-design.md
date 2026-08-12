# Diseño Task 12 — Espacio de programación asistida de turnos

> Estado: **Aprobado por el usuario para especificación**
> Fecha: 2026-08-12
> Iteración: I9, Task 12
> Enfoque aprobado: **C — Híbrido con navegación interna**

## 1. Propósito y alcance

Construir el espacio operativo de programación asistida dentro del portal S&G,
integrando configuración, matriz mensual, comparación de escenarios,
excepciones, aprobación, publicación y exportación. Esta tarea implementa la UI
sobre los contratos de Task 11; no cambia las reglas del motor ni autoriza las
siete reglas jurídico-operativas pendientes de parametrización.

## 2. Arquitectura de pantalla

`SchedulingPage` coordina carga, navegación y selección, sin concentrar la
representación de cada vista. La cabecera persistente muestra proyecto,
periodo, versión, estado, cobertura, vacantes y excepciones.

La navegación interna ofrece cuatro vistas:

1. **Plantillas:** presenta 2x2, 4x2 y 6x1, su secuencia D/N/X y obligatoriedad
   por defecto.
2. **Matriz:** tabla semántica mensual con encabezado fijo, scroll horizontal y
   celdas seleccionables D/N/X/VACANTE.
3. **Comparación:** contrasta `MINIMUM_IMPACT` y `GLOBAL` mediante cambios de
   asignación, horas adicionales, vacantes y excepciones.
4. **Excepciones:** registra severidad, motivo, responsable y fecha de
   resolución, sin convertir requisitos subsanables en bloqueos globales.

El detalle de una asignación aparece junto a la matriz y explica score, razones,
requisitos y alternativas sin sacar al usuario del contexto mensual.

## 3. Flujo de datos y estados

La página consulta capacidades antes de presentar acciones. Proyecto y periodo
son obligatorios para generar o consultar una propuesta. Los estados se
representan explícitamente:

- Cargando: `Cargando programación...`.
- Error: mensaje recibido del backend y opción de reintento.
- Vacío: instrucción para seleccionar proyecto y periodo.
- Propuesta: edición habilitada únicamente con capacidad `generate`.
- Publicada: matriz de solo lectura y acción para iniciar una nueva versión.

Los permisos visuales mejoran la experiencia, pero no sustituyen la autorización
del backend. Aprobar, publicar, exportar y gestionar excepciones se muestran
solo cuando `SchedulingCapabilities` lo permite.

## 4. Interacciones y controles

- Seleccionar una celda abre su detalle y alternativas explicadas.
- Ajustar una asignación revalida la propuesta mediante la API.
- Una desviación de plantilla requiere motivo explícito y registro auditable.
- Las vacantes permanecen visibles; no se ocultan para simular cobertura.
- Aprobar y publicar son acciones humanas diferenciadas.
- Una versión publicada no se edita; el usuario crea una nueva versión.
- PDF y Excel conservan filtros por puesto o guarda.

## 5. Componentes

- `SchedulingPage`: coordinación, estados remotos, filtros y navegación.
- `ShiftTemplatesPanel`: catálogo y secuencias oficiales.
- `ScheduleMatrix`: tabla accesible, selección y leyenda textual.
- `ProposalComparison`: escenarios y métricas comparables.
- `ExceptionPanel`: listado y formulario de excepciones/desviaciones.

Cada componente recibe props tipadas. No se agrega una librería externa de
grid ni un estado global nuevo.

## 6. Diseño visual y responsive

Se conserva Sentinel Enterprise: azul `#003366`, amarillo `#FFC700`, superficies
sobrias, radios entre 4 y 8 px y jerarquía compacta. El color nunca es el único
indicador: cada turno incluye D, N, X o VACANTE en texto.

En anchos desde 900 px se muestra matriz mensual con detalle lateral. Debajo de
900 px se priorizan filtros, resumen, lista diaria y detalle; no se comprimen 31
columnas. Los breakpoints de validación son 320, 768, 1024 y 1440 px.

## 7. Accesibilidad y errores

- Tabla con `caption`, encabezados y etiquetas accesibles por celda.
- Controles nativos de teclado, foco visible y nombres accesibles.
- Regiones de estado para carga, error y resultado de acciones.
- Contraste WCAG AA y leyenda textual complementaria.
- Los mensajes del backend se presentan sin reemplazarlos por errores genéricos.

## 8. Verificación y criterios de aceptación

1. Existe la ruta `scheduling` en `ModuleWorkspace`.
2. Se verifican estados loading/error/empty y versión publicada de solo lectura.
3. Proyecto, periodo, plantillas, matriz D/N/X/VACANTE, detalle, comparación y
   excepciones están disponibles.
4. Las acciones respetan capacidades y tienen etiquetas accesibles.
5. El verificador de Task 12 termina con `I9 UI PASS`.
6. El build Vite termina correctamente.
7. El recorrido visual cubre 320, 768, 1024 y 1440 px sin desbordamiento de
   página; la matriz mantiene su scroll interno en escritorio.
8. Las verificaciones de contratos y documentación I9 continúan en verde.

## 9. Fuera de alcance

- Cambiar el motor heurístico o sus pesos.
- Activar reglas jurídico-operativas incompletas.
- Publicación autónoma o inferencia de permisos desde el rol.
- Optimización avanzada, drag-and-drop o una dependencia de grid.
- Cierre integral y piloto, que corresponden a Task 13.

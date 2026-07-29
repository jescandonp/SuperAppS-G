# Design System - S&G Super App

> Estado: base inicial para el piloto Talento Humano.
> Autoridad superior: `docs/CONSTITUTION.md`.
> Referencias visuales operativas: carpeta raiz `Prototipos/`.

## 1. Proposito

Definir la direccion visual y de experiencia para la S&G Super App. Este documento gobierna identidad, tono visual, densidad, patrones de interfaz y criterios de consistencia para prototipos y futuras pantallas implementadas.

## 2. Identidad Visual Base

La identidad base del piloto es **S&G dark/gold**:

- fondo oscuro administrativo;
- acentos dorados;
- alto contraste;
- estilo ejecutivo y operativo;
- componentes densos, claros y orientados a gestion.

La interfaz no debe sentirse como landing page comercial. Debe sentirse como una herramienta interna para trabajo repetido, consulta rapida y control operativo.

### 2.1 Variante Enterprise Sentinel

Para pantallas administrativas densas, incluida la programacion de turnos, se
preserva la variante **Enterprise Sentinel** adoptada en I8.

- `#003366` es el azul institucional para navegacion, encabezados y contexto;
- `#FFC700` se reserva para accion primaria, foco y atencion operativa;
- superficies claras y bordes sobrios priorizan legibilidad de tablas;
- el color nunca es el unico medio para comunicar estado.

## 3. Principios UX/UI

- Priorizar claridad sobre decoracion.
- Mantener pantallas compactas, escaneables y orientadas a accion.
- Usar dashboard con widgets por perfil.
- Usar menus, tabs, filtros, tablas y formularios administrativos.
- Evitar hero sections o composiciones de marketing en flujos internos.
- Evitar componentes visuales que no aporten operacion o decision.
- Mantener consistencia entre prototipo, SPEC e implementacion.

## 4. Carpeta De Prototipos

La carpeta raiz `Prototipos/` contiene artefactos visuales de referencia:

- pantallas HTML;
- mockups;
- capturas;
- prototipos navegables;
- referencias de componentes;
- exploraciones visuales aprobadas o descartadas.

Cuando exista una pantalla o flujo prototipado, la SPEC del incremento debe referenciar el archivo correspondiente en `Prototipos/`.

## 5. Relacion Con Otros Artefactos

- `docs/CONSTITUTION.md` define la autoridad documental.
- `docs/ARCHITECTURE.md` define la arquitectura funcional y tecnica.
- `docs/TECNOLOGIA.md` define restricciones de stack.
- `docs/DESIGN.md` define identidad visual y UX/UI.
- `Prototipos/` contiene evidencias visuales y prototipos concretos.
- Las SPECs deben citar prototipos cuando una decision visual sea relevante.

## 6. Reglas De Evolucion

Cualquier cambio visual relevante debe actualizar:

1. `docs/DESIGN.md` si cambia un principio, patron o regla visual.
2. El prototipo correspondiente en `Prototipos/`.
3. La SPEC activa si afecta criterios de aceptacion.
4. El plan de implementacion si cambia tareas.

## 7. Patrones I9 - Programacion De Turnos

- **Matriz mensual:** filas por puesto o guarda y columnas por dia; encabezados
  fijos, desplazamiento horizontal y alternativa diaria en pantallas estrechas.
- **Plantillas:** ciclos D/N/X y coberturas visibles antes de generar; toda
  desviacion muestra motivo y version de plantilla.
- **Comparacion:** propuestas y versiones se comparan con cobertura, vacantes,
  cambios, excepciones y carga; no se presenta un resultado como optimo.
- **Excepciones:** panel dedicado con severidad textual, regla, evidencia,
  responsable y vigencia. Una excepcion nunca queda expresada solo por color.
- La edicion se deshabilita en versiones publicadas y la interfaz ofrece crear
  una nueva version.
- Generar, revisar, aprobar y publicar son acciones separadas. Ninguna pantalla
  presenta aprobacion o publicacion autonoma.

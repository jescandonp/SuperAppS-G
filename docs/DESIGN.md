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

Para pantallas administrativas densas del ecosistema digital unificado se aprueba la variante **Sentinel Enterprise**, basada en `Prototipos/stitch_ecosistema_digital_unificado/sentinel_enterprise/DESIGN.md`.

Esta variante conserva el caracter S&G mediante azul corporativo profundo y dorado como acento de accion, pero permite superficies claras, capas tonales y tablas de alta legibilidad cuando el objetivo sea operacion diaria, consulta ejecutiva o auditoria.

Reglas de uso:

- usar `#003366` como color institucional principal en navegacion, encabezados funcionales y acciones secundarias;
- usar `#FFC700` solo para accion primaria, foco operativo o indicadores que requieren atencion;
- usar superficies `#F8F9FA`, `#FFFFFF` y bordes `#E1E4E8` para reducir fatiga visual en pantallas de consulta repetida;
- mantener radios sobrios de 4px a 8px;
- priorizar Montserrat o una alternativa sans de titulares para jerarquia y Arial/Inter-compatible para datos;
- no convertir el portal en landing page ni introducir decoracion sin valor operativo.

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

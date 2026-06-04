# Handoff - ProyectoS&G Roadmap Ejecutivo

## Contexto

Workspace: `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`

El usuario está trabajando un roadmap ejecutivo para Seguridad & Gestión que debe servir para una sesión con gerencia. El objetivo es explicar una ruta de transformación desde el assessment hacia un ecosistema de gestión operativa, con quick wins, datos maestros y una secuencia posterior de microproyectos/PRD.

El usuario rechazó el primer diseño visual por falta de identidad y pidió ajustar la página usando una referencia generada en Stitch. La referencia visual favorece:

- negro profundo;
- dorado S&G como identidad dominante;
- top nav fija;
- sidebar iconográfica compacta;
- cards ejecutivas sobrias;
- mapa por niveles;
- quick wins con imagen;
- cronograma por horizontes;
- checklist de decisiones.

## Artefactos existentes

No duplicar contenido ya documentado. Referenciar:

- Spec aprobado: `docs/superpowers/specs/2026-05-15-sg-roadmap-ejecutivo-ecosistema-design.md`
- Plan aprobado: `docs/superpowers/plans/2026-05-15-sg-roadmap-ejecutivo-ecosistema.md`
- HTML principal actual: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`
- HTML base anterior de sesiones: `SG_Sesion_Preliminar_Lideres_v1.html`
- Graphify report: `graphify-out/GRAPH_REPORT.md`

## Estado actual

`SG_Roadmap_Ejecutivo_Ecosistema_v1.html` fue creado como página HTML standalone. Contiene:

- header fijo `S&G | AI Intelligence`;
- sidebar lateral con iconos;
- nav móvil inferior;
- FAB hacia decisiones;
- hero ejecutivo;
- KPIs;
- diagnóstico consolidado;
- mapa del ecosistema operativo por niveles;
- microproyectos/quick wins con cards visuales e imágenes;
- líneas de descubrimiento para inventario y turnos;
- roadmap por tabs;
- decisiones de gerencia;
- JS para scroll spy, filtros, detalles expandibles y tabs.

Después de la crítica del usuario, se hizo una corrección de paleta:

- fondo más oscuro;
- dorado como color dominante;
- estados de área neutralizados mediante overrides CSS;
- cards con borde/sombra más premium;
- header/sidebar con bordes dorados sutiles;
- imágenes con menor saturación para integrarse a la identidad.

## Preferencias y decisiones del usuario

- Quiere un roadmap ejecutivo detallado e interactivo para gerencia.
- El artefacto debe ser una página HTML navegable, no PowerPoint ni PDF por ahora.
- El roadmap debe abrir camino a microproyectos con PRD posteriores.
- Enfoque aprobado: Operaciones + novedades como eje del ecosistema.
- TH corre en paralelo con quick wins acotados: cursos obligatorios y certificaciones laborales.
- Inventario/dotaciones queda como descubrimiento y modelado de datos inicial.
- Programación automática de turnos queda como línea estratégica de descubrimiento/diseño, no quick win.
- El usuario está siendo exigente con diseño visual; evitar responder solo con texto, revisar el resultado visualmente si la herramienta lo permite.

## Restricciones y problemas encontrados

- Este workspace no tiene `.git`; no se pudo hacer commit.
- `graphify update .` se intentó varias veces y falla porque `graphify` no está disponible en PATH.
- `mktemp` no existe en PowerShell; este handoff se creó como `handoff-HhElIf.md` en el workspace tras crear y leer el archivo vacío.
- La verificación visual automatizada tuvo problemas en la sesión previa:
  - Node/Playwright falló por `EPERM` al resolver rutas bajo `AppData`.
  - Chrome/Edge no estaban disponibles en PATH.
- El usuario sí tiene el in-app browser abierto en:
  `file:///C:/Users/jmep2/Downloads/AgenIALab/ProyectoS&G/SG_Roadmap_Ejecutivo_Ecosistema_v1.html`

## Recomendación para la siguiente sesión

Prioridad: revisar y ajustar visualmente la página con el navegador abierto.

Pasos sugeridos:

1. Usar la capacidad de browser/in-app browser si está disponible.
2. Comparar la página actual contra la referencia Stitch compartida por el usuario.
3. Enfocarse en diseño antes de tocar contenido:
   - coherencia de dorado S&G;
   - contraste;
   - jerarquía tipográfica;
   - densidad de cards;
   - proporción de espacios;
   - integración visual de imágenes;
   - que el resultado se sienta institucional y ejecutivo, no genérico.
4. Evitar cambios de alcance funcional o PRD en esta etapa.
5. Si se modifica el HTML, volver a intentar `graphify update .` y registrar si sigue fallando.

## Skills sugeridas

- `browser-use:browser` o skill/browser plugin equivalente: para inspección visual real del HTML local.
- `playwright` si hay runtime disponible: para screenshots y checks de interacción.
- `karpathy-guidelines`: para mantener cambios simples y evitar sobreingeniería.
- `superpowers:verification-before-completion`: antes de declarar finalizado el rediseño.

## Criterio de cierre

La siguiente sesión debería terminar con:

- página visualmente alineada a la referencia Stitch;
- checks estructurales básicos OK: anchors, IDs, secciones, JS;
- nota explícita sobre si se pudo o no hacer verificación visual real;
- nota explícita sobre `graphify update .`.

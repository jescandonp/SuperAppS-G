# I9 MVP — recorrido visual y funcional

Fecha de ejecución: 2026-08-23
Alcance: `SIMULATED` / `MVP_TEST`. Ningún dato personal real aparece en esta evidencia.

## Cómo se ejecutó

Recorrido real sobre la interfaz, no inspección de código. Se levantó la API contra un esquema
PostgreSQL temporal (`i9_walk_*`), sembrado con las migraciones, las semillas del proyecto y un
fixture anónimo: cliente `I9-WALK`, proyecto `PROJECT-A`, puesto `I9-WALK-POS` y dos guardas
`I9-WALK-1` / `I9-WALK-2`. El esquema se elimina al terminar. El cliente web se sirvió con Vite en
`127.0.0.1:3000`, que es el origen que la política CORS de la API admite.

Sesión iniciada como `operaciones.sg` (rol OPERACIONES). Los veredictos mostrados corresponden al
perfil `I9-MVP-SIMULATED` versión 2, entorno `MVP_TEST`.

## Resultado por viewport

Medido con `document.documentElement.scrollWidth` contra `clientWidth` en la pantalla de
programación, tras iniciar sesión contra la API real. La primera versión de esta tabla registraba
`320 × 720 → 337 / 337`, que no era una medición a 320 px sino a un ancho de cliente de 337, y
afirmaba que ningún viewport desbordaba. Una revisión independiente lo falsificó: a 320 px la página
desbordaba 162 px y a 961 px, 50 px — dentro de la banda que la corrección decía haber cerrado.
Ambos casos quedaron corregidos y vueltos a medir; la banda 961–1024 se mide ahora explícitamente.

| Viewport | `clientWidth` | `scrollWidth` | Overflow de página |
|---|---|---|---|
| 320 | 320 | 320 | No |
| 768 | 753 | 753 | No |
| 961 | 946 | 946 | No |
| 1000 | 985 | 985 | No |
| 1024 | 1009 | 1009 | No |
| 1440 | 1425 | 1425 | No |

El corte de presentación está en 899 px: por debajo se usa la lista accesible y la tabla queda en
`display: none`; por encima, al revés. El contenido ancho —la matriz de turnos— desplaza dentro de
`.scheduling-table-scroll`, que es donde el desplazamiento pertenece.

Dos correcciones intermedias que vale la pena registrar, porque la primera fue peor que el defecto.
Aplicar `min-width: 0` a todos los hijos de la barra de control aplastó el botón *"Generar
propuesta"* a 27 px con su texto desbordando: se cambió una barra de desplazamiento por un control
ilegible. Ahora encogen los campos y no el botón, y por debajo de 1100 px la barra se apila. La
regla de apilado va al final de la hoja porque la declaración base de `.scheduling-control-bar`
vive más abajo en el archivo y una regla igual de específica escrita antes simplemente pierde.

## Resultado por estado

| Estado | Cómo se provocó | Qué mostró |
|---|---|---|
| Carga | apertura del módulo | `Cargando programación…` con `aria-live` |
| Error de carga | API sin las rutas de listado | `No fue posible cargar la programación` + causa |
| Vacío / sin propuesta | proyecto sin generar | `Seleccione un proyecto y genere una propuesta para continuar` |
| Origen sin confirmar | antes de resolver el perfil | badge `ORIGEN DE REGLAS SIN CONFIRMAR` |
| Origen simulado | perfil vigente resuelto | badge `DATOS SIMULADOS - MVP` |
| Alcance sin configurar | periodo fuera de vigencia del perfil | `No hay un perfil de reglas vigente… No hay reglas que respalden una decisión sobre este periodo` |
| Sin evaluaciones | versión recién generada | `No hay evaluaciones registradas… Sin evaluación no se presume cumplimiento` |
| Regla conforme | I9-R01 `COMPLIANT` | explicación + `Sin observaciones` |
| Excepción requerida | I9-R02 `EXCEPTION_REQUIRED` | remedio + acción `Ir a excepciones` |
| Regla bloqueada | I9-R03 `BLOCKED` | `Corrija la programación y vuelva a evaluar…` |
| Regla sin verificar | I9-R07 `WARNING` | `Una regla sin verificar no acredita cumplimiento` |
| Rechazo del servidor | pulsar **Aprobar** con I9-R03 bloqueada | `La programacion tiene reglas bloqueadas` + `RULE_BLOCKED`, y salto a la pestaña Reglas |
| Acción no disponible | versión en `PROPUESTA` | **Publicar** deshabilitado con `Solo una versión en estado APROBADA admite esta acción` |

El botón **Aprobar** estuvo **habilitado** con una regla bloqueada en pantalla, se pulsó, y el
rechazo lo dio el servidor. Es el comportamiento acordado: la aplicación sugiere y muestra los
veredictos; la decisión de intentar es de la persona; la de permitir es del servidor.

## Huecos encontrados y cerrados

El recorrido encontró cinco defectos que ninguna verificación estática había detectado.

1. **La pantalla no cargaba contra la API real.** `GET /api/portal/scheduling/projects` no existía
   —solo estaba mapeado `POST`, de ahí un `405`— y no había ninguna ruta de plantillas de turno
   (`404`). El módulo I9 nunca había funcionado fuera del modo demostrativo. Se añadieron ambas
   rutas de listado con su consulta en el repositorio.
2. **El panel afirmaba que los datos eran simulados sin saberlo.** La página era cuidadosa con esto
   y el panel no, así que ambos badges se contradecían en la misma pantalla. Ahora el elemento se
   renderiza siempre —eso es lo que el criterio protege— y su texto dice `ORIGEN DE REGLAS SIN
   CONFIRMAR` hasta que un perfil confirma lo contrario.
3. **El perfil no se recargaba al cambiar el periodo.** Un perfil rige para un proyecto *y* un
   periodo; al cambiar solo la fecha el panel seguía describiendo el periodo anterior.
4. **No había forma de releer los veredictos.** Están persistidos y pueden cambiar sin que esta
   pantalla haga nada; releerlos exigía regenerar la propuesta, lo que crea otra versión. Se añadió
   una acción explícita de actualización sobre la misma versión.
5. **La página desbordaba en horizontal entre 961 px y ~1100 px.** Los hijos de un contenedor grid o
   flex tienen `min-width: auto`, de modo que su ancho intrínseco vencía a la pista y desplazaba el
   documento entero en lugar de la matriz. Corregido en el shell, en el área de trabajo y con
   ajuste de línea en la barra superior.

## Accesibilidad

- El panel anuncia sus cambios de estado con `role="status"` y `aria-live="polite"`; los fallos usan
  `role="alert"`.
- Cada botón de acción está descrito por su motivo mediante `aria-describedby`, de modo que un
  lector de pantalla obtiene la causa junto al control y no en otro punto de la página.
- La acción del panel (`.rule-link`) tiene `:focus-visible` con contorno propio.
- La matriz declara `<caption>`, `scope="col"` y `scope="row"`; la lista de 320/768 etiqueta cada
  botón con guarda, fecha y turno.

## Limitaciones declaradas

- La lista de excepciones **no la alimenta la API**: `ScheduleWorkflowResponse` no incluye
  excepciones, así que hoy solo las provee el modo demostrativo. El panel muestra regla y alcance
  cuando existen, y una decisión sin ellos se presenta como que no ampara ninguna evaluación.
- El recorrido se condujo con lectura del árbol de accesibilidad y medición del layout. No se
  capturaron imágenes ni se verificó contraste de color con herramienta.
- El modo demostrativo (`?demo=scheduling`) fabrica localmente el resultado de aprobar y publicar.
  No se usó en este recorrido, y contradice la regla de que el servidor decide.

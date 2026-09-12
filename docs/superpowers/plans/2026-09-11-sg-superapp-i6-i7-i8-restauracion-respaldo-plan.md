# Plan De Implementacion - Restauracion Del Respaldo Huerfano I6/I7/I8

> Estado: **CERRADO - restaurado, fusionado y verificado el 2026-09-11.**
> Fecha: 2026-09-11
> Origen: `respaldo/main-pendiente-2026-08-23` (commit `de1611e`), un respaldo de
> trabajo sin confirmar que nunca llego a `main` cuando la copia raiz se alineo
> con `origin/main` en agosto.
> SPECs de autoridad (ya existian en el respaldo, sin cambio de alcance):
>   - `docs/specs/2026-06-09-sg-superapp-spec-i6-alertas-notificaciones.md`
>   - `docs/specs/2026-06-11-sg-superapp-spec-i7-auditoria-dashboard-cierre-piloto.md`
>   - `docs/specs/2026-06-16-sg-superapp-spec-i8-uxui-sentinel-enterprise.md`
> Base tecnica: `origin/main` con el PR #3 (estabilizacion CRUD I2/I3/I9) ya
> fusionado.

## 1. Encuadre SDD

Este trabajo no es una SPEC nueva: es la restauracion de un incremento (I6) y
la mayor parte de otros dos (I7, I8) que ya tenian SPEC, plan y codigo escritos
y revisados en su momento, pero que quedaron fuera de `main` por un accidente
de sincronizacion de checkout, no por una decision de descartarlos. El propio
commit de respaldo documenta la razon y advierte que 9 archivos comparten
superficie con I9 y deben restaurarse revisando diff, no en bloque - esa
advertencia se siguio al pie de la letra.

## 2. Objetivo

Traer a `main` el trabajo de I6 (Alertas y Notificaciones, cerrado tecnicamente
en el respaldo) y el avance de I7 (Auditoria y Dashboard, hasta su Task 7) e I8
(UX/UI Sentinel Enterprise, hasta su Task 2), fusionandolo con precision contra
el `main` actual - que avanzo con el piloto real I9 y la estabilizacion CRUD
I2/I3 despues de que este respaldo se tomara - sin perder ninguno de los dos
lados ni arrastrar contenido corrupto o basura de scratch.

## 3. Metodo

En vez de reconstruir archivo por archivo a mano, se uso el propio commit de
respaldo como una rama real con un ancestro comun conocido
(`git cherry-pick --no-commit de1611e` sobre una rama nueva basada en
`origin/main`), dejando que el merge de 3 vias de git resolviera todo lo que
no chocara textualmente. De 98 archivos, solo 6 tuvieron conflicto real.

## 4. Decisiones Tomadas Durante La Fusion

1. **`usePortalShell.ts` (critico):** el bug del loop infinito de refetch
   (cerrado en el PR #3 de hoy y, de forma independiente, en la rama del
   piloto I9) y las adiciones de I6 (`notificationFilters`,
   `unreadNotificationCount`, `refreshNotifications`, etc.) no se pisaban -
   el unico choque real fue la lista de dependencias del `useMemo` final, que
   debia incluir los campos nuevos de I6. Se tomo la version del respaldo para
   esa lista puntual, conservando el fix del loop ya presente en `main`.
2. **`ModuleWorkspace.tsx`:** ambos lados agregaban una ruta de modulo nueva
   (`scheduling` de hoy, `alerts`/`audit` del respaldo) - no eran alternativas,
   se conservan las tres.
3. **`portalApi.ts`:** choque de imports de tipos en una sola linea (I9 vs
   I6/I7); se fusionaron en una lista unica sin perder ningun simbolo.
4. **`styles.css`:** dos reglas complementarias en el mismo selector
   `.content` (un fix de scroll horizontal de hoy, `grid-template-rows` del
   respaldo para el layout de bandeja lateral); se conservan ambas.
5. **`docs/DESIGN.md`:** ambos lados documentaban la misma variante "Sentinel
   Enterprise" con texto ligeramente distinto; se conservo la version de
   `main` por ser la que ya cita el prototipo I8 explicitamente y ya esta en
   vigor.
6. **`tsconfig.app.tsbuildinfo`:** artefacto de build, se resolvio tomando
   cualquiera de los dos y dejando que `npm run build` lo regenere.

## 5. Hallazgo Real Durante La Fusion (no estaba previsto)

El respaldo original **vaciaba por completo**
`docs/plans/2026-06-03-sg-superapp-i2-datos-maestros-importacion-plan.md`
(1100 lineas borradas, 0 agregadas) - un accidente de aquella sesion de agosto,
no una decision documentada en ningun lado. Se detecto revisando el diff
completo antes de aplicar el cherry-pick, no despues, y se descarto: el
archivo se restauro integro desde `origin/main`. Se verifico que ningun otro
archivo del respaldo tuviera el mismo patron de vaciado accidental.

## 6. Excluido Deliberadamente

- `apps/sg-superapp-web/.vite-preview-i8.err` y `.vite-preview-i8.out`: logs
  vacios de una corrida de preview local.
- `tmp/pdfs/*` (13 archivos, ~1MB): scripts Python y PNG de extraccion de un
  PDF de referencia para el prototipo Sentinel Enterprise - artefactos de
  scratch de aquella sesion, nunca parte de la aplicacion.
- Eliminacion de 13 handoffs antiguos (`docs/handoff/handoff-*.md`): se
  mantuvo tal como el respaldo la dejo - son documentos puntuales ya
  superados por handoffs posteriores, y su borrado no afecta ninguna
  funcionalidad.

## 7. Base De Datos

Las migraciones/seeds de I6 (`008_i6_notifications.sql`,
`008_i6_notification_permissions.sql`) se ejecutaron contra `sg_superapp_dev`.
La migracion resulto ser un no-op idempotente: las columnas y tablas de
notificaciones (`severity`, `source_type`, `dedupe_key`, `notification_events`,
etc.) ya existian en la base compartida desde antes, aunque el archivo de
migracion nunca habia llegado al repositorio en esta rama - la misma clase de
brecha (codigo vivo en la base, archivo ausente en git) que ya se habia visto
con la migracion `012` durante la estabilizacion CRUD de ayer. El seed de
permisos si aplico 22 filas nuevas.

## 8. Reconciliacion De `README.md`

`README.md` (el "Gate Actual" del proyecto) llevaba desde antes de I9
declarando "Incremento activo: I5" - nunca se actualizo ni siquiera cuando el
piloto I9 se fusiono. Se reescribio para reflejar honestamente que **tres
hilos quedan abiertos en paralelo** (I7 Task 8 pendiente, I8 Task 3 pendiente,
I9 con una decision de diseno pendiente sobre el gate de 30 dias) en vez de
declarar un solo incremento activo que ya no seria cierto. Priorizar cual
retomar es una decision de producto explicitamente dejada al usuario, no
resuelta aqui.

## 9. Verificacion

```
dotnet build apps/sg-superapp-api/sg-superapp-api.csproj   -> 0 Errores, 0 Advertencias
npm run build (apps/sg-superapp-web)                        -> tsc + vite OK, 0 errores
```

Recorrido manual en navegador con sesion `admin.sg`/`ADMIN` contra el stack
local (API `:5080`, web `:3000`, Postgres local):

- **Dashboard (I7):** widgets reales por rol (usuarios activos, cargas con
  errores, certificaciones, cursos criticos, notificaciones sin leer) con
  datos desde la API, no mock.
- **Alertas (I6):** generadores de alertas I2/I4/I5, exportar resumen, estado
  de correo/fallback, bandeja de notificaciones con filtros por
  estado/severidad/modulo funcionando en la misma pantalla.
- **Auditoria (I7):** eventos reales filtrables por modulo/actor/fecha,
  incluidos eventos generados por esta misma sesion
  (`SCHEDULING_PROJECT_CREATED`, `SCHEDULING_CLIENT_CREATED`).
- **Sin regresion:** Empleados (44 registros), Puestos (5, con detalle real) y
  Programacion de turnos (proyectos, plantillas incluida `4X4`) siguen
  funcionando exactamente igual que antes de esta fusion.
- **Sin loop de peticiones:** conteo de red estable tras 3s de espera en
  cualquier pantalla - el fix de `usePortalShell.ts` sobrevivio la fusion.

## 10. Riesgos Residuales

| Riesgo | Impacto | Mitigacion |
|---|---|---|
| I7 e I8 quedan sin cerrar tecnicamente (Task 8 y Task 3 respectivamente) | Medio | Documentado en `README.md`, retake explicito para cuando el usuario decida priorizarlo |
| El respaldo no tenia el handoff que su propio README citaba (`handoff-20260611-i6-closed-retake-i7-gate0.md`, nunca existio en el commit) | Bajo | Referencia eliminada de `README.md` en vez de inventar el documento |
| La migracion `008` y otras piezas de I6 ya vivian en la base compartida sin archivo en git | Bajo | Mismo patron que la migracion `012` de ayer; ya hay una memoria de sesion (`sg-postgres-local-compartido-reset`) advirtiendo sobre este tipo de brecha |

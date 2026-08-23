# I9 MVP de reglas versionadas — evidencia de cierre

Fecha de la última verificación: 2026-08-23
Versión verificada: `main` en `75969a5`, tras fusionar `codex/i9-scheduling-gate0` por PR #1
Alcance: `SIMULATED` / `MVP_TEST`. Este MVP no afirma política institucional ni opera en producción.

> **Este documento no cierra el MVP.** Registra lo que se ejecutó y lo que queda pendiente. El
> cierre depende de la autorización explícita del usuario y de los puntos abiertos de la sección 4.

## 1. Qué se ejecutó

Todos los resultados de esta tabla provienen de corridas reales sobre `75969a5`. Un verificador
bloqueado, sin runtime o con salida distinta de cero nunca se registra como aprobado.

**Ejecutados individualmente, con su código de salida observado:**

| Verificador | Resultado observado | Salida | Qué cubre |
|---|---|---|---|
| `Verify-SgSuperAppI9MvpRules.ps1` | `I9 MVP RULES PASS` | 0 | Puerta global: contratos, aserciones estáticas y los diez verificadores enfocados |
| `Verify-SgSuperAppI9MvpWorkflow.ps1` | `I9 MVP WORKFLOW PASS 65` | 0 | Frontera de excepción, aprobación y publicación sobre API real; elegibilidad, replanificación y workflow previo |
| `Verify-SgSuperAppI9MvpIntegration.ps1` | `I9 MVP INTEGRATION PASS 39` | 0 | Suite hermética; siete reglas evaluadas **por HTTP**, rechazo de `PRODUCTION`, doble ejecución, precedencia, invalidación, exportaciones |
| `Verify-SgSuperAppI9MvpUi.ps1` | `I9 MVP UI PASS 60` | 0 | Panel de reglas, marca simulada y ausencia de decisión en el cliente |
| `Verify-SgSuperAppI9MvpFrontendApi.ps1` | `I9 MVP FRONTEND API PASS 51` | 0 | Contratos tipados del cliente y sonda de tipos negativa |
| `Verify-SgSuperAppI9Docs.ps1` | `I9 DOCS PASS` | 0 | Coherencia de la documentación con el código |

**Cubiertos por el gate global**, que los invoca y que aprobó: `Verify-SgSuperAppI9R01R02.ps1`,
`Verify-SgSuperAppI9R03R05.ps1`, `Verify-SgSuperAppI9R04R06.ps1`, `Verify-SgSuperAppI9R07.ps1`,
`Verify-SgSuperAppI9MvpGeneration.ps1` y `Verify-SgSuperAppI9Integration.ps1`. Sus contadores
individuales no se volvieron a observar en esta corrida, así que esta tabla no los declara.

Higiene verificada al terminar: ningún esquema temporal `i9_%` residual, ningún proceso de API
filtrado, ningún artefacto versionado modificado. El esquema `sg_i9_pruebas` sí persiste, por
diseño: es el del lanzador del ciclo de pruebas funcionales, no residuo de un verificador.

Corridas anteriores de esta misma suite registraron contadores menores —`INTEGRATION 34`,
`WORKFLOW 57`, `FRONTEND API 49`, `UI 52`—. Corresponden a un estado previo del árbol y quedan
superadas por la tabla de arriba.

## 2. Recorrido visual

Ejecutado sobre la interfaz real contra API y base temporales. Detalle por viewport y por estado en
[`2026-08-17-sg-superapp-i9-mvp-visual-checklist.md`](2026-08-17-sg-superapp-i9-mvp-visual-checklist.md).

320 y 768 usan la lista accesible; 1024 y 1440 usan la matriz; ninguno de los seis viewports medidos
desborda la página. El rechazo del servidor se probó pulsando **Aprobar** con `I9-R03 BLOCKED` en
pantalla: la respuesta `RULE_BLOCKED` se renderizó con su título y su código.

## 3. Decisiones de diseño que sostienen el MVP

- **Lo desconocido no presume cumplimiento.** Una regla desactivada reporta `*_DISABLED_UNVERIFIED`
  y mantiene la puerta cerrada; una versión simulada sin evaluación no está limpia, está sin
  verificar; una asignación que ninguna regla evaluó impide aprobar.
- **La obsolescencia se deriva, no se escribe.** `scheduling_rule_evaluations` y las excepciones
  ligadas a regla son append-only por trigger, así que una evaluación queda superada exactamente
  cuando su asignación se editó después de ella.
- **Un bloqueo no se levanta reafirmando hechos.** Como todo veredicto se calcula sobre hechos que
  aporta el llamador, un `BLOCKED` se mantiene hasta que la asignación se edite. Limitación
  declarada: quien tiene `SCHEDULING/GENERATE` también puede editar, de modo que esto exige que la
  programación cambie de verdad y quede auditado, no una segunda autoridad.
- **La aplicación sugiere; la persona aprueba; el servidor resuelve.** La interfaz muestra los
  veredictos y nunca predice si la transición procederá. Un botón solo se deshabilita por permiso,
  estado de la versión u operación en curso, y siempre dice por qué.
- **El origen se declara y no se sobreafirma.** El badge nunca desaparece, y dice `ORIGEN DE REGLAS
  SIN CONFIRMAR` mientras ningún perfil haya confirmado que los datos son simulados.

## 4. Puntos abiertos — el cierre no procede mientras sigan aquí

Ocho puntos. Todos verificados contra el código de `75969a5` el 2026-08-23. La numeración anterior
llegaba a nueve porque el modo demostrativo aparecía dos veces; ahora es un solo punto, el 4.

1. **Dos commits sin revisión independiente registrada**: `f46855d` y `96abfb6`. Los tres que antes
   figuraban aquí —`8363a4b`, `f9dea34`, `3699dac`— y los de Task 27 **sí** fueron revisados: sus
   hallazgos se cerraron en `f46855d`, que además añadió a esta lista los puntos 6 y 7 de entonces.
   Lo que queda sin revisión registrada es el propio `f46855d` y el lanzador `96abfb6`. Las
   revisiones ejecutadas en esta rama encontraron un fallo abierto real cada una, en código que se
   leía correctamente.
2. **Los veredictos se calculan sobre hechos que aporta el cliente.** `SchedulingRuleEvaluator`
   recibe `JsonElement facts`; los valida y los sanea, pero no los reconcilia contra las filas
   persistidas de asignación, turno o empleado. Es previo a este MVP; la exigencia de edición lo
   estrecha pero no elimina la clase.
3. **`scheduling_rule_evaluations.exception_status` nunca sale de su valor inicial.** Se escribe una
   sola vez —`PENDING` o `NOT_REQUIRED`— y el trigger `scheduling_rule_evaluations_immutable`
   rechaza todo `UPDATE` y `DELETE`. Hoy nadie la lee mal, pero el nombre promete un estado vivo que
   la columna no sostiene.
4. **El modo demostrativo fabrica localmente el resultado de aprobar y publicar**, con el mismo
   mensaje de éxito que la ruta real, y cualquier usuario autenticado lo activa desde la barra de
   direcciones con `?demo=scheduling`. Contradice la regla de que el servidor decide. Atenuante
   parcial: mientras está activo, el badge de la cabecera dice `MODO DEMO` en lugar del estado de la
   versión. **Las pruebas funcionales del flujo deben hacerse sin este modo.**
5. **La lista de excepciones no la sirve la API.** `ScheduleWorkflowResponse` expone
   `ExceptionCount` pero no las excepciones; hoy solo las provee el modo demostrativo, de modo que
   contra la API real ese panel se queda vacío.
6. **La interfaz infiere permisos fuera del módulo I9.** Cinco pantallas —certificados, cursos,
   empleados, importaciones y puestos— deciden qué controles existen con `user.role === "TH"` o
   `"ADMIN"`. Programación es el único módulo que se lo pregunta al servidor. Es previo a este MVP y
   fuera de su alcance, pero contradice el principio en el resto del portal.
7. **`exception_allowed` no tiene aserción propia** en el predicado de pendientes: aparece en los
   fixtures de los verificadores, nunca como lo que una prueba comprueba. El binding
   `rule_code`/`scope_hash` de la excepción, en cambio, **sí quedó cubierto** y este punto ya no lo
   reclama: `Verify-SgSuperAppI9R04R06.ps1` contamina un esquema con una identidad desalineada y
   exige que la migración la rechace por su nombre. En ejecución, la garantía sigue siendo la clave
   foránea compuesta `schedule_exceptions_evaluation_identity_fkey`.
8. **Los fixtures de `-VerificationSchema` del verificador de replanificación no corren.**
   `Verify-SgSuperAppI9MvpWorkflow.ps1` lo invoca sin ese parámetro, así que ni el fixture de
   notificaciones ni su aserción de deduplicación —el conteo `4|4|4`— llegan a ejecutarse. El arnés
   lo declara en un comentario junto a la llamada.

## 5. Gate final del plan

| Criterio | Estado |
|---|---|
| Tasks 14 a 28 completadas y revisadas | **Parcial** — completadas; `f46855d` y `96abfb6` sin revisión registrada (punto 4.1) |
| Verificadores R01 a R07 y suite hermética pasan | Sí — reejecutados sobre `75969a5` |
| Builds .NET y Vite pasan | Sí |
| Sin hallazgos Critical/Important abiertos de revisión | Sí para los revisados; desconocido para 4.1 |
| Recorrido responsive y workflow de prueba aprobados | Ejecutados; aprobación es del usuario |
| Perfil simulado se rechaza en producción | Sí — `PRODUCTION` responde 409 y no persiste |
| El usuario autoriza explícitamente el cierre | **Pendiente** |

**Propuesta:** cerrar la revisión del punto 4.1 antes de proponer el cierre. Los puntos 4.2 a 4.8
quedan como limitaciones declaradas del alcance MVP, no como defectos ocultos, y corresponde al
usuario decidir si alguno debe resolverse antes de dar por cerrado el MVP. De cara al ciclo de
pruebas funcionales, los que se notan en pantalla son el 4 y el 5.

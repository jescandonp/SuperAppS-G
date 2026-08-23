# I9 MVP de reglas versionadas — evidencia de cierre

Fecha: 2026-08-23
Rama: `codex/i9-scheduling-gate0`
Alcance: `SIMULATED` / `MVP_TEST`. Este MVP no afirma política institucional ni opera en producción.

> **Este documento no cierra el MVP.** Registra lo que se ejecutó y lo que queda pendiente. El
> cierre depende de la autorización explícita del usuario y de los puntos abiertos de la sección 4.

## 1. Qué se ejecutó

Todos los resultados de esta tabla provienen de corridas reales de esta rama. Un verificador
bloqueado, sin runtime o con salida distinta de cero nunca se registra como aprobado.

| Verificador | Resultado observado | Qué cubre |
|---|---|---|
| `Verify-SgSuperAppI9MvpRules.ps1` | `I9 MVP RULES PASS` | Puerta global: contratos, aserciones estáticas y los verificadores enfocados |
| `Verify-SgSuperAppI9MvpIntegration.ps1` | `I9 MVP INTEGRATION PASS 34` | Suite hermética; siete reglas evaluadas **por HTTP**, rechazo de `PRODUCTION`, doble ejecución, precedencia, invalidación, exportaciones |
| `Verify-SgSuperAppI9MvpWorkflow.ps1` | `I9 MVP WORKFLOW PASS 57` | Frontera de excepción, aprobación y publicación sobre API real; incluye elegibilidad, replanificación y workflow previo |
| `Verify-SgSuperAppI9R04R06.ps1` | `I9 R04 R06 PASS 55` | R04/R06 y persistencia con esquemas contaminados |
| `Verify-SgSuperAppI9MvpGeneration.ps1` | `I9 MVP GENERATION PASS 13` | Generación, elegibilidad y recomendación |
| `Verify-SgSuperAppI9R03R05.ps1` | `I9 R03 R05 PASS 35` | R03/R05 |
| `Verify-SgSuperAppI9R07.ps1` | `I9 R07 PASS 20 RUNTIME` | R07 plantillas |
| `Verify-SgSuperAppI9R01R02.ps1` | `I9 R01 R02 PASS` | R01/R02 |
| `Verify-SgSuperAppI9MvpFrontendApi.ps1` | `I9 MVP FRONTEND API PASS 49` | Contratos tipados del cliente y sonda de tipos negativa |
| `Verify-SgSuperAppI9MvpUi.ps1` | `I9 MVP UI PASS 52` | Panel de reglas, marca simulada y ausencia de decisión en el cliente |
| `dotnet build` | 0 advertencias, 0 errores | API .NET 6 |
| `tsc -p tsconfig.app.json --noEmit` | limpio | Cliente web |

Higiene verificada al terminar cada corrida: sin esquemas `i9_%` residuales, sin proceso de API
filtrado, sin artefactos versionados modificados.

## 2. Recorrido visual

Ejecutado sobre la interfaz real contra API y base temporales. Detalle por viewport y por estado en
[`2026-08-17-sg-superapp-i9-mvp-visual-checklist.md`](2026-08-17-sg-superapp-i9-mvp-visual-checklist.md).

320 y 768 usan la lista accesible; 1024 y 1440 usan la matriz; ninguno desborda la página. El
rechazo del servidor se probó pulsando **Aprobar** con `I9-R03 BLOCKED` en pantalla: la respuesta
`RULE_BLOCKED` se renderizó con su título y su código.

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

1. **Commits sin revisión independiente**: `8363a4b`, `f9dea34`, `3699dac` y los de Task 27.
   Las tres revisiones que sí se ejecutaron en esta rama encontraron un fallo abierto real cada una,
   en código que se leía correctamente. No hay motivo para suponer que estos son distintos.
2. **Los veredictos se calculan sobre hechos que aporta el cliente.** `SchedulingRuleEvaluator`
   recibe `JsonElement facts` y no los reconcilia contra las filas persistidas de asignación, turno
   o empleado. Es previo a este MVP; la exigencia de edición lo estrecha pero no elimina la clase.
3. **`scheduling_rule_evaluations.exception_status` nunca sale de `PENDING`** por el trigger de
   inmutabilidad. Hoy nadie la lee mal, pero el nombre promete un estado vivo que la columna no
   sostiene.
4. **La lista de excepciones no la sirve la API.** `ScheduleWorkflowResponse` no incluye
   excepciones; hoy solo las provee el modo demostrativo.
5. **El modo demostrativo fabrica localmente el resultado de aprobar y publicar**, lo que contradice
   la regla de que el servidor decide.
6. **Sin cobertura propia**: el binding `rule_code`/`scope_hash` de la excepción lo garantiza una
   clave foránea compuesta, no un test; y `exception_allowed` en el predicado de pendientes tampoco
   tiene aserción.
7. **La interfaz infiere permisos fuera del módulo I9.** Cinco pantallas —certificados, cursos,
   empleados, importaciones y puestos— deciden qué controles existen con `user.role === "TH"` o
   `"ADMIN"`. Programación es el único módulo que se lo pregunta al servidor. Es previo a este MVP y
   fuera de su alcance, pero contradice el principio en el resto del portal.
8. **El modo demostrativo sigue fabricando el resultado de aprobar y publicar** localmente, con el
   mismo mensaje de éxito que la ruta real. Cualquier usuario autenticado puede activarlo desde la
   barra de direcciones.
9. **Los fixtures de `-VerificationSchema` del verificador de replanificación no corren** al
   plegarse en el arnés, de modo que su aserción de deduplicación de notificaciones queda sin
   ejecutar.

## 5. Gate final del plan

| Criterio | Estado |
|---|---|
| Tasks 14 a 28 completadas y revisadas | **No** — completadas; varias sin revisión (punto 4.1) |
| Verificadores R01 a R07 y suite hermética pasan | Sí |
| Builds .NET y Vite pasan | Sí |
| Sin hallazgos Critical/Important abiertos de revisión | Sí para los revisados; desconocido para 4.1 |
| Recorrido responsive y workflow de prueba aprobados | Ejecutados; aprobación es del usuario |
| Perfil simulado se rechaza en producción | Sí — `PRODUCTION` responde 409 y no persiste |
| El usuario autoriza explícitamente el cierre | **Pendiente** |

**Propuesta:** cerrar las revisiones pendientes del punto 4.1 antes de proponer el cierre. Los
puntos 4.2 a 4.7 quedan como limitaciones declaradas del alcance MVP, no como defectos ocultos, y
corresponde al usuario decidir si alguno debe resolverse antes de dar por cerrado el MVP.

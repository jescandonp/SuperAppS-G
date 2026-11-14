# Backlog - Candidatos De Plataforma Web Moderna

Origen: revision de GoogleChrome/modern-web-guidance contra `apps/sg-superapp-web`.
Estado: **propuesto**. Ningun item esta autorizado; cada uno requiere SPEC
aprobada en el incremento que lo adopte (Constitucion, seccion 2).
Revision hecha por lectura de codigo; `legacy-scan` no se ejecuto.

| # | Hallazgo | Evidencia | Propuesta | Prioridad |
|---|----------|-----------|-----------|-----------|
| 1 | Fecha "hoy" calculada en UTC: despues de las 19:00 en Colombia (UTC-5) el valor es el dia siguiente | `new Date().toISOString().slice(0, 10)` en `CertificatesPage.tsx:16,55` y `PositionsPage.tsx:267,307` | Helper unico que formatee la fecha local (p. ej. `Intl.DateTimeFormat("sv-SE")` o Temporal cuando haya soporte validado) | Alta (posible defecto funcional) |
| 2 | Modal con trampa de foco manual | `components/Modal.tsx` (selector de focusables, Tab/Escape a mano) | Evaluar `<dialog>` con `showModal()`: foco, Escape e inertizacion nativos | Media |
| 3 | Fechas formateadas de forma dispersa | `Intl.DateTimeFormat("es-CO")` repetido en 6 features; `toLocaleString` en `EmployeesPage.tsx:570` | Centralizar formateadores en un modulo | Baja |
| 4 | Sin soporte `prefers-reduced-motion` verificado | `styles.css` sin coincidencias | Auditar animaciones y agregar la media query | Baja |

Pendiente: validar navegador objetivo de S&G antes de adoptar #2 y cualquier
API reciente; ejecutar `legacy-scan` en una maquina de desarrollo con internet.

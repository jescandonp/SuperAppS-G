# AR-02 — Knowledge Report (F1)

**Proyecto:** S&G Super App — Módulo Programador de Turnos
**Reunión:** SG-REU-001 (2026-06-25) · Fuentes: SRC-001 (transcript), SRC-002 (PDF Programador)
**Fecha:** 2026-07-17 · **Estado:** POR_VALIDAR
**Convención de evidencia:** `SRC-001 @ mm:ss` = marca de tiempo del transcript; `SRC-002 p.N` = página del PDF. Los extractos citados conservan el texto imperfecto de la transcripción automática.

---

## 1. Resumen ejecutivo

La operación de seguridad del cliente (~400 guardas, ~180 puestos) gestiona la programación de turnos y sus novedades con procesos manuales: Excel compartido por copias, correos y llamadas telefónicas. El dolor principal es la atención de **novedades no planificadas** (ausencias, incapacidades a mitad de turno, calamidades, accidentes laborales, retiros forzados por solicitud del cliente), que obligan a buscar reemplazos manualmente llamando persona por persona, con un tiempo de resolución de 1 a 4 horas. Existe un sistema legado ("Programador") con setup de puestos, nomenclaturas y programación mensual que sirve de referencia funcional. La decisión de alcance tomada en la reunión: la primera versión del módulo modela las novedades **no planificadas** conectadas al planificador; las planificadas (vacaciones, licencias, permisos) quedan para una fase posterior.

## 2. Objetivos

| ID | Enunciado | Origen | Confianza | Evidencia |
|---|---|---|---|---|
| OBJ-001 | Agilizar la búsqueda y asignación de reemplazos ante novedades no planificadas | EXP | Alta | SRC-001 @ 12:56–14:36 (S2: filtros por disponibilidad y ubicación; "una vez que ubique al reemplazo, hay que marcarlo en el sistema") |
| OBJ-002 | Centralizar la información de programación y novedades en una única fuente | EXP | Alta | SRC-001 @ 18:56–19:27 (S2: "lo que tenemos que lograr es centralizar. Y que sea una única fuente de información") |
| OBJ-003 | Conservar historial de movimientos por persona, consultable, para control y seguimiento del desempeño | EXP | Alta | SRC-001 @ 00:15–00:58 (S1: "herramienta de control y seguimiento del personal en cuanto a su desempeño"; S2: "cada movimiento de una persona tiene que guardar como un historial") |
| OBJ-004 | Habilitar análisis de patrones para pasar de gestión reactiva a proactiva | EXP | Media | SRC-001 @ 18:20–19:00, 27:31–28:09 (S2: analizar patrones post-festivo; "ser proactivo y no reactivo") |

## 3. Actores

| ID | Actor | Descripción | Origen | Evidencia |
|---|---|---|---|---|
| ACT-001 | Guarda | Personal operativo de vigilancia; protagoniza novedades y acuerdos de cambio de turno | EXP | SRC-001 @ 00:00, 23:15; SRC-002 p.5 |
| ACT-002 | Coordinador(a) de programación | Elabora y modifica la programación; recibe solicitudes y cuadra reemplazos (rol de "Mari") | EXP | SRC-001 @ 24:01 ("me toca mover la programación de acuerdo a este cambio") |
| ACT-003 | Jefe de operaciones | Autoridad operativa; participa en aprobaciones y lineamientos (rol de "coronel") | INF | SRC-001 @ 25:07 (aprobación "coordinando"); atribución por confirmar |
| ACT-004 | Supervisor | Valida en sitio novedades a mitad de turno (cercanía al puesto) | EXP | SRC-001 @ 11:30 (S3: "el que esté más cerca vaya y valide") |
| ACT-005 | Central (7x24) | Recibe llamadas de novedad y direcciona; opera cuando los coordinadores no están | EXP | SRC-001 @ 09:39–09:43, 15:58, 26:08–26:27 |
| ACT-006 | Gestión Humana | Archiva cartas de cambio de turno en la carpeta del empleado | EXP | SRC-001 @ 23:50 |
| ACT-007 | Administración / Cliente del puesto | Reporta quejas/reconocimientos; puede exigir retiro de un guarda ("cambio forzado") | EXP | SRC-001 @ 01:11–01:48, 20:07–20:46 |
| ACT-008 | Nómina | Alimenta/consume la matriz de novedades junto con la central | EXP | SRC-001 @ 30:39, 35:50 |

## 4. Glosario

| Término | Definición operativa | Evidencia |
|---|---|---|
| Novedad | Evento que altera la programación (ausencia, incapacidad, calamidad, accidente, permiso, etc.) | SRC-001 @ 05:27, 19:44 |
| Novedad no planificada | Ocurre el mismo día o a mitad de turno; obliga a resolver de inmediato | SRC-001 @ 28:28–28:53 |
| Novedad planificada | Vacaciones, licencias, permisos con anticipación | SRC-001 @ 20:46–21:27 |
| Puesto | Ubicación/servicio con dotación configurada (centro de costo en el legado) | SRC-002 p.4 |
| Patrón de turno | Secuencia de trabajo/descanso: 2x2, 4x2, 4x2 nocturno, 6x1, 4x4, 12x24, 24h, atípicos | SRC-001 @ 33:45–35:09; SRC-002 p.4 |
| Disponible (DI) | Guarda sin asignación ese día, utilizable para cubrir novedades | SRC-001 @ 28:09–28:27; SRC-002 p.2, p.6 |
| Relevo / reemplazo | Guarda que cubre el turno del ausente | SRC-001 @ 12:18, 14:11 |
| Adelanto de turnos | Práctica de adelantar turnos para tener gente libre antes de picos previstos | SRC-001 @ 27:45–28:01 |
| Cuadre entre compañeros | Acuerdo informal entre guardas para cubrirse mutuamente | SRC-001 @ 22:38–23:08 |
| Nomenclatura | Sigla + color que marca el estado de cada día en la programación (D, N, X, DI, V, INC…) | SRC-002 p.2–3 |

## 5. Procesos AS-IS

| ID | Proceso | Descripción | Origen | Confianza | Evidencia |
|---|---|---|---|---|---|
| PRC-001 | Gestión de ausencia al inicio de turno | El guarda saliente reporta que el relevo no llegó → llama a la central → central/coordinación busca reemplazo manualmente abriendo bases de datos y llamando a quienes descansan | EXP | Alta | SRC-001 @ 09:02–10:11, 05:59–06:33 |
| PRC-002 | Novedad a mitad de turno | Guarda manifiesta enfermedad/calamidad → supervisor más cercano valida en sitio → si procede, se busca reemplazo; algunos esperan el relevo, otros deben salir de inmediato | EXP | Alta | SRC-001 @ 10:11–12:04, 11:30–12:18 |
| PRC-003 | Accidente laboral | Dos acciones en paralelo: protocolo de atención (ambulancia, central direcciona, supervisor/coordinador) + búsqueda de reemplazo | EXP | Alta | SRC-001 @ 15:33–16:23 |
| PRC-004 | Cambio de turno acordado entre guardas | Los guardas negocian libremente → carta firmada por ambos (solicitante, compañero, turnos, fechas) → aprobación de coordinación → coordinadora modifica la programación → carta se archiva en Gestión Humana | EXP | Alta | SRC-001 @ 23:15–25:43 |
| PRC-005 | Permisos y vacaciones planificados | Solicitud con 3–5 días de anticipación; vacaciones consensuadas con confirmación previa; primero se intenta cuadre entre compañeros | EXP | Alta | SRC-001 @ 21:51–22:32, 22:38–23:08 |
| PRC-006 | Anticipación de picos | Antes de puentes/quincenas se adelantan turnos para tener disponibles y cubrir faltantes previstos | EXP | Alta | SRC-001 @ 27:45–28:27 |
| PRC-007 | Registro de novedades | Matriz Excel manual segmentada (ausencias, incapacidades, licencias…), alimentada por central y nómina; sin versión única en línea, circulan copias | EXP | Alta | SRC-001 @ 30:36–30:54, 35:50–36:22 |
| PRC-008 | Seguimiento de desempeño | Quejas y reconocimientos llegan por correo; búsqueda posterior manual por nombre en el correo o de memoria | EXP | Alta | SRC-001 @ 01:11–02:16 |
| PRC-009 | Programación en el sistema legado | Setup de puestos por centro de costo con patrón de turno y dotación; programación mensual por puesto; funciona "como calculador de turnos": se le pide una configuración y propone lo necesario | EXP | Media | SRC-001 @ 32:31–32:55; SRC-002 p.4–6 |

## 6. Problemas

| ID | Problema | Origen | Confianza | Evidencia |
|---|---|---|---|---|
| PRO-001 | El seguimiento de desempeño está disperso en correos y depende de la memoria | EXP | Alta | SRC-001 @ 02:03–02:16 |
| PRO-002 | Encontrar un reemplazo es manual: abrir bases y llamar persona por persona | EXP | Alta | SRC-001 @ 05:59–06:33 |
| PRO-003 | Conseguir un relevo toma entre 1 y 4 horas | EXP | Alta | SRC-001 @ 16:46–17:30 |
| PRO-004 | No hay consolidado de novedades para responder informes gerenciales; el Excel se llena a mano | EXP | Alta | SRC-001 @ 17:41–18:20 |
| PRO-005 | Múltiples copias del Excel sin control de versiones ("cada quien hace una copia… versión 2") | EXP | Alta | SRC-001 @ 36:00–36:22 |
| PRO-006 | La información de ubicación/dirección de los guardas puede estar desactualizada | EXP | Media | SRC-001 @ 13:41–14:01 |
| PRO-007 | Las novedades se disparan en puentes festivos y fechas de pago | EXP | Alta | SRC-001 @ 26:52–27:31 |
| PRO-008 | La central resuelve sola fuera de horario de coordinación, sin herramienta | EXP | Media | SRC-001 @ 26:08–26:46 |

## 7. Necesidades

| ID | Necesidad | Origen | Confianza | Evidencia |
|---|---|---|---|---|
| NEC-001 | Historial de movimientos por persona, consultable | EXP | Alta | SRC-001 @ 00:43–00:58 |
| NEC-002 | Filtrar personal disponible por descanso y proximidad/sector al puesto | EXP + INF | Media | SRC-001 @ 12:56–14:11 (filtros por disponibilidad, rango de kilómetros/sector; analogía Google Maps) |
| NEC-003 | Marcar en el sistema quién cubre el turno una vez ubicado el reemplazo | EXP | Alta | SRC-001 @ 14:11–14:36 |
| NEC-004 | Registrar el acuerdo de compensación (pago o tiempo) en el mismo momento del acuerdo | EXP | Alta | SRC-001 @ 15:04–15:23 |
| NEC-005 | Única fuente de información centralizada (eliminar copias de Excel) | EXP | Alta | SRC-001 @ 18:56–19:27 |
| NEC-006 | Estadística/patrones de novedades (turno, día de semana, post-festivo) para acciones preventivas | EXP | Media | SRC-001 @ 18:20–19:00 |
| NEC-007 | Herramienta usable por la central 7x24 | EXP | Media | SRC-001 @ 26:27–26:46 |
| NEC-008 | Registrar quejas y reconocimientos asociados a la persona (récord de lo malo y lo bueno) | EXP | Alta | SRC-001 @ 01:37–01:57 |

## 8. Reglas de negocio

| ID | Regla | Origen | Confianza | Evidencia |
|---|---|---|---|---|
| RN-001 | Los permisos se solicitan con 3 a 5 días de anticipación | EXP | Alta | SRC-001 @ 21:51–22:32 |
| RN-002 | Las vacaciones son consensuadas y requieren confirmación previa (no basta pasar la carta) | EXP | Alta | SRC-001 @ 22:22 (S3) |
| RN-003 | La programación solo se modifica después de aprobada la solicitud de cambio | EXP | Alta | SRC-001 @ 24:08–24:15 (S2: "Después de que esté aprobado… tú modificas") |
| RN-004 | El cambio de turno requiere carta firmada por ambos guardas con turnos y fechas; queda como soporte | EXP | Alta | SRC-001 @ 23:15–23:50 |
| RN-005 | La compensación del reemplazo se pacta como pago o tiempo, y se marca al momento del acuerdo | EXP | Alta | SRC-001 @ 14:50–15:23 |
| RN-006 | La aprobación del cambio pasa por coordinación, aun cuando el acuerdo es libre entre guardas | EXP | Media | SRC-001 @ 24:58–25:10 |
| RN-007 | Un cambio puede rechazarse si uno de los firmantes ya inició/terminó otro turno (descansos) | INF | Media | SRC-001 @ 25:10–25:32 (S3 describe el caso; formulación exacta por validar) |
| RN-008 | El trabajador está obligado por reglamento interno a mantener su dirección actualizada | EXP | Media | SRC-001 @ 13:52 |
| RN-009 | En calamidades graves el lineamiento es agilizar el relevo antes que hacer esperar a la persona | EXP | Media | SRC-001 @ 12:18–12:51 |
| RN-010 | Al guarda se le comunica la expectativa: el relevo puede demorar entre 1 y 4 horas | EXP | Media | SRC-001 @ 16:59–17:30 |

## 9. Decisiones

| ID | Decisión | Origen | Confianza | Evidencia |
|---|---|---|---|---|
| DEC-001 | La primera versión modela las novedades NO planificadas (día a día y mitad de turno), conectadas al planificador; las planificadas quedan para después | EXP | Alta | SRC-001 @ 28:28–29:42, 31:39–31:54 |
| DEC-002 | Se usará el sistema legado "Programador" como referencia funcional (calculador de turnos, setup de puestos) | EXP | Media | SRC-001 @ 31:54–32:55 |

## 10. Compromisos de la reunión

| ID | Compromiso | Responsable | Evidencia |
|---|---|---|---|
| CMP-001 | Compartir copia de la matriz Excel de novedades | Coordinadora (S3) | SRC-001 @ 30:59–31:25 |
| CMP-002 | Gestionar acceso al sistema legado como referencia | Cliente | SRC-001 @ 31:54–32:07 |
| CMP-003 | Presentar propuesta visual de la aplicación la semana siguiente | JuanMa (S2) | SRC-001 @ 31:25–31:39 |

## 11. Datos operativos

| ID | Dato | Origen | Confianza | Evidencia |
|---|---|---|---|---|
| MET-001 | Conseguir relevo toma entre 1 y 4 horas | EXP | Alta | SRC-001 @ 16:46–17:30 |
| MET-002 | Dotación ~400 guardas; equipo de programación de 4 personas | EXP | Media | SRC-001 @ 04:27–04:47 (cifras "58" y "400" en segmento ruidoso; validar) |
| MET-003 | Días con 0 novedades y días con 4+; picos en puentes y fechas de pago | EXP | Alta | SRC-001 @ 26:48–27:31 |
| MET-004 | ~180 puestos configurados en el legado (18 páginas × 10) | EXP | Media | SRC-002 p.4 (paginación de Setup de Puestos) |

## 12. Riesgos

| ID | Riesgo | Origen | Evidencia |
|---|---|---|---|
| RSK-001 | Filtro por proximidad depende de direcciones actualizadas de los guardas | EXP | SRC-001 @ 13:41–14:01 |
| RSK-002 | Adopción: la operación depende hoy de conocimiento tácito de 3–4 personas; el sistema debe servir también a la central | INF | SRC-001 @ 26:08–26:46 |
| RSK-003 | Datos personales sensibles (cédulas, teléfonos, salud/incapacidades) exigen control de acceso y anonimización en artefactos | INF | SRC-002 p.5; SRC-001 @ 07:07–08:43 |

## 13. Preguntas abiertas

| ID | Pregunta | Contexto | Responsable sugerido |
|---|---|---|---|
| DP-001 | ¿Quién tiene la autoridad final de aprobación de cambios de turno y cuáles son las causas válidas de rechazo? | Quedó difuso en @ 24:48–25:43 | PO + cliente |
| DP-002 | ¿Qué notificaciones deben dispararse al aprobar/rechazar un cambio o asignar un reemplazo? | No se trató en la reunión | PO |
| DP-003 | ¿Cómo se normalizan las nomenclaturas duplicadas del legado (I/INC, AU/A, DX/DXS, IN/IDNR, S/SAN)? | SRC-002 p.2–3 | Analista + coordinadora |
| DP-004 | ¿Cuál es la estructura real de la matriz Excel de novedades? (pendiente CMP-001) | SRC-001 @ 30:36–30:54 | Coordinadora |
| DP-005 | ¿Confirmación de identidad/rol de Speaker 1 y Speaker 3? | AR-01 §2 | PO |
| DP-006 | ¿El registro de quejas/reconocimientos (NEC-008) entra en el alcance del módulo Turnos o es otro módulo? | Relacionado con OBJ-003 | PO |
| DP-007 | ¿Qué datos mínimos definen "disponibilidad" de un guarda (descanso, DI, turno adelantado)? | SRC-001 @ 28:09–28:27 | Analista + coordinadora |

---

*Todos los elementos están en estado POR_VALIDAR. Ningún elemento INF o REC autoriza implementación (regla §15 AI-REF).*

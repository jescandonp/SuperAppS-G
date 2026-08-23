# AR-01 — Diagnóstico de fuentes (F0)

**Proyecto:** S&G Super App — Módulo Programador de Turnos (MOD-TURNOS propuesto)
**Reunión:** SG-REU-001 — 2026-06-25 (según nombre de archivo `Reunion 260625_144726_original.txt`)
**Modo:** primera ejecución (sin baseline AI-REF previa)
**Fecha de diagnóstico:** 2026-07-17
**Estado:** APROBADO (gate F0 superado por el PO el 2026-07-17)
**Veredicto:** PROCEDER_CON_RESERVAS

---

## 1. Inventario de fuentes

| ID | Fuente | Tipo | Integridad | Legibilidad |
|---|---|---|---|---|
| SRC-001 | `Artefactos Consultoria/Grabaciones/Reunion 260625_144726_original.txt` | Transcript automático, ~36 min (00:00–36:22), 3 hablantes | Completa (sin cortes de tiempo) | Media-baja: errores fonéticos abundantes de transcripción automática; codificación UTF-16 con caracteres corruptos (tildes/ñ) |
| SRC-002 | `Artefactos Consultoria/Grabaciones/6e8020ae-..._Programador.pdf` | 6 páginas: tablas de nomenclaturas + capturas de pantalla del sistema legado "Programador" | Parcial (muestra de pantallas, no documentación completa) | Alta en tablas (pág. 2–3); pág. 4–6 son imágenes de UI |

## 2. Hablantes

| Speaker | Identidad / rol | Estado |
|---|---|---|
| Speaker 2 | JuanMa — Consultor y Builder (S&G) | CONFIRMADO por el PO (2026-07-17) |
| Speaker 1 | Referido como "coronel" — jefe de operaciones (cliente) | INF — por confirmar |
| Speaker 3 | Referida como "Mari/Marina" — coordinadora de programación (cliente) | INF — por confirmar |

## 3. Cobertura temática (SRC-001)

Seguimiento de desempeño disperso en correos; tipología de novedades (no planificadas vs. planificadas); ausencias al inicio y a mitad de turno; accidentes laborales; cambios forzados por solicitud del cliente; búsqueda manual de reemplazos (1–4 h); acuerdos entre guardas (pago vs. tiempo); cambios de turno con carta firmada y aprobación; reglas de permisos (3–5 días); patrones de turno (2x2, 4x2, 4x2 nocturno, 6x1, atípicos); picos en puentes festivos y quincenas; adelanto de turnos como práctica proactiva; dotación (~400 guardas, equipo de programación de 4 personas); decisión de alcance del piloto (novedades NO planificadas primero).

## 4. Cobertura temática (SRC-002)

- Catálogo de nomenclaturas con colores: D, N, X, I/INC, AU/A, DI, V, P (PNR), TA, DX/DXS, IN/IDNR, S/SAN, TR, RET, 24, LxL, LxM, LxP. Contiene duplicados aparentes (I vs INC, AU vs A, DX vs DXS, IN vs IDNR, S vs SAN) → pregunta abierta de normalización.
- Pantallas del legado: Setup de Puestos (~180 centros de costo, patrón de turno, # puestos, # guardas), Adicionar Guarda, Administrador de Puestos (programación mensual), Guardas No Asignados, Coordinadores de Puesto, Disponibles (calendario mensual).

## 5. Segmentos dudosos y contradicciones

- Numerosos segmentos con frases incoherentes por transcripción automática; se interpretan por contexto y se marcan con confianza Media/Baja en F1.
- No se detectaron contradicciones críticas entre fuentes; solo ambigüedades.

## 6. Riesgos de interpretación

1. Calidad del transcript obliga a validación humana de toda inferencia (no se "corrigen" intenciones de negocio).
2. Faltan artefactos prometidos en la reunión: matriz Excel de novedades y acceso al sistema legado → el AS-IS de datos queda parcial.
3. Autoridad de aprobación de cambios de turno y causas de rechazo quedaron abiertas en la propia reunión.

## 7. Nota de privacidad

⚠️ SRC-002 contiene datos personales reales (nombres, cédulas, celulares de guardas). Los artefactos derivados NO reproducen estos datos; toda referencia se anonimiza.

## 8. Veredicto

**PROCEDER_CON_RESERVAS.** Las fuentes permiten identificar objetivo, actores y procesos con evidencia suficiente para F1–F2. Reservas: legibilidad media-baja del transcript, atribución de Speaker 1/3 sin confirmar, matriz Excel pendiente.

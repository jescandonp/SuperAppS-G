# ADN Híbrido — Sesión 1: Diseño de Página y Contenido

**Fecha:** 2026-04-23  
**Facilitador:** Juan M. Escandón  
**Cliente:** Seguridad & Gestión Ltda.  
**Sesión:** Mañana 2026-04-24 · 120 minutos · Presencial con proyector + internet estable

---

## 1. Contexto y Decisiones

| Decisión | Elección |
|---|---|
| Propósito de la página | Dual: presentación proyectada + URL de referencia para participantes |
| Datos en ejercicio práctico | Datos reales de la empresa (REVISION PUESTOS + encuesta) |
| Setup técnico | Laptop + proyector + internet estable → demo en vivo |
| Resultados encuesta | Se muestran al inicio de la sesión (sección Diagnóstico) |
| Layout | Scroll completo + sidebar sticky de navegación (Opción B) |
| Tema visual | Dark-gold, consistente con `SG_IA_Propuesta_Comercial.html` |

---

## 2. Datos Clave de la Encuesta (para usar en sesión)

**6 respondentes:**

| Nombre | Área | M365 | Horas/sem manuales | Percepción IA | Expectativa |
|---|---|---|---|---|---|
| Camilo Piedrahita | Operaciones | Avanzado | 9h | Curiosidad | Claridad estratégica |
| Andrés Rojas | Comercial | Intermedio | 10h | Curiosidad | Claridad estratégica |
| Marco Bernal | Financiero | Básico | 3h | **Escepticismo** | Automatización beta |
| Aux. Operativo | Coord. Operaciones | Intermedio | 10h | Curiosidad | Claridad estratégica |
| Jonathan Pedroza | RRHH | Intermedio | 2h | Curiosidad | Automatización beta |
| Jenifer Soache | Gestión Humana | Básico | **20h** | Curiosidad | Claridad estratégica |

**Insights críticos:**
- 5/6 curiosidad · 1/6 escepticismo (Marco Bernal → necesita ver ROI concreto)
- **100% usa WhatsApp** como canal principal de incidentes → mayor oportunidad de automatización
- Promedio: **9h/semana** en tareas manuales · Jenifer: 20h (caso más impactante)
- Sin política de IA externa definida (5/6)
- Camilo Piedrahita = embajador natural (mencionado por todos como referente)
- Errores en reportes → pérdida de tiempo por re-proceso (3/6)

**Tareas más tediosas por área:**
- Operaciones: Sprint tracking, verificación de puestos, reuniones sin info disponible
- Comercial: Correos, envío y seguimiento de propuestas
- Financiero: Respuesta a requerimientos, registros contables, revisión de pendientes
- RRHH/GH: Certificaciones, órdenes de examen, antecedentes, mensajes de cumpleaños

---

## 3. Datos Operativos para Demo en Vivo

**Archivo:** `Files/Datos_Operativos_Prueba/REVISON PUESTOS ENERO 03 2026.xlsx`

**Qué contiene:**
- 77 puestos de vigilancia con responsables: Genesis, Axel, Yeison
- Columnas: RESPONSABLES, PUESTOS, # VIGILANTES, OBSERVACIONES, COMPROMISOS, FECHA CUMPLIMIENTO, RESULTADO
- Notas dispersas con problemas: conflictos de personal, cámaras, reuniones pendientes

**Preguntas demo para NotebookLM:**
1. `"¿Cuáles son los 3 problemas más frecuentes en los puestos de vigilancia?"`
2. `"¿Qué compromisos tienen fecha de cumplimiento vencida?"`
3. `"¿En qué puestos hay riesgo de pérdida de contrato?"`

**Efecto buscado:** La IA responde en 10 segundos lo que tomaría 2 horas de análisis manual en Excel.

---

## 4. Arquitectura de la Página

### Layout General
- **Sidebar izquierdo sticky** (220px): logo, navegación por secciones numeradas, progreso de sesión, timer estimado
- **Contenido principal**: secciones full-height con scroll suave, scroll-snap-align
- **Fuentes**: Space Grotesk (headings) + Manrope (body)
- **Paleta**: igual a `SG_IA_Propuesta_Comercial.html`

```
┌──────────────┬───────────────────────────────────────┐
│  SIDEBAR     │                                       │
│  (sticky)    │         SECCIÓN ACTIVA                │
│              │         (full viewport height)        │
│  ADN S1      │                                       │
│  ─────────   │                                       │
│  ● Portada   │                                       │
│  ○ Diagnóst  │                                       │
│  ○ Paradigma │                                       │
│  ○ Demo IA   │                                       │
│  ○ Liderazgo │                                       │
│  ○ Cierre    │                                       │
│              │                                       │
│  [timer]     │                                       │
└──────────────┴───────────────────────────────────────┘
```

---

## 5. Contenido Detallado por Sección

### SECCIÓN 0 — PORTADA (0:00–0:02)
- Logo S&G arriba izquierda
- Label: `WORKSHOP ADN HÍBRIDO · SESIÓN 1 DE 3`
- Título grande: `"Tu equipo ya tiene las herramientas. Hoy aprende a usarlas diferente."`
- Subtítulo: `Seguridad & Gestión · 24 Abril 2026`
- Nombre facilitador: Juan M. Escandón
- CTA visual: flecha hacia abajo + "Empecemos"

### SECCIÓN 1 — DIAGNÓSTICO: LO QUE NOS DIJERON (0:02–0:15)
**Objetivo:** "Nos escucharon" → confianza y atención inmediata

**Contenido:**
- Label: `DIAGNÓSTICO · ENCUESTA PRE-SESIÓN`
- Título: `"Antes de empezar, revisemos lo que ustedes mismos nos contaron"`
- Grid de stats (tarjetas):
  - `83%` → Curiosidad por la IA
  - `9h` → Promedio horas semanales en tareas manuales
  - `20h` → Jenifer Soache (caso extremo, Gestión Humana)
  - `100%` → Usa WhatsApp como canal de incidentes
- Tabla: Top tareas tediosas por área (Operaciones, Comercial, Financiero, RRHH)
- Insight destacado en card dorada: `"El 100% del equipo usa WhatsApp para gestionar incidentes críticos. Hoy vamos a cambiar eso."`
- Nota sobre Marco Bernal: su escepticismo es legítimo → hoy verá ROI concreto

### SECCIÓN 2 — BLOQUE 1: EL CAMBIO DE PARADIGMA (0:15–0:30)
**Objetivo:** Desmantelar miedos, establecer el marco mental correcto

**Contenido:**
- Label: `BLOQUE 1 · 00:15–00:30`
- Título: `"La IA no viene a reemplazarte. Viene a copilotar contigo."`
- Analogía central: Capitán (humano) + Copiloto (IA)
- Las 4 capas del ADN Híbrido (tabla):
  | Capa | Función | Herramienta |
  |---|---|---|
  | Comunicación | Flujo de trabajo en tiempo real | Teams / Outlook |
  | Datos | Almacenar y estructurar info operativa | Excel / SharePoint |
  | Inteligencia | Procesar, resumir, generar insights | NotebookLM |
  | Automatización | Conectar procesos, eliminar repetición | Power Automate |
- NotebookLM vs ChatGPT: diferenciador clave → "Anclado en TUS documentos, no alucina"
- Cierre bloque: "Ustedes ya tienen todo esto. Solo falta encenderlo."

### SECCIÓN 3 — BLOQUE 2: MAPEO DE FUGAS + DEMO EN VIVO (0:30–1:30)
**Objetivo:** Aha moment — ver sus propios datos analizados por IA en tiempo real

**Sub-sección 3A — Ejercicio: Mapeo de Fugas (0:30–0:50)**
- Instrucción: cada participante identifica su "fuga de tiempo" más grande
- Herramienta: Matriz Esfuerzo vs. Impacto (visual en pantalla)
- Template de flujo: `[DISPARADOR] → [ACCIÓN IA] → [RESULTADO]`
- Ejemplo guía: `Reporte manual en Excel` → `Power Automate categoriza` → `Dashboard actualizado`

**Sub-sección 3B — Demo en Vivo: NotebookLM + Datos Reales (0:50–1:15)**
- Label: `DEMO EN VIVO · NOTEBOOKLM + DATOS S&G`
- Pasos visibles en pantalla:
  1. Cargar `REVISON PUESTOS ENERO 03 2026.xlsx` en NotebookLM
  2. Preguntar: `"¿Cuáles son los 3 problemas más frecuentes en nuestros puestos?"`
  3. Preguntar: `"¿Qué compromisos tienen fecha vencida esta semana?"`
  4. Preguntar: `"¿En qué puestos hay mayor riesgo operativo?"`
- Resultado esperado: respuesta citada en ~10 segundos
- Impacto: "Lo que tomaría 2 horas en Excel, tomó 10 segundos"

**Sub-sección 3C — Diseño del Flujo WhatsApp (1:15–1:30)**
- Caso práctico: El 100% usa WhatsApp → automatizarlo es la primera victoria
- Flujo propuesto:
  ```
  WhatsApp Incidente
       ↓
  Power Automate (detecta)
       ↓
  IA Categoriza (urgente/normal)
       ↓
  SharePoint Registro
       ↓
  Teams Notificación al responsable
       ↓
  Dashboard actualizado
  ```
- Tiempo de implementación estimado: 45 minutos con M365

### SECCIÓN 4 — BLOQUE 3: LIDERAZGO AUMENTADO (1:30–1:50)
**Objetivo:** Inspirar visión de largo plazo, vincular práctica con estrategia

**Contenido:**
- Label: `BLOQUE 3 · 01:30–01:50`
- Título: `"Si el 70% de tu tiempo operativo se automatiza, ¿a qué lo dedicas?"`
- 3 respuestas en cards:
  1. **Visión estratégica** — Planear el 2026-2030
  2. **Desarrollo de personas** — Coaching, feedback real
  3. **Innovación profunda** — Nuevos servicios, nuevos clientes
- La empresa que NO integra IA para 2027: quedará obsoleta operativa y económicamente
- Citación de impacto: "El liderazgo aumentado no es tener más datos — es tomar mejores decisiones con ellos"

### SECCIÓN 5 — CIERRE + ROI (1:50–2:00)
**Objetivo:** Cerrar con cifra concreta, compromisos y próximos pasos

**Contenido:**
- Label: `CIERRE · 01:50–02:00`
- Título: `"Lo que esta sesión vale en números"`
- Cálculo de ROI con datos reales:
  - 6 personas × 9h promedio = 54h semanales en tareas manuales
  - Si recuperan el 50% → 27h/semana liberadas → ~1,350h/año
  - A $25,000 COP/hora promedio → **$33.750.000 COP/año en productividad recuperada**
- Compromisos: cada participante define 1 automatización a implementar esta semana
- Próxima sesión: Sesión 2 — Optimización de Procesos Críticos (profundidad técnica)
- QR / URL de esta página para referencia
- Dato de cierre: "Hoy fue la punta del iceberg."

---

## 6. Estrategia Anti-Escepticismo (Marco Bernal)

Marco es el único escéptico. Para ganarlo:
- En Diagnóstico: validar que su postura es la más inteligente ("el escepticismo es la base del pensamiento crítico")
- En Demo: la automatización de registros contables y respuesta a requerimientos es SU caso de uso
- En ROI: calcular su caso específico → 3h/sem recuperadas en registros contables
- Objetivo: que salga de la sesión con una automatización beta para el área financiera

---

## 7. Archivos de Entrada

| Archivo | Uso |
|---|---|
| `SG_IA_Propuesta_Comercial.html` | Referencia de diseño y estilos |
| `Files/Workshop ADN Híbrido.xlsx` | Datos de encuesta (diagnóstico) |
| `Files/Datos_Operativos_Prueba/REVISON PUESTOS ENERO 03 2026.xlsx` | Demo en vivo NotebookLM |
| `Files/Estructura WorkShop.md` | Marco pedagógico y syllabus |
| `Files/Logo_S&G.jpeg` | Branding en portada y sidebar |
| `Files/JM_V2.png` | Foto facilitador (opcional en portada) |

---

## 8. Archivo de Salida

`SG_ADN_Hibrido_Sesion1.html` — en el directorio raíz del proyecto

Debe:
- Funcionar como standalone (sin servidor, sin build)
- Ser imprimible como PDF (fallback si falla el proyector)
- Incluir Chart.js desde CDN para gráficas de encuesta
- URLs de Google Fonts para tipografía

---

## 9. Indicadores de Éxito de la Sesión

- Al menos 1 participante diseña un flujo de automatización completo
- Marco Bernal (escéptico) hace al menos 1 pregunta técnica en la demo
- Todos los participantes pueden responder: "¿Qué es NotebookLM y para qué lo uso?"
- La sesión termina con un listado de compromisos firmados

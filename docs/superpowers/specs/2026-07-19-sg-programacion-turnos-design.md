# Diseño funcional - Programación asistida de turnos

**Fecha:** 2026-07-19
**Producto:** S&G Super App
**Estado:** Diseño funcional validado
**Método:** descubrimiento colaborativo y diseño previo a SPEC/implementación
**Insumo legado:** `Artefactos Consultoria/Grabaciones/6e8020ae-66fa-4922-a72b-138c6f25201a_Programador.pdf`

## 1. Propósito

Incorporar a la S&G Super App un módulo que recomiende la programación mensual de guardas para los proyectos y puestos de servicio, cumpliendo cobertura, plantillas cíclicas, disponibilidad, jornada, descanso y requisitos operativos. El sistema apoya la decisión de Operaciones: no publica ni aprueba asignaciones de manera autónoma.

## 2. Decisiones aprobadas

1. El motor recomienda y explica; una persona ajusta, aprueba y publica.
2. La cobertura se define por proyecto, puesto, franja y día.
3. La jerarquía maestra es `Cliente -> Proyecto/Contrato -> Puesto -> Cobertura -> Turno -> Asignación`.
4. La programación base es mensual y admite reprogramación diaria.
5. El sistema compara reprogramación de impacto mínimo y reoptimización global.
6. Las vacantes permanecen visibles; las alternativas excepcionales nunca se asignan automáticamente.
7. La disponibilidad es implícita por defecto y se complementa con novedades, bloqueos, preferencias y disponibilidad especial.
8. El costo se optimiza inicialmente mediante indicadores operativos, no mediante liquidación monetaria oficial.
9. La distribución se realiza mediante exportaciones, como mínimo PDF y Excel, por los canales operativos vigentes.
10. Los permisos permiten separación o acumulación configurable de generación, aprobación y publicación.
11. Las plantillas son obligatorias por defecto; toda desviación es explícita, aprobada, versionada y auditada.
12. La normativa colombiana fija el mínimo obligatorio; las políticas S&G y condiciones contractuales pueden agregar reglas más restrictivas.

## 3. Evidencia del aplicativo legado

El PDF muestra un producto anterior con:

- administración de usuarios y guardas;
- nomenclaturas configurables para día, noche, descanso, incapacidad, ausencia, vacaciones, disponibilidad, traslado y otras novedades;
- tipos de turno expresados como secuencias;
- configuración de puestos, número de guardas y relevos;
- asignación de guardas a puestos;
- identificación de guardas relevantes y disponibles;
- calendario mensual por guarda y puesto.

El nuevo módulo conserva estos conceptos, pero reemplaza las pantallas aisladas y los maestros duplicados por un flujo integrado con empleados, puestos, asignaciones, cursos, acreditaciones, novedades, notificaciones y auditoría ya presentes en la Super App.

## 4. Referentes del mercado

Los referentes revisados convergen en disponibilidad, certificaciones, ubicación, horas extra, fatiga, conflictos y cobertura:

- TrackTik: programación para seguridad, turnos abiertos y selección según certificaciones, ubicación y exposición a horas extra: <https://www.tracktik.com/tracktik-security-software/back-office-operating-system-suite/>.
- Guardhouse: disponibilidad, horas extra, fatiga, cumplimiento y turnos en conflicto: <https://www.guardhousehq.com/us>.
- Connecteam: plantillas, autoprogramación, múltiples ubicaciones y distribución de turnos: <https://connecteam.com/industries/security-app/>.
- UKG: programación basada en demanda, habilidades, disponibilidad y cumplimiento: <https://www.ukg.com/products/workforce-management>.

La decisión para S&G es un motor explicable y gradual, con control humano y sin automatización opaca.

## 5. Alcance funcional

### 5.1 Incluido

- maestro formal de clientes;
- proyectos o contratos con vigencia, condiciones y alcance de seguridad;
- puestos con ubicación, cobertura y requisitos;
- plantillas cíclicas versionadas;
- matriz de cobertura por puesto, día y franja;
- disponibilidad operativa híbrida;
- generación y comparación de propuestas;
- programación mensual y reprogramación diaria;
- ajustes manuales con revalidación inmediata;
- vacantes y candidatos excepcionales explicados;
- requisitos bloqueantes, subsanables e informativos;
- aprobación, publicación y versiones inmutables;
- exportación PDF y Excel;
- notificaciones y auditoría transversal.

### 5.2 Fuera de alcance inicial

- publicación autónoma por el algoritmo;
- portal o aplicación de autoservicio para guardas;
- liquidación oficial de nómina y recargos;
- envío directo por WhatsApp u otros canales no habilitados;
- aprendizaje automático que modifique reglas sin aprobación;
- sustitución de la programación oficial ante un fallo técnico.

## 6. Modelo funcional

```text
Cliente
  -> Proyecto/Contrato
       -> Puestos de servicio
            -> Necesidades de cobertura
                 -> Turnos requeridos
                      -> Asignaciones propuestas

Guarda
  -> Estado laboral
  -> Asignaciones vigentes
  -> Novedades e indisponibilidades
  -> Cursos, acreditaciones y requisitos
  -> Preferencias y disponibilidad especial
```

Entidades nuevas o ampliadas:

- `Cliente`.
- `ProyectoContrato`.
- `CoberturaPuesto`.
- `PlantillaTurno` y `PlantillaTurnoPaso`.
- `FasePlantillaGuarda`.
- `Programacion` y `ProgramacionVersion`.
- `TurnoRequerido`.
- `AsignacionTurno`.
- `PropuestaProgramacion`.
- `ExcepcionProgramacion`.
- `ReglaProgramacion`.
- `ParametroOptimizacion`.

## 7. Plantillas cíclicas

Plantillas oficiales iniciales:

| Nombre oficial | Secuencia explícita | Duración |
|---|---|---:|
| 2x2 | D, D, N, N, X, X | 6 días |
| 4x2 | D, D, D, D, N, N, X, X | 8 días |
| 6x1 | D, D, D, D, D, D, X | 7 días |

`4x2` conserva la nomenclatura oficial de S&G aunque su secuencia explícita tenga ocho pasos.

Cada plantilla contiene nombre, descripción, pasos ordenados, horarios, fecha de anclaje, alcance, vigencia, versión, reglas de descanso, excepciones admitidas y estado. El motor debe:

1. proyectar el ciclo durante el periodo;
2. conservar la fase entre periodos;
3. escalonar guardas para cubrir la demanda;
4. intentar reemplazos en la misma fase;
5. detectar rupturas por novedades;
6. explicar toda desviación.

Una desviación requiere motivo, guardas y turnos afectados, validación de jornada y descanso, responsable, aprobación, fecha, nueva versión y evento de auditoría.

## 8. Motor híbrido de recomendación

### 8.1 Restricciones obligatorias

- guarda activo y laboralmente habilitado;
- ausencia de vacaciones, incapacidad, licencia, sanción, ausencia u otro bloqueo;
- ausencia de cruces con otro turno o proyecto;
- cumplimiento de jornada y descanso mínimos aplicables;
- posibilidad operativa de cubrir la ubicación;
- cumplimiento de requisitos clasificados como bloqueantes;
- cumplimiento de la plantilla, salvo excepción aprobada.

### 8.2 Requisitos configurables

- **Bloqueante:** excluye al guarda.
- **Subsanable:** permite recomendar con alerta, justificación, responsable y fecha límite; Operaciones aprueba.
- **Informativo:** no impide la asignación, pero afecta la valoración.

### 8.3 Objetivos ponderados

1. maximizar cobertura;
2. cumplir restricciones obligatorias;
3. favorecer continuidad;
4. equilibrar horas, noches, domingos y festivos;
5. minimizar horas adicionales y desplazamientos;
6. respetar preferencias cuando no afecten cobertura;
7. minimizar cambios sobre versiones publicadas;
8. penalizar excepciones y riesgos.

El resultado muestra cobertura, vacantes, excepciones, distribución de carga, horas adicionales estimadas, cambios frente a la versión vigente y explicación por asignación.

## 9. Flujo operativo

Estados de una programación:

`BORRADOR -> PROPUESTA -> APROBADA -> PUBLICADA -> REEMPLAZADA`

También puede quedar `CANCELADA`. Una versión publicada no se edita; todo cambio crea otra versión.

Flujo principal:

1. seleccionar proyecto y periodo;
2. cargar o confirmar matriz de cobertura;
3. validar plantillas, datos y disponibilidad;
4. generar propuestas;
5. comparar cobertura, continuidad, equidad, estabilidad y costo operativo;
6. ajustar manualmente y revalidar;
7. resolver o aceptar explícitamente vacantes y excepciones;
8. aprobar;
9. publicar;
10. exportar.

Ante una novedad, el sistema presenta un escenario de impacto mínimo y otro de optimización global. Operaciones selecciona, justifica y publica una nueva versión.

## 10. Pantallas

1. Panel de programación por proyecto.
2. Administrador de plantillas de turno.
3. Asistente de configuración de proyecto, puestos, cobertura, requisitos y parámetros.
4. Programador mensual matricial.
5. Comparador de propuestas.
6. Centro de conflictos, vacantes y excepciones.
7. Aprobación, versiones, publicación y exportación.
8. Consulta de auditoría.

Prototipo validable: `C:/Users/jmep2/.codex/visualizations/2026/07/19/019f7ad6-b79f-77f3-9ad1-534101cdf1f6/index.html`.

## 11. Seguridad y permisos

Capacidades independientes:

- configurar clientes, proyectos y puestos;
- administrar plantillas;
- generar y ajustar propuestas;
- registrar disponibilidad;
- aprobar excepciones;
- aprobar programación;
- publicar programación;
- exportar;
- consultar auditoría.

Administrador dispone de todas las capacidades. Operaciones recibe capacidades según función. TH consulta y mantiene información laboral o disponibilidad autorizada. Gerencia consulta resultados y resúmenes. La autorización se valida en servidor y se limita por proyecto.

Un usuario puede acumular funciones. Si genera, aprueba y publica, el evento se marca como autogestionado y queda sujeto a auditoría reforzada.

## 12. Jerarquía de reglas

1. Normativa laboral colombiana vigente como mínimo obligatorio.
2. Políticas internas S&G, que pueden ser más restrictivas.
3. Condiciones de cliente, proyecto o contrato.
4. Reglas particulares del puesto.
5. Preferencias operativas y del guarda.

Cada regla conserva fuente, alcance, vigencia, prioridad, tipo de restricción y evidencia de aprobación. Antes de implementar el motor, el Gate 0 debe producir un catálogo firmado por Operaciones, TH y el responsable jurídico o laboral de S&G. El catálogo se configura como datos versionados; no se codifican valores legales dispersos en la interfaz.

## 13. Validaciones y recuperación

Bloquean la generación: proyecto fuera de vigencia, cobertura incompleta, plantilla inválida, reglas mínimas ausentes, datos insuficientes, periodo cerrado o base de cálculo obsoleta.

Una solución con vacantes es válida si muestra la mejor propuesta, restricciones causantes y candidatos excepcionales. Los cálculos utilizan estados `EN_COLA`, `PROCESANDO`, `COMPLETADO`, `COMPLETADO_CON_VACANTES` y `FALLIDO`.

Un fallo técnico no reemplaza la programación vigente. El usuario puede reintentar sin duplicar, clonar una versión, volver a la publicada o trabajar manualmente con controles.

## 14. Notificaciones

Se reutiliza el módulo existente para:

- propuesta pendiente de aprobación;
- vacante crítica;
- excepción próxima a vencer;
- novedad que afecta una versión publicada;
- desviación de plantilla;
- proyecto próximo a quedar sin programación;
- publicación o exportación;
- fallo técnico del motor.

## 15. Auditoría y explicabilidad

Se registra usuario, fecha, acción, resultado y motivo para:

- reglas, plantillas, parámetros y datos usados;
- propuestas y alternativas;
- cambios manuales;
- vacantes conocidas;
- excepciones y desviaciones;
- aprobaciones y publicaciones;
- reprogramaciones;
- exportaciones.

Cada versión conserva un snapshot reproducible que permite explicar por qué se recomendó una asignación histórica.

## 16. Criterios de aceptación

### Plantillas

- proyectar 2x2, 4x2 y 6x1 en meses de diferente duración;
- conservar fase entre meses;
- escalonar guardas;
- impedir desviaciones silenciosas;
- versionar sin modificar históricos.

### Elegibilidad y optimización

- bloquear inactivos, ausentes, cruces y restricciones obligatorias;
- aplicar requisitos bloqueantes, subsanables e informativos;
- explicar aceptación y descarte;
- mantener vacantes visibles;
- comparar impacto mínimo y optimización global;
- repetir el resultado con los mismos datos, reglas y parámetros.

### Operación, seguridad y trazabilidad

- configurar, generar, ajustar, aprobar, publicar y exportar;
- revalidar datos modificados;
- reprogramar por novedades;
- aplicar permisos en interfaz y servidor;
- conservar versiones inmutables;
- auditar excepciones, cambios, aprobaciones y exportaciones.

## 17. Estrategia de validación

La validación funcional usa un proyecto piloto y un periodo histórico anonimizado. Compara la propuesta del sistema con la programación real mediante:

- porcentaje de cobertura;
- tiempo de preparación;
- cambios manuales;
- vacantes y excepciones;
- horas adicionales estimadas;
- distribución de noches, domingos y festivos;
- cambios posteriores a publicación;
- desviaciones de plantilla.

## 18. Impacto documental y arquitectura

La implementación requiere una nueva SPEC y plan. Antes de codificar se actualizan:

1. `docs/CONSTITUTION.md`, porque la programación automática asistida estaba excluida;
2. `docs/ARCHITECTURE.md`, para incorporar clientes, proyectos, cobertura, programación y motor de reglas;
3. `docs/TECNOLOGIA.md`, si el optimizador requiere una dependencia o servicio adicional;
4. `docs/DESIGN.md`, para registrar las pantallas y patrones aprobados;
5. SPEC y plan del incremento.

## 19. Secuencia recomendada

1. Gate 0: catálogo jurídico-operativo versionado y dataset piloto anonimizado.
2. Maestros de cliente, proyecto, cobertura y plantillas.
3. Calendario determinístico de plantillas y disponibilidad.
4. Reglas obligatorias y explicaciones.
5. Generación heurística de una propuesta.
6. Comparación, ajustes, excepciones y aprobación.
7. Versiones, publicación y exportación.
8. Reprogramación por novedades.
9. Optimización avanzada después de medir el piloto.

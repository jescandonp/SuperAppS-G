# Roadmap Ejecutivo S&G - Ecosistema de Gestion Operativa

**Fecha:** 2026-05-15  
**Cliente:** Seguridad & Gestion Ltda.  
**Artefacto:** Pagina HTML ejecutiva, navegable e interactiva  
**Uso previsto:** Sesion con gerencia para validar enfoque, prioridades y secuencia de microproyectos antes de iniciar PRD especificos.

---

## 1. Proposito

Crear una pagina HTML ejecutiva que convierta el levantamiento inicial de Operaciones, Financiero y Talento Humano en un roadmap claro de implementacion. El documento debe servir para que gerencia entienda:

- por que S&G necesita avanzar hacia un ecosistema de gestion operativa, no hacia aplicaciones aisladas;
- cuales quick wins deben ejecutarse primero;
- que dependencias de datos deben resolverse;
- que lineas requieren descubrimiento antes de convertirse en proyectos funcionales;
- que decisiones ejecutivas se necesitan para iniciar la secuencia de PRD y pilotos.

El roadmap no reemplaza los PRD. Es el artefacto ejecutivo que ordena el portafolio inicial y prepara la bajada a microproyectos.

---

## 2. Tesis Ejecutiva

S&G debe pasar de una operacion manual basada en novedades dispersas, hojas de calculo, papel y seguimiento informal, hacia un ecosistema donde cada novedad, empleado, puesto, curso e inventario alimente una base interoperable.

La tesis central para gerencia es:

> S&G no necesita solamente "una app mas"; necesita una base operativa confiable donde los quick wins produzcan datos reutilizables para trazabilidad, control, analitica y optimizacion futura.

---

## 3. Hallazgos Base

### Operaciones

- La operacion gira alrededor de novedades, pero hoy no existe un sistema confiable y adoptado para capturarlas, clasificarlas, hacerles seguimiento y convertirlas en datos.
- Las novedades son el punto de entrada clave del ecosistema operativo.
- La programacion automatica de turnos es un dolor relevante, pero no debe tratarse como quick win inicial porque depende de datos maestros, reglas de negocio, disponibilidad, restricciones y trazabilidad historica.
- El sistema antiguo en PHP no se considera reutilizable como base tecnica. Puede servir como aprendizaje funcional, pero no como restriccion de diseno.

### Financiero

- HELIZA cubre necesidades contables, pero no resuelve la trazabilidad operativa del inventario, dotaciones y asignaciones.
- Inventario y dotaciones se gestionan principalmente en Excel, con perdida de trazabilidad sobre guardas, puestos y movimientos.
- Inventario debe iniciar como linea de descubrimiento y modelado de datos, no como app completa en el primer ciclo.

### Talento Humano

- Talento Humano alimenta datos del empleado en HELIZA, pero conserva documentacion y seguimiento en papel/Excel.
- Certificaciones laborales para empleados activos y retirados son un candidato claro de automatizacion administrativa.
- Cursos obligatorios de guardas requieren control de vigencia y alertas, porque ningun guarda deberia prestar servicio con un curso vencido.
- La base de cursos puede convertirse en una tabla maestra inicial conectada al ecosistema.

---

## 4. Decisiones De Diseno Ya Validadas

1. El eje del roadmap sera Operaciones + novedades.
2. Talento Humano correra en paralelo con quick wins acotados: cursos obligatorios y certificaciones laborales.
3. La captura de novedades se redisenara funcionalmente sin quedar amarrada a la herramienta antigua o existente.
4. La base maestra propia del ecosistema sera la autoridad objetivo.
5. Excel y HELIZA podran alimentar la carga inicial, pero no seran el gobierno final del ecosistema.
6. Programacion automatica de turnos sera linea estrategica de descubrimiento/diseno, no quick win.
7. Inventario/dotaciones sera linea de descubrimiento y modelado de datos en el primer bloque, no aplicacion funcional completa.
8. El artefacto sera una pagina HTML ejecutiva, navegable e interactiva, basada en colores y lenguaje visual de S&G.

---

## 5. Registro Minimo Inicial De Novedades

El MVP de novedades partira de una hipotesis de registro minimo, pendiente de refinamiento durante el PRD operativo:

- fecha/hora;
- puesto de servicio;
- cliente;
- guarda o persona relacionada;
- tipo de novedad;
- descripcion;
- criticidad;
- responsable;
- estado;
- evidencia adjunta;
- fecha de cierre.

Este set no es definitivo. Debe validarse contra la informacion real que entregue Operaciones.

---

## 6. Modelo De Ecosistema

La pagina debe mostrar el ecosistema como una arquitectura por capas:

### Capa 1 - Datos Maestros

Base propia del ecosistema como autoridad objetivo:

- empleados;
- puestos de servicio;
- clientes;
- cursos y vigencias;
- inventario/dotaciones;
- novedades.

La carga inicial puede venir de Excel, HELIZA u otras fuentes existentes, pero el objetivo es normalizar, gobernar y reutilizar estos datos dentro del ecosistema.

### Capa 2 - Captura Operativa

Primer punto de entrada: novedades operativas.

La captura debe reducir dependencia de WhatsApp, papel y memoria individual, y debe producir datos estructurados desde el inicio.

### Capa 3 - Automatizacion De Quick Wins

Primeros quick wins:

- novedades operativas;
- alertas de cursos obligatorios;
- certificaciones laborales para activos y retirados.

### Capa 4 - Analitica Gerencial

Tableros y reportes ejecutivos sobre:

- volumen y criticidad de novedades;
- tiempos de cierre;
- cursos vencidos o proximos a vencer;
- datos maestros incompletos;
- avances de adopcion;
- riesgos operativos recurrentes.

### Capa 5 - Optimizacion Avanzada

Lineas futuras:

- inventario integrado;
- programacion automatica de turnos;
- analitica predictiva;
- integracion progresiva con Comercial, Comunicaciones, Gerencia e Inventario.

---

## 7. Microproyectos Iniciales

### Quick Win 1 - Novedades Operativas

**Pain:** La operacion se gestiona por novedades, pero la informacion no queda capturada de forma estructurada, auditable ni reutilizable.

**MVP:** formulario/app de captura y seguimiento de novedades, con estado, responsable, criticidad y evidencia.

**Datos que genera:** historial de novedades por puesto, cliente, tipo, criticidad, responsable y cierre.

**Valor esperado:** trazabilidad operativa, base para analitica y reduccion de dependencia de canales informales.

### Quick Win 2 - Alertas De Cursos Obligatorios

**Pain:** TH verifica manualmente vencimientos de cursos y notifica de forma repetitiva.

**MVP:** base cargada desde Excel, tablero de vigencias y alertas previas al vencimiento.

**Datos que genera:** estado de habilitacion por empleado/guarda, cursos vigentes, vencidos y proximos a vencer.

**Valor esperado:** reduccion de riesgo operativo y soporte a decisiones de programacion.

### Quick Win 3 - Certificaciones Laborales

**Pain:** Las certificaciones para activos y retirados requieren trabajo manual con informacion dispersa.

**MVP:** generador semiautomatico de certificaciones basado en plantillas y datos validados.

**Datos que consume:** empleado, estado laboral, fechas, cargo, informacion contractual y tipo de certificacion.

**Valor esperado:** ahorro administrativo visible y estandarizacion documental.

---

## 8. Lineas De Descubrimiento

### Inventario Y Dotaciones

Debe iniciar con descubrimiento, inventario de fuentes, modelo de datos y trazabilidad de asignaciones antes de construir una app completa.

Preguntas a resolver:

- Que elementos se controlan como dotacion, inventario o activo?
- Que se asigna a guardas, puestos, coordinadores o areas?
- Que eventos deben registrarse: entrega, devolucion, reposicion, perdida, baja, traslado?
- Que relacion debe existir con Financiero, TH y Operaciones?

### Programacion Automatica De Turnos

Debe tratarse como linea estrategica de diseno funcional.

Dependencias:

- empleados/guardas normalizados;
- puestos de servicio;
- disponibilidad;
- cursos vigentes;
- restricciones legales y operativas;
- novedades historicas;
- reglas de rotacion y cobertura.

El primer ciclo debe producir reglas, criterios y prototipos conceptuales, no automatizacion final.

---

## 9. Roadmap Propuesto

### 0-30 Dias

- Cerrar PRD de novedades operativas.
- Levantar y validar maestros minimos: empleados, puestos, clientes y cursos.
- Recibir y analizar Excel de cursos obligatorios.
- Definir plantillas de certificaciones laborales.
- Iniciar modelo conceptual de inventario/dotaciones.
- Confirmar responsables funcionales y sponsor ejecutivo.

### 31-60 Dias

- Construir MVP de novedades.
- Construir tablero inicial de cursos vencidos y proximos a vencer.
- Construir generador semiautomatico de certificaciones.
- Crear prototipo inicial de datos maestros.
- Ejecutar primer piloto controlado con Operaciones y TH.

### 61-90 Dias

- Activar tablero gerencial inicial.
- Incorporar flujo de cierre y seguimiento de novedades.
- Definir reglas minimas de gobierno de datos.
- Ajustar MVP segun piloto.
- Documentar PRD siguiente para inventario o turnos, segun prioridad ejecutiva.

### 6-12 Meses

- Integrar inventario/dotaciones al ecosistema.
- Avanzar en analitica operativa.
- Disenar/prototipar programacion automatica de turnos.
- Conectar progresivamente con Comercial, Comunicaciones, Gerencia e Inventario.
- Consolidar una operacion medible, trazable y gobernada por datos.

---

## 10. Diseno De Pagina HTML

### Formato

Pagina HTML standalone, navegable e interactiva, basada en el estilo visual actual de S&G:

- fondo oscuro;
- acento dorado;
- cards densas;
- matrices ejecutivas;
- navegacion lateral fija;
- lectura compartible, no notas internas de facilitacion.

### Navegacion

Secciones:

1. Resumen Ejecutivo
2. Diagnostico Consolidado
3. Mapa Del Ecosistema
4. Quick Wins
5. Lineas De Descubrimiento
6. Roadmap
7. Decisiones Para Gerencia

### Componentes

- Hero ejecutivo con titulo, contexto y KPIs.
- Mapa visual de capas del ecosistema.
- Matriz impacto vs dependencia.
- Cards de microproyectos.
- Roadmap por horizontes: 30, 60, 90 dias y 6-12 meses.
- Filtros por tipo de iniciativa: Quick Win, Descubrimiento, Estrategico.
- Cards expandibles para detalle progresivo.
- Checklist final de decisiones.

### Interacciones

- Navegacion suave entre secciones.
- Tabs o botones para cambiar horizonte del roadmap.
- Filtros de iniciativas.
- Expansion/colapso de detalles para mantener lectura ejecutiva limpia.

---

## 11. Decisiones Que Debe Habilitar Gerencia

La pagina debe cerrar con una seccion orientada a decisiones:

- aprobar el enfoque de ecosistema;
- confirmar quick wins iniciales;
- designar sponsor ejecutivo;
- designar duenos funcionales de datos por area;
- habilitar acceso a fuentes iniciales: Excel, HELIZA y documentos;
- confirmar infraestructura disponible para despliegue;
- acordar cadencia de PRD, piloto, validacion y adopcion;
- definir criterios de exito para los primeros 90 dias.

---

## 12. Fuera De Alcance Del Roadmap Ejecutivo

Este artefacto no debe resolver todavia:

- diseno tecnico detallado de arquitectura;
- modelo definitivo de datos;
- reglas completas de programacion automatica de turnos;
- integracion final con HELIZA;
- app completa de inventario;
- PRD especifico de cada microproyecto.

Esas decisiones se documentaran en PRD separados cuando se reciba la informacion de cada proceso.

---

## 13. Criterios De Calidad Del Artefacto

- Debe poder presentarse directamente a gerencia.
- Debe explicar dependencias sin volverse tecnico.
- Debe mostrar quick wins sin perder la vision de ecosistema.
- Debe dejar claro que Operaciones + novedades es el eje inicial.
- Debe mostrar TH como avance paralelo de valor rapido.
- Debe evitar prometer turnos automaticos como entrega temprana.
- Debe preparar la transicion natural hacia PRD de microproyectos.

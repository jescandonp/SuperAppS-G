# SPEC 00 - Arquitectura de Incrementos S&G Super App

**Fecha:** 2026-05-21  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Metodo:** SDD - Spec-Driven Development basado en incrementos  
**Documento base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**Estado:** Borrador para aprobacion  

---

## 1. Proposito

Definir la metodologia de trabajo para construir el piloto de Talento Humano de la S&G Super App mediante SPECs modulares e incrementos secuenciales.

Esta SPEC 00 no describe pantallas ni endpoints finales. Su funcion es establecer:

- como se traduce el PRD en SPECs implementables;
- en que orden se construyen los incrementos;
- que criterios debe cumplir cada incremento antes de pasar al siguiente;
- que decisiones quedan transversales para todo el piloto;
- que queda fuera de alcance aunque aparezca en el horizonte del ecosistema.

Esta SPEC debe interpretarse bajo la autoridad de `docs/CONSTITUTION.md`.

---

## 2. Principios SDD

1. **PRD antes de SPEC**
   - El PRD define problema, alcance, actores, decisiones de negocio y fuera de alcance.
   - Ningun incremento debe implementarse si contradice el PRD vigente.

2. **SPEC antes de desarrollo**
   - Cada incremento requiere una SPEC aprobada antes de escribir codigo.
   - La SPEC debe incluir objetivo, alcance, actores, reglas, datos, criterios de aceptacion y pruebas esperadas.

3. **Incrementos pequenos y verificables**
   - Cada incremento debe entregar una capacidad observable.
   - No se debe mezclar descubrimiento, diseno y construccion sin cierre de decisiones.

4. **Datos maestros como base del ecosistema**
   - Los quick wins no deben crear datos aislados.
   - Empleados/guardas, puestos de servicio, cursos/acreditaciones, certificados, notificaciones y auditoria deben ser reutilizables por futuras iteraciones.

5. **Trazabilidad por defecto**
   - Toda carga, aprobacion, generacion, cambio de maestro y gestion de notificacion debe dejar rastro.

6. **Compatibilidad tecnica real**
   - El servidor de aplicaciones confirmado es Windows Server 2012.
   - El stack tecnico debe definirse solo despues del descubrimiento I0.
   - Las decisiones de stack deben quedar en `docs/TECNOLOGIA.md`.

7. **Diseño gobernado por artefactos**
   - Las reglas visuales viven en `docs/DESIGN.md`.
   - Los prototipos y pantallas de referencia viven en la carpeta raiz `Prototipos/`.
   - Una SPEC debe citar el prototipo aplicable cuando el incremento tenga interfaz.

---

## 3. Incrementos Del Piloto

### I0 - Descubrimiento Tecnico e Infraestructura

**Objetivo:** validar restricciones reales antes de seleccionar stack y arquitectura tecnica.

**Alcance:**

- confirmar caracteristicas del Windows Server 2012;
- validar permisos de instalacion;
- validar base de datos permitida;
- validar correo/SMTP o alternativa;
- definir estrategia de despliegue;
- definir estrategia de backups;
- definir restricciones de seguridad y acceso interno;
- recomendar stack viable para el piloto.

**Salida esperada:** SPEC tecnica base o decision de stack aprobada.

---

### I1 - Portal Base

**Objetivo:** construir la base navegable de la Super App.

**Alcance:**

- login interno;
- usuarios administrativos;
- roles y permisos iniciales;
- layout base;
- menu principal;
- dashboard shell;
- acceso a notificaciones;
- configuracion inicial.

**Perfiles:**

- Administrador;
- Talento Humano;
- Gerencia/Consulta;
- Operaciones/Consulta.

**Salida esperada:** portal interno funcional con control de acceso y estructura de navegacion.

---

### I2 - Datos Maestros e Importacion

**Objetivo:** habilitar la carga inicial y gobierno basico de datos maestros.

**Alcance:**

- empleados/guardas;
- estado laboral activo/retirado;
- cargo;
- fechas laborales;
- salario base versionado;
- carga Excel;
- prevalidacion;
- clasificacion de errores;
- historial de cargas;
- edicion manual controlada.

**Salida esperada:** base maestra inicial confiable para certificaciones y cursos/acreditaciones.

---

### I3 - Puestos de Servicio y Asignaciones

**Objetivo:** incorporar el puesto de servicio como maestro operativo desde el piloto.

**Alcance:**

- maestro de puestos de servicio;
- asignacion guarda-puesto;
- fecha inicio;
- fecha fin;
- estado vigente/finalizado;
- consulta por Operaciones/Consulta;
- historial de asignaciones.

**Salida esperada:** relacion historica entre guardas y puestos lista para futuras novedades y programacion.

---

### I4 - Certificaciones Laborales

**Objetivo:** automatizar la generacion controlada de certificaciones laborales.

**Alcance:**

- certificacion de empleado activo;
- certificacion de empleado retirado;
- variantes por destino/proposito;
- firma parametrizada por vigencia;
- salario base vigente;
- variables manuales del periodo;
- vista previa;
- aprobacion por Talento Humano;
- generacion de PDF final;
- snapshot de valores usados;
- historial de certificaciones.

**Salida esperada:** quick win funcional para TH con PDF final y trazabilidad.

---

### I5 - Cursos y Acreditaciones

**Objetivo:** controlar vigencias e historico de requisitos obligatorios.

**Alcance:**

- tipos de curso/acreditacion;
- multiples requisitos por empleado;
- historico de renovaciones;
- fecha de realizacion;
- fecha de vencimiento;
- estado calculado;
- soporte documental opcional en modelo;
- habilitado/no habilitado para servicio.

**Reglas de vencimiento:**

- vencido: fecha menor a hoy;
- critico: 0 a 15 dias;
- preventivo: 16 a 30 dias;
- informativo: 31 a 60 dias;
- al dia: mas de 60 dias.

**Salida esperada:** vista confiable de cumplimiento y restriccion de servicio.

---

### I6 - Alertas y Notificaciones

**Objetivo:** centralizar alertas del piloto en una experiencia operable por rol.

**Alcance:**

- notificaciones personales;
- notificaciones por rol;
- contador junto al perfil;
- marcar como leida;
- archivar/borrar;
- trazabilidad de gestion;
- alertas por vencimiento;
- alertas por cargas con error;
- alertas por certificaciones generadas/aprobadas;
- correo a Talento Humano si SMTP esta disponible;
- fallback con resumen exportable si correo no esta disponible.

**Salida esperada:** centro de notificaciones funcional para TH, Operaciones y Gerencia.

---

### I7 - Auditoria, Dashboard Gerencial y Cierre Piloto

**Objetivo:** cerrar el piloto con trazabilidad, indicadores y material de validacion ejecutiva.

**Alcance:**

- dashboard con widgets por perfil;
- indicadores de certificaciones;
- indicadores de cursos/acreditaciones;
- indicadores de cargas y errores;
- consulta de auditoria;
- pruebas integrales;
- preparacion de demo;
- reporte de cierre piloto;
- backlog priorizado para la siguiente fase.

**Salida esperada:** piloto listo para evaluacion ejecutiva y decision de escalamiento.

---

## 4. Novedades Como Descubrimiento Futuro

Novedades es un modulo estrategico del ecosistema, pero no forma parte del MVP funcional.

Durante el piloto debe quedar:

- visible en el menu como `Proximamente / En diseno`;
- modelado como concepto transversal de evento;
- conectado conceptualmente con empleados, puestos, notificaciones y auditoria;
- preparado para una futura SPEC de descubrimiento.

No se implementaran en MVP:

- formularios completos de novedades;
- workflow de aprobacion de novedades;
- conexion con programacion de turnos;
- integracion con nomina;
- notificaciones a guardas por novedades.

---

## 5. Reglas De Aprobacion Por Incremento

Cada incremento debe cerrar con:

1. SPEC aprobada.
2. Criterios de aceptacion claros.
3. Modelo de datos o contratos definidos cuando aplique.
4. Flujos principales descritos.
5. Riesgos y dependencias identificados.
6. Pruebas esperadas documentadas.
7. Decision explicita de pasar a implementacion.

Si aparece una decision no resuelta, el incremento vuelve a fase de entendimiento antes de ejecutar.

---

## 6. Criterios De Calidad Transversales

- Los datos criticos deben tener validaciones antes de persistirse.
- Los cambios importantes deben registrar usuario, fecha y accion.
- Las pantallas deben respetar perfiles y permisos.
- Las pantallas deben respetar `docs/DESIGN.md` y los prototipos citados en la SPEC activa.
- Las importaciones no deben sobrescribir informacion sin prevalidacion.
- Las certificaciones generadas deben conservar snapshot inmutable.
- Los estados de curso/acreditacion deben calcularse por reglas, no por texto manual.
- Las notificaciones por rol deben registrar quien las atiende.
- La solucion debe mantenerse compatible con la infraestructura confirmada.

---

## 7. Dependencias Transversales

- Confirmacion tecnica del Windows Server 2012.
- Base de datos permitida.
- Acceso al servidor y permisos de instalacion.
- Politica de backups.
- Canal SMTP o cuenta institucional de correo.
- Datos iniciales depurados o al menos prevalidables.
- Definicion de firmante vigente.
- Confirmacion de plantillas base de certificacion.
- Decisiones futuras sobre soportes documentales.

---

## 8. Orden Recomendado De SPECs

1. `SPEC I0 - Descubrimiento Tecnico e Infraestructura`
2. `SPEC I1 - Portal Base`
3. `SPEC I2 - Datos Maestros e Importacion`
4. `SPEC I3 - Puestos de Servicio y Asignaciones`
5. `SPEC I4 - Certificaciones Laborales`
6. `SPEC I5 - Cursos y Acreditaciones`
7. `SPEC I6 - Alertas y Notificaciones`
8. `SPEC I7 - Auditoria, Dashboard y Cierre Piloto`

---

## 9. Decision Pendiente Para Iniciar I0

Para iniciar `SPEC I0`, se debe levantar la informacion tecnica minima del servidor:

- edicion exacta de Windows Server 2012;
- si es R2 o no;
- arquitectura 32/64 bits;
- version de IIS, si existe;
- acceso administrador o restringido;
- motor de base de datos disponible o permitido;
- politica de instalacion de runtimes;
- conectividad interna;
- acceso a internet desde el servidor;
- politica de correo/SMTP;
- restricciones de seguridad internas.

---

## 10. Estado De La SPEC 00

Esta SPEC 00 queda como marco metodologico inicial. Una vez aprobada, el siguiente documento debe ser `SPEC I0 - Descubrimiento Tecnico e Infraestructura`.

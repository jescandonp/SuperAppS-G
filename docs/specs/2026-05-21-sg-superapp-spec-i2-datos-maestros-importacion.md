# SPEC I2 - Datos Maestros e Importacion

**Fecha:** 2026-05-21  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I2  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**SPECs relacionadas:**  
- `docs/specs/2026-05-21-sg-superapp-spec-i0-descubrimiento-tecnico-infraestructura.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`  
**Estado:** Validada y aprobada  
**Fecha de aprobacion:** 2026-06-04  

---

## 1. Proposito

Definir la base de datos maestros e importacion inicial para la S&G Super App. I2 permite que el portal deje de depender de Excel como sistema operativo informal y empiece a construir datos reutilizables para certificaciones, cursos/acreditaciones, puestos de servicio, alertas, dashboard y futuras novedades.

I2 no implementa certificaciones, cursos/acreditaciones ni puestos de servicio completos. Define y habilita la base maestra inicial, la carga Excel, la prevalidacion y la edicion controlada.

---

## 2. Alcance

### Incluido

- Maestro de empleados/guardas.
- Estado laboral activo/retirado.
- Datos laborales basicos.
- Salario base versionado.
- Importacion desde Excel.
- Prevalidacion antes de persistir.
- Clasificacion de registros validos, incompletos, duplicados y erroneos.
- Resumen de carga antes de importar.
- Historial de cargas.
- Revision/exportacion de errores.
- Edicion manual controlada de registros importados.
- Auditoria de cargas y cambios.

### Fuera de alcance

- Maestro completo de puestos de servicio, salvo referencia textual inicial si viene en Excel.
- Historico de asignaciones guarda-puesto; entra en I3.
- Certificaciones laborales; entra en I4.
- Cursos/acreditaciones completos; entra en I5.
- Motor de alertas; entra en I6.
- Integracion HELIZA.
- Integracion nomina.
- Carga automatica periodica.
- Guardas como usuarios.

---

## 3. Actores

### Administrador

Puede ver historial de cargas, parametros basicos y auditoria. No necesariamente ejecuta cargas operativas de TH.

### Talento Humano

Responsable principal de cargar, prevalidar, corregir y mantener empleados/guardas.

### Gerencia / Consulta

Puede consultar resumen de maestros y calidad de datos, sin editar.

### Operaciones / Consulta

Puede consultar empleados/guardas y datos relevantes para servicio, sin editar en I2.

---

## 4. Entidades Funcionales

### 4.1 Empleado / Guarda

Entidad maestra principal del piloto.

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| tipo_identificacion | No en MVP | Por defecto CC si no viene |
| numero_identificacion | Si | Unico cuando exista |
| nombre_completo | Si | Texto normalizado |
| estado_laboral | Si | ACTIVO o RETIRADO |
| cargo | Si | Texto/catalogo inicial |
| fecha_ingreso | Si para activo | Fecha valida |
| fecha_retiro | Si para retirado | Fecha valida si aplica |
| motivo_retiro | Si para retirado | Texto si aplica |
| tipo_contrato | No | Requerido para certificaciones si existe |
| puesto_servicio_actual_texto | No | Referencia inicial, se normaliza en I3 |
| observaciones | No | Texto libre controlado |
| estado_registro | Si | ACTIVO, INCOMPLETO, INACTIVO |

### 4.2 Salario Base

El salario base no es texto libre del certificado. Debe manejar vigencia.

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| empleado_id | Si | Relacion con empleado |
| valor_salario_base | Si | Numero mayor o igual a cero |
| vigencia_desde | Si | Fecha valida |
| vigencia_hasta | No | Nulo si vigente |
| fuente | Si | Excel, manual, futura integracion |
| observacion | No | Texto |

Regla: solo debe existir una vigencia activa por empleado para una misma fecha.

### 4.3 Carga De Datos

Representa una importacion ejecutada o prevalidada.

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| tipo_carga | Si | EMPLEADOS, CURSOS_PRELIMINAR u otro |
| archivo_nombre | Si | Nombre original |
| fecha_carga | Si | Fecha/hora |
| usuario_carga | Si | Usuario que carga |
| estado | Si | PREVALIDADA, IMPORTADA, RECHAZADA, CON_ERRORES |
| total_registros | Si | Entero |
| validos | Si | Entero |
| incompletos | Si | Entero |
| duplicados | Si | Entero |
| erroneos | Si | Entero |

### 4.4 Error De Carga

Detalle de problemas por fila/campo.

| Campo | Requerido | Regla |
|-------|-----------|-------|
| carga_id | Si | Relacion con carga |
| numero_fila | Si | Fila del archivo |
| campo | Si | Campo afectado |
| tipo_error | Si | INCOMPLETO, DUPLICADO, FORMATO_INVALIDO, VALOR_NO_RECONOCIDO |
| mensaje | Si | Descripcion clara |
| valor_original | No | Valor recibido |

---

## 5. Fuentes Iniciales

I2 toma como referencia los archivos reales compartidos:

- `Referencias/Matriz de Cursos y Acreditaciones para IA.xlsx`
- `Referencias/Novedades de Personal Diaras RRHH - OP-GERENCIA 2026 copia.xlsx`
- `Talento Humano.xlsx`
- `Talento Humano(Sheet1).csv`

Para I2, estos archivos sirven para extraer datos iniciales de empleados/guardas y validar problemas de calidad. No se asume que una sola fuente este limpia o sea definitiva.

---

## 6. Flujo De Importacion

1. Talento Humano selecciona tipo de carga.
2. Talento Humano carga archivo Excel/CSV.
3. El sistema lee encabezados.
4. El sistema intenta mapear columnas conocidas.
5. El sistema previsualiza el mapeo.
6. El sistema prevalida registros.
7. El sistema muestra resumen:
   - total;
   - validos;
   - incompletos;
   - duplicados;
   - erroneos.
8. Talento Humano revisa detalle de errores.
9. Talento Humano decide:
   - importar solo validos;
   - cancelar carga;
   - corregir archivo externamente y volver a cargar.
10. Si importa, el sistema persiste registros validos.
11. El sistema guarda historial de carga.
12. El sistema registra auditoria.

---

## 7. Prevalidaciones Minimas

### Identificacion

- Debe existir `numero_identificacion` para considerar valido un empleado.
- `tipo_identificacion` tendra default CC.
- Se debe permitir CE para cedula de extranjeria.
- Otros tipos de identificacion quedan fuera del MVP salvo decision posterior.
- Si viene `#N/A`, vacio o texto no identificable, clasificar como incompleto/error.
- Identificacion duplicada dentro del archivo: duplicado.
- Identificacion ya existente en base: posible actualizacion, no creacion directa sin confirmacion.

### Nombre

- `nombre_completo` requerido.
- Debe limpiarse de espacios extremos.
- Si nombre esta vacio: incompleto.

### Estado Laboral

- Si no viene estado, inferir ACTIVO solo si la fuente es matriz activa y no hay fecha de retiro.
- Si hay fecha de retiro, sugerir RETIRADO.
- Si estado no puede inferirse, clasificar como incompleto.

### Fechas

- Fechas deben ser parseables.
- Fecha ingreso requerida para activo.
- Fecha retiro requerida para retirado.
- Fecha retiro no puede ser anterior a fecha ingreso.

### Cargo

- Cargo requerido.
- Si el cargo no coincide con catalogo inicial, permitir como texto nuevo marcado para normalizacion.

### Salario Base

- Si viene valor, debe ser numerico.
- Salario base es obligatorio para crear empleado.
- Si no viene salario base, el registro queda en errores/incompletos y no se importa.
- La vigencia inicial recomendada sera la fecha de carga o fecha definida por TH.

---

## 8. Clasificacion De Registros

| Clasificacion | Significado | Puede importarse |
|---------------|-------------|------------------|
| Valido | Cumple campos minimos | Si |
| Incompleto | Falta dato requerido | No, salvo decision explicita futura |
| Duplicado | Repite identificacion o coincide con existente | No directo |
| Erroneo | Formato invalido o inconsistente | No |

I2 debe permitir importar validos sin bloquear por errores de otros registros, siempre que el usuario confirme.

Los registros incompletos no se importan como borrador en el MVP. Deben quedar en errores para que Talento Humano corrija el archivo y lo cargue nuevamente.

---

## 9. Edicion Manual Controlada

Talento Humano puede editar:

- nombre completo;
- estado laboral;
- cargo;
- fecha ingreso;
- fecha retiro;
- motivo retiro;
- tipo contrato;
- observaciones;
- salario base vigente.

Toda edicion debe registrar:

- usuario;
- fecha/hora;
- campo modificado;
- valor anterior;
- valor nuevo.

Para el MVP, los errores de importacion no se corrigen dentro del portal antes de importar. El flujo aprobado es corregir el archivo fuente y recargar.

---

## 10. Reglas Funcionales

1. No se persiste ningun archivo sin prevalidacion.
2. Una carga puede ser prevalidada y luego cancelada.
3. Una carga importada debe conservar resumen.
4. Los errores deben ser consultables despues de la carga.
5. La identificacion es la llave funcional primaria cuando existe.
6. No se permite crear dos empleados activos con la misma identificacion.
7. Empleados retirados pueden compartir identificacion solo si son el mismo registro historico, no duplicados.
8. Salario base debe manejar vigencia.
9. Salario base es obligatorio para crear empleado.
10. La carga inicial puede detectar datos incompletos, pero no importarlos como borrador.
11. Los datos incompletos deben quedar en errores y corregirse en archivo fuente.
12. Gerencia puede consultar detalle salarial.
13. Operaciones no consulta detalle salarial en MVP salvo autorizacion posterior.
14. Gerencia y Operaciones no editan en I2.
15. La fuente HELIZA queda futura.

---

## 11. Pantallas Esperadas

### 11.1 Listado De Empleados/Guardas

Debe incluir:

- busqueda por nombre/identificacion;
- filtro por estado laboral;
- filtro por cargo;
- estado de completitud;
- acceso a detalle.

### 11.2 Detalle De Empleado/Guarda

Debe mostrar:

- datos personales/laborales;
- estado laboral;
- salario base vigente;
- fuente del dato;
- historial de cambios basico.

### 11.3 Carga De Datos

Debe permitir:

- seleccionar tipo de carga;
- subir archivo;
- ver resumen de prevalidacion;
- revisar errores;
- confirmar importacion de validos;
- cancelar.

### 11.4 Historial De Cargas

Debe mostrar:

- fecha;
- usuario;
- archivo;
- estado;
- conteos;
- acceso a errores.

---

## 12. Dependencias Tecnicas De I0

I2 depende de I0 para:

- tecnologia de lectura Excel/CSV;
- base de datos;
- estrategia de almacenamiento temporal de archivos;
- limite de tamaño de archivo;
- permisos de carpeta;
- estrategia de auditoria;
- formatos de exportacion de errores.

I0 cerro con React SPA + backend .NET 6 compatible + PostgreSQL + API REST. Las decisiones operativas especificas de lectura Excel/CSV, almacenamiento temporal, limite de archivo, auditoria y exportacion de errores deben quedar cerradas en el plan I2 antes de retomar implementacion.

---

## 13. Criterios De Aceptacion

I2 se considera aceptado cuando:

1. Existe listado de empleados/guardas.
2. Existe detalle de empleado/guarda.
3. Talento Humano puede cargar archivo Excel/CSV.
4. El sistema prevalidada antes de importar.
5. El resumen de carga muestra total, validos, incompletos, duplicados y erroneos.
6. El sistema permite cancelar una carga prevalidada.
7. El sistema permite importar registros validos.
8. Los errores quedan disponibles para consulta.
9. Se evita crear duplicados por identificacion.
10. Salario base se exige para crear empleado y se guarda con vigencia.
11. Las ediciones manuales quedan auditadas.
12. Gerencia puede consultar detalle salarial.
13. Operaciones consulta empleados sin detalle salarial.
14. Gerencia y Operaciones consultan sin editar.
15. La UI respeta `docs/DESIGN.md`.

---

## 14. Pruebas Esperadas

Las pruebas concretas dependeran del stack definido por I0, pero deben cubrir:

- carga con registros validos;
- carga con identificacion vacia;
- carga con `#N/A`;
- carga con duplicados internos;
- carga con registro ya existente;
- carga con fecha invalida;
- carga con salario no numerico;
- cancelacion de carga;
- importacion solo de validos;
- auditoria de edicion manual;
- permisos de consulta para Gerencia/Operaciones;
- bloqueo de edicion para Gerencia/Operaciones.

---

## 15. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Fuentes Excel con datos mezclados | Alto | Prevalidacion y mapeo revisable |
| Identificaciones faltantes | Alto | Clasificar incompletos y no importar como validos |
| Duplicados reales | Alto | Reglas por identificacion y confirmacion futura de merge |
| Salario base incompleto | Alto | Clasificar como incompleto/error y no importar empleado hasta corregir |
| Cargos no normalizados | Medio | Permitir texto inicial y normalizar en fases posteriores |
| Dependencia de HELIZA | Medio | Mantener HELIZA fuera de I2 |

---

## 16. Preguntas Abiertas

No quedan preguntas funcionales abiertas para I2.

Decisiones cerradas:

1. Registros incompletos quedan solo en errores; no se importan como borrador.
2. `tipo_identificacion` tiene default CC y permite CE para cedula de extranjeria.
3. Errores se corrigen en el archivo fuente y se recarga; no se corrigen dentro del portal en MVP.
4. Salario base es obligatorio para crear empleado.
5. Gerencia puede ver detalle salarial.
6. Operaciones no ve detalle salarial en MVP salvo autorizacion posterior.

---

## 17. Estado De La SPEC I2

Esta SPEC queda validada y aprobada como contrato funcional de datos maestros e importacion.

Gate SDD: la implementacion I2 solo puede continuar cuando el plan I2 completo haya sido revisado y aprobado.

# SPEC I4 - Certificaciones Laborales

**Fecha:** 2026-05-21  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I4  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**SPECs relacionadas:**  
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`  
**Referencias:**  
- `Referencias/CERT LUIS CARLOS YOLIS CORREA 2.pdf`  
- `Referencias/membrete actual CERT RETIRADO ORLANDO ESTEBAN CADENA LONDOÑO 3.pdf`  
**Estado:** Borrador funcional, pendiente decisiones tecnicas I0  

---

## 1. Proposito

Automatizar la generacion controlada de certificaciones laborales para empleados activos y retirados. I4 debe eliminar trabajo manual repetitivo, conservar trazabilidad y generar PDF final con firma parametrizada, vista previa, aprobacion de Talento Humano y snapshot inmutable de los datos usados.

---

## 2. Alcance

### Incluido

- Certificacion laboral para empleado activo.
- Certificacion laboral para empleado retirado.
- Seleccion de empleado desde maestro.
- Validacion de datos requeridos.
- Variante por destino/proposito.
- Firma parametrizada y vigente.
- Vista previa.
- Aprobacion por Talento Humano.
- Generacion de PDF final.
- Snapshot de datos laborales y salariales.
- Historial de certificaciones.
- Consulta por Gerencia.
- Auditoria.

### Fuera de alcance

- Firma digital certificada.
- Envio automatico por correo al solicitante.
- Portal externo de validacion.
- QR de validacion.
- Integracion HELIZA.
- Integracion nomina.
- Aprobacion obligatoria de Gerencia.
- Edicion libre de plantilla desde UI.

---

## 3. Actores

### Talento Humano

Genera, revisa, aprueba y descarga certificaciones.

### Gerencia / Consulta

Consulta historial y trazabilidad de certificaciones, sin aprobar ni editar en MVP.

### Administrador

Configura firmantes y parametros base.

### Operaciones / Consulta

No participa en el flujo de certificaciones en MVP.

---

## 4. Tipos De Certificacion

### 4.1 Empleado Activo

Debe incluir como minimo:

- nombre del trabajador;
- identificacion;
- fecha de ingreso;
- cargo;
- tipo de contrato si existe;
- salario base;
- auxilio de transporte si aplica;
- extras/variables si fueron cargadas;
- destino/proposito;
- fecha de expedicion;
- firmante vigente;
- elaborador.

### 4.2 Empleado Retirado

Debe incluir como minimo:

- nombre del trabajador;
- identificacion;
- fecha de ingreso;
- fecha de retiro;
- cargo;
- motivo de retiro;
- texto de expedicion a solicitud del interesado;
- texto asociado a cesantias si aplica por variante;
- fecha de expedicion;
- firmante vigente;
- elaborador.

---

## 5. Variantes Por Destino / Proposito

El MVP debe permitir seleccionar un destino/proposito:

- entidad financiera;
- cesantias;
- cliente;
- tramite general;
- interesado.

La variante no implica una plantilla completamente distinta en MVP. Puede ajustar texto, destinatario o bloque contextual.

---

## 6. Firma Parametrizada

### Firmante

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| nombre | Si | Nombre del firmante |
| cargo | Si | Cargo visible |
| firma_imagen | No | Si se define archivo/imagen |
| vigencia_desde | Si | Fecha |
| vigencia_hasta | No | Nulo si vigente |
| estado | Si | ACTIVO/INACTIVO |

Reglas:

1. Debe existir un firmante activo y vigente para generar certificacion.
2. El firmante usado debe guardarse en snapshot.
3. Si cambia el firmante despues, certificaciones previas no cambian.

---

## 7. Datos Salariales

### Salario Base

- Viene del maestro de empleados.
- Es obligatorio para crear empleado desde I2.
- Debe tomarse el salario base vigente a la fecha de expedicion.
- Debe guardarse en snapshot.

### Variables Manuales

Talento Humano puede registrar variables al preparar la certificacion:

- auxilio de transporte;
- extras;
- recargos;
- bonificaciones/otros auxilios;
- observacion salarial.

Reglas:

- Las variables son opcionales.
- Las variables deben registrarse con desglose por concepto.
- Si se incluyen, quedan en snapshot.
- La certificacion activa solo muestra variables si Talento Humano las ingresa.
- No modifican el salario base maestro.
- No reemplazan integracion futura con nomina.

---

## 8. Flujo De Certificacion

1. Talento Humano entra a Certificaciones Laborales.
2. Busca y selecciona empleado.
3. El sistema identifica si esta ACTIVO o RETIRADO.
4. El sistema valida datos requeridos segun tipo.
5. Talento Humano selecciona destino/proposito.
6. Talento Humano revisa salario base vigente.
7. Talento Humano agrega variables manuales si aplica.
8. El sistema genera vista previa.
9. Talento Humano aprueba.
10. El sistema genera PDF final.
11. El sistema guarda snapshot.
12. El sistema registra auditoria.
13. Talento Humano descarga PDF.

---

## 9. Estados De Certificacion

| Estado | Descripcion |
|--------|-------------|
| BORRADOR | Preparada pero no aprobada |
| PREVISUALIZADA | Tiene vista previa generada |
| APROBADA | TH aprobo generacion |
| GENERADA | PDF final emitido |
| ANULADA | Documento invalidado internamente |

Regla: en MVP, la anulacion no elimina el PDF ni el snapshot; solo marca estado.

---

## 10. Snapshot De Certificacion

Cada certificacion generada debe conservar:

- numero_consecutivo;
- empleado_id;
- nombre empleado al momento;
- identificacion al momento;
- estado laboral al momento;
- cargo al momento;
- fechas laborales al momento;
- salario base usado;
- variables usadas;
- destino/proposito;
- firmante usado;
- usuario elaborador;
- usuario aprobador;
- fecha/hora aprobacion;
- fecha/hora generacion;
- plantilla/version usada;
- ruta o referencia del PDF;

El snapshot es inmutable salvo anulacion de estado.

El numero consecutivo es obligatorio para trazabilidad. Su formato exacto se definira en implementacion tecnica, pero debe ser unico y consultable.

---

## 11. Pantallas Esperadas

### 11.1 Listado De Certificaciones

Debe incluir:

- busqueda por empleado/identificacion;
- filtro por tipo;
- filtro por estado;
- filtro por fecha;
- acceso a detalle;
- descarga si esta generada.

### 11.2 Nueva Certificacion

Debe permitir:

- buscar empleado;
- seleccionar destino/proposito;
- revisar datos requeridos;
- ingresar variables manuales;
- generar vista previa;
- aprobar/generar.

### 11.3 Vista Previa

Debe mostrar:

- contenido del certificado antes de PDF final;
- datos laborales;
- bloque salarial si aplica;
- firmante;
- advertencias de datos faltantes.

### 11.4 Configuracion De Firmante

Debe permitir:

- crear/editar firmante;
- definir vigencia;
- activar/inactivar;
- consultar historial.

---

## 12. Permisos

| Accion | Administrador | Talento Humano | Gerencia/Consulta | Operaciones/Consulta |
|--------|---------------|----------------|-------------------|----------------------|
| Ver certificaciones | Si | Si | Si | No |
| Crear certificacion | No | Si | No | No |
| Previsualizar | No | Si | No | No |
| Aprobar/generar | No | Si | No | No |
| Descargar PDF | Si | Si | Si | No |
| Anular | Si | Si | No | No |
| Configurar firmante | Si | No | No | No |
| Ver detalle salarial en certificacion | Si | Si | Si | No |

---

## 13. Reglas Funcionales

1. No se puede generar certificacion sin empleado existente.
2. No se puede generar certificacion sin firmante vigente.
3. No se puede generar certificacion activa sin salario base vigente.
4. No se puede generar certificacion retirada sin fecha de retiro.
5. No se puede generar certificacion retirada sin motivo de retiro.
6. Talento Humano aprueba y genera en MVP.
7. Gerencia consulta, pero no aprueba.
8. Administrador configura firmante, pero no genera certificaciones en MVP.
9. Operaciones no accede al modulo en MVP.
10. PDF generado conserva snapshot inmutable.
11. Cambios posteriores del empleado no alteran certificaciones generadas.
12. Cambios posteriores del firmante no alteran certificaciones generadas.
13. Anular no borra documento ni auditoria.
14. Anular exige motivo obligatorio.
15. Variables manuales no modifican maestro salarial.
16. Variables manuales se registran por concepto.
17. La certificacion activa solo muestra variables si TH las ingresa.
18. Toda certificacion generada debe tener numero consecutivo unico.

---

## 14. Dependencias Tecnicas De I0/I2

I4 depende de:

- I0 para libreria/mecanismo de generacion PDF;
- I0 para almacenamiento de PDFs;
- I0 para estrategia de seguridad y auditoria;
- I2 para maestro de empleados y salario base;
- I1 para usuarios, roles y permisos;
- `docs/DESIGN.md` para interfaz.

Mientras I0 no cierre, esta SPEC se considera funcional y de contrato.

---

## 15. Criterios De Aceptacion

I4 se considera aceptado cuando:

1. Talento Humano puede crear certificacion para empleado activo.
2. Talento Humano puede crear certificacion para empleado retirado.
3. El sistema bloquea activo sin salario base vigente.
4. El sistema bloquea retirado sin fecha/motivo de retiro.
5. El sistema exige firmante vigente.
6. Talento Humano puede seleccionar destino/proposito.
7. Talento Humano puede agregar variables manuales.
8. El sistema muestra vista previa.
9. Talento Humano puede aprobar/generar PDF.
10. El PDF queda disponible para descarga.
11. Se conserva snapshot.
12. Gerencia puede consultar certificaciones y detalle salarial.
13. Operaciones no accede al modulo.
14. Administrador puede configurar firmante.
15. Anulacion marca estado sin eliminar PDF.
16. Anulacion exige motivo.
17. Variables manuales se capturan por concepto.
18. La certificacion activa no muestra variables si TH no las ingresa.
19. Toda certificacion generada tiene numero consecutivo.
20. La UI respeta `docs/DESIGN.md`.

---

## 16. Pruebas Esperadas

Las pruebas concretas dependeran del stack definido por I0, pero deben cubrir:

- activo con datos completos;
- retirado con datos completos;
- activo sin salario base;
- retirado sin fecha retiro;
- retirado sin motivo retiro;
- ausencia de firmante vigente;
- seleccion de destino/proposito;
- variables manuales;
- snapshot inmutable;
- descarga de PDF;
- anulacion;
- permisos TH/Gerencia/Operaciones/Admin.

---

## 17. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Plantillas reales tienen variantes no conocidas | Medio | Usar tipo + variante y permitir evolucion |
| PDF depende de libreria no viable en Windows Server 2012 | Alto | Resolver en I0 antes de implementar |
| Datos salariales incompletos | Alto | I2 exige salario base para crear empleado |
| Firma cambia en el tiempo | Medio | Firmante versionado y snapshot |
| Usuarios esperan envio por correo | Bajo | Dejar fuera de MVP; descarga manual |

---

## 18. Preguntas Abiertas

No quedan preguntas funcionales abiertas para I4.

Decisiones cerradas:

1. Solo Talento Humano genera certificaciones en MVP.
2. Administrador configura firmantes, pero no genera certificaciones.
3. Anulacion exige motivo obligatorio.
4. Variables manuales se registran con desglose por concepto.
5. La certificacion activa solo muestra variables si TH las ingresa.
6. Toda certificacion generada debe tener numero consecutivo unico por trazabilidad.

---

## 19. Estado De La SPEC I4

Esta SPEC queda lista como contrato funcional de certificaciones laborales. La implementacion queda bloqueada hasta cerrar I0 y actualizar `docs/TECNOLOGIA.md`.

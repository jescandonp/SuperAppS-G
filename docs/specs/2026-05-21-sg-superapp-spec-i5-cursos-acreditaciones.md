# SPEC I5 - Cursos y Acreditaciones

**Fecha:** 2026-05-21  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I5  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**SPECs relacionadas:**  
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`  
**Estado:** Revisada y aprobada para planificacion I5  

---

## 1. Proposito

Implementar el control de cursos y acreditaciones obligatorias por empleado/guarda, con tipos parametrizados, historico de renovaciones, vencimientos calculados, estado de cumplimiento y marca explicita de habilitado/no habilitado para servicio.

I5 debe convertir la matriz manual de vencimientos en datos gobernados por reglas, reutilizables por Operaciones, Alertas/Notificaciones y Dashboard.

---

## 2. Alcance

### Incluido

- Tipos de curso/acreditacion.
- Requisitos multiples por empleado.
- Historico de renovaciones por tipo.
- Fecha de realizacion.
- Fecha de vencimiento.
- Estado calculado por umbrales.
- Marca de habilitado/no habilitado para servicio.
- Consulta por Talento Humano, Operaciones y Gerencia.
- Gestion por Talento Humano y Administrador segun permisos.
- Soporte documental opcional en modelo.
- Auditoria de creacion, actualizacion e inactivacion.

### Fuera de alcance

- Envio automatico de alertas.
- Correo/SMTP.
- Bloqueo automatico de programacion de turnos.
- Notificaciones a guardas.
- WhatsApp.
- Integracion HELIZA.
- Integracion nomina.
- Carga masiva especifica de cursos/acreditaciones si no se define en plan.
- Validacion externa de certificados o soportes.

---

## 3. Actores

### Talento Humano

Gestiona tipos, registra renovaciones, corrige datos y consulta empleados no habilitados.

### Administrador

Configura catalogos base y puede consultar/gestionar registros para soporte operativo.

### Operaciones / Consulta

Consulta estado de cumplimiento y si un guarda esta habilitado para servicio. No edita.

### Gerencia / Consulta

Consulta indicadores y detalle de cumplimiento. No edita.

---

## 4. Conceptos De Dominio

### Tipo De Curso/Acreditacion

Campos minimos:

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| codigo | No | Unico si se define |
| nombre | Si | Nombre visible |
| categoria | Si | CURSO o ACREDITACION |
| vigencia_dias | No | Permite calcular vencimiento si aplica |
| obligatorio_servicio | Si | Define impacto en habilitacion |
| estado | Si | ACTIVO/INACTIVO |
| notas | No | Texto operativo |

### Renovacion / Registro De Cumplimiento

Campos minimos:

| Campo | Requerido | Regla |
|-------|-----------|-------|
| empleado_id | Si | Debe existir en maestro |
| tipo_id | Si | Debe existir y estar activo al crear |
| fecha_realizacion | Si | Fecha valida |
| fecha_vencimiento | Si | Fecha valida calculada o ingresada |
| soporte_path | No | Referencia documental opcional |
| observaciones | No | Texto operativo |
| estado_registro | Si | ACTIVO/INACTIVO |

---

## 5. Estados Calculados

El estado no debe depender de texto manual. Se calcula comparando fecha de vencimiento contra la fecha actual:

| Estado | Regla |
|--------|-------|
| VENCIDO | fecha de vencimiento menor a hoy |
| CRITICO | 0 a 15 dias restantes |
| PREVENTIVO | 16 a 30 dias restantes |
| INFORMATIVO | 31 a 60 dias restantes |
| AL_DIA | mas de 60 dias restantes |

Reglas:

1. Si un empleado tiene al menos un requisito obligatorio vencido, queda `NO_HABILITADO` para servicio.
2. Si no tiene requisitos obligatorios vencidos, queda `HABILITADO` para servicio.
3. La habilitacion es una lectura calculada, no un campo manual editable por UI.
4. Los umbrales deben quedar centralizados para que I6 pueda generar alertas con las mismas reglas.

---

## 6. Flujos Esperados

### 6.1 Configurar Tipo

1. Administrador o TH entra a Cursos y Acreditaciones.
2. Crea tipo con nombre, categoria, obligatoriedad y vigencia.
3. El sistema valida campos obligatorios y unicidad de codigo si aplica.
4. El sistema registra auditoria.

### 6.2 Registrar Renovacion

1. TH busca empleado.
2. Selecciona tipo de curso/acreditacion.
3. Ingresa fecha de realizacion.
4. El sistema calcula fecha de vencimiento si el tipo tiene vigencia en dias, o exige fecha de vencimiento manual si no la tiene.
5. TH adjunta referencia de soporte si existe o deja campo vacio.
6. El sistema guarda renovacion e invalida la renovacion anterior como actual solo por lectura de ultima vigencia, sin borrar historial.

### 6.3 Consultar Cumplimiento

1. TH, Operaciones o Gerencia consulta empleado o listado.
2. El sistema muestra estado calculado por requisito.
3. El sistema muestra habilitado/no habilitado para servicio.
4. Operaciones y Gerencia no ven acciones de edicion.

---

## 7. Pantallas Esperadas

### 7.1 Listado De Cumplimiento

Debe incluir:

- busqueda por empleado/identificacion;
- filtro por estado calculado;
- filtro por tipo;
- filtro por habilitacion;
- fecha de vencimiento;
- indicador visual de prioridad;
- acceso a detalle.

### 7.2 Detalle De Empleado

Debe mostrar:

- empleado;
- puesto actual si existe;
- habilitado/no habilitado;
- requisitos actuales;
- historico de renovaciones;
- acciones de registro para TH/ADMIN.

### 7.3 Gestion De Tipos

Debe permitir:

- crear/editar tipos;
- activar/inactivar;
- marcar obligatoriedad para servicio;
- definir vigencia en dias.

---

## 8. Permisos

| Accion | Administrador | Talento Humano | Gerencia/Consulta | Operaciones/Consulta |
|--------|---------------|----------------|-------------------|----------------------|
| Ver cumplimiento | Si | Si | Si | Si |
| Ver detalle | Si | Si | Si | Si |
| Crear/editar tipo | Si | Si | No | No |
| Inactivar tipo | Si | Si | No | No |
| Registrar renovacion | Si | Si | No | No |
| Inactivar renovacion | Si | Si | No | No |
| Ver habilitacion servicio | Si | Si | Si | Si |

---

## 9. Reglas Funcionales

1. No se registra renovacion sin empleado existente.
2. No se registra renovacion sin tipo activo.
3. Fecha de realizacion es obligatoria.
4. Fecha de vencimiento es obligatoria, calculada o ingresada.
5. Fecha de vencimiento no puede ser anterior a fecha de realizacion.
6. Un tipo obligatorio vencido marca al empleado como `NO_HABILITADO`.
7. Estados se calculan por umbrales, no se editan manualmente.
8. Renovaciones historicas no se eliminan fisicamente.
9. Inactivar un tipo no borra historicos.
10. Operaciones y Gerencia no editan datos I5.
11. Toda creacion/edicion/inactivacion registra auditoria.
12. La UI debe respetar `docs/DESIGN.md`.

---

## 10. Dependencias

I5 depende de:

- I1 para login, roles, permisos y auditoria base.
- I2 para maestro de empleados.
- I3 para mostrar puesto actual cuando aplique.
- I6 para convertir estados en alertas/notificaciones automaticas.
- `docs/DESIGN.md` para interfaz administrativa.

I5 no depende de I4 para operar, pero ambos comparten el maestro de empleados.

---

## 11. Criterios De Aceptacion

I5 se considera aceptado cuando:

1. Existen tipos de curso/acreditacion parametrizables.
2. ADMIN y TH pueden crear/editar/inactivar tipos.
3. GERENCIA y OPERACIONES no pueden editar tipos.
4. TH puede registrar renovaciones por empleado.
5. El sistema conserva historico de renovaciones.
6. El sistema calcula vencimiento desde vigencia cuando aplique.
7. El sistema exige fecha de vencimiento cuando no puede calcularla.
8. El sistema rechaza vencimiento anterior a realizacion.
9. Estados VENCIDO/CRITICO/PREVENTIVO/INFORMATIVO/AL_DIA se calculan correctamente.
10. Un requisito obligatorio vencido marca `NO_HABILITADO`.
11. Sin requisitos obligatorios vencidos marca `HABILITADO`.
12. Operaciones consulta habilitacion sin editar.
13. Gerencia consulta cumplimiento sin editar.
14. Listado filtra por empleado, tipo, estado y habilitacion.
15. Detalle muestra requisitos actuales e historico.
16. Soporte documental queda modelado como referencia opcional.
17. Cambios registran auditoria.
18. Permisos por rol quedan protegidos en backend.
19. UI respeta estilo administrativo dark/gold.
20. El cierre deja reglas listas para I6 alertas/notificaciones.

---

## 12. Pruebas Esperadas

Las verificaciones deben cubrir:

- persistencia de tipos y renovaciones;
- calculo de estados por umbral;
- calculo de habilitacion de servicio;
- rechazo de fechas invalidas;
- historico de renovaciones;
- permisos ADMIN/TH/GERENCIA/OPERACIONES;
- consulta de Operaciones;
- auditoria;
- build backend;
- build frontend.

---

## 13. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Tipos reales no estandarizados | Alto | Parametrizar tipos y permitir codigo/nombre gestionable |
| Matriz fuente con vencimientos incompletos | Alto | Exigir fecha vencimiento si no puede calcularse por vigencia |
| Usuarios esperan alerta automatica inmediata | Medio | Documentar que generacion de notificaciones queda en I6 |
| Habilitacion puede confundirse con bloqueo operativo | Alto | Mostrar `NO_HABILITADO` como indicador, sin bloquear programacion en MVP |
| Soportes documentales no tienen ruta definida | Medio | Modelar referencia opcional y diferir carga binaria si no hay ruta aprobada |

---

## 14. Preguntas Abiertas

No hay preguntas funcionales bloqueantes para Gate 0.

Decisiones cerradas:

1. Estados se calculan por fecha y umbrales definidos en PRD/SPEC 00.
2. `NO_HABILITADO` es indicador visible, no bloqueo automatico de turnos.
3. Alertas automaticas se implementan en I6.
4. Soporte documental es opcional en modelo durante I5.
5. Operaciones consulta cumplimiento, pero no edita.

---

## 15. Estado De La SPEC I5

Esta SPEC queda aprobada como contrato funcional de Cursos y Acreditaciones. La implementacion queda autorizada solo mediante el plan I5 aprobado.

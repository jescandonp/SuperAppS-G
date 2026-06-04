# SPEC I3 - Puestos de Servicio y Asignaciones

**Fecha:** 2026-05-21  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I3  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**SPECs relacionadas:**  
- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`  
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`  
**Estado:** Borrador funcional, pendiente decisiones tecnicas I0  

---

## 1. Proposito

Definir el maestro de Puestos de Servicio y la relacion historica de asignacion entre guardas/empleados y puestos. Este incremento conecta desde el piloto la informacion de Talento Humano con la estructura operativa de S&G.

El puesto de servicio no es un campo plano del empleado. Es una entidad maestra con asignaciones historicas.

---

## 2. Alcance

### Incluido

- Maestro de puestos de servicio.
- Creacion y edicion controlada de puestos.
- Estado del puesto.
- Asignacion de empleado/guarda a puesto.
- Historico de asignaciones.
- Consulta de puesto actual por empleado.
- Consulta de empleados asignados por puesto.
- Finalizacion de asignaciones.
- Auditoria de cambios.
- Permisos de consulta para Operaciones y Gerencia.

### Fuera de alcance

- Programacion automatica de turnos.
- Cuadrantes.
- Relevos.
- Validacion contra contratos/clientes.
- Facturacion por puesto.
- Novedades operativas completas.
- Inventario/dotacion por puesto.
- Armamento por puesto.

---

## 3. Actores

### Administrador

Puede configurar catalogos y consultar datos. No necesariamente gestiona asignaciones operativas en MVP.

### Talento Humano

Puede gestionar asignaciones de puesto vinculadas a empleados/guardas durante el piloto.

### Operaciones / Consulta

Puede consultar puesto actual, historial y empleados asignados, sin editar en MVP.

### Gerencia / Consulta

Puede consultar la estructura general y trazabilidad de asignaciones.

---

## 4. Entidades Funcionales

### 4.1 Puesto De Servicio

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| codigo | No en MVP | Si existe, debe ser unico |
| nombre | Si | Nombre del puesto |
| cliente_texto | No | Referencia textual inicial si existe |
| ubicacion | No | Texto inicial |
| estado | Si | ACTIVO, INACTIVO |
| observaciones | No | Texto |

### 4.2 Asignacion De Puesto

| Campo | Requerido | Regla |
|-------|-----------|-------|
| id | Si | Identificador interno |
| empleado_id | Si | Guarda/empleado |
| puesto_id | Si | Puesto de servicio |
| fecha_inicio | Si | Fecha valida |
| fecha_fin | No | Nulo si vigente |
| estado | Si | VIGENTE, FINALIZADA |
| motivo_cambio | No | Texto |
| observaciones | No | Texto |

Regla central: un empleado/guarda no puede tener mas de una asignacion vigente al mismo tiempo.

El cliente se manejará como texto libre en el MVP. Un maestro formal de clientes queda para iteracion futura.

La asignacion puede aplicar a guardas y personal administrativo. El cargo del empleado permite diferenciar el tipo de persona asignada.

---

## 5. Flujo De Puesto De Servicio

1. Talento Humano o Administrador ingresa al modulo Puestos de Servicio.
2. Crea puesto con nombre obligatorio.
3. Opcionalmente registra cliente/ubicacion/observaciones.
4. El puesto queda ACTIVO.
5. Si el puesto deja de usarse, se marca INACTIVO.
6. No se elimina fisicamente si tiene asignaciones historicas.

---

## 6. Flujo De Asignacion

1. Talento Humano selecciona empleado/guarda.
2. El sistema muestra si tiene asignacion vigente.
3. Talento Humano selecciona puesto activo.
4. Define fecha de inicio.
5. Si existe asignacion vigente previa, el sistema exige finalizarla antes o como parte del cambio.
6. El sistema crea nueva asignacion vigente.
7. El sistema conserva historial.
8. El sistema registra auditoria.

---

## 7. Reglas Funcionales

1. Puesto de servicio es entidad maestra, no campo libre final del empleado.
2. Todo puesto debe tener nombre.
3. No se puede asignar un empleado a puesto inactivo.
4. Un empleado no puede tener dos asignaciones vigentes simultaneas.
5. Una asignacion vigente tiene `fecha_fin` vacia.
6. Finalizar una asignacion exige fecha fin.
7. `fecha_fin` no puede ser anterior a `fecha_inicio`.
8. Al cambiar de puesto, el historial anterior debe conservarse.
9. Operaciones puede consultar asignaciones, pero no editarlas en MVP.
10. Gerencia puede consultar asignaciones e historico.
11. Las asignaciones deben dejar auditoria.
12. Si un puesto aparece como texto en carga inicial I2, puede quedar pendiente de normalizacion en I3.
13. Talento Humano y Administrador pueden crear puestos.
14. Cliente es texto libre en MVP.
15. El maestro formal de clientes queda para futuro.
16. La asignacion permite empleados/guardas y personal administrativo.
17. Motivo de finalizacion es opcional en MVP.
18. Operaciones no puede solicitar cambios de puesto dentro del MVP.

---

## 8. Pantallas Esperadas

### 8.1 Listado De Puestos

Debe incluir:

- busqueda por nombre;
- filtro por estado;
- cantidad de empleados asignados vigente;
- acceso a detalle.

### 8.2 Detalle De Puesto

Debe mostrar:

- datos del puesto;
- estado;
- empleados/guardas asignados actualmente;
- historial basico de asignaciones;
- observaciones.

### 8.3 Asignacion Desde Empleado

Debe mostrar:

- empleado/guarda;
- puesto actual;
- historial de puestos;
- accion para asignar/cambiar puesto si el perfil lo permite.

### 8.4 Historial De Asignaciones

Debe mostrar:

- empleado;
- puesto;
- fecha inicio;
- fecha fin;
- estado;
- motivo/observacion;
- usuario que registro el cambio si esta disponible.

---

## 9. Permisos

| Accion | Administrador | Talento Humano | Gerencia/Consulta | Operaciones/Consulta |
|--------|---------------|----------------|-------------------|----------------------|
| Ver puestos | Si | Si | Si | Si |
| Crear puesto | Si | Si | No | No |
| Editar puesto | Si | Si | No | No |
| Inactivar puesto | Si | Si | No | No |
| Ver asignaciones | Si | Si | Si | Si |
| Crear asignacion | Si | Si | No | No |
| Finalizar asignacion | Si | Si | No | No |
| Ver historial | Si | Si | Si | Si |

---

## 10. Dependencias Tecnicas De I0/I2

I3 depende de:

- I0 para stack, base de datos y auditoria tecnica.
- I2 para maestro de empleados/guardas.
- `docs/DESIGN.md` para interfaz.

Mientras I0 no cierre, esta SPEC se considera funcional y de contrato.

---

## 11. Criterios De Aceptacion

I3 se considera aceptado cuando:

1. Existe listado de puestos.
2. Se puede crear puesto activo con nombre.
3. Se puede inactivar puesto.
4. No se puede asignar empleado a puesto inactivo.
5. Se puede asignar empleado a puesto activo.
6. El empleado muestra puesto actual.
7. Un empleado no puede tener dos asignaciones vigentes.
8. Se puede finalizar asignacion con fecha fin.
9. El historial de asignaciones se conserva.
10. Operaciones puede consultar puesto actual e historial sin editar.
11. Gerencia puede consultar puesto actual e historial.
12. Los cambios quedan auditados.
13. La UI respeta `docs/DESIGN.md`.
14. Talento Humano puede crear puestos.
15. Cliente se registra como texto libre.
16. Se puede asignar personal administrativo si existe como empleado.
17. Finalizar asignacion no exige motivo en MVP.
18. Operaciones no puede crear solicitudes de cambio.

---

## 12. Pruebas Esperadas

Las pruebas concretas dependeran del stack definido por I0, pero deben cubrir:

- crear puesto valido;
- crear puesto sin nombre;
- inactivar puesto;
- asignar empleado a puesto activo;
- bloquear asignacion a puesto inactivo;
- bloquear doble asignacion vigente;
- finalizar asignacion;
- consultar historial;
- permisos de edicion para TH/Admin;
- bloqueo de edicion para Gerencia/Operaciones.

---

## 13. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Puestos duplicados por variaciones de nombre | Medio | Busqueda y normalizacion manual |
| Puestos cargados como texto en I2 | Medio | Normalizar en I3 antes de asignacion definitiva |
| Cambios de puesto sin fecha clara | Medio | Exigir fecha inicio y fecha fin para cierres |
| Operaciones requiere editar | Medio | Mantener consulta en MVP; evaluar edicion futura |
| Confundir asignacion con programacion de turnos | Alto | Mantener turnos fuera de alcance |

---

## 14. Preguntas Abiertas

No quedan preguntas funcionales abiertas para I3.

Decisiones cerradas:

1. Talento Humano y Administrador pueden crear puestos.
2. Cliente sera texto libre en MVP; maestro de clientes queda futuro.
3. Se permite asignar empleados/guardas y personal administrativo, diferenciando por cargo.
4. Motivo de finalizacion de asignacion es opcional en MVP.
5. Operaciones no puede solicitar cambio de puesto dentro del MVP.

---

## 15. Estado De La SPEC I3

Esta SPEC queda lista como contrato funcional de puestos de servicio y asignaciones. La implementacion queda bloqueada hasta cerrar I0 y actualizar `docs/TECNOLOGIA.md`.

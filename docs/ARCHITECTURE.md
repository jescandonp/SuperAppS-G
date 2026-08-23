# Arquitectura Rectora - S&G Super App

> Documento vivo para el piloto Talento Humano de Seguridad & Gestion Ltda.
> Autoridad superior: `docs/CONSTITUTION.md`.
> Autoridad visual: `docs/DESIGN.md` y referencias citadas en `Prototipos/`.
> Stack definitivo: pendiente de `SPEC I0 - Descubrimiento Tecnico e Infraestructura`.

## 1. Vision General

S&G Super App sera un portal interno para gestionar informacion operativa y administrativa de Seguridad & Gestion desde un unico punto. El piloto inicia con Talento Humano, pero su arquitectura debe permitir evolucionar hacia Operaciones, novedades, inventario, armamento, nomina, HELIZA, gerencia y analitica.

La tesis arquitectonica es:

> Cada quick win debe producir datos maestros y trazabilidad reutilizable para el ecosistema.

## 2. Contexto Del Piloto

```text
Usuarios internos
  ├─ Administrador
  ├─ Talento Humano
  ├─ Gerencia / Consulta
  └─ Operaciones / Consulta
        │
        ▼
S&G Super App
  ├─ Portal base
  ├─ Datos maestros
  ├─ Importacion y validacion
  ├─ Certificaciones laborales
  ├─ Cursos y acreditaciones
  ├─ Alertas y notificaciones
  ├─ Dashboard
  ├─ Auditoria
  └─ Programacion asistida de turnos
        │
        ▼
Base de datos relacional
        │
        ├─ Excel inicial
        ├─ HELIZA futuro
        ├─ Nomina futuro
        ├─ Novedades futuro
        └─ Inventario/armamento futuro
```

## 3. Restriccion De Infraestructura

El servidor de aplicaciones confirmado es **Windows Server 2012**.

Esta restriccion afecta:

- runtime backend;
- version de base de datos o instalacion permitida;
- servidor web/aplicaciones;
- TLS y configuraciones de seguridad;
- tareas programadas;
- servicios de correo;
- estrategia de backups;
- compatibilidad de herramientas de despliegue.

La arquitectura tecnica final no debe cerrarse antes de I0.

## 4. Capas Logicas

### 4.1 Capa De Presentacion

Responsable de:

- login;
- navegacion principal;
- dashboard por perfil;
- formularios administrativos;
- bandeja de notificaciones;
- vistas de consulta para Gerencia y Operaciones.

Reglas:

- no exponer acciones sin permisos;
- no crear experiencia de landing para tareas administrativas;
- mantener identidad S&G dark/gold conforme a `docs/DESIGN.md`;
- referenciar prototipos desde `Prototipos/` cuando una SPEC defina una pantalla;
- priorizar claridad y densidad operativa.

### 4.2 Capa De Aplicacion

Responsable de:

- orquestar casos de uso;
- validar reglas de negocio;
- gestionar transacciones;
- emitir eventos/notificaciones;
- generar snapshots;
- evitar que la UI sea dueña de reglas criticas.

### 4.3 Capa De Dominio

Responsable de:

- entidades maestras;
- reglas de estado;
- calculo de vencimientos;
- habilitacion/no habilitacion;
- relaciones historicas;
- trazabilidad funcional.

### 4.4 Capa De Persistencia

Responsable de:

- persistir datos maestros;
- registrar auditoria;
- conservar historicos;
- soportar consultas operativas;
- preservar snapshots de certificados.

### 4.5 Capa De Integracion

Inicialmente limitada a:

- carga Excel;
- correo/SMTP si esta disponible.

Futuro:

- HELIZA;
- nomina;
- WhatsApp;
- novedades operativas;
- inventario;
- armamento.

## 5. Modulos Arquitectonicos

### 5.1 Identidad Y Acceso

- Usuarios internos.
- Roles.
- Permisos.
- Sesion.
- Restricciones por perfil.

Perfiles iniciales:

- Administrador;
- Talento Humano;
- Gerencia/Consulta;
- Operaciones/Consulta.

### 5.2 Datos Maestros

Entidades principales:

- empleado/guarda;
- puesto de servicio;
- asignacion de puesto;
- cargo;
- estado laboral;
- estructura salarial;
- tipo de curso/acreditacion;
- firmante;
- catalogos.

### 5.3 Importacion Y Validacion

Responsabilidades:

- cargar Excel;
- prevalidar;
- clasificar validos, incompletos, duplicados y erroneos;
- permitir revision;
- registrar historial;
- no persistir sin decision explicita.

### 5.4 Certificaciones Laborales

Responsabilidades:

- flujo activo;
- flujo retirado;
- variantes por destino/proposito;
- vista previa;
- aprobacion por TH;
- generacion PDF;
- snapshot de datos y valores;
- historial.

### 5.5 Compensacion

Responsabilidades:

- salario base versionado;
- tabla por cargo/vigencia cuando aplique;
- override por empleado;
- variables manuales del periodo;
- preparacion para carga periodica futura.

### 5.6 Cursos Y Acreditaciones

Responsabilidades:

- multiples tipos por empleado;
- historico de renovaciones;
- fecha de realizacion;
- fecha de vencimiento;
- calculo de estado;
- habilitado/no habilitado para servicio;
- soporte documental opcional.

### 5.7 Alertas Y Notificaciones

Responsabilidades:

- bandeja personal;
- bandeja por rol;
- contador junto al perfil;
- marcar como leida;
- archivar/borrar;
- trazabilidad de gestion;
- correo si SMTP esta disponible.

### 5.8 Dashboard

Responsabilidades:

- widgets segun perfil;
- indicadores de certificaciones;
- indicadores de vencimientos;
- indicadores de importaciones;
- indicadores para gerencia.

### 5.9 Auditoria

Responsabilidades:

- usuario;
- fecha/hora;
- accion;
- entidad afectada;
- resultado;
- trazabilidad de cargas, certificados, notificaciones y cambios maestros.

### 5.10 Novedades Futuro

Novedades se modela como evento transversal, pero no se implementa funcionalmente en MVP.

Conceptos preliminares:

- fecha/hora;
- tipo;
- empleado/guarda relacionado;
- puesto de servicio;
- descripcion;
- estado;
- responsable;
- evidencia;
- cierre.

### 5.11 Programacion Asistida De Turnos

I9 incorpora un modulo delimitado que produce propuestas explicables de
programacion mensual. No reemplaza la decision de Operaciones: genera, valida y
compara; un usuario autorizado revisa, aprueba y publica.

Entidades del limite I9:

- `PlantillaDeTurno`: ciclo y cobertura esperada versionados;
- `ProyectoDeProgramacion`: puesto, periodo y parametros de una corrida;
- `TurnoRequerido`: necesidad concreta por fecha, franja y puesto;
- `VersionDeProgramacion`: snapshot de fuentes, reglas, parametros y resultados;
- `AsignacionDeProgramacion`: guarda asignado o vacante explicita;
- `ExcepcionDeProgramacion`: desviacion tipificada, motivada y con responsable;
- `CorridaDeGeneracion`: ejecucion idempotente y auditable del motor.

Limites:

- I9 no mantiene empleados, puestos, asignaciones base ni acreditaciones;
- I9 no decide la validez juridica de una regla;
- I9 no modifica novedades en su fuente;
- I9 no aprueba ni publica autonomamente;
- una version publicada es inmutable y todo cambio crea otra version.

Integracion entre incrementos: **I2** aporta empleados y maestros; **I3** aporta
puestos y asignaciones habituales; **I5** aporta cursos, acreditaciones y
habilitacion; **I6** recibe avisos de vacantes, excepciones y propuestas; **I7**
recibe eventos de auditoria e indicadores. La integracion usa identificadores y
snapshots, sin duplicar la propiedad de esos dominios.

Resumen de integracion I9: I2 -> I3 -> I5 -> I6 -> I7.

## 6. Modelo Conceptual Inicial

```text
Empleado
  ├─ Estado laboral
  ├─ Cargo
  ├─ Salario base vigente
  ├─ Asignaciones de puesto
  ├─ Cursos/acreditaciones
  └─ Certificaciones generadas

Puesto de Servicio
  └─ Asignaciones historicas

Certificacion
  ├─ Tipo: activo/retirado
  ├─ Variante: destino/proposito
  ├─ Firmante vigente
  ├─ Snapshot laboral
  ├─ Snapshot salarial
  └─ PDF emitido

Curso/Acreditacion
  ├─ Tipo
  ├─ Renovaciones
  ├─ Vencimiento
  └─ Estado calculado

Notificacion
  ├─ Personal o rol
  ├─ Estado lectura
  ├─ Gestion
  └─ Auditoria

Programacion
  ├─ PlantillaDeTurno
  ├─ ProyectoDeProgramacion
  ├─ TurnoRequerido
  ├─ VersionDeProgramacion
  │   ├─ AsignacionDeProgramacion
  │   └─ ExcepcionDeProgramacion
  └─ CorridaDeGeneracion
```

## 7. Patrones Requeridos

- DTOs o contratos separados de entidades persistentes.
- Validaciones antes de persistencia.
- Servicios de aplicacion para casos de uso.
- Repositorios/persistencia desacoplados de la UI.
- Estados calculados por reglas.
- Historicos para relaciones que cambian en el tiempo.
- Snapshots para documentos emitidos.
- Auditoria transversal.
- Motor deterministico separado del workflow de aprobacion/publicacion.
- Snapshots de fuentes, reglas y parametros por version de programacion.
- Vacantes y excepciones visibles; nunca se ocultan mediante una asignacion invalida.

## 8. Seguridad Y Permisos

Principios:

- todo acceso pasa por usuario autenticado;
- toda edicion requiere permiso;
- Gerencia y Operaciones/Consulta no editan datos TH en MVP;
- autorizacion se valida del lado servidor cuando exista backend;
- las acciones criticas dejan auditoria.

## 9. Decisiones Pendientes De I0

- stack backend;
- stack frontend;
- motor de base de datos;
- modo de despliegue;
- servidor web o app server;
- estrategia de certificados/TLS;
- estrategia de correo;
- backups;
- acceso remoto;
- politicas de instalacion en Windows Server 2012.

## 10. Evolucion

Cualquier cambio de arquitectura debe actualizar:

1. `docs/ARCHITECTURE.md`;
2. `docs/TECNOLOGIA.md` si toca stack;
3. `docs/DESIGN.md` si toca reglas visuales o UX;
4. prototipos en `Prototipos/` si afecta pantallas de referencia;
5. SPECs afectadas;
6. planes afectados.

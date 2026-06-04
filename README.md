# ProyectoS&G - S&G Super App

S&G Super App es el ecosistema digital propuesto para Seguridad & Gestion Ltda. El piloto inicial se enfoca en Talento Humano, con certificaciones laborales y alertas de cursos/acreditaciones como quick wins, pero se estructura desde el inicio como plataforma interna con datos maestros, perfiles, trazabilidad y capacidad de evolucionar hacia novedades, operaciones, inventario, armamento, nomina e integraciones.

El proyecto se organiza bajo **Spec-Driven Development (SDD), nivel Spec-Anchored**: las especificaciones gobiernan el desarrollo y el codigo no es la fuente primaria de verdad.

## Entrada Canonica

Este `README.md` es el punto de entrada obligatorio para iniciar o retomar trabajo en el repositorio.

Antes de editar codigo:

1. Leer este `README.md`.
2. Confirmar el incremento activo y su gate.
3. Leer los documentos rectores en el orden definido por la Constitucion.
4. Leer la SPEC activa completa.
5. Leer el plan activo completo.
6. Verificar que SPEC y plan esten aprobados.

Si la SPEC o el plan activo estan en revision, la implementacion permanece pausada. En ese estado solo se permite trabajar sobre artefactos documentales y decisiones pendientes.

## Orden De Autoridad

| Documento | Proposito |
|-----------|-----------|
| `docs/CONSTITUTION.md` | Reglas SDD, autoridad de artefactos, gates, alcance y limites por incremento |
| `docs/ARCHITECTURE.md` | Arquitectura rectora de la S&G Super App y modelo de ecosistema |
| `docs/TECNOLOGIA.md` | Restricciones, decisiones y criterios de seleccion tecnologica |
| `docs/DESIGN.md` | Identidad visual, UX/UI y reglas de diseño para la Super App |
| `docs/prd/` | PRD del piloto y documentos de producto |
| `docs/specs/` | SPECs por incremento |
| `docs/plans/` | Planes ejecutables, execution logs y tareas por incremento |
| `Referencias/` | Insumos reales compartidos por S&G para levantamiento funcional |
| `Prototipos/` | Prototipos visuales, pantallas, mockups y capturas de referencia |

Cuando exista contradiccion, prevalece el orden definido en `docs/CONSTITUTION.md`. El codigo fuente no reemplaza una decision documental.

## Incrementos Del Piloto

| Incremento | Descripcion | Estado |
|-----------|-------------|--------|
| I0 | Descubrimiento tecnico e infraestructura | Cerrado |
| I1 | Portal base | Cerrado tecnicamente |
| I2 | Datos maestros e importacion | Activo: SPEC y plan aprobados |
| I3 | Puestos de servicio y asignaciones | SPEC borrador funcional |
| I4 | Certificaciones laborales | SPEC borrador funcional |
| I5 | Cursos y acreditaciones | Pendiente |
| I6 | Alertas y notificaciones | Pendiente |
| I7 | Auditoria, dashboard y cierre piloto | Pendiente |

El incremento activo, sus decisiones y validaciones obligatorias deben consultarse siempre en `docs/specs/` y `docs/plans/`.

## Gate Actual

**Incremento activo:** I2 - Datos Maestros e Importacion  
**Estado:** SPEC I2 y plan I2 aprobados; Gate 0 y Tasks 1-3 cerrados  
**Implementacion:** autorizada desde Task 4 del plan I2, siguiendo TDD  

Documentos obligatorios para la revision:

- SPEC I2: `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`
- Plan I2: `docs/plans/2026-06-03-sg-superapp-i2-datos-maestros-importacion-plan.md`

La SPEC I2 y el plan I2 fueron aprobados el 2026-06-04. Gate 0 esta cerrado.

La implementacion I2 adelantada fue auditada en Task 1. Se conserva como prototipo parcial sujeto a correcciones; las brechas y prioridades estan registradas en el execution log del plan I2.

## Estructura Base

```text
ProyectoS&G/
├── docs/
│   ├── CONSTITUTION.md
│   ├── ARCHITECTURE.md
│   ├── TECNOLOGIA.md
│   ├── DESIGN.md
│   ├── prd/
│   ├── specs/
│   ├── plans/
│   ├── handoff/
│   └── superpowers/
├── apps/
│   ├── sg-superapp-api/
│   └── sg-superapp-web/
├── db/
├── config/
├── scripts/
├── Prototipos/
├── graphify-out/
└── README.md
```

## Estado Actual

- PRD refinado del piloto: `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`.
- SPEC marco de incrementos: `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md`.
- SPEC I0: `docs/specs/2026-05-21-sg-superapp-spec-i0-descubrimiento-tecnico-infraestructura.md`.
- SPEC I1: `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`.
- SPEC I2: `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`.
- SPEC I3: `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`.
- SPEC I4: `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`.
- Plan I0: `docs/plans/2026-05-21-sg-superapp-i0-descubrimiento-tecnico-plan.md`.
- Plan I1: `docs/plans/2026-06-03-sg-superapp-i1-portal-base-plan.md`.
- Plan I2 aprobado: `docs/plans/2026-06-03-sg-superapp-i2-datos-maestros-importacion-plan.md`.
- Servidor de aplicaciones confirmado: Windows Server 2012.
- I0 cerrado documentalmente con decision de stack: React SPA + backend .NET compatible + PostgreSQL.
- I1 cerrado tecnicamente como portal base.
- I2 activo, con Gate 0 y Tasks 1-3 cerrados; siguiente tarea autorizada: Task 4.
- `graphify update .` es obligatorio despues de modificar codigo cuando la herramienta este disponible.

## Siguiente Paso Metodologico

Ejecutar Task 4 del plan I2: completar consulta y edicion de empleados.

Condicion de entrada:

- aplicar TDD para cambios de comportamiento;
- comenzar por pruebas fallidas de filtros, edicion manual, auditoria y versionado salarial;
- mantener la autorizacion backend ya establecida en Task 3.

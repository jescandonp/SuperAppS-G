# S&G Super App SDD Constitution

> Estado: Activa para el piloto Talento Humano.
> Metodologia: Spec-Driven Development (SDD), nivel Spec-Anchored.
> Fecha base: 2026-05-21.

## 1. Autoridad De Artefactos

Cuando exista tension entre documentos, decisiones, planes o codigo, aplicar este orden:

1. `docs/CONSTITUTION.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TECNOLOGIA.md`
4. `docs/DESIGN.md`
5. PRD vigente en `docs/prd/`
6. SPEC tecnica del incremento activo en `docs/specs/`
7. Catalogo operativo versionado y aprobado en `docs/operations/`
8. Plan de implementacion aprobado en `docs/superpowers/plans/`
9. Execution log documental en `docs/plans/`
10. Codigo fuente

El codigo nunca es la fuente primaria de verdad del proyecto. Si el codigo contradice la SPEC, se corrige el codigo o primero se actualiza la SPEC y luego el plan.

Los HTML ejecutivos y documentos de presentacion son artefactos de comunicacion. No reemplazan PRD, SPEC, arquitectura ni tecnologia.

Los prototipos visuales en `Prototipos/` son referencias de diseño. Cuando una SPEC los cite explicitamente, pasan a ser referencia obligatoria para ese incremento, subordinada a `docs/DESIGN.md`.

Los catalogos de `docs/operations/` estan subordinados a `CONSTITUTION`,
`ARCHITECTURE`, `TECNOLOGIA`, `DESIGN` y la SPEC activa. Una vez versionado y
aprobado, el catalogo es la fuente ejecutable de parametros operativos, pero no
puede contradecir las autoridades superiores. Ante contradiccion, prevalece la
autoridad superior, se bloquea la ejecucion de la regla y se corrige el catalogo
antes de implementar o continuar.

## 2. Reglas SDD

- Todo incremento debe tener SPEC escrita, revisada y aprobada antes de implementarse.
- Todo incremento debe tener plan tecnico en `docs/superpowers/plans/` y
  execution log en `docs/plans/` antes de ejecutar tareas.
- Todo cambio de alcance entra primero por PRD o SPEC, no por codigo.
- Todo cambio de arquitectura entra primero por `docs/ARCHITECTURE.md` o por esta constitucion.
- Todo cambio de stack entra primero por `docs/TECNOLOGIA.md`.
- Todo cambio visual rector entra primero por `docs/DESIGN.md` y, cuando aplique, por `Prototipos/`.
- Cada tarea debe tener salida verificable y trazabilidad a criterios de aceptacion.
- No se implementa funcionalidad fuera del incremento activo aunque parezca conveniente.
- Si aparece una decision no resuelta, se vuelve a entendimiento antes de codificar.

## 3. Modelo De Incrementos

El piloto se ejecuta por incrementos:

| Incremento | Alcance |
|-----------|---------|
| I0 | Descubrimiento tecnico e infraestructura |
| I1 | Portal base |
| I2 | Datos maestros e importacion |
| I3 | Puestos de servicio y asignaciones |
| I4 | Certificaciones laborales |
| I5 | Cursos y acreditaciones |
| I6 | Alertas y notificaciones |
| I7 | Auditoria, dashboard y cierre piloto |
| I8 | Consolidacion operativa y experiencia Sentinel Enterprise |
| I9 | Programacion asistida de turnos |

La SPEC 00 define el orden y reglas iniciales: `docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md`.

## 4. Alcance No Negociable Del Piloto

El piloto inicia como portal interno administrativo de la S&G Super App.

Incluye:

- login y perfiles internos;
- datos maestros;
- empleados/guardas como entidades, no como usuarios;
- puestos de servicio como maestro clave;
- certificaciones laborales;
- cursos/acreditaciones;
- alertas y notificaciones;
- dashboard;
- auditoria.

Excluye:

- guardas como usuarios del portal;
- programacion autonoma de turnos;
- bloqueo automatico de asignaciones;
- modulo completo de novedades;
- inventario funcional;
- armamento funcional;
- HELIZA como integracion obligatoria;
- nomina como integracion obligatoria;
- WhatsApp;
- analitica predictiva o IA avanzada.

I9 autoriza la **programacion asistida de turnos** como incremento posterior al
piloto base. El sistema puede validar reglas, generar propuestas deterministicas,
comparar alternativas y explicar excepciones. Toda aprobacion y publicacion queda
bajo control humano y requiere una accion explicita, autorizada y auditada. El
motor no aprueba ni publica de forma autonoma o automatica.

Las tres condiciones de Gate 0 quedaron satisfechas el 2026-07-29: SPEC
aprobada, catalogo `APROBADO_PARA_PARAMETRIZACION` y cierre ejecutivo explicito.
Gate 0 queda cerrado, pero el catalogo no es ejecutable por el motor hasta
completar y validar sus parametros. El usuario
confirma a Jorge Guzman por Operaciones; Carolina Rodriguez Russi por Talento
Humano y Juridica; y Camilo Piedrahita, Gerente General, para el cierre.

Para I9, `docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan.md`
tiene estado **APROBADO COMO HOJA DE RUTA DOCUMENTAL**. El retake queda
**TASK 2 AUTORIZADA - NO INICIADA**. Gate 0 esta cerrado; esta autorizacion no
declara que la tarea tecnica haya comenzado.

## 5. Stack Y Restricciones

- El servidor de aplicaciones confirmado es Windows Server 2012.
- El stack sigue abierto hasta cerrar I0.
- No se debe seleccionar tecnologia de implementacion sin validar compatibilidad con Windows Server 2012.
- La seleccion final de stack debe quedar en `docs/TECNOLOGIA.md` y en la SPEC I0.
- La solucion debe considerar mantenibilidad, seguridad, backups y facilidad de despliegue en la infraestructura real.

## 6. Reglas De Arquitectura

- La Super App debe diseñarse como plataforma, no como automatizaciones aisladas.
- Datos maestros deben ser reutilizables por modulos futuros.
- Cada modulo funcional debe dejar trazabilidad.
- Importaciones deben tener prevalidacion antes de persistir.
- Certificaciones generadas deben conservar snapshot inmutable.
- Estados de cursos/acreditaciones deben calcularse por reglas, no por texto manual.
- Notificaciones por rol deben registrar quien las atiende.
- Novedades se modela como evento transversal, pero no se implementa completo en el MVP.
- La programacion asistida consume datos maestros y reglas versionadas, conserva
  snapshots de cada propuesta y separa generar, revisar, aprobar y publicar.
- Una version publicada es inmutable; cualquier ajuste posterior crea una nueva
  version trazable.

## 7. Reglas UX/UI

- La autoridad visual base es `docs/DESIGN.md`.
- La carpeta raiz `Prototipos/` contiene pantallas, mockups, capturas y prototipos de referencia.
- La identidad visual base es S&G dark/gold.
- La interfaz de gestion debe ser administrativa, clara, compacta y orientada a operacion.
- No crear landing pages para flujos administrativos.
- Usar componentes consistentes antes de crear patrones aislados.
- El dashboard debe mostrar widgets segun perfil/permisos.

## 8. Gates De Calidad

Antes de cerrar una tarea:

- confirmar que respeta la SPEC activa;
- confirmar que no invade alcance de otro incremento;
- confirmar que respeta `docs/ARCHITECTURE.md`;
- confirmar que respeta `docs/TECNOLOGIA.md`;
- confirmar que respeta `docs/DESIGN.md` cuando toca UI;
- ejecutar la verificacion definida en el plan;
- documentar resultados en el plan o execution log correspondiente.

Antes de cerrar un incremento:

- criterios de aceptacion cubiertos;
- pruebas definidas ejecutadas o justificadas;
- riesgos residuales documentados;
- artefactos actualizados;
- siguiente retake point claro.

## 9. Politica De Evolucion

Esta constitucion es un documento vivo, pero estable. Cualquier cambio debe:

- explicar la regla modificada;
- indicar SPECs, planes o artefactos afectados;
- actualizar documentos derivados antes de implementar codigo;
- conservar trazabilidad del cambio.

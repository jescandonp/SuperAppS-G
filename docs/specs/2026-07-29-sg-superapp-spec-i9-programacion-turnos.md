# SPEC I9 - Programacion Asistida De Turnos

> Estado: **Aprobada**
> Fecha: 2026-07-29
> Gate: 0 cerrado; Tasks 2 a 10 completadas; Task 11 pendiente
> Fuentes: Constitucion, Arquitectura, Tecnologia, Design y diseño funcional del 2026-07-19.
> Plan tecnico: `docs/superpowers/plans/2026-07-29-sg-programacion-turnos-implementation-plan.md`
> Aprobacion: aprobada el 2026-07-29 por el usuario, en calidad de patrocinador funcional.

Estado del plan tecnico: **APROBADO COMO HOJA DE RUTA DOCUMENTAL** por decision
del usuario.
Estado de aplicacion: **TASK_10_COMPLETADA_TASK_11_PENDIENTE**

Las tres condiciones estan satisfechas. El catalogo queda
`APROBADO_PARA_PARAMETRIZACION`; Gate 0 queda cerrado por Camilo Piedrahita, Gerente
General, segun confirmacion explicita del usuario. Las Tasks 2 a 7 fueron
completadas posteriormente. Las Tasks 8, 9 y 10 tambien fueron completadas; la
Task 11 permanece pendiente y no iniciada.

El catalogo no es ejecutable por el motor hasta completar y validar valores,
unidades, vigencia, alcance, mensajes, responsable y pruebas de cada regla.

## 1. Objetivo

Permitir que Operaciones configure necesidades, genere propuestas deterministicas
y explicables, compare alternativas, gestione excepciones y publique una version
mensual despues de controles humanos. El sistema asiste; no aprueba ni publica
autonomamente.

El motor no publica de forma autonoma.

## 2. Alcance

Incluye plantillas ciclicas, proyectos por puesto y periodo, turnos requeridos,
elegibilidad, propuesta con vacantes visibles, ajuste manual revalidado,
comparacion de versiones, excepciones, aprobacion, publicacion inmutable,
reprogramacion asistida, exportacion y auditoria.

## 3. Contratos Funcionales

1. La misma entrada, version de reglas y parametros produce el mismo resultado.
2. Cada asignacion expone razones; cada vacante conserva los rechazos relevantes.
3. Un ajuste manual vuelve a validar reglas y nunca evita un bloqueo.
4. Una excepcion subsanable exige regla, motivo, responsable y vigencia.
5. Aprobar y publicar son acciones humanas explicitas, con permiso y auditoria.
6. Una version publicada es inmutable; su reemplazo crea otra version.
7. Novedades posteriores generan escenarios comparables, no cambios silenciosos.

## 4. Reglas Y Jerarquia

La jerarquia es: norma colombiana validada por Juridico, politica S&G aprobada,
condicion contractual versionada y parametros del proyecto. El catalogo operativo
solo podra convertirse en fuente ejecutable cuando tenga decisiones aprobadas,
version vigente y todos los campos obligatorios completos y validados. El
catalogo I9 mantiene pendiente esa condicion hasta completar valores, unidades,
vigencia, alcance, mensajes, responsable y pruebas.

Las reglas se clasifican como `BLOQUEANTE`, `SUBSANABLE` o `INFORMATIVA`.
Jornada, descanso, cruces, novedades, ubicacion, requisitos y desviaciones deben
ser explicables. Esta SPEC no inventa umbrales legales numericos.

## 5. Estados

- Proyecto: `BORRADOR`, `ACTIVO`, `CERRADO`.
- Corrida: `EN_COLA`, `PROCESANDO`, `COMPLETADO`,
  `COMPLETADO_CON_VACANTES`, `FALLIDO`.
- Version: `BORRADOR`, `PROPUESTA`, `APROBADA`, `PUBLICADA`, `REEMPLAZADA`,
  `CANCELADA`.
- Asignacion: `ASIGNADA`, `VACANTE`.
- Excepcion: `PENDIENTE`, `APROBADA`, `RECHAZADA`, `VENCIDA`.

Solo una version puede estar `PUBLICADA` por proyecto y periodo. Publicar
reemplaza la anterior sin alterarla.

## 6. Permisos

| Capacidad | ADMIN | OPERACIONES | TH | GERENCIA |
|---|---|---|---|---|
| Consultar | Si | Segun alcance | Segun alcance | Segun alcance |
| Configurar/generar/ajustar | Si | Con permiso | No | No |
| Gestionar excepcion | Si | Con permiso | Consulta/validacion asignada | No |
| Aprobar/publicar | Si | Con permiso explicito | No | No |
| Exportar | Si | Segun alcance | Segun alcance | Segun alcance |

El backend valida permisos; ocultar una accion en UI no constituye seguridad.
Si una misma persona crea, aprueba y publica por limitacion organizacional, el
hecho se marca como autogestionado y queda auditable.

## 7. Modelo Y Limites

I9 posee plantillas, proyectos, turnos requeridos, corridas, versiones,
asignaciones y excepciones. Consume I2 (empleados), I3 (puestos/asignaciones),
I5 (habilitacion), I6 (notificaciones) e I7 (auditoria/dashboard) mediante
identificadores y snapshots. No reasigna propiedad de esos datos.

### 7.1 Enmienda aprobada para configuracion (2026-08-11)

Por aprobacion explicita del usuario, la configuracion previa a la generacion
debe persistir los siguientes datos, sin convertir por ello el catalogo de
reglas en ejecutable:

- cada cobertura de puesto identifica plantilla, cantidad requerida, vigencia,
  ambito semanal y franja horaria de inicio y fin;
- cada excepcion de disponibilidad identifica tipo, periodo, motivo y si es
  bloqueante;
- cada requisito de puesto relaciona el puesto con el tipo de curso,
  acreditacion o requisito, y lo clasifica como `BLOQUEANTE`, `SUBSANABLE` o
  `INFORMATIVA`; la fecha de subsanacion es opcional;
- la configuracion rechaza periodos invertidos, cantidades no positivas,
  textos obligatorios vacios y clasificaciones fuera del catalogo anterior;
- toda mutacion queda auditada en la misma transaccion.

Esta enmienda define estructura y validaciones de integridad. No fija jornadas,
umbrales legales, dias de la semana concretos ni valores regulatorios que no
hayan sido validados por las areas responsables.

## 8. API Conceptual

```text
GET/POST /api/portal/scheduling/templates
GET/POST /api/portal/scheduling/projects
POST     /api/portal/scheduling/projects/{id}/versions
GET      /api/portal/scheduling/versions/{versionId}
PUT      /api/portal/scheduling/versions/{versionId}/assignments/{id}
POST     /api/portal/scheduling/versions/{versionId}/exceptions
POST     /api/portal/scheduling/versions/{versionId}/approve
POST     /api/portal/scheduling/versions/{versionId}/publish
POST     /api/portal/scheduling/versions/{versionId}/replan
GET      /api/portal/scheduling/versions/{versionId}/audit
GET      /api/portal/scheduling/versions/{versionId}/export.{pdf|xlsx}
```

El POST de generacion crea una `schedule version` en estado `PROPUESTA`. Toda
consulta y accion posterior usa la ruta canonica `versions/{versionId}`. Las
mutaciones usan version esperada e idempotencia cuando aplique. Los errores
devuelven codigo, mensaje y razones de negocio.

## 9. Criterios De Aceptacion

1. El catálogo firmado gobierna todas las validaciones y queda en snapshot.
2. Dos corridas iguales producen asignaciones, orden y razones iguales.
3. Ningun candidato bloqueado es asignado; la vacante permanece visible.
4. Ajustes, excepciones, aprobacion, publicacion y exportacion dejan auditoria.
5. Una version publicada no admite UPDATE/DELETE y conserva fuentes/resultados.
6. Seguridad se verifica por endpoint para cada capacidad.
7. Matriz mensual, plantillas, comparacion y excepciones cumplen Design I9.
8. Reprogramacion informa impacto y nunca modifica la publicada.
9. Regresiones criticas I2/I3/I5/I6/I7 y builds quedan correctas.
10. El piloto anonimizado registra cobertura, vacantes, excepciones y cambios.

## 10. Exclusiones

- publicacion o aprobacion autonoma;
- valores legales no validados o codificados desde este borrador;
- optimizacion matematica avanzada, IA generativa o servicios externos;
- nomina, liquidacion, pago de recargos o control de asistencia;
- app de guardas, WhatsApp e integraciones obligatorias con HELIZA;
- reemplazo del modulo fuente de novedades.

## 11. Gate 0 Cerrado

La SPEC esta **Aprobada**. El usuario confirma a Jorge Guzman para Operaciones,
a Carolina Rodriguez Russi para Talento Humano y Juridica, y a Camilo
Piedrahita, Gerente General, para el cierre ejecutivo. Gate 0 esta cerrado y
Task 2 autorizada, pero no iniciada.

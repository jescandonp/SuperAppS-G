# Handoff - Proyecto S&G Super App Piloto TH

**Fecha:** 2026-05-21  
**Workspace:** `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`  
**Objetivo del siguiente tramo:** continuar desde el PRD refinado hacia SPECs modulares para el piloto de Talento Humano de la S&G Super App.

## Contexto resumido

S&G aprobo iniciar un plan piloto con dos quick wins de Talento Humano:

- Certificaciones laborales.
- Alertas de vencimiento de cursos y acreditaciones.

La decision clave es que estos quick wins no se construyen como automatizaciones aisladas. Deben iniciar un **Portal S&G Super App** desde el dia 1, con login, perfiles, datos maestros, trazabilidad, dashboard y notificaciones.

## Decisiones cerradas

- El piloto sera un portal interno administrativo.
- Guardas/empleados no seran usuarios del portal en MVP; seran datos maestros.
- Perfiles MVP: Administrador, Talento Humano, Gerencia/Consulta, Operaciones/Consulta.
- Fuente inicial de datos: Excel + correccion manual controlada.
- HELIZA queda como fuente futura, no dependencia inicial.
- Puesto de servicio es maestro clave desde el piloto.
- La relacion guarda-puesto debe ser historica.
- Salario base viene de carga inicial y debe ser versionado.
- Salario base debe soportar tabla por cargo/vigencia y override por empleado.
- Variables mensuales no son datos estaticos del empleado.
- Variables MVP: carga manual para extras, recargos, auxilios, bonificaciones/otros y observaciones.
- Futuro: carga periodica de variables conectada con novedades de nomina / HELIZA.
- Certificaciones: el portal genera PDF final con vista previa y aprobacion TH.
- Firma: parametrizada, versionada por vigencia, no hardcoded.
- Certificaciones: dos plantillas base iniciales, activo y retirado, con variante por destino/proposito.
- Cursos/acreditaciones: multiples tipos por empleado, historico de renovaciones y estado calculado.
- Umbrales: vencido, critico 0-15, preventivo 16-30, informativo 31-60, al dia >60 dias.
- Guarda con curso/acreditacion vencida queda "No habilitado para servicio", visible a TH y Operaciones/Consulta.
- No hay bloqueo automatico de programacion en MVP.
- Notificaciones: personales y por rol, con lectura, archivo/borrado y trazabilidad de gestion.
- Email a TH incluido si hay SMTP/cuenta institucional; fallback con notificaciones internas y resumen exportable.
- Dashboard unico con widgets por perfil.
- Novedades visible como "Proximamente / En diseno"; se modela como evento transversal, pero no se implementa completo en MVP.
- Stack abierto, con restriccion confirmada: servidor de aplicaciones Windows Server 2012.

## Artefactos creados/modificados

- PRD refinado:
  `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\docs\prd\2026-05-21-sg-super-app-piloto-th-prd.md`

- HTML base para stakeholders:
  `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\SG_PRD_Piloto_TH_SuperApp_v1.html`

- Handoff anterior del roadmap:
  `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\handoff-HhElIf.md`

## Referencias fuente usadas

- `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\Referencias\Matriz de Cursos y Acreditaciones para IA.xlsx`
- `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\Referencias\Novedades de Personal Diaras RRHH - OP-GERENCIA 2026 copia.xlsx`
- `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\Referencias\CERT LUIS CARLOS YOLIS CORREA 2.pdf`
- `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\Referencias\membrete actual CERT RETIRADO ORLANDO ESTEBAN CADENA LONDOÑO 3.pdf`
- Roadmap ejecutivo previo:
  `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\docs\superpowers\specs\2026-05-15-sg-roadmap-ejecutivo-ecosistema-design.md`

## Hallazgos relevantes de archivos

- Matriz cursos/acreditaciones:
  - Tiene hojas `Consulta`, `Consulta NUEVA`, `ENERO 2026`.
  - Campos clave: nombre, cedula, fecha ingreso, cargo, fecha curso, dias vencimiento curso, estado curso, fecha vencimiento acreditacion, dias vencimiento credencial, estado credencial, observaciones.
  - Se observaron registros con credencial sin fecha y estados como `ACTUALIZADO`, `AL DIA`, `PROCESO`.

- Novedades RRHH/Operaciones:
  - Contiene hojas mensuales, listas y personal activo.
  - Campos visibles: cedula, nombre, motivo, fecha ausencia, soporte, observaciones, puesto de servicio.
  - Hay datos con `#N/A`, vacios y mezclas de encabezados/registros; por eso importacion con prevalidacion es requisito fuerte.

- PDFs certificaciones:
  - Hay formato para empleado activo y formato para retirado.
  - Ambos incluyen verificacion por contacto institucional y firma de Laura Rodriguez/Subgerente en los ejemplos.

## HTML stakeholder actual

Archivo: `SG_PRD_Piloto_TH_SuperApp_v1.html`

Contenido:

- Vision del piloto.
- Alcance incluido / preparado para futuro / fuera de alcance.
- Modulos de la iteracion.
- Datos maestros y relaciones.
- Flujos de certificaciones y cursos/acreditaciones.
- Decisiones cerradas.
- Siguientes pasos hacia SPECs.
- Interaccion basica:
  - navegacion lateral;
  - filtros de modulos;
  - ejemplo de bandeja de notificaciones junto al perfil.

Validaciones realizadas:

- Archivo creado correctamente.
- Secciones principales verificadas por busqueda estatica.
- Se reemplazo `findLast` por logica compatible.
- No se pudo hacer screenshot automatizado porque Playwright no esta instalado en el runtime disponible.
- `graphify update .` fallo porque `graphify` no esta disponible en PATH.

## Instrucciones del proyecto

El workspace tiene `AGENTS.md` con reglas Graphify:

- Antes de arquitectura/codigo, leer `graphify-out/GRAPH_REPORT.md`.
- Si se modifica codigo, correr `graphify update .`.
- En esta sesion `graphify update .` fallo por comando no reconocido.

## Siguiente punto recomendado

El siguiente agente deberia continuar con SPECs modulares, en este orden:

1. SPEC arquitectura funcional y datos maestros.
2. SPEC certificaciones laborales y PDF.
3. SPEC cursos/acreditaciones, alertas y notificaciones.
4. SPEC infraestructura/despliegue tras confirmar servidor y stack.

Antes de escribir SPEC tecnica, validar:

- detalles especificos del Windows Server 2012 disponible;
- base de datos permitida;
- acceso y restricciones de instalacion;
- cuenta/canal de correo institucional o SMTP;
- si se requiere guardar soportes documentales en MVP o solo dejar el modelo preparado.

## Skills sugeridas para el siguiente tramo

- `superpowers:brainstorming` si se siguen cerrando decisiones funcionales.
- `to-prd` solo si se necesita regenerar/ampliar PRD.
- `superpowers:writing-plans` para convertir SPECs aprobadas en plan de ejecucion.
- `pdf` si se revisan/generan plantillas PDF.
- `spreadsheets:Spreadsheets` si se profundiza en importacion Excel y validaciones.
- `handoff` si se vuelve a cortar la sesion.

# Demo Checklist - S&G Super App Piloto TH I1-I7

**Fecha base:** 2026-06-11  
**Actualizacion:** 2026-06-12  
**Producto:** S&G Super App  
**Piloto:** Talento Humano  
**Incremento:** I7 - Auditoria, Dashboard y Cierre Piloto  
**Estado:** Checklist de demo creado para cierre piloto  

## 1. Objetivo De La Demo

Demostrar que el piloto Talento Humano consolida un portal interno operativo con autenticacion, datos maestros, importaciones, puestos, certificaciones, cursos/acreditaciones, alertas/notificaciones, dashboard por perfil y auditoria consultable.

La demo no debe presentar WhatsApp, HELIZA, nomina, IA avanzada, inventario, armamento ni novedades funcionales como si estuvieran implementados. Esos temas quedan para backlog o fase siguiente.

## 2. Perfiles De Recorrido

| Perfil | Enfoque de demo | Resultado esperado |
|--------|-----------------|-------------------|
| ADMIN | Salud del piloto, modulos, dashboard amplio, auditoria | Valida control transversal y trazabilidad |
| TH | Empleados, certificaciones, cursos, alertas | Valida operacion principal de Talento Humano |
| GERENCIA | Dashboard ejecutivo, consulta, evidencia de valor | Valida lectura ejecutiva sin edicion |
| OPERACIONES | Habilitacion, puestos, consulta operativa | Valida lectura operativa sin modificar datos TH |

## 3. Preparacion

- [ ] Confirmar backend local disponible cuando la demo sea funcional.
- [ ] Confirmar frontend disponible en preview o build estatico.
- [ ] Confirmar usuarios demo por rol.
- [ ] Confirmar datos de prueba suficientes para empleados, puestos, certificados, cursos y alertas.
- [ ] Confirmar que los limites del piloto se explican al inicio.
- [ ] Confirmar que el fallback local solo se usa si la API no esta disponible.

## 4. Recorrido I1 - Portal Base

- [ ] Iniciar sesion con usuario interno.
- [ ] Mostrar shell administrativo dark/gold.
- [ ] Mostrar navegacion por modulos segun rol.
- [ ] Mostrar perfil activo y contador de notificaciones.
- [ ] Cerrar sesion y confirmar retorno al login.

**Evidencia esperada:** login, shell, rutas internas y rol visible.

## 5. Recorrido I2 - Datos Maestros E Importacion

- [ ] Abrir empleados/guardas.
- [ ] Filtrar empleados por busqueda, estado o completitud.
- [ ] Revisar detalle de empleado.
- [ ] Mostrar historial de cambios cuando aplique.
- [ ] Abrir cargas de datos.
- [ ] Revisar resumen de validos, incompletos, duplicados y erroneos.
- [ ] Mostrar errores exportables o consultables.

**Evidencia esperada:** datos maestros consultables, prevalidacion y trazabilidad de carga.

## 6. Recorrido I3 - Puestos De Servicio

- [ ] Abrir puestos de servicio.
- [ ] Buscar puesto activo.
- [ ] Revisar detalle y asignaciones vigentes.
- [ ] Mostrar asignacion de empleado a puesto.
- [ ] Confirmar lectura operativa para roles de consulta.

**Evidencia esperada:** relacion empleado-puesto y estado vigente/finalizado.

## 7. Recorrido I4 - Certificaciones Laborales

- [ ] Abrir certificaciones.
- [ ] Generar vista previa de certificado para empleado valido.
- [ ] Mostrar aprobacion/generacion segun rol autorizado.
- [ ] Mostrar firmantes administrables por ADMIN.
- [ ] Mostrar certificado generado o historial.
- [ ] Mostrar anulacion si aplica al escenario de demo.

**Evidencia esperada:** snapshot, firmante, PDF/registro generado e historial.

## 8. Recorrido I5 - Cursos Y Acreditaciones

- [ ] Abrir cursos y acreditaciones.
- [ ] Filtrar por estado de cumplimiento.
- [ ] Mostrar estados `VENCIDO`, `CRITICO`, `PREVENTIVO`, `INFORMATIVO` y `AL_DIA`.
- [ ] Mostrar habilitacion `HABILITADO` o `NO_HABILITADO`.
- [ ] Crear o revisar registro de curso segun rol.
- [ ] Mostrar gestion de tipos de curso/acreditacion para ADMIN/TH.

**Evidencia esperada:** reglas de vigencia, habilitacion operativa y gestion TH.

## 9. Recorrido I6 - Alertas Y Notificaciones

- [ ] Mostrar bandeja de notificaciones.
- [ ] Filtrar por estado, severidad y modulo.
- [ ] Marcar notificacion como leida.
- [ ] Archivar notificacion.
- [ ] Abrir panel de alertas.
- [ ] Generar alertas de cursos, importaciones o certificados con rol autorizado.
- [ ] Exportar resumen de notificaciones.
- [ ] Mostrar fallback de correo sin depender de SMTP.

**Evidencia esperada:** bandeja operativa, contador, gestion y fallback.

## 10. Recorrido I7 - Dashboard

- [ ] Abrir dashboard.
- [ ] Mostrar widgets visibles para el rol actual.
- [ ] Mostrar lectura ejecutiva para GERENCIA.
- [ ] Mostrar prioridades operativas para TH.
- [ ] Mostrar habilitacion/puestos para OPERACIONES.
- [ ] Mostrar salud del piloto para ADMIN.
- [ ] Navegar desde un widget con accion interna cuando aplique.

**Evidencia esperada:** widgets por perfil y sin acciones fuera de permiso.

## 11. Recorrido I7 - Auditoria

- [ ] Abrir auditoria.
- [ ] Filtrar por modulo.
- [ ] Filtrar por actor.
- [ ] Filtrar por fecha desde/hasta.
- [ ] Seleccionar evento en tabla compacta.
- [ ] Revisar detalle estructurado.
- [ ] Confirmar que no existen acciones de edicion.

**Evidencia esperada:** eventos con fecha, actor, modulo, accion, entidad y detalle.

## 12. Cierre De Demo

- [ ] Mostrar reporte de cierre piloto.
- [ ] Mostrar backlog priorizado de fase siguiente.
- [ ] Explicar riesgos residuales.
- [ ] Explicar recomendacion de escalamiento.
- [ ] Confirmar que I7 no reabre reglas cerradas de I1-I6.

## 13. Criterios De Exito

- [ ] Los flujos I1-I7 son demostrables con datos de prueba o fallback documentado.
- [ ] Los roles ven solo lectura/accion acorde a permisos.
- [ ] Dashboard y auditoria consolidan la trazabilidad del piloto.
- [ ] El sponsor entiende alcance construido, limites, riesgos y siguiente fase.
- [ ] No se promete funcionalidad excluida por la SPEC I7.

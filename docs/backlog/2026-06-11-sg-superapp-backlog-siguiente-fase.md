# Backlog Priorizado - S&G Super App Fase Siguiente

**Fecha base:** 2026-06-11  
**Actualizacion:** 2026-06-12  
**Producto:** S&G Super App  
**Fuente:** Cierre piloto I7  
**Estado:** Backlog inicial priorizado para decision ejecutiva  

## 1. Criterios De Priorizacion

| Criterio | Lectura |
|----------|---------|
| Valor operativo | Reduce trabajo manual, mejora control o acelera decision |
| Riesgo | Evita fallas de seguridad, datos, cumplimiento o operacion |
| Dependencia | Habilita otros modulos o integraciones |
| Complejidad | Se puede ejecutar sin romper la base actual |
| Evidencia piloto | Surge de I1-I7 y no de una idea aislada |

## 2. Backlog P0 - Cierre Productivo Controlado

| Item | Descripcion | Resultado esperado |
|------|-------------|-------------------|
| Datos demo/productivos controlados | Preparar dataset confiable para presentacion y piloto real | Demo consistente y medicion inicial |
| Despliegue piloto | Definir instalacion en infraestructura S&G sin tocar XAMPP/puertos ocupados | Ambiente controlado |
| Backups y restauracion | Definir politica para PostgreSQL, PDFs y soportes | Riesgo operativo reducido |
| Hardening de seguridad | Revisar sesiones, puertos, roles, permisos y usuarios iniciales | Base lista para usuarios internos |
| Manual operativo inicial | Documentar login, roles, flujos y soporte | Transferencia al equipo S&G |

## 3. Backlog P1 - Profundizacion Talento Humano

| Item | Descripcion | Resultado esperado |
|------|-------------|-------------------|
| Ampliar auditoria | Cubrir mas eventos historicos y acciones de I1-I6 | Trazabilidad mas completa |
| Reportes ejecutivos exportables | Exportar dashboard/cierre a PDF o Excel | Consumo gerencial |
| Parametrizacion de alertas | Ajustar umbrales de vencimiento por tipo de curso/acreditacion | Alertas mas precisas |
| Gestion documental de soportes | Adjuntar y consultar soportes de cursos/acreditaciones | Evidencia centralizada |
| Mejoras de recorrido movil | Ajustes responsive tras prueba manual | Consulta mas robusta |

## 4. Backlog P2 - Operaciones Y Novedades

| Item | Descripcion | Resultado esperado |
|------|-------------|-------------------|
| Novedades operativas MVP | Modelar eventos operativos basicos sin automatizar turnos | Primer puente TH-Operaciones |
| Incidentes y seguimiento | Registrar evento, responsable, estado y evidencia | Trazabilidad operacional |
| Asignaciones con restricciones informativas | Alertar riesgos de asignacion sin bloqueo automatico | Control gradual |
| Vista operativa de puestos | Mejorar tablero de puestos, guardas y habilitacion | Decision diaria de operaciones |

## 5. Backlog P3 - Integraciones

| Item | Descripcion | Resultado esperado |
|------|-------------|-------------------|
| HELIZA discovery | Levantar campos, permisos, frecuencia y mecanismo viable | SPEC de integracion |
| Nomina discovery | Levantar flujo de datos y controles de seguridad | Decision informada |
| SMTP productivo | Validar servidor, credenciales, plantillas y logs | Correo sin depender de fallback |
| Importaciones recurrentes | Definir jobs compatibles con Windows Server 2012 | Actualizacion controlada |

## 6. Backlog P4 - Futuro No MVP

| Item | Descripcion | Condicion de entrada |
|------|-------------|---------------------|
| WhatsApp | Notificaciones o novedades por canal externo | Requiere decision de seguridad y proveedor |
| IA avanzada | Analitica predictiva o asistentes | Requiere datos historicos confiables |
| Inventario | Control de activos | Requiere SPEC propia |
| Armamento | Control especializado | Requiere reglas legales/operativas propias |
| App movil guardas | Acceso para personal operativo externo | Requiere cambio de alcance y seguridad |

## 7. Recomendacion De Secuencia

1. Ejecutar P0 antes de usuarios reales.
2. Ejecutar P1 para robustecer el piloto TH.
3. Preparar SPEC de Novedades/Operaciones solo despues de cerrar P0.
4. Tratar integraciones como discovery antes de implementacion.
5. Mantener SDD: toda iniciativa nueva requiere SPEC, plan, criterios y verificacion.

## 8. Items Explicitamente No Autorizados Sin Nueva SPEC

- WhatsApp productivo.
- HELIZA productivo.
- Nomina productiva.
- IA avanzada.
- Bloqueo automatico de asignaciones.
- Guardas como usuarios del portal.
- Inventario o armamento funcional.

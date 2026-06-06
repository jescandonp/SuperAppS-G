# Plan I4 - Certificaciones Laborales

**Fecha:** 2026-06-05  
**Producto:** S&G Super App  
**Incremento:** I4 - Certificaciones Laborales  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Estado del plan:** Revisado y aprobado  
**Fecha de aprobacion:** 2026-06-05  
**Gate actual:** I4 cerrado tecnicamente; retake autorizado en I5 Gate 0 documental  

## 1. Objetivo

Implementar el modulo de certificaciones laborales para empleados activos y retirados, con firmantes parametrizados, vista previa, aprobacion por Talento Humano, PDF final descargable, snapshot inmutable, historial, anulacion controlada, permisos por rol y auditoria.

I4 termina cuando el flujo completo de certificacion cumpla los 20 criterios de aceptacion de la SPEC I4 sin invadir correo automatico, firma digital certificada, portal externo, QR, HELIZA, nomina ni editor libre de plantillas.

## 2. Documentos Rectores

Orden de autoridad aplicable:

1. `docs/CONSTITUTION.md`
2. `docs/ARCHITECTURE.md`
3. `docs/TECNOLOGIA.md`
4. `docs/DESIGN.md`
5. `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`
6. `docs/specs/2026-05-21-sg-superapp-spec-i4-certificaciones-laborales.md`
7. Este plan

SPECs relacionadas:

- `docs/specs/2026-05-21-sg-superapp-spec-i1-portal-base.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i2-datos-maestros-importacion.md`
- `docs/specs/2026-05-21-sg-superapp-spec-i3-puestos-servicio-asignaciones.md`

## 3. Gate 0

### Decisiones Confirmadas

- I0 ya cerro stack: React SPA + backend .NET compatible + PostgreSQL.
- I1 provee login, roles, permisos, dashboard base, notificaciones y auditoria tecnica.
- I2 provee maestro de empleados, estado laboral, salario base versionado, edicion TH y auditoria de cambios.
- I3 provee puestos/asignaciones, pero I4 solo consume empleado y salario; no depende de puesto para emitir certificados.
- La generacion PDF queda autorizada dentro de I4 usando libreria/mecanismo compatible con .NET 6 y Windows Server 2012.
- El almacenamiento local de PDFs se resolvera con ruta configurable para entorno piloto; no se integra almacenamiento externo.
- La aprobacion en MVP la hace Talento Humano; Gerencia consulta; Administrador configura firmantes; Operaciones no accede.
- El PDF generado conserva snapshot inmutable de datos usados y no se re-renderiza con cambios posteriores.

### Restricciones

- No implementar firma digital certificada.
- No implementar envio automatico por correo.
- No implementar QR ni portal externo de validacion.
- No integrar HELIZA ni nomina.
- No construir editor libre de plantillas desde UI.
- No cambiar stack ni instalar dependencias no compatibles con Windows Server 2012 sin actualizar `docs/TECNOLOGIA.md`.

### Gate De Cierre I4

- [x] Criterios de aceptacion 1-20 cubiertos.
- [x] Suite funcional I4 ejecutada.
- [x] Backend build limpio.
- [x] Frontend build limpio.
- [x] Riesgos residuales documentados.
- [x] Retake point I5 definido.

## 4. Alcance

### Incluido

- Firmantes versionados y vigentes.
- Preparacion de certificacion para activo y retirado.
- Destino/proposito.
- Variables manuales por concepto.
- Vista previa.
- Aprobacion/generacion por TH.
- PDF final descargable.
- Snapshot inmutable.
- Historial y detalle.
- Anulacion con motivo.
- Permisos por rol.
- Auditoria.

### Excluido

- Correo automatico.
- Firma digital certificada.
- Validacion externa.
- QR.
- Integraciones HELIZA/nomina.
- Aprobacion obligatoria de Gerencia.
- Editor de plantillas.

## 5. Diseño Tecnico Propuesto

### Persistencia

Tablas nuevas:

- `certificate_signers`
- `labor_certificates`
- `labor_certificate_variables`
- `labor_certificate_events` o auditoria via `audit_log`

Campos minimos de `labor_certificates`:

- `id`
- `certificate_number`
- `employee_id`
- `certificate_type`
- `purpose`
- `status`
- `snapshot_payload`
- `preview_content`
- `pdf_path`
- `annulment_reason`
- `created_by`
- `approved_by`
- `approved_at`
- `generated_at`
- `annulled_by`
- `annulled_at`
- `created_at`
- `updated_at`

### Contratos API

Endpoints esperados bajo `/api/portal/certificates`:

- `GET /portal/certificates`
- `GET /portal/certificates/{certificateId}`
- `POST /portal/certificates/preview`
- `POST /portal/certificates`
- `POST /portal/certificates/{certificateId}/approve-generate`
- `POST /portal/certificates/{certificateId}/annul`
- `GET /portal/certificates/{certificateId}/download`

Endpoints de firmantes:

- `GET /portal/certificate-signers`
- `POST /portal/certificate-signers`
- `PUT /portal/certificate-signers/{signerId}`
- `POST /portal/certificate-signers/{signerId}/inactivate`

### PDF

- Generar PDF desde HTML/texto controlado en backend.
- Guardar referencia/ruta del archivo generado.
- Descargar como `application/pdf`.
- Snapshot y PDF no cambian si cambia empleado, salario o firmante.

### UI

Modulo `CERTIFICATES`:

- listado con filtros;
- nueva certificacion;
- vista previa;
- detalle/historial;
- configuracion de firmantes para ADMIN;
- acciones por rol.

## 6. Tareas

### Task 1 - Persistencia I4 y permisos base

**Objetivo:** crear tablas, restricciones, permisos y contrato SQL para certificaciones y firmantes.

**Criterios:** 2, 5, 11, 14, 18, 19.

**Aceptacion:**

- [x] Existen tablas de firmantes y certificaciones.
- [x] Numero consecutivo unico queda restringido.
- [x] Firmante vigente se puede consultar por fecha.
- [x] Snapshot JSON queda persistible.
- [x] Permisos I4 quedan registrados para cuatro roles.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI4Persistence.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI4PersistenceClean.ps1`
- [x] `dotnet build`

### Task 2 - Contratos backend de firmantes

**Objetivo:** implementar API para configurar firmantes con vigencia y estado.

**Criterios:** 5, 14.

**Aceptacion:**

- [x] ADMIN crea/edita/inactiva firmantes.
- [x] Nombre y cargo son obligatorios.
- [x] Vigencia desde es obligatoria.
- [x] TH/GERENCIA consultan segun necesidad, pero no configuran.
- [x] OPERACIONES no accede.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI4Signers.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI4Security.ps1`
- [x] `dotnet build`

### Task 3 - Preview de certificacion activa

**Objetivo:** preparar snapshot preliminar y vista previa para empleado activo.

**Criterios:** 1, 3, 5, 6, 7, 8, 17, 18.

**Aceptacion:**

- [x] TH puede previsualizar certificacion activa.
- [x] Activo sin salario base vigente queda bloqueado.
- [x] Ausencia de firmante vigente queda bloqueada.
- [x] Variables manuales opcionales se muestran solo si se ingresan.
- [x] Variables se capturan por concepto y no modifican salario maestro.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI4ActivePreview.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI4SalaryVariables.ps1`
- [x] `dotnet build`

### Task 4 - Preview de certificacion retirada

**Objetivo:** preparar snapshot preliminar y vista previa para empleado retirado.

**Criterios:** 2, 4, 5, 6, 8.

**Aceptacion:**

- [x] TH puede previsualizar certificacion retirada.
- [x] Retirado sin fecha de retiro queda bloqueado.
- [x] Retirado sin motivo de retiro queda bloqueado.
- [x] Variante cesantias/interesado ajusta bloque contextual.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI4RetiredPreview.ps1`
- [x] `dotnet build`

### Task 5 - Aprobacion, generacion PDF y snapshot inmutable

**Objetivo:** aprobar/generar certificado final con PDF descargable y snapshot inmutable.

**Criterios:** 9, 10, 11, 18, 19.

**Aceptacion:**

- [x] TH aprueba y genera PDF final.
- [x] PDF queda disponible para descarga.
- [x] Snapshot conserva empleado, salario, variables, firmante, plantilla/version y usuarios.
- [x] Cambios posteriores del empleado/firmante no alteran certificado generado.
- [x] Numero consecutivo unico se asigna.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI4Generation.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI4SnapshotImmutability.ps1`
- [x] `dotnet build`

### Task 6 - Anulacion, historial y auditoria

**Objetivo:** agregar anulacion con motivo, historial y eventos/auditoria.

**Criterios:** 11, 12, 15, 16.

**Aceptacion:**

- [x] ADMIN/TH anulan con motivo obligatorio.
- [x] Anulacion no borra PDF ni snapshot.
- [x] Historial muestra generacion y anulacion.
- [x] Auditoria registra cambios de estado.
- [x] GERENCIA consulta sin anular.

**Verificacion:**

- [x] `scripts/dev/Verify-SgSuperAppI4Annulment.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI4Audit.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI4Security.ps1`

### Task 7 - Cliente API y tipos frontend

**Objetivo:** agregar tipos TypeScript y cliente API I4.

**Criterios:** 1-20.

**Aceptacion:**

- [x] Tipos cubren certificado, firmante, variables, preview y detalle.
- [x] Cliente API cubre listado, preview, generacion, descarga, anulacion y firmantes.
- [x] Errores HTTP se propagan con mensajes backend.

**Verificacion:**

- [x] `npm run build`

### Task 8 - UI de certificaciones

**Objetivo:** implementar listado, nueva certificacion, preview, detalle y descarga.

**Criterios:** 1, 2, 6, 7, 8, 9, 10, 12, 20.

**Aceptacion:**

- [x] Listado filtra por empleado, tipo, estado y fecha.
- [x] TH crea/previsualiza/aprueba/genera.
- [x] GERENCIA consulta y descarga.
- [x] OPERACIONES no ve modulo.
- [x] Vista previa muestra advertencias de datos faltantes.
- [x] UI respeta estilo dark/gold administrativo.

**Verificacion:**

- [x] `npm run build`
- [x] `scripts/dev/Verify-SgSuperAppI4Security.ps1`

### Task 9 - UI de firmantes y anulacion

**Objetivo:** exponer configuracion ADMIN de firmantes y anulacion ADMIN/TH.

**Criterios:** 5, 14, 15, 16, 20.

**Aceptacion:**

- [x] ADMIN configura firmantes.
- [x] TH no configura firmantes.
- [x] ADMIN/TH anulan con motivo.
- [x] GERENCIA consulta estado ANULADA sin acciones.

**Verificacion:**

- [x] `npm run build`
- [x] `scripts/dev/Verify-SgSuperAppI4Signers.ps1`
- [x] `scripts/dev/Verify-SgSuperAppI4Annulment.ps1`

### Task 10 - Verificacion integral y cierre I4

**Objetivo:** demostrar cumplimiento completo de SPEC I4.

**Criterios:** 1-20.

**Aceptacion:**

- [x] Suite `Verify-SgSuperAppI4*.ps1` completa pasa.
- [x] Backend build pasa.
- [x] Frontend build pasa.
- [x] Matriz final 1-20 queda registrada.
- [x] Riesgos residuales quedan documentados.
- [x] Retake point I5 queda definido.

**Verificacion:**

- [x] `dotnet build apps/sg-superapp-api/sg-superapp-api.csproj`
- [x] `npm run build` en `apps/sg-superapp-web`
- [x] `scripts/dev/Verify-SgSuperAppI4*.ps1`
- [ ] `graphify update .` cuando la herramienta este disponible.

## 7. Checkpoints

### Checkpoint A - Base documental y contratos

Despues de Tasks 1-2:

- [x] persistencia I4 creada;
- [x] permisos I4 registrados;
- [x] firmantes configurables;
- [x] backend build limpio.

### Checkpoint B - Flujo backend completo

Despues de Tasks 3-6:

- [x] preview activo/retirado funciona;
- [x] PDF generado y descargable;
- [x] snapshot inmutable;
- [x] anulacion/auditoria completas.

### Checkpoint C - UI y cierre

Despues de Tasks 7-10:

- [x] UI operativa por rol;
- [x] suite completa I4 pasa;
- [x] matriz 1-20 registrada;
- [x] retake I5 definido.

## 8. Matriz De Trazabilidad

| Criterio SPEC I4 | Tareas |
|------------------|--------|
| 1. TH crea certificacion activo | 3, 8, 10 |
| 2. TH crea certificacion retirado | 4, 8, 10 |
| 3. Bloquea activo sin salario | 3, 10 |
| 4. Bloquea retirado sin fecha/motivo | 4, 10 |
| 5. Exige firmante vigente | 1, 2, 3, 4, 10 |
| 6. Selecciona destino/proposito | 3, 4, 8, 10 |
| 7. Variables manuales | 3, 8, 10 |
| 8. Vista previa | 3, 4, 8, 10 |
| 9. TH aprueba/genera PDF | 5, 8, 10 |
| 10. PDF descargable | 5, 8, 10 |
| 11. Snapshot conservado | 5, 6, 10 |
| 12. Gerencia consulta detalle salarial | 6, 8, 10 |
| 13. Operaciones no accede | 2, 6, 8, 10 |
| 14. Admin configura firmante | 2, 9, 10 |
| 15. Anulacion no elimina PDF | 6, 9, 10 |
| 16. Anulacion exige motivo | 6, 9, 10 |
| 17. Variables por concepto | 3, 7, 8, 10 |
| 18. Activa no muestra variables si no ingresan | 3, 8, 10 |
| 19. Consecutivo unico | 1, 5, 10 |
| 20. UI respeta DESIGN | 8, 9, 10 |

### Matriz Final De Cumplimiento I4

| Criterio SPEC I4 | Estado | Evidencia |
|------------------|--------|-----------|
| 1. TH crea certificacion activo | Cumplido | `Verify-SgSuperAppI4ActivePreview.ps1`, `Verify-SgSuperAppI4Generation.ps1` |
| 2. TH crea certificacion retirado | Cumplido | `Verify-SgSuperAppI4RetiredPreview.ps1` |
| 3. Bloquea activo sin salario | Cumplido | `Verify-SgSuperAppI4ActivePreview.ps1` |
| 4. Bloquea retirado sin fecha/motivo | Cumplido | `Verify-SgSuperAppI4RetiredPreview.ps1` |
| 5. Exige firmante vigente | Cumplido | `Verify-SgSuperAppI4ActivePreview.ps1`, `Verify-SgSuperAppI4RetiredPreview.ps1`, `Verify-SgSuperAppI4Signers.ps1` |
| 6. Selecciona destino/proposito | Cumplido | `Verify-SgSuperAppI4ActivePreview.ps1`, `Verify-SgSuperAppI4RetiredPreview.ps1` |
| 7. Variables manuales | Cumplido | `Verify-SgSuperAppI4SalaryVariables.ps1` |
| 8. Vista previa | Cumplido | `Verify-SgSuperAppI4ActivePreview.ps1`, `Verify-SgSuperAppI4RetiredPreview.ps1` |
| 9. TH aprueba/genera PDF | Cumplido | `Verify-SgSuperAppI4Generation.ps1` |
| 10. PDF descargable | Cumplido | `Verify-SgSuperAppI4Generation.ps1`, `Verify-SgSuperAppI4Annulment.ps1` |
| 11. Snapshot conservado | Cumplido | `Verify-SgSuperAppI4SnapshotImmutability.ps1` |
| 12. Gerencia consulta detalle salarial | Cumplido | `Verify-SgSuperAppI4Security.ps1` |
| 13. Operaciones no accede | Cumplido | `Verify-SgSuperAppI4Security.ps1` |
| 14. Admin configura firmante | Cumplido | `Verify-SgSuperAppI4Signers.ps1` |
| 15. Anulacion no elimina PDF | Cumplido | `Verify-SgSuperAppI4Annulment.ps1` |
| 16. Anulacion exige motivo | Cumplido | `Verify-SgSuperAppI4Annulment.ps1` |
| 17. Variables por concepto | Cumplido | `Verify-SgSuperAppI4SalaryVariables.ps1` |
| 18. Activa no muestra variables si no ingresan | Cumplido | `Verify-SgSuperAppI4SalaryVariables.ps1` |
| 19. Consecutivo unico | Cumplido | `Verify-SgSuperAppI4Persistence.ps1`, `Verify-SgSuperAppI4Generation.ps1` |
| 20. UI respeta DESIGN | Cumplido | `npm run build`, UI dark/gold en `CertificatesPage` |

## 9. Riesgos Y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Generacion PDF incompatible con Windows Server 2012 | Alto | Usar libreria .NET compatible y validar en Task 5 con build/prueba local |
| Ruta de almacenamiento PDF no definida para servidor | Medio | Usar configuracion local parametrizable y documentar variable antes de despliegue |
| Plantillas reales tienen variantes no conocidas | Medio | Versionar plantilla y limitar MVP a activo/retirado + proposito |
| Datos salariales incompletos | Alto | Bloqueo activo sin salario base vigente |
| Cambios posteriores alteran documentos | Alto | Snapshot JSON + PDF persistido inmutable |
| Firma cambia en el tiempo | Medio | Snapshot de firmante usado |
| Browser automation ausente | Medio | Builds, scripts HTTP y recorrido visual manual si Playwright no esta disponible |
| `graphify` no disponible | Bajo | Intentar `graphify update .` y documentar fallo hasta instalar herramienta |

### Riesgos Residuales De Cierre

- Recorrido visual manual desktop/movil pendiente por limitacion local de Vite/esbuild: `Cannot read directory "../../../../..": Access is denied.`
- `graphify update .` pendiente porque `graphify` no esta disponible en PATH.
- Ruta productiva de PDF debe parametrizarse en despliegue mediante `SG_CERTIFICATES_PDF_DIR` y validarse contra permisos del servidor.
- I5 no tiene SPEC ni plan creados; el siguiente trabajo debe iniciar con Gate 0 documental, no con implementacion directa.

## 10. Open Questions

No hay preguntas funcionales abiertas segun SPEC I4.

Decisiones tecnicas de Gate 0:

- [x] Stack I0 desbloquea implementacion I4.
- [x] PDF local configurable queda aceptado para piloto.
- [x] ADMIN configura firmantes, pero no genera certificaciones.
- [x] TH genera y aprueba en MVP.
- [x] Gerencia consulta y descarga, no aprueba.
- [x] Operaciones no accede al modulo.

## 11. Execution Log

### 2026-06-05 - Gate 0 plan I4 creado y aprobado

- Se leyo SPEC I4 y documentos rectores.
- Se confirmo que el bloqueo historico de la SPEC por I0 queda resuelto por `docs/TECNOLOGIA.md`.
- Se creo plan I4 con 10 tareas, checkpoints, matriz 1-20, riesgos y decisiones tecnicas.
- Gate 0 cerrado.
- Retake point: Task 1, persistencia I4 y permisos base.

### 2026-06-05 - Task 1 persistencia I4 y permisos base cerrada

- Se inicio Task 1 con TDD:
  - RED/contrato: `Verify-SgSuperAppI4PersistenceClean.ps1` valido migraciones en esquema aislado;
  - GREEN: se creo migracion `006_i4_labor_certificates.sql`, seed `006_i4_certificates_permissions.sql` y contrato `004_i4_persistence_contract.sql`.
- Persistencia cerrada:
  - `certificate_signers`;
  - `labor_certificates`;
  - `labor_certificate_variables`;
  - consecutivo unico en `labor_certificates.certificate_number`;
  - snapshot `JSONB` obligatorio tipo objeto;
  - restricciones de PDF generado y anulacion con motivo.
- Permisos base I4 cerrados:
  - ADMIN configura firmantes y puede consultar/descargar/anular certificados;
  - TH crea/previsualiza/genera/descarga/anula certificados;
  - GERENCIA consulta/descarga certificados;
  - OPERACIONES no recibe permisos I4 en MVP.
- Verificaciones:
  - `Verify-SgSuperAppI4PersistenceClean.ps1`: correcto;
  - `Verify-SgSuperAppI4Persistence.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 1 cerrada.
- Retake point: Task 2, contratos backend de firmantes.

### 2026-06-05 - Task 2 contratos backend de firmantes cerrada

- Se implementaron contratos backend de firmantes:
  - `CertificateSignerResponse`;
  - `UpsertCertificateSignerRequest`.
- Se agregaron endpoints:
  - `GET /api/portal/certificate-signers`;
  - `GET /api/portal/certificate-signers/{signerId}`;
  - `POST /api/portal/certificate-signers`;
  - `PUT /api/portal/certificate-signers/{signerId}`;
  - `POST /api/portal/certificate-signers/{signerId}/inactivate`.
- Se agregaron metodos de repositorio para listar, consultar, crear, editar e inactivar firmantes.
- Se actualizo catalogo de modulos para exponer `CERTIFICATES` como disponible a roles autorizados.
- Se corrigio matriz de permisos I4 para que GERENCIA consulte firmantes y OPERACIONES no acceda al modulo.
- Verificaciones:
  - `Verify-SgSuperAppI4Persistence.ps1`: correcto;
  - `Verify-SgSuperAppI4PersistenceClean.ps1`: correcto;
  - `Verify-SgSuperAppI4Signers.ps1`: correcto;
  - `Verify-SgSuperAppI4Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 2 cerrada.
- Retake point: Task 3, preview de certificacion activa.

### 2026-06-05 - Task 3 preview de certificacion activa cerrada

- Se implemento contrato backend de preview activo:
  - `CertificatePreviewRequest`;
  - `CertificatePreviewResponse`;
  - `CertificateVariableRequest`;
  - `CertificateVariableResponse`.
- Se agrego `POST /api/portal/certificates/preview`.
- Reglas cerradas:
  - solo TH puede previsualizar;
  - empleado inexistente retorna `404`;
  - empleado no activo retorna conflicto;
  - activo sin salario base vigente retorna conflicto;
  - ausencia de firmante activo/vigente retorna conflicto;
  - variables manuales se devuelven en preview solo si se ingresan;
  - variables manuales no modifican `employee_salary_history`.
- Verificaciones:
  - `Verify-SgSuperAppI4ActivePreview.ps1`: correcto;
  - `Verify-SgSuperAppI4SalaryVariables.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 3 cerrada.
- Retake point: Task 4, preview de certificacion retirada.

### 2026-06-05 - Task 4 preview de certificacion retirada cerrada

- Se extendio el contrato backend de preview para soportar certificado `RETIRADO` sin crear endpoint adicional.
- El preview retirado valida:
  - empleado en estado `RETIRADO`;
  - fecha de retiro;
  - motivo de retiro;
  - firmante activo y vigente;
  - variantes contextuales `CESANTIAS` e `INTERESADO`.
- Se mantuvo la ruta de preview activo con salario vigente y variables manuales sin modificar salario maestro.
- Verificaciones ejecutadas:
  - `Verify-SgSuperAppI4RetiredPreview.ps1`: correcto;
  - `Verify-SgSuperAppI4ActivePreview.ps1`: correcto;
  - `Verify-SgSuperAppI4SalaryVariables.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 4 cerrada.
- Retake point: Task 5, aprobacion, generacion PDF y snapshot inmutable.

### 2026-06-05 - Task 5 aprobacion, generacion PDF y snapshot inmutable cerrada

- Se implemento generacion backend de certificados con:
  - `POST /api/portal/certificates/approve-generate`;
  - `GET /api/portal/certificates/{certificateId}/download`;
  - contrato `LaborCertificateResponse`;
  - PDF local bajo ruta configurable por `SG_CERTIFICATES_PDF_DIR` o carpeta interna `generated-certificates`.
- Se persiste certificado `GENERADA` con numero unico `SG-I4-yyyyMMdd-000000`, snapshot JSONB, PDF y variables.
- El snapshot incorpora datos de empleado, salario, variables, firmante, plantilla/version y usuario generador.
- Se valido que cambios posteriores de empleado/firmante no alteran snapshot ni PDF.
- Verificaciones ejecutadas:
  - `Verify-SgSuperAppI4Generation.ps1`: correcto;
  - `Verify-SgSuperAppI4SnapshotImmutability.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 5 cerrada.
- Retake point: Task 6, anulacion, historial y auditoria.

### 2026-06-05 - Task 6 anulacion, historial y auditoria cerrada

- Se implemento anulacion backend de certificados:
  - `POST /api/portal/certificates/{certificateId}/annul`;
  - motivo obligatorio;
  - permisos `CERTIFICATES/ANNUL`;
  - estado `ANULADA`, `annulment_reason`, `annulled_by`, `annulled_at`.
- Se mantiene PDF descargable para certificados anulados.
- Se expuso historial minimo:
  - `GET /api/portal/certificates/{certificateId}/history`;
  - eventos desde `audit_log` para generacion y anulacion.
- Se agregaron contratos `AnnulCertificateRequest` y `LaborCertificateHistoryResponse`.
- Verificaciones ejecutadas:
  - `Verify-SgSuperAppI4Annulment.ps1`: correcto;
  - `Verify-SgSuperAppI4Audit.ps1`: correcto;
  - `Verify-SgSuperAppI4Security.ps1`: correcto;
  - backend `dotnet build`: correcto, 0 advertencias y 0 errores.
- Task 6 cerrada.
- Retake point: Task 7, cliente API y tipos frontend.

### 2026-06-05 - Task 7 cliente API y tipos frontend cerrada

- Se agregaron tipos TypeScript I4:
  - firmantes;
  - preview;
  - variables;
  - certificados;
  - historial;
  - anulacion.
- Se extendio `portalApi.ts` con cliente I4:
  - firmantes;
  - listado/detalle futuro de certificados;
  - preview;
  - aprobacion/generacion;
  - descarga PDF;
  - anulacion;
  - historial.
- Se alineo `getJson` para propagar mensajes de error del backend igual que `sendJson`.
- Verificacion ejecutada:
  - frontend `npm run build`: correcto.
- Task 7 cerrada.
- Retake point: Task 8, UI de certificaciones.

### 2026-06-05 - Task 8 UI de certificaciones cerrada tecnicamente

- Se implemento UI I4 de certificaciones en React:
  - listado con filtros por empleado, tipo, estado y fechas;
  - detalle con preview persistido, estado, firmante, generador e historial;
  - descarga de PDF;
  - preview y generacion para TH;
  - anulacion para ADMIN/TH sobre certificados generados;
  - consulta/descarga para GERENCIA.
- Se conecto el modulo `certificates` al shell de la aplicacion.
- Se agregaron endpoints backend de soporte para UI:
  - `GET /api/portal/certificates`;
  - `GET /api/portal/certificates/{certificateId}`.
- La exposicion de modulo por rol queda gobernada por permisos backend: ADMIN/TH/GERENCIA acceden y OPERACIONES no ve modulo.
- Verificaciones ejecutadas:
  - frontend `npm run build`: correcto;
  - backend `dotnet build apps/sg-superapp-api/sg-superapp-api.csproj`: correcto;
  - `Verify-SgSuperAppI4Security.ps1`: correcto.
- Recorrido visual local queda pendiente por limitacion del entorno: Vite/esbuild fallo al abrir servidor dev con `Cannot read directory "../../../../..": Access is denied.`
- Task 8 cerrada tecnicamente.
- Retake point: Task 9, UI de firmantes y anulacion.

### 2026-06-05 - Task 9 UI de firmantes y anulacion cerrada tecnicamente

- Se agrego administracion visual de firmantes para ADMIN dentro del modulo de certificaciones:
  - listado de firmantes;
  - creacion;
  - edicion;
  - inactivacion;
  - vigencias, cargo, firma y notas.
- TH no recibe UI de configuracion de firmantes y conserva solo flujo de preview/generacion.
- GERENCIA conserva consulta/descarga sin acciones operativas.
- La anulacion ADMIN/TH sigue disponible desde el detalle de certificados generados y mantiene motivo obligatorio por backend.
- Verificaciones ejecutadas:
  - frontend `npm run build`: correcto;
  - `Verify-SgSuperAppI4Signers.ps1`: correcto;
  - `Verify-SgSuperAppI4Annulment.ps1`: correcto.
- Task 9 cerrada tecnicamente.
- Retake point: Task 10, verificacion integral y cierre I4.

### 2026-06-05 - Task 10 verificacion integral y cierre I4

- Se ejecuto suite completa `Verify-SgSuperAppI4*.ps1` con API activa:
  - `Verify-SgSuperAppI4ActivePreview.ps1`: correcto;
  - `Verify-SgSuperAppI4Annulment.ps1`: correcto;
  - `Verify-SgSuperAppI4Audit.ps1`: correcto;
  - `Verify-SgSuperAppI4Generation.ps1`: correcto;
  - `Verify-SgSuperAppI4Persistence.ps1`: correcto;
  - `Verify-SgSuperAppI4PersistenceClean.ps1`: correcto;
  - `Verify-SgSuperAppI4RetiredPreview.ps1`: correcto;
  - `Verify-SgSuperAppI4SalaryVariables.ps1`: correcto;
  - `Verify-SgSuperAppI4Security.ps1`: correcto;
  - `Verify-SgSuperAppI4Signers.ps1`: correcto;
  - `Verify-SgSuperAppI4SnapshotImmutability.ps1`: correcto.
- Builds finales:
  - backend `dotnet build apps\sg-superapp-api\sg-superapp-api.csproj`: correcto, 0 advertencias y 0 errores;
  - frontend `npm run build`: correcto.
- Se registro matriz final I4 1-20 como cumplida.
- Se documentaron riesgos residuales:
  - recorrido visual manual pendiente por limitacion local de Vite/esbuild;
  - `graphify update .` pendiente por herramienta no disponible;
  - validacion de ruta PDF productiva pendiente para despliegue.
- I4 queda cerrado tecnicamente.
- Retake point: I5 Gate 0 documental para crear/revisar SPEC y plan de Cursos y acreditaciones.

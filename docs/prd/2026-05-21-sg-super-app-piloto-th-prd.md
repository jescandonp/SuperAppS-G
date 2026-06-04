# PRD - S&G Super App Piloto Talento Humano

**Fecha:** 2026-05-21  
**Cliente:** Seguridad & Gestion Ltda.  
**Producto:** S&G Super App  
**Fase:** Piloto interno administrativo  
**Quick wins:** Certificaciones laborales y alertas de cursos/acreditaciones  
**Estado:** Borrador refinado para bajar a SPECs  

---

## Problem Statement

Seguridad & Gestion gestiona procesos criticos de Talento Humano, Operaciones y control administrativo con Excel, documentos fisicos, verificaciones manuales y trazabilidad limitada. En Talento Humano, la generacion de certificaciones laborales exige recopilar datos desde varias fuentes y producir documentos manualmente. El seguimiento de cursos obligatorios y acreditaciones depende de una matriz en Excel revisada manualmente, con riesgo de que un guarda preste servicio con requisitos vencidos.

El piloto aprobado debe resolver dos dolores inmediatos de Talento Humano, pero no puede nacer como automatizaciones aisladas. Debe ser la punta de lanza de la S&G Super App: un portal interno con login, perfiles, datos maestros, trazabilidad y una arquitectura preparada para conectar en iteraciones futuras con novedades, puestos de servicio, armamento, inventario, HELIZA, nomina y Operaciones.

---

## Solution

Construir un portal web interno para el piloto de la S&G Super App. El portal inicia con usuarios administrativos, perfiles por rol, dashboard comun con widgets segun permisos, modulo de notificaciones, carga inicial de datos maestros y dos modulos funcionales de Talento Humano:

- certificaciones laborales para empleados activos y retirados;
- alertas de vencimiento de cursos obligatorios y acreditaciones.

El portal debe permitir carga inicial desde Excel y correccion manual controlada. HELIZA se considera fuente externa futura, no dependencia del MVP. Los guardas/empleados, puestos de servicio, asignaciones, estructura salarial, cursos, acreditaciones y certificaciones generadas deben quedar modelados como entidades reutilizables del ecosistema.

El piloto sera de uso interno administrativo. Los guardas y empleados no tendran usuario en esta fase; seran entidades maestras consultadas y gestionadas por los perfiles internos.

---

## User Stories

1. As an Administrador, I want to create and manage internal users, so that access to the portal is controlled from the pilot.
2. As an Administrador, I want to assign roles to users, so that each profile only sees and edits the information that corresponds to its responsibility.
3. As an Administrador, I want to configure active signers for labor certificates, so that certificate templates do not depend on hardcoded names.
4. As an Administrador, I want signer configuration to have validity dates, so that historical certificates preserve the signer used at issuance time.
5. As an Administrador, I want to manage basic catalogues, so that roles, statuses, course types, accreditation types and service posts remain consistent.
6. As a Talento Humano user, I want to upload employee data from Excel, so that the pilot can start from the current working matrices.
7. As a Talento Humano user, I want the import process to prevalidate records, so that errors are detected before corrupting master data.
8. As a Talento Humano user, I want to see valid, incomplete, duplicate and erroneous records before importing, so that I can decide what to correct or accept.
9. As a Talento Humano user, I want to download or review import errors, so that I can clean the source file or correct the portal data.
10. As a Talento Humano user, I want the system to keep import history, so that every data load has traceability.
11. As a Talento Humano user, I want to manage employees/guardas as master records, so that certificates, courses and operational queries use the same employee base.
12. As a Talento Humano user, I want to classify employees as active or retired, so that the system selects the correct certification flow.
13. As a Talento Humano user, I want to register employment entry dates, exit dates and exit reasons, so that retired employee certificates can be generated correctly.
14. As a Talento Humano user, I want to maintain position/cargo information, so that certifications and operational views reflect the employee function.
15. As a Talento Humano user, I want each guarda to have a current service post assignment, so that the pilot connects from day one with the operational structure.
16. As an Operaciones/Consulta user, I want to consult the current service post of a guarda, so that operational decisions use current assignment information.
17. As an Operaciones/Consulta user, I want to see whether a guarda is enabled for service, so that vencido course/accreditation restrictions are visible.
18. As a Talento Humano user, I want service post assignment to be historical, so that changes over time are not lost.
19. As a Talento Humano user, I want salary base data to come from the initial employee load, so that active employee certificates can use a controlled baseline.
20. As a Talento Humano user, I want salary base values to have validity periods, so that normative or negotiated changes are traceable.
21. As a Talento Humano user, I want to enter monthly variable values manually for certificates, so that extras and allowances can be reflected during the pilot.
22. As a Talento Humano user, I want future periodic loads of variable values to be supported conceptually, so that the model can later connect with payroll novelties.
23. As a Talento Humano user, I want certificate generation to store a snapshot of values used, so that later changes do not alter previously issued documents.
24. As a Talento Humano user, I want to generate a labor certificate for an active employee, so that manual Word/PDF preparation is reduced.
25. As a Talento Humano user, I want to generate a labor certificate for a retired employee, so that the correct legal and operational text is used.
26. As a Talento Humano user, I want to preview a certificate before final generation, so that errors can be corrected before issuance.
27. As a Talento Humano user, I want to approve the certificate before download, so that issuance remains controlled inside TH.
28. As a Talento Humano user, I want the portal to generate the final PDF with letterhead and configured signer, so that the quick win eliminates repetitive manual document work.
29. As a Gerencia/Consulta user, I want to consult generated certificates, so that I can review activity and traceability without editing documents.
30. As a Talento Humano user, I want every generated certificate to store who generated it and when, so that audit history is available.
31. As a Talento Humano user, I want to manage multiple course and accreditation types per employee, so that the model is not limited to one current course.
32. As a Talento Humano user, I want to see historical renewals for each course/accreditation, so that previous compliance cycles are visible.
33. As a Talento Humano user, I want course/accreditation status to be calculated from dates, so that the system consistently classifies vencido, critico, preventivo, informativo and al dia.
34. As a Talento Humano user, I want alerts for vencido and upcoming vencimiento, so that renewals can be managed before service risk appears.
35. As an Operaciones/Consulta user, I want to see if a guarda has vencido requirements, so that I know the employee is not enabled for service.
36. As a Talento Humano user, I want the system to mark a guarda with vencido course/accreditation as no habilitado para servicio, so that the compliance restriction is explicit.
37. As a Talento Humano user, I want the portal to send email alerts to TH, so that critical issues are not only visible inside the portal.
38. As a Talento Humano user, I want a portal alert panel, so that daily compliance work can be reviewed from one place.
39. As an internal user, I want a notification icon/count near my profile, so that important events are visible when I enter the system.
40. As an internal user, I want to mark notifications as read, so that my notification tray stays manageable.
41. As an internal user, I want to delete or archive notifications, so that old notifications do not block daily work.
42. As a Talento Humano role user, I want shared role notifications, so that any authorized TH user can see important TH alerts.
43. As an Operaciones/Consulta role user, I want role notifications relevant to operations, so that compliance constraints are visible to the area.
44. As the system owner, I want role notifications to track who handled them, so that shared alerts have accountability.
45. As a Gerencia/Consulta user, I want a dashboard with consolidated indicators, so that I can monitor pilot value without entering operational forms.
46. As a Talento Humano user, I want dashboard widgets for vencimientos, certificates and imports, so that my daily priorities are visible.
47. As an Operaciones/Consulta user, I want dashboard widgets for no habilitado guards and service post assignments, so that future operational processes can connect to the same data.
48. As an Administrador, I want dashboard widgets for users, configuration and data loads, so that platform health is visible.
49. As a project sponsor, I want a visible Novedades module marked as proximamente/en diseno, so that the portal communicates the ecosystem roadmap from the pilot.
50. As a future product team, I want the data model to anticipate RRHH and operational novelties, so that the next iteration can reuse employees, posts, statuses and notification patterns.

---

## Implementation Decisions

- The pilot will be a portal from day one, not isolated scripts or one-off automations.
- The pilot is internal administrative only. Guardas/empleados are master records, not active portal users.
- The initial roles are Administrador, Talento Humano, Gerencia/Consulta and Operaciones/Consulta.
- The initial data source is Excel import plus controlled manual edits. HELIZA will be evaluated later as an integration source.
- The stack remains open, but the application server is confirmed as Windows Server 2012. Technical SPECs must account for this constraint.
- The portal must be deployable as an internal web application with a relational database and login with local users for the pilot.
- The technical SPEC must include an infrastructure discovery checkpoint before committing to runtime, database engine, deployment model and background job strategy.
- Because Windows Server 2012 is confirmed, the implementation should avoid technology choices that require unsupported OS capabilities, hard-to-maintain runtimes or security configurations unavailable on that server.
- Employee/guarda is a master entity reused by certifications, courses/accreditations, service post assignment and future novelties.
- Service post is a required master concept from the pilot because it links the guarda to the operational structure.
- Service post assignment must be historical, with start/end dates and current status.
- Salary base belongs to a versioned salary structure loaded initially from employee data.
- Salary base must support two levels: a general salary table by cargo/vigencia when applicable and an employee-specific salary override when the real value differs.
- Monthly variables such as extras or additional concepts are not static employee attributes.
- For the pilot, monthly variables may be entered manually when generating or preparing a certificate.
- Manual monthly variables should initially support extras, recargos, auxilio de transporte when applicable, bonificaciones/otros auxilios and free-form observations.
- The model should support a future periodic load of salary variables connected with payroll novelties.
- Certificate generation stores a snapshot of salary base, variables, employee data, signer and template values used at issuance time.
- Certificates for active and retired employees are separate flows/templates.
- Certificate templates should support an initial active certificate and an initial retired certificate, with a template variant field for destination or purpose such as entidad financiera, cesantias, cliente, tramite general or interesado.
- The portal generates the final PDF with letterhead and configured signer after TH preview and approval.
- Talento Humano can generate and approve certificates during the pilot. Gerencia does not approve each certificate.
- Signer data is configurable and versioned by validity period.
- Course/accreditation tracking supports multiple types per employee.
- Course/accreditation renewals are historical; the current state is calculated from the latest applicable validity.
- Courses and accreditations should allow optional support attachments in the data model, but attachment upload can be implemented after the first MVP release if needed.
- Alert thresholds are: vencido if date is before today; critico 0-15 days; preventivo 16-30 days; informativo 31-60 days; al dia over 60 days.
- A guarda with vencido course/accreditation is marked no habilitado para servicio, visible to TH and Operaciones/Consulta.
- The pilot does not automatically block shift scheduling because scheduling is outside MVP scope.
- Notifications are both personal and role-based.
- Notifications support read/unread and archive/delete actions.
- Role notifications track who handled or managed the notification.
- Initial notification triggers include critical vencimientos, vencido courses/accreditations, import errors and certificate generation/approval.
- Direct notifications to guardas and WhatsApp are future iterations.
- Email alerts to Talento Humano are included in the MVP if an institutional SMTP/account is available. If email service is not available at deployment time, the portal must still generate internal notifications and an exportable/sendable alert summary.
- Dashboard is one common base with widgets controlled by role/permissions.
- The visible portal menu includes Inicio/Dashboard, Empleados/Guardas, Puestos de Servicio, Cursos y Acreditaciones, Certificaciones Laborales, Alertas, Notificaciones, Cargas de Datos, Configuracion and Novedades as proximamente/en diseno.
- Import prevalidation is a transversal module, not only a TH utility.
- Import prevalidation must classify records as valid, incomplete, duplicate or erroneous before final import.
- The system keeps import history and supports review/export of errors.
- Audit and generated records should be retained indefinitely during the pilot unless S&G defines a formal retention policy. The model must support later retention rules without deleting historical traceability by default.
- Novedades should be modeled as a transversal event concept in the PRD and data design, but the functional module remains outside the pilot.

---

## Brainstorming Questions Resolved

1. **Infrastructure real**
   - Decision: keep stack open and add an infrastructure discovery checkpoint before technical SPECs.
   - Working assumption: internal web app, relational database, local pilot users and deployability on the available S&G server.
   - Confirmed constraint: application server is Windows Server 2012.
   - Risk: Windows Server 2012 constrains runtime choices, security posture and maintainability.

2. **Base salarial**
   - Decision: salary base is versioned and supports both cargo/vigencia tables and employee-specific values.
   - Reason: annual normative increases may apply broadly, but individual negotiations or employee-specific conditions may exist.

3. **Variables mensuales**
   - Decision: variables are not static employee attributes.
   - MVP input: manual entry for extras, recargos, auxilio de transporte when applicable, bonificaciones/otros auxilios and observations.
   - Future input: periodic load connected to payroll novelties or HELIZA/nómina source.

4. **Plantillas de certificacion**
   - Decision: start with two base templates: active employee and retired employee.
   - Extension: include a destination/purpose variant so the wording can adapt without creating a new module.

5. **Soportes documentales**
   - Decision: the data model supports optional attachments for courses/accreditations and certificate evidence.
   - MVP priority: generated certificate PDFs and source data traceability are mandatory; attachment upload can be phased if needed.

6. **Correo**
   - Decision: include email alerts to Talento Humano when institutional email/SMTP is available.
   - Fallback: internal notification center plus exportable alert summary if email setup is not ready.

7. **Retencion y auditoria**
   - Decision: retain generated certificates, imports, notification history and master data changes indefinitely during the pilot.
   - Future: add formal retention rules when S&G defines legal/compliance policy.

8. **Novedades futuras**
   - Decision: model novedades as a transversal event concept from the PRD/design phase.
   - Scope: visible menu entry as proximamente/en diseno; no full implementation in MVP.

---

## Proposed Deep Modules

- **Identity and Access Module:** users, roles, permissions and session entry.
- **Master Data Module:** employees/guardas, service posts, assignments, catalogues and controlled edits.
- **Import and Validation Module:** Excel ingestion, prevalidation, error classification, approval and import history.
- **Certification Module:** certificate request, preview, approval, PDF generation, signer configuration and issuance history.
- **Compensation Snapshot Module:** salary base validity, manual variables and certificate value snapshots.
- **Courses and Accreditation Module:** types, renewals, vencimiento calculation, historical records and service enablement.
- **Alert and Notification Module:** alert rules, role/personal notifications, read/archive/delete and email dispatch.
- **Dashboard Module:** shared dashboard shell and role-based widgets.
- **Audit Module:** traceability for imports, certificate generation, approvals, notification handling and relevant master data changes.
- **Novedades Discovery Module:** visible future module and preliminary domain model for RRHH/operational events.

---

## Testing Decisions

- Tests should verify external behavior and business outcomes, not implementation details.
- The import module should be tested with valid, duplicate, incomplete and erroneous Excel-like inputs.
- The certification module should be tested for active and retired employee flows, including preview, approval, PDF generation trigger and immutable snapshot.
- The signer configuration should be tested for active signer selection by validity date.
- The compensation snapshot module should be tested to ensure later salary changes do not mutate historical certificates.
- The course/accreditation module should be tested for multiple types, renewal history and status calculation by date thresholds.
- Service enablement should be tested so that vencido requirements mark the guarda as no habilitado para servicio.
- Notification tests should cover personal notifications, role notifications, read state, archive/delete and handler traceability.
- Permission tests should cover read/edit boundaries for Administrador, Talento Humano, Gerencia/Consulta and Operaciones/Consulta.
- Dashboard tests should verify that widgets are visible according to role permissions.
- Audit tests should verify that imports, certificate generation and notification handling record user/time/action.

---

## Out of Scope

- Guardas/empleados as portal users.
- Direct notifications to guardas.
- WhatsApp notifications.
- Automatic shift scheduling.
- Automatic blocking of scheduling.
- Full novedades module implementation.
- Full inventory/dotaciones module.
- Armamento management implementation.
- HELIZA integration.
- Payroll/nomina integration.
- Automatic periodic salary variable import.
- Mobile field application for guards.
- Advanced analytics or predictive AI.
- Public/client-facing portal.

---

## Further Notes

- The pilot should preserve the S&G ecosystem vision: every quick win must create reusable data for future modules.
- Novedades is strategically important and should be modeled early, but it is not part of the functional MVP.
- The Excel files shared show data quality risks such as missing identifiers, blank dates, mixed records and manual status conventions. Import prevalidation is therefore a core requirement, not a nice-to-have.
- The certificate PDFs shared confirm that active and retired certificates require distinct templates and wording.
- The course/accreditation matrix confirms the need for historical renewals, calculated statuses and vencimiento-driven prioritization.
- Infrastructure must be validated before technical SPECs. The application server is Windows Server 2012, so stack selection must account for runtime compatibility, security posture and maintainability.
- No issue tracker is currently configured in this workspace, so this PRD is published as a local project artifact and can later be converted into issues.

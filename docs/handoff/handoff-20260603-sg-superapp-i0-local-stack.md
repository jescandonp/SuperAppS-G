# Handoff - S&G Super App I0 / Stack Y Ambiente Local

Fecha: 2026-06-03  
Workspace: `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G`

## Contexto

El proyecto S&G Super App viene de una fase PRD/SDD para un piloto interno de Talento Humano con dos quick wins: certificaciones laborales y alarmas de vencimiento de cursos/acreditaciones. El piloto debe ser la punta de lanza de una Super App modular para Seguridad y Gestion.

La metodologia base es SDD. Ya existen documentos base y SPECs; no iniciar implementacion sin revisar `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, las SPECs activas y el plan I0.

## Instrucciones De Proyecto

Leer `graphify-out/GRAPH_REPORT.md` antes de responder preguntas de arquitectura/codigo. El reporte destaca comunidades de diseno S&G, identidad dark/gold y estrategia S&G. Si se modifican archivos de codigo en esta sesion, intentar `graphify update .`; en sesiones previas `graphify` no estaba disponible en PATH.

## Estado Tecnico I0

Artefactos principales:

- `docs/TECNOLOGIA.md`
- `docs/plans/i0-ficha-tecnica-servidor.md`
- `docs/plans/i0-matriz-decision-stack.md`
- `docs/plans/2026-05-21-sg-superapp-i0-descubrimiento-tecnico-plan.md`
- `docs/plans/i0-ambiente-desarrollo-local.md`
- `scripts/i0-server-validation/`
- `scripts/i0-local-dev/Check-SGLocalDev.ps1`

Servidor S&G validado:

- Equipo: `SERVIDORGESTION`
- SO: Windows NT `6.3.9600.0`, familia Windows Server 2012/2012 R2; WMI falla y no debe usarse para cierre tecnico.
- Capacidad: ~8 GB RAM, 4 procesadores logicos, discos fijos C/E/F/G con aprox. 5 TB totales y 1.43 TB libres.
- PowerShell: 4.0.
- IIS: no detectado.
- .NET: Framework 4.8.03761 y .NET Runtime/Desktop Runtime 6.0.10 x86.
- XAMPP: PHP 5.6.20, Apache en `C:\xampp\apache\bin\httpd.exe`, MariaDB/MySQL 10.1.13 en `C:\xampp\mysql\bin\mysqld.exe`.
- Puertos ocupados: 80/443 por Apache XAMPP; 3306 por MariaDB/MySQL XAMPP.
- Firewall: perfil dominio activo con entrada bloqueada y salida permitida.
- Seguridad: Kaspersky Small Office Security instalado; falta validar excepciones.
- WMI: servicio `winmgmt` corre, pero repositorio falla con `0x80041002`.

Conclusion servidor: no tocar XAMPP ni reutilizar 80/443/3306 sin decision explicita. Preferir despliegue piloto en puerto separado y sin Node.js productivo.

## Stack Decidido/Preliminar

Decision preliminar documentada:

- Frontend: React SPA recomendado; Angular queda como alternativa si el equipo mantenedor prefiere Angular por experiencia.
- Backend: .NET compatible con servidor actual, inicialmente pensando en .NET Framework 4.8 / ASP.NET Web API por compatibilidad.
- DB: PostgreSQL recomendado, preferiblemente aislado. No usar MariaDB antigua de XAMPP como primera opcion.
- Integracion: API REST.
- Despliegue: frontend compilado como archivos estaticos; backend en puerto separado; PostgreSQL como servicio separado si es aprobado.

Razonamiento: React permite Super App modular y build estatico sin instalar Node.js en produccion. PostgreSQL evita depender de MariaDB/XAMPP antigua. .NET es la familia de menor friccion con la infraestructura actual.

## Ambiente Local

Se creo y corrigio `scripts/i0-local-dev/Check-SGLocalDev.ps1`.

Ultimo resultado local:

- Git: OK, `2.50.1.windows.1`
- Node.js: OK, `v22.16.0`
- npm: OK, `11.12.0`
- PostgreSQL client: OK, `psql (PostgreSQL) 18.4` en `C:\Program Files\PostgreSQL\18\bin\psql.exe`
- PostgreSQL local: OK, `localhost:5432` reachable
- .NET Framework 4.8 runtime: OK, Release `533509`
- Visual Studio / Build Tools: parcial, Build Tools 2019 detectado
- DBeaver: opcional/falta

El ambiente local ya es suficiente para iniciar configuracion de base de datos y scaffolding inicial. Sigue recomendado instalar Visual Studio 2022 Community o confirmar IDE equivalente para desarrollo backend comodo.

## Estado De Documentacion

Se actualizaron:

- `docs/TECNOLOGIA.md`: decision frontend SPA, React recomendado, evidencia servidor, reglas provisionales.
- `docs/plans/i0-matriz-decision-stack.md`: React SPA + .NET + PostgreSQL como inclinacion preliminar; PHP/XAMPP descartado como stack principal sin hardening.
- `docs/plans/i0-ficha-tecnica-servidor.md`: evidencia tecnica del servidor.
- `docs/plans/i0-ambiente-desarrollo-local.md`: guia de instalacion y validacion local.
- `docs/plans/2026-05-21-sg-superapp-i0-descubrimiento-tecnico-plan.md`: execution log con validaciones de servidor, stack y ambiente local.

## Pendientes Inmediatos

1. Definir si se instala Visual Studio 2022 Community o si Build Tools 2019 + editor actual basta para I1.
2. Crear base local `sg_superapp_dev`, usuario `sg_app` y esquema inicial cuando empiece scaffolding.
3. Cerrar formalmente I0 con decision de stack en `docs/TECNOLOGIA.md` y `docs/plans/i0-matriz-decision-stack.md`.
4. Preparar SPEC/plan de I1 si el usuario confirma avanzar a implementacion: Portal Base con login, roles, shell React, API backend, DB inicial y health checks.
5. Mantener fuera de alcance: integracion HELIZA, nomina, app movil, WhatsApp, IA generativa, tocar XAMPP existente.

## Skills Recomendadas Para La Siguiente Sesion

- `agent-skills:spec-driven-development`: antes de implementar I1.
- `superpowers:writing-plans`: para plan ejecutable de I1.
- `superpowers:executing-plans`: si se aprueba ejecutar el plan.
- `agent-skills:frontend-ui-engineering`: para shell React y design system S&G.
- `agent-skills:api-and-interface-design`: para contratos API REST y modelos.
- `agent-skills:security-and-hardening`: para login, roles, contrasenas, sesiones y configuracion de secrets.

## Retake Point

Continuar desde cierre I0. Recomendacion concreta: cerrar decision como **React SPA + backend .NET compatible + PostgreSQL**, luego preparar SPEC/plan I1 para scaffolding del portal base y base de datos local. No tocar XAMPP del servidor.

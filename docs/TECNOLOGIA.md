# Tecnologia - S&G Super App

> Estado: cierre tecnico I0 completado; stack aprobado para entrada a I1.
> Fuente rectora: `docs/CONSTITUTION.md` y `docs/ARCHITECTURE.md`.
> Alcance: restricciones, decisiones confirmadas y criterios de seleccion tecnologica.

## 1. Coordenadas Del Sistema

| Elemento | Valor |
|----------|-------|
| Sistema | `S&G Super App` |
| Cliente | Seguridad & Gestion Ltda. |
| Piloto | Talento Humano |
| Modulos MVP | Certificaciones laborales, cursos/acreditaciones, alertas/notificaciones |
| Servidor de aplicaciones | Windows Server 2012 |
| Stack final | React SPA + backend .NET compatible con Windows Server 2012 + API REST |
| Base de datos final | PostgreSQL en instancia separada para el piloto |
| Frontend objetivo | SPA robusta: React recomendado; Angular alternativa valida segun equipo |
| Integracion HELIZA | Futuro |
| Integracion nomina | Futuro |

## 2. Restricciones Confirmadas

- El servidor de aplicaciones es Windows Server 2012.
- El piloto es interno administrativo.
- El stack de entrada a I1 queda definido por cierre I0.
- No cambiar tecnologia aprobada sin actualizar este documento, la SPEC afectada y el plan correspondiente.
- La solucion debe poder desplegarse y mantenerse en la infraestructura real de S&G.
- Las integraciones con HELIZA y nomina no son obligatorias en MVP.
- El frontend debe pensarse como una SPA mantenible y escalable, no como HTML manual, porque la Super App crecera por modulos y perfiles.

## 3. Criterios De Seleccion Tecnologica

La tecnologia elegida debe:

- ser compatible con Windows Server 2012;
- tener runtime mantenible en esa infraestructura;
- permitir autenticacion interna;
- soportar base de datos relacional;
- permitir generacion de PDF;
- permitir importacion Excel;
- permitir envio de correo o fallback;
- permitir tareas programadas o jobs;
- facilitar auditoria;
- ser operable por el equipo responsable;
- minimizar dependencias dificiles de instalar.

## 4. Decisiones Cerradas En I0

| Area | Decision cerrada |
|------|------------------|
| Frontend | React SPA como opcion aprobada para I1; Angular queda fuera del camino principal salvo cambio formal |
| Backend | Backend .NET compatible con Windows Server 2012, privilegiando compatibilidad de despliegue y soporte sobre modernidad de runtime |
| Base de datos | PostgreSQL como motor objetivo del piloto, en servicio/instancia separada de XAMPP |
| Integracion | API REST entre frontend y backend |
| Despliegue | Frontend compilado como estaticos; backend en puerto separado; no reutilizar 80/443/3306 ni tocar XAMPP |
| Correo | Para I1 usar notificaciones internas y dejar SMTP como dependencia futura validable en I6 |
| Archivos | PDFs y soportes quedan sujetos a ruta aprobada por S&G antes de I4; no bloquea arranque de I1 |
| Backups | Deben definirse antes de salida productiva del piloto; no bloquean scaffolding local/controlado de I1 |
| Seguridad | Usuarios propios del portal en MVP, sesiones con expiracion, contrasenas hasheadas y hardening de puertos/servicios |
| Jobs | Resolver con mecanismo compatible con Windows Server 2012 cuando se ejecute I6; no bloquea I1 |

## 5. Evidencia Tecnica I0 - 2026-06-01

Fuente: `scripts/i0-server-validation/SG-I0-Validation-20260601-084759`.

| Area | Evidencia | Implicacion |
|------|-----------|-------------|
| Servidor | `SERVIDORGESTION`; Windows NT 6.3.9600.0; 64 bits | Confirmar edicion comercial exacta por comando alterno porque WMI fallo |
| Capacidad | ~8 GB RAM; 4 procesadores logicos; discos fijos C/E/F/G con aprox. 5.0 TB totales y 1.43 TB libres | Capacidad suficiente para piloto, sujeto a ruta/backups y monitoreo de recursos |
| PowerShell | Version 4.0 | Evitar scripts que dependan de PowerShell 5+ |
| IIS | W3SVC no detectado; WebAdministration no disponible | No asumir IIS como hosting para I1 |
| .NET | .NET Framework 4.8.03761; .NET Runtime/Desktop Runtime 6.0.10 x86 | .NET es candidato fuerte, sujeto a validacion de hosting y arquitectura runtime |
| PHP/XAMPP | XAMPP by Bitnami 5.6.20-0 instalado; PHP 5.6.20 en `C:\xampp\php\php.exe` | No aprobar PHP como stack principal sin excepcion formal de riesgo, aislamiento y hardening |
| Node.js | No detectado en PATH | No viable como stack inmediato sin instalacion y prueba de compatibilidad |
| Java/JDK | No detectado en PATH | No viable como stack inmediato sin instalacion y prueba de compatibilidad |
| Base de datos | Servicio Windows `mysql` en `AUTO_START`; MariaDB 10.1.13 en `C:\xampp\mysql\bin`; Firebird 3 instalado | Motor existente, pero antiguo; validar si se acepta, se aisla o se instala instancia separada |
| Red | IP LAN `192.168.1.15` por DHCP; DNS publicos configurados | Falta definir DNS interno, TLS y modo de acceso de usuarios |
| Firewall | Perfil dominio activo con `BlockInbound,AllowOutbound`; perfiles privado/publico desactivados | El puerto del portal debe abrirse de forma explicita o por politica aprobada |
| Puertos | 80/443 ocupados por `C:\xampp\apache\bin\httpd.exe`; 3306 ocupado por `C:\xampp\mysql\bin\mysqld.exe` | No tocar XAMPP/MySQL ni reutilizar esos puertos sin decision explicita; preferir puerto separado para piloto |
| Seguridad | Kaspersky Small Office Security instalado | Validar excepciones/permisos para servicio, puertos, PDFs y tareas programadas |
| Diagnostico | Servicio `winmgmt` corriendo, pero WMI falla para OS, CPU, RAM, BIOS, discos y red; `winmgmt /verifyrepository` falla con `0x80041002` | El inventario tecnico sigue parcial; no depender de WMI para cerrar I0 |

## 6. Decision Frontend Cerrada

El frontend debe desarrollarse como SPA desacoplada del backend. El servidor S&G no necesita ejecutar Node.js en produccion si el frontend se compila en ambiente de desarrollo/CI y se despliega como archivos estaticos.

| Opcion | Lectura |
|--------|---------|
| React | Recomendado como primera opcion: menor friccion para construir una SPA modular, buena integracion con componentes reutilizables, build estatico facil de servir y curva operativa moderada |
| Angular | Alternativa valida si el equipo mantenedor tiene experiencia fuerte en Angular o si se prefiere una estructura mas opinionada desde el inicio |
| HTML/CSS/JS simple | No recomendado como arquitectura objetivo; puede servir solo para prototipos ejecutivos |

Decision aprobada para entrada a I1: **React SPA + backend .NET compatible + API REST + PostgreSQL**. Si la infraestructura mejora, la SPA se mantiene y solo cambia la capa de hosting/backend bajo control documental.

## 7. Reglas Tecnicas De Entrada A I1

- no instalar Node.js en el servidor productivo; usarlo solo para build local/CI del frontend;
- no desplegar el piloto sobre el XAMPP existente;
- no reutilizar los puertos 80, 443 o 3306 ocupados;
- no usar MariaDB 10.1.13 de XAMPP como base principal del piloto;
- no depender de WMI para validaciones tecnicas de cierre u operacion;
- no asumir acceso a internet desde el servidor;
- no asumir permisos de administrador;
- no asumir disponibilidad de SMTP;
- no asumir IIS configurado;
- no asumir compatibilidad con runtimes modernos sin prueba;
- cualquier cambio de stack o despliegue debe pasar primero por actualizacion de `docs/TECNOLOGIA.md`.

## 8. Capacidades Tecnicas Minimas Del MVP

El stack seleccionado debe cubrir:

- login interno;
- roles y permisos;
- CRUD de datos maestros;
- carga Excel con prevalidacion;
- persistencia relacional;
- generacion de PDF;
- almacenamiento de documentos generados;
- historicos;
- auditoria;
- dashboard;
- notificaciones internas;
- correo o fallback exportable.

## 9. Familias Tecnologicas Evaluadas En I0

| Familia | Resultado |
|---------|-----------|
| .NET compatible con Windows Server 2012 | Aprobada como familia backend del piloto |
| Java/Spring compatible con servidor | No priorizada; requiere instalacion y validacion desde cero |
| PHP/Laravel u otro stack liviano | Descartada como base principal por dependencia observada en XAMPP/PHP 5.6 |
| Node.js LTS compatible | Descartada como stack servidor del piloto; se usa solo para build frontend local |
| Aplicacion empaquetada local/interna | Descartada por desviarse de la arquitectura de portal multiusuario |
| React SPA | Aprobada como frontend principal |
| Angular SPA | Queda como alternativa no activa; no aprobada como camino principal |

La decision final prioriza estabilidad, aislamiento del servidor existente y crecimiento modular sobre novedad tecnologica.

## 10. Tecnologia Fuera De Alcance Hasta Nueva Decision

- IA generativa dentro del MVP;
- WhatsApp;
- integracion directa HELIZA;
- integracion directa nomina;
- app movil para guardas;
- despliegue cloud si no es aprobado por S&G;
- stack que requiera actualizar el servidor sin decision ejecutiva.

## 11. Regla De Evolucion

Cambios de tecnologia deben actualizar, en este orden:

1. `docs/CONSTITUTION.md` si cambia una regla no negociable.
2. `docs/ARCHITECTURE.md` si cambia una decision arquitectonica.
3. `docs/TECNOLOGIA.md`.
4. SPECs afectadas.
5. Planes afectados.

## 12. Decision Tecnologica I9

El MVP de programacion asistida usa un **motor heuristico deterministico interno
en .NET 6**, integrado en el backend existente. Recibe snapshots versionados,
aplica reglas ordenadas y produce el mismo resultado para la misma entrada,
parametros y version de reglas. Cada resultado debe conservar razones, puntajes,
vacantes y excepciones para revision humana.

I9 no incorpora optimizador comercial, solver remoto, IA generativa ni servicio
cloud: opera **sin dependencia externa en el MVP**. Una evolucion a otro motor
requiere evidencia del piloto, actualizacion de arquitectura/tecnologia, nueva
SPEC aprobada y preservacion del contrato deterministico y auditable.

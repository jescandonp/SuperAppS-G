# I0 - Matriz De Decision De Stack

**Producto:** S&G Super App  
**Incremento:** I0 - Descubrimiento Tecnico e Infraestructura  
**Restriccion confirmada:** Windows Server 2012  
**Estado:** Cierre I0 documentado; decision aprobada para entrada a I1  

## 1. Criterios De Evaluacion

Puntuar cada opcion de 1 a 5.

| Criterio | Peso | Descripcion |
|----------|------|-------------|
| Compatibilidad Windows Server 2012 | 5 | Debe instalarse/ejecutarse sin upgrade obligatorio |
| Seguridad | 5 | Debe permitir configuracion segura aceptable |
| Mantenibilidad | 5 | Debe ser mantenible por el equipo/proveedor |
| Base de datos relacional | 4 | Debe conectarse a motor permitido |
| PDF | 4 | Debe generar certificaciones PDF |
| Excel | 4 | Debe importar matrices iniciales |
| Jobs/alertas | 3 | Debe permitir tareas programadas |
| Correo/fallback | 3 | Debe soportar SMTP o alternativa |
| Evolucion modular | 4 | Debe crecer hacia nuevos modulos |
| Esfuerzo de despliegue | 4 | Debe ser viable en infraestructura real |

## 2. Opciones Candidatas

| Opcion | Estado | Evidencia requerida |
|--------|--------|---------------------|
| .NET compatible con Windows Server 2012 | Compatible con restricciones | .NET Framework 4.8 y .NET Runtime 6.0.10 x86 instalados; IIS no detectado |
| Java compatible | Pendiente / no instalado actualmente | Java/JDK no detectado en PATH |
| PHP/stack liviano | Compatible tecnicamente, no recomendable como stack principal sin excepcion de riesgo | XAMPP 5.6.20-0 instalado; PHP 5.6.20; MariaDB 10.1.13; Apache escuchando 80/443; version antigua requiere hardening |
| Node.js compatible | Pendiente / no instalado actualmente | Node.js y npm no detectados en PATH |
| Aplicacion interna empaquetada | Pendiente | Multiusuario, backups, seguridad, despliegue |

## 3. Evaluacion

| Criterio | Peso | .NET | Java | PHP | Node.js | Empaquetada |
|----------|------|------|------|-----|---------|-------------|
| Compatibilidad Windows Server 2012 | 5 | 4 | 2 | 4 | 2 | 2 |
| Seguridad | 5 | 4 | 3 | 1 | 3 | 2 |
| Mantenibilidad | 5 | 4 | 2 | 1 | 3 | 1 |
| Base de datos relacional | 4 | 4 | 4 | 4 | 4 | 2 |
| PDF | 4 | 4 | 4 | 3 | 3 | 2 |
| Excel | 4 | 4 | 4 | 3 | 3 | 2 |
| Jobs/alertas | 3 | 4 | 3 | 3 | 3 | 2 |
| Correo/fallback | 3 | 4 | 4 | 3 | 3 | 2 |
| Evolucion modular | 4 | 4 | 3 | 1 | 3 | 1 |
| Esfuerzo de despliegue | 4 | 3 | 2 | 4 | 2 | 2 |

## 4. Decision Recomendada

| Campo | Valor |
|-------|-------|
| Stack recomendado | React SPA + backend .NET compatible con Windows Server 2012 + PostgreSQL + API REST |
| Justificacion | Es la combinacion que mejor balancea compatibilidad con la infraestructura observada, aislamiento frente al stack heredado XAMPP, crecimiento modular y despliegue administrable para un piloto interno |
| Riesgos aceptados | WMI no confiable; IIS no detectado; SMTP, backups y ruta final de PDFs siguen como decisiones operativas posteriores; el backend debe elegirse con compatibilidad real de hosting en Windows Server 2012 |
| Condiciones para I1 | Trabajar con PostgreSQL separado de XAMPP, autenticar con usuarios locales del portal, servir frontend como build estatico, desplegar backend en puerto separado y no invadir integraciones futuras |

## 5. Descartes

| Opcion | Causa | Evidencia |
|--------|-------|-----------|
| PHP/XAMPP como stack principal sin hardening | PHP 5.6.20 y MariaDB 10.1.13 son componentes antiguos; pueden servir como evidencia de stack existente, pero no deberian aprobarse como base del nuevo portal sin aislamiento, hardening y aceptacion formal del riesgo | `10-installed-programs.csv`; comandos manuales `php.exe -v` y `mysql.exe --version` |
| Node.js como stack inmediato | No esta instalado y Windows Server 2012 limita versiones modernas soportadas; requiere validacion explicita antes de considerarlo | `SG-I0-Server-Report.md` |
| Java como stack inmediato | No esta instalado; requiere aprobacion de instalacion de JDK/runtime y politica de servicio | `SG-I0-Server-Report.md` |

## 6. Evidencia Base I0 - 2026-06-01

| Hallazgo | Lectura tecnica |
|----------|-----------------|
| Windows NT 6.3.9600.0 | Compatible con familia Windows Server 2012 R2; falta confirmar edicion comercial por comando alterno |
| PowerShell 4.0 | Suficiente para administracion basica; scripts modernos deben evitar dependencias PS 5+ |
| IIS no detectado | No asumir despliegue web sobre IIS hasta instalar/habilitar o elegir hosting alterno |
| MariaDB 10.1.13/MySQL running | Motor existente como servicio Windows `AUTO_START` bajo `LocalSystem`; candidato solo si se acepta su version o si se define migracion/instancia separada |
| Firebird 3 instalado | Puede estar asociado a software existente; no elegir sin confirmar uso/licencia/responsable |
| .NET Framework 4.8 y .NET 6 x86 runtime | Base favorable para .NET, pero hay que validar si backend objetivo puede correr de forma soportada |
| XAMPP 5.6.20 instalado | Apache `httpd.exe` publica 80/443 y MySQL/MariaDB `mysqld.exe` publica 3306; riesgo por antiguedad y posible dependencia de aplicaciones existentes |
| WMI falla | No cerrar inventario tecnico hasta validar hardware/OS por comandos alternos |
| WMI repository 0x80041002 | Confirmado con `winmgmt /verifyrepository`; usar comandos alternos para hardware o reparar WMI fuera del alcance I0 |

## 7. Decision Frontend Preliminar

| Opcion | Estado | Lectura |
|--------|--------|---------|
| React SPA | Recomendada | Buena base para Super App modular por perfiles, componentes reutilizables, dashboard, notificaciones y crecimiento por modulos; el build puede generarse fuera del servidor y desplegarse como archivos estaticos |
| Angular SPA | Alternativa valida | Conveniente si el equipo mantenedor tiene mayor experiencia Angular o si se quiere una estructura mas opinionada desde el inicio; exige cuidar versionado de Node/CLI en ambiente de build |
| HTML/CSS/JS simple | Solo prototipo | No recomendable como base de producto porque la app crecera en formularios, permisos, dashboards, estados y modulos |

Decision operativa: usar React salvo que el responsable tecnico de mantenimiento prefiera Angular por experiencia comprobada.

## 8. Cierre I0

- Decision formal: React SPA + backend .NET compatible + PostgreSQL.
- Camino descartado: usar PHP/XAMPP o MariaDB heredada como base del piloto.
- Camino descartado: usar Node.js como backend productivo en el servidor actual.
- Entrada a I1 autorizada bajo las condiciones documentadas en `docs/TECNOLOGIA.md`.

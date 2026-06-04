# SPEC I0 - Descubrimiento Tecnico e Infraestructura

**Fecha:** 2026-05-21  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I0  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**Estado:** Cerrada documentalmente; habilita entrada a I1  

---

## 1. Proposito

Definir el alcance del descubrimiento tecnico necesario antes de seleccionar stack, arquitectura de despliegue y plan de implementacion para el piloto de la S&G Super App.

El servidor de aplicaciones confirmado es **Windows Server 2012**. Esta restriccion puede afectar runtime, seguridad, base de datos, correo, generacion de PDFs, jobs de alertas y mantenibilidad. Por eso I0 es obligatorio antes de iniciar I1.

---

## 2. Resultado Esperado

Al finalizar I0 debe existir una decision tecnica aprobada que responda:

- que stack se usara;
- donde se desplegara;
- que base de datos se usara;
- como se autenticaran usuarios internos;
- como se generaran y almacenaran PDFs;
- como se enviaran o reemplazaran correos;
- como se ejecutaran tareas programadas;
- como se respaldara la informacion;
- que restricciones se aceptan para el piloto.

La salida de I0 debe actualizar `docs/TECNOLOGIA.md` con decisiones definitivas de stack y condiciones de entrada a I1.

---

## 3. Alcance

### Incluido

- Levantamiento tecnico del Windows Server 2012.
- Validacion de permisos y restricciones de instalacion.
- Evaluacion de stack backend.
- Evaluacion de stack frontend.
- Evaluacion de base de datos.
- Evaluacion de correo/SMTP.
- Evaluacion de almacenamiento de PDFs y soportes.
- Evaluacion de jobs/tareas programadas.
- Estrategia de backups.
- Estrategia de seguridad y acceso interno.
- Recomendacion de stack viable para el piloto.
- Definicion de condiciones tecnicas minimas para iniciar I1.

### Fuera de alcance

- Desarrollo de portal.
- Desarrollo de backend.
- Desarrollo de frontend.
- Configuracion final del servidor.
- Migracion de datos.
- Implementacion de autenticacion.
- Implementacion de correo.
- Integracion HELIZA.
- Integracion nomina.

---

## 4. Informacion Minima A Levantar

### 4.1 Servidor

| Pregunta | Estado |
|----------|--------|
| ¿Es Windows Server 2012 o Windows Server 2012 R2? | Pendiente |
| ¿Arquitectura 32 bits o 64 bits? | Pendiente |
| ¿Memoria RAM disponible? | Pendiente |
| ¿CPU / nucleos disponibles? | Pendiente |
| ¿Espacio en disco disponible? | Pendiente |
| ¿Tiene acceso a internet? | Pendiente |
| ¿Esta en dominio corporativo? | Pendiente |
| ¿Tiene IIS instalado? | Pendiente |
| ¿Version de PowerShell disponible? | Pendiente |
| ¿Hay antivirus/EDR con restricciones? | Pendiente |
| ¿Se permite instalar runtimes? | Pendiente |
| ¿Se cuenta con permisos de administrador? | Pendiente |

### 4.2 Red Y Acceso

| Pregunta | Estado |
|----------|--------|
| ¿El portal sera accesible solo en red interna? | Pendiente |
| ¿Requiere VPN? | Pendiente |
| ¿Hay DNS interno para publicar el portal? | Pendiente |
| ¿Hay certificado TLS disponible? | Pendiente |
| ¿Se permite trafico saliente a internet? | Pendiente |
| ¿Se permite conexion hacia servidor de correo? | Pendiente |

### 4.3 Base De Datos

| Pregunta | Estado |
|----------|--------|
| ¿Existe motor de base de datos instalado? | Pendiente |
| ¿Que motores estan permitidos: SQL Server, MySQL/MariaDB, PostgreSQL, SQLite, otro? | Pendiente |
| ¿Se permite instalar un nuevo motor? | Pendiente |
| ¿Hay politicas de backup de base de datos? | Pendiente |
| ¿Quien administra la base de datos? | Pendiente |
| ¿Se requiere ambiente separado de pruebas? | Pendiente |

### 4.4 Correo

| Pregunta | Estado |
|----------|--------|
| ¿Existe cuenta institucional para envio de alertas? | Pendiente |
| ¿Hay SMTP disponible? | Pendiente |
| ¿Requiere autenticacion? | Pendiente |
| ¿Requiere TLS/SSL? | Pendiente |
| ¿Hay limite de envio? | Pendiente |
| ¿Que fallback se aprueba si no hay correo: solo notificaciones internas o resumen exportable? | Pendiente |

### 4.5 Archivos Y PDFs

| Pregunta | Estado |
|----------|--------|
| ¿Donde se almacenaran PDFs generados? | Pendiente |
| ¿Se requiere ruta compartida? | Pendiente |
| ¿Se permite guardar soportes documentales en MVP? | Pendiente |
| ¿Hay limite de espacio por documentos? | Pendiente |
| ¿Quien puede acceder a carpetas de certificados? | Pendiente |
| ¿Se requiere cifrado o restriccion especial para documentos laborales? | Pendiente |

### 4.6 Seguridad Y Usuarios

| Pregunta | Estado |
|----------|--------|
| ¿Usuarios locales propios del portal para MVP? | Aprobado funcionalmente |
| ¿Existe Active Directory disponible para futuro? | Pendiente |
| ¿Politica minima de contrasenas? | Pendiente |
| ¿Tiempo de expiracion de sesion? | Pendiente |
| ¿Requiere logs de acceso? | Pendiente |
| ¿Requiere roles configurables o roles fijos para MVP? | Pendiente |

---

## 5. Capacidades Tecnicas Requeridas

El stack seleccionado debe permitir:

1. Portal web interno.
2. Login con usuarios propios.
3. Roles y permisos.
4. CRUD de maestros.
5. Importacion Excel.
6. Prevalidacion de datos.
7. Persistencia relacional.
8. Generacion de PDFs.
9. Almacenamiento de documentos.
10. Notificaciones internas.
11. Correo o fallback exportable.
12. Jobs o tareas programadas para alertas.
13. Auditoria.
14. Backups.
15. Despliegue mantenible en Windows Server 2012.

---

## 6. Opciones Tecnologicas A Evaluar

Estas opciones son candidatas, no decisiones.

### Opcion A - .NET compatible con Windows Server 2012

Evaluar:

- version soportada por Windows Server 2012;
- compatibilidad con IIS;
- librerias PDF;
- librerias Excel;
- autenticacion local;
- facilidad de soporte;
- estrategia de jobs;
- base de datos compatible.

Riesgo:

- versiones modernas de .NET pueden no estar soportadas o requerir ajustes.

### Opcion B - Java compatible

Evaluar:

- JDK soportado;
- framework compatible;
- ejecucion como servicio;
- librerias PDF/Excel;
- conexion a base de datos;
- mantenibilidad.

Riesgo:

- stack moderno puede requerir Java no viable en Windows Server 2012.

### Opcion C - PHP / stack liviano

Evaluar:

- version PHP soportada;
- servidor web disponible;
- seguridad;
- librerias PDF/Excel;
- ORM/base de datos;
- mantenibilidad.

Riesgo:

- evitar repetir dependencia de sistemas antiguos PHP si no hay gobierno tecnico suficiente.

### Opcion D - Node.js compatible

Evaluar:

- version Node soportada por Windows Server 2012;
- ejecucion como servicio;
- seguridad;
- PDF/Excel;
- base de datos;
- soporte futuro.

Riesgo:

- Windows Server 2012 puede limitar versiones LTS modernas.

### Opcion E - Aplicacion interna empaquetada

Evaluar:

- multiusuario;
- persistencia;
- backups;
- acceso por red;
- mantenibilidad;
- seguridad.

Riesgo:

- puede alejarse del objetivo de portal/Super App.

---

## 7. Criterios De Decision Tecnologica

La opcion elegida debe puntuar favorablemente en:

- compatibilidad real con Windows Server 2012;
- capacidad de despliegue sin friccion excesiva;
- seguridad aceptable;
- facilidad de mantenimiento;
- soporte de base relacional;
- soporte PDF;
- soporte Excel;
- soporte de notificaciones/jobs;
- posibilidad de evolucionar hacia nuevos modulos;
- curva razonable para el equipo que operara la solucion;
- bajo riesgo de obsolescencia inmediata.

No se debe elegir tecnologia solo por preferencia del desarrollador.

---

## 8. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Windows Server 2012 limita runtimes modernos | Alto | Validar compatibilidad antes de decidir stack |
| Sin permisos de administrador | Alto | Diseñar despliegue compatible con permisos disponibles |
| Sin SMTP | Medio | Usar notificaciones internas + resumen exportable |
| Sin motor DB disponible | Alto | Definir motor permitido o instalacion controlada |
| Sin backups claros | Alto | Exigir estrategia minima antes de MVP productivo |
| Sin TLS/certificado | Medio | Definir alcance interno y riesgo aceptado |
| Datos Excel sucios | Alto | I2 debe incluir prevalidacion robusta |

---

## 9. Entregables De I0

1. Ficha tecnica del servidor.
2. Matriz comparativa de opciones tecnologicas.
3. Decision de stack recomendada.
4. Decision de base de datos.
5. Decision de correo/fallback.
6. Decision de almacenamiento de PDFs.
7. Decision de jobs/alertas programadas.
8. Riesgos aceptados.
9. Actualizacion de `docs/TECNOLOGIA.md`.
10. Criterios de entrada para I1.

---

## 10. Criterios De Aceptacion

I0 se considera cerrado cuando:

- la ficha tecnica del servidor esta completa;
- se confirma si el servidor tiene IIS, internet, permisos y base de datos;
- se documentan al menos dos opciones tecnologicas evaluadas;
- se recomienda una opcion con justificacion;
- se identifican riesgos residuales;
- se actualiza `docs/TECNOLOGIA.md`;
- se autoriza iniciar `SPEC I1 - Portal Base`.

## 12. Cierre Tecnico I0 - 2026-06-03

### Decision aprobada

- Frontend: React SPA.
- Backend: backend .NET compatible con Windows Server 2012.
- Integracion: API REST.
- Base de datos: PostgreSQL en instancia separada del stack XAMPP existente.
- Despliegue: frontend como archivos estaticos; backend en puerto separado; no reutilizar 80/443/3306.

### Restricciones aceptadas

- No tocar XAMPP, Apache ni MariaDB existentes sin decision ejecutiva explicita.
- No usar WMI como fuente obligatoria de verificacion tecnica por falla `0x80041002`.
- SMTP, ruta final de PDFs y politica de backups quedan pendientes de definicion operativa, pero no bloquean el arranque de I1.

### Condiciones de entrada a I1

1. Mantener autenticacion local de usuarios para MVP.
2. Preparar base local `sg_superapp_dev` y usuario de aplicacion durante el scaffolding inicial.
3. Diseñar el backend y el despliegue para puerto separado del stack heredado.
4. Mantener el frontend desacoplado y servible como estaticos.
5. No ampliar alcance hacia integraciones, movil o IA generativa.

---

## 11. Preguntas Para El Levantamiento Tecnico

Estas son las preguntas que se deben resolver con quien administre el servidor:

1. ¿El servidor es Windows Server 2012 o 2012 R2?
2. ¿Es 64 bits?
3. ¿Tenemos permisos de administrador?
4. ¿Tiene IIS instalado y habilitado?
5. ¿Tiene acceso a internet?
6. ¿Que motor de base de datos existe o se permite instalar?
7. ¿Se puede instalar runtime adicional?
8. ¿Hay cuenta SMTP institucional para envio de alertas?
9. ¿Hay certificado TLS o dominio interno?
10. ¿Donde se guardaran PDFs y backups?
11. ¿Existe politica de backup?
12. ¿El portal sera solo red interna o acceso remoto/VPN?
13. ¿Hay restricciones de antivirus/seguridad para servicios nuevos?
14. ¿Quien dara soporte operativo al servidor?

---

## 12. Decision Pendiente

La decision de stack queda bloqueada hasta cerrar esta SPEC I0 con evidencia tecnica real.

Una vez aprobada I0, se debe actualizar `docs/TECNOLOGIA.md` y avanzar a:

`SPEC I1 - Portal Base`.

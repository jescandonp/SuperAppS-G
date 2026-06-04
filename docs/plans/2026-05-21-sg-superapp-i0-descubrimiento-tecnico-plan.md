# S&G Super App I0 Descubrimiento Tecnico Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completar el levantamiento tecnico de infraestructura para decidir stack, base de datos, correo, almacenamiento y criterios de entrada a I1.

**Architecture:** Este plan ejecuta `SPEC I0 - Descubrimiento Tecnico e Infraestructura` como un discovery gate. No implementa software; produce evidencia tecnica, matriz de decision y actualizacion de `docs/TECNOLOGIA.md`.

**Tech Stack:** Pendiente de decision. Restriccion confirmada: Windows Server 2012.

---

## File Structure

- Reference: `docs/CONSTITUTION.md`
  - Autoridad SDD y gates.
- Reference: `docs/ARCHITECTURE.md`
  - Arquitectura rectora del portal y dependencias de I0.
- Reference: `docs/TECNOLOGIA.md`
  - Documento que debe actualizarse al cerrar I0.
- Reference: `docs/specs/2026-05-21-sg-superapp-spec-i0-descubrimiento-tecnico-infraestructura.md`
  - SPEC activa de I0.
- Modify: `docs/TECNOLOGIA.md`
  - Registrar decisiones finales de stack cuando exista evidencia.
- Modify: `docs/plans/2026-05-21-sg-superapp-i0-descubrimiento-tecnico-plan.md`
  - Registrar avance, evidencia y cierre documental.
- Create: `docs/plans/i0-ficha-tecnica-servidor.md`
  - Ficha de levantamiento del Windows Server 2012.
- Create: `docs/plans/i0-matriz-decision-stack.md`
  - Comparativo de opciones tecnologicas y recomendacion.
- Create: `scripts/i0-server-validation/Collect-SGServerInfo.ps1`
  - Script de levantamiento tecnico de solo lectura para ejecutar en el servidor.
- Create: `scripts/i0-server-validation/README.md`
  - Guia de ejecucion de scripts I0.
- Create: `scripts/i0-server-validation/run-basic-validation.cmd`
  - Lanzador basico para ejecutar el script desde CMD/Explorer.

---

## Task 1: Preparar Ficha Tecnica Del Servidor

**Files:**
- Create: `docs/plans/i0-ficha-tecnica-servidor.md`

- [ ] **Step 1: Crear ficha tecnica base**

Crear `docs/plans/i0-ficha-tecnica-servidor.md` con este contenido:

```markdown
# I0 - Ficha Tecnica Del Servidor

**Producto:** S&G Super App  
**Incremento:** I0 - Descubrimiento Tecnico e Infraestructura  
**Servidor confirmado:** Windows Server 2012  
**Estado:** Pendiente levantamiento  

## 1. Identificacion Del Servidor

| Campo | Valor | Evidencia |
|-------|-------|-----------|
| Nombre del servidor | Pendiente | Pendiente |
| Sistema operativo exacto | Windows Server 2012 / pendiente confirmar R2 | Pendiente |
| Arquitectura | Pendiente 32/64 bits | Pendiente |
| RAM | Pendiente | Pendiente |
| CPU / nucleos | Pendiente | Pendiente |
| Disco disponible | Pendiente | Pendiente |
| Dominio/red | Pendiente | Pendiente |
| Responsable tecnico | Pendiente | Pendiente |

## 2. Acceso Y Permisos

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Tenemos acceso remoto? | Pendiente | Pendiente |
| ¿Tenemos usuario administrador? | Pendiente | Pendiente |
| ¿Se permite instalar runtimes? | Pendiente | Pendiente |
| ¿Se permite crear servicios Windows? | Pendiente | Pendiente |
| ¿Hay politicas de antivirus/EDR? | Pendiente | Pendiente |

## 3. Servicios Instalados

| Servicio | Estado | Evidencia |
|----------|--------|-----------|
| IIS | Pendiente | Pendiente |
| PowerShell | Pendiente version | Pendiente |
| .NET Framework | Pendiente version | Pendiente |
| Java/JDK | Pendiente version | Pendiente |
| PHP | Pendiente version | Pendiente |
| Node.js | Pendiente version | Pendiente |
| Motor de base de datos | Pendiente | Pendiente |

## 4. Red Y Seguridad

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Acceso solo red interna? | Pendiente | Pendiente |
| ¿Requiere VPN? | Pendiente | Pendiente |
| ¿DNS interno disponible? | Pendiente | Pendiente |
| ¿Certificado TLS disponible? | Pendiente | Pendiente |
| ¿Acceso a internet desde servidor? | Pendiente | Pendiente |
| ¿Salida a SMTP/correo? | Pendiente | Pendiente |

## 5. Base De Datos

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Motor existente? | Pendiente | Pendiente |
| ¿Motor permitido? | Pendiente | Pendiente |
| ¿Se puede instalar motor nuevo? | Pendiente | Pendiente |
| ¿Hay DBA/responsable? | Pendiente | Pendiente |
| ¿Politica de backup DB? | Pendiente | Pendiente |

## 6. Correo

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Cuenta institucional para alertas? | Pendiente | Pendiente |
| ¿SMTP disponible? | Pendiente | Pendiente |
| ¿Autenticacion requerida? | Pendiente | Pendiente |
| ¿TLS/SSL requerido? | Pendiente | Pendiente |
| ¿Limites de envio? | Pendiente | Pendiente |

## 7. Archivos, PDFs Y Backups

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| Ruta para PDFs generados | Pendiente | Pendiente |
| Ruta para soportes | Pendiente | Pendiente |
| Politica de backups | Pendiente | Pendiente |
| Responsable de backups | Pendiente | Pendiente |
| Retencion esperada | Pendiente | Pendiente |

## 8. Observaciones

Registrar aqui restricciones, capturas, respuestas del administrador o riesgos adicionales.
```

- [ ] **Step 2: Verificar que la ficha fue creada**

Ejecutar:

```powershell
Get-Item -Path "docs/plans/i0-ficha-tecnica-servidor.md" | Select-Object FullName,Length
```

Esperado: el archivo existe y tiene contenido mayor a 1 KB.

---

## Task 2: Preparar Matriz De Decision De Stack

**Files:**
- Create: `docs/plans/i0-matriz-decision-stack.md`

- [ ] **Step 1: Crear matriz comparativa base**

Crear `docs/plans/i0-matriz-decision-stack.md` con este contenido:

```markdown
# I0 - Matriz De Decision De Stack

**Producto:** S&G Super App  
**Incremento:** I0 - Descubrimiento Tecnico e Infraestructura  
**Restriccion confirmada:** Windows Server 2012  
**Estado:** Pendiente evidencia tecnica  

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
| .NET compatible con Windows Server 2012 | Pendiente | Version runtime, IIS, PDF, Excel, DB |
| Java compatible | Pendiente | JDK, framework, servicio/app server, PDF, Excel, DB |
| PHP/stack liviano | Pendiente | Version PHP, servidor web, seguridad, PDF, Excel, DB |
| Node.js compatible | Pendiente | Version soportada, servicio Windows, PDF, Excel, DB |
| Aplicacion interna empaquetada | Pendiente | Multiusuario, backups, seguridad, despliegue |

## 3. Evaluacion

| Criterio | Peso | .NET | Java | PHP | Node.js | Empaquetada |
|----------|------|------|------|-----|---------|-------------|
| Compatibilidad Windows Server 2012 | 5 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Seguridad | 5 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Mantenibilidad | 5 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Base de datos relacional | 4 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| PDF | 4 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Excel | 4 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Jobs/alertas | 3 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Correo/fallback | 3 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Evolucion modular | 4 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Esfuerzo de despliegue | 4 | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |

## 4. Decision Recomendada

| Campo | Valor |
|-------|-------|
| Stack recomendado | Pendiente |
| Justificacion | Pendiente |
| Riesgos aceptados | Pendiente |
| Condiciones para I1 | Pendiente |

## 5. Descartes

Registrar opciones descartadas y causa.
```

- [ ] **Step 2: Verificar que la matriz fue creada**

Ejecutar:

```powershell
Get-Item -Path "docs/plans/i0-matriz-decision-stack.md" | Select-Object FullName,Length
```

Esperado: el archivo existe y tiene contenido mayor a 1 KB.

---

## Task 3: Levantar Informacion Con El Administrador Del Servidor

**Files:**
- Modify: `docs/plans/i0-ficha-tecnica-servidor.md`

- [ ] **Step 1: Enviar preguntas tecnicas al administrador**

Usar este bloque como cuestionario:

```text
Para cerrar el incremento I0 de la S&G Super App necesitamos confirmar:

1. ¿El servidor es Windows Server 2012 o Windows Server 2012 R2?
2. ¿Es 64 bits?
3. ¿Cuanta RAM, CPU y disco disponible tiene?
4. ¿Tenemos permisos de administrador?
5. ¿Se permite instalar runtimes o crear servicios Windows?
6. ¿Tiene IIS instalado? ¿Que version?
7. ¿Tiene acceso a internet?
8. ¿Esta en dominio corporativo?
9. ¿Existe motor de base de datos instalado o permitido?
10. ¿Se puede instalar un motor nuevo si es necesario?
11. ¿Existe cuenta SMTP institucional para alertas?
12. ¿Hay certificado TLS o DNS interno para publicar el portal?
13. ¿Donde se pueden almacenar PDFs generados y backups?
14. ¿Existe politica de backup?
15. ¿Hay restricciones de antivirus/seguridad para aplicaciones nuevas?
16. ¿Quien sera responsable tecnico del servidor?
```

- [ ] **Step 1A: Ejecutar script de validacion en el servidor**

Copiar la carpeta:

```text
scripts/i0-server-validation/
```

al Windows Server 2012 y ejecutar:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Collect-SGServerInfo.ps1 -OutputRoot "."
```

Si se conoce SMTP:

```powershell
.\Collect-SGServerInfo.ps1 -OutputRoot "." -SmtpHost "smtp.dominio.com" -SmtpPort 587
```

Si se conoce host de base de datos:

```powershell
.\Collect-SGServerInfo.ps1 -OutputRoot "." -DbHost "servidor-db" -DbPorts 1433,3306,5432,1521
```

Esperado: carpeta `SG-I0-Validation-YYYYMMDD-HHMMSS` con reporte `SG-I0-Server-Report.md`.

- [ ] **Step 2: Registrar respuestas**

Actualizar `docs/plans/i0-ficha-tecnica-servidor.md` reemplazando `Pendiente` por respuestas verificadas.

- [ ] **Step 3: Registrar evidencia**

En la columna `Evidencia`, registrar una de estas formas:

```text
Confirmado por administrador el YYYY-MM-DD
Captura local
Comando ejecutado
Documento tecnico
Pendiente evidencia
```

---

## Task 4: Evaluar Opciones Tecnologicas

**Files:**
- Modify: `docs/plans/i0-matriz-decision-stack.md`

- [ ] **Step 1: Completar compatibilidad por opcion**

Para cada opcion candidata, registrar:

```text
Compatible
Compatible con restricciones
No compatible
Pendiente evidencia
```

- [ ] **Step 2: Puntuar criterios**

Reemplazar cada `Pendiente` de la tabla de evaluacion por un puntaje `1`, `2`, `3`, `4` o `5`.

- [ ] **Step 3: Documentar descartes**

Si una opcion no es viable, registrar en `Descartes`:

```markdown
| Opcion | Causa | Evidencia |
|--------|-------|-----------|
| Node.js compatible | No viable si version soportada no corre en Windows Server 2012 | Pendiente/confirmado |
```

- [ ] **Step 4: Recomendar stack**

Completar `Decision Recomendada` con:

```markdown
| Campo | Valor |
|-------|-------|
| Stack recomendado | <stack elegido> |
| Justificacion | <razon de compatibilidad, seguridad, mantenimiento y alcance MVP> |
| Riesgos aceptados | <riesgos concretos> |
| Condiciones para I1 | <condiciones tecnicas obligatorias> |
```

---

## Task 5: Actualizar Tecnologia

**Files:**
- Modify: `docs/TECNOLOGIA.md`

- [ ] **Step 1: Actualizar coordenadas tecnicas**

Cuando exista decision, actualizar `docs/TECNOLOGIA.md` en:

```markdown
| Stack final | <valor aprobado> |
| Base de datos final | <valor aprobado> |
```

- [ ] **Step 2: Agregar versiones canonicas**

Agregar una seccion `Versiones Canonicas Aprobadas` con:

```markdown
## Versiones Canonicas Aprobadas

| Capa | Tecnologia | Version | Regla |
|------|------------|---------|-------|
| Backend | Pendiente decision I0 | Pendiente | Pendiente |
| Frontend | Pendiente decision I0 | Pendiente | Pendiente |
| Base de datos | Pendiente decision I0 | Pendiente | Pendiente |
| PDF | Pendiente decision I0 | Pendiente | Pendiente |
| Excel | Pendiente decision I0 | Pendiente | Pendiente |
| Jobs | Pendiente decision I0 | Pendiente | Pendiente |
```

Reemplazar `Pendiente decision I0` por valores aprobados cuando la matriz este completa.

- [ ] **Step 3: Registrar restricciones finales**

Agregar o actualizar una seccion `Restricciones Finales I0` con:

```markdown
## Restricciones Finales I0

- Servidor: Windows Server 2012.
- <restriccion 1>.
- <restriccion 2>.
- <restriccion 3>.
```

---

## Task 6: Cerrar I0 Documentalmente

**Files:**
- Modify: `docs/plans/2026-05-21-sg-superapp-i0-descubrimiento-tecnico-plan.md`
- Modify: `README.md`

- [ ] **Step 1: Verificar criterios de aceptacion**

Confirmar:

```text
Ficha tecnica completa: SI/NO
Matriz de decision completa: SI/NO
Stack recomendado: SI/NO
Base de datos definida: SI/NO
Correo/fallback definido: SI/NO
PDF/storage definido: SI/NO
docs/TECNOLOGIA.md actualizado: SI/NO
Autorizacion para SPEC I1: SI/NO
```

- [ ] **Step 2: Actualizar estado en README**

Cuando I0 este cerrado, cambiar:

```markdown
| I0 | Descubrimiento tecnico e infraestructura | SPEC borrador |
```

por:

```markdown
| I0 | Descubrimiento tecnico e infraestructura | Cerrado |
```

- [ ] **Step 3: Registrar retake point**

Agregar al final de este plan:

```markdown
## Execution Log

### Cierre I0

- Fecha:
- Decision de stack:
- Base de datos:
- Correo/fallback:
- Riesgos aceptados:
- Siguiente SPEC: `SPEC I1 - Portal Base`
- Retake point: iniciar SPEC I1 con stack ya definido en `docs/TECNOLOGIA.md`.
```

---

## Self-Review

- Spec coverage: cubre levantamiento de servidor, red, DB, correo, archivos, seguridad, opciones tecnologicas, matriz de decision, actualizacion de tecnologia y cierre de I0.
- Placeholder policy: los documentos iniciales usan `Pendiente` porque I0 es discovery; esos campos son datos a levantar, no placeholders de implementacion.
- No code implementation: correcto; I0 es gate tecnico previo a desarrollo.

## Execution Log

### 2026-06-01 - Evidencia inicial servidor

- Fuente importada: `scripts/i0-server-validation/SG-I0-Validation-20260601-084759`.
- Ficha tecnica actualizada con servidor `SERVIDORGESTION`, Windows NT 6.3.9600.0, 64 bits, PowerShell 4.0, .NET Framework 4.8, .NET Runtime 6.0.10 x86, MySQL running, Firebird 3 instalado, XAMPP 5.6.20 instalado, Kaspersky instalado e IIS no detectado.
- Matriz de decision actualizada con lectura preliminar: .NET queda como candidato fuerte sujeto a validacion de hosting; PHP/XAMPP queda con restricciones altas por antiguedad; Node.js y Java no estan instalados.
- Pendiente para cerrar I0: RAM/CPU/disco por comandos alternos, version/ruta real de PHP/MySQL, puertos abiertos, politica de instalacion/servicios, ruta de PDFs, backups, SMTP/fallback y decision formal de stack.

### 2026-06-03 - Cierre I0 y habilitacion de I1

- Se consolido la decision tecnica de entrada a I1 en `docs/TECNOLOGIA.md`: React SPA + backend .NET compatible + PostgreSQL + API REST.
- Se actualizo la SPEC I0 a estado cerrado documentalmente con condiciones de entrada a I1.
- Se actualizo la SPEC I1 para reflejar que ya no depende de una definicion abierta de stack.
- Se mantiene fuera de alcance tocar XAMPP, reutilizar 80/443/3306 o aprobar MariaDB heredada como base del piloto.
- Riesgos residuales aceptados para pasar a I1: WMI no confiable, SMTP no confirmado, ruta final de PDFs pendiente, politica formal de backups pendiente, hosting backend por detallar dentro del marco .NET compatible.
- Retake point: preparar y ejecutar el plan I1 para scaffolding del portal base, autenticacion local, shell React, API backend y base PostgreSQL local/controlada.

### 2026-06-01 - Validacion manual complementaria

- WMI confirmado como no confiable: `winmgmt /verifyrepository` fallo con `0x80041002`; `wmic` y `systeminfo` tambien fallaron con `No encontrado`.
- XAMPP confirmado en `C:\xampp`; PHP confirmado como `PHP 5.6.20`; MySQL/MariaDB confirmado como `MariaDB 10.1.13`.
- Servicio `winmgmt` confirmado como `RUNNING`, pero con repositorio WMI no confiable. Servicio `mysql` confirmado como `AUTO_START`, ejecutando `C:\xampp\mysql\bin\mysqld.exe --defaults-file=c:\xampp\mysql\bin\my.ini mysql` bajo cuenta `LocalSystem`.
- Puertos detectados: 80/443 escuchando en PID 1348 `httpd.exe` (`C:\xampp\apache\bin\httpd.exe`); 3306 escuchando en PID 1512 `mysqld.exe` (`C:\xampp\mysql\bin\mysqld.exe`).
- Capacidad validada sin WMI: ~8 GB RAM, 4 procesadores logicos; discos fijos C/E/F/G con aproximadamente 5.0 TB totales y 1.43 TB libres. Modelo exacto de CPU sigue pendiente por limitacion de comandos alternos.
- Decision tecnica preliminar reforzada: no usar PHP/XAMPP 5.6 como stack principal del nuevo portal salvo aceptacion formal de riesgo; validar .NET como candidato preferente con hosting separado y sin interferir servicios existentes.

### 2026-06-01 - Ajuste frontend Super App

- Se descarta HTML/CSS/JS simple como arquitectura objetivo del producto; queda solo para prototipos ejecutivos.
- Se propone SPA robusta para el frontend. React queda como recomendacion preliminar por modularidad, despliegue estatico y menor friccion operativa; Angular queda como alternativa valida si el equipo mantenedor tiene experiencia comprobada.
- Implicacion I1: definir estrategia de build local/CI para que Node.js sea dependencia de desarrollo, no necesariamente runtime productivo en el Windows Server 2012.

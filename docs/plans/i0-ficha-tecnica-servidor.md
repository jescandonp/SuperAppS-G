# I0 - Ficha Tecnica Del Servidor

**Producto:** S&G Super App  
**Incremento:** I0 - Descubrimiento Tecnico e Infraestructura  
**Servidor confirmado:** Windows Server 2012  
**Estado:** Levantamiento parcial con evidencia del servidor  

## 1. Identificacion Del Servidor

| Campo | Valor | Evidencia |
|-------|-------|-----------|
| Nombre del servidor | `SERVIDORGESTION` | `SG-I0-Validation-20260601-084759/SG-I0-Server-Report.md`; `03-ipconfig-all.txt` |
| Sistema operativo exacto | Windows NT 6.3.9600.0; pendiente confirmar edicion comercial por WMI alterno | `transcript.txt`; las consultas WMI fallaron |
| Arquitectura | 64 bits | `SG-I0-Server-Report.md` (`Is 64-bit OS: True`) |
| RAM | 8,371,240,960 bytes total (~7.8 GiB); 3,214,422,016 bytes disponibles (~3.0 GiB); carga 61% al momento de prueba | Comando manual `GlobalMemoryStatusEx` via `kernel32.dll` |
| CPU / nucleos | 4 procesadores logicos; modelo pendiente | Comando manual `$env:NUMBER_OF_PROCESSORS`; lectura de registro de procesador fallo por conversion |
| Disco disponible | C: 1.06 TB total / 320.98 GB libre; E: 1.00 TB total / 804.66 GB libre; F: 938.17 GB total / 163.83 GB libre; G: 2.00 TB total / 140.27 GB libre | Comando manual `[System.IO.DriveInfo]::GetDrives()` |
| Dominio/red | Grupo de trabajo `SEG_GESTION`; IP LAN `192.168.1.15` por DHCP | Captura Server Manager; `03-ipconfig-all.txt` |
| Responsable tecnico | Pendiente | Pendiente |

## 2. Acceso Y Permisos

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Tenemos acceso remoto? | Si | Captura Server Manager enviada por usuario |
| ¿Tenemos usuario administrador? | Si, sesion `SERVIDORGESTION\Administrador` ejecutando como admin | `SG-I0-Server-Report.md` |
| ¿Se permite instalar runtimes? | Pendiente | Pendiente |
| ¿Se permite crear servicios Windows? | Pendiente | Pendiente |
| ¿Hay politicas de antivirus/EDR? | Kaspersky Small Office Security instalado; politica pendiente | `10-installed-programs.csv` |

## 3. Servicios Instalados

| Servicio | Estado | Evidencia |
|----------|--------|-----------|
| IIS | No detectado | `SG-I0-Server-Report.md`: W3SVC no detectado; WebAdministration no disponible |
| PowerShell | 4.0 | `SG-I0-Server-Report.md` |
| .NET Framework | .NET Framework 4.8.03761; .NET Runtime/Desktop Runtime 6.0.10 x86 instalado | `05-dotnet-framework.txt`; `10-installed-programs.csv` |
| Java/JDK | No detectado en PATH | `SG-I0-Server-Report.md` |
| PHP | PHP 5.6.20 CLI en `C:\xampp\php\php.exe`; no esta en PATH | Comando manual `C:\xampp\php\php.exe -v` |
| Node.js | No detectado en PATH | `SG-I0-Server-Report.md` |
| Motor de base de datos | Servicio `mysql` en ejecucion; MariaDB 10.1.13 en `C:\xampp\mysql\bin\mysql.exe`; Firebird 3.0.2 instalado | `06-db-services.txt`; comando manual `C:\xampp\mysql\bin\mysql.exe --version`; `10-installed-programs.csv` |
| Servicio MySQL Windows | `AUTO_START`, ejecuta `C:\xampp\mysql\bin\mysqld.exe --defaults-file=c:\xampp\mysql\bin\my.ini mysql`, cuenta `LocalSystem` | Comando manual `sc.exe qc mysql` |

## 4. Red Y Seguridad

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Acceso solo red interna? | Pendiente confirmar; IP privada LAN `192.168.1.15` | `03-ipconfig-all.txt` |
| ¿Requiere VPN? | Pendiente | Pendiente |
| ¿DNS interno disponible? | No evidenciado; DNS configurados `200.75.51.132` y `200.75.51.133` | `03-ipconfig-all.txt` |
| ¿Certificado TLS disponible? | Pendiente | Pendiente |
| ¿Acceso a internet desde servidor? | Pendiente | Pendiente |
| ¿Salida a SMTP/correo? | Pendiente; prueba SMTP no ejecutada | `SG-I0-Server-Report.md` |
| Firewall | Perfil dominio activo con `BlockInbound,AllowOutbound`; perfiles privado/publico desactivados | `09-firewall.txt` |
| Puertos escuchando | `0.0.0.0:80` y `0.0.0.0:443` PID 1348 `httpd.exe`; `0.0.0.0:3306` PID 1512 `mysqld.exe` | Comandos manuales `netstat`; `Get-Process -Id 1348,1512` |

## 5. Base De Datos

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Motor existente? | MariaDB 10.1.13/MySQL en ejecucion; Firebird instalado | `06-db-services.txt`; comando manual MySQL/MariaDB; `10-installed-programs.csv` |
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

- Resultado generado en `scripts/i0-server-validation/SG-I0-Validation-20260601-084759`.
- Riesgo tecnico: el servicio `winmgmt` esta `RUNNING`, pero varias consultas WMI fallaron con `No encontrado` para `Win32_OperatingSystem`, `Win32_ComputerSystem`, `Win32_Processor`, `Win32_BIOS`, `Win32_LogicalDisk` y `Win32_NetworkAdapterConfiguration`. `winmgmt /verifyrepository` tambien fallo con `0x80041002`. Esto impide cerrar hardware/OS con WMI y exige validacion por comandos alternos o reparacion del repositorio WMI.
- No hay IIS detectado. Si se elige .NET con IIS, I1 requiere habilitar IIS o definir hospedaje como servicio Windows/reverse proxy.
- Firewall: el perfil dominio bloquea entrada y permite salida. Cualquier portal interno requerira regla de entrada explicita para el puerto definido o aprobacion de politica/GPO.
- XAMPP existe y tiene Apache/PHP/MySQL publicados: puertos 80 y 443 ocupados por `C:\xampp\apache\bin\httpd.exe`; puerto 3306 ocupado por `C:\xampp\mysql\bin\mysqld.exe`. El nuevo portal no debe reutilizar 80/443/3306 sin decision explicita para no afectar aplicaciones existentes.
- PHP 5.6.20 y MariaDB 10.1.13 son versiones antiguas. No se recomienda aprobarlas como stack principal del nuevo portal sin decision explicita de riesgo, aislamiento y plan de hardening.
- Kaspersky Small Office Security esta instalado; se debe confirmar si permite servicios nuevos, puertos locales, escrituras en carpeta de PDFs y tareas programadas.
- Capacidad base suficiente para piloto: ~8 GB RAM, 4 procesadores logicos y discos con espacio disponible. La menor holgura esta en `G:\` con ~140 GB libres y `F:\` con ~164 GB libres.
- `tasklist` fallo con `No encontrado`; para identificar PID usar `Get-Process` o ruta completa a ejecutables del sistema.

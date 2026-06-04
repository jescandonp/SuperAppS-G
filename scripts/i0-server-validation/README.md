# S&G Super App - Scripts I0 Server Validation

Estos scripts levantan evidencia tecnica de solo lectura para responder la SPEC I0.

## Objetivo

Generar un paquete de evidencia del servidor Windows Server 2012 para decidir:

- stack viable;
- base de datos;
- correo/SMTP;
- almacenamiento de PDFs;
- jobs/tareas programadas;
- permisos;
- restricciones de seguridad.

## Archivo principal

```text
Collect-SGServerInfo.ps1
```

## Ejecucion rapida en el servidor

Abrir PowerShell como administrador si es posible y ejecutar desde la carpeta donde copies los scripts:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Collect-SGServerInfo.ps1 -OutputRoot "."
```

El script crea una carpeta como:

```text
SG-I0-Validation-YYYYMMDD-HHMMSS
```

Dentro queda el reporte principal:

```text
SG-I0-Server-Report.md
```

## Ejecucion con pruebas de correo y base de datos

Si conoces SMTP:

```powershell
.\Collect-SGServerInfo.ps1 -OutputRoot "." -SmtpHost "smtp.dominio.com" -SmtpPort 587
```

Si conoces host de base de datos:

```powershell
.\Collect-SGServerInfo.ps1 -OutputRoot "." -DbHost "servidor-db" -DbPorts 1433,3306,5432,1521
```

Con DNS interno del futuro portal:

```powershell
.\Collect-SGServerInfo.ps1 -OutputRoot "." -PortalDns "sg-superapp.local"
```

## Que recopila

- Sistema operativo, arquitectura, RAM, CPU.
- Usuario actual y si corre como administrador.
- PowerShell version.
- Discos y espacio libre.
- Red e ipconfig.
- IIS y sitios si WebAdministration esta disponible.
- .NET Framework instalado.
- Java, Node.js, npm, PHP, Python si estan en PATH.
- Servicios de base de datos detectables.
- Prueba opcional de puertos DB.
- Prueba opcional SMTP.
- Firewall.
- Antivirus si el namespace WMI esta disponible.
- Programas instalados en CSV.

## Seguridad

El script es de solo lectura:

- no instala dependencias;
- no cambia configuracion;
- no crea usuarios;
- no abre puertos;
- no reinicia servicios;
- no modifica IIS;
- no prueba credenciales.

## Como usar el resultado

1. Copiar la carpeta `SG-I0-Validation-*` de regreso al workspace.
2. Usar `SG-I0-Server-Report.md` para completar:
   - `docs/plans/i0-ficha-tecnica-servidor.md`
   - `docs/plans/i0-matriz-decision-stack.md`
3. Con la evidencia, actualizar:
   - `docs/TECNOLOGIA.md`
4. Cerrar I0 y pasar a SPEC I1/plan de implementacion.

## Si PowerShell bloquea scripts

Usar:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Tambien se puede ejecutar asi:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Collect-SGServerInfo.ps1 -OutputRoot "."
```

# I0 - Ambiente De Desarrollo Local

**Producto:** S&G Super App  
**Stack objetivo preliminar:** React SPA + backend .NET compatible + PostgreSQL  
**Proposito:** Preparar el ambiente local antes de iniciar I1 sin depender del Windows Server 2012 para compilar frontend ni instalar herramientas modernas.

## 1. Principio De Instalacion

El ambiente local debe tener todas las herramientas de desarrollo. El servidor S&G debe recibir artefactos desplegables y servicios controlados, no convertirse en maquina de desarrollo.

| Capa | Local desarrollo | Servidor piloto |
|------|------------------|-----------------|
| Frontend | Node.js LTS, npm, React build | Archivos estaticos compilados |
| Backend | Visual Studio, .NET Framework 4.8 Developer Pack | Runtime/hosting validado en puerto separado |
| DB | PostgreSQL local | PostgreSQL aislado o DB aprobada |
| DB tooling | DBeaver o pgAdmin | No obligatorio |
| Scripts | PowerShell moderno local | PowerShell 4-compatible en servidor |

## 2. Instalacion Recomendada Con Winget

Ejecutar PowerShell como administrador.

```powershell
winget --version
```

Si `winget` existe, instalar:

```powershell
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e
winget source update
winget search --source winget PostgreSQL
winget search --source winget DBeaver
winget install --id PostgreSQL.PostgreSQL --source winget -e
winget install --id DBeaver.DBeaver.Community --source winget -e
winget install --id Microsoft.VisualStudio.2022.Community -e
```

Durante la instalacion de Visual Studio seleccionar:

```text
ASP.NET and web development
.NET desktop development
.NET Framework 4.8 targeting pack / Developer Pack
```

Opcional:

```powershell
winget install --id Microsoft.VisualStudioCode -e
winget install --id Postman.Postman -e
```

Si `winget` no encuentra paquetes, reparar catalogo:

```powershell
winget source list
winget source reset --force
winget source update
```

Si aun falla, instalar manualmente desde fuentes oficiales:

- PostgreSQL Windows installer: `https://www.postgresql.org/download/windows/`
- DBeaver Community: `https://dbeaver.io/download/`

## 3. PostgreSQL Local

Crear una base local para desarrollo:

```sql
CREATE DATABASE sg_superapp_dev;
CREATE USER sg_app WITH PASSWORD 'Cambiar_Esta_Clave_Local';
GRANT ALL PRIVILEGES ON DATABASE sg_superapp_dev TO sg_app;
```

Regla: la clave local no debe copiarse a documentos compartidos ni al repositorio.

## 4. Validacion Local

Desde la raiz del proyecto ejecutar:

```powershell
.\scripts\i0-local-dev\Check-SGLocalDev.ps1
```

El resultado esperado es:

```text
Git: OK
Node.js: OK
npm: OK
PostgreSQL client: OK
.NET Framework 4.8: OK
Visual Studio: OK o Pendiente validar manualmente
```

## 5. Decision De Frontend

Se adopta React como recomendacion preliminar:

- SPA modular para portal por perfiles.
- Build estatico, desplegable sin Node.js en produccion.
- Buena base para dashboard, notificaciones, formularios y modulos futuros.
- Compatible con evolucion hacia infraestructura moderna sin reescribir la UI.

Angular sigue como alternativa valida si el equipo mantenedor confirma experiencia fuerte en Angular.

## 6. Decision De Backend

Para compatibilidad con el servidor actual:

- Backend compatible con .NET Framework 4.8.
- API REST para separar frontend y backend.
- Evitar dependencia directa de XAMPP/PHP.
- Mantener opcion futura de migrar a .NET moderno si mejora la infraestructura.

## 7. Decision De Base De Datos

PostgreSQL es la opcion recomendada para el desarrollo y el piloto, siempre que se pueda instalar o disponer como servicio aislado.

Condiciones:

- no usar la MariaDB antigua de XAMPP como primera opcion;
- no tocar `C:\xampp\mysql` sin decision explicita;
- definir backups desde el primer despliegue piloto;
- versionar scripts de esquema y datos semilla.

## 8. Criterio De Listo Para I1

El ambiente local queda listo cuando:

- Visual Studio puede crear/abrir proyecto .NET Framework 4.8;
- Node.js y npm compilan una app React;
- PostgreSQL responde localmente;
- DBeaver/pgAdmin puede conectarse a `sg_superapp_dev`;
- se define estrategia de variables locales sin secretos en repositorio;
- se valida que el servidor productivo no requiere Node.js para ejecutar el frontend.

## 9. Chequeo Local Inicial - 2026-06-02

Resultado de `scripts/i0-local-dev/Check-SGLocalDev.ps1` en la maquina local:

| Componente | Estado | Evidencia |
|------------|--------|-----------|
| Git | OK | `git version 2.50.1.windows.1` |
| Node.js | OK | `v22.16.0` |
| npm | OK | `11.12.0` |
| PostgreSQL client | Falta | `psql` no detectado en PATH |
| PostgreSQL local | Falta | `localhost:5432` no reachable |
| .NET Framework 4.8 runtime | OK | Release `533509` |
| Visual Studio / Build Tools | Parcial | Visual Studio Build Tools 2019 detectado |
| DBeaver | Opcional / falta | No detectado en PATH |

Accion inmediata: instalar PostgreSQL local y una herramienta DB. Recomendado instalar Visual Studio 2022 Community si se requiere IDE completo para backend .NET Framework.

## 10. Chequeo Local Actualizado - 2026-06-02

Resultado posterior a instalar PostgreSQL:

| Componente | Estado | Evidencia |
|------------|--------|-----------|
| Git | OK | `git version 2.50.1.windows.1` |
| Node.js | OK | `v22.16.0` |
| npm | OK | `11.12.0` |
| PostgreSQL client | OK | `psql (PostgreSQL) 18.4` en `C:\Program Files\PostgreSQL\18\bin\psql.exe` |
| PostgreSQL local | OK | `localhost:5432` reachable |
| .NET Framework 4.8 runtime | OK | Release `533509` |
| Visual Studio / Build Tools | Parcial | Visual Studio Build Tools 2019 detectado |
| DBeaver | Opcional / falta | No detectado en PATH |

Estado: ambiente local suficiente para iniciar configuracion de base de datos y scaffolding inicial. Para desarrollo backend comodo, sigue recomendado instalar Visual Studio 2022 Community o confirmar IDE equivalente.

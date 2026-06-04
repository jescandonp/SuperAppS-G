# Base de datos I1

Este directorio contiene la base versionada para el portal base de la S&G Super App.

## Estructura

- `bootstrap/`: scripts administrativos para crear rol, base y prerequisitos locales.
- `migrations/`: esquema transaccional versionado del incremento.
- `seeds/`: datos controlados de arranque para desarrollo.

## Flujo local propuesto

1. Crear rol y base:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U postgres -f 'db/bootstrap/001_create_sg_superapp_dev.sql'
```

Nota: el script usa `\gexec` para crear la base solo si no existe. Debe ejecutarse con `psql`, no copiando el SQL manualmente dentro de otro cliente.

2. Aplicar esquema:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U sg_app -d sg_superapp_dev -f 'db/migrations/001_identity_and_access.sql'
```

3. Aplicar seeds:

```powershell
& 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -U sg_app -d sg_superapp_dev -f 'db/seeds/001_roles_and_permissions.sql'
```

## Wrapper PowerShell

Tambien puede ejecutarse el flujo completo con:

```powershell
.\scripts\dev\Init-SgSuperAppDb.ps1
```

Si `postgres` requiere password:

```powershell
.\scripts\dev\Init-SgSuperAppDb.ps1 -PostgresPassword '<password-postgres>'
```

## Alcance I1

La base inicial cubre:

- usuarios internos;
- roles fijos del MVP;
- permisos por modulo/accion;
- notificaciones shell;
- auditoria minima.

No cubre todavia maestros funcionales de I2+.

## Seed funcional I1

Los seeds dejan preparado:

- usuario `admin.sg`
- contrasena inicial `Admin123`
- rol `ADMIN`
- notificaciones shell de arranque

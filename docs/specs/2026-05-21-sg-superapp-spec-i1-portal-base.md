# SPEC I1 - Portal Base

**Fecha:** 2026-05-21  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I1  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**PRD base:** `docs/prd/2026-05-21-sg-super-app-piloto-th-prd.md`  
**SPEC previa:** `docs/specs/2026-05-21-sg-superapp-spec-i0-descubrimiento-tecnico-infraestructura.md`  
**Estado:** Aprobada para planeacion y ejecucion de I1 con stack definido en I0  

---

## 1. Proposito

Definir el portal base de la S&G Super App para el piloto interno administrativo. Este incremento crea la experiencia inicial sobre la que se conectaran datos maestros, certificaciones, cursos/acreditaciones, alertas, notificaciones y dashboard.

I1 no implementa los modulos funcionales de Talento Humano. Establece acceso, perfiles, navegacion, shell visual, dashboard base y reglas de permisos.

---

## 2. Alcance

### Incluido

- Pantalla de login interno.
- Usuarios internos del portal.
- Roles iniciales.
- Permisos base por rol.
- Layout principal.
- Menu de modulos.
- Dashboard shell.
- Acceso visual a notificaciones.
- Perfil de usuario basico.
- Pantallas placeholder para modulos futuros.
- Control de rutas/pantallas segun rol.

### Fuera de alcance

- CRUD completo de empleados/guardas.
- Carga Excel.
- Certificaciones laborales.
- Cursos/acreditaciones.
- Generacion PDF.
- Envio real de correo.
- Novedades funcionales.
- Integracion HELIZA.
- Guardas como usuarios del portal.
- Active Directory/SSO, salvo que I0 lo apruebe.

---

## 3. Actores

### Administrador

Usuario interno responsable de configuracion inicial, usuarios, roles y parametros base.

### Talento Humano

Usuario interno responsable de gestionar empleados/guardas, certificaciones, cursos/acreditaciones y alertas TH en incrementos posteriores.

### Gerencia / Consulta

Usuario de consulta ejecutiva. Accede a dashboard e informacion consolidada sin editar datos operativos.

### Operaciones / Consulta

Usuario de consulta operativa. Accede a informacion relevante de guardas, puestos, habilitacion y futuras novedades sin editar datos TH en MVP.

---

## 4. Roles Y Permisos Base

Los roles del MVP seran **fijos**, no configurables por Administrador durante el piloto.

Justificacion:

- reduce complejidad de seguridad en el primer incremento;
- evita que una mala configuracion deje usuarios con permisos indebidos;
- permite probar rapidamente el modelo de acceso;
- mantiene la posibilidad futura de roles configurables si el piloto escala.

El Administrador podra asignar usuarios a roles existentes, pero no crear nuevos roles ni modificar la matriz de permisos en el MVP.

| Modulo / Accion | Administrador | Talento Humano | Gerencia/Consulta | Operaciones/Consulta |
|-----------------|---------------|----------------|-------------------|----------------------|
| Acceder al portal | Si | Si | Si | Si |
| Ver dashboard | Si | Si | Si | Si |
| Ver notificaciones propias | Si | Si | Si | Si |
| Ver notificaciones por rol | Si | Si | Si | Si |
| Configurar usuarios | Si | No | No | No |
| Configurar roles/permisos | Si | No | No | No |
| Ver menu Empleados/Guardas | Si | Si | Si | Si |
| Editar empleados/guardas | No en I1 | No en I1 | No | No |
| Ver menu Puestos de Servicio | Si | Si | Si | Si |
| Editar puestos | No en I1 | No en I1 | No | No |
| Ver menu Certificaciones | Si | Si | Si | No |
| Ver menu Cursos/Acreditaciones | Si | Si | Si | Si |
| Ver menu Cargas de Datos | Si | Si | No | No |
| Ver menu Configuracion | Si | No | No | No |
| Ver menu Novedades Proximamente | Si | Si | Si | Si |

Nota: en I1, muchos menus abren placeholders. Las capacidades CRUD se activan en incrementos posteriores.

---

## 5. Navegacion Principal

El portal debe mostrar estos modulos:

1. Inicio / Dashboard
2. Empleados / Guardas
3. Puestos de Servicio
4. Cursos y Acreditaciones
5. Certificaciones Laborales
6. Alertas
7. Notificaciones
8. Cargas de Datos
9. Configuracion
10. Novedades - Proximamente / En diseno

Cada opcion debe:

- estar protegida por permiso;
- mostrar estado si aun no esta implementada;
- mantener coherencia visual con `docs/DESIGN.md`;
- permitir evolucionar sin rediseñar el shell.

---

## 6. Pantalla De Login

### Campos

- Usuario
- Contrasena

### Comportamiento

- Si credenciales son validas, redirige al dashboard.
- Si credenciales son invalidas, muestra mensaje claro.
- Si usuario esta inactivo, no permite acceso.
- Si rol no existe o no tiene permisos, no permite acceso.
- El login inicial sera usuario/contrasena local hasta que I0 defina si existe una alternativa viable.
- La sesion debe expirar por inactividad.
- El tiempo de expiracion recomendado para MVP es 30 minutos de inactividad.

### Mensajes

| Caso | Mensaje |
|------|---------|
| Credenciales invalidas | Usuario o contrasena incorrectos. |
| Usuario inactivo | El usuario no se encuentra activo. Contacte al administrador. |
| Sesion expirada | Su sesion expiro. Ingrese nuevamente. |

### Politica Minima De Contrasenas

La politica minima para usuarios locales del MVP sera:

- longitud minima: 8 caracteres;
- al menos una letra;
- al menos un numero;
- no permitir contrasenas vacias;
- no permitir que la contrasena sea igual al usuario;
- almacenar solo hash, nunca contrasena plana.

Si I0 define una tecnologia con capacidades adicionales, podran agregarse reglas como mayuscula, simbolo, bloqueo por intentos fallidos o expiracion periodica.

---

## 7. Layout Principal

El layout debe incluir:

- header superior;
- identificador S&G Super App;
- menu lateral o principal;
- nombre/rol del usuario;
- icono de notificaciones con contador;
- acceso a perfil;
- area de contenido;
- estado visual del modulo activo.

El diseño debe ser administrativo, compacto y alineado con S&G dark/gold.

---

## 8. Dashboard Shell

I1 solo define el shell del dashboard, no indicadores finales.

El dashboard I1 debe mostrar **estados vacios y textos de modulo pendiente**, no datos simulados.

Justificacion:

- evita confundir a stakeholders con cifras no reales;
- mantiene honestidad sobre el estado del piloto;
- prepara la estructura visual sin inventar informacion;
- permite que cada incremento posterior active datos reales.

### Widgets base por rol

| Widget | Administrador | Talento Humano | Gerencia/Consulta | Operaciones/Consulta |
|--------|---------------|----------------|-------------------|----------------------|
| Resumen del piloto | Si | Si | Si | Si |
| Modulos disponibles | Si | Si | Si | Si |
| Alertas pendientes placeholder | Si | Si | Si | Si |
| Notificaciones recientes placeholder | Si | Si | Si | Si |
| Estado de cargas placeholder | Si | Si | No | No |
| Estado de configuracion | Si | No | No | No |
| Guardas no habilitados placeholder | Si | Si | Si | Si |

Los widgets reales se completaran en I2-I7.

---

## 9. Notificaciones Shell

I1 debe incluir la estructura visual de notificaciones:

- contador junto al perfil;
- bandeja desplegable o vista de notificaciones;
- estados visuales leida/no leida;
- acciones visibles: marcar como leida, archivar/borrar;
- separacion conceptual entre personales y por rol.

En I1 no se requiere motor real de reglas de notificacion. Ese motor entra en I6.

---

## 10. Perfil De Usuario

El usuario debe poder ver:

- nombre;
- usuario/login;
- rol;
- estado;
- fecha/hora de ultimo acceso si esta disponible.

En I1 no se requiere edicion avanzada de perfil.

---

## 11. Pantallas Placeholder

Para modulos no implementados en I1, mostrar una pantalla con:

- nombre del modulo;
- estado: Proximamente / En diseno / Pendiente siguiente incremento;
- breve descripcion del alcance futuro;
- incremento asociado.

Ejemplos:

| Modulo | Estado | Incremento |
|--------|--------|------------|
| Empleados / Guardas | Pendiente implementacion | I2 |
| Puestos de Servicio | Pendiente implementacion | I3 |
| Certificaciones Laborales | Pendiente implementacion | I4 |
| Cursos y Acreditaciones | Pendiente implementacion | I5 |
| Alertas y Notificaciones | Pendiente implementacion | I6 |
| Novedades | Proximamente / En diseno | Futuro |

---

## 12. Reglas Funcionales

1. Un usuario debe tener al menos un rol.
2. Un usuario inactivo no puede iniciar sesion.
3. Todo usuario autenticado debe llegar al dashboard.
4. El menu debe ocultar o deshabilitar opciones sin permiso.
5. Las pantallas placeholder no deben permitir acciones funcionales no implementadas.
6. El portal debe mostrar claramente el perfil activo.
7. El dashboard debe renderizar widgets segun rol.
8. La bandeja de notificaciones debe existir como shell, aunque use datos simulados o vacios en I1.
9. El modulo Novedades debe mostrarse como futuro, no como funcional.
10. Los roles del MVP son fijos.
11. El Administrador asigna roles existentes, pero no crea roles nuevos en MVP.
12. La sesion expira tras 30 minutos de inactividad, salvo que I0 obligue a otro valor.
13. Las contrasenas locales deben cumplir la politica minima definida.
14. El dashboard I1 muestra estados vacios, no metricas simuladas.

---

## 13. Datos Minimos De I1

### Usuario

| Campo | Requerido | Comentario |
|-------|-----------|------------|
| id | Si | Identificador interno |
| nombre | Si | Nombre visible |
| usuario | Si | Login unico |
| contrasena_hash | Si | No guardar contrasena plana |
| rol | Si | Uno de los roles iniciales |
| estado | Si | Activo/Inactivo |
| ultimo_acceso | No | Si la tecnologia lo permite en I1 |

### Rol

| Campo | Requerido | Comentario |
|-------|-----------|------------|
| id | Si | Identificador interno |
| codigo | Si | ADMIN, TH, GERENCIA, OPERACIONES |
| nombre | Si | Nombre visible |
| descripcion | Si | Alcance del rol |

### Permiso

| Campo | Requerido | Comentario |
|-------|-----------|------------|
| modulo | Si | Modulo del menu |
| accion | Si | Ver, crear, editar, eliminar, aprobar |
| rol | Si | Rol asociado |
| permitido | Si | Booleano |

---

## 14. Dependencias Tecnicas De I0

I1 depende de I0 para:

- stack backend/frontend;
- motor de base de datos;
- mecanismo de autenticacion real;
- estrategia de sesiones;
- ubicacion de despliegue;
- restricciones de IIS/app server/servicio;
- estrategia de logs.

El stack de entrada a I1 queda definido por cierre I0: React SPA + backend .NET compatible + API REST + PostgreSQL. Las decisiones de detalle de scaffolding y despliegue deben resolverse en el plan I1 sin contradecir `docs/TECNOLOGIA.md`.

---

## 15. Criterios De Aceptacion

I1 se considera aceptado cuando:

1. Existe login interno funcional.
2. Un usuario activo puede iniciar sesion.
3. Un usuario inactivo no puede iniciar sesion.
4. Los cuatro roles iniciales existen.
5. El menu se muestra segun permisos.
6. El dashboard shell se muestra despues del login.
7. Los widgets base se ajustan al rol.
8. El icono/contador de notificaciones aparece junto al perfil.
9. La bandeja o pantalla de notificaciones existe como shell.
10. Los modulos futuros muestran placeholder y no ejecutan acciones funcionales.
11. Novedades aparece como Proximamente / En diseno.
12. La UI respeta `docs/DESIGN.md`.
13. Las decisiones tecnicas utilizadas estan registradas en `docs/TECNOLOGIA.md`.

---

## 16. Pruebas Esperadas

Las pruebas concretas dependeran del stack definido por I0, pero deben cubrir:

- login exitoso;
- login fallido;
- usuario inactivo;
- permisos por rol;
- menu por rol;
- redireccion al dashboard;
- visualizacion de placeholders;
- shell de notificaciones;
- visibilidad de widgets por rol.

---

## 17. Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| I0 no define stack a tiempo | Alto | Mantener I1 como SPEC funcional hasta cierre tecnico |
| Permisos demasiado amplios | Medio | Definir matriz inicial y validar con stakeholders |
| Dashboard sobrecargado | Medio | Mantener widgets shell y crecer por incremento |
| Notificaciones se confunden con alertas reales | Bajo | Rotular como shell o placeholder en I1 |
| UI se vuelve landing page | Medio | Aplicar `docs/DESIGN.md` y prototipos |

---

## 18. Preguntas Abiertas

No quedan preguntas funcionales abiertas para I1.

Decisiones cerradas:

1. Roles fijos en MVP; Administrador solo asigna roles existentes.
2. Sesion con expiracion por inactividad.
3. Tiempo recomendado de expiracion: 30 minutos.
4. Politica minima de contrasenas obligatoria.
5. Login inicial con usuario/contrasena local hasta que I0 defina una alternativa.
6. Dashboard I1 con estados vacios y textos de modulo pendiente, no datos simulados.

---

## 19. Estado De La SPEC I1

Esta SPEC queda lista como contrato funcional del Portal Base. La implementacion queda bloqueada hasta cerrar I0 y actualizar `docs/TECNOLOGIA.md`.

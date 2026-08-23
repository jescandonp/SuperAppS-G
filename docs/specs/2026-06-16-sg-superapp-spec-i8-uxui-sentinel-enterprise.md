# SPEC I8 - UX/UI Sentinel Enterprise

**Fecha:** 2026-06-16  
**Producto:** S&G Super App  
**Fase:** Piloto Talento Humano  
**Incremento:** I8  
**Metodo:** SDD - Spec-Driven Development, nivel Spec-Anchored  
**Documentos rectores:** `docs/CONSTITUTION.md`, `docs/ARCHITECTURE.md`, `docs/TECNOLOGIA.md`, `docs/DESIGN.md`  
**Referencia visual obligatoria:** `Prototipos/stitch_ecosistema_digital_unificado/sentinel_enterprise/DESIGN.md`  
**Estado:** Aprobada para planificacion e implementacion UX/UI incremental

## 1. Proposito

Elevar la experiencia visual del portal administrativo hacia la referencia Sentinel Enterprise, sin cambiar reglas de negocio, contratos backend, permisos ni alcance funcional del piloto.

## 2. Alcance

Incluido:

- tokens visuales Sentinel Enterprise para la SPA React;
- shell administrativo con navegacion persistente, topbar, bandeja y workspace mas legibles;
- dashboard I7 refinado para lectura ejecutiva/operativa;
- auditoria I7 refinada para filtros, tabla y detalle de alta densidad;
- verificacion estructural y build frontend.

Excluido:

- nuevos endpoints o cambios backend;
- nuevos permisos;
- nuevas funcionalidades de modulos I1-I7;
- landing page comercial;
- IA, WhatsApp, HELIZA, nomina o novedades funcionales.

## 3. Reglas UX/UI

1. La UI debe usar una consola enterprise clara con azul corporativo `#003366` y dorado `#FFC700` como acento controlado.
2. Las superficies deben usar capas claras y bordes discretos para mejorar lectura prolongada.
3. Dashboard y auditoria deben seguir siendo compactos, escaneables y orientados a decision.
4. La navegacion debe hacer visible estado de modulo y contexto del piloto.
5. La bandeja de notificaciones debe mantener filtros y acciones existentes.
6. Los estados de carga, error y vacio deben conservarse.
7. No se debe ocultar informacion de rol, fuente de datos ni restricciones de solo lectura.
8. Los componentes deben respetar radios sobrios, foco visible y contraste suficiente.

## 4. Pantallas

- Login: queda fuera del primer corte salvo tokens globales.
- Shell: navegacion, topbar, usuario, contador y notificaciones.
- Dashboard: resumen por perfil, widgets agrupados y acciones internas.
- Auditoria: filtros, tabla compacta y detalle estructurado.

## 5. Criterios De Aceptacion

1. `docs/DESIGN.md` referencia la variante Sentinel Enterprise.
2. La SPA expone tokens CSS Sentinel Enterprise.
3. Shell usa clase de consola enterprise y mantiene navegacion por modulo.
4. Dashboard conserva widgets por scope y estados de carga/error/vacio.
5. Auditoria conserva filtros por modulo, actor y fechas.
6. Tablas, tarjetas, formularios y chips usan superficies claras y bordes discretos.
7. Acciones primarias usan dorado, acciones secundarias usan azul corporativo o ghost.
8. Build frontend pasa.
9. `graphify update .` se intenta despues de modificar codigo.

## 6. Pruebas Esperadas

- `scripts/dev/Verify-SgSuperAppI8SentinelUx.ps1`
- `npm run build` en `apps/sg-superapp-web`
- intento de `graphify update .`

## 7. Decision De Entrada

Retake inicial autorizado: Task 1 del plan I8, base visual Sentinel Enterprise para shell, dashboard y auditoria.

# Checklist De Demostracion I9

> Estado: **VALIDACION_VISUAL_APROBADA_PILOTO_FUNCIONAL_PENDIENTE**
> Fecha de actualizacion: 2026-08-13
> Alcance: Programacion asistida de turnos, sin datos personales reales.

## Precondiciones

- [ ] Base local con migraciones I9 `009`, `010` y `011` aplicadas.
- [ ] Proyecto, puestos, cobertura y disponibilidad cargados con datos anonimizados.
- [ ] Parametros de las siete reglas validados; el catalogo deja de estar solo
      aprobado para parametrizacion mediante acto documental separado.
- [ ] Usuario de Operaciones y aprobadores disponibles para el recorrido.

## Recorrido Funcional

- [ ] Seleccionar proyecto y periodo; verificar estado vacio antes de generar.
- [ ] Confirmar plantillas 2x2, 4x2 y 6x1 como obligatorias por defecto.
- [ ] Generar propuesta y registrar tiempo de respuesta.
- [ ] Revisar matriz D/N/X/VACANTE y explicación de al menos tres asignaciones.
- [ ] Comparar `MINIMUM_IMPACT` y `GLOBAL` sin declarar ganador automatico.
- [ ] Registrar desviacion con motivo, responsable y fecha.
- [ ] Aprobar y publicar con usuarios autorizados distintos cuando aplique.
- [ ] Confirmar que la version publicada es de solo lectura.
- [ ] Exportar PDF y Excel y validar proyecto, periodo, version y responsable.

## Accesibilidad Y Responsive

- [x] 320 px: validacion visual aprobada por el usuario el 2026-08-13.
- [x] 768 px: validacion visual aprobada por el usuario el 2026-08-13.
- [x] 1024 px: validacion visual aprobada por el usuario el 2026-08-13.
- [x] 1440 px: validacion visual aprobada por el usuario el 2026-08-13.
- [x] Validacion visual general aprobada por el usuario el 2026-08-13.

La aprobacion anterior es evidencia humana proporcionada por el usuario; no se
presenta como captura o medicion automatizada de cada viewport.

## Criterio De Cierre

Todos los puntos deben tener evidencia fechada. Un fallo funcional, la falta de
ejecucion/comparacion del piloto o reglas sin parametros validados impide cerrar
Gate 5.

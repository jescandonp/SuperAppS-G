# Checklist De Demostracion I9

> Estado: **PENDIENTE_DE_EJECUCION_HUMANA**
> Fecha de preparacion: 2026-08-12
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

- [ ] 320 px: filtros y lista diaria sin desplazamiento horizontal de pagina.
- [ ] 768 px: navegación, detalle y acciones operables por teclado.
- [ ] 1024 px: matriz con scroll interno y encabezado sticky.
- [ ] 1440 px: resumen, matriz y detalle legibles sin solapamientos.
- [ ] El foco es visible; D/N/X/VACANTE tienen etiqueta textual además del color.

## Criterio De Cierre

Todos los puntos deben tener evidencia fechada. Un fallo funcional, la falta del
piloto anonimizado o reglas sin parametros validados impide cerrar Gate 5.

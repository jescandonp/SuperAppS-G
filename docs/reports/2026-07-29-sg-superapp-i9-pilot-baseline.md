# Linea Base De Piloto I9

> Estado: **PENDIENTE_DE_DATOS_Y_EJECUCION**
> Fecha de preparacion: 2026-08-12
> Regla de evidencia: no completar valores sin fuente historica anonimizada.

## Fuente Requerida

Se requiere una programacion historica representativa, sin nombres, documentos,
telefonos ni otros identificadores personales. Debe conservar un identificador
tecnico estable por guarda, proyecto, puesto, fecha, turno, novedad y ajuste
manual para permitir la comparación.

## Metricas Del Piloto

| Metrica | Historico | Propuesta I9 | Diferencia | Estado |
|---|---:|---:|---:|---|
| Cobertura (%) | Pendiente | Pendiente | Pendiente | Sin fuente |
| Tiempo de generacion | No aplica | Pendiente | No aplica | Sin ejecucion |
| Cambios manuales | Pendiente | Pendiente | Pendiente | Sin fuente |
| Vacantes | Pendiente | Pendiente | Pendiente | Sin fuente |
| Excepciones | Pendiente | Pendiente | Pendiente | Sin fuente |
| Horas adicionales estimadas | Pendiente | Pendiente | Pendiente | Sin fuente |
| Turnos nocturnos | Pendiente | Pendiente | Pendiente | Sin fuente |
| Domingos y festivos | Pendiente | Pendiente | Pendiente | Sin fuente |
| Desviaciones de plantilla | Pendiente | Pendiente | Pendiente | Sin fuente |

## Resultado De Suite Al Abrir Task 13

Ejecucion del 2026-08-12:

- PASS: configuracion, documentos, elegibilidad, persistencia aislada, contrato
  frontend, recomendaciones, ciclos de turno e interfaz.
- FAIL inicial por base local incompleta: exportaciones, reprogramacion,
  seguridad y workflow; faltaban `schedules` y `schedule_versions`.
- Se aplicaron de forma idempotente las migraciones I9 `009`, `010`, `011` y
  semillas `009`, `010` en la base local de desarrollo.
- Retake posterior: exportaciones `404` por no existir version publicada de
  prueba; reprogramacion `409` por no existir una version elegible; seguridad
  devolvio `500` al generar propuesta; workflow no obtuvo el snapshot esperado.

Estos resultados no satisfacen Gate 5. No se infieren métricas ni aprobación a
partir de verificadores parciales.

## Decision Pendiente

La optimizacion avanzada solo podrá evaluarse después de completar esta tabla y
comparar la heuristica con el histórico. Este documento no autoriza reglas aún
no parametrizadas ni publicación en un entorno productivo.

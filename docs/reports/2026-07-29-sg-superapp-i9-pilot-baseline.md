# Linea Base De Piloto I9

> Estado: **HISTORICO_SIMULADO_RECIBIDO_PENDIENTE_DE_EJECUCION_I9**
> Fecha de actualizacion: 2026-08-13
> Regla de evidencia: no completar valores que la fuente no permita calcular.

## Fuentes Recibidas

El usuario aporto el 2026-08-13 dos PDF y declaro expresamente que contienen
datos simulados:

- `BOTANIKA JULIO.pdf`.
- `BOTANIKA AGOSTO.pdf`.

Trazabilidad SHA-256:

- Julio: `38E91CE343A0A8D17FDF40C01B0A9D91ED4FBCB558A9D9017C12126BB05338D5`.
- Agosto: `A9D16CE5A0801B9CBD4C3302371547B9BDB06C4CD67790BE39BDA1288E4997E1`.

Ambos documentos tienen una pagina y su contenido visual es identico. Los dos
estan rotulados `Julio de 2026`, version `01`, fecha de elaboracion `13-08-2026`,
puesto `BOTANIKA`, turno `2x2`, cinco puestos y una grilla de 16 guardas. El
encabezado, sin embargo, declara 15 guardas. Por esa inconsistencia, el archivo
denominado agosto no se contabiliza como un segundo periodo. Los nombres visibles
no se reproducen en este artefacto; la atribucion de que son simulados proviene
del usuario.

## Linea Base Observable - Julio De 2026

La grilla contiene 496 celdas (16 filas por 31 dias). El conteo reproducible de
codigos visibles es:

| Codigo | Cantidad |
|---|---:|
| D - Dia | 157 |
| N - Noche | 156 |
| X - Descanso | 165 |
| A - Ausencia | 8 |
| INC - Incapacidad | 8 |
| V - Vacaciones | 1 |
| TA - Turno adicional | 1 |
| **Total** | **496** |

Se observan 313 turnos ordinarios D/N, un turno adicional, 17 novedades
A/INC/V y 37 turnos D/N/TA en domingos. El PDF no identifica festivos de forma
separada.

## Metricas Del Piloto

| Metrica | Historico simulado | Propuesta I9 | Diferencia | Estado |
|---|---:|---:|---:|---|
| Cobertura (%) | No calculable | Pendiente | Pendiente | Sin asignacion puesto-turno por celda |
| Tiempo de generacion | No aplica | Pendiente | No aplica | Sin ejecucion del piloto |
| Cambios manuales | No calculable | Pendiente | Pendiente | La fuente no distingue cambios |
| Vacantes | No calculable | Pendiente | Pendiente | No existe codigo de vacante observable |
| Excepciones A/INC/V | 17 | Pendiente | Pendiente | Historico calculado |
| Turnos adicionales | 1 | Pendiente | Pendiente | Historico calculado |
| Horas adicionales estimadas | No calculable | Pendiente | Pendiente | Sin duracion atribuible al codigo TA |
| Turnos nocturnos | 156 | Pendiente | Pendiente | Historico calculado |
| Turnos en domingos | 37 | Pendiente | Pendiente | Historico calculado |
| Festivos | No calculable | Pendiente | Pendiente | No diferenciados en la fuente |
| Desviaciones de plantilla | No calculable | Pendiente | Pendiente | Novedad no equivale automaticamente a desviacion |

## Evidencia Tecnica Y Visual

- El retake hermetico del 2026-08-12 termino en PASS para configuracion,
  elegibilidad, recomendaciones, ciclos, workflow, seguridad, reprogramacion y
  exportaciones; tambien pasaron documentos, frontend, persistencia e interfaz.
- Las compilaciones .NET y Vite terminaron sin errores.
- El usuario aprobo expresamente la validacion visual el 2026-08-13. Esta es una
  aprobacion humana aportada por el usuario, no una medicion visual inferida por
  los verificadores.

## Condiciones Pendientes De Gate 5

El historico simulado y la aprobacion visual satisfacen esas dos entradas del
piloto, pero no cierran Task 13 ni Gate 5. Aun se requiere:

1. Corregir o confirmar el periodo del archivo denominado agosto y la diferencia
   entre 15 guardas declarados y 16 filas visibles.
2. Ejecutar I9 con un conjunto estructurado que relacione guarda, puesto, fecha y
   turno, y registrar las metricas de la propuesta.
3. Comparar historico y propuesta sin completar datos no observables.
4. Completar y validar los parametros de las siete reglas normativas antes de
   declararlas ejecutables.

Este documento no autoriza reglas incompletas ni publicacion productiva.

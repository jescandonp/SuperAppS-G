\set ON_ERROR_STOP on

BEGIN;

INSERT INTO import_batches (
    load_type,
    file_name,
    uploaded_by,
    status,
    total_records,
    valid_records,
    incomplete_records,
    duplicate_records,
    invalid_records,
    created_at,
    imported_at
)
SELECT *
FROM (
    VALUES
        ('EMPLEADOS', 'Talento Humano(Sheet1).csv', 'admin.sg', 'IMPORTADA', 42, 35, 3, 2, 2, NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
        ('EMPLEADOS', 'Talento Humano.xlsx', 'admin.sg', 'CON_ERRORES', 18, 11, 4, 1, 2, NOW() - INTERVAL '1 day', NULL),
        ('EMPLEADOS', 'Novedades RRHH 2026.xlsx', 'admin.sg', 'PREVALIDADA', 27, 19, 5, 1, 2, NOW() - INTERVAL '4 hours', NULL)
) AS seed(load_type, file_name, uploaded_by, status, total_records, valid_records, incomplete_records, duplicate_records, invalid_records, created_at, imported_at)
WHERE NOT EXISTS (
    SELECT 1
    FROM import_batches ib
    WHERE ib.file_name = seed.file_name
      AND ib.created_at::date = seed.created_at::date
);

WITH batch_map AS (
    SELECT id, file_name
    FROM import_batches
    WHERE file_name IN ('Talento Humano.xlsx', 'Novedades RRHH 2026.xlsx')
)
INSERT INTO import_batch_errors (import_batch_id, row_number, field_name, error_type, message, original_value)
SELECT bm.id, e.row_number, e.field_name, e.error_type, e.message, e.original_value
FROM batch_map bm
JOIN (
    VALUES
        ('Talento Humano.xlsx', 8, 'numero_identificacion', 'INCOMPLETO', 'La identificacion no puede estar vacia.', ''),
        ('Talento Humano.xlsx', 11, 'salario_base', 'FORMATO_INVALIDO', 'El salario base debe ser numerico.', '1.8MM'),
        ('Talento Humano.xlsx', 14, 'numero_identificacion', 'DUPLICADO', 'La identificacion ya existe en el archivo.', '1023456789'),
        ('Novedades RRHH 2026.xlsx', 4, 'estado_laboral', 'VALOR_NO_RECONOCIDO', 'No fue posible inferir el estado laboral.', 'PEND'),
        ('Novedades RRHH 2026.xlsx', 9, 'fecha_ingreso', 'FORMATO_INVALIDO', 'La fecha de ingreso no tiene formato valido.', '32/13/2025')
) AS e(file_name, row_number, field_name, error_type, message, original_value)
    ON e.file_name = bm.file_name
WHERE NOT EXISTS (
    SELECT 1
    FROM import_batch_errors ibe
    WHERE ibe.import_batch_id = bm.id
      AND ibe.row_number = e.row_number
      AND ibe.field_name = e.field_name
);

COMMIT;

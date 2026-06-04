\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    status_constraint TEXT;
    employee_id BIGINT;
BEGIN
    IF to_regclass('public.import_column_mappings') IS NULL THEN
        RAISE EXCEPTION 'Missing table import_column_mappings';
    END IF;

    IF to_regclass('public.import_batch_rows') IS NULL THEN
        RAISE EXCEPTION 'Missing table import_batch_rows';
    END IF;

    SELECT pg_get_constraintdef(oid)
    INTO status_constraint
    FROM pg_constraint
    WHERE conrelid = 'import_batches'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%status%'
    LIMIT 1;

    IF status_constraint IS NULL
       OR status_constraint NOT LIKE '%CANCELADA%'
       OR status_constraint NOT LIKE '%CON_ERRORES%'
       OR status_constraint NOT LIKE '%IMPORTADA%'
       OR status_constraint NOT LIKE '%PREVALIDADA%'
       OR status_constraint NOT LIKE '%PREVALIDANDO%'
       OR status_constraint NOT LIKE '%RECHAZADA%' THEN
        RAISE EXCEPTION 'Import batch statuses incomplete: %', status_constraint;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'employees'
          AND indexdef LIKE '%identification_type, identification_number%'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'Missing unique employee functional key (identification_type, identification_number)';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'employee_salary_history'
          AND indexdef LIKE '%employee_id%'
          AND indexdef LIKE '%WHERE (effective_to IS NULL)%'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'Missing unique open salary constraint';
    END IF;

    INSERT INTO employees (
        identification_type,
        identification_number,
        full_name,
        employment_status,
        job_title,
        hire_date
    )
    VALUES
        ('CC', 'I2-PERSISTENCE-TEST', 'Contrato Persistencia CC', 'ACTIVO', 'Prueba', CURRENT_DATE),
        ('CE', 'I2-PERSISTENCE-TEST', 'Contrato Persistencia CE', 'ACTIVO', 'Prueba', CURRENT_DATE);

    BEGIN
        INSERT INTO employees (
            identification_type,
            identification_number,
            full_name,
            employment_status,
            job_title,
            hire_date
        )
        VALUES ('CC', 'I2-PERSISTENCE-TEST', 'Duplicado', 'ACTIVO', 'Prueba', CURRENT_DATE);

        RAISE EXCEPTION 'Employee functional key accepted an exact duplicate';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    SELECT id
    INTO employee_id
    FROM employees
    WHERE identification_type = 'CC'
      AND identification_number = 'I2-PERSISTENCE-TEST';

    INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from)
    VALUES (employee_id, 1000000, CURRENT_DATE);

    BEGIN
        INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from)
        VALUES (employee_id, 1100000, CURRENT_DATE + 1);

        RAISE EXCEPTION 'Salary history accepted two open periods';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    INSERT INTO import_batches (load_type, file_name, uploaded_by, status)
    VALUES
        ('EMPLEADOS', 'test-prevalidando.csv', 'test', 'PREVALIDANDO'),
        ('EMPLEADOS', 'test-prevalidada.csv', 'test', 'PREVALIDADA'),
        ('EMPLEADOS', 'test-con-errores.csv', 'test', 'CON_ERRORES'),
        ('EMPLEADOS', 'test-rechazada.csv', 'test', 'RECHAZADA'),
        ('EMPLEADOS', 'test-importada.csv', 'test', 'IMPORTADA'),
        ('EMPLEADOS', 'test-cancelada.csv', 'test', 'CANCELADA');
END
$$;

ROLLBACK;

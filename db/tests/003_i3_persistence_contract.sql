\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    employee_id BIGINT;
    active_position_id BIGINT;
    inactive_position_id BIGINT;
    assignment_id BIGINT;
BEGIN
    IF to_regclass('public.service_positions') IS NULL THEN
        RAISE EXCEPTION 'Missing table service_positions';
    END IF;

    IF to_regclass('public.employee_position_assignments') IS NULL THEN
        RAISE EXCEPTION 'Missing table employee_position_assignments';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'service_positions'
          AND indexdef LIKE '%code%'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'Missing unique service position code index';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'employee_position_assignments'
          AND indexdef LIKE '%employee_id%'
          AND indexdef LIKE '%WHERE ((status)::text = ''VIGENTE''::text)%'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'Missing unique active assignment constraint';
    END IF;

    BEGIN
        INSERT INTO service_positions (name, status)
        VALUES ('', 'ACTIVO');

        RAISE EXCEPTION 'Service position accepted blank name';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO service_positions (code, name, client_text, location_text, status)
    VALUES
        ('I3-ACTIVE', 'Puesto I3 Activo', 'Cliente texto', 'Bogota', 'ACTIVO'),
        ('I3-INACTIVE', 'Puesto I3 Inactivo', 'Cliente texto', 'Medellin', 'INACTIVO');

    SELECT id
    INTO active_position_id
    FROM service_positions
    WHERE code = 'I3-ACTIVE';

    SELECT id
    INTO inactive_position_id
    FROM service_positions
    WHERE code = 'I3-INACTIVE';

    BEGIN
        INSERT INTO service_positions (code, name, status)
        VALUES ('I3-ACTIVE', 'Duplicado codigo', 'ACTIVO');

        RAISE EXCEPTION 'Service position accepted duplicate code';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    INSERT INTO employees (
        identification_type,
        identification_number,
        full_name,
        employment_status,
        job_title,
        hire_date
    )
    VALUES ('CC', 'I3-PERSISTENCE-EMPLOYEE', 'Empleado I3 Persistencia', 'ACTIVO', 'Guarda', CURRENT_DATE)
    RETURNING id INTO employee_id;

    BEGIN
        INSERT INTO employee_position_assignments (
            employee_id,
            position_id,
            start_date,
            status
        )
        VALUES (employee_id, inactive_position_id, CURRENT_DATE, 'VIGENTE');

        RAISE EXCEPTION 'Assignment accepted inactive position';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO employee_position_assignments (
        employee_id,
        position_id,
        start_date,
        status
    )
    VALUES (employee_id, active_position_id, CURRENT_DATE, 'VIGENTE')
    RETURNING id INTO assignment_id;

    BEGIN
        INSERT INTO employee_position_assignments (
            employee_id,
            position_id,
            start_date,
            status
        )
        VALUES (employee_id, active_position_id, CURRENT_DATE + 1, 'VIGENTE');

        RAISE EXCEPTION 'Assignment accepted two active assignments for same employee';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    BEGIN
        UPDATE employee_position_assignments
        SET end_date = start_date - 1,
            status = 'FINALIZADA'
        WHERE id = assignment_id;

        RAISE EXCEPTION 'Assignment accepted end_date before start_date';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END
$$;

ROLLBACK;

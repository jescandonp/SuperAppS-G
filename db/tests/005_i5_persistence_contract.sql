\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    employee_id BIGINT;
    type_id BIGINT;
    inactive_type_id BIGINT;
    admin_role_id BIGINT;
    th_role_id BIGINT;
    gerencia_role_id BIGINT;
    operaciones_role_id BIGINT;
BEGIN
    IF to_regclass('training_requirement_types') IS NULL THEN
        RAISE EXCEPTION 'Missing table training_requirement_types';
    END IF;

    IF to_regclass('employee_training_records') IS NULL THEN
        RAISE EXCEPTION 'Missing table employee_training_records';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE tablename = 'training_requirement_types'
          AND indexdef LIKE '%code%'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'Missing unique training type code constraint';
    END IF;

    BEGIN
        INSERT INTO training_requirement_types (code, name, category)
        VALUES ('I5-BAD-CATEGORY', 'Categoria invalida', 'LICENCIA');

        RAISE EXCEPTION 'Training type accepted invalid category';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO training_requirement_types (code, name, category, status)
        VALUES ('I5-BAD-STATUS', 'Estado invalido', 'CURSO', 'BORRADOR');

        RAISE EXCEPTION 'Training type accepted invalid status';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO training_requirement_types (code, name, category, validity_days)
        VALUES ('I5-BAD-VALIDITY', 'Vigencia invalida', 'CURSO', 0);

        RAISE EXCEPTION 'Training type accepted non-positive validity_days';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO training_requirement_types (
        code,
        name,
        category,
        validity_days,
        is_service_required,
        status,
        notes
    )
    VALUES (
        'I5-CURSO-SEGURIDAD',
        'Curso seguridad privada I5',
        'CURSO',
        365,
        TRUE,
        'ACTIVO',
        'Contrato de persistencia I5'
    )
    RETURNING id INTO type_id;

    BEGIN
        INSERT INTO training_requirement_types (code, name, category)
        VALUES ('I5-CURSO-SEGURIDAD', 'Duplicado', 'CURSO');

        RAISE EXCEPTION 'Training type accepted duplicate code';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    INSERT INTO training_requirement_types (code, name, category, status)
    VALUES ('I5-INACTIVO', 'Tipo inactivo I5', 'ACREDITACION', 'INACTIVO')
    RETURNING id INTO inactive_type_id;

    INSERT INTO employees (
        identification_type,
        identification_number,
        full_name,
        employment_status,
        job_title,
        hire_date
    )
    VALUES ('CC', 'I5-PERSISTENCE-EMPLOYEE', 'Empleado I5 Persistencia', 'ACTIVO', 'Guarda', CURRENT_DATE - 90)
    RETURNING id INTO employee_id;

    INSERT INTO employee_training_records (
        employee_id,
        requirement_type_id,
        completed_at,
        expires_at,
        support_path,
        notes,
        created_by
    )
    VALUES (
        employee_id,
        type_id,
        CURRENT_DATE - 30,
        CURRENT_DATE + 335,
        'soportes/i5/curso-seguridad.pdf',
        'Renovacion vigente I5',
        'th.sg'
    );

    INSERT INTO employee_training_records (
        employee_id,
        requirement_type_id,
        completed_at,
        expires_at,
        created_by
    )
    VALUES (
        employee_id,
        type_id,
        CURRENT_DATE - 400,
        CURRENT_DATE - 35,
        'th.sg'
    );

    BEGIN
        INSERT INTO employee_training_records (
            employee_id,
            requirement_type_id,
            completed_at,
            expires_at,
            created_by
        )
        VALUES (
            employee_id,
            type_id,
            CURRENT_DATE,
            CURRENT_DATE - 1,
            'th.sg'
        );

        RAISE EXCEPTION 'Training record accepted expiry before completion';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO employee_training_records (
            employee_id,
            requirement_type_id,
            completed_at,
            expires_at,
            status,
            created_by
        )
        VALUES (
            employee_id,
            type_id,
            CURRENT_DATE,
            CURRENT_DATE + 10,
            'BORRADOR',
            'th.sg'
        );

        RAISE EXCEPTION 'Training record accepted invalid status';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO employee_training_records (
            employee_id,
            requirement_type_id,
            completed_at,
            expires_at,
            created_by
        )
        VALUES (
            999999999,
            type_id,
            CURRENT_DATE,
            CURRENT_DATE + 10,
            'th.sg'
        );

        RAISE EXCEPTION 'Training record accepted missing employee';
    EXCEPTION
        WHEN foreign_key_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO employee_training_records (
            employee_id,
            requirement_type_id,
            completed_at,
            expires_at,
            created_by
        )
        VALUES (
            employee_id,
            999999999,
            CURRENT_DATE,
            CURRENT_DATE + 10,
            'th.sg'
        );

        RAISE EXCEPTION 'Training record accepted missing type';
    EXCEPTION
        WHEN foreign_key_violation THEN
            NULL;
    END;

    SELECT id INTO admin_role_id FROM roles WHERE code = 'ADMIN';
    SELECT id INTO th_role_id FROM roles WHERE code = 'TH';
    SELECT id INTO gerencia_role_id FROM roles WHERE code = 'GERENCIA';
    SELECT id INTO operaciones_role_id FROM roles WHERE code = 'OPERACIONES';

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = admin_role_id AND module_code = 'TRAINING_TYPES' AND action_code = 'MANAGE' AND allowed) THEN
        RAISE EXCEPTION 'ADMIN must manage training types';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = th_role_id AND module_code = 'TRAINING_RECORDS' AND action_code = 'MANAGE' AND allowed) THEN
        RAISE EXCEPTION 'TH must manage training records';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = gerencia_role_id AND module_code = 'TRAINING_SERVICE_ENABLEMENT' AND action_code = 'VIEW' AND allowed) THEN
        RAISE EXCEPTION 'GERENCIA must view training service enablement';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = operaciones_role_id AND module_code = 'TRAINING_SERVICE_ENABLEMENT' AND action_code = 'VIEW' AND allowed) THEN
        RAISE EXCEPTION 'OPERACIONES must view training service enablement';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM role_permissions
        WHERE role_id IN (gerencia_role_id, operaciones_role_id)
          AND module_code IN ('TRAINING_TYPES', 'TRAINING_RECORDS')
          AND action_code = 'MANAGE'
          AND allowed
    ) THEN
        RAISE EXCEPTION 'GERENCIA and OPERACIONES must not manage I5 training data';
    END IF;
END
$$;

ROLLBACK;

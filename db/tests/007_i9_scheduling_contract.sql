\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    required_table TEXT;
    client_id BIGINT;
    project_id BIGINT;
    template_id BIGINT;
    position_id BIGINT;
    employee_id BIGINT;
BEGIN
    FOREACH required_table IN ARRAY ARRAY[
        'clients',
        'service_projects',
        'shift_templates',
        'shift_template_steps',
        'position_coverage_rules',
        'scheduling_rules',
        'employee_availability_exceptions'
    ]
    LOOP
        IF to_regclass('public.' || required_table) IS NULL THEN
            RAISE EXCEPTION 'Missing table %', required_table;
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'service_positions'
          AND column_name = 'project_id'
    ) THEN
        RAISE EXCEPTION 'Missing service_positions.project_id';
    END IF;

    IF EXISTS (SELECT 1 FROM scheduling_rules) THEN
        RAISE EXCEPTION 'I9 seeds must not create executable scheduling rules';
    END IF;

    INSERT INTO clients (code, name)
    VALUES ('I9-CLIENT', 'Cliente contrato I9')
    RETURNING id INTO client_id;

    INSERT INTO service_projects (client_id, code, name, effective_from)
    VALUES (client_id, 'I9-PROJECT', 'Proyecto contrato I9', CURRENT_DATE)
    RETURNING id INTO project_id;

    INSERT INTO service_positions (code, name, project_id)
    VALUES ('I9-POSITION', 'Puesto contrato I9', project_id)
    RETURNING id INTO position_id;

    BEGIN
        INSERT INTO service_projects (client_id, code, name, effective_from)
        VALUES (999999999, 'I9-BAD-FK', 'Proyecto sin cliente', CURRENT_DATE);
        RAISE EXCEPTION 'service_projects accepted missing client';
    EXCEPTION
        WHEN foreign_key_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO service_positions (code, name, project_id)
        VALUES ('I9-BAD-PROJECT', 'Puesto sin proyecto', 999999999);
        RAISE EXCEPTION 'service_positions accepted missing project';
    EXCEPTION
        WHEN foreign_key_violation THEN NULL;
    END;

    INSERT INTO shift_templates (
        code, name, version, effective_from, mandatory_by_default
    )
    VALUES ('I9-TEMPLATE', 'Plantilla contrato I9', 1, CURRENT_DATE, FALSE)
    RETURNING id INTO template_id;

    BEGIN
        INSERT INTO shift_templates (code, name, version, effective_from)
        VALUES ('I9-TEMPLATE', 'Plantilla duplicada', 1, CURRENT_DATE);
        RAISE EXCEPTION 'shift_templates accepted duplicate code and version';
    EXCEPTION
        WHEN unique_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO shift_templates (code, name, version, effective_from, status)
        VALUES ('I9-BAD-STATUS', 'Estado invalido', 1, CURRENT_DATE, 'BORRADOR');
        RAISE EXCEPTION 'shift_templates accepted invalid status';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    INSERT INTO shift_template_steps (template_id, step_order, shift_code)
    VALUES (template_id, 1, 'D');

    BEGIN
        INSERT INTO shift_template_steps (template_id, step_order, shift_code)
        VALUES (template_id, 1, 'N');
        RAISE EXCEPTION 'shift_template_steps accepted duplicate order';
    EXCEPTION
        WHEN unique_violation THEN NULL;
    END;

    BEGIN
        INSERT INTO shift_template_steps (template_id, step_order, shift_code)
        VALUES (template_id, 2, 'M');
        RAISE EXCEPTION 'shift_template_steps accepted invalid shift code';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    INSERT INTO position_coverage_rules (
        position_id, template_id, required_quantity, effective_from
    )
    VALUES (position_id, template_id, 1, CURRENT_DATE);

    BEGIN
        INSERT INTO position_coverage_rules (
            position_id, template_id, required_quantity, effective_from
        )
        VALUES (position_id, template_id, 0, CURRENT_DATE);
        RAISE EXCEPTION 'position_coverage_rules accepted non-positive quantity';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    INSERT INTO scheduling_rules (
        source_level, scope_type, scope_id, severity, effective_from, parameters
    )
    VALUES ('POLITICA_INTERNA', 'PROYECTO', project_id, 'BLOQUEANTE', CURRENT_DATE, '{"maximo": 1}'::jsonb);

    BEGIN
        INSERT INTO scheduling_rules (
            source_level, scope_type, severity, effective_from, parameters
        )
        VALUES ('POLITICA_INTERNA', 'GLOBAL', 'BLOQUEANTE', CURRENT_DATE, '[]'::jsonb);
        RAISE EXCEPTION 'scheduling_rules accepted non-object parameters';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    INSERT INTO employees (
        identification_type, identification_number, full_name,
        employment_status, job_title, hire_date
    )
    VALUES ('CC', 'I9-PERSISTENCE-EMPLOYEE', 'Empleado I9 Persistencia',
            'ACTIVO', 'Guarda', CURRENT_DATE)
    RETURNING id INTO employee_id;

    INSERT INTO employee_availability_exceptions (
        employee_id, starts_at, ends_at, reason, created_by
    )
    VALUES (employee_id, NOW(), NOW() + INTERVAL '1 day', 'Contrato I9', 'test.i9');

    BEGIN
        INSERT INTO employee_availability_exceptions (
            employee_id, starts_at, ends_at, reason, created_by
        )
        VALUES (employee_id, NOW(), NOW() - INTERVAL '1 minute', 'Rango invalido', 'test.i9');
        RAISE EXCEPTION 'employee_availability_exceptions accepted invalid range';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    IF (SELECT count(*) FROM shift_templates WHERE code IN ('2X2', '4X2', '6X1') AND status = 'ACTIVO') <> 3 THEN
        RAISE EXCEPTION 'Missing active I9 shift template seeds';
    END IF;

    IF (SELECT string_agg(sts.shift_code, ',' ORDER BY sts.step_order)
        FROM shift_template_steps sts
        JOIN shift_templates st ON st.id = sts.template_id
        WHERE st.code = '2X2' AND st.version = 1) <> 'D,D,N,N,X,X' THEN
        RAISE EXCEPTION 'Invalid 2X2 template sequence';
    END IF;

    IF (SELECT string_agg(sts.shift_code, ',' ORDER BY sts.step_order)
        FROM shift_template_steps sts
        JOIN shift_templates st ON st.id = sts.template_id
        WHERE st.code = '4X2' AND st.version = 1) <> 'D,D,D,D,N,N,X,X' THEN
        RAISE EXCEPTION 'Invalid 4X2 template sequence';
    END IF;

    IF (SELECT string_agg(sts.shift_code, ',' ORDER BY sts.step_order)
        FROM shift_template_steps sts
        JOIN shift_templates st ON st.id = sts.template_id
        WHERE st.code = '6X1' AND st.version = 1) <> 'D,D,D,D,D,D,X' THEN
        RAISE EXCEPTION 'Invalid 6X1 template sequence';
    END IF;

    IF (SELECT count(*)
        FROM role_permissions rp
        JOIN roles r ON r.id = rp.role_id
        WHERE r.code = 'ADMIN' AND rp.module_code = 'SCHEDULING'
          AND rp.action_code IN ('VIEW', 'CONFIGURE', 'GENERATE', 'APPROVE_EXCEPTION', 'APPROVE', 'PUBLISH', 'EXPORT', 'AUDIT')
          AND rp.allowed) <> 8 THEN
        RAISE EXCEPTION 'ADMIN scheduling permission matrix is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1 FROM role_permissions rp JOIN roles r ON r.id = rp.role_id
        WHERE r.code = 'OPERACIONES' AND rp.module_code = 'SCHEDULING'
          AND rp.action_code = 'CONFIGURE' AND rp.allowed
    ) THEN
        RAISE EXCEPTION 'OPERACIONES must not configure global scheduling rules';
    END IF;

    IF (SELECT count(*)
        FROM role_permissions rp JOIN roles r ON r.id = rp.role_id
        WHERE r.code = 'OPERACIONES' AND rp.module_code = 'SCHEDULING'
          AND rp.action_code IN ('VIEW', 'GENERATE', 'APPROVE_EXCEPTION', 'APPROVE', 'PUBLISH', 'EXPORT', 'AUDIT')
          AND rp.allowed) <> 7 THEN
        RAISE EXCEPTION 'OPERACIONES scheduling permission matrix is incomplete';
    END IF;

    IF (SELECT count(*)
        FROM role_permissions rp JOIN roles r ON r.id = rp.role_id
        WHERE r.code = 'TH' AND rp.module_code = 'SCHEDULING'
          AND rp.action_code IN ('VIEW', 'APPROVE_EXCEPTION') AND rp.allowed) <> 2 THEN
        RAISE EXCEPTION 'TH scheduling permissions must cover view and availability exceptions';
    END IF;

    IF (SELECT count(*)
        FROM role_permissions rp JOIN roles r ON r.id = rp.role_id
        WHERE r.code = 'GERENCIA' AND rp.module_code = 'SCHEDULING'
          AND rp.action_code IN ('VIEW', 'EXPORT') AND rp.allowed) <> 2 THEN
        RAISE EXCEPTION 'GERENCIA scheduling permissions must cover view and export';
    END IF;
END
$$;

ROLLBACK;

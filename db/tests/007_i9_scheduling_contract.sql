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
    requirement_type_id BIGINT;
BEGIN
    FOREACH required_table IN ARRAY ARRAY[
        'clients',
        'service_projects',
        'shift_templates',
        'shift_template_steps',
        'position_coverage_rules',
        'scheduling_rules',
        'employee_availability_exceptions',
        'position_requirements'
    ]
    LOOP
        IF to_regclass(required_table) IS NULL THEN
            RAISE EXCEPTION 'Missing table %', required_table;
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'service_positions'
          AND column_name = 'project_id'
    ) THEN
        RAISE EXCEPTION 'Missing service_positions.project_id';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'shift_templates'
          AND column_name = 'mandatory_by_default'
          AND column_default = 'true'
    ) THEN
        RAISE EXCEPTION 'shift_templates.mandatory_by_default must default to TRUE';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (VALUES
            ('clients','code'),('clients','name'),('clients','status'),('clients','created_at'),('clients','updated_at'),
            ('service_projects','client_id'),('service_projects','code'),('service_projects','name'),('service_projects','effective_from'),('service_projects','status'),('service_projects','created_at'),('service_projects','updated_at'),
            ('shift_templates','code'),('shift_templates','name'),('shift_templates','version'),('shift_templates','effective_from'),('shift_templates','mandatory_by_default'),('shift_templates','status'),('shift_templates','created_at'),('shift_templates','updated_at'),
            ('shift_template_steps','template_id'),('shift_template_steps','step_order'),('shift_template_steps','shift_code'),
            ('position_coverage_rules','position_id'),('position_coverage_rules','template_id'),('position_coverage_rules','weekday_scope'),('position_coverage_rules','starts_at'),('position_coverage_rules','ends_at'),('position_coverage_rules','required_quantity'),('position_coverage_rules','effective_from'),('position_coverage_rules','status'),('position_coverage_rules','created_at'),('position_coverage_rules','updated_at'),
            ('scheduling_rules','source_level'),('scheduling_rules','scope_type'),('scheduling_rules','severity'),('scheduling_rules','effective_from'),('scheduling_rules','parameters'),('scheduling_rules','status'),('scheduling_rules','created_at'),('scheduling_rules','updated_at'),
            ('employee_availability_exceptions','employee_id'),('employee_availability_exceptions','starts_at'),('employee_availability_exceptions','ends_at'),('employee_availability_exceptions','kind'),('employee_availability_exceptions','blocking'),('employee_availability_exceptions','reason'),('employee_availability_exceptions','created_by'),('employee_availability_exceptions','status'),('employee_availability_exceptions','created_at'),('employee_availability_exceptions','updated_at'),
            ('position_requirements','position_id'),('position_requirements','requirement_type_id'),('position_requirements','severity'),('position_requirements','status'),('position_requirements','created_at'),('position_requirements','updated_at')
        ) expected(table_name,column_name)
        LEFT JOIN information_schema.columns c
          ON c.table_schema=current_schema() AND c.table_name=expected.table_name AND c.column_name=expected.column_name
        WHERE c.column_name IS NULL OR c.is_nullable <> 'NO'
    ) THEN
        RAISE EXCEPTION 'I9 critical columns are missing or nullable';
    END IF;

    IF EXISTS (
        SELECT 1 FROM (VALUES
            ('clients','id','bigint'),('clients','code','character varying(50)'),('clients','name','character varying(180)'),('clients','status','character varying(20)'),('clients','created_at','timestamp with time zone'),('clients','updated_at','timestamp with time zone'),
            ('service_projects','id','bigint'),('service_projects','client_id','bigint'),('service_projects','code','character varying(50)'),('service_projects','name','character varying(180)'),('service_projects','effective_from','date'),('service_projects','effective_to','date'),('service_projects','status','character varying(20)'),('service_projects','created_at','timestamp with time zone'),('service_projects','updated_at','timestamp with time zone'),
            ('service_positions','project_id','bigint'),
            ('shift_templates','id','bigint'),('shift_templates','code','character varying(30)'),('shift_templates','name','character varying(180)'),('shift_templates','version','integer'),('shift_templates','effective_from','date'),('shift_templates','effective_to','date'),('shift_templates','mandatory_by_default','boolean'),('shift_templates','status','character varying(20)'),('shift_templates','created_at','timestamp with time zone'),('shift_templates','updated_at','timestamp with time zone'),
            ('shift_template_steps','id','bigint'),('shift_template_steps','template_id','bigint'),('shift_template_steps','step_order','integer'),('shift_template_steps','shift_code','character(1)'),
            ('position_coverage_rules','id','bigint'),('position_coverage_rules','position_id','bigint'),('position_coverage_rules','template_id','bigint'),('position_coverage_rules','weekday_scope','character varying(80)'),('position_coverage_rules','starts_at','time without time zone'),('position_coverage_rules','ends_at','time without time zone'),('position_coverage_rules','required_quantity','integer'),('position_coverage_rules','effective_from','date'),('position_coverage_rules','effective_to','date'),('position_coverage_rules','status','character varying(20)'),('position_coverage_rules','created_at','timestamp with time zone'),('position_coverage_rules','updated_at','timestamp with time zone'),
            ('scheduling_rules','id','bigint'),('scheduling_rules','source_level','character varying(50)'),('scheduling_rules','scope_type','character varying(50)'),('scheduling_rules','scope_id','bigint'),('scheduling_rules','severity','character varying(30)'),('scheduling_rules','effective_from','date'),('scheduling_rules','effective_to','date'),('scheduling_rules','parameters','jsonb'),('scheduling_rules','status','character varying(20)'),('scheduling_rules','created_at','timestamp with time zone'),('scheduling_rules','updated_at','timestamp with time zone'),
            ('employee_availability_exceptions','id','bigint'),('employee_availability_exceptions','employee_id','bigint'),('employee_availability_exceptions','starts_at','timestamp with time zone'),('employee_availability_exceptions','ends_at','timestamp with time zone'),('employee_availability_exceptions','kind','character varying(50)'),('employee_availability_exceptions','blocking','boolean'),('employee_availability_exceptions','reason','character varying(500)'),('employee_availability_exceptions','created_by','character varying(80)'),('employee_availability_exceptions','status','character varying(20)'),('employee_availability_exceptions','created_at','timestamp with time zone'),('employee_availability_exceptions','updated_at','timestamp with time zone'),
            ('position_requirements','id','bigint'),('position_requirements','position_id','bigint'),('position_requirements','requirement_type_id','bigint'),('position_requirements','severity','character varying(20)'),('position_requirements','resolution_due_date','date'),('position_requirements','status','character varying(20)'),('position_requirements','created_at','timestamp with time zone'),('position_requirements','updated_at','timestamp with time zone')
        ) expected(table_name,column_name,expected_type)
        JOIN pg_attribute a ON a.attrelid=expected.table_name::regclass AND a.attname=expected.column_name AND NOT a.attisdropped
        WHERE format_type(a.atttypid,a.atttypmod) <> expected.expected_type
    ) THEN
        RAISE EXCEPTION 'I9 critical column type or length mismatch';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM unnest(ARRAY[
            'clients','service_projects','shift_templates','shift_template_steps',
            'position_coverage_rules','scheduling_rules','employee_availability_exceptions','position_requirements'
        ]) AS expected(table_name)
        WHERE pg_get_serial_sequence(format('%I.%I', current_schema(), expected.table_name), 'id') IS NULL
    ) THEN
        RAISE EXCEPTION 'I9 id columns must have owned sequence defaults';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'shift_template_steps'::regclass
          AND conname = 'shift_template_steps_template_id_fkey'
          AND confdeltype = 'r'
    ) THEN
        RAISE EXCEPTION 'shift_template_steps.template_id must use ON DELETE RESTRICT';
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
        VALUES (' ', 'Texto valido', 1, CURRENT_DATE);
        RAISE EXCEPTION 'shift_templates accepted blank code';
    EXCEPTION WHEN check_violation THEN NULL; END;

    BEGIN
        INSERT INTO shift_templates (code, name, version, effective_from)
        VALUES ('I9-BAD-VERSION', 'Version invalida', 0, CURRENT_DATE);
        RAISE EXCEPTION 'shift_templates accepted non-positive version';
    EXCEPTION WHEN check_violation THEN NULL; END;

    BEGIN
        INSERT INTO shift_templates (code, name, version, effective_from, effective_to)
        VALUES ('I9-BAD-DATES', 'Vigencia invalida', 1, CURRENT_DATE, CURRENT_DATE - 1);
        RAISE EXCEPTION 'shift_templates accepted invalid effective dates';
    EXCEPTION WHEN check_violation THEN NULL; END;

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
        VALUES (template_id, 0, 'D');
        RAISE EXCEPTION 'shift_template_steps accepted non-positive order';
    EXCEPTION WHEN check_violation THEN NULL; END;

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
        position_id, template_id, weekday_scope, starts_at, ends_at,
        required_quantity, effective_from
    )
    VALUES (position_id, template_id, 'TODOS', '06:00', '18:00', 1, CURRENT_DATE);

    BEGIN
        INSERT INTO position_coverage_rules (
            position_id, template_id, weekday_scope, starts_at, ends_at,
            required_quantity, effective_from
        )
        VALUES (position_id, template_id, 'TODOS', '06:00', '18:00', 0, CURRENT_DATE);
        RAISE EXCEPTION 'position_coverage_rules accepted non-positive quantity';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    INSERT INTO scheduling_rules (
        source_level, scope_type, scope_id, severity, effective_from, parameters
    )
    VALUES ('POLITICA_INTERNA', 'PROYECTO', project_id, 'BLOQUEANTE', CURRENT_DATE, '{"maximo": 1}'::jsonb);

    BEGIN
        INSERT INTO scheduling_rules (source_level, scope_type, severity, effective_from)
        VALUES ('POLITICA_INTERNA', 'GLOBAL', ' ', CURRENT_DATE);
        RAISE EXCEPTION 'scheduling_rules accepted blank severity';
    EXCEPTION WHEN check_violation THEN NULL; END;

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
        employee_id, starts_at, ends_at, kind, blocking, reason, created_by
    )
    VALUES (employee_id, NOW(), NOW() + INTERVAL '1 day', 'NOVEDAD', TRUE, 'Contrato I9', 'test.i9');

    BEGIN
        INSERT INTO employee_availability_exceptions (
            employee_id, starts_at, ends_at, kind, blocking, reason, created_by
        )
        VALUES (employee_id, NOW(), NOW() - INTERVAL '1 minute', 'NOVEDAD', TRUE, 'Rango invalido', 'test.i9');
        RAISE EXCEPTION 'employee_availability_exceptions accepted invalid range';
    EXCEPTION
        WHEN check_violation THEN NULL;
    END;

    INSERT INTO training_requirement_types (code, name, category)
    VALUES ('I9-REQ', 'Requisito contrato I9', 'CURSO')
    RETURNING id INTO requirement_type_id;

    INSERT INTO position_requirements (
        position_id, requirement_type_id, severity, resolution_due_date
    ) VALUES (position_id, requirement_type_id, 'SUBSANABLE', CURRENT_DATE + 30);

    BEGIN
        INSERT INTO position_requirements (position_id, requirement_type_id, severity)
        VALUES (position_id, requirement_type_id + 999999999, 'BLOQUEANTE');
        RAISE EXCEPTION 'position_requirements accepted missing requirement type';
    EXCEPTION WHEN foreign_key_violation THEN NULL; END;

    BEGIN
        UPDATE position_requirements SET severity = 'OPCIONAL'
        WHERE id = (SELECT min(id) FROM position_requirements);
        RAISE EXCEPTION 'position_requirements accepted invalid severity';
    EXCEPTION WHEN check_violation THEN NULL; END;

    IF (SELECT count(*) FROM shift_templates WHERE code IN ('2X2', '4X2', '6X1') AND status = 'ACTIVO' AND mandatory_by_default) <> 3 THEN
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

    IF EXISTS (
        SELECT 1
        FROM role_permissions rp
        JOIN roles r ON r.id = rp.role_id
        WHERE r.code IN ('ADMIN', 'OPERACIONES', 'TH', 'GERENCIA')
          AND rp.module_code = 'SCHEDULING'
          AND (
              NOT rp.allowed
              OR (r.code = 'ADMIN' AND rp.action_code NOT IN ('VIEW', 'CONFIGURE', 'GENERATE', 'APPROVE_EXCEPTION', 'APPROVE', 'PUBLISH', 'EXPORT', 'AUDIT'))
              OR (r.code = 'OPERACIONES' AND rp.action_code NOT IN ('VIEW', 'GENERATE', 'APPROVE_EXCEPTION', 'APPROVE', 'PUBLISH', 'EXPORT', 'AUDIT'))
              OR (r.code = 'TH' AND rp.action_code NOT IN ('VIEW', 'APPROVE_EXCEPTION'))
              OR (r.code = 'GERENCIA' AND rp.action_code NOT IN ('VIEW', 'EXPORT'))
          )
    ) THEN
        RAISE EXCEPTION 'Managed roles must have the exact I9 scheduling permission matrix';
    END IF;
END
$$;

DO $$
DECLARE
    missing_tables TEXT;
    client_id BIGINT;
    project_id BIGINT;
    position_id BIGINT;
    employee_id BIGINT;
    schedule_id BIGINT;
    version_id BIGINT;
    required_shift_id BIGINT;
    assignment_id BIGINT;
BEGIN
    SELECT string_agg(expected_table, ', ' ORDER BY expected_table)
    INTO missing_tables
    FROM unnest(ARRAY[
        'schedules', 'schedule_versions', 'required_shifts',
        'schedule_assignments', 'schedule_exceptions', 'schedule_generation_runs'
    ]) AS expected(expected_table)
    WHERE to_regclass(expected_table) IS NULL;

    IF missing_tables IS NOT NULL THEN
        RAISE EXCEPTION 'I9 schedule version tables missing: %', missing_tables;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = current_schema()
          AND tablename = 'schedule_versions'
          AND indexname = 'schedule_versions_one_published_per_schedule'
          AND indexdef LIKE '%UNIQUE%WHERE%status%PUBLICADA%'
    ) THEN
        RAISE EXCEPTION 'Missing unique published schedule version index';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'schedule_versions'::regclass
          AND tgname = 'schedule_versions_immutable_when_published'
          AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'schedule_assignments'::regclass
          AND tgname = 'schedule_assignments_immutable_when_published'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Missing published schedule immutability triggers';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'schedule_versions'::regclass
          AND conname = 'schedule_versions_status_check'
          AND pg_get_constraintdef(oid) LIKE '%BORRADOR%PROPUESTA%APROBADA%PUBLICADA%REEMPLAZADA%CANCELADA%'
    ) THEN
        RAISE EXCEPTION 'Invalid schedule version status contract';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'schedule_assignments'::regclass
          AND conname = 'schedule_assignments_employee_status_check'
    ) THEN
        RAISE EXCEPTION 'Invalid vacant assignment contract';
    END IF;

    INSERT INTO clients (code, name, status)
    VALUES ('I9-VERSION-CLIENT', 'Cliente versiones I9', 'ACTIVO')
    RETURNING id INTO client_id;

    INSERT INTO service_projects (client_id, code, name, effective_from, status)
    VALUES (client_id, 'I9-VERSION-PROJECT', 'Proyecto versiones I9', CURRENT_DATE, 'ACTIVO')
    RETURNING id INTO project_id;

    INSERT INTO service_positions (project_id, code, name)
    VALUES (project_id, 'I9-VERSION-POSITION', 'Puesto versiones I9')
    RETURNING id INTO position_id;

    INSERT INTO employees (
        identification_type, identification_number, full_name,
        employment_status, job_title, hire_date
    ) VALUES (
        'CC', 'I9-VERSION-EMPLOYEE', 'Empleado versiones I9',
        'ACTIVO', 'Guarda', CURRENT_DATE
    ) RETURNING id INTO employee_id;

    INSERT INTO schedules (project_id, period_start, period_end, created_by)
    VALUES (project_id, CURRENT_DATE, CURRENT_DATE + 30, 'test.i9')
    RETURNING id INTO schedule_id;

    INSERT INTO schedule_versions (
        schedule_id, version_number, status, source_snapshot,
        rules_snapshot, parameters_snapshot, created_by
    ) VALUES (
        schedule_id, 1, 'PROPUESTA', '{"source":"test"}',
        '{"rules":[]}', '{"parameters":{}}', 'test.i9'
    ) RETURNING id INTO version_id;

    INSERT INTO required_shifts (
        schedule_version_id, position_id, shift_date, starts_at, ends_at
    ) VALUES (version_id, position_id, CURRENT_DATE, '06:00', '18:00')
    RETURNING id INTO required_shift_id;

    BEGIN
        INSERT INTO schedule_assignments (
            schedule_version_id, required_shift_id, status
        ) VALUES (version_id, required_shift_id, 'ASIGNADA');
        RAISE EXCEPTION 'schedule_assignments accepted ASIGNADA without employee';
    EXCEPTION WHEN check_violation THEN NULL; END;

    INSERT INTO schedule_assignments (
        schedule_version_id, required_shift_id, employee_id, status, reasons
    ) VALUES (version_id, required_shift_id, employee_id, 'ASIGNADA', '["eligible"]')
    RETURNING id INTO assignment_id;

    INSERT INTO schedule_exceptions (
        schedule_version_id, assignment_id, exception_type, reason, responsible
    ) VALUES (version_id, assignment_id, 'DESVIACION_PLANTILLA', 'Excepcion contractual', 'test.i9');

    INSERT INTO schedule_generation_runs (schedule_version_id, idempotency_key)
    VALUES (version_id, 'i9-contract-run');

    UPDATE schedule_versions
    SET status = 'PUBLICADA', published_by = 'test.i9', published_at = NOW()
    WHERE id = version_id;

    BEGIN
        UPDATE schedule_assignments SET score = 99 WHERE id = assignment_id;
        RAISE EXCEPTION 'published schedule assignment remained mutable';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        UPDATE schedule_versions SET vacancy_count = 1 WHERE id = version_id;
        RAISE EXCEPTION 'published schedule version remained mutable';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        INSERT INTO schedule_versions (
            schedule_id, version_number, status, created_by, published_by, published_at
        ) VALUES (schedule_id, 2, 'PUBLICADA', 'test.i9', 'test.i9', NOW());
        RAISE EXCEPTION 'schedule accepted more than one published version';
    EXCEPTION WHEN unique_violation THEN NULL; END;

    UPDATE schedule_versions SET status = 'REEMPLAZADA' WHERE id = version_id;
    IF (SELECT status FROM schedule_versions WHERE id = version_id) <> 'REEMPLAZADA' THEN
        RAISE EXCEPTION 'published schedule version was not replaced';
    END IF;

    INSERT INTO schedule_versions (
        schedule_id, version_number, status, created_by, approved_by, approved_at, published_by, published_at
    ) VALUES (schedule_id, 2, 'PUBLICADA', 'test.i9', 'test.i9', NOW(), 'test.i9', NOW());
END
$$;

ROLLBACK;

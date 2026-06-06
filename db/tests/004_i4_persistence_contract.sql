\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    employee_id BIGINT;
    signer_id BIGINT;
    certificate_id BIGINT;
    admin_role_id BIGINT;
    th_role_id BIGINT;
    gerencia_role_id BIGINT;
    operaciones_role_id BIGINT;
BEGIN
    IF to_regclass('certificate_signers') IS NULL THEN
        RAISE EXCEPTION 'Missing table certificate_signers';
    END IF;

    IF to_regclass('labor_certificates') IS NULL THEN
        RAISE EXCEPTION 'Missing table labor_certificates';
    END IF;

    IF to_regclass('labor_certificate_variables') IS NULL THEN
        RAISE EXCEPTION 'Missing table labor_certificate_variables';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE tablename = 'labor_certificates'
          AND indexdef LIKE '%certificate_number%'
          AND indexdef LIKE '%UNIQUE%'
    ) THEN
        RAISE EXCEPTION 'Missing unique certificate number constraint';
    END IF;

    BEGIN
        INSERT INTO certificate_signers (full_name, job_title, valid_from)
        VALUES ('', 'Representante Legal', CURRENT_DATE);

        RAISE EXCEPTION 'Signer accepted blank full_name';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO certificate_signers (full_name, job_title, valid_from, valid_to)
        VALUES ('Firmante Invalido', 'Representante Legal', CURRENT_DATE, CURRENT_DATE - 1);

        RAISE EXCEPTION 'Signer accepted invalid validity range';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO certificate_signers (full_name, job_title, valid_from, status)
    VALUES ('Firmante I4', 'Representante Legal', CURRENT_DATE - 10, 'ACTIVO')
    RETURNING id INTO signer_id;

    INSERT INTO employees (
        identification_type,
        identification_number,
        full_name,
        employment_status,
        job_title,
        hire_date
    )
    VALUES ('CC', 'I4-PERSISTENCE-EMPLOYEE', 'Empleado I4 Persistencia', 'ACTIVO', 'Guarda', CURRENT_DATE - 30)
    RETURNING id INTO employee_id;

    INSERT INTO labor_certificates (
        certificate_number,
        employee_id,
        signer_id,
        certificate_type,
        purpose,
        status,
        snapshot_payload,
        created_by
    )
    VALUES (
        'CERT-I4-0001',
        employee_id,
        signer_id,
        'ACTIVO',
        'TRAMITE_GENERAL',
        'BORRADOR',
        '{"employeeFullName":"Empleado I4 Persistencia","baseSalary":1500000}'::jsonb,
        'th.sg'
    )
    RETURNING id INTO certificate_id;

    BEGIN
        INSERT INTO labor_certificates (
            certificate_number,
            employee_id,
            signer_id,
            certificate_type,
            purpose,
            status,
            snapshot_payload,
            created_by
        )
        VALUES (
            'CERT-I4-0001',
            employee_id,
            signer_id,
            'ACTIVO',
            'TRAMITE_GENERAL',
            'BORRADOR',
            '{}'::jsonb,
            'th.sg'
        );

        RAISE EXCEPTION 'Certificate accepted duplicate number';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO labor_certificates (
            certificate_number,
            employee_id,
            signer_id,
            certificate_type,
            purpose,
            status,
            snapshot_payload,
            created_by
        )
        VALUES (
            'CERT-I4-0002',
            employee_id,
            signer_id,
            'ACTIVO',
            'TRAMITE_GENERAL',
            'GENERADA',
            '{}'::jsonb,
            'th.sg'
        );

        RAISE EXCEPTION 'Generated certificate accepted without pdf_path and generated_at';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO labor_certificates (
            certificate_number,
            employee_id,
            signer_id,
            certificate_type,
            purpose,
            status,
            snapshot_payload,
            created_by
        )
        VALUES (
            'CERT-I4-0003',
            employee_id,
            signer_id,
            'ACTIVO',
            'TRAMITE_GENERAL',
            'ANULADA',
            '{}'::jsonb,
            'th.sg'
        );

        RAISE EXCEPTION 'Annulled certificate accepted without reason';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO labor_certificate_variables (
        certificate_id,
        concept_code,
        concept_label,
        amount
    )
    VALUES (
        certificate_id,
        'AUX_TRANSPORTE',
        'Auxilio de transporte',
        162000
    );

    BEGIN
        INSERT INTO labor_certificate_variables (
            certificate_id,
            concept_code,
            concept_label,
            amount
        )
        VALUES (
            certificate_id,
            'EXTRAS',
            'Horas extras',
            -1
        );

        RAISE EXCEPTION 'Certificate variable accepted negative amount';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    SELECT id INTO admin_role_id FROM roles WHERE code = 'ADMIN';
    SELECT id INTO th_role_id FROM roles WHERE code = 'TH';
    SELECT id INTO gerencia_role_id FROM roles WHERE code = 'GERENCIA';
    SELECT id INTO operaciones_role_id FROM roles WHERE code = 'OPERACIONES';

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = admin_role_id AND module_code = 'CERTIFICATE_SIGNERS' AND action_code = 'MANAGE' AND allowed) THEN
        RAISE EXCEPTION 'ADMIN must manage certificate signers';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = th_role_id AND module_code = 'CERTIFICATES' AND action_code = 'GENERATE' AND allowed) THEN
        RAISE EXCEPTION 'TH must generate certificates';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = gerencia_role_id AND module_code = 'CERTIFICATES' AND action_code = 'VIEW' AND allowed) THEN
        RAISE EXCEPTION 'GERENCIA must view certificates';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = gerencia_role_id AND module_code = 'CERTIFICATE_SIGNERS' AND action_code = 'VIEW' AND allowed) THEN
        RAISE EXCEPTION 'GERENCIA must view certificate signers';
    END IF;

    IF EXISTS (SELECT 1 FROM role_permissions WHERE role_id = operaciones_role_id AND module_code IN ('CERTIFICATES', 'CERTIFICATE_SIGNERS') AND allowed) THEN
        RAISE EXCEPTION 'OPERACIONES must not have I4 permissions in MVP';
    END IF;
END
$$;

ROLLBACK;

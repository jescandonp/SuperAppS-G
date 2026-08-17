\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    profile_id BIGINT;
    evaluation_id BIGINT;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM unnest(ARRAY[
            'scheduling_rule_profiles',
            'scheduling_rule_profile_entries',
            'scheduling_rule_evaluations'
        ]) AS expected(table_name)
        WHERE to_regclass(expected.table_name) IS NULL
    ) THEN
        RAISE EXCEPTION 'I9 MVP rule profile tables are missing';
    END IF;

    SELECT id
      INTO profile_id
      FROM scheduling_rule_profiles
     WHERE profile_code = 'I9-MVP-SIMULATED'
       AND version = 1;

    IF profile_id IS NULL THEN
        RAISE EXCEPTION 'Missing simulated MVP rule profile seed';
    END IF;

    IF (SELECT count(*) FROM scheduling_rule_profiles
        WHERE profile_code = 'I9-MVP-SIMULATED' AND version = 1
          AND origin = 'SIMULATED' AND environment_scope = 'MVP_TEST'
          AND status = 'ACTIVE') <> 1 THEN
        RAISE EXCEPTION 'Simulated seed profile is not uniquely ACTIVE in MVP_TEST';
    END IF;

    IF (SELECT array_agg(rule_code ORDER BY rule_code)
        FROM scheduling_rule_profile_entries WHERE rule_profile_id = profile_id)
       <> ARRAY['I9-R01','I9-R02','I9-R03','I9-R04','I9-R05','I9-R06','I9-R07']::VARCHAR[] THEN
        RAISE EXCEPTION 'Simulated seed must contain exactly I9-R01 through I9-R07';
    END IF;

    IF EXISTS (
        SELECT 1 FROM scheduling_rule_profile_entries
        WHERE rule_profile_id = profile_id
          AND (jsonb_typeof(parameters) <> 'object'
               OR jsonb_typeof(catalog_snapshot) <> 'object'
               OR parameters = '{}'::jsonb)
    ) THEN
        RAISE EXCEPTION 'Every seeded rule entry requires complete object JSON';
    END IF;

    BEGIN
        INSERT INTO scheduling_rule_profiles (
            profile_code, version, origin, environment_scope, scope_code,
            effective_from, status, checksum, created_by, approval_evidence
        ) VALUES (
            'I9-BAD-PRODUCTION', 1, 'SIMULATED', 'PRODUCTION', 'GLOBAL',
            CURRENT_DATE, 'DRAFT', repeat('a', 64), 'contract.i9', '{}'::jsonb
        );
        RAISE EXCEPTION 'SIMULATED profile was accepted in PRODUCTION';
    EXCEPTION WHEN check_violation THEN NULL; END;

    BEGIN
        INSERT INTO scheduling_rule_profiles (
            profile_code, version, origin, environment_scope, scope_code,
            effective_from, effective_to, status, checksum, created_by,
            activated_by, activated_at, approval_evidence
        ) SELECT
            profile_code, 99, origin, environment_scope, scope_code,
            effective_from, effective_to, 'ACTIVE', repeat('b', 64), 'contract.i9',
            'contract.i9', clock_timestamp(), '{}'::jsonb
        FROM scheduling_rule_profiles WHERE id = profile_id;
        RAISE EXCEPTION 'Overlapping ACTIVE profile was accepted';
    EXCEPTION WHEN integrity_constraint_violation THEN NULL; END;

    BEGIN
        UPDATE scheduling_rule_profiles SET checksum = repeat('d', 64) WHERE id = profile_id;
        RAISE EXCEPTION 'ACTIVE profile immutability failed';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        UPDATE scheduling_rule_profile_entries
           SET parameters = jsonb_set(parameters, '{tampered}', 'true'::jsonb)
         WHERE rule_profile_id = profile_id AND rule_code = 'I9-R01';
        RAISE EXCEPTION 'ACTIVE profile entry immutability failed';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    INSERT INTO scheduling_rule_evaluations (
        rule_profile_id, rule_code, outcome, severity, message_code,
        explanation, parameters_snapshot, facts_snapshot, scope_hash,
        exception_allowed, exception_status, correlation_id, audit_actor
    ) VALUES (
        profile_id, 'I9-R02', 'EXCEPTION_REQUIRED', 'WARNING', 'I9_R02_MIN_REST',
        'Anonymous contract evaluation', '{"minimumRestHours":12}'::jsonb,
        '{"restMinutes":660,"subjectRef":"ANON-001"}'::jsonb, repeat('e', 64),
        TRUE, 'PENDING', 'contract-evaluation-001', 'contract.i9'
    ) RETURNING id INTO evaluation_id;

    BEGIN
        UPDATE scheduling_rule_evaluations SET outcome = 'COMPLIANT' WHERE id = evaluation_id;
        RAISE EXCEPTION 'Historical evaluation immutability failed';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        DELETE FROM scheduling_rule_evaluations WHERE id = evaluation_id;
        RAISE EXCEPTION 'Historical evaluation remained deletable';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'schedule_versions'
          AND column_name = 'rule_profile_id'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'schedule_versions'
          AND column_name = 'simulated'
    ) THEN
        RAISE EXCEPTION 'schedule_versions lacks rule profile or simulated audit fields';
    END IF;

    IF EXISTS (
        SELECT 1 FROM (VALUES ('rule_code'),('evaluation_id'),('scope_hash'),
            ('motive_code'),('decision'),('decided_by'),('decided_at'),('decision_detail')) expected(column_name)
        LEFT JOIN information_schema.columns c
          ON c.table_schema = current_schema()
         AND c.table_name = 'schedule_exceptions'
         AND c.column_name = expected.column_name
        WHERE c.column_name IS NULL
    ) THEN
        RAISE EXCEPTION 'schedule_exceptions lacks audited rule decision fields';
    END IF;
END
$$;

ROLLBACK;

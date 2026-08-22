\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    profile_id BIGINT;
    draft_profile_id BIGINT;
    evaluation_id BIGINT;
    schedule_version_id BIGINT;
    exception_id BIGINT;
    client_id BIGINT;
    project_id BIGINT;
    schedule_id BIGINT;
    retirement_date DATE := CURRENT_DATE + 30;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM unnest(ARRAY[
            'scheduling_rule_profiles',
            'scheduling_rule_profile_entries',
            'scheduling_rule_evaluations',
            'scheduling_rule_hr_validations'
        ]) AS expected(table_name)
        WHERE to_regclass(expected.table_name) IS NULL
    ) THEN
        RAISE EXCEPTION 'I9 MVP rule profile tables are missing';
    END IF;

    IF EXISTS (
        SELECT 1 FROM unnest(ARRAY[
            'evaluation_id','rule_code','scope_hash','evidence_id','status',
            'validator_user_id','validator_username','validated_at','audit_detail'
        ]) AS expected(column_name)
        WHERE NOT EXISTS (
            SELECT 1 FROM information_schema.columns c
            WHERE c.table_schema = current_schema()
              AND c.table_name = 'scheduling_rule_hr_validations'
              AND c.column_name = expected.column_name
              AND c.is_nullable = 'NO'
        )
    ) THEN
        RAISE EXCEPTION 'Persisted TH validation contract is incomplete';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='scheduling_rule_hr_validations'::regclass AND tgname='scheduling_rule_hr_validation_scope' AND NOT tgisinternal)
       OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='scheduling_rule_hr_validations'::regclass AND tgname='scheduling_rule_hr_validations_immutable' AND NOT tgisinternal)
       OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='scheduling_rule_hr_validations'::regclass AND conname='scheduling_rule_hr_validation_evaluation_fkey' AND contype='f')
       OR NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='scheduling_rule_hr_validations'::regclass AND conname='uq_scheduling_rule_hr_validation_evidence' AND contype='u') THEN
        RAISE EXCEPTION 'Persisted TH validation guards are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid='schedule_exceptions'::regclass
          AND conname='uq_schedule_exceptions_evaluation_rule_scope_motive'
          AND contype='u'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid='schedule_exceptions'::regclass
          AND tgname='schedule_exceptions_i9_immutable'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'I9 schedule exception identity or immutability guard is missing';
    END IF;

    SELECT id
      INTO profile_id
      FROM scheduling_rule_profiles
     WHERE profile_code = 'I9-MVP-SIMULATED'
       AND version = 2;

    IF profile_id IS NULL THEN
        RAISE EXCEPTION 'Missing simulated MVP rule profile seed';
    END IF;

    IF (SELECT count(*) FROM scheduling_rule_profiles
        WHERE profile_code = 'I9-MVP-SIMULATED' AND version = 2
          AND origin = 'SIMULATED' AND environment_scope = 'MVP_TEST'
          AND status = 'ACTIVE') <> 1 THEN
        RAISE EXCEPTION 'Simulated seed profile is not uniquely ACTIVE in MVP_TEST';
    END IF;

    IF EXISTS (SELECT 1 FROM scheduling_rule_profiles
               WHERE profile_code='I9-MVP-SIMULATED' AND version=1 AND status='ACTIVE') THEN
        RAISE EXCEPTION 'Superseded simulated v1 profile remained ACTIVE';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM scheduling_rule_profile_entries
                   WHERE rule_profile_id=profile_id AND rule_code='I9-R04'
                     AND jsonb_array_length(catalog_snapshot->'mappingDemo')>=5)
       OR NOT EXISTS (SELECT 1 FROM scheduling_rule_profile_entries
                      WHERE rule_profile_id=profile_id AND rule_code='I9-R06'
                        AND jsonb_array_length(catalog_snapshot->'requirementsDemo')>=2) THEN
        RAISE EXCEPTION 'Simulated v2 catalogs are not executable R04/R06 snapshots';
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

    IF i9_mvp_canonical_jsonb('1e2'::jsonb) <> i9_mvp_canonical_jsonb('100'::jsonb)
       OR i9_mvp_canonical_jsonb('1.0'::jsonb) <> i9_mvp_canonical_jsonb('1.00'::jsonb)
       OR i9_mvp_canonical_jsonb('1.00'::jsonb) <> i9_mvp_canonical_jsonb('1'::jsonb)
       OR i9_mvp_canonical_jsonb('-0'::jsonb) <> i9_mvp_canonical_jsonb('0'::jsonb)
       OR i9_mvp_canonical_jsonb('0.0100'::jsonb) <> i9_mvp_canonical_jsonb('0.01'::jsonb) THEN
        RAISE EXCEPTION 'I9 canonical JSONB number equivalence failed';
    END IF;

    IF i9_mvp_canonical_jsonb('{"bbb":1,"a":2,"cc":3}'::jsonb)
       <> '{"a": 2, "cc": 3, "bbb": 1}' THEN
        RAISE EXCEPTION 'I9 canonical JSONB object ordering failed';
    END IF;
    IF i9_mvp_canonical_jsonb('[{"z":1,"a":true},null,"x"]'::jsonb)
       <> '[{"a": true, "z": 1}, null, "x"]' THEN
        RAISE EXCEPTION 'I9 canonical JSONB array or scalar preservation failed';
    END IF;
    IF i9_mvp_canonical_jsonb(to_jsonb(chr(11))) <> ('"'||chr(92)||'u000b"') THEN
        RAISE EXCEPTION 'I9 canonical JSONB control escape casing failed';
    END IF;
    IF i9_mvp_canonical_jsonb('{"outer":{"dup":1,"dup":2}}'::jsonb)
       <> '{"outer": {"dup": 2}}' THEN
        RAISE EXCEPTION 'I9 canonical JSONB nested duplicate last-wins failed';
    END IF;

    BEGIN
        PERFORM i9_mvp_canonical_jsonb('1e1001'::jsonb);
        RAISE EXCEPTION 'I9 unsupported canonical number was accepted';
    EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;

    IF (SELECT checksum::TEXT FROM scheduling_rule_profiles WHERE id=profile_id)
       <> (SELECT encode(public.digest(convert_to(string_agg(rule_code||':'||i9_mvp_canonical_jsonb(parameters)||':'||
                    i9_mvp_canonical_jsonb(catalog_snapshot),'|' ORDER BY rule_code),'UTF8'),'sha256'),'hex')
             FROM scheduling_rule_profile_entries WHERE rule_profile_id=profile_id) THEN
        RAISE EXCEPTION 'Seed checksum does not match canonical executable composition';
    END IF;
    IF encode(public.digest(convert_to(i9_mvp_canonical_jsonb('"ñ"'::jsonb),'UTF8'),'sha256'),'hex')
       <> '1141a26205a85d1449eebbea3abff7b04018691fd12fd0f2394feea4058afb8b' THEN
        RAISE EXCEPTION 'I9 canonical checksum is not explicit UTF8 for non-ASCII content';
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
        DELETE FROM scheduling_rule_profiles WHERE id = profile_id;
        RAISE EXCEPTION 'ACTIVE profile deletion was accepted';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        UPDATE scheduling_rule_profile_entries
           SET parameters = jsonb_set(parameters, '{tampered}', 'true'::jsonb)
         WHERE rule_profile_id = profile_id AND rule_code = 'I9-R01';
        RAISE EXCEPTION 'ACTIVE profile entry immutability failed';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    INSERT INTO scheduling_rule_profiles (
        profile_code, version, origin, environment_scope, scope_code,
        effective_from, status, checksum, created_by, approval_evidence
    ) VALUES (
        'I9-DRAFT-TRANSFER-TARGET', 1, 'INSTITUTIONAL', 'MVP_TEST', 'GLOBAL-DEMO',
        CURRENT_DATE, 'DRAFT', repeat('f', 64), 'contract.i9', '{}'::jsonb
    ) RETURNING id INTO draft_profile_id;

    BEGIN
        INSERT INTO scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled)
        VALUES(draft_profile_id,'I9-R01',jsonb_build_object('payload',repeat('x',65537)),'{}'::jsonb,TRUE);
        RAISE EXCEPTION 'Oversized parameters JSON was accepted';
    EXCEPTION WHEN check_violation THEN NULL; END;

    BEGIN
        INSERT INTO scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled)
        VALUES(draft_profile_id,'I9-R01','{}'::jsonb,jsonb_build_object('payload',repeat('x',262145)),TRUE);
        RAISE EXCEPTION 'Oversized catalog snapshot JSON was accepted';
    EXCEPTION WHEN check_violation THEN NULL; END;

    INSERT INTO scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled)
    SELECT draft_profile_id,'I9-R0'||number,'{}'::jsonb,'{}'::jsonb,TRUE FROM generate_series(1,7) number;
    BEGIN
        INSERT INTO scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled)
        VALUES(draft_profile_id,'I9-R01','{}'::jsonb,'{}'::jsonb,FALSE);
        RAISE EXCEPTION 'Eighth rule profile entry was accepted';
    EXCEPTION WHEN check_violation THEN NULL; END;

    BEGIN
        UPDATE scheduling_rule_profile_entries
           SET rule_profile_id = draft_profile_id
         WHERE rule_profile_id = profile_id AND rule_code = 'I9-R01';
        RAISE EXCEPTION 'Entry was moved from ACTIVE profile to DRAFT profile';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    UPDATE scheduling_rule_profiles
       SET status = 'RETIRED', effective_to = retirement_date
     WHERE id = profile_id;

    IF NOT EXISTS (
        SELECT 1 FROM scheduling_rule_profiles
        WHERE id = profile_id AND status = 'RETIRED'
          AND effective_to = retirement_date
    ) THEN
        RAISE EXCEPTION 'Controlled ACTIVE to RETIRED transition failed';
    END IF;

    BEGIN
        UPDATE scheduling_rule_profile_entries
           SET catalog_snapshot = jsonb_set(catalog_snapshot, '{tampered}', 'true'::jsonb)
         WHERE rule_profile_id = profile_id AND rule_code = 'I9-R04';
        RAISE EXCEPTION 'RETIRED profile entry UPDATE was accepted';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        DELETE FROM scheduling_rule_profile_entries
         WHERE rule_profile_id = profile_id AND rule_code = 'I9-R04';
        RAISE EXCEPTION 'RETIRED profile entry DELETE was accepted';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        UPDATE scheduling_rule_profile_entries
           SET rule_profile_id = draft_profile_id
         WHERE rule_profile_id = profile_id AND rule_code = 'I9-R04';
        RAISE EXCEPTION 'Entry was moved from RETIRED profile to DRAFT profile';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        INSERT INTO scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled)
        VALUES(profile_id,'I9-R01','{}'::jsonb,'{}'::jsonb,FALSE);
        RAISE EXCEPTION 'Entry was inserted into RETIRED profile';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    INSERT INTO scheduling_rule_profiles (
        profile_code, version, origin, environment_scope, scope_code,
        effective_from, status, checksum, created_by,
        activated_by, activated_at, approval_evidence
    ) SELECT
        profile_code, 3, origin, environment_scope, scope_code,
        retirement_date + 1, 'ACTIVE', repeat('c', 64), 'contract.i9',
        'contract.i9', clock_timestamp(), '{}'::jsonb
    FROM scheduling_rule_profiles WHERE id = profile_id;

    IF EXISTS (
        SELECT 1
        FROM scheduling_rule_profiles retired
        JOIN scheduling_rule_profiles replacement
          ON replacement.profile_code = retired.profile_code
         AND replacement.scope_code = retired.scope_code
         AND replacement.environment_scope = retired.environment_scope
         AND replacement.version = 3
        WHERE retired.id = profile_id
          AND daterange(retired.effective_from, retired.effective_to + 1, '[)')
              && daterange(replacement.effective_from,
                           coalesce(replacement.effective_to + 1, 'infinity'::date), '[)')
    ) THEN
        RAISE EXCEPTION 'Replacement ACTIVE profile overlaps retired profile validity';
    END IF;

    INSERT INTO clients (code, name, status)
    VALUES ('I9-MVP-CONTRACT-CLIENT', 'I9 MVP contract client', 'ACTIVO')
    RETURNING id INTO client_id;

    INSERT INTO service_projects (client_id, code, name, effective_from, status)
    VALUES (client_id, 'I9-MVP-CONTRACT-PROJECT', 'I9 MVP contract project', CURRENT_DATE, 'ACTIVO')
    RETURNING id INTO project_id;

    INSERT INTO schedules (project_id, period_start, period_end, created_by)
    VALUES (project_id, CURRENT_DATE, CURRENT_DATE + 30, 'contract.i9')
    RETURNING id INTO schedule_id;

    INSERT INTO schedule_versions (schedule_id, version_number, status, created_by)
    VALUES (schedule_id, 1, 'BORRADOR', 'contract.i9')
    RETURNING id INTO schedule_version_id;

    INSERT INTO scheduling_rule_evaluations (
        schedule_version_id, rule_profile_id, rule_code, outcome, severity, message_code,
        explanation, parameters_snapshot, facts_snapshot, scope_hash,
        exception_allowed, exception_status, correlation_id, audit_actor
    ) VALUES (
        schedule_version_id, profile_id, 'I9-R02', 'EXCEPTION_REQUIRED', 'WARNING', 'I9_R02_MIN_REST',
        'Anonymous contract evaluation', '{"minimumRestHours":12}'::jsonb,
        '{"restMinutes":660,"subjectRef":"ANON-001"}'::jsonb, repeat('e', 64),
        TRUE, 'PENDING', 'contract-evaluation-001', 'contract.i9'
    ) RETURNING id INTO evaluation_id;

    BEGIN
        INSERT INTO schedule_exceptions (
            schedule_version_id, exception_type, reason, responsible,
            evaluation_id, rule_code, scope_hash, motive_code
        ) VALUES (
            schedule_version_id, 'RULE_EXCEPTION', 'Contract mismatch', 'contract.i9',
            evaluation_id, 'I9-R03', repeat('e', 64), 'CONTRACT_TEST'
        );
        RAISE EXCEPTION 'schedule_exceptions accepted a foreign rule_code';
    EXCEPTION WHEN foreign_key_violation THEN NULL; END;

    BEGIN
        INSERT INTO schedule_exceptions (
            schedule_version_id, exception_type, reason, responsible,
            evaluation_id, rule_code, scope_hash, motive_code
        ) VALUES (
            schedule_version_id, 'RULE_EXCEPTION', 'Contract mismatch', 'contract.i9',
            evaluation_id, 'I9-R02', repeat('f', 64), 'CONTRACT_TEST'
        );
        RAISE EXCEPTION 'schedule_exceptions accepted a foreign scope_hash';
    EXCEPTION WHEN foreign_key_violation THEN NULL; END;

    BEGIN
        INSERT INTO schedule_exceptions (
            schedule_version_id, exception_type, reason, responsible,
            evaluation_id
        ) VALUES (
            schedule_version_id, 'RULE_EXCEPTION', 'Partial identity', 'contract.i9',
            evaluation_id
        );
        RAISE EXCEPTION 'schedule_exceptions accepted a partial I9 identity';
    EXCEPTION WHEN check_violation THEN NULL; END;

    INSERT INTO schedule_exceptions (
        schedule_version_id, exception_type, reason, responsible,
        evaluation_id, rule_code, scope_hash, motive_code
    ) VALUES (
        schedule_version_id, 'RULE_EXCEPTION', 'Contract match', 'contract.i9',
        evaluation_id, 'I9-R02', repeat('e', 64), 'CONTRACT_TEST'
    ) RETURNING id INTO exception_id;

    BEGIN
        INSERT INTO schedule_exceptions (
            schedule_version_id, exception_type, reason, responsible,
            evaluation_id, rule_code, scope_hash, motive_code
        ) VALUES (
            schedule_version_id, 'RULE_EXCEPTION', 'Duplicate contract match', 'contract.i9',
            evaluation_id, 'I9-R02', repeat('e', 64), 'CONTRACT_TEST'
        );
        RAISE EXCEPTION 'Duplicate I9 exception identity was accepted';
    EXCEPTION WHEN unique_violation THEN NULL; END;

    BEGIN
        UPDATE schedule_exceptions SET reason = 'Tampered history' WHERE id = exception_id;
        RAISE EXCEPTION 'Historical I9 schedule exception UPDATE was accepted';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

    BEGIN
        DELETE FROM schedule_exceptions WHERE id = exception_id;
        RAISE EXCEPTION 'Historical I9 schedule exception DELETE was accepted';
    EXCEPTION WHEN SQLSTATE '55000' THEN NULL; END;

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

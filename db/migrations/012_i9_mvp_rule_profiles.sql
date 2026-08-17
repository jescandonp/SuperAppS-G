\set ON_ERROR_STOP on
BEGIN;

CREATE TABLE IF NOT EXISTS scheduling_rule_profiles ();
CREATE TABLE IF NOT EXISTS scheduling_rule_profile_entries ();
CREATE TABLE IF NOT EXISTS scheduling_rule_evaluations ();

ALTER TABLE scheduling_rule_profiles
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS profile_code VARCHAR(80),
 ADD COLUMN IF NOT EXISTS version INTEGER,
 ADD COLUMN IF NOT EXISTS origin VARCHAR(20),
 ADD COLUMN IF NOT EXISTS environment_scope VARCHAR(20),
 ADD COLUMN IF NOT EXISTS scope_code VARCHAR(120),
 ADD COLUMN IF NOT EXISTS effective_from DATE,
 ADD COLUMN IF NOT EXISTS effective_to DATE,
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS checksum CHAR(64),
 ADD COLUMN IF NOT EXISTS created_by VARCHAR(80),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS activated_by VARCHAR(80),
 ADD COLUMN IF NOT EXISTS activated_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS approval_evidence JSONB;

ALTER TABLE scheduling_rule_profile_entries
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS rule_profile_id BIGINT,
 ADD COLUMN IF NOT EXISTS rule_code VARCHAR(20),
 ADD COLUMN IF NOT EXISTS parameters JSONB,
 ADD COLUMN IF NOT EXISTS catalog_snapshot JSONB,
 ADD COLUMN IF NOT EXISTS enabled BOOLEAN,
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ;

ALTER TABLE scheduling_rule_evaluations
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS schedule_version_id BIGINT,
 ADD COLUMN IF NOT EXISTS assignment_id BIGINT,
 ADD COLUMN IF NOT EXISTS rule_profile_id BIGINT,
 ADD COLUMN IF NOT EXISTS rule_code VARCHAR(20),
 ADD COLUMN IF NOT EXISTS outcome VARCHAR(30),
 ADD COLUMN IF NOT EXISTS severity VARCHAR(20),
 ADD COLUMN IF NOT EXISTS message_code VARCHAR(80),
 ADD COLUMN IF NOT EXISTS explanation VARCHAR(1000),
 ADD COLUMN IF NOT EXISTS parameters_snapshot JSONB,
 ADD COLUMN IF NOT EXISTS facts_snapshot JSONB,
 ADD COLUMN IF NOT EXISTS scope_hash CHAR(64),
 ADD COLUMN IF NOT EXISTS exception_allowed BOOLEAN,
 ADD COLUMN IF NOT EXISTS exception_status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS correlation_id VARCHAR(80),
 ADD COLUMN IF NOT EXISTS evaluated_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS audit_actor VARCHAR(80);

ALTER TABLE schedule_versions
 ADD COLUMN IF NOT EXISTS rule_profile_id BIGINT,
 ADD COLUMN IF NOT EXISTS rule_profile_version INTEGER,
 ADD COLUMN IF NOT EXISTS simulated BOOLEAN;

ALTER TABLE schedule_exceptions
 ADD COLUMN IF NOT EXISTS rule_code VARCHAR(20),
 ADD COLUMN IF NOT EXISTS evaluation_id BIGINT,
 ADD COLUMN IF NOT EXISTS scope_hash CHAR(64),
 ADD COLUMN IF NOT EXISTS motive_code VARCHAR(50),
 ADD COLUMN IF NOT EXISTS decision VARCHAR(20),
 ADD COLUMN IF NOT EXISTS decided_by VARCHAR(80),
 ADD COLUMN IF NOT EXISTS decided_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS decision_detail JSONB;

DO $$
DECLARE
    r RECORD;
    actual_type TEXT;
BEGIN
    FOR r IN SELECT * FROM (VALUES
      ('scheduling_rule_profiles','id','bigint'),('scheduling_rule_profiles','profile_code','character varying(80)'),('scheduling_rule_profiles','version','integer'),('scheduling_rule_profiles','origin','character varying(20)'),('scheduling_rule_profiles','environment_scope','character varying(20)'),('scheduling_rule_profiles','scope_code','character varying(120)'),('scheduling_rule_profiles','effective_from','date'),('scheduling_rule_profiles','effective_to','date'),('scheduling_rule_profiles','status','character varying(20)'),('scheduling_rule_profiles','checksum','character(64)'),('scheduling_rule_profiles','created_by','character varying(80)'),('scheduling_rule_profiles','created_at','timestamp with time zone'),('scheduling_rule_profiles','activated_by','character varying(80)'),('scheduling_rule_profiles','activated_at','timestamp with time zone'),('scheduling_rule_profiles','approval_evidence','jsonb'),
      ('scheduling_rule_profile_entries','id','bigint'),('scheduling_rule_profile_entries','rule_profile_id','bigint'),('scheduling_rule_profile_entries','rule_code','character varying(20)'),('scheduling_rule_profile_entries','parameters','jsonb'),('scheduling_rule_profile_entries','catalog_snapshot','jsonb'),('scheduling_rule_profile_entries','enabled','boolean'),('scheduling_rule_profile_entries','created_at','timestamp with time zone'),
      ('scheduling_rule_evaluations','id','bigint'),('scheduling_rule_evaluations','schedule_version_id','bigint'),('scheduling_rule_evaluations','assignment_id','bigint'),('scheduling_rule_evaluations','rule_profile_id','bigint'),('scheduling_rule_evaluations','rule_code','character varying(20)'),('scheduling_rule_evaluations','outcome','character varying(30)'),('scheduling_rule_evaluations','severity','character varying(20)'),('scheduling_rule_evaluations','message_code','character varying(80)'),('scheduling_rule_evaluations','explanation','character varying(1000)'),('scheduling_rule_evaluations','parameters_snapshot','jsonb'),('scheduling_rule_evaluations','facts_snapshot','jsonb'),('scheduling_rule_evaluations','scope_hash','character(64)'),('scheduling_rule_evaluations','exception_allowed','boolean'),('scheduling_rule_evaluations','exception_status','character varying(20)'),('scheduling_rule_evaluations','correlation_id','character varying(80)'),('scheduling_rule_evaluations','evaluated_at','timestamp with time zone'),('scheduling_rule_evaluations','audit_actor','character varying(80)'),
      ('schedule_versions','rule_profile_id','bigint'),('schedule_versions','rule_profile_version','integer'),('schedule_versions','simulated','boolean'),
      ('schedule_exceptions','rule_code','character varying(20)'),('schedule_exceptions','evaluation_id','bigint'),('schedule_exceptions','scope_hash','character(64)'),('schedule_exceptions','motive_code','character varying(50)'),('schedule_exceptions','decision','character varying(20)'),('schedule_exceptions','decided_by','character varying(80)'),('schedule_exceptions','decided_at','timestamp with time zone'),('schedule_exceptions','decision_detail','jsonb')
    ) expected(t,c,expected_type)
    LOOP
        SELECT format_type(a.atttypid,a.atttypmod) INTO actual_type
        FROM pg_attribute a
        WHERE a.attrelid=r.t::regclass AND a.attname=r.c AND NOT a.attisdropped;
        IF actual_type <> r.expected_type THEN
            BEGIN
                EXECUTE format('ALTER TABLE %I ALTER COLUMN %I TYPE %s USING %I::%s',r.t,r.c,r.expected_type,r.c,r.expected_type);
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'I9_MVP_PARTIAL_SCHEMA_INCOMPATIBLE: %.% cannot converge from % to %: %',
                    r.t,r.c,actual_type,r.expected_type,SQLERRM;
            END;
        END IF;
    END LOOP;
END $$;

ALTER TABLE scheduling_rule_profiles
 ALTER COLUMN status SET DEFAULT 'DRAFT',
 ALTER COLUMN created_at SET DEFAULT NOW(),
 ALTER COLUMN approval_evidence SET DEFAULT '{}'::jsonb;
ALTER TABLE scheduling_rule_profile_entries
 ALTER COLUMN catalog_snapshot SET DEFAULT '{}'::jsonb,
 ALTER COLUMN enabled SET DEFAULT TRUE,
 ALTER COLUMN created_at SET DEFAULT NOW();
ALTER TABLE scheduling_rule_evaluations
 ALTER COLUMN parameters_snapshot SET DEFAULT '{}'::jsonb,
 ALTER COLUMN facts_snapshot SET DEFAULT '{}'::jsonb,
 ALTER COLUMN exception_allowed SET DEFAULT FALSE,
 ALTER COLUMN exception_status SET DEFAULT 'NOT_REQUIRED',
 ALTER COLUMN evaluated_at SET DEFAULT NOW();
ALTER TABLE schedule_versions ALTER COLUMN simulated SET DEFAULT FALSE;
ALTER TABLE schedule_exceptions ALTER COLUMN decision_detail SET DEFAULT '{}'::jsonb;

UPDATE schedule_versions SET simulated=FALSE WHERE simulated IS NULL;
UPDATE schedule_exceptions SET decision_detail='{}'::jsonb WHERE decision_detail IS NULL;

DO $$
DECLARE
    r RECORD;
    null_count BIGINT;
BEGIN
    FOR r IN SELECT * FROM (VALUES
      ('scheduling_rule_profiles','id'),('scheduling_rule_profiles','profile_code'),('scheduling_rule_profiles','version'),('scheduling_rule_profiles','origin'),('scheduling_rule_profiles','environment_scope'),('scheduling_rule_profiles','scope_code'),('scheduling_rule_profiles','effective_from'),('scheduling_rule_profiles','status'),('scheduling_rule_profiles','checksum'),('scheduling_rule_profiles','created_by'),('scheduling_rule_profiles','created_at'),('scheduling_rule_profiles','approval_evidence'),
      ('scheduling_rule_profile_entries','id'),('scheduling_rule_profile_entries','rule_profile_id'),('scheduling_rule_profile_entries','rule_code'),('scheduling_rule_profile_entries','parameters'),('scheduling_rule_profile_entries','catalog_snapshot'),('scheduling_rule_profile_entries','enabled'),('scheduling_rule_profile_entries','created_at'),
      ('scheduling_rule_evaluations','id'),('scheduling_rule_evaluations','rule_profile_id'),('scheduling_rule_evaluations','rule_code'),('scheduling_rule_evaluations','outcome'),('scheduling_rule_evaluations','severity'),('scheduling_rule_evaluations','message_code'),('scheduling_rule_evaluations','explanation'),('scheduling_rule_evaluations','parameters_snapshot'),('scheduling_rule_evaluations','facts_snapshot'),('scheduling_rule_evaluations','scope_hash'),('scheduling_rule_evaluations','exception_allowed'),('scheduling_rule_evaluations','exception_status'),('scheduling_rule_evaluations','correlation_id'),('scheduling_rule_evaluations','evaluated_at'),('scheduling_rule_evaluations','audit_actor'),
      ('schedule_versions','simulated'),('schedule_exceptions','decision_detail')
    ) required(t,c)
    LOOP
        EXECUTE format('SELECT count(*) FROM %I WHERE %I IS NULL',r.t,r.c) INTO null_count;
        IF null_count > 0 THEN
            RAISE EXCEPTION 'I9_MVP_PARTIAL_SCHEMA_INCOMPATIBLE: %.% contains % NULL values',r.t,r.c,null_count;
        END IF;
        EXECUTE format('ALTER TABLE %I ALTER COLUMN %I SET NOT NULL',r.t,r.c);
    END LOOP;
END $$;

DO $$
DECLARE
    table_name TEXT;
    sequence_name TEXT;
    maximum_id BIGINT;
BEGIN
    FOREACH table_name IN ARRAY ARRAY['scheduling_rule_profiles','scheduling_rule_profile_entries','scheduling_rule_evaluations']
    LOOP
        sequence_name := pg_get_serial_sequence(format('%I.%I',current_schema(),table_name),'id');
        IF sequence_name IS NULL THEN
            sequence_name := format('%I.%I',current_schema(),table_name || '_id_seq');
            IF to_regclass(sequence_name) IS NULL THEN EXECUTE format('CREATE SEQUENCE %s AS BIGINT',sequence_name); END IF;
            EXECUTE format('ALTER TABLE %I ALTER COLUMN id SET DEFAULT nextval(%L::regclass)',table_name,sequence_name);
            EXECUTE format('ALTER SEQUENCE %s OWNED BY %I.id',sequence_name,table_name);
        END IF;
        EXECUTE format('SELECT coalesce(max(id),0) FROM %I',table_name) INTO maximum_id;
        IF maximum_id > 0 THEN PERFORM setval(sequence_name::regclass,maximum_id,TRUE); ELSE PERFORM setval(sequence_name::regclass,1,FALSE); END IF;
    END LOOP;
END $$;

CREATE OR REPLACE FUNCTION pg_temp.i9_mvp_constraint(t TEXT,n TEXT,k "char",d TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE existing RECORD;
BEGIN
 SELECT contype,pg_get_constraintdef(oid) AS definition INTO existing
 FROM pg_constraint WHERE conrelid=t::regclass AND conname=n;
 IF FOUND AND existing.contype=k
    AND regexp_replace(lower(existing.definition),'\s+','','g')=regexp_replace(lower(d),'\s+','','g') THEN RETURN; END IF;
 IF FOUND THEN EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I',t,n); END IF;
 EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I %s',t,n,d);
END $$;

SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profiles','scheduling_rule_profiles_pkey','p','PRIMARY KEY(id)');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profiles','uq_scheduling_rule_profiles_code_version','u','UNIQUE(profile_code,version)');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profiles','ck_scheduling_rule_profiles_values','c',$d$CHECK (btrim(profile_code)<>'' AND version>0 AND origin IN('SIMULATED','INSTITUTIONAL') AND environment_scope IN('MVP_TEST','PRODUCTION') AND btrim(scope_code)<>'' AND status IN('DRAFT','ACTIVE','RETIRED') AND (effective_to IS NULL OR effective_to>=effective_from))$d$);
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profiles','ck_scheduling_rule_profiles_environment','c',$d$CHECK (origin<>'SIMULATED' OR environment_scope='MVP_TEST')$d$);
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profiles','ck_scheduling_rule_profiles_json','c',$d$CHECK (jsonb_typeof(approval_evidence)='object' AND checksum ~ '^[0-9a-f]{64}$')$d$);
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profiles','ck_scheduling_rule_profiles_activation','c',$d$CHECK (status<>'ACTIVE' OR (activated_by IS NOT NULL AND activated_at IS NOT NULL))$d$);
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profile_entries','scheduling_rule_profile_entries_pkey','p','PRIMARY KEY(id)');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profile_entries','scheduling_rule_profile_entries_profile_fkey','f','FOREIGN KEY(rule_profile_id) REFERENCES scheduling_rule_profiles(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profile_entries','uq_scheduling_rule_profile_entries_rule','u','UNIQUE(rule_profile_id,rule_code)');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_profile_entries','ck_scheduling_rule_profile_entries_values','c',$d$CHECK (rule_code ~ '^I9-R0[1-7]$' AND jsonb_typeof(parameters)='object' AND jsonb_typeof(catalog_snapshot)='object')$d$);
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_evaluations','scheduling_rule_evaluations_pkey','p','PRIMARY KEY(id)');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_evaluations','scheduling_rule_evaluations_profile_fkey','f','FOREIGN KEY(rule_profile_id) REFERENCES scheduling_rule_profiles(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_evaluations','scheduling_rule_evaluations_schedule_version_fkey','f','FOREIGN KEY(schedule_version_id) REFERENCES schedule_versions(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_evaluations','scheduling_rule_evaluations_assignment_fkey','f','FOREIGN KEY(assignment_id) REFERENCES schedule_assignments(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_mvp_constraint('scheduling_rule_evaluations','ck_scheduling_rule_evaluations_values','c',$d$CHECK (rule_code ~ '^I9-R0[1-7]$' AND outcome IN('COMPLIANT','BLOCKED','EXCEPTION_REQUIRED','WARNING','NOT_APPLICABLE') AND severity IN('INFO','WARNING','ERROR','BLOCKING') AND btrim(message_code)<>'' AND btrim(explanation)<>'' AND jsonb_typeof(parameters_snapshot)='object' AND jsonb_typeof(facts_snapshot)='object' AND scope_hash ~ '^[0-9a-f]{64}$' AND btrim(correlation_id)<>'' AND btrim(audit_actor)<>'' AND exception_status IN('NOT_REQUIRED','PENDING','APPROVED','REJECTED','EXPIRED','STALE') AND (exception_allowed OR exception_status='NOT_REQUIRED'))$d$);
SELECT pg_temp.i9_mvp_constraint('schedule_versions','schedule_versions_rule_profile_fkey','f','FOREIGN KEY(rule_profile_id) REFERENCES scheduling_rule_profiles(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_mvp_constraint('schedule_versions','schedule_versions_rule_profile_audit_check','c',$d$CHECK ((rule_profile_id IS NULL AND rule_profile_version IS NULL AND NOT simulated) OR (rule_profile_id IS NOT NULL AND rule_profile_version>0))$d$);
SELECT pg_temp.i9_mvp_constraint('schedule_exceptions','schedule_exceptions_evaluation_fkey','f','FOREIGN KEY(evaluation_id) REFERENCES scheduling_rule_evaluations(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_mvp_constraint('schedule_exceptions','schedule_exceptions_rule_audit_check','c',$d$CHECK (((evaluation_id IS NULL AND rule_code IS NULL AND scope_hash IS NULL AND motive_code IS NULL) OR (evaluation_id IS NOT NULL AND rule_code ~ '^I9-R0[1-7]$' AND scope_hash ~ '^[0-9a-f]{64}$' AND btrim(motive_code)<>'')) AND jsonb_typeof(decision_detail)='object' AND ((decision IS NULL AND decided_by IS NULL AND decided_at IS NULL) OR (decision IN('APPROVED','REJECTED','CANCELLED') AND btrim(decided_by)<>'' AND decided_at IS NOT NULL)))$d$);

CREATE OR REPLACE FUNCTION enforce_single_active_rule_profile()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.status='ACTIVE' THEN
  PERFORM pg_advisory_xact_lock(hashtext(NEW.profile_code||'|'||NEW.scope_code||'|'||NEW.environment_scope));
  IF EXISTS(SELECT 1 FROM scheduling_rule_profiles p WHERE p.id<>coalesce(NEW.id,-1)
    AND p.profile_code=NEW.profile_code AND p.scope_code=NEW.scope_code
    AND p.environment_scope=NEW.environment_scope AND p.status='ACTIVE'
    AND daterange(p.effective_from,coalesce(p.effective_to+1,'infinity'::date),'[)')
        && daterange(NEW.effective_from,coalesce(NEW.effective_to+1,'infinity'::date),'[)')) THEN
   RAISE EXCEPTION USING ERRCODE='23000',MESSAGE='overlapping ACTIVE rule profile';
  END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS scheduling_rule_profiles_active_overlap ON scheduling_rule_profiles;
CREATE TRIGGER scheduling_rule_profiles_active_overlap BEFORE INSERT OR UPDATE ON scheduling_rule_profiles FOR EACH ROW EXECUTE FUNCTION enforce_single_active_rule_profile();

CREATE OR REPLACE FUNCTION reject_active_rule_profile_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 IF OLD.status='ACTIVE' THEN
  IF TG_OP='UPDATE'
     AND NEW.status='RETIRED'
     AND NEW.effective_to IS NOT NULL
     AND NEW.effective_to>=OLD.effective_from
     AND (OLD.effective_to IS NULL OR NEW.effective_to<=OLD.effective_to)
     AND NEW.id IS NOT DISTINCT FROM OLD.id
     AND NEW.profile_code IS NOT DISTINCT FROM OLD.profile_code
     AND NEW.version IS NOT DISTINCT FROM OLD.version
     AND NEW.origin IS NOT DISTINCT FROM OLD.origin
     AND NEW.environment_scope IS NOT DISTINCT FROM OLD.environment_scope
     AND NEW.scope_code IS NOT DISTINCT FROM OLD.scope_code
     AND NEW.effective_from IS NOT DISTINCT FROM OLD.effective_from
     AND NEW.checksum IS NOT DISTINCT FROM OLD.checksum
     AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
     AND NEW.created_at IS NOT DISTINCT FROM OLD.created_at
     AND NEW.activated_by IS NOT DISTINCT FROM OLD.activated_by
     AND NEW.activated_at IS NOT DISTINCT FROM OLD.activated_at
     AND NEW.approval_evidence IS NOT DISTINCT FROM OLD.approval_evidence THEN
   RETURN NEW;
  END IF;
  RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='ACTIVE rule profile is immutable except for controlled retirement';
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
DROP TRIGGER IF EXISTS scheduling_rule_profiles_immutable_active ON scheduling_rule_profiles;
CREATE TRIGGER scheduling_rule_profiles_immutable_active BEFORE UPDATE OR DELETE ON scheduling_rule_profiles FOR EACH ROW EXECUTE FUNCTION reject_active_rule_profile_change();

CREATE OR REPLACE FUNCTION reject_active_rule_profile_entry_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE parent_id BIGINT:=CASE WHEN TG_OP='DELETE' THEN OLD.rule_profile_id ELSE NEW.rule_profile_id END;
BEGIN
 IF EXISTS(SELECT 1 FROM scheduling_rule_profiles WHERE id=parent_id AND status='ACTIVE') THEN
  RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='ACTIVE rule profile entries are immutable';
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
DROP TRIGGER IF EXISTS scheduling_rule_profile_entries_immutable_active ON scheduling_rule_profile_entries;
CREATE TRIGGER scheduling_rule_profile_entries_immutable_active BEFORE INSERT OR UPDATE OR DELETE ON scheduling_rule_profile_entries FOR EACH ROW EXECUTE FUNCTION reject_active_rule_profile_entry_change();

CREATE OR REPLACE FUNCTION reject_rule_evaluation_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION USING ERRCODE='55000',MESSAGE='rule evaluation history is immutable'; END $$;
DROP TRIGGER IF EXISTS scheduling_rule_evaluations_immutable ON scheduling_rule_evaluations;
CREATE TRIGGER scheduling_rule_evaluations_immutable BEFORE UPDATE OR DELETE ON scheduling_rule_evaluations FOR EACH ROW EXECUTE FUNCTION reject_rule_evaluation_change();

DROP INDEX IF EXISTS idx_scheduling_rule_profiles_active_lookup;
CREATE INDEX idx_scheduling_rule_profiles_active_lookup ON scheduling_rule_profiles(profile_code,scope_code,environment_scope,effective_from,effective_to) WHERE status='ACTIVE';
DROP INDEX IF EXISTS idx_scheduling_rule_evaluations_version_rule;
CREATE INDEX idx_scheduling_rule_evaluations_version_rule ON scheduling_rule_evaluations(schedule_version_id,rule_code,evaluated_at);
DROP INDEX IF EXISTS idx_scheduling_rule_evaluations_scope_hash;
CREATE INDEX idx_scheduling_rule_evaluations_scope_hash ON scheduling_rule_evaluations(scope_hash);
DROP INDEX IF EXISTS idx_schedule_exceptions_evaluation;
CREATE INDEX idx_schedule_exceptions_evaluation ON schedule_exceptions(evaluation_id) WHERE evaluation_id IS NOT NULL;

COMMIT;

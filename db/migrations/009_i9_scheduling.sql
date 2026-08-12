\set ON_ERROR_STOP on
BEGIN;

CREATE TABLE IF NOT EXISTS clients ();
CREATE TABLE IF NOT EXISTS service_projects ();
CREATE TABLE IF NOT EXISTS shift_templates ();
CREATE TABLE IF NOT EXISTS shift_template_steps ();
CREATE TABLE IF NOT EXISTS position_coverage_rules ();
CREATE TABLE IF NOT EXISTS scheduling_rules ();
CREATE TABLE IF NOT EXISTS employee_availability_exceptions ();
CREATE TABLE IF NOT EXISTS position_requirements ();

ALTER TABLE clients
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS code VARCHAR(50),
 ADD COLUMN IF NOT EXISTS name VARCHAR(180),
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE service_projects
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS client_id BIGINT,
 ADD COLUMN IF NOT EXISTS code VARCHAR(50),
 ADD COLUMN IF NOT EXISTS name VARCHAR(180),
 ADD COLUMN IF NOT EXISTS effective_from DATE,
 ADD COLUMN IF NOT EXISTS effective_to DATE,
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE service_positions ADD COLUMN IF NOT EXISTS project_id BIGINT;
ALTER TABLE shift_templates
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS code VARCHAR(30),
 ADD COLUMN IF NOT EXISTS name VARCHAR(180),
 ADD COLUMN IF NOT EXISTS version INTEGER,
 ADD COLUMN IF NOT EXISTS effective_from DATE,
 ADD COLUMN IF NOT EXISTS effective_to DATE,
 ADD COLUMN IF NOT EXISTS mandatory_by_default BOOLEAN,
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE shift_template_steps
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS template_id BIGINT,
 ADD COLUMN IF NOT EXISTS step_order INTEGER,
 ADD COLUMN IF NOT EXISTS shift_code CHAR(1);
ALTER TABLE position_coverage_rules
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS position_id BIGINT,
 ADD COLUMN IF NOT EXISTS template_id BIGINT,
 ADD COLUMN IF NOT EXISTS weekday_scope VARCHAR(80),
 ADD COLUMN IF NOT EXISTS starts_at TIME,
 ADD COLUMN IF NOT EXISTS ends_at TIME,
 ADD COLUMN IF NOT EXISTS required_quantity INTEGER,
 ADD COLUMN IF NOT EXISTS effective_from DATE,
 ADD COLUMN IF NOT EXISTS effective_to DATE,
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE scheduling_rules
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS source_level VARCHAR(50),
 ADD COLUMN IF NOT EXISTS scope_type VARCHAR(50),
 ADD COLUMN IF NOT EXISTS scope_id BIGINT,
 ADD COLUMN IF NOT EXISTS severity VARCHAR(30),
 ADD COLUMN IF NOT EXISTS effective_from DATE,
 ADD COLUMN IF NOT EXISTS effective_to DATE,
 ADD COLUMN IF NOT EXISTS parameters JSONB,
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE employee_availability_exceptions
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS employee_id BIGINT,
 ADD COLUMN IF NOT EXISTS starts_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS ends_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS kind VARCHAR(50),
 ADD COLUMN IF NOT EXISTS blocking BOOLEAN,
 ADD COLUMN IF NOT EXISTS reason VARCHAR(500),
 ADD COLUMN IF NOT EXISTS created_by VARCHAR(80),
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE position_requirements
 ADD COLUMN IF NOT EXISTS id BIGSERIAL,
 ADD COLUMN IF NOT EXISTS position_id BIGINT,
 ADD COLUMN IF NOT EXISTS requirement_type_id BIGINT,
 ADD COLUMN IF NOT EXISTS severity VARCHAR(20),
 ADD COLUMN IF NOT EXISTS resolution_due_date DATE,
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

DO $$
DECLARE
    r RECORD;
    actual_type TEXT;
    row_count BIGINT;
    maximum_length BIGINT;
    compatible BOOLEAN;
BEGIN
    FOR r IN SELECT * FROM (VALUES
        ('clients','id','bigint'),('clients','code','character varying(50)'),('clients','name','character varying(180)'),('clients','status','character varying(20)'),('clients','created_at','timestamp with time zone'),('clients','updated_at','timestamp with time zone'),
        ('service_projects','id','bigint'),('service_projects','client_id','bigint'),('service_projects','code','character varying(50)'),('service_projects','name','character varying(180)'),('service_projects','effective_from','date'),('service_projects','effective_to','date'),('service_projects','status','character varying(20)'),('service_projects','created_at','timestamp with time zone'),('service_projects','updated_at','timestamp with time zone'),
        ('service_positions','project_id','bigint'),
        ('shift_templates','id','bigint'),('shift_templates','code','character varying(30)'),('shift_templates','name','character varying(180)'),('shift_templates','version','integer'),('shift_templates','effective_from','date'),('shift_templates','effective_to','date'),('shift_templates','mandatory_by_default','boolean'),('shift_templates','status','character varying(20)'),('shift_templates','created_at','timestamp with time zone'),('shift_templates','updated_at','timestamp with time zone'),
        ('shift_template_steps','id','bigint'),('shift_template_steps','template_id','bigint'),('shift_template_steps','step_order','integer'),('shift_template_steps','shift_code','character(1)'),
        ('position_coverage_rules','id','bigint'),('position_coverage_rules','position_id','bigint'),('position_coverage_rules','template_id','bigint'),('position_coverage_rules','weekday_scope','character varying(80)'),('position_coverage_rules','starts_at','time without time zone'),('position_coverage_rules','ends_at','time without time zone'),('position_coverage_rules','required_quantity','integer'),('position_coverage_rules','effective_from','date'),('position_coverage_rules','effective_to','date'),('position_coverage_rules','status','character varying(20)'),('position_coverage_rules','created_at','timestamp with time zone'),('position_coverage_rules','updated_at','timestamp with time zone'),
        ('scheduling_rules','id','bigint'),('scheduling_rules','source_level','character varying(50)'),('scheduling_rules','scope_type','character varying(50)'),('scheduling_rules','scope_id','bigint'),('scheduling_rules','severity','character varying(30)'),('scheduling_rules','effective_from','date'),('scheduling_rules','effective_to','date'),('scheduling_rules','parameters','jsonb'),('scheduling_rules','status','character varying(20)'),('scheduling_rules','created_at','timestamp with time zone'),('scheduling_rules','updated_at','timestamp with time zone'),
        ('employee_availability_exceptions','id','bigint'),('employee_availability_exceptions','employee_id','bigint'),('employee_availability_exceptions','starts_at','timestamp with time zone'),('employee_availability_exceptions','ends_at','timestamp with time zone'),('employee_availability_exceptions','kind','character varying(50)'),('employee_availability_exceptions','blocking','boolean'),('employee_availability_exceptions','reason','character varying(500)'),('employee_availability_exceptions','created_by','character varying(80)'),('employee_availability_exceptions','status','character varying(20)'),('employee_availability_exceptions','created_at','timestamp with time zone'),('employee_availability_exceptions','updated_at','timestamp with time zone'),
        ('position_requirements','id','bigint'),('position_requirements','position_id','bigint'),('position_requirements','requirement_type_id','bigint'),('position_requirements','severity','character varying(20)'),('position_requirements','resolution_due_date','date'),('position_requirements','status','character varying(20)'),('position_requirements','created_at','timestamp with time zone'),('position_requirements','updated_at','timestamp with time zone')
    ) expected(t,c,expected_type)
    LOOP
        SELECT format_type(a.atttypid,a.atttypmod) INTO actual_type
        FROM pg_attribute a WHERE a.attrelid=r.t::regclass AND a.attname=r.c AND NOT a.attisdropped;
        IF actual_type <> r.expected_type THEN
            EXECUTE format('SELECT count(*) FROM %I',r.t) INTO row_count;
            compatible := row_count=0 OR (actual_type='integer' AND r.expected_type='bigint');
            IF actual_type IN ('text','character varying')
               OR actual_type LIKE 'character varying(%'
               OR actual_type LIKE 'character(%' THEN
                IF r.expected_type LIKE 'character varying(%' OR r.expected_type LIKE 'character(%' THEN
                    EXECUTE format('SELECT max(length(%I::text)) FROM %I',r.c,r.t) INTO maximum_length;
                    compatible := coalesce(maximum_length,0) <=
                        substring(r.expected_type FROM '\(([0-9]+)\)')::integer;
                END IF;
            END IF;
            IF NOT compatible THEN
                RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: %.% has type %, expected %; conversion is not provably lossless',
                    r.t,r.c,actual_type,r.expected_type;
            END IF;
        END IF;
    END LOOP;

    FOR r IN SELECT * FROM (VALUES
        ('clients','id','bigint'),('clients','code','character varying(50)'),('clients','name','character varying(180)'),('clients','status','character varying(20)'),('clients','created_at','timestamp with time zone'),('clients','updated_at','timestamp with time zone'),
        ('service_projects','id','bigint'),('service_projects','client_id','bigint'),('service_projects','code','character varying(50)'),('service_projects','name','character varying(180)'),('service_projects','effective_from','date'),('service_projects','effective_to','date'),('service_projects','status','character varying(20)'),('service_projects','created_at','timestamp with time zone'),('service_projects','updated_at','timestamp with time zone'),
        ('service_positions','project_id','bigint'),
        ('shift_templates','id','bigint'),('shift_templates','code','character varying(30)'),('shift_templates','name','character varying(180)'),('shift_templates','version','integer'),('shift_templates','effective_from','date'),('shift_templates','effective_to','date'),('shift_templates','mandatory_by_default','boolean'),('shift_templates','status','character varying(20)'),('shift_templates','created_at','timestamp with time zone'),('shift_templates','updated_at','timestamp with time zone'),
        ('shift_template_steps','id','bigint'),('shift_template_steps','template_id','bigint'),('shift_template_steps','step_order','integer'),('shift_template_steps','shift_code','character(1)'),
        ('position_coverage_rules','id','bigint'),('position_coverage_rules','position_id','bigint'),('position_coverage_rules','template_id','bigint'),('position_coverage_rules','weekday_scope','character varying(80)'),('position_coverage_rules','starts_at','time without time zone'),('position_coverage_rules','ends_at','time without time zone'),('position_coverage_rules','required_quantity','integer'),('position_coverage_rules','effective_from','date'),('position_coverage_rules','effective_to','date'),('position_coverage_rules','status','character varying(20)'),('position_coverage_rules','created_at','timestamp with time zone'),('position_coverage_rules','updated_at','timestamp with time zone'),
        ('scheduling_rules','id','bigint'),('scheduling_rules','source_level','character varying(50)'),('scheduling_rules','scope_type','character varying(50)'),('scheduling_rules','scope_id','bigint'),('scheduling_rules','severity','character varying(30)'),('scheduling_rules','effective_from','date'),('scheduling_rules','effective_to','date'),('scheduling_rules','parameters','jsonb'),('scheduling_rules','status','character varying(20)'),('scheduling_rules','created_at','timestamp with time zone'),('scheduling_rules','updated_at','timestamp with time zone'),
        ('employee_availability_exceptions','id','bigint'),('employee_availability_exceptions','employee_id','bigint'),('employee_availability_exceptions','starts_at','timestamp with time zone'),('employee_availability_exceptions','ends_at','timestamp with time zone'),('employee_availability_exceptions','kind','character varying(50)'),('employee_availability_exceptions','blocking','boolean'),('employee_availability_exceptions','reason','character varying(500)'),('employee_availability_exceptions','created_by','character varying(80)'),('employee_availability_exceptions','status','character varying(20)'),('employee_availability_exceptions','created_at','timestamp with time zone'),('employee_availability_exceptions','updated_at','timestamp with time zone'),
        ('position_requirements','id','bigint'),('position_requirements','position_id','bigint'),('position_requirements','requirement_type_id','bigint'),('position_requirements','severity','character varying(20)'),('position_requirements','resolution_due_date','date'),('position_requirements','status','character varying(20)'),('position_requirements','created_at','timestamp with time zone'),('position_requirements','updated_at','timestamp with time zone')
    ) expected(t,c,expected_type)
    LOOP
        SELECT format_type(a.atttypid,a.atttypmod) INTO actual_type
        FROM pg_attribute a WHERE a.attrelid=r.t::regclass AND a.attname=r.c AND NOT a.attisdropped;
        IF actual_type <> r.expected_type THEN
            BEGIN
                EXECUTE format('ALTER TABLE %I ALTER COLUMN %I TYPE %s USING %I::%s',r.t,r.c,r.expected_type,r.c,r.expected_type);
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: %.% cannot be converted from % to %: %',
                    r.t,r.c,actual_type,r.expected_type,SQLERRM;
            END;
        END IF;
    END LOOP;

    FOR r IN SELECT * FROM (VALUES
        ('clients','id','bigint'),('clients','code','character varying(50)'),('clients','name','character varying(180)'),('clients','status','character varying(20)'),('clients','created_at','timestamp with time zone'),('clients','updated_at','timestamp with time zone'),
        ('service_projects','id','bigint'),('service_projects','client_id','bigint'),('service_projects','code','character varying(50)'),('service_projects','name','character varying(180)'),('service_projects','effective_from','date'),('service_projects','effective_to','date'),('service_projects','status','character varying(20)'),('service_projects','created_at','timestamp with time zone'),('service_projects','updated_at','timestamp with time zone'),
        ('service_positions','project_id','bigint'),
        ('shift_templates','id','bigint'),('shift_templates','code','character varying(30)'),('shift_templates','name','character varying(180)'),('shift_templates','version','integer'),('shift_templates','effective_from','date'),('shift_templates','effective_to','date'),('shift_templates','mandatory_by_default','boolean'),('shift_templates','status','character varying(20)'),('shift_templates','created_at','timestamp with time zone'),('shift_templates','updated_at','timestamp with time zone'),
        ('shift_template_steps','id','bigint'),('shift_template_steps','template_id','bigint'),('shift_template_steps','step_order','integer'),('shift_template_steps','shift_code','character(1)'),
        ('position_coverage_rules','id','bigint'),('position_coverage_rules','position_id','bigint'),('position_coverage_rules','template_id','bigint'),('position_coverage_rules','weekday_scope','character varying(80)'),('position_coverage_rules','starts_at','time without time zone'),('position_coverage_rules','ends_at','time without time zone'),('position_coverage_rules','required_quantity','integer'),('position_coverage_rules','effective_from','date'),('position_coverage_rules','effective_to','date'),('position_coverage_rules','status','character varying(20)'),('position_coverage_rules','created_at','timestamp with time zone'),('position_coverage_rules','updated_at','timestamp with time zone'),
        ('scheduling_rules','id','bigint'),('scheduling_rules','source_level','character varying(50)'),('scheduling_rules','scope_type','character varying(50)'),('scheduling_rules','scope_id','bigint'),('scheduling_rules','severity','character varying(30)'),('scheduling_rules','effective_from','date'),('scheduling_rules','effective_to','date'),('scheduling_rules','parameters','jsonb'),('scheduling_rules','status','character varying(20)'),('scheduling_rules','created_at','timestamp with time zone'),('scheduling_rules','updated_at','timestamp with time zone'),
        ('employee_availability_exceptions','id','bigint'),('employee_availability_exceptions','employee_id','bigint'),('employee_availability_exceptions','starts_at','timestamp with time zone'),('employee_availability_exceptions','ends_at','timestamp with time zone'),('employee_availability_exceptions','kind','character varying(50)'),('employee_availability_exceptions','blocking','boolean'),('employee_availability_exceptions','reason','character varying(500)'),('employee_availability_exceptions','created_by','character varying(80)'),('employee_availability_exceptions','status','character varying(20)'),('employee_availability_exceptions','created_at','timestamp with time zone'),('employee_availability_exceptions','updated_at','timestamp with time zone'),
        ('position_requirements','id','bigint'),('position_requirements','position_id','bigint'),('position_requirements','requirement_type_id','bigint'),('position_requirements','severity','character varying(20)'),('position_requirements','resolution_due_date','date'),('position_requirements','status','character varying(20)'),('position_requirements','created_at','timestamp with time zone'),('position_requirements','updated_at','timestamp with time zone')
    ) expected(t,c,expected_type)
    LOOP
        SELECT format_type(a.atttypid,a.atttypmod) INTO actual_type
        FROM pg_attribute a WHERE a.attrelid=r.t::regclass AND a.attname=r.c AND NOT a.attisdropped;
        IF actual_type <> r.expected_type THEN
            RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: %.% remains type %, expected %',r.t,r.c,actual_type,r.expected_type;
        END IF;
    END LOOP;
END $$;

DO $$
DECLARE
    table_name TEXT;
    sequence_name TEXT;
    qualified_sequence TEXT;
    sequence_kind "char";
    sequence_owner_table REGCLASS;
    sequence_owner_column SMALLINT;
    maximum_id BIGINT;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'clients', 'service_projects', 'shift_templates', 'shift_template_steps',
        'position_coverage_rules', 'scheduling_rules', 'employee_availability_exceptions',
        'position_requirements'
    ]
    LOOP
        sequence_name := pg_get_serial_sequence(format('%I.%I', current_schema(), table_name), 'id');
        IF sequence_name IS NULL THEN
            qualified_sequence := format('%I.%I', current_schema(), table_name || '_id_seq');
            SELECT c.relkind INTO sequence_kind
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname=current_schema() AND c.relname=table_name || '_id_seq';

            IF sequence_kind IS NULL THEN
                EXECUTE format('CREATE SEQUENCE %s AS BIGINT', qualified_sequence);
            ELSIF sequence_kind <> 'S' THEN
                RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: %.id requires sequence %, but that name belongs to a non-sequence object',
                    table_name, qualified_sequence;
            ELSE
                SELECT d.refobjid::regclass, d.refobjsubid
                  INTO sequence_owner_table, sequence_owner_column
                FROM pg_depend d
                WHERE d.classid='pg_class'::regclass
                  AND d.objid=qualified_sequence::regclass
                  AND d.refclassid='pg_class'::regclass
                  AND d.deptype='a';
                IF sequence_owner_table IS NOT NULL
                   AND (sequence_owner_table <> table_name::regclass
                        OR sequence_owner_column <> (SELECT attnum FROM pg_attribute WHERE attrelid=table_name::regclass AND attname='id')) THEN
                    RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: sequence % is owned by another column and cannot safely back %.id',
                        qualified_sequence, table_name;
                END IF;
            END IF;
            sequence_name := qualified_sequence;
        END IF;

        EXECUTE format('SELECT max(id) FROM %I', table_name) INTO maximum_id;
        IF maximum_id IS NULL THEN
            EXECUTE format('SELECT setval(%L::regclass, 1, false)', sequence_name);
        ELSE
            EXECUTE format('SELECT setval(%L::regclass, %s, true)', sequence_name, maximum_id);
        END IF;
        EXECUTE format('ALTER SEQUENCE %s OWNED BY %I.id', sequence_name, table_name);
        EXECUTE format('ALTER TABLE %I ALTER COLUMN id SET DEFAULT nextval(%L::regclass)', table_name, sequence_name);
    END LOOP;
END $$;

DO $$
DECLARE r RECORD; n BIGINT;
BEGIN
 FOR r IN SELECT * FROM (VALUES
  ('clients','id',NULL),('clients','code',NULL),('clients','name',NULL),('clients','status','ACTIVO'),('clients','created_at','NOW()'),('clients','updated_at','NOW()'),
  ('service_projects','id',NULL),('service_projects','client_id',NULL),('service_projects','code',NULL),('service_projects','name',NULL),('service_projects','effective_from',NULL),('service_projects','status','ACTIVO'),('service_projects','created_at','NOW()'),('service_projects','updated_at','NOW()'),
  ('shift_templates','id',NULL),('shift_templates','code',NULL),('shift_templates','name',NULL),('shift_templates','version',NULL),('shift_templates','effective_from',NULL),('shift_templates','mandatory_by_default','TRUE'),('shift_templates','status','ACTIVO'),('shift_templates','created_at','NOW()'),('shift_templates','updated_at','NOW()'),
  ('shift_template_steps','id',NULL),('shift_template_steps','template_id',NULL),('shift_template_steps','step_order',NULL),('shift_template_steps','shift_code',NULL),
  ('position_coverage_rules','id',NULL),('position_coverage_rules','position_id',NULL),('position_coverage_rules','template_id',NULL),('position_coverage_rules','weekday_scope',NULL),('position_coverage_rules','starts_at',NULL),('position_coverage_rules','ends_at',NULL),('position_coverage_rules','required_quantity',NULL),('position_coverage_rules','effective_from',NULL),('position_coverage_rules','status','ACTIVO'),('position_coverage_rules','created_at','NOW()'),('position_coverage_rules','updated_at','NOW()'),
  ('scheduling_rules','id',NULL),('scheduling_rules','source_level',NULL),('scheduling_rules','scope_type',NULL),('scheduling_rules','severity',NULL),('scheduling_rules','effective_from',NULL),('scheduling_rules','parameters','{}'),('scheduling_rules','status','ACTIVO'),('scheduling_rules','created_at','NOW()'),('scheduling_rules','updated_at','NOW()'),
  ('employee_availability_exceptions','id',NULL),('employee_availability_exceptions','employee_id',NULL),('employee_availability_exceptions','starts_at',NULL),('employee_availability_exceptions','ends_at',NULL),('employee_availability_exceptions','kind',NULL),('employee_availability_exceptions','blocking','TRUE'),('employee_availability_exceptions','reason',NULL),('employee_availability_exceptions','created_by',NULL),('employee_availability_exceptions','status','ACTIVO'),('employee_availability_exceptions','created_at','NOW()'),('employee_availability_exceptions','updated_at','NOW()'),
  ('position_requirements','id',NULL),('position_requirements','position_id',NULL),('position_requirements','requirement_type_id',NULL),('position_requirements','severity',NULL),('position_requirements','status','ACTIVO'),('position_requirements','created_at','NOW()'),('position_requirements','updated_at','NOW()')
 ) v(t,c,backfill)
 LOOP
  EXECUTE format('SELECT count(*) FROM %I WHERE %I IS NULL',r.t,r.c) INTO n;
  IF n > 0 AND r.backfill IS NULL THEN
   RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: %.% contains NULL values and has no safe deterministic backfill',r.t,r.c;
  ELSIF n > 0 THEN
   IF r.backfill='NOW()' THEN EXECUTE format('UPDATE %I SET %I=NOW() WHERE %I IS NULL',r.t,r.c,r.c);
   ELSIF r.c='parameters' THEN EXECUTE format('UPDATE %I SET %I=''{}''::jsonb WHERE %I IS NULL',r.t,r.c,r.c);
   ELSE EXECUTE format('UPDATE %I SET %I=%L WHERE %I IS NULL',r.t,r.c,r.backfill,r.c); END IF;
  END IF;
  EXECUTE format('ALTER TABLE %I ALTER COLUMN %I SET NOT NULL',r.t,r.c);
 END LOOP;
END $$;

ALTER TABLE clients ALTER status SET DEFAULT 'ACTIVO', ALTER created_at SET DEFAULT NOW(), ALTER updated_at SET DEFAULT NOW();
ALTER TABLE service_projects ALTER status SET DEFAULT 'ACTIVO', ALTER created_at SET DEFAULT NOW(), ALTER updated_at SET DEFAULT NOW();
ALTER TABLE shift_templates ALTER mandatory_by_default SET DEFAULT TRUE, ALTER status SET DEFAULT 'ACTIVO', ALTER created_at SET DEFAULT NOW(), ALTER updated_at SET DEFAULT NOW();
ALTER TABLE position_coverage_rules ALTER status SET DEFAULT 'ACTIVO', ALTER created_at SET DEFAULT NOW(), ALTER updated_at SET DEFAULT NOW();
ALTER TABLE scheduling_rules ALTER parameters SET DEFAULT '{}'::jsonb, ALTER status SET DEFAULT 'ACTIVO', ALTER created_at SET DEFAULT NOW(), ALTER updated_at SET DEFAULT NOW();
ALTER TABLE employee_availability_exceptions ALTER status SET DEFAULT 'ACTIVO', ALTER created_at SET DEFAULT NOW(), ALTER updated_at SET DEFAULT NOW();
ALTER TABLE employee_availability_exceptions ALTER blocking SET DEFAULT TRUE;
ALTER TABLE position_requirements ALTER status SET DEFAULT 'ACTIVO', ALTER created_at SET DEFAULT NOW(), ALTER updated_at SET DEFAULT NOW();

CREATE OR REPLACE FUNCTION pg_temp.i9_constraint(t regclass,n text,k "char",d text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text; actual_kind "char";
BEGIN
 SELECT contype,pg_get_constraintdef(oid) INTO actual_kind,actual FROM pg_constraint WHERE conrelid=t AND conname=n;
 IF actual IS NOT NULL AND (actual_kind<>k OR regexp_replace(lower(actual),'\s+','','g')<>regexp_replace(lower(d),'\s+','','g')) THEN
  BEGIN EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I',t,n); EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s',t,n,d);
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: constraint % on % is incompatible and existing data prevents safe replacement: %',n,t,SQLERRM; END;
 ELSIF actual IS NULL THEN
  BEGIN EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s',t,n,d);
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'I9_PARTIAL_SCHEMA_INCOMPATIBLE: cannot add constraint % on % because existing data is incompatible: %',n,t,SQLERRM; END;
 END IF;
END $$;

SELECT pg_temp.i9_constraint('clients','clients_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('clients','clients_code_key','u','UNIQUE (code)');
SELECT pg_temp.i9_constraint('clients','clients_status_check','c','CHECK ((status)::text = ANY ((ARRAY[''ACTIVO''::character varying, ''INACTIVO''::character varying])::text[]))');
SELECT pg_temp.i9_constraint('clients','ck_clients_code_not_blank','c','CHECK (length(btrim((code)::text)) > 0)');
SELECT pg_temp.i9_constraint('clients','ck_clients_name_not_blank','c','CHECK (length(btrim((name)::text)) > 0)');
SELECT pg_temp.i9_constraint('service_projects','service_projects_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('service_projects','service_projects_client_id_fkey','f','FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('service_projects','service_projects_code_key','u','UNIQUE (code)');
SELECT pg_temp.i9_constraint('service_projects','service_projects_status_check','c','CHECK ((status)::text = ANY ((ARRAY[''ACTIVO''::character varying, ''INACTIVO''::character varying])::text[]))');
SELECT pg_temp.i9_constraint('service_projects','ck_service_projects_code_not_blank','c','CHECK (length(btrim((code)::text)) > 0)');
SELECT pg_temp.i9_constraint('service_projects','ck_service_projects_name_not_blank','c','CHECK (length(btrim((name)::text)) > 0)');
SELECT pg_temp.i9_constraint('service_projects','ck_service_projects_dates','c','CHECK ((effective_to IS NULL) OR (effective_to >= effective_from))');
SELECT pg_temp.i9_constraint('service_positions','fk_service_positions_project','f','FOREIGN KEY (project_id) REFERENCES service_projects(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('shift_templates','shift_templates_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('shift_templates','uq_shift_templates_code_version','u','UNIQUE (code, version)');
SELECT pg_temp.i9_constraint('shift_templates','shift_templates_version_check','c','CHECK (version > 0)');
SELECT pg_temp.i9_constraint('shift_templates','shift_templates_status_check','c','CHECK ((status)::text = ANY ((ARRAY[''ACTIVO''::character varying, ''INACTIVO''::character varying])::text[]))');
SELECT pg_temp.i9_constraint('shift_templates','ck_shift_templates_code_not_blank','c','CHECK (length(btrim((code)::text)) > 0)');
SELECT pg_temp.i9_constraint('shift_templates','ck_shift_templates_name_not_blank','c','CHECK (length(btrim((name)::text)) > 0)');
SELECT pg_temp.i9_constraint('shift_templates','ck_shift_templates_dates','c','CHECK ((effective_to IS NULL) OR (effective_to >= effective_from))');
SELECT pg_temp.i9_constraint('shift_template_steps','shift_template_steps_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('shift_template_steps','shift_template_steps_template_id_fkey','f','FOREIGN KEY (template_id) REFERENCES shift_templates(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('shift_template_steps','uq_shift_template_steps_order','u','UNIQUE (template_id, step_order)');
SELECT pg_temp.i9_constraint('shift_template_steps','shift_template_steps_step_order_check','c','CHECK (step_order > 0)');
SELECT pg_temp.i9_constraint('shift_template_steps','shift_template_steps_shift_code_check','c','CHECK (shift_code = ANY (ARRAY[''D''::bpchar, ''N''::bpchar, ''X''::bpchar]))');
SELECT pg_temp.i9_constraint('position_coverage_rules','position_coverage_rules_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('position_coverage_rules','position_coverage_rules_position_id_fkey','f','FOREIGN KEY (position_id) REFERENCES service_positions(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('position_coverage_rules','position_coverage_rules_template_id_fkey','f','FOREIGN KEY (template_id) REFERENCES shift_templates(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('position_coverage_rules','ck_position_coverage_rules_weekday_scope','c','CHECK (length(btrim((weekday_scope)::text)) > 0)');
SELECT pg_temp.i9_constraint('position_coverage_rules','ck_position_coverage_rules_time_range','c','CHECK (ends_at <> starts_at)');
SELECT pg_temp.i9_constraint('position_coverage_rules','position_coverage_rules_required_quantity_check','c','CHECK (required_quantity > 0)');
SELECT pg_temp.i9_constraint('position_coverage_rules','ck_position_coverage_rules_dates','c','CHECK ((effective_to IS NULL) OR (effective_to >= effective_from))');
SELECT pg_temp.i9_constraint('position_coverage_rules','uq_position_coverage_rules_period','u','UNIQUE (position_id, template_id, effective_from)');
SELECT pg_temp.i9_constraint('position_coverage_rules','position_coverage_rules_status_check','c','CHECK ((status)::text = ANY ((ARRAY[''ACTIVO''::character varying, ''INACTIVO''::character varying])::text[]))');
SELECT pg_temp.i9_constraint('scheduling_rules','scheduling_rules_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('scheduling_rules','scheduling_rules_status_check','c','CHECK ((status)::text = ANY ((ARRAY[''ACTIVO''::character varying, ''INACTIVO''::character varying])::text[]))');
SELECT pg_temp.i9_constraint('scheduling_rules','ck_scheduling_rules_source_not_blank','c','CHECK (length(btrim((source_level)::text)) > 0)');
SELECT pg_temp.i9_constraint('scheduling_rules','ck_scheduling_rules_scope_not_blank','c','CHECK (length(btrim((scope_type)::text)) > 0)');
SELECT pg_temp.i9_constraint('scheduling_rules','ck_scheduling_rules_severity_not_blank','c','CHECK (length(btrim((severity)::text)) > 0)');
SELECT pg_temp.i9_constraint('scheduling_rules','ck_scheduling_rules_dates','c','CHECK ((effective_to IS NULL) OR (effective_to >= effective_from))');
SELECT pg_temp.i9_constraint('scheduling_rules','ck_scheduling_rules_parameters_object','c','CHECK (jsonb_typeof(parameters) = ''object''::text)');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','employee_availability_exceptions_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','employee_availability_exceptions_employee_id_fkey','f','FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','employee_availability_exceptions_status_check','c','CHECK ((status)::text = ANY ((ARRAY[''ACTIVO''::character varying, ''INACTIVO''::character varying])::text[]))');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','ck_employee_availability_exception_range','c','CHECK (ends_at > starts_at)');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','ck_employee_availability_exception_kind','c','CHECK (length(btrim((kind)::text)) > 0)');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','ck_employee_availability_exception_reason','c','CHECK (length(btrim((reason)::text)) > 0)');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','ck_employee_availability_exception_created_by','c','CHECK (length(btrim((created_by)::text)) > 0)');
SELECT pg_temp.i9_constraint('position_requirements','position_requirements_pkey','p','PRIMARY KEY (id)');
SELECT pg_temp.i9_constraint('position_requirements','position_requirements_position_id_fkey','f','FOREIGN KEY (position_id) REFERENCES service_positions(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('position_requirements','position_requirements_requirement_type_id_fkey','f','FOREIGN KEY (requirement_type_id) REFERENCES training_requirement_types(id) ON DELETE RESTRICT');
SELECT pg_temp.i9_constraint('position_requirements','uq_position_requirements_position_type','u','UNIQUE (position_id, requirement_type_id)');
SELECT pg_temp.i9_constraint('position_requirements','position_requirements_severity_check','c','CHECK ((severity)::text = ANY ((ARRAY[''BLOQUEANTE''::character varying, ''SUBSANABLE''::character varying, ''INFORMATIVA''::character varying])::text[]))');
SELECT pg_temp.i9_constraint('position_requirements','position_requirements_status_check','c','CHECK ((status)::text = ANY ((ARRAY[''ACTIVO''::character varying, ''INACTIVO''::character varying])::text[]))');

CREATE INDEX IF NOT EXISTS idx_service_projects_client_status ON service_projects(client_id,status);
CREATE INDEX IF NOT EXISTS idx_service_positions_project ON service_positions(project_id);
CREATE INDEX IF NOT EXISTS idx_shift_templates_status_dates ON shift_templates(status,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS idx_position_coverage_rules_position_dates ON position_coverage_rules(position_id,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS idx_scheduling_rules_scope_dates ON scheduling_rules(scope_type,scope_id,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS idx_employee_availability_employee_dates ON employee_availability_exceptions(employee_id,starts_at,ends_at);
CREATE INDEX IF NOT EXISTS idx_position_requirements_position_status ON position_requirements(position_id,status);
COMMIT;

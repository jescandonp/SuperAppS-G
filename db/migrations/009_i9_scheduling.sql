\set ON_ERROR_STOP on
BEGIN;

CREATE TABLE IF NOT EXISTS clients ();
CREATE TABLE IF NOT EXISTS service_projects ();
CREATE TABLE IF NOT EXISTS shift_templates ();
CREATE TABLE IF NOT EXISTS shift_template_steps ();
CREATE TABLE IF NOT EXISTS position_coverage_rules ();
CREATE TABLE IF NOT EXISTS scheduling_rules ();
CREATE TABLE IF NOT EXISTS employee_availability_exceptions ();

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
 ADD COLUMN IF NOT EXISTS code VARCHAR(50),
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
 ADD COLUMN IF NOT EXISTS reason VARCHAR(500),
 ADD COLUMN IF NOT EXISTS created_by VARCHAR(80),
 ADD COLUMN IF NOT EXISTS status VARCHAR(20),
 ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
 ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

DO $$
DECLARE r RECORD; n BIGINT;
BEGIN
 FOR r IN SELECT * FROM (VALUES
  ('clients','id',NULL),('clients','code',NULL),('clients','name',NULL),('clients','status','ACTIVO'),('clients','created_at','NOW()'),('clients','updated_at','NOW()'),
  ('service_projects','id',NULL),('service_projects','client_id',NULL),('service_projects','code',NULL),('service_projects','name',NULL),('service_projects','effective_from',NULL),('service_projects','status','ACTIVO'),('service_projects','created_at','NOW()'),('service_projects','updated_at','NOW()'),
  ('shift_templates','id',NULL),('shift_templates','code',NULL),('shift_templates','name',NULL),('shift_templates','version',NULL),('shift_templates','effective_from',NULL),('shift_templates','mandatory_by_default','TRUE'),('shift_templates','status','ACTIVO'),('shift_templates','created_at','NOW()'),('shift_templates','updated_at','NOW()'),
  ('shift_template_steps','id',NULL),('shift_template_steps','template_id',NULL),('shift_template_steps','step_order',NULL),('shift_template_steps','shift_code',NULL),
  ('position_coverage_rules','id',NULL),('position_coverage_rules','position_id',NULL),('position_coverage_rules','template_id',NULL),('position_coverage_rules','required_quantity',NULL),('position_coverage_rules','effective_from',NULL),('position_coverage_rules','status','ACTIVO'),('position_coverage_rules','created_at','NOW()'),('position_coverage_rules','updated_at','NOW()'),
  ('scheduling_rules','id',NULL),('scheduling_rules','source_level',NULL),('scheduling_rules','scope_type',NULL),('scheduling_rules','severity',NULL),('scheduling_rules','effective_from',NULL),('scheduling_rules','parameters','{}'),('scheduling_rules','status','ACTIVO'),('scheduling_rules','created_at','NOW()'),('scheduling_rules','updated_at','NOW()'),
  ('employee_availability_exceptions','id',NULL),('employee_availability_exceptions','employee_id',NULL),('employee_availability_exceptions','starts_at',NULL),('employee_availability_exceptions','ends_at',NULL),('employee_availability_exceptions','reason',NULL),('employee_availability_exceptions','created_by',NULL),('employee_availability_exceptions','status','ACTIVO'),('employee_availability_exceptions','created_at','NOW()'),('employee_availability_exceptions','updated_at','NOW()')
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
SELECT pg_temp.i9_constraint('employee_availability_exceptions','ck_employee_availability_exception_reason','c','CHECK (length(btrim((reason)::text)) > 0)');
SELECT pg_temp.i9_constraint('employee_availability_exceptions','ck_employee_availability_exception_created_by','c','CHECK (length(btrim((created_by)::text)) > 0)');

CREATE INDEX IF NOT EXISTS idx_service_projects_client_status ON service_projects(client_id,status);
CREATE INDEX IF NOT EXISTS idx_service_positions_project ON service_positions(project_id);
CREATE INDEX IF NOT EXISTS idx_shift_templates_status_dates ON shift_templates(status,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS idx_position_coverage_rules_position_dates ON position_coverage_rules(position_id,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS idx_scheduling_rules_scope_dates ON scheduling_rules(scope_type,scope_id,effective_from,effective_to);
CREATE INDEX IF NOT EXISTS idx_employee_availability_employee_dates ON employee_availability_exceptions(employee_id,starts_at,ends_at);
COMMIT;

\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS service_positions (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(50),
    name            VARCHAR(180) NOT NULL,
    client_text     VARCHAR(180),
    location_text   VARCHAR(180),
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_service_positions_name_not_blank CHECK (length(btrim(name)) > 0),
    CONSTRAINT ck_service_positions_code_not_blank CHECK (code IS NULL OR length(btrim(code)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_service_positions_code
    ON service_positions (code)
    WHERE code IS NOT NULL;

CREATE TABLE IF NOT EXISTS employee_position_assignments (
    id                  BIGSERIAL PRIMARY KEY,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    position_id         BIGINT NOT NULL REFERENCES service_positions(id) ON DELETE RESTRICT,
    start_date          DATE NOT NULL,
    end_date            DATE,
    status              VARCHAR(20) NOT NULL DEFAULT 'VIGENTE' CHECK (status IN ('VIGENTE', 'FINALIZADA')),
    change_reason       VARCHAR(180),
    notes               TEXT,
    created_by          VARCHAR(80),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_employee_position_assignment_range CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT ck_employee_position_assignment_finalized CHECK (
        (status = 'VIGENTE' AND end_date IS NULL)
        OR (status = 'FINALIZADA' AND end_date IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_employee_position_assignments_active_employee
    ON employee_position_assignments (employee_id)
    WHERE status = 'VIGENTE';

CREATE INDEX IF NOT EXISTS idx_service_positions_status_name
    ON service_positions (status, name);

CREATE INDEX IF NOT EXISTS idx_employee_position_assignments_position
    ON employee_position_assignments (position_id, status, start_date DESC);

CREATE INDEX IF NOT EXISTS idx_employee_position_assignments_employee
    ON employee_position_assignments (employee_id, start_date DESC);

CREATE OR REPLACE FUNCTION enforce_active_service_position_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    target_status TEXT;
BEGIN
    IF NEW.status = 'VIGENTE' THEN
        SELECT status
        INTO target_status
        FROM service_positions
        WHERE id = NEW.position_id;

        IF target_status IS DISTINCT FROM 'ACTIVO' THEN
            RAISE EXCEPTION 'Cannot assign employee to inactive service position'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_employee_position_assignments_active_position ON employee_position_assignments;

CREATE TRIGGER trg_employee_position_assignments_active_position
BEFORE INSERT OR UPDATE OF position_id, status
ON employee_position_assignments
FOR EACH ROW
EXECUTE FUNCTION enforce_active_service_position_assignment();

COMMIT;

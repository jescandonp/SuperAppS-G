\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE IF NOT EXISTS certificate_signers (
    id              BIGSERIAL PRIMARY KEY,
    full_name       VARCHAR(180) NOT NULL,
    job_title       VARCHAR(120) NOT NULL,
    signature_path  VARCHAR(260),
    valid_from      DATE NOT NULL,
    valid_to        DATE,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVO' CHECK (status IN ('ACTIVO', 'INACTIVO')),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_certificate_signers_full_name_not_blank CHECK (length(btrim(full_name)) > 0),
    CONSTRAINT ck_certificate_signers_job_title_not_blank CHECK (length(btrim(job_title)) > 0),
    CONSTRAINT ck_certificate_signers_valid_range CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE INDEX IF NOT EXISTS idx_certificate_signers_status_validity
    ON certificate_signers (status, valid_from DESC, valid_to);

CREATE TABLE IF NOT EXISTS labor_certificates (
    id                  BIGSERIAL PRIMARY KEY,
    certificate_number  VARCHAR(40) NOT NULL UNIQUE,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    signer_id           BIGINT REFERENCES certificate_signers(id) ON DELETE SET NULL,
    certificate_type    VARCHAR(20) NOT NULL CHECK (certificate_type IN ('ACTIVO', 'RETIRADO')),
    purpose             VARCHAR(40) NOT NULL CHECK (purpose IN ('ENTIDAD_FINANCIERA', 'CESANTIAS', 'CLIENTE', 'TRAMITE_GENERAL', 'INTERESADO')),
    status              VARCHAR(20) NOT NULL DEFAULT 'BORRADOR' CHECK (status IN ('BORRADOR', 'PREVISUALIZADA', 'APROBADA', 'GENERADA', 'ANULADA')),
    snapshot_payload    JSONB NOT NULL DEFAULT '{}'::jsonb,
    preview_content     TEXT,
    pdf_path            VARCHAR(500),
    template_version    VARCHAR(40) NOT NULL DEFAULT 'I4-MVP-1',
    annulment_reason    VARCHAR(240),
    created_by          VARCHAR(80) NOT NULL,
    approved_by         VARCHAR(80),
    approved_at         TIMESTAMPTZ,
    generated_at        TIMESTAMPTZ,
    annulled_by         VARCHAR(80),
    annulled_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_labor_certificates_number_not_blank CHECK (length(btrim(certificate_number)) > 0),
    CONSTRAINT ck_labor_certificates_snapshot_object CHECK (jsonb_typeof(snapshot_payload) = 'object'),
    CONSTRAINT ck_labor_certificates_generated_pdf CHECK (
        status <> 'GENERADA'
        OR (pdf_path IS NOT NULL AND generated_at IS NOT NULL)
    ),
    CONSTRAINT ck_labor_certificates_annulment CHECK (
        status <> 'ANULADA'
        OR (annulment_reason IS NOT NULL AND length(btrim(annulment_reason)) > 0 AND annulled_at IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS labor_certificate_variables (
    id                  BIGSERIAL PRIMARY KEY,
    certificate_id      BIGINT NOT NULL REFERENCES labor_certificates(id) ON DELETE CASCADE,
    concept_code        VARCHAR(50) NOT NULL,
    concept_label       VARCHAR(120) NOT NULL,
    amount              NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_labor_certificate_variables_code_not_blank CHECK (length(btrim(concept_code)) > 0),
    CONSTRAINT ck_labor_certificate_variables_label_not_blank CHECK (length(btrim(concept_label)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_labor_certificates_employee
    ON labor_certificates (employee_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_labor_certificates_status_type
    ON labor_certificates (status, certificate_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_labor_certificates_signer
    ON labor_certificates (signer_id);

CREATE INDEX IF NOT EXISTS idx_labor_certificate_variables_certificate
    ON labor_certificate_variables (certificate_id);

COMMIT;

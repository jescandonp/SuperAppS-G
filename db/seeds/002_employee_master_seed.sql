\set ON_ERROR_STOP on

BEGIN;

INSERT INTO employees (
    identification_type,
    identification_number,
    full_name,
    employment_status,
    job_title,
    hire_date,
    termination_date,
    termination_reason,
    contract_type,
    current_service_position_text,
    notes,
    record_status,
    source
)
VALUES
    ('CC', '1012345678', 'Laura Marcela Torres', 'ACTIVO', 'Guarda de Seguridad', DATE '2024-02-01', NULL, NULL, 'Termino fijo', 'Puesto Norte 1', 'Registro inicial para I2.', 'ACTIVO', 'SEED'),
    ('CC', '1023456789', 'Carlos Andres Mejia', 'ACTIVO', 'Supervisor de Zona', DATE '2023-09-15', NULL, NULL, 'Indefinido', 'Puesto Central', 'Pendiente normalizacion de cargo.', 'ACTIVO', 'SEED'),
    ('CC', '1034567890', 'Sandra Milena Ruiz', 'RETIRADO', 'Auxiliar TH', DATE '2022-05-10', DATE '2025-12-20', 'Renuncia', 'Indefinido', NULL, 'Ejemplo de retirado para filtros I2.', 'INACTIVO', 'SEED')
ON CONFLICT (identification_number) DO UPDATE
SET
    full_name = EXCLUDED.full_name,
    employment_status = EXCLUDED.employment_status,
    job_title = EXCLUDED.job_title,
    hire_date = EXCLUDED.hire_date,
    termination_date = EXCLUDED.termination_date,
    termination_reason = EXCLUDED.termination_reason,
    contract_type = EXCLUDED.contract_type,
    current_service_position_text = EXCLUDED.current_service_position_text,
    notes = EXCLUDED.notes,
    record_status = EXCLUDED.record_status,
    source = EXCLUDED.source,
    updated_at = NOW();

WITH employee_map AS (
    SELECT id, identification_number
    FROM employees
    WHERE identification_number IN ('1012345678', '1023456789', '1034567890')
)
INSERT INTO employee_salary_history (employee_id, base_salary_amount, effective_from, effective_to, source, notes)
SELECT em.id, s.base_salary_amount, s.effective_from, s.effective_to, s.source, s.notes
FROM employee_map em
JOIN (
    VALUES
        ('1012345678', 1850000.00::numeric, DATE '2026-01-01', NULL::date, 'SEED', 'Salario vigente I2'),
        ('1023456789', 2450000.00::numeric, DATE '2026-01-01', NULL::date, 'SEED', 'Salario vigente I2'),
        ('1034567890', 2100000.00::numeric, DATE '2025-01-01', DATE '2025-12-20', 'SEED', 'Ultimo salario antes de retiro')
) AS s(identification_number, base_salary_amount, effective_from, effective_to, source, notes)
    ON s.identification_number = em.identification_number
WHERE NOT EXISTS (
    SELECT 1
    FROM employee_salary_history esh
    WHERE esh.employee_id = em.id
      AND esh.effective_from = s.effective_from
      AND COALESCE(esh.effective_to, DATE '2999-12-31') = COALESCE(s.effective_to, DATE '2999-12-31')
);

COMMIT;

\set ON_ERROR_STOP on

BEGIN;

INSERT INTO shift_templates (
    code, name, version, effective_from, mandatory_by_default, status
)
VALUES
    ('2X2', 'Ciclo 2x2 dia, noche y descanso', 1, CURRENT_DATE, TRUE, 'ACTIVO'),
    ('4X2', 'Ciclo 4x2 dia, noche y descanso', 1, CURRENT_DATE, TRUE, 'ACTIVO'),
    ('6X1', 'Ciclo 6x1 dia y descanso', 1, CURRENT_DATE, TRUE, 'ACTIVO')
ON CONFLICT (code, version) DO UPDATE
SET name = EXCLUDED.name,
    mandatory_by_default = EXCLUDED.mandatory_by_default,
    status = EXCLUDED.status,
    updated_at = NOW();

WITH template_steps(code, version, step_order, shift_code) AS (
    VALUES
        ('2X2', 1, 1, 'D'), ('2X2', 1, 2, 'D'),
        ('2X2', 1, 3, 'N'), ('2X2', 1, 4, 'N'),
        ('2X2', 1, 5, 'X'), ('2X2', 1, 6, 'X'),
        ('4X2', 1, 1, 'D'), ('4X2', 1, 2, 'D'),
        ('4X2', 1, 3, 'D'), ('4X2', 1, 4, 'D'),
        ('4X2', 1, 5, 'N'), ('4X2', 1, 6, 'N'),
        ('4X2', 1, 7, 'X'), ('4X2', 1, 8, 'X'),
        ('6X1', 1, 1, 'D'), ('6X1', 1, 2, 'D'),
        ('6X1', 1, 3, 'D'), ('6X1', 1, 4, 'D'),
        ('6X1', 1, 5, 'D'), ('6X1', 1, 6, 'D'),
        ('6X1', 1, 7, 'X')
)
INSERT INTO shift_template_steps (template_id, step_order, shift_code)
SELECT st.id, ts.step_order, ts.shift_code
FROM template_steps ts
JOIN shift_templates st ON st.code = ts.code AND st.version = ts.version
ON CONFLICT (template_id, step_order) DO UPDATE
SET shift_code = EXCLUDED.shift_code;

WITH expected_steps(code, version, step_order) AS (
    VALUES
        ('2X2', 1, 1), ('2X2', 1, 2), ('2X2', 1, 3), ('2X2', 1, 4), ('2X2', 1, 5), ('2X2', 1, 6),
        ('4X2', 1, 1), ('4X2', 1, 2), ('4X2', 1, 3), ('4X2', 1, 4), ('4X2', 1, 5), ('4X2', 1, 6), ('4X2', 1, 7), ('4X2', 1, 8),
        ('6X1', 1, 1), ('6X1', 1, 2), ('6X1', 1, 3), ('6X1', 1, 4), ('6X1', 1, 5), ('6X1', 1, 6), ('6X1', 1, 7)
)
DELETE FROM shift_template_steps sts
USING shift_templates st
WHERE sts.template_id = st.id
  AND (st.code, st.version) IN (('2X2', 1), ('4X2', 1), ('6X1', 1))
  AND NOT EXISTS (
      SELECT 1
      FROM expected_steps es
      WHERE es.code = st.code
        AND es.version = st.version
        AND es.step_order = sts.step_order
  );

COMMIT;

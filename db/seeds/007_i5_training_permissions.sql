\set ON_ERROR_STOP on

BEGIN;

WITH permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'TRAINING', 'VIEW'),
            ('ADMIN', 'TRAINING_TYPES', 'VIEW'),
            ('ADMIN', 'TRAINING_TYPES', 'MANAGE'),
            ('ADMIN', 'TRAINING_RECORDS', 'VIEW'),
            ('ADMIN', 'TRAINING_RECORDS', 'MANAGE'),
            ('ADMIN', 'TRAINING_SERVICE_ENABLEMENT', 'VIEW'),
            ('TH', 'TRAINING', 'VIEW'),
            ('TH', 'TRAINING_TYPES', 'VIEW'),
            ('TH', 'TRAINING_TYPES', 'MANAGE'),
            ('TH', 'TRAINING_RECORDS', 'VIEW'),
            ('TH', 'TRAINING_RECORDS', 'MANAGE'),
            ('TH', 'TRAINING_SERVICE_ENABLEMENT', 'VIEW'),
            ('GERENCIA', 'TRAINING', 'VIEW'),
            ('GERENCIA', 'TRAINING_TYPES', 'VIEW'),
            ('GERENCIA', 'TRAINING_RECORDS', 'VIEW'),
            ('GERENCIA', 'TRAINING_SERVICE_ENABLEMENT', 'VIEW'),
            ('OPERACIONES', 'TRAINING', 'VIEW'),
            ('OPERACIONES', 'TRAINING_TYPES', 'VIEW'),
            ('OPERACIONES', 'TRAINING_RECORDS', 'VIEW'),
            ('OPERACIONES', 'TRAINING_SERVICE_ENABLEMENT', 'VIEW')
    ) AS t(role_code, module_code, action_code)
)
INSERT INTO role_permissions (role_id, module_code, action_code, allowed)
SELECT r.id, pm.module_code, pm.action_code, TRUE
FROM permission_matrix pm
JOIN roles r ON r.code = pm.role_code
ON CONFLICT (role_id, module_code, action_code) DO UPDATE
SET allowed = EXCLUDED.allowed;

COMMIT;

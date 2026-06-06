\set ON_ERROR_STOP on

BEGIN;

WITH permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'POSITIONS', 'VIEW'),
            ('ADMIN', 'POSITIONS', 'MANAGE'),
            ('ADMIN', 'POSITION_ASSIGNMENTS', 'VIEW'),
            ('ADMIN', 'POSITION_ASSIGNMENTS', 'MANAGE'),
            ('TH', 'POSITIONS', 'VIEW'),
            ('TH', 'POSITIONS', 'MANAGE'),
            ('TH', 'POSITION_ASSIGNMENTS', 'VIEW'),
            ('TH', 'POSITION_ASSIGNMENTS', 'MANAGE'),
            ('GERENCIA', 'POSITIONS', 'VIEW'),
            ('GERENCIA', 'POSITION_ASSIGNMENTS', 'VIEW'),
            ('OPERACIONES', 'POSITIONS', 'VIEW'),
            ('OPERACIONES', 'POSITION_ASSIGNMENTS', 'VIEW')
    ) AS t(role_code, module_code, action_code)
)
INSERT INTO role_permissions (role_id, module_code, action_code, allowed)
SELECT r.id, pm.module_code, pm.action_code, TRUE
FROM permission_matrix pm
JOIN roles r ON r.code = pm.role_code
ON CONFLICT (role_id, module_code, action_code) DO UPDATE
SET allowed = EXCLUDED.allowed;

COMMIT;

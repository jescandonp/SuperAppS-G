\set ON_ERROR_STOP on

BEGIN;

WITH permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'VIEW'),
            ('ADMIN', 'CONFIGURE'),
            ('ADMIN', 'GENERATE'),
            ('ADMIN', 'APPROVE_EXCEPTION'),
            ('ADMIN', 'APPROVE'),
            ('ADMIN', 'PUBLISH'),
            ('ADMIN', 'EXPORT'),
            ('ADMIN', 'AUDIT'),
            ('OPERACIONES', 'VIEW'),
            ('OPERACIONES', 'GENERATE'),
            ('OPERACIONES', 'APPROVE_EXCEPTION'),
            ('OPERACIONES', 'APPROVE'),
            ('OPERACIONES', 'PUBLISH'),
            ('OPERACIONES', 'EXPORT'),
            ('OPERACIONES', 'AUDIT'),
            ('TH', 'VIEW'),
            ('TH', 'APPROVE_EXCEPTION'),
            ('GERENCIA', 'VIEW'),
            ('GERENCIA', 'EXPORT')
    ) AS t(role_code, action_code)
)
INSERT INTO role_permissions (role_id, module_code, action_code, allowed)
SELECT r.id, 'SCHEDULING', pm.action_code, TRUE
FROM permission_matrix pm
JOIN roles r ON r.code = pm.role_code
ON CONFLICT (role_id, module_code, action_code) DO UPDATE
SET allowed = EXCLUDED.allowed;

COMMIT;

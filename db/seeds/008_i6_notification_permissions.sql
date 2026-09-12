\set ON_ERROR_STOP on

BEGIN;

WITH permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'NOTIFICATIONS', 'VIEW'),
            ('ADMIN', 'NOTIFICATIONS', 'MANAGE'),
            ('ADMIN', 'NOTIFICATIONS', 'GENERATE_ALERTS'),
            ('ADMIN', 'NOTIFICATIONS', 'EXPORT'),
            ('ADMIN', 'NOTIFICATIONS', 'CONFIGURE_EMAIL'),
            ('ADMIN', 'ALERTS', 'VIEW'),
            ('ADMIN', 'ALERTS', 'MANAGE'),
            ('TH', 'NOTIFICATIONS', 'VIEW'),
            ('TH', 'NOTIFICATIONS', 'MANAGE'),
            ('TH', 'NOTIFICATIONS', 'GENERATE_ALERTS'),
            ('TH', 'NOTIFICATIONS', 'EXPORT'),
            ('TH', 'NOTIFICATIONS', 'CONFIGURE_EMAIL'),
            ('TH', 'ALERTS', 'VIEW'),
            ('TH', 'ALERTS', 'MANAGE'),
            ('GERENCIA', 'NOTIFICATIONS', 'VIEW'),
            ('GERENCIA', 'NOTIFICATIONS', 'MANAGE'),
            ('GERENCIA', 'NOTIFICATIONS', 'EXPORT'),
            ('GERENCIA', 'ALERTS', 'VIEW'),
            ('OPERACIONES', 'NOTIFICATIONS', 'VIEW'),
            ('OPERACIONES', 'NOTIFICATIONS', 'MANAGE'),
            ('OPERACIONES', 'NOTIFICATIONS', 'EXPORT'),
            ('OPERACIONES', 'ALERTS', 'VIEW')
    ) AS t(role_code, module_code, action_code)
)
INSERT INTO role_permissions (role_id, module_code, action_code, allowed)
SELECT r.id, pm.module_code, pm.action_code, TRUE
FROM permission_matrix pm
JOIN roles r ON r.code = pm.role_code
ON CONFLICT (role_id, module_code, action_code) DO UPDATE
SET allowed = EXCLUDED.allowed;

COMMIT;

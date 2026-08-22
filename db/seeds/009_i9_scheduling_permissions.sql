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
            ('ADMIN', 'VALIDATE_REQUIREMENT'),
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
            ('TH', 'VALIDATE_REQUIREMENT'),
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

WITH permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'VIEW'), ('ADMIN', 'CONFIGURE'), ('ADMIN', 'GENERATE'),
            ('ADMIN', 'APPROVE_EXCEPTION'), ('ADMIN', 'VALIDATE_REQUIREMENT'), ('ADMIN', 'APPROVE'), ('ADMIN', 'PUBLISH'),
            ('ADMIN', 'EXPORT'), ('ADMIN', 'AUDIT'),
            ('OPERACIONES', 'VIEW'), ('OPERACIONES', 'GENERATE'),
            ('OPERACIONES', 'APPROVE_EXCEPTION'), ('OPERACIONES', 'APPROVE'),
            ('OPERACIONES', 'PUBLISH'), ('OPERACIONES', 'EXPORT'), ('OPERACIONES', 'AUDIT'),
            ('TH', 'VIEW'), ('TH', 'VALIDATE_REQUIREMENT'),
            ('GERENCIA', 'VIEW'), ('GERENCIA', 'EXPORT')
    ) AS t(role_code, action_code)
)
DELETE FROM role_permissions rp
USING roles r
WHERE rp.role_id = r.id
  AND rp.module_code = 'SCHEDULING'
  AND r.code IN ('ADMIN', 'OPERACIONES', 'TH', 'GERENCIA')
  AND NOT EXISTS (
      SELECT 1
      FROM permission_matrix pm
      WHERE pm.role_code = r.code
        AND pm.action_code = rp.action_code
  );

COMMIT;

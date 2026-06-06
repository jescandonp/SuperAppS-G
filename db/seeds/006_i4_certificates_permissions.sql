\set ON_ERROR_STOP on

BEGIN;

WITH permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'CERTIFICATES', 'VIEW'),
            ('ADMIN', 'CERTIFICATES', 'DOWNLOAD'),
            ('ADMIN', 'CERTIFICATES', 'ANNUL'),
            ('ADMIN', 'CERTIFICATE_SIGNERS', 'VIEW'),
            ('ADMIN', 'CERTIFICATE_SIGNERS', 'MANAGE'),
            ('TH', 'CERTIFICATES', 'VIEW'),
            ('TH', 'CERTIFICATES', 'CREATE'),
            ('TH', 'CERTIFICATES', 'PREVIEW'),
            ('TH', 'CERTIFICATES', 'GENERATE'),
            ('TH', 'CERTIFICATES', 'DOWNLOAD'),
            ('TH', 'CERTIFICATES', 'ANNUL'),
            ('TH', 'CERTIFICATE_SIGNERS', 'VIEW'),
            ('GERENCIA', 'CERTIFICATES', 'VIEW'),
            ('GERENCIA', 'CERTIFICATES', 'DOWNLOAD'),
            ('GERENCIA', 'CERTIFICATE_SIGNERS', 'VIEW')
    ) AS t(role_code, module_code, action_code)
)
INSERT INTO role_permissions (role_id, module_code, action_code, allowed)
SELECT r.id, pm.module_code, pm.action_code, TRUE
FROM permission_matrix pm
JOIN roles r ON r.code = pm.role_code
ON CONFLICT (role_id, module_code, action_code) DO UPDATE
SET allowed = EXCLUDED.allowed;

COMMIT;

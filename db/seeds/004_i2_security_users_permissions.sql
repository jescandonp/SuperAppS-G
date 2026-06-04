\set ON_ERROR_STOP on

BEGIN;

INSERT INTO app_users (full_name, username, password_hash, email, is_active)
VALUES
    ('Talento Humano S&G', 'th.sg', crypt('Th123456', gen_salt('bf')), 'th@sg.local', TRUE),
    ('Gerencia S&G', 'gerencia.sg', crypt('Gerencia123', gen_salt('bf')), 'gerencia@sg.local', TRUE),
    ('Operaciones S&G', 'operaciones.sg', crypt('Operaciones123', gen_salt('bf')), 'operaciones@sg.local', TRUE)
ON CONFLICT (username) DO UPDATE
SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM (
    VALUES
        ('th.sg', 'TH'),
        ('gerencia.sg', 'GERENCIA'),
        ('operaciones.sg', 'OPERACIONES')
) assignments(username, role_code)
JOIN app_users u ON u.username = assignments.username
JOIN roles r ON r.code = assignments.role_code
ON CONFLICT (user_id, role_id) DO NOTHING;

WITH permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'EMPLOYEES', 'VIEW'),
            ('ADMIN', 'EMPLOYEES', 'VIEW_SALARY'),
            ('ADMIN', 'IMPORTS', 'VIEW'),
            ('ADMIN', 'IMPORTS', 'VIEW_ERRORS'),
            ('TH', 'EMPLOYEES', 'VIEW'),
            ('TH', 'EMPLOYEES', 'VIEW_SALARY'),
            ('TH', 'EMPLOYEES', 'EDIT'),
            ('TH', 'IMPORTS', 'VIEW'),
            ('TH', 'IMPORTS', 'VIEW_ERRORS'),
            ('TH', 'IMPORTS', 'PREVALIDATE'),
            ('TH', 'IMPORTS', 'MANAGE'),
            ('GERENCIA', 'EMPLOYEES', 'VIEW'),
            ('GERENCIA', 'EMPLOYEES', 'VIEW_SALARY'),
            ('GERENCIA', 'IMPORTS', 'VIEW'),
            ('OPERACIONES', 'EMPLOYEES', 'VIEW')
    ) AS t(role_code, module_code, action_code)
)
INSERT INTO role_permissions (role_id, module_code, action_code, allowed)
SELECT r.id, pm.module_code, pm.action_code, TRUE
FROM permission_matrix pm
JOIN roles r ON r.code = pm.role_code
ON CONFLICT (role_id, module_code, action_code) DO UPDATE
SET allowed = EXCLUDED.allowed;

COMMIT;

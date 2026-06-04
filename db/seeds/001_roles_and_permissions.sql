\set ON_ERROR_STOP on

BEGIN;

INSERT INTO roles (code, name, description)
VALUES
    ('ADMIN', 'Administrador', 'Configura usuarios, consulta el portal completo y administra el piloto.'),
    ('TH', 'Talento Humano', 'Gestiona funciones de Talento Humano en incrementos posteriores.'),
    ('GERENCIA', 'Gerencia / Consulta', 'Consulta dashboard e informacion consolidada sin edicion operativa.'),
    ('OPERACIONES', 'Operaciones / Consulta', 'Consulta informacion operativa y estados del personal.')
ON CONFLICT (code) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = NOW();

INSERT INTO app_users (full_name, username, password_hash, email, is_active)
VALUES
    (
        'Administrador S&G',
        'admin.sg',
        crypt('Admin123', gen_salt('bf')),
        'admin@sg.local',
        TRUE
    )
ON CONFLICT (username) DO UPDATE
SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM app_users u
JOIN roles r ON r.code = 'ADMIN'
WHERE u.username = 'admin.sg'
ON CONFLICT (user_id, role_id) DO NOTHING;

WITH role_map AS (
    SELECT id, code FROM roles
),
permission_matrix AS (
    SELECT *
    FROM (
        VALUES
            ('ADMIN', 'PORTAL', 'ACCESS', TRUE),
            ('ADMIN', 'DASHBOARD', 'VIEW', TRUE),
            ('ADMIN', 'EMPLOYEES', 'VIEW', TRUE),
            ('ADMIN', 'POSITIONS', 'VIEW', TRUE),
            ('ADMIN', 'COURSES', 'VIEW', TRUE),
            ('ADMIN', 'CERTIFICATIONS', 'VIEW', TRUE),
            ('ADMIN', 'ALERTS', 'VIEW', TRUE),
            ('ADMIN', 'NOTIFICATIONS', 'VIEW', TRUE),
            ('ADMIN', 'NOTIFICATIONS', 'MANAGE', TRUE),
            ('ADMIN', 'IMPORTS', 'VIEW', TRUE),
            ('ADMIN', 'SETTINGS', 'VIEW', TRUE),
            ('ADMIN', 'NOVEDADES', 'VIEW', TRUE),
            ('ADMIN', 'USERS', 'VIEW', TRUE),
            ('ADMIN', 'USERS', 'ASSIGN_ROLE', TRUE),
            ('ADMIN', 'CONFIG', 'VIEW', TRUE),
            ('TH', 'PORTAL', 'ACCESS', TRUE),
            ('TH', 'DASHBOARD', 'VIEW', TRUE),
            ('TH', 'EMPLOYEES', 'VIEW', TRUE),
            ('TH', 'POSITIONS', 'VIEW', TRUE),
            ('TH', 'COURSES', 'VIEW', TRUE),
            ('TH', 'CERTIFICATIONS', 'VIEW', TRUE),
            ('TH', 'ALERTS', 'VIEW', TRUE),
            ('TH', 'NOTIFICATIONS', 'VIEW', TRUE),
            ('TH', 'NOTIFICATIONS', 'MANAGE', TRUE),
            ('TH', 'IMPORTS', 'VIEW', TRUE),
            ('TH', 'NOVEDADES', 'VIEW', TRUE),
            ('GERENCIA', 'PORTAL', 'ACCESS', TRUE),
            ('GERENCIA', 'DASHBOARD', 'VIEW', TRUE),
            ('GERENCIA', 'EMPLOYEES', 'VIEW', TRUE),
            ('GERENCIA', 'POSITIONS', 'VIEW', TRUE),
            ('GERENCIA', 'COURSES', 'VIEW', TRUE),
            ('GERENCIA', 'CERTIFICATIONS', 'VIEW', TRUE),
            ('GERENCIA', 'ALERTS', 'VIEW', TRUE),
            ('GERENCIA', 'NOTIFICATIONS', 'VIEW', TRUE),
            ('GERENCIA', 'NOVEDADES', 'VIEW', TRUE),
            ('OPERACIONES', 'PORTAL', 'ACCESS', TRUE),
            ('OPERACIONES', 'DASHBOARD', 'VIEW', TRUE),
            ('OPERACIONES', 'EMPLOYEES', 'VIEW', TRUE),
            ('OPERACIONES', 'POSITIONS', 'VIEW', TRUE),
            ('OPERACIONES', 'COURSES', 'VIEW', TRUE),
            ('OPERACIONES', 'ALERTS', 'VIEW', TRUE),
            ('OPERACIONES', 'NOTIFICATIONS', 'VIEW', TRUE),
            ('OPERACIONES', 'NOVEDADES', 'VIEW', TRUE)
    ) AS t(role_code, module_code, action_code, allowed)
)
INSERT INTO role_permissions (role_id, module_code, action_code, allowed)
SELECT rm.id, pm.module_code, pm.action_code, pm.allowed
FROM permission_matrix pm
JOIN role_map rm ON rm.code = pm.role_code
ON CONFLICT (role_id, module_code, action_code) DO UPDATE
SET allowed = EXCLUDED.allowed;

INSERT INTO notification_items (target_type, target_key, title, body, status, source_module)
SELECT *
FROM (
    VALUES
        ('USER', 'admin.sg', 'Portal base activo', 'El shell I1 esta disponible para pruebas internas.', 'UNREAD', 'SYSTEM'),
        ('ROLE', 'ADMIN', 'Pendiente backend real', 'Se requiere conectar autenticacion y persistencia PostgreSQL.', 'UNREAD', 'SYSTEM')
) AS seed(target_type, target_key, title, body, status, source_module)
WHERE NOT EXISTS (
    SELECT 1
    FROM notification_items ni
    WHERE ni.target_type = seed.target_type
      AND ni.target_key = seed.target_key
      AND ni.title = seed.title
);

COMMIT;

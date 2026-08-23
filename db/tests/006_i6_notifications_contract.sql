\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    notification_id BIGINT;
    admin_role_id BIGINT;
    th_role_id BIGINT;
    gerencia_role_id BIGINT;
    operaciones_role_id BIGINT;
BEGIN
    IF to_regclass('notification_items') IS NULL THEN
        RAISE EXCEPTION 'Missing table notification_items';
    END IF;

    IF to_regclass('notification_events') IS NULL THEN
        RAISE EXCEPTION 'Missing table notification_events';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM pg_attribute
        WHERE attrelid = to_regclass('notification_items')
          AND attname IN ('severity', 'source_type', 'source_id', 'dedupe_key', 'action_url', 'managed_at', 'managed_by')
          AND NOT attisdropped
    ) <> 7 THEN
        RAISE EXCEPTION 'notification_items is missing I6 columns';
    END IF;

    BEGIN
        INSERT INTO notification_items (target_type, target_key, title, body, severity, source_module, source_type, status)
        VALUES ('TEAM', 'TH', 'Target invalido', 'Debe fallar', 'INFO', 'SYSTEM', 'TEST', 'UNREAD');
        RAISE EXCEPTION 'notification_items accepted invalid target_type';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO notification_items (target_type, target_key, title, body, severity, source_module, source_type, status)
        VALUES ('ROLE', 'TH', 'Severidad invalida', 'Debe fallar', 'BLOCKER', 'SYSTEM', 'TEST', 'UNREAD');
        RAISE EXCEPTION 'notification_items accepted invalid severity';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO notification_items (target_type, target_key, title, body, severity, source_module, source_type, status)
        VALUES ('ROLE', 'TH', 'Modulo invalido', 'Debe fallar', 'INFO', 'WHATSAPP', 'TEST', 'UNREAD');
        RAISE EXCEPTION 'notification_items accepted invalid source_module';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO notification_items (target_type, target_key, title, body, severity, source_module, source_type, status)
        VALUES ('ROLE', 'TH', 'Estado invalido', 'Debe fallar', 'INFO', 'SYSTEM', 'TEST', 'RESOLVED');
        RAISE EXCEPTION 'notification_items accepted invalid status';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO notification_items (
        target_type,
        target_key,
        title,
        body,
        severity,
        source_module,
        source_type,
        source_id,
        dedupe_key,
        status,
        action_url
    )
    VALUES (
        'ROLE',
        'TH',
        'Curso critico',
        'Empleado con acreditacion critica',
        'CRITICAL',
        'TRAINING',
        'TRAINING_EXPIRY',
        'training-record-1',
        'TRAINING:TRAINING_EXPIRY:training-record-1:ROLE:TH:CRITICAL',
        'UNREAD',
        '/module/courses'
    )
    RETURNING id INTO notification_id;

    BEGIN
        INSERT INTO notification_items (
            target_type,
            target_key,
            title,
            body,
            severity,
            source_module,
            source_type,
            source_id,
            dedupe_key
        )
        VALUES (
            'ROLE',
            'TH',
            'Curso critico duplicado',
            'Debe fallar por dedupe',
            'CRITICAL',
            'TRAINING',
            'TRAINING_EXPIRY',
            'training-record-1',
            'TRAINING:TRAINING_EXPIRY:training-record-1:ROLE:TH:CRITICAL'
        );
        RAISE EXCEPTION 'notification_items accepted duplicate active dedupe_key';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;

    INSERT INTO notification_events (notification_id, actor_username, event_type, detail)
    VALUES (notification_id, 'th.sg', 'READ', '{"source":"contract"}'::jsonb);

    BEGIN
        INSERT INTO notification_events (notification_id, actor_username, event_type)
        VALUES (notification_id, 'th.sg', 'INVALID');
        RAISE EXCEPTION 'notification_events accepted invalid event_type';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    SELECT id INTO admin_role_id FROM roles WHERE code = 'ADMIN';
    SELECT id INTO th_role_id FROM roles WHERE code = 'TH';
    SELECT id INTO gerencia_role_id FROM roles WHERE code = 'GERENCIA';
    SELECT id INTO operaciones_role_id FROM roles WHERE code = 'OPERACIONES';

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = admin_role_id AND module_code = 'NOTIFICATIONS' AND action_code = 'GENERATE_ALERTS' AND allowed) THEN
        RAISE EXCEPTION 'ADMIN must generate I6 alerts';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = th_role_id AND module_code = 'NOTIFICATIONS' AND action_code = 'GENERATE_ALERTS' AND allowed) THEN
        RAISE EXCEPTION 'TH must generate I6 alerts';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = gerencia_role_id AND module_code = 'NOTIFICATIONS' AND action_code = 'EXPORT' AND allowed) THEN
        RAISE EXCEPTION 'GERENCIA must export notification summaries';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM role_permissions WHERE role_id = operaciones_role_id AND module_code = 'NOTIFICATIONS' AND action_code = 'VIEW' AND allowed) THEN
        RAISE EXCEPTION 'OPERACIONES must view notifications';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM role_permissions
        WHERE role_id IN (gerencia_role_id, operaciones_role_id)
          AND module_code = 'NOTIFICATIONS'
          AND action_code IN ('GENERATE_ALERTS', 'CONFIGURE_EMAIL')
          AND allowed
    ) THEN
        RAISE EXCEPTION 'GERENCIA and OPERACIONES must not configure or generate I6 alerts';
    END IF;
END
$$;

ROLLBACK;

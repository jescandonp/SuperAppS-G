\set ON_ERROR_STOP on

-- Run this script with a PostgreSQL superuser or a role with CREATEROLE/CREATEDB.
-- Example:
-- psql -U postgres -f db/bootstrap/001_create_sg_superapp_dev.sql

DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sg_app') THEN
        CREATE ROLE sg_app
            LOGIN
            PASSWORD 'sg_app_change_me'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            INHERIT;
    ELSE
        ALTER ROLE sg_app
            WITH LOGIN
                 PASSWORD 'sg_app_change_me'
                 NOSUPERUSER
                 NOCREATEDB
                 NOCREATEROLE
                 INHERIT;
    END IF;
END
$$;

SELECT 'CREATE DATABASE sg_superapp_dev OWNER sg_app'
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = 'sg_superapp_dev'
)
\gexec

GRANT ALL PRIVILEGES ON DATABASE sg_superapp_dev TO sg_app;

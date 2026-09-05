\set ON_ERROR_STOP on
BEGIN;

-- I9-PILOTO-SIMULATED v3 (2026-09-05): agrega approvedMotiveCodes al catalogo de I9-R01. Sin esto,
-- CreateScheduleExceptionAsync rechazaba TODA excepcion de R01 con "El motivo no pertenece al catalogo
-- versionado de la regla" - el catalogo de v2 no declaraba ningun motivo aprobado para R01, asi que
-- ninguna de las 48 asignaciones reales del piloto (todas con I9-R01 EXCEPTION_REQUIRED, jornada de 12h
-- por encima del umbral aprobable de 10h) podia aprobarse jamas, aunque el permiso escrito ya estuviera
-- confirmado por Legal (ver v2). Se reusan los MISMOS codigos demo ya aprobados para R02 (misma familia
-- de excepciones de jornada/descanso) - ningun motivo nuevo, solo se completa el catalogo que faltaba.
-- Todo lo demas (R01-R07 parametros, R04/R06 deshabilitados) se copia identico de v2.

UPDATE scheduling_rule_profiles
SET status='RETIRED', effective_to=LEAST(COALESCE(effective_to,CURRENT_DATE),CURRENT_DATE)
WHERE profile_code='I9-PILOTO-SIMULATED' AND version=2 AND status='ACTIVE';

INSERT INTO scheduling_rule_profiles (
 profile_code,version,origin,environment_scope,scope_code,effective_from,status,
 checksum,created_by,approval_evidence
) VALUES (
 'I9-PILOTO-SIMULATED',3,'SIMULATED','MVP_TEST','PILOTO-NUEVO-PLANEADOR',DATE '2026-09-01','DRAFT',
 repeat('0',64),'seed.i9.piloto.v3',
 '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","approval":"AUTHORIZED_FOR_MVP_TEST_ONLY","replacesVersion":2,"decision":"catalogo de motivos de R01 completado - mismos codigos demo ya aprobados para R02"}'::jsonb
) ON CONFLICT(profile_code,version) DO NOTHING;

WITH desired(rule_code,parameters,catalog_snapshot,enabled) AS (VALUES
 ('I9-R01','{"ordinaryDailyHours":8,"ordinaryWeeklyHours":42,"approvalFromDailyHours":10,"absoluteDailyHours":12,"absoluteWeeklyHours":60,"writtenAgreementRequiredAboveOrdinary":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","source":"MVP_SPEC_V2","approvedMotiveCodes":["OPERATIONAL_CONTINUITY_DEMO","EMERGENCY_DEMO","OTHER"]}'::jsonb,TRUE),
 ('I9-R02','{"minimumRestHours":12,"otherReasonRequiresDescription":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","approvedMotiveCodes":["OPERATIONAL_CONTINUITY_DEMO","EMERGENCY_DEMO","OTHER"]}'::jsonb,TRUE),
 ('I9-R03','{"intervalSemantics":"HALF_OPEN","adjacentIntervalsOverlap":false,"precedenceOver":["I9-R05"]}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","sources":["CURRENT_DRAFTS","APPROVED_SCHEDULES"]}'::jsonb,TRUE),
 ('I9-R04','{"unknownOutcome":"UNVERIFIED","unknownApprovalBlocked":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","approvedMotiveCodes":["HR_VALIDATED_DEMO","OPERATIONAL_CONTINUITY_DEMO"],"mappingDemo":[]}'::jsonb,FALSE),
 ('I9-R05','{"missingRelationOutcome":"EXCEPTION_REQUIRED","neverAssumeZero":true,"directional":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","matrixDemo":[]}'::jsonb,TRUE),
 ('I9-R06','{"validForEntireShift":true,"unverifiedOutcome":"EXCEPTION_REQUIRED","informativeRequiresOwnerAndDueDate":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","approvedMotiveCodes":["HR_VALIDATED_DEMO"],"requirementsDemo":[]}'::jsonb,FALSE),
 ('I9-R07','{"compareBy":["templateVersion","anchor","cell"],"changeInvalidatesApproval":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","templateCodes":["2X2","4X2","4X4","6X1"],"templateVersions":["1"],"approvedMotiveCodes":["OPERATIONAL_NEED_DEMO","COVERAGE_DEMO","OTHER"]}'::jsonb,TRUE)
)
INSERT INTO scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled)
SELECT p.id,d.rule_code,d.parameters,d.catalog_snapshot,d.enabled
FROM scheduling_rule_profiles p CROSS JOIN desired d
WHERE p.profile_code='I9-PILOTO-SIMULATED' AND p.version=3 AND p.status='DRAFT'
ON CONFLICT(rule_profile_id,rule_code) DO UPDATE
 SET parameters=EXCLUDED.parameters,catalog_snapshot=EXCLUDED.catalog_snapshot,enabled=EXCLUDED.enabled;

UPDATE scheduling_rule_profiles p
SET checksum=content.checksum,status='ACTIVE',activated_by='seed.i9.piloto.v3',activated_at=NOW()
FROM (
 SELECT e.rule_profile_id,
        encode(public.digest(convert_to(string_agg(e.rule_code||':'||i9_mvp_canonical_jsonb(e.parameters)||':'||i9_mvp_canonical_jsonb(e.catalog_snapshot), '|' ORDER BY e.rule_code),'UTF8'),'sha256'),'hex') AS checksum
 FROM scheduling_rule_profile_entries e GROUP BY e.rule_profile_id
) content
WHERE p.id=content.rule_profile_id AND p.profile_code='I9-PILOTO-SIMULATED'
  AND p.version=3 AND p.status='DRAFT';

DO $$
DECLARE p_id BIGINT;
BEGIN
 IF EXISTS(SELECT 1 FROM scheduling_rule_profiles WHERE profile_code='I9-PILOTO-SIMULATED' AND version=2 AND status='ACTIVE') THEN
  RAISE EXCEPTION 'I9-PILOTO-SIMULATED v2 remained active';
 END IF;
 SELECT id INTO p_id FROM scheduling_rule_profiles
 WHERE profile_code='I9-PILOTO-SIMULATED' AND version=3 AND scope_code='PILOTO-NUEVO-PLANEADOR'
   AND status='ACTIVE' AND effective_from=DATE '2026-09-01';
 IF p_id IS NULL THEN RAISE EXCEPTION 'I9-PILOTO-SIMULATED v3 did not activate with the corrected effective_from'; END IF;
 IF NOT (SELECT catalog_snapshot ? 'approvedMotiveCodes' FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id AND rule_code='I9-R01') THEN
  RAISE EXCEPTION 'I9-R01 must declare approvedMotiveCodes in v3';
 END IF;
 IF (SELECT count(*) FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id AND enabled=FALSE)<>2 THEN
  RAISE EXCEPTION 'exactly R04 and R06 must remain disabled in v3';
 END IF;
END $$;

COMMIT;

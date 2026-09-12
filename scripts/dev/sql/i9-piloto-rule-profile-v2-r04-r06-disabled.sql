\set ON_ERROR_STOP on
BEGIN;

-- I9-PILOTO-SIMULATED v2 (2026-09-03): misma decision aprobada por el usuario para el piloto real -
-- I9-R04 (novedades) e I9-R06 (requisitos) quedan enabled=FALSE porque no existe hoy ninguna fuente
-- real de datos para ninguna de las dos (el modulo "Novedades" esta explicitamente fuera del alcance
-- del MVP segun db/seeds - ver docs/specs/2026-05-21-sg-superapp-spec-00-arquitectura-incrementos.md
-- seccion 4; el catalogo de requisitos por puesto de estos 4 sitios nunca se construyo, solo existe un
-- demo de juguete para POSITION-1). Deshabilitar una regla no la excluye del calculo de elegibilidad
-- por si sola sin el cambio de motor del mismo dia (SchedulingRuleEvaluator: enabled=false ahora emite
-- NOT_APPLICABLE, no WARNING) - esa es la salvaguarda real contra "aprobar por omision", no este script.
-- v1 sigue existiendo, RETIRED, inmutable y auditable con status='RETIRED'.
-- Todos los demas parametros (R01,R02,R03,R05,R07) se copian identicos de v1 - ningun umbral nuevo.

UPDATE scheduling_rule_profiles
SET status='RETIRED', effective_to=LEAST(COALESCE(effective_to,CURRENT_DATE),CURRENT_DATE)
WHERE profile_code='I9-PILOTO-SIMULATED' AND version=1 AND status='ACTIVE';

-- effective_from se fija en el mismo inicio de vigencia que v1 (2026-09-01, todo el periodo piloto de
-- septiembre 2026), no en CURRENT_DATE: v2 redefine la politica para el mismo alcance temporal completo
-- que v1 ya cubria, no un corte a mitad de periodo. Usar CURRENT_DATE aqui dejaba sin perfil activo
-- cualquier fecha del piloto anterior a "hoy" - error real encontrado al generar una propuesta real
-- tras aplicar este script por primera vez (LoadActiveAsync exige effective_from <= periodo pedido).
INSERT INTO scheduling_rule_profiles (
 profile_code,version,origin,environment_scope,scope_code,effective_from,status,
 checksum,created_by,approval_evidence
) VALUES (
 'I9-PILOTO-SIMULATED',2,'SIMULATED','MVP_TEST','PILOTO-NUEVO-PLANEADOR',DATE '2026-09-01','DRAFT',
 repeat('0',64),'seed.i9.piloto.v2',
 '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","approval":"AUTHORIZED_FOR_MVP_TEST_ONLY","replacesVersion":1,"decision":"R04 y R06 deshabilitados para el piloto: sin fuente real de datos, novedades fuera del alcance del MVP"}'::jsonb
) ON CONFLICT(profile_code,version) DO NOTHING;

WITH desired(rule_code,parameters,catalog_snapshot,enabled) AS (VALUES
 ('I9-R01','{"ordinaryDailyHours":8,"ordinaryWeeklyHours":42,"approvalFromDailyHours":10,"absoluteDailyHours":12,"absoluteWeeklyHours":60,"writtenAgreementRequiredAboveOrdinary":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","source":"MVP_SPEC_V2"}'::jsonb,TRUE),
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
WHERE p.profile_code='I9-PILOTO-SIMULATED' AND p.version=2 AND p.status='DRAFT'
ON CONFLICT(rule_profile_id,rule_code) DO UPDATE
 SET parameters=EXCLUDED.parameters,catalog_snapshot=EXCLUDED.catalog_snapshot,enabled=EXCLUDED.enabled;

UPDATE scheduling_rule_profiles p
SET checksum=content.checksum,status='ACTIVE',activated_by='seed.i9.piloto.v2',activated_at=NOW()
FROM (
 SELECT e.rule_profile_id,
        encode(public.digest(convert_to(string_agg(e.rule_code||':'||i9_mvp_canonical_jsonb(e.parameters)||':'||i9_mvp_canonical_jsonb(e.catalog_snapshot), '|' ORDER BY e.rule_code),'UTF8'),'sha256'),'hex') AS checksum
 FROM scheduling_rule_profile_entries e GROUP BY e.rule_profile_id
) content
WHERE p.id=content.rule_profile_id AND p.profile_code='I9-PILOTO-SIMULATED'
  AND p.version=2 AND p.status='DRAFT';

DO $$
DECLARE p_id BIGINT; actual_checksum TEXT;
BEGIN
 IF EXISTS(SELECT 1 FROM scheduling_rule_profiles WHERE profile_code='I9-PILOTO-SIMULATED' AND version=1 AND status='ACTIVE') THEN
  RAISE EXCEPTION 'I9-PILOTO-SIMULATED v1 remained active';
 END IF;
 SELECT id,checksum::text INTO p_id,actual_checksum FROM scheduling_rule_profiles
 WHERE profile_code='I9-PILOTO-SIMULATED' AND version=2 AND scope_code='PILOTO-NUEVO-PLANEADOR'
   AND origin='SIMULATED' AND environment_scope='MVP_TEST' AND status='ACTIVE';
 IF p_id IS NULL THEN RAISE EXCEPTION 'I9-PILOTO-SIMULATED v2 profile did not activate'; END IF;
 IF (SELECT count(*) FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id)<>7 THEN
  RAISE EXCEPTION 'I9-PILOTO-SIMULATED v2 profile must contain exactly R01-R07';
 END IF;
 IF actual_checksum<>(SELECT encode(public.digest(convert_to(string_agg(rule_code||':'||i9_mvp_canonical_jsonb(parameters)||':'||i9_mvp_canonical_jsonb(catalog_snapshot),'|' ORDER BY rule_code),'UTF8'),'sha256'),'hex') FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id) THEN
  RAISE EXCEPTION 'I9-PILOTO-SIMULATED v2 checksum does not match executable content';
 END IF;
 IF EXISTS(SELECT 1 FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id AND catalog_snapshot->>'classification'<>'SIMULATED_DEMO_NOT_INSTITUTIONAL') THEN
  RAISE EXCEPTION 'I9-PILOTO-SIMULATED v2 catalogs and matrices must be marked as demo';
 END IF;
 IF (SELECT enabled FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id AND rule_code='I9-R04') THEN
  RAISE EXCEPTION 'I9-R04 must be disabled in v2';
 END IF;
 IF (SELECT enabled FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id AND rule_code='I9-R06') THEN
  RAISE EXCEPTION 'I9-R06 must be disabled in v2';
 END IF;
 IF (SELECT count(*) FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id AND enabled=FALSE)<>2 THEN
  RAISE EXCEPTION 'exactly R04 and R06 must be disabled in v2, no other rule';
 END IF;
END $$;

COMMIT;

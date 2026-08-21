\set ON_ERROR_STOP on
BEGIN;

-- v1 remains immutable and auditable, but is no longer executable.
UPDATE scheduling_rule_profiles
SET status='RETIRED', effective_to=LEAST(COALESCE(effective_to,CURRENT_DATE),CURRENT_DATE)
WHERE profile_code='I9-MVP-SIMULATED' AND version=1 AND status='ACTIVE';

INSERT INTO scheduling_rule_profiles (
 profile_code,version,origin,environment_scope,scope_code,effective_from,status,
 checksum,created_by,approval_evidence
) VALUES (
 'I9-MVP-SIMULATED',2,'SIMULATED','MVP_TEST','PROJECT-A',DATE '2026-08-21','DRAFT',
 repeat('0',64),'seed.i9.mvp.v2',
 '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","approval":"AUTHORIZED_FOR_MVP_TEST_ONLY","replacesVersion":1}'::jsonb
) ON CONFLICT(profile_code,version) DO NOTHING;

WITH desired(rule_code,parameters,catalog_snapshot) AS (VALUES
 ('I9-R01','{"ordinaryDailyHours":8,"ordinaryWeeklyHours":42,"approvalFromDailyHours":10,"absoluteDailyHours":12,"absoluteWeeklyHours":60,"writtenAgreementRequiredAboveOrdinary":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","source":"MVP_SPEC_V2"}'::jsonb),
 ('I9-R02','{"minimumRestHours":12,"otherReasonRequiresDescription":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","approvedMotiveCodes":["OPERATIONAL_CONTINUITY_DEMO","EMERGENCY_DEMO","OTHER"]}'::jsonb),
 ('I9-R03','{"intervalSemantics":"HALF_OPEN","adjacentIntervalsOverlap":false,"precedenceOver":["I9-R05"]}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","sources":["CURRENT_DRAFTS","APPROVED_SCHEDULES"]}'::jsonb),
 ('I9-R04','{"unknownOutcome":"UNVERIFIED","unknownApprovalBlocked":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","mappingDemo":[
    {"sourceSystem":"HR-DEMO","sourceCode":"INC","sourceStatus":"ACTIVE","semanticCategory":"INCAPACITY_ACTIVE","mappingVersion":"MAP-V2","effectiveFrom":"2026-01-01T00:00:00Z","effectiveTo":null,"mappedBy":"TH-DEMO-ROLE","approvedBy":"OPS-DEMO-ROLE"},
    {"sourceSystem":"HR-DEMO","sourceCode":"V","sourceStatus":"APPROVED","semanticCategory":"VACATION_APPROVED_ACTIVE","mappingVersion":"MAP-V2","effectiveFrom":"2026-01-01T00:00:00Z","effectiveTo":null,"mappedBy":"TH-DEMO-ROLE","approvedBy":"OPS-DEMO-ROLE"},
    {"sourceSystem":"HR-DEMO","sourceCode":"A","sourceStatus":"CONFIRMED","semanticCategory":"ABSENCE_CONFIRMED","mappingVersion":"MAP-V2","effectiveFrom":"2026-01-01T00:00:00Z","effectiveTo":null,"mappedBy":"TH-DEMO-ROLE","approvedBy":"OPS-DEMO-ROLE"},
    {"sourceSystem":"HR-DEMO","sourceCode":"A","sourceStatus":"PENDING","semanticCategory":"ABSENCE_PENDING_CONFIRMATION","mappingVersion":"MAP-V2","effectiveFrom":"2026-01-01T00:00:00Z","effectiveTo":null,"mappedBy":"TH-DEMO-ROLE","approvedBy":"OPS-DEMO-ROLE"},
    {"sourceSystem":"HR-DEMO","sourceCode":"TA","sourceStatus":"ACTIVE","semanticCategory":"ADDITIONAL_SHIFT","mappingVersion":"MAP-V2","effectiveFrom":"2026-01-01T00:00:00Z","effectiveTo":null,"mappedBy":"TH-DEMO-ROLE","approvedBy":"OPS-DEMO-ROLE"}
  ]}'::jsonb),
 ('I9-R05','{"missingRelationOutcome":"EXCEPTION_REQUIRED","neverAssumeZero":true,"directional":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","matrixDemo":[{"from":"PROJECT-A/POSITION-1","to":"PROJECT-B/POSITION-2","minutes":45,"prohibited":false},{"from":"PROJECT-B/POSITION-2","to":"PROJECT-A/POSITION-1","minutes":60,"prohibited":false},{"from":"PROJECT-A/POSITION-1","to":"PROJECT-C/POSITION-3","minutes":null,"prohibited":true}]}'::jsonb),
 ('I9-R06','{"validForEntireShift":true,"unverifiedOutcome":"EXCEPTION_REQUIRED","informativeRequiresOwnerAndDueDate":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","requirementsDemo":[
    {"projectCode":"PROJECT-A","positionCode":"POSITION-1","requirementCode":"COURSE-DEMO","category":"COURSE","catalogVersion":"REQ-V2","sourceSystem":"I3-DEMO","sourceRequirementCode":"SRC-COURSE-DEMO","sourceStatus":"ACTIVE","evidenceType":"DEMO_RECORD","evidenceSource":"I3-DEMO","effectiveFrom":"2026-01-01T00:00:00Z","effectiveTo":null,"informativeRemediable":true},
    {"projectCode":"PROJECT-A","positionCode":"POSITION-1","requirementCode":"ACCREDITATION-DEMO","category":"ACCREDITATION","catalogVersion":"REQ-V2","sourceSystem":"I3-DEMO","sourceRequirementCode":"SRC-ACCREDITATION-DEMO","sourceStatus":"ACTIVE","evidenceType":"DEMO_RECORD","evidenceSource":"I3-DEMO","effectiveFrom":"2026-01-01T00:00:00Z","effectiveTo":null,"informativeRemediable":false}
  ]}'::jsonb),
 ('I9-R07','{"compareBy":["templateVersion","anchor","cell"],"changeInvalidatesApproval":true}'::jsonb,
  '{"classification":"SIMULATED_DEMO_NOT_INSTITUTIONAL","templateCodes":["2X2","4X2","6X1"],"approvedMotiveCodes":["OPERATIONAL_NEED_DEMO","COVERAGE_DEMO","OTHER"]}'::jsonb)
)
INSERT INTO scheduling_rule_profile_entries(rule_profile_id,rule_code,parameters,catalog_snapshot,enabled)
SELECT p.id,d.rule_code,d.parameters,d.catalog_snapshot,TRUE
FROM scheduling_rule_profiles p CROSS JOIN desired d
WHERE p.profile_code='I9-MVP-SIMULATED' AND p.version=2 AND p.status='DRAFT'
ON CONFLICT(rule_profile_id,rule_code) DO UPDATE
 SET parameters=EXCLUDED.parameters,catalog_snapshot=EXCLUDED.catalog_snapshot,enabled=TRUE;

UPDATE scheduling_rule_profiles p
SET checksum=content.checksum,status='ACTIVE',activated_by='seed.i9.mvp.v2',activated_at=NOW()
FROM (
 SELECT e.rule_profile_id,
        encode(public.digest(convert_to(string_agg(e.rule_code||':'||i9_mvp_canonical_jsonb(e.parameters)||':'||i9_mvp_canonical_jsonb(e.catalog_snapshot), '|' ORDER BY e.rule_code),'UTF8'),'sha256'),'hex') AS checksum
 FROM scheduling_rule_profile_entries e GROUP BY e.rule_profile_id
) content
WHERE p.id=content.rule_profile_id AND p.profile_code='I9-MVP-SIMULATED'
  AND p.version=2 AND p.status='DRAFT';

DO $$
DECLARE p_id BIGINT; actual_checksum TEXT;
BEGIN
 IF EXISTS(SELECT 1 FROM scheduling_rule_profiles WHERE profile_code='I9-MVP-SIMULATED' AND version=1 AND status='ACTIVE') THEN
  RAISE EXCEPTION 'I9 simulated MVP v1 remained active';
 END IF;
 SELECT id,checksum::text INTO p_id,actual_checksum FROM scheduling_rule_profiles
 WHERE profile_code='I9-MVP-SIMULATED' AND version=2 AND scope_code='PROJECT-A'
   AND origin='SIMULATED' AND environment_scope='MVP_TEST' AND status='ACTIVE';
 IF p_id IS NULL THEN RAISE EXCEPTION 'I9 simulated MVP v2 profile did not activate'; END IF;
 IF (SELECT count(*) FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id)<>7 THEN
  RAISE EXCEPTION 'I9 simulated MVP v2 profile must contain exactly R01-R07';
 END IF;
 IF actual_checksum<>(SELECT encode(public.digest(convert_to(string_agg(rule_code||':'||i9_mvp_canonical_jsonb(parameters)||':'||i9_mvp_canonical_jsonb(catalog_snapshot),'|' ORDER BY rule_code),'UTF8'),'sha256'),'hex') FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id) THEN
  RAISE EXCEPTION 'I9 simulated MVP v2 checksum does not match executable content';
 END IF;
 IF EXISTS(SELECT 1 FROM scheduling_rule_profile_entries WHERE rule_profile_id=p_id AND catalog_snapshot->>'classification'<>'SIMULATED_DEMO_NOT_INSTITUTIONAL') THEN
  RAISE EXCEPTION 'I9 simulated MVP v2 catalogs and matrices must be marked as demo';
 END IF;
END $$;

COMMIT;

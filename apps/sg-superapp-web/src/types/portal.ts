export type RoleCode = "ADMIN" | "TH" | "GERENCIA" | "OPERACIONES";

export type ScheduleStatus = "BORRADOR" | "PROPUESTA" | "APROBADA" | "PUBLICADA" | "REEMPLAZADA" | "CANCELADA";
export type ShiftCode = "D" | "N" | "X";
export type RequirementSeverity = "BLOQUEANTE" | "SUBSANABLE" | "INFORMATIVA";

export interface ShiftTemplate {
  id: number;
  code: string;
  name: string;
  version: number;
  mandatoryByDefault: boolean;
  status: "ACTIVO" | "INACTIVO";
  steps: Array<{ order: number; shiftCode: ShiftCode }>;
}

export interface SchedulingProject {
  id: number;
  clientId: number;
  code: string;
  name: string;
  effectiveFrom: string;
  effectiveTo: string | null;
  status: "ACTIVO" | "INACTIVO";
}

export interface ScheduleAssignment {
  id: number;
  date: string;
  startsAt: string;
  endsAt: string;
  positionId: number;
  employeeId?: number;
  shiftCode: ShiftCode;
  status: "ASIGNADA" | "VACANTE";
  score?: number;
  reasons: Array<{ code: string; severity: string; message: string }>;
}

export interface ScheduleException {
  id: number;
  assignmentId?: number;
  exceptionType: string;
  reason: string;
  responsible: string;
  resolutionDate: string;
  status: "REGISTRADA" | "APROBADA" | "RECHAZADA" | "CANCELADA";
}

export interface ScheduleProposal {
  versionId: number;
  scheduleId: number;
  projectId: number;
  versionNumber: number;
  status: ScheduleStatus;
  periodStart: string;
  periodEnd: string;
  coveragePercent: number;
  vacancyCount: number;
  exceptionCount: number;
  acceptedVacancy: boolean;
  createdBy: string;
  approvedBy: string | null;
  publishedBy: string | null;
  selfManaged: boolean;
  assignments?: ScheduleAssignment[];
  exceptions?: ScheduleException[];
}

export interface ScheduleComparison {
  mode: "MINIMUM_IMPACT" | "GLOBAL";
  changedAssignments: number;
  additionalHours: number;
  vacancies: number;
  exceptions: number;
}

export interface SchedulingCapabilities {
  view: boolean;
  configure: boolean;
  generate: boolean;
  approveException: boolean;
  approve: boolean;
  publish: boolean;
  export: boolean;
}

export interface CurrentUser {
  id: number;
  fullName: string;
  username: string;
  role: RoleCode;
  isActive: boolean;
  lastLoginAt: string | null;
}

export interface AppModule {
  code: string;
  label: string;
  description: string;
  enabled: boolean;
  status: "Disponible" | "Pendiente";
}

export interface NotificationItem {
  id: number;
  targetType: "USER" | "ROLE";
  targetKey: string;
  title: string;
  body: string;
  status: "UNREAD" | "READ" | "ARCHIVED";
  createdAt: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  authenticated: boolean;
  message: string;
  sessionToken: string | null;
  user: CurrentUser | null;
}

export interface EmployeeSummary {
  id: number;
  identificationType: "CC" | "CE";
  identificationNumber: string;
  fullName: string;
  employmentStatus: "ACTIVO" | "RETIRADO";
  jobTitle: string;
  recordStatus: "ACTIVO" | "INCOMPLETO" | "INACTIVO";
  currentBaseSalary: number | null;
  currentServicePositionText: string | null;
}

export interface EmployeeDetail extends EmployeeSummary {
  hireDate: string | null;
  terminationDate: string | null;
  terminationReason: string | null;
  contractType: string | null;
  currentServicePositionId: number | null;
  currentServicePositionName: string | null;
  notes: string | null;
  salaryEffectiveFrom: string | null;
  salaryEffectiveTo: string | null;
  salarySource: string;
  changeHistory: EmployeeChange[];
}

export interface EmployeeChange {
  id: number;
  actorUsername: string;
  fieldName: string;
  previousValue: string | null;
  newValue: string | null;
  changedAt: string;
}

export interface ImportBatchSummary {
  id: number;
  loadType: string;
  fileName: string;
  uploadedBy: string;
  status: "PREVALIDANDO" | "PREVALIDADA" | "IMPORTADA" | "RECHAZADA" | "CON_ERRORES" | "CANCELADA";
  totalRecords: number;
  validRecords: number;
  incompleteRecords: number;
  duplicateRecords: number;
  invalidRecords: number;
  createdAt: string;
  importedAt: string | null;
}

export interface ImportBatchError {
  id: number;
  rowNumber: number;
  fieldName: string;
  errorType: "INCOMPLETO" | "DUPLICADO" | "FORMATO_INVALIDO" | "VALOR_NO_RECONOCIDO" | "FECHA_INCONSISTENTE";
  message: string;
  originalValue: string | null;
}

export interface ImportColumnMapping {
  sourceHeader: string;
  targetField: string | null;
  mappingStatus: "MAPPED" | "UNMAPPED" | "IGNORED";
  sourcePosition: number;
}

export type ImportRowClassification = "VALIDO" | "INCOMPLETO" | "DUPLICADO" | "ERRONEO";

export interface ImportBatchRow {
  id: number;
  rowNumber: number;
  classification: ImportRowClassification;
  identificationType: string;
  identificationNumber: string | null;
  normalizedPayload: Record<string, string | null>;
  sourcePayload: Record<string, string | null>;
}

export interface ImportPrevalidationResponse {
  batchId: number;
  status: "PREVALIDADA" | "CON_ERRORES";
  fileName: string;
  totalRecords: number;
  validRecords: number;
  incompleteRecords: number;
  duplicateRecords: number;
  invalidRecords: number;
}

export type ServicePositionStatus = "ACTIVO" | "INACTIVO";

export interface ServicePosition {
  id: number;
  code: string | null;
  name: string;
  clientText: string | null;
  locationText: string | null;
  status: ServicePositionStatus;
  notes: string | null;
  activeAssignmentsCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface ServicePositionRequest {
  code: string | null;
  name: string;
  clientText: string | null;
  locationText: string | null;
  notes: string | null;
}

export type PositionAssignmentStatus = "VIGENTE" | "FINALIZADA";

export interface PositionAssignment {
  id: number;
  employeeId: number;
  positionId: number;
  positionName: string;
  positionCode: string | null;
  clientText: string | null;
  startDate: string;
  endDate: string | null;
  status: PositionAssignmentStatus;
  changeReason: string | null;
  notes: string | null;
  createdBy: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreatePositionAssignmentRequest {
  positionId: number;
  startDate: string;
  changeReason: string | null;
  notes: string | null;
}

export interface FinalizePositionAssignmentRequest {
  endDate: string;
  changeReason: string | null;
  notes: string | null;
}

export type CertificateSignerStatus = "ACTIVO" | "INACTIVO";

export interface CertificateSigner {
  id: number;
  fullName: string;
  jobTitle: string;
  signaturePath: string | null;
  validFrom: string;
  validTo: string | null;
  status: CertificateSignerStatus;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CertificateSignerRequest {
  fullName: string;
  jobTitle: string;
  signaturePath: string | null;
  validFrom: string;
  validTo: string | null;
  notes: string | null;
}

export type CertificateType = "ACTIVO" | "RETIRADO";
export type CertificatePurpose = "ENTIDAD_FINANCIERA" | "CESANTIAS" | "CLIENTE" | "TRAMITE_GENERAL" | "INTERESADO";
export type CertificateStatus = "BORRADOR" | "PREVISUALIZADA" | "APROBADA" | "GENERADA" | "ANULADA";

export interface CertificateVariableRequest {
  conceptCode: string;
  conceptLabel: string;
  amount: number;
  notes: string | null;
}

export interface CertificateVariable extends CertificateVariableRequest {}

export interface CertificatePreviewRequest {
  employeeId: number;
  purpose: CertificatePurpose;
  issueDate: string;
  variables: CertificateVariableRequest[];
}

export interface CertificatePreview {
  employeeId: number;
  certificateType: CertificateType;
  purpose: CertificatePurpose;
  issueDate: string;
  employeeFullName: string;
  identificationType: string;
  identificationNumber: string;
  hireDate: string;
  terminationDate: string | null;
  terminationReason: string | null;
  jobTitle: string;
  contractType: string | null;
  baseSalary: number | null;
  signerId: number;
  signerFullName: string;
  signerJobTitle: string;
  variables: CertificateVariable[];
  previewContent: string;
  snapshot: Record<string, unknown>;
}

export interface LaborCertificate {
  id: number;
  certificateNumber: string;
  employeeId: number;
  signerId: number;
  certificateType: CertificateType;
  purpose: CertificatePurpose;
  status: CertificateStatus;
  issueDate: string;
  employeeFullName: string;
  signerFullName: string;
  previewContent: string;
  pdfFileName: string;
  templateVersion: string;
  createdBy: string;
  approvedBy: string | null;
  createdAt: string;
  approvedAt: string | null;
  generatedAt: string | null;
  snapshot: Record<string, unknown>;
}

export interface LaborCertificateHistoryItem {
  eventType: "LABOR_CERTIFICATE_GENERATED" | "LABOR_CERTIFICATE_ANNULLED" | string;
  actorUsername: string;
  createdAt: string;
  detail: Record<string, unknown>;
}

export interface AnnulCertificateRequest {
  reason: string;
}

export type TrainingRequirementCategory = "CURSO" | "ACREDITACION";
export type TrainingRequirementStatus = "ACTIVO" | "INACTIVO";
export type TrainingComplianceStatus = "VENCIDO" | "CRITICO" | "PREVENTIVO" | "INFORMATIVO" | "AL_DIA";
export type TrainingServiceEnablementStatus = "HABILITADO" | "NO_HABILITADO";
export type TrainingRecordStatus = "ACTIVO" | "INACTIVO";

export interface TrainingRequirementType {
  id: number;
  code: string | null;
  name: string;
  category: TrainingRequirementCategory;
  validityDays: number | null;
  isServiceRequired: boolean;
  status: TrainingRequirementStatus;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface UpsertTrainingRequirementTypeRequest {
  code: string | null;
  name: string;
  category: TrainingRequirementCategory;
  validityDays: number | null;
  isServiceRequired: boolean;
  notes: string | null;
}

export interface CreateTrainingRecordRequest {
  requirementTypeId: number;
  completedAt: string;
  expiresAt: string | null;
  supportPath: string | null;
  notes: string | null;
}

export interface TrainingRecord {
  id: number;
  employeeId: number;
  requirementTypeId: number;
  requirementTypeName: string;
  requirementCategory: TrainingRequirementCategory;
  completedAt: string;
  expiresAt: string;
  complianceStatus: TrainingComplianceStatus;
  daysUntilExpiry: number;
  supportPath: string | null;
  notes: string | null;
  status: TrainingRecordStatus;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface TrainingServiceEnablement {
  employeeId: number;
  serviceEnablementStatus: TrainingServiceEnablementStatus;
  blockingExpiredRequirementsCount: number;
  calculatedAt: string;
}

export interface TrainingComplianceSummary {
  employeeId: number;
  identificationNumber: string;
  fullName: string;
  employmentStatus: "ACTIVO" | "RETIRADO";
  jobTitle: string;
  currentPositionName: string | null;
  serviceEnablementStatus: TrainingServiceEnablementStatus;
  blockingExpiredRequirementsCount: number;
  worstComplianceStatus: TrainingComplianceStatus;
  activeRequirementsCount: number;
  calculatedAt: string;
}

export interface TrainingComplianceEmployee {
  employeeId: number;
  identificationType: "CC" | "CE";
  identificationNumber: string;
  fullName: string;
  employmentStatus: "ACTIVO" | "RETIRADO";
  jobTitle: string;
}

export interface TrainingCurrentPosition {
  id: number;
  name: string;
  code: string | null;
  clientText: string | null;
  startDate: string;
}

export interface TrainingComplianceDetail {
  employee: TrainingComplianceEmployee;
  currentPosition: TrainingCurrentPosition | null;
  serviceEnablement: TrainingServiceEnablement;
  currentRequirements: TrainingRecord[];
  trainingHistory: TrainingRecord[];
}

// --- I9 MVP versioned rule contracts ---------------------------------------------------------
// Every verdict below is the server's. The frontend never decides whether a rule is satisfied nor
// whether a schedule may be approved: it renders what the versioned evaluation already said. The
// unions mirror the API and are exhaustive on purpose, so a state the backend can emit and the UI
// has not handled is a compile error rather than a blank panel.

export type SchedulingRuleCode = "I9-R01" | "I9-R02" | "I9-R03" | "I9-R04" | "I9-R05" | "I9-R06" | "I9-R07";

export type SchedulingRuleOutcome =
  | "COMPLIANT"
  | "BLOCKED"
  | "EXCEPTION_REQUIRED"
  | "WARNING"
  | "NOT_APPLICABLE";

export type SchedulingRuleSeverity = "INFO" | "WARNING" | "ERROR" | "BLOCKING";

export type SchedulingRuleOrigin = "SIMULATED" | "INSTITUTIONAL";

export type SchedulingEnvironmentScope = "MVP_TEST" | "PRODUCTION";

export type SchedulingRuleProfileStatus = "DRAFT" | "ACTIVE" | "RETIRED";

// The states an approval or a publication can be refused on, as the API states them. Mirrors
// RuleGateCodes in apps/sg-superapp-api/Endpoints/PortalEndpoints.cs, which is the source of truth.
export type SchedulingRuleGateCode =
  | "RULE_BLOCKED"
  | "RULE_UNVERIFIED"
  | "RULE_EXCEPTION_REQUIRED"
  | "RULE_EVALUATION_MISSING"
  | "RULE_EVALUATION_SUPERSEDED"
  | "RULE_ASSIGNMENT_UNEVALUATED";

export interface SchedulingRuleProfileEntry {
  ruleCode: SchedulingRuleCode;
  parameters: unknown;
  catalogSnapshot: unknown;
  enabled: boolean;
}

export interface SchedulingRuleProfile {
  id: number;
  profileCode: string;
  version: number;
  origin: SchedulingRuleOrigin;
  environmentScope: SchedulingEnvironmentScope;
  scopeCode: string;
  effectiveFrom: string;
  effectiveTo: string | null;
  status: SchedulingRuleProfileStatus;
  checksum: string;
  simulated: boolean;
  entries: SchedulingRuleProfileEntry[];
}

export interface SchedulingRuleEvaluation {
  ruleCode: SchedulingRuleCode;
  profileVersion: number;
  outcome: SchedulingRuleOutcome;
  severity: SchedulingRuleSeverity;
  messageCode: string;
  explanation: string;
  scopeHash: string;
  parametersSnapshot: unknown;
  factsSnapshot: unknown;
  exceptionAllowed: boolean;
}

export interface SchedulingRuleSummary {
  total: number;
  compliant: number;
  blocked: number;
  exceptionRequired: number;
  warning: number;
  notApplicable: number;
  // Decided by the server. The UI must not recompute it from the counts above.
  canApproveOrPublish: boolean;
}

// The API answers with three different shapes and the client models all three, because modelling
// one of them everywhere is how UNCONFIGURED became dead code and how reading a summary from the
// wrong route threw. GET /rule-profiles returns a LIST, and never 404s. GET /rules/evaluations
// returns a LIST of verdicts with no summary. Only POST /rules/evaluate returns a batch, and its
// rows carry an evaluationId instead of the snapshots the persisted rows have.
export interface PersistedSchedulingRuleEvaluation {
  evaluationId: number;
  ruleCode: SchedulingRuleCode;
  outcome: SchedulingRuleOutcome;
  severity: SchedulingRuleSeverity;
  messageCode: string;
  explanation: string;
  scopeHash: string;
  exceptionAllowed: boolean;
}

export interface PersistedSchedulingRuleBatch {
  ruleProfileId: number;
  profileVersion: number;
  simulated: boolean;
  evaluations: PersistedSchedulingRuleEvaluation[];
  summary: SchedulingRuleSummary;
}

// A refusal the API stated, carried whole rather than flattened to a sentence. `code` is null for
// anything that is not a rule gate, so a caller cannot mistake an ordinary conflict for one.
export interface SchedulingRuleProblem {
  status: number;
  code: SchedulingRuleGateCode | null;
  title: string | null;
  message: string;
}

// Loading, failure and incomplete configuration are states, not an absent value: the panel has to
// tell "no active profile for this scope" from "the request failed" from "still loading", and
// showing an empty rule list for any of them would read as "nothing to worry about".
export type SchedulingRuleProfileState =
  | { status: "IDLE" }
  | { status: "LOADING" }
  | { status: "READY"; profile: SchedulingRuleProfile }
  | { status: "UNCONFIGURED"; message: string }
  | { status: "FAILED"; problem: SchedulingRuleProblem };

// Reading what is persisted gives verdicts and nothing else. There is no approval decision here,
// and the UI must not manufacture one: it renders these and lets the server refuse the transition.
export type SchedulingRuleEvaluationState =
  | { status: "IDLE" }
  | { status: "LOADING" }
  | { status: "READY"; evaluations: SchedulingRuleEvaluation[] }
  | { status: "FAILED"; problem: SchedulingRuleProblem };

// A re-evaluation is the only response that carries the server's summary.
export type SchedulingRuleRevalidationState =
  | { status: "IDLE" }
  | { status: "LOADING" }
  | { status: "READY"; batch: PersistedSchedulingRuleBatch }
  | { status: "FAILED"; problem: SchedulingRuleProblem };

export interface PreEvaluateSchedulingRulesRequest {
  ruleProfileId: number;
  projectCode: string;
  period: string;
  environmentScope: SchedulingEnvironmentScope;
  facts: unknown;
}

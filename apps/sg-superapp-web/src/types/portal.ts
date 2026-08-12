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

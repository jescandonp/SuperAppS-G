import { API_BASE_URL } from "../config";
import type { AnnulCertificateRequest, AppModule, CertificatePreview, CertificatePreviewRequest, CertificateSigner, CertificateSignerRequest, CertificateSignerStatus, CertificateStatus, CertificateType, CreatePositionAssignmentRequest, CreateTrainingRecordRequest, CurrentUser, EmployeeDetail, EmployeeSummary, FinalizePositionAssignmentRequest, ImportBatchError, ImportBatchRow, ImportBatchSummary, ImportColumnMapping, ImportPrevalidationResponse, ImportRowClassification, LaborCertificate, LaborCertificateHistoryItem, LoginRequest, LoginResponse, NotificationItem, PositionAssignment, RoleCode, ServicePosition, ServicePositionRequest, ServicePositionStatus, TrainingComplianceDetail, TrainingComplianceStatus, TrainingComplianceSummary, TrainingRecord, TrainingRequirementCategory, TrainingRequirementStatus, TrainingRequirementType, TrainingServiceEnablement, TrainingServiceEnablementStatus, UpsertTrainingRequirementTypeRequest } from "../types/portal";
import type { ScheduleComparison, ScheduleProposal, SchedulingCapabilities, SchedulingProject, ShiftTemplate } from "../types/portal";
import type { PersistedSchedulingRuleBatch, PreEvaluateSchedulingRulesRequest, SchedulingEnvironmentScope, SchedulingRuleEvaluation, SchedulingRuleGateCode, SchedulingRuleProblem, SchedulingRuleProfile } from "../types/portal";

const SESSION_TOKEN_KEY = "sg.superapp.sessionToken";

function getSessionHeaders(): HeadersInit {
  const token = sessionStorage.getItem(SESSION_TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

const RULE_GATE_CODES: readonly SchedulingRuleGateCode[] = [
  "RULE_BLOCKED",
  "RULE_UNVERIFIED",
  "RULE_EXCEPTION_REQUIRED",
  "RULE_EVALUATION_MISSING",
  "RULE_EVALUATION_SUPERSEDED",
  "RULE_ASSIGNMENT_UNEVALUATED"
];

function isRuleGateCode(value: unknown): value is SchedulingRuleGateCode {
  return typeof value === "string" && RULE_GATE_CODES.includes(value as SchedulingRuleGateCode);
}

// A refused transition arrives as application/problem+json carrying a stable `code`. Flattening it
// to a message would discard the one field that says which state the schedule is in, leaving the UI
// to guess from Spanish prose. The code travels with the error instead.
export class PortalApiError extends Error {
  readonly status: number;
  readonly code: SchedulingRuleGateCode | null;
  readonly title: string | null;

  constructor(problem: SchedulingRuleProblem) {
    super(problem.message);
    this.name = "PortalApiError";
    this.status = problem.status;
    this.code = problem.code;
    this.title = problem.title;
  }

  get problem(): SchedulingRuleProblem {
    return { status: this.status, code: this.code, title: this.title, message: this.message };
  }
}

async function readProblem(response: Response): Promise<SchedulingRuleProblem> {
  let code: SchedulingRuleGateCode | null = null;
  let title: string | null = null;
  let message: string | undefined;

  try {
    const data = (await response.json()) as { message?: string; detail?: string; title?: string; code?: unknown };
    message = data.message ?? data.detail;
    title = typeof data.title === "string" ? data.title : null;
    // A code the client does not know is not passed through as if it were understood.
    code = isRuleGateCode(data.code) ? data.code : null;
  } catch {
    message = undefined;
  }

  return { status: response.status, code, title, message: message || `API request failed: ${response.status}` };
}

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: getSessionHeaders()
  });

  if (!response.ok) {
    throw new PortalApiError(await readProblem(response));
  }

  return response.json() as Promise<T>;
}

async function sendJson<T>(path: string, method: "POST" | "PUT", body?: unknown): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers: {
      ...getSessionHeaders(),
      "Content-Type": "application/json"
    },
    body: body === undefined ? undefined : JSON.stringify(body)
  });

  if (!response.ok) {
    throw new PortalApiError(await readProblem(response));
  }

  return response.json() as Promise<T>;
}

async function downloadSchedulingExport(path: string, fileName: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}${path}`, { headers: getSessionHeaders() });
  if (!response.ok) {
    let message: string | undefined;
    try {
      const data = (await response.json()) as { message?: string };
      message = data.message;
    } catch {
      message = undefined;
    }
    throw new Error(message || `API request failed: ${response.status}`);
  }
  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  link.click();
  URL.revokeObjectURL(url);
}

export async function fetchSchedulingCapabilities(): Promise<SchedulingCapabilities> {
  return getJson<SchedulingCapabilities>("/portal/scheduling/capabilities");
}

export async function fetchSchedulingProjects(): Promise<SchedulingProject[]> {
  return getJson<SchedulingProject[]>("/portal/scheduling/projects");
}

export async function fetchShiftTemplates(): Promise<ShiftTemplate[]> {
  return getJson<ShiftTemplate[]>("/portal/scheduling/shift-templates");
}

export async function generateScheduleProposal(projectId: number, request: { periodStart: string; periodEnd: string; acceptedVacancy?: boolean }): Promise<ScheduleProposal> {
  return sendJson<ScheduleProposal>(`/portal/scheduling/projects/${projectId}/proposals`, "POST", request);
}

export async function fetchScheduleProposal(versionId: number): Promise<ScheduleProposal> {
  return getJson<ScheduleProposal>(`/portal/scheduling/proposals/${versionId}`);
}

export async function updateScheduleAssignment(versionId: number, assignmentId: number, request: { employeeId?: number; status: "ASIGNADA" | "VACANTE"; reasons?: string[]; expectedVersion: number }): Promise<ScheduleProposal> {
  return sendJson<ScheduleProposal>(`/portal/scheduling/proposals/${versionId}/assignments/${assignmentId}`, "PUT", request);
}

export async function approveScheduleException(versionId: number, request: { assignmentId?: number; exceptionType: string; reason: string; responsible: string; resolutionDate: string; expectedVersion: number }): Promise<ScheduleProposal> {
  return sendJson<ScheduleProposal>(`/portal/scheduling/proposals/${versionId}/exceptions`, "POST", request);
}

export async function approveSchedule(versionId: number, expectedVersion: number): Promise<ScheduleProposal> {
  return sendJson<ScheduleProposal>(`/portal/scheduling/proposals/${versionId}/approve`, "POST", { expectedVersion });
}

export async function publishSchedule(versionId: number, expectedVersion: number): Promise<ScheduleProposal> {
  return sendJson<ScheduleProposal>(`/portal/scheduling/proposals/${versionId}/publish`, "POST", { expectedVersion });
}

export async function replanSchedule(versionId: number, request: { triggerType: string; triggerId: string; modes: Array<"MINIMUM_IMPACT" | "GLOBAL"> }): Promise<{ versionId: number; triggerType: string; triggerId: string; scenarios: ScheduleComparison[] }> {
  return sendJson(`/portal/scheduling/versions/${versionId}/replan`, "POST", request);
}

export async function downloadSchedulePdf(versionId: number, filters: { positionId?: number; employeeId?: number } = {}): Promise<void> {
  const query = new URLSearchParams(Object.entries(filters).filter((entry) => entry[1] !== undefined).map(([key, value]) => [key, String(value)]));
  return downloadSchedulingExport(`/portal/scheduling/versions/${versionId}/export.pdf${query.size ? `?${query}` : ""}`, `programacion-v${versionId}.pdf`);
}

export async function downloadScheduleXlsx(versionId: number, filters: { positionId?: number; employeeId?: number } = {}): Promise<void> {
  const query = new URLSearchParams(Object.entries(filters).filter((entry) => entry[1] !== undefined).map(([key, value]) => [key, String(value)]));
  return downloadSchedulingExport(`/portal/scheduling/versions/${versionId}/export.xlsx${query.size ? `?${query}` : ""}`, `programacion-v${versionId}.xlsx`);
}

export async function fetchCurrentUser(): Promise<CurrentUser> {
  return getJson<CurrentUser>("/auth/me");
}

export async function fetchModules(role: RoleCode): Promise<AppModule[]> {
  return getJson<AppModule[]>(`/portal/modules/${role}`);
}

export async function fetchNotifications(username: string): Promise<NotificationItem[]> {
  return getJson<NotificationItem[]>(`/portal/notifications/${username}`);
}

export async function login(request: LoginRequest): Promise<LoginResponse> {
  const response = await fetch(`${API_BASE_URL}/auth/login`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(request)
  });

  const data = (await response.json()) as LoginResponse;

  if (!response.ok) {
    throw new Error(data.message || "Login failed.");
  }

  return data;
}

export async function fetchEmployees(filters: { search?: string; status?: string; jobTitle?: string; completeness?: string }): Promise<EmployeeSummary[]> {
  const params = new URLSearchParams();

  if (filters.search) {
    params.set("search", filters.search);
  }

  if (filters.status) {
    params.set("status", filters.status);
  }

  if (filters.jobTitle) {
    params.set("jobTitle", filters.jobTitle);
  }

  if (filters.completeness) {
    params.set("completeness", filters.completeness);
  }

  const query = params.toString();
  return getJson<EmployeeSummary[]>(`/portal/employees${query ? `?${query}` : ""}`);
}

export async function fetchEmployeeDetail(employeeId: number): Promise<EmployeeDetail> {
  return getJson<EmployeeDetail>(`/portal/employees/${employeeId}`);
}

export async function updateEmployee(employeeId: number, request: {
  fullName: string;
  employmentStatus: "ACTIVO" | "RETIRADO";
  jobTitle: string;
  hireDate: string;
  terminationDate: string | null;
  terminationReason: string | null;
  contractType: string | null;
  notes: string | null;
  currentBaseSalary: number | null;
  salaryEffectiveFrom: string | null;
}): Promise<void> {
  await sendJson<unknown>(`/portal/employees/${employeeId}`, "PUT", request);
}

export async function fetchServicePositions(filters: { search?: string; status?: ServicePositionStatus }): Promise<ServicePosition[]> {
  const params = new URLSearchParams();

  if (filters.search) {
    params.set("search", filters.search);
  }

  if (filters.status) {
    params.set("status", filters.status);
  }

  const query = params.toString();
  return getJson<ServicePosition[]>(`/portal/positions${query ? `?${query}` : ""}`);
}

export async function fetchServicePositionDetail(positionId: number): Promise<ServicePosition> {
  return getJson<ServicePosition>(`/portal/positions/${positionId}`);
}

export async function fetchServicePositionAssignments(positionId: number): Promise<PositionAssignment[]> {
  return getJson<PositionAssignment[]>(`/portal/positions/${positionId}/assignments`);
}

export async function createServicePosition(request: ServicePositionRequest): Promise<ServicePosition> {
  return sendJson<ServicePosition>("/portal/positions", "POST", request);
}

export async function updateServicePosition(positionId: number, request: ServicePositionRequest): Promise<ServicePosition> {
  return sendJson<ServicePosition>(`/portal/positions/${positionId}`, "PUT", request);
}

export async function inactivateServicePosition(positionId: number): Promise<ServicePosition> {
  return sendJson<ServicePosition>(`/portal/positions/${positionId}/inactivate`, "POST");
}

export async function fetchEmployeePositionAssignments(employeeId: number): Promise<PositionAssignment[]> {
  return getJson<PositionAssignment[]>(`/portal/employees/${employeeId}/position-assignments`);
}

export async function createPositionAssignment(employeeId: number, request: CreatePositionAssignmentRequest): Promise<PositionAssignment> {
  return sendJson<PositionAssignment>(`/portal/employees/${employeeId}/position-assignments`, "POST", request);
}

export async function finalizePositionAssignment(assignmentId: number, request: FinalizePositionAssignmentRequest): Promise<PositionAssignment> {
  return sendJson<PositionAssignment>(`/portal/position-assignments/${assignmentId}/finalize`, "POST", request);
}

export async function fetchCertificateSigners(status?: CertificateSignerStatus): Promise<CertificateSigner[]> {
  return getJson<CertificateSigner[]>(`/portal/certificate-signers${status ? `?status=${status}` : ""}`);
}

export async function createCertificateSigner(request: CertificateSignerRequest): Promise<CertificateSigner> {
  return sendJson<CertificateSigner>("/portal/certificate-signers", "POST", request);
}

export async function updateCertificateSigner(signerId: number, request: CertificateSignerRequest): Promise<CertificateSigner> {
  return sendJson<CertificateSigner>(`/portal/certificate-signers/${signerId}`, "PUT", request);
}

export async function inactivateCertificateSigner(signerId: number): Promise<CertificateSigner> {
  return sendJson<CertificateSigner>(`/portal/certificate-signers/${signerId}/inactivate`, "POST");
}

export async function fetchCertificates(filters: { employeeId?: number; type?: CertificateType; status?: CertificateStatus; from?: string; to?: string }): Promise<LaborCertificate[]> {
  const params = new URLSearchParams();
  if (filters.employeeId) {
    params.set("employeeId", filters.employeeId.toString());
  }
  if (filters.type) {
    params.set("type", filters.type);
  }
  if (filters.status) {
    params.set("status", filters.status);
  }
  if (filters.from) {
    params.set("from", filters.from);
  }
  if (filters.to) {
    params.set("to", filters.to);
  }

  const query = params.toString();
  return getJson<LaborCertificate[]>(`/portal/certificates${query ? `?${query}` : ""}`);
}

export async function fetchCertificateDetail(certificateId: number): Promise<LaborCertificate> {
  return getJson<LaborCertificate>(`/portal/certificates/${certificateId}`);
}

export async function previewCertificate(request: CertificatePreviewRequest): Promise<CertificatePreview> {
  return sendJson<CertificatePreview>("/portal/certificates/preview", "POST", request);
}

export async function approveGenerateCertificate(request: CertificatePreviewRequest): Promise<LaborCertificate> {
  return sendJson<LaborCertificate>("/portal/certificates/approve-generate", "POST", request);
}

export async function annulCertificate(certificateId: number, request: AnnulCertificateRequest): Promise<LaborCertificate> {
  return sendJson<LaborCertificate>(`/portal/certificates/${certificateId}/annul`, "POST", request);
}

export async function fetchCertificateHistory(certificateId: number): Promise<LaborCertificateHistoryItem[]> {
  return getJson<LaborCertificateHistoryItem[]>(`/portal/certificates/${certificateId}/history`);
}

export async function fetchTrainingRequirementTypes(filters: { search?: string; status?: TrainingRequirementStatus; category?: TrainingRequirementCategory }): Promise<TrainingRequirementType[]> {
  const params = new URLSearchParams();
  if (filters.search) {
    params.set("search", filters.search);
  }
  if (filters.status) {
    params.set("status", filters.status);
  }
  if (filters.category) {
    params.set("category", filters.category);
  }

  const query = params.toString();
  return getJson<TrainingRequirementType[]>(`/portal/training-types${query ? `?${query}` : ""}`);
}

export async function fetchTrainingRequirementTypeDetail(typeId: number): Promise<TrainingRequirementType> {
  return getJson<TrainingRequirementType>(`/portal/training-types/${typeId}`);
}

export async function createTrainingRequirementType(request: UpsertTrainingRequirementTypeRequest): Promise<TrainingRequirementType> {
  return sendJson<TrainingRequirementType>("/portal/training-types", "POST", request);
}

export async function updateTrainingRequirementType(typeId: number, request: UpsertTrainingRequirementTypeRequest): Promise<TrainingRequirementType> {
  return sendJson<TrainingRequirementType>(`/portal/training-types/${typeId}`, "PUT", request);
}

export async function inactivateTrainingRequirementType(typeId: number): Promise<TrainingRequirementType> {
  return sendJson<TrainingRequirementType>(`/portal/training-types/${typeId}/inactivate`, "POST");
}

export async function createTrainingRecord(employeeId: number, request: CreateTrainingRecordRequest): Promise<TrainingRecord> {
  return sendJson<TrainingRecord>(`/portal/employees/${employeeId}/training`, "POST", request);
}

export async function inactivateTrainingRecord(recordId: number): Promise<TrainingRecord> {
  return sendJson<TrainingRecord>(`/portal/training/${recordId}/inactivate`, "POST");
}

export async function fetchTrainingServiceEnablement(employeeId: number): Promise<TrainingServiceEnablement> {
  return getJson<TrainingServiceEnablement>(`/portal/employees/${employeeId}/training/enablement`);
}

export async function fetchTrainingCompliance(filters: { search?: string; typeId?: number; complianceStatus?: TrainingComplianceStatus; enablementStatus?: TrainingServiceEnablementStatus }): Promise<TrainingComplianceSummary[]> {
  const params = new URLSearchParams();
  if (filters.search) {
    params.set("search", filters.search);
  }
  if (filters.typeId) {
    params.set("typeId", filters.typeId.toString());
  }
  if (filters.complianceStatus) {
    params.set("complianceStatus", filters.complianceStatus);
  }
  if (filters.enablementStatus) {
    params.set("enablementStatus", filters.enablementStatus);
  }

  const query = params.toString();
  return getJson<TrainingComplianceSummary[]>(`/portal/training-compliance${query ? `?${query}` : ""}`);
}

export async function fetchTrainingComplianceDetail(employeeId: number): Promise<TrainingComplianceDetail> {
  return getJson<TrainingComplianceDetail>(`/portal/employees/${employeeId}/training-compliance`);
}

export async function downloadCertificatePdf(certificateId: number): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/portal/certificates/${certificateId}/download`, {
    headers: getSessionHeaders()
  });
  if (!response.ok) {
    let message: string | undefined;
    try {
      const data = (await response.json()) as { message?: string };
      message = data.message;
    } catch {
      message = undefined;
    }
    throw new Error(message || `API request failed: ${response.status}`);
  }

  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `certificado-${certificateId}.pdf`;
  link.click();
  URL.revokeObjectURL(url);
}

export async function fetchImportBatches(): Promise<ImportBatchSummary[]> {
  return getJson<ImportBatchSummary[]>("/portal/imports");
}

export async function fetchImportBatchErrors(batchId: number): Promise<ImportBatchError[]> {
  return getJson<ImportBatchError[]>(`/portal/imports/${batchId}/errors`);
}

export async function fetchImportColumnMappings(batchId: number): Promise<ImportColumnMapping[]> {
  return getJson<ImportColumnMapping[]>(`/portal/imports/${batchId}/mappings`);
}

export async function fetchImportBatchRows(batchId: number, classification?: ImportRowClassification): Promise<ImportBatchRow[]> {
  return getJson<ImportBatchRow[]>(`/portal/imports/${batchId}/rows${classification ? `?classification=${classification}` : ""}`);
}

export async function exportImportBatchErrors(batchId: number): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/portal/imports/${batchId}/errors/export`, {
    headers: getSessionHeaders()
  });
  if (!response.ok) {
    throw new Error(`API request failed: ${response.status}`);
  }

  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `import-errors-${batchId}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

async function postImportAction(batchId: number, action: "confirm" | "cancel"): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/portal/imports/${batchId}/${action}`, {
    method: "POST",
    headers: getSessionHeaders()
  });
  if (!response.ok) {
    throw new Error(`API request failed: ${response.status}`);
  }
}

export async function confirmImportBatch(batchId: number): Promise<void> {
  return postImportAction(batchId, "confirm");
}

export async function cancelImportBatch(batchId: number): Promise<void> {
  return postImportAction(batchId, "cancel");
}

export async function prevalidateEmployeeCsv(file: File, uploadedBy: string): Promise<ImportPrevalidationResponse> {
  const body = new FormData();
  body.append("file", file);
  body.append("uploadedBy", uploadedBy);

  const response = await fetch(`${API_BASE_URL}/portal/imports/prevalidate`, {
    method: "POST",
    headers: getSessionHeaders(),
    body
  });

  const data = await response.json() as ImportPrevalidationResponse & { message?: string };
  if (!response.ok) {
    throw new Error(data.message || `API request failed: ${response.status}`);
  }

  return data;
}


// --- I9 MVP versioned rules ------------------------------------------------------------------
// Each function returns the shape its route actually returns. None of them derives an approval
// decision: whether a transition will succeed is the server's answer to the transition itself.

// The route answers 200 with a list and never 404s, so "no active profile for this scope" is an
// empty result, not an error. The list is unfiltered by status, so the caller must select.
export async function fetchSchedulingRuleProfiles(
  projectCode: string,
  period: string,
  environmentScope: SchedulingEnvironmentScope
): Promise<SchedulingRuleProfile[]> {
  const query = new URLSearchParams({ projectCode, period, environmentScope });
  return getJson<SchedulingRuleProfile[]>(`/portal/scheduling/rule-profiles?${query.toString()}`);
}

export async function fetchSchedulingRuleProfile(id: number): Promise<SchedulingRuleProfile> {
  return getJson<SchedulingRuleProfile>(`/portal/scheduling/rule-profiles/${id}`);
}

// Persisted verdicts, with no summary: this route has none. Reading an approval decision from here
// is what threw before, and the UI does not need one.
export async function fetchSchedulingRuleEvaluations(
  scheduleVersionId: number
): Promise<SchedulingRuleEvaluation[]> {
  const query = new URLSearchParams({ scheduleVersionId: String(scheduleVersionId) });
  return getJson<SchedulingRuleEvaluation[]>(`/portal/scheduling/rules/evaluations?${query.toString()}`);
}

// The only response that carries the server's summary, because it is the only one that evaluated
// anything. It also writes, so it belongs to an explicit revalidation, never to a page load.
export async function evaluateSchedulingRules(
  scheduleVersionId: number,
  assignmentId: number | null,
  request: PreEvaluateSchedulingRulesRequest
): Promise<PersistedSchedulingRuleBatch> {
  const query = new URLSearchParams({ scheduleVersionId: String(scheduleVersionId) });
  if (assignmentId !== null) {
    query.set("assignmentId", String(assignmentId));
  }

  return sendJson<PersistedSchedulingRuleBatch>(
    `/portal/scheduling/rules/evaluate?${query.toString()}`,
    "POST",
    request
  );
}

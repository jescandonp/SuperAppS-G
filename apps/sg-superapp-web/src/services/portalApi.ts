import { API_BASE_URL } from "../config";
import type { AppModule, CurrentUser, EmployeeDetail, EmployeeSummary, ImportBatchError, ImportBatchSummary, ImportPrevalidationResponse, LoginRequest, LoginResponse, NotificationItem, RoleCode } from "../types/portal";

const SESSION_TOKEN_KEY = "sg.superapp.sessionToken";

function getSessionHeaders(): HeadersInit {
  const token = sessionStorage.getItem(SESSION_TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function getJson<T>(path: string): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: getSessionHeaders()
  });

  if (!response.ok) {
    throw new Error(`API request failed: ${response.status}`);
  }

  return response.json() as Promise<T>;
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

export async function fetchEmployees(filters: { search?: string; status?: string; jobTitle?: string }): Promise<EmployeeSummary[]> {
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

  const query = params.toString();
  return getJson<EmployeeSummary[]>(`/portal/employees${query ? `?${query}` : ""}`);
}

export async function fetchEmployeeDetail(employeeId: number): Promise<EmployeeDetail> {
  return getJson<EmployeeDetail>(`/portal/employees/${employeeId}`);
}

export async function fetchImportBatches(): Promise<ImportBatchSummary[]> {
  return getJson<ImportBatchSummary[]>("/portal/imports");
}

export async function fetchImportBatchErrors(batchId: number): Promise<ImportBatchError[]> {
  return getJson<ImportBatchError[]>(`/portal/imports/${batchId}/errors`);
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

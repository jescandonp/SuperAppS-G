export type RoleCode = "ADMIN" | "TH" | "GERENCIA" | "OPERACIONES";

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
  notes: string | null;
  salaryEffectiveFrom: string | null;
  salaryEffectiveTo: string | null;
  salarySource: string;
}

export interface ImportBatchSummary {
  id: number;
  loadType: string;
  fileName: string;
  uploadedBy: string;
  status: "PREVALIDADA" | "IMPORTADA" | "RECHAZADA" | "CON_ERRORES";
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
  errorType: "INCOMPLETO" | "DUPLICADO" | "FORMATO_INVALIDO" | "VALOR_NO_RECONOCIDO";
  message: string;
  originalValue: string | null;
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

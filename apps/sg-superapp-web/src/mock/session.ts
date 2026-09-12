import type { AppModule, AuditEvent, CurrentUser, DashboardResponse, NotificationItem, RoleCode } from "../types/portal";

export const mockCurrentUser: CurrentUser = {
  id: 1,
  fullName: "Administrador S&G",
  username: "admin.sg",
  role: "ADMIN",
  isActive: true,
  lastLoginAt: null
};

const baseModules: AppModule[] = [
  { code: "dashboard", label: "Dashboard", description: "Indicadores del piloto por rol.", enabled: true, status: "Disponible" },
  { code: "employees", label: "Empleados / Guardas", description: "Maestro de empleados y guardas I2.", enabled: true, status: "Disponible" },
  { code: "positions", label: "Puestos de Servicio", description: "Listado, detalle y asignaciones I3.", enabled: true, status: "Disponible" },
  { code: "scheduling", label: "Programacion de Turnos", description: "Programacion asistida, explicable y auditable I9.", enabled: true, status: "Disponible" },
  { code: "certifications", label: "Certificaciones", description: "Firmantes y certificados laborales I4.", enabled: true, status: "Disponible" },
  { code: "courses", label: "Cursos y Acreditaciones", description: "Tipos de curso, cumplimiento y registros I5.", enabled: true, status: "Disponible" },
  { code: "alerts", label: "Alertas", description: "Generadores, exportacion y fallback de correo I6.", enabled: true, status: "Disponible" },
  { code: "imports", label: "Cargas de Datos", description: "Historial y prevalidacion de cargas I2.", enabled: true, status: "Disponible" },
  { code: "audit", label: "Auditoria", description: "Consulta transversal de eventos I7.", enabled: true, status: "Disponible" },
  { code: "settings", label: "Configuracion", description: "Proximamente / En diseno para incrementos futuros.", enabled: true, status: "Pendiente" },
  { code: "novedades", label: "Novedades", description: "Proximamente / En diseno para incrementos futuros.", enabled: true, status: "Pendiente" }
];

export const modulesByRole: Record<RoleCode, AppModule[]> = {
  ADMIN: baseModules,
  TH: baseModules.filter((module) => module.code !== "settings"),
  GERENCIA: baseModules.filter((module) => !["imports", "settings"].includes(module.code)),
  OPERACIONES: baseModules.filter((module) => !["imports", "settings", "certifications"].includes(module.code))
};

export const mockNotifications: NotificationItem[] = [
  {
    id: 1,
    targetType: "USER",
    targetKey: "admin.sg",
    title: "Portal base activo",
    body: "El shell I1 esta disponible para pruebas internas.",
    status: "UNREAD",
    sourceModule: "SYSTEM",
    severity: "INFO",
    sourceType: "SYSTEM",
    sourceId: null,
    actionUrl: null,
    createdAt: new Date().toISOString(),
    readAt: null,
    archivedAt: null,
    managedAt: null,
    managedBy: null
  },
  {
    id: 2,
    targetType: "ROLE",
    targetKey: "ADMIN",
    title: "Pendiente backend real",
    body: "Se requiere conectar autenticacion y persistencia PostgreSQL.",
    status: "UNREAD",
    sourceModule: "SYSTEM",
    severity: "WARNING",
    sourceType: "SYSTEM",
    sourceId: null,
    actionUrl: null,
    createdAt: new Date().toISOString(),
    readAt: null,
    archivedAt: null,
    managedAt: null,
    managedBy: null
  }
];

export const mockDashboard: DashboardResponse = {
  role: "ADMIN",
  generatedAt: new Date().toISOString(),
  widgets: [
    {
      id: "platform-health",
      title: "Salud del piloto",
      scope: "ADMIN",
      metric: "I1-I7",
      trend: "Cierre piloto en curso",
      severity: "SUCCESS",
      actionUrl: "/portal/dashboard"
    },
    {
      id: "training-risk",
      title: "Cursos por vencer",
      scope: "TH",
      metric: "12",
      trend: "Criticos y preventivos",
      severity: "WARNING",
      actionUrl: "/portal/courses"
    },
    {
      id: "operations-enablements",
      title: "Habilitacion operativa",
      scope: "OPERATIONS",
      metric: "88%",
      trend: "Guardas habilitados",
      severity: "INFO",
      actionUrl: "/portal/courses"
    },
    {
      id: "executive-value",
      title: "Cobertura del piloto",
      scope: "EXECUTIVE",
      metric: "7 modulos",
      trend: "Talento Humano consolidado",
      severity: "SUCCESS",
      actionUrl: null
    }
  ]
};

export const mockAuditEvents: AuditEvent[] = [
  {
    id: 1,
    occurredAt: new Date().toISOString(),
    actorUsername: "admin.sg",
    actorRole: "ADMIN",
    module: "IMPORTS",
    action: "IMPORT_CONFIRMED",
    entityType: "import_batch",
    entityId: "1",
    summary: "Carga de empleados confirmada",
    detail: {
      validRecords: 24,
      incompleteRecords: 2
    }
  },
  {
    id: 2,
    occurredAt: new Date().toISOString(),
    actorUsername: "talento.humano",
    actorRole: "TH",
    module: "CERTIFICATES",
    action: "LABOR_CERTIFICATE_GENERATED",
    entityType: "labor_certificate",
    entityId: "15",
    summary: "Certificado laboral generado",
    detail: {
      purpose: "TRAMITE_GENERAL",
      templateVersion: "I4-v1"
    }
  },
  {
    id: 3,
    occurredAt: new Date().toISOString(),
    actorUsername: "SYSTEM",
    actorRole: "SYSTEM",
    module: "NOTIFICATIONS",
    action: "CREATED",
    entityType: "notification_item",
    entityId: "42",
    summary: "Alerta de acreditacion creada",
    detail: {
      severity: "CRITICAL",
      sourceModule: "TRAINING"
    }
  }
];

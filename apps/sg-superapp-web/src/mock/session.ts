import type { AppModule, CurrentUser, NotificationItem, RoleCode } from "../types/portal";

export const mockCurrentUser: CurrentUser = {
  id: 1,
  fullName: "Administrador S&G",
  username: "admin.sg",
  role: "ADMIN",
  isActive: true,
  lastLoginAt: null
};

const baseModules: AppModule[] = [
  { code: "dashboard", label: "Dashboard", description: "Vista inicial del piloto.", enabled: true, status: "Disponible" },
  { code: "employees", label: "Empleados / Guardas", description: "Pendiente implementacion en I2.", enabled: true, status: "Pendiente" },
  { code: "positions", label: "Puestos de Servicio", description: "Pendiente implementacion en I3.", enabled: true, status: "Pendiente" },
  { code: "courses", label: "Cursos y Acreditaciones", description: "Pendiente implementacion en I5.", enabled: true, status: "Pendiente" },
  { code: "certifications", label: "Certificaciones", description: "Pendiente implementacion en I4.", enabled: true, status: "Pendiente" },
  { code: "alerts", label: "Alertas", description: "Pendiente implementacion en I6.", enabled: true, status: "Pendiente" },
  { code: "notifications", label: "Notificaciones", description: "Bandeja shell de I1.", enabled: true, status: "Disponible" },
  { code: "imports", label: "Cargas de Datos", description: "Pendiente implementacion en I2.", enabled: true, status: "Pendiente" },
  { code: "settings", label: "Configuracion", description: "Administracion base del piloto.", enabled: true, status: "Disponible" },
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
    createdAt: new Date().toISOString()
  },
  {
    id: 2,
    targetType: "ROLE",
    targetKey: "ADMIN",
    title: "Pendiente backend real",
    body: "Se requiere conectar autenticacion y persistencia PostgreSQL.",
    status: "UNREAD",
    createdAt: new Date().toISOString()
  }
];

import { NavLink, Outlet } from "react-router-dom";
import type { AppModule, CurrentUser, NotificationFilters, NotificationItem, NotificationSeverity, NotificationSourceModule, NotificationStatus } from "../../types/portal";

interface ShellLayoutProps {
  user: CurrentUser;
  modules: AppModule[];
  notifications: NotificationItem[];
  notificationFilters: NotificationFilters;
  unreadNotificationCount: number;
  source: "api" | "mock";
  onNotificationFiltersChange: (filters: NotificationFilters) => void;
  onRefreshNotifications: () => Promise<void>;
  onMarkNotificationRead: (notificationId: number) => Promise<void>;
  onArchiveNotification: (notificationId: number) => Promise<void>;
  onLogout: () => void;
}

const statusOptions: Array<{ value: NotificationStatus; label: string }> = [
  { value: "UNREAD", label: "No leidas" },
  { value: "READ", label: "Leidas" },
  { value: "ARCHIVED", label: "Archivadas" }
];

const severityOptions: Array<{ value: NotificationSeverity; label: string }> = [
  { value: "CRITICAL", label: "Critica" },
  { value: "WARNING", label: "Preventiva" },
  { value: "INFO", label: "Informativa" }
];

const moduleOptions: Array<{ value: NotificationSourceModule; label: string }> = [
  { value: "TRAINING", label: "Cursos" },
  { value: "IMPORTS", label: "Importaciones" },
  { value: "CERTIFICATES", label: "Certificados" },
  { value: "SYSTEM", label: "Sistema" }
];

function getNotificationScope(notification: NotificationItem): string {
  return notification.targetType === "USER" ? "Personal" : `Rol ${notification.targetKey}`;
}

export function ShellLayout({
  user,
  modules,
  notifications,
  notificationFilters,
  unreadNotificationCount,
  source,
  onNotificationFiltersChange,
  onRefreshNotifications,
  onMarkNotificationRead,
  onArchiveNotification,
  onLogout
}: ShellLayoutProps) {
  const updateFilters = (next: Partial<NotificationFilters>) => {
    onNotificationFiltersChange({ ...notificationFilters, ...next });
  };

  return (
    <div className="shell sentinel-console">
      <aside className="sidebar">
        <div className="brand-block">
          <p className="eyebrow">S&amp;G</p>
          <h2>Super App</h2>
          <p className="muted">Ecosistema digital unificado</p>
        </div>

        <nav className="module-nav">
          {modules.map((module) => {
            const to = module.code === "dashboard" ? "/dashboard" : `/module/${module.code}`;

            return (
              <NavLink key={module.code} to={to} className="nav-item">
                <span>{module.label}</span>
                <small>{module.status}</small>
              </NavLink>
            );
          })}
        </nav>
      </aside>

      <main className="content">
        <header className="topbar">
          <div className="topbar-title">
            <p className="eyebrow">Consola enterprise</p>
            <h1>Portal operativo S&amp;G</h1>
          </div>

          <div className="topbar-search">
            <label htmlFor="portal-search">Busqueda operativa</label>
            <input id="portal-search" type="search" placeholder="Buscar empleados, puestos o modulos..." />
          </div>

          <div className="user-block">
            <div className="notification-pill" aria-label="Notificaciones no leidas">{unreadNotificationCount}</div>
            <div>
              <strong>{user.fullName}</strong>
              <p className="muted">
                {user.username} · {user.role}
              </p>
            </div>
            <button type="button" className="ghost-button" onClick={onLogout}>
              Salir
            </button>
          </div>
        </header>

        <div className="shell-body">
          <section className="workspace-panel">
            <Outlet />
          </section>

          <aside className="notification-tray" aria-label="Bandeja de notificaciones">
            <div className="notification-tray-header">
              <div>
                <p className="eyebrow">Personales y rol</p>
                <h2>Notificaciones</h2>
                <p className="muted">{notifications.length} items desde {source === "api" ? "API" : "mock local"}.</p>
              </div>
              <button type="button" className="ghost-button" onClick={() => void onRefreshNotifications()}>
                Actualizar
              </button>
            </div>

            <div className="notification-filters" aria-label="Filtros de notificaciones">
              <label>
                Estado
                <select value={notificationFilters.status ?? ""} onChange={(event) => updateFilters({ status: event.target.value ? event.target.value as NotificationStatus : undefined })}>
                  <option value="">Todos</option>
                  {statusOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
                </select>
              </label>
              <label>
                Severidad
                <select value={notificationFilters.severity ?? ""} onChange={(event) => updateFilters({ severity: event.target.value ? event.target.value as NotificationSeverity : undefined })}>
                  <option value="">Todas</option>
                  {severityOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
                </select>
              </label>
              <label>
                Modulo
                <select value={notificationFilters.sourceModule ?? ""} onChange={(event) => updateFilters({ sourceModule: event.target.value ? event.target.value as NotificationSourceModule : undefined })}>
                  <option value="">Todos</option>
                  {moduleOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
                </select>
              </label>
            </div>

            <div className="notification-list" role="list">
              {notifications.length === 0 ? (
                <div className="panel-empty compact-empty">No hay notificaciones con los filtros actuales.</div>
              ) : notifications.map((notification) => (
                <article key={notification.id} className={`notification-row severity-${notification.severity.toLowerCase()}`} role="listitem">
                  <div className="notification-main">
                    <div className="notification-row-heading">
                      <strong>{notification.title}</strong>
                      <span className="status-chip">{notification.severity}</span>
                    </div>
                    <p>{notification.body}</p>
                    <small className="muted">{getNotificationScope(notification)} · {notification.sourceModule} · {notification.status}</small>
                  </div>
                  <div className="notification-actions">
                    <button type="button" className="ghost-button" disabled={notification.status !== "UNREAD"} onClick={() => void onMarkNotificationRead(notification.id)}>
                      Marcar leida
                    </button>
                    <button type="button" className="ghost-button" disabled={notification.status === "ARCHIVED"} onClick={() => void onArchiveNotification(notification.id)}>
                      Archivar
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </aside>
        </div>
      </main>
    </div>
  );
}

import { NavLink, Outlet } from "react-router-dom";
import type { AppModule, CurrentUser, NotificationItem } from "../../types/portal";

interface ShellLayoutProps {
  user: CurrentUser;
  modules: AppModule[];
  notifications: NotificationItem[];
  source: "api" | "mock";
  onLogout: () => void;
}

export function ShellLayout({ user, modules, notifications, source, onLogout }: ShellLayoutProps) {
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand-block">
          <p className="eyebrow">S&amp;G</p>
          <h2>Super App</h2>
          <p className="muted">Piloto TH</p>
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
          <div>
            <p className="eyebrow">Operacion interna</p>
            <h1>Portal base</h1>
          </div>

          <div className="user-block">
            <div className="notification-pill">{notifications.filter((item) => item.status === "UNREAD").length}</div>
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

        <section className="dashboard-grid">
          <article className="panel">
            <h3>Estado del portal</h3>
            <p className="muted">Shell activo con rutas protegibles, placeholders y modulos por rol.</p>
          </article>
          <article className="panel">
            <h3>Notificaciones</h3>
            <p className="muted">
              {notifications.length} items cargados desde {source === "api" ? "API" : "mock local"}.
            </p>
          </article>
          <article className="panel">
            <h3>Alcance</h3>
            <p className="muted">Sin datos simulados operativos. Solo estados vacios y estructura de navegacion.</p>
          </article>
        </section>

        <section className="workspace-panel">
          <Outlet />
        </section>
      </main>
    </div>
  );
}

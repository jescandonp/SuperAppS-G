import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { mockDashboard } from "../../mock/session";
import { fetchDashboard } from "../../services/portalApi";
import type { CurrentUser, DashboardResponse, DashboardWidget, DashboardWidgetScope } from "../../types/portal";

interface DashboardPageProps {
  currentUser: CurrentUser;
}

const scopeLabels: Record<DashboardWidgetScope, string> = {
  EXECUTIVE: "Gerencia",
  TH: "Talento Humano",
  OPERATIONS: "Operaciones",
  ADMIN: "Administrador",
  SYSTEM: "Sistema"
};

const scopeOrder: DashboardWidgetScope[] = ["EXECUTIVE", "TH", "OPERATIONS", "ADMIN", "SYSTEM"];

const scopeA11yLabels: Record<DashboardWidgetScope, string> = {
  EXECUTIVE: "scope EXECUTIVE",
  TH: "scope TH",
  OPERATIONS: "scope OPERATIONS",
  ADMIN: "scope ADMIN",
  SYSTEM: "scope SYSTEM"
};

function resolveActionUrl(actionUrl: string | null): string | null {
  if (!actionUrl) {
    return null;
  }

  if (actionUrl.startsWith("/portal/courses")) {
    return "/module/courses";
  }
  if (actionUrl.startsWith("/portal/certificates")) {
    return "/module/certifications";
  }
  if (actionUrl.startsWith("/portal/imports")) {
    return "/module/imports";
  }
  if (actionUrl.startsWith("/portal/positions")) {
    return "/module/positions";
  }
  if (actionUrl.startsWith("/portal/notifications") || actionUrl.startsWith("/portal/alerts")) {
    return "/module/alerts";
  }

  return actionUrl;
}

function getWidgetDecision(widget: DashboardWidget): string {
  if (widget.scope === "EXECUTIVE") {
    return "Lectura ejecutiva";
  }
  if (widget.scope === "TH") {
    return "Prioridad operativa TH";
  }
  if (widget.scope === "OPERATIONS") {
    return "Habilitacion y puestos";
  }
  if (widget.scope === "ADMIN") {
    return "Salud de plataforma";
  }

  return "Seguimiento del sistema";
}

function DashboardWidgetCard({ widget }: { widget: DashboardWidget }) {
  const actionUrl = resolveActionUrl(widget.actionUrl);

  return (
    <article className={`dashboard-widget dashboard-widget-${widget.severity.toLowerCase()}`} aria-label={scopeA11yLabels[widget.scope]}>
      <div className="dashboard-widget-header">
        <span className="status-chip">{scopeLabels[widget.scope]}</span>
        <span className={`dashboard-severity severity-label-${widget.severity.toLowerCase()}`}>{widget.severity}</span>
      </div>
      <div className="dashboard-widget-metric">
        <strong>{widget.metric}</strong>
        <h3>{widget.title}</h3>
      </div>
      {widget.trend ? <p>{widget.trend}</p> : <p className="muted">{getWidgetDecision(widget)}</p>}
      <div className="dashboard-widget-footer">
        <small className="muted">{getWidgetDecision(widget)}</small>
        {actionUrl ? <Link className="ghost-button dashboard-action" to={actionUrl}>Abrir</Link> : null}
      </div>
    </article>
  );
}

export function DashboardPage({ currentUser }: DashboardPageProps) {
  const [dashboard, setDashboard] = useState<DashboardResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [source, setSource] = useState<"api" | "mock">("api");

  useEffect(() => {
    let cancelled = false;

    async function loadDashboard() {
      setLoading(true);
      setErrorMessage(null);

      try {
        const response = await fetchDashboard();
        if (cancelled) {
          return;
        }
        setDashboard(response);
        setSource("api");
      } catch {
        if (cancelled) {
          return;
        }
        setDashboard({ ...mockDashboard, role: currentUser.role });
        setSource("mock");
        setErrorMessage("No fue posible cargar el dashboard desde la API. Se muestra fallback local para demo.");
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    void loadDashboard();

    return () => {
      cancelled = true;
    };
  }, [currentUser.role]);

  const widgetsByScope = useMemo(() => {
    const grouped = new Map<DashboardWidgetScope, DashboardWidget[]>();
    for (const widget of dashboard?.widgets ?? []) {
      grouped.set(widget.scope, [...(grouped.get(widget.scope) ?? []), widget]);
    }

    return scopeOrder
      .map((scope) => ({ scope, widgets: grouped.get(scope) ?? [] }))
      .filter((group) => group.widgets.length > 0);
  }, [dashboard]);

  return (
    <div className="dashboard-workspace">
      <section className="dashboard-summary-panel">
        <div>
          <p className="eyebrow">Dashboard I7</p>
          <h2>Lectura del piloto por perfil</h2>
          <p className="muted">
            {currentUser.fullName} · {currentUser.role} · datos desde {source === "api" ? "API" : "mock local"}
          </p>
        </div>
        <div className="dashboard-context">
          <span>{dashboard?.widgets.length ?? 0}</span>
          <small>widgets visibles</small>
        </div>
      </section>

      {loading ? (
        <div className="panel-empty compact-empty dashboard-loading">Cargando indicadores del dashboard...</div>
      ) : null}

      {errorMessage ? (
        <div className="dashboard-error" role="status">{errorMessage}</div>
      ) : null}

      {!loading && dashboard && dashboard.widgets.length === 0 ? (
        <div className="panel-empty compact-empty dashboard-empty">No hay widgets autorizados para este perfil.</div>
      ) : null}

      {!loading && widgetsByScope.length > 0 ? (
        <div className="dashboard-sections">
          {widgetsByScope.map((group) => (
            <section key={group.scope} className="dashboard-scope-section" aria-label={scopeA11yLabels[group.scope]}>
              <div className="dashboard-scope-heading">
                <h3>{scopeLabels[group.scope]}</h3>
                <p className="muted">{group.widgets.length} indicadores disponibles para decision.</p>
              </div>
              <div className="dashboard-widget-grid">
                {group.widgets.map((widget) => <DashboardWidgetCard key={widget.id} widget={widget} />)}
              </div>
            </section>
          ))}
        </div>
      ) : null}
    </div>
  );
}

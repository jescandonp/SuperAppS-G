import { useEffect, useMemo, useState } from "react";
import { mockAuditEvents } from "../../mock/session";
import { fetchAuditEvents } from "../../services/portalApi";
import type { AuditEvent, AuditFilters, AuditModule, CurrentUser } from "../../types/portal";

interface AuditPageProps {
  user: CurrentUser;
}

const moduleOptions: Array<{ value: AuditModule; label: string }> = [
  { value: "IMPORTS", label: "Importaciones" },
  { value: "CERTIFICATES", label: "Certificados" },
  { value: "TRAINING", label: "Cursos" },
  { value: "NOTIFICATIONS", label: "Notificaciones" },
  { value: "POSITIONS", label: "Puestos" },
  { value: "EMPLOYEES", label: "Empleados" },
  { value: "SYSTEM", label: "Sistema" }
];

function toApiDate(value: string, endOfDay = false): string | undefined {
  if (!value) {
    return undefined;
  }

  return `${value}T${endOfDay ? "23:59:59" : "00:00:00"}Z`;
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat("es-CO", {
    dateStyle: "short",
    timeStyle: "short"
  }).format(new Date(value));
}

function stringifyDetail(detail: Record<string, unknown>): string {
  return JSON.stringify(detail, null, 2);
}

export function AuditPage({ user }: AuditPageProps) {
  const [moduleFilter, setModuleFilter] = useState<AuditModule | "">("");
  const [actorFilter, setActorFilter] = useState("");
  const [fromFilter, setFromFilter] = useState("");
  const [toFilter, setToFilter] = useState("");
  const [events, setEvents] = useState<AuditEvent[]>([]);
  const [selectedEventId, setSelectedEventId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [source, setSource] = useState<"api" | "mock">("api");

  const filters: AuditFilters = useMemo(() => ({
    module: moduleFilter || undefined,
    actor: actorFilter.trim() || undefined,
    from: toApiDate(fromFilter),
    to: toApiDate(toFilter, true)
  }), [actorFilter, fromFilter, moduleFilter, toFilter]);

  useEffect(() => {
    let cancelled = false;

    async function loadAuditEvents() {
      setLoading(true);
      setErrorMessage(null);

      try {
        const response = await fetchAuditEvents(filters);
        if (cancelled) {
          return;
        }
        setEvents(response.events);
        setSelectedEventId((current) => response.events.some((event) => event.id === current) ? current : response.events[0]?.id ?? null);
        setSource("api");
      } catch {
        if (cancelled) {
          return;
        }
        const fallbackEvents = mockAuditEvents.filter((event) => {
          const moduleMatches = !filters.module || event.module === filters.module;
          const actorMatches = !filters.actor || event.actorUsername.toLowerCase().includes(filters.actor.toLowerCase());
          return moduleMatches && actorMatches;
        });
        setEvents(fallbackEvents);
        setSelectedEventId(fallbackEvents[0]?.id ?? null);
        setSource("mock");
        setErrorMessage("No fue posible cargar auditoria desde la API. Se muestra fallback local para demo.");
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    void loadAuditEvents();

    return () => {
      cancelled = true;
    };
  }, [filters]);

  const selectedEvent = events.find((event) => event.id === selectedEventId) ?? null;

  return (
    <div className="audit-workspace">
      <section className="audit-summary-panel">
        <div>
          <p className="eyebrow">Auditoria I7</p>
          <h2>Consulta transversal de eventos</h2>
          <p className="muted">
            {user.fullName} · {user.role} · datos desde {source === "api" ? "API" : "mock local"}
          </p>
        </div>
        <div className="audit-readonly-note">Sin acciones de edicion</div>
      </section>

      <section className="audit-filters" aria-label="Filtros de auditoria">
        <label>
          Modulo
          <select value={moduleFilter} onChange={(event) => setModuleFilter(event.target.value as AuditModule | "")}>
            <option value="">Todos</option>
            {moduleOptions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label>
          Actor
          <input value={actorFilter} onChange={(event) => setActorFilter(event.target.value)} placeholder="usuario o SYSTEM" />
        </label>
        <label>
          Desde
          <input type="date" value={fromFilter} onChange={(event) => setFromFilter(event.target.value)} />
        </label>
        <label>
          Hasta
          <input type="date" value={toFilter} onChange={(event) => setToFilter(event.target.value)} />
        </label>
      </section>

      {loading ? <div className="panel-empty compact-empty audit-loading">Cargando eventos de auditoria...</div> : null}
      {errorMessage ? <div className="audit-error" role="status">{errorMessage}</div> : null}
      {!loading && events.length === 0 ? <div className="panel-empty compact-empty audit-empty">No hay eventos con los filtros actuales.</div> : null}

      {!loading && events.length > 0 ? (
        <section className="audit-grid">
          <div className="audit-table" role="table" aria-label="Tabla compacta de eventos de auditoria">
            <div className="audit-table-header" role="row">
              <span>Fecha</span>
              <span>Modulo</span>
              <span>Actor</span>
              <span>Accion</span>
              <span>Entidad</span>
            </div>
            {events.map((event) => (
              <button
                key={event.id}
                type="button"
                className={`audit-row ${event.id === selectedEventId ? "selected" : ""}`}
                onClick={() => setSelectedEventId(event.id)}
                role="row"
              >
                <span>{formatDateTime(event.occurredAt)}</span>
                <span>{event.module}</span>
                <span>{event.actorUsername}</span>
                <span>{event.action}</span>
                <span>{event.entityType}{event.entityId ? ` #${event.entityId}` : ""}</span>
              </button>
            ))}
          </div>

          <aside className="audit-detail-panel" aria-label="Detalle estructurado de auditoria">
            {selectedEvent ? (
              <>
                <div className="panel-header compact-header">
                  <div>
                    <p className="eyebrow">{selectedEvent.module}</p>
                    <h3>{selectedEvent.summary}</h3>
                  </div>
                  <span className="status-chip">{selectedEvent.actorRole ?? "SIN_ROL"}</span>
                </div>
                <dl className="audit-detail-list">
                  <div>
                    <dt>Fecha</dt>
                    <dd>{formatDateTime(selectedEvent.occurredAt)}</dd>
                  </div>
                  <div>
                    <dt>Actor</dt>
                    <dd>{selectedEvent.actorUsername}</dd>
                  </div>
                  <div>
                    <dt>Accion</dt>
                    <dd>{selectedEvent.action}</dd>
                  </div>
                  <div>
                    <dt>Entidad</dt>
                    <dd>{selectedEvent.entityType}{selectedEvent.entityId ? ` #${selectedEvent.entityId}` : ""}</dd>
                  </div>
                </dl>
                <pre className="audit-detail-json">{stringifyDetail(selectedEvent.detail)}</pre>
              </>
            ) : (
              <div className="panel-empty compact-empty">Selecciona un evento para revisar el detalle.</div>
            )}
          </aside>
        </section>
      ) : null}
    </div>
  );
}

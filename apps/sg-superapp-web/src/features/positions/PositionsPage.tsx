import { useEffect, useState } from "react";
import { createServicePosition, fetchServicePositionAssignments, fetchServicePositionDetail, fetchServicePositions, inactivateServicePosition, updateServicePosition } from "../../services/portalApi";
import type { CurrentUser, PositionAssignment, ServicePosition, ServicePositionRequest, ServicePositionStatus } from "../../types/portal";

interface PositionsPageProps {
  user: CurrentUser;
}

function formatDate(value: string | null): string {
  if (!value) {
    return "Vigente";
  }

  return new Intl.DateTimeFormat("es-CO", { dateStyle: "medium" }).format(new Date(value));
}

function getStatusClass(status: ServicePosition["status"] | PositionAssignment["status"]): string {
  return status === "ACTIVO" || status === "VIGENTE" ? "status-active" : "status-retired";
}

export function PositionsPage({ user }: PositionsPageProps) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<ServicePositionStatus | "">("");
  const [positions, setPositions] = useState<ServicePosition[]>([]);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [selectedPosition, setSelectedPosition] = useState<ServicePosition | null>(null);
  const [assignments, setAssignments] = useState<PositionAssignment[]>([]);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [actionPending, setActionPending] = useState(false);
  const [formMode, setFormMode] = useState<"edit" | "create">("edit");
  const [formCode, setFormCode] = useState("");
  const [formName, setFormName] = useState("");
  const [formClientText, setFormClientText] = useState("");
  const [formLocationText, setFormLocationText] = useState("");
  const [formNotes, setFormNotes] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    let ignore = false;

    async function loadPositions() {
      setLoading(true);
      setErrorMessage(null);

      try {
        const data = await fetchServicePositions({ search, status: status || undefined });
        if (ignore) {
          return;
        }

        setPositions(data);
        if (data.length === 0) {
          setSelectedId(null);
          setSelectedPosition(null);
          setAssignments([]);
          return;
        }

        const nextId = selectedId !== null && data.some((position) => position.id === selectedId)
          ? selectedId
          : data[0].id;
        setSelectedId(nextId);
      } catch (error) {
        if (!ignore) {
          setErrorMessage(error instanceof Error ? error.message : "No fue posible cargar puestos de servicio.");
          setPositions([]);
          setSelectedId(null);
          setSelectedPosition(null);
          setAssignments([]);
        }
      } finally {
        if (!ignore) {
          setLoading(false);
        }
      }
    }

    void loadPositions();

    return () => {
      ignore = true;
    };
  }, [search, status, selectedId, refreshKey]);

  useEffect(() => {
    if (selectedId === null) {
      return;
    }

    const positionId = selectedId;
    let ignore = false;

    async function loadDetail() {
      setDetailLoading(true);

      try {
        const [position, positionAssignments] = await Promise.all([
          fetchServicePositionDetail(positionId),
          fetchServicePositionAssignments(positionId)
        ]);

        if (!ignore) {
          setSelectedPosition(position);
          setAssignments(positionAssignments);
        }
      } catch {
        if (!ignore) {
          setSelectedPosition(null);
          setAssignments([]);
        }
      } finally {
        if (!ignore) {
          setDetailLoading(false);
        }
      }
    }

    void loadDetail();

    return () => {
      ignore = true;
    };
  }, [selectedId]);

  useEffect(() => {
    if (!selectedPosition || formMode !== "edit") {
      return;
    }

    setFormCode(selectedPosition.code || "");
    setFormName(selectedPosition.name);
    setFormClientText(selectedPosition.clientText || "");
    setFormLocationText(selectedPosition.locationText || "");
    setFormNotes(selectedPosition.notes || "");
  }, [selectedPosition, formMode]);

  const canManagePositions = user.role === "ADMIN" || user.role === "TH";
  const currentAssignments = assignments.filter((assignment) => assignment.status === "VIGENTE");
  const historicalAssignments = assignments.filter((assignment) => assignment.status !== "VIGENTE");

  function clearForm() {
    setFormCode("");
    setFormName("");
    setFormClientText("");
    setFormLocationText("");
    setFormNotes("");
  }

  function buildRequest(): ServicePositionRequest | null {
    const name = formName.trim();
    if (!name) {
      setActionMessage("El nombre del puesto es obligatorio.");
      return null;
    }

    return {
      code: formCode.trim() || null,
      name,
      clientText: formClientText.trim() || null,
      locationText: formLocationText.trim() || null,
      notes: formNotes.trim() || null
    };
  }

  async function reloadPosition(positionId: number) {
    const [position, positionAssignments] = await Promise.all([
      fetchServicePositionDetail(positionId),
      fetchServicePositionAssignments(positionId)
    ]);
    setSelectedPosition(position);
    setAssignments(positionAssignments);
    setPositions((current) => current.map((item) => item.id === position.id ? position : item));
  }

  async function savePosition() {
    if (!canManagePositions) {
      return;
    }

    const request = buildRequest();
    if (!request) {
      return;
    }

    setActionPending(true);
    setActionMessage(null);

    try {
      if (formMode === "create") {
        const created = await createServicePosition(request);
        setSelectedId(created.id);
        setSelectedPosition(created);
        setAssignments([]);
        setFormMode("edit");
        setRefreshKey((current) => current + 1);
        setActionMessage("Puesto creado.");
        return;
      }

      if (!selectedPosition) {
        setActionMessage("Seleccione un puesto para editar.");
        return;
      }

      const updated = await updateServicePosition(selectedPosition.id, request);
      setSelectedPosition(updated);
      setPositions((current) => current.map((item) => item.id === updated.id ? updated : item));
      setActionMessage("Puesto actualizado.");
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : "No fue posible guardar el puesto.");
    } finally {
      setActionPending(false);
    }
  }

  async function deactivateSelectedPosition() {
    if (!canManagePositions || !selectedPosition) {
      return;
    }

    if (!window.confirm("¿Inactivar este puesto de servicio?")) {
      return;
    }

    setActionPending(true);
    setActionMessage(null);

    try {
      const updated = await inactivateServicePosition(selectedPosition.id);
      setSelectedPosition(updated);
      setPositions((current) => current.map((item) => item.id === updated.id ? updated : item));
      await reloadPosition(updated.id);
      setActionMessage("Puesto inactivado.");
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : "No fue posible inactivar el puesto.");
    } finally {
      setActionPending(false);
    }
  }

  return (
    <div className="employees-workspace">
      <div className="employees-toolbar">
        <div>
          <p className="eyebrow">I3 en curso</p>
          <h2>Puestos de servicio</h2>
        </div>
        <div className="toolbar-filters positions-filters">
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Buscar por nombre, codigo o cliente" />
          <select value={status} onChange={(event) => setStatus(event.target.value as ServicePositionStatus | "")}>
            <option value="">Todos los estados</option>
            <option value="ACTIVO">Activos</option>
            <option value="INACTIVO">Inactivos</option>
          </select>
          {canManagePositions ? (
            <button
              type="button"
              className="secondary-action"
              onClick={() => {
                setFormMode("create");
                setSelectedId(null);
                setSelectedPosition(null);
                setAssignments([]);
                clearForm();
                setActionMessage(null);
              }}
            >
              Nuevo puesto
            </button>
          ) : null}
        </div>
      </div>

      {errorMessage ? <div className="panel-empty">{errorMessage}</div> : null}

      <div className="employees-grid">
        <section className="panel employee-list-panel">
          <div className="panel-header">
            <h3>Listado</h3>
            <span>{loading ? "Cargando..." : `${positions.length} puestos`}</span>
          </div>

          <div className="employee-table">
            {positions.map((position) => (
              <button
                key={position.id}
                type="button"
                className={position.id === selectedId ? "employee-row selected" : "employee-row"}
                onClick={() => setSelectedId(position.id)}
              >
                <div>
                  <strong>{position.name}</strong>
                  <p className="muted">
                    {position.code || "Sin codigo"} · {position.clientText || "Sin cliente"} · {position.locationText || "Sin ubicacion"}
                  </p>
                </div>
                <div className="employee-row-meta">
                  <span className={`status-chip ${getStatusClass(position.status)}`}>{position.status}</span>
                  <small>{position.activeAssignmentsCount} vigentes</small>
                </div>
              </button>
            ))}

            {!loading && positions.length === 0 ? <div className="panel-empty">No hay puestos para los filtros actuales.</div> : null}
          </div>
        </section>

        <aside className="panel employee-detail-panel">
          <div className="panel-header">
            <h3>Detalle</h3>
            <span>{detailLoading ? "Cargando..." : selectedPosition ? "Disponible" : "Sin seleccion"}</span>
          </div>

          {selectedPosition || formMode === "create" ? (
            <div className="employee-detail">
              {selectedPosition ? (
                <>
                  <h4>{selectedPosition.name}</h4>
                  <p className="muted">
                    {selectedPosition.code || "Sin codigo"} · {selectedPosition.clientText || "Sin cliente"}
                  </p>
                </>
              ) : (
                <>
                  <h4>Nuevo puesto de servicio</h4>
                  <p className="muted">Registro maestro con cliente como texto libre.</p>
                </>
              )}

              {selectedPosition ? <dl>
                <div>
                  <dt>Estado</dt>
                  <dd><span className={`status-chip ${getStatusClass(selectedPosition.status)}`}>{selectedPosition.status}</span></dd>
                </div>
                <div>
                  <dt>Ubicacion</dt>
                  <dd>{selectedPosition.locationText || "No definida"}</dd>
                </div>
                <div>
                  <dt>Asignados vigentes</dt>
                  <dd>{selectedPosition.activeAssignmentsCount}</dd>
                </div>
                <div>
                  <dt>Observaciones</dt>
                  <dd>{selectedPosition.notes || "Sin observaciones"}</dd>
                </div>
              </dl> : null}

              {canManagePositions ? (
                <div className="position-form">
                  <div className="panel-header compact-header">
                    <h4>{formMode === "create" ? "Crear puesto" : "Editar puesto"}</h4>
                    {formMode === "create" && positions.length > 0 ? (
                      <button
                        type="button"
                        className="ghost-button"
                        onClick={() => {
                          setFormMode("edit");
                          setSelectedId(positions[0].id);
                        }}
                      >
                        Cancelar
                      </button>
                    ) : null}
                  </div>
                  <input value={formCode} onChange={(event) => setFormCode(event.target.value)} placeholder="Codigo opcional" />
                  <input value={formName} onChange={(event) => setFormName(event.target.value)} placeholder="Nombre obligatorio" />
                  <input value={formClientText} onChange={(event) => setFormClientText(event.target.value)} placeholder="Cliente texto libre" />
                  <input value={formLocationText} onChange={(event) => setFormLocationText(event.target.value)} placeholder="Ubicacion" />
                  <textarea value={formNotes} onChange={(event) => setFormNotes(event.target.value)} placeholder="Observaciones" />
                  <div className="position-form-actions">
                    <button type="button" onClick={() => void savePosition()} disabled={actionPending}>
                      {actionPending ? "Guardando..." : formMode === "create" ? "Crear puesto" : "Guardar cambios"}
                    </button>
                    {selectedPosition && selectedPosition.status === "ACTIVO" && formMode === "edit" ? (
                      <button type="button" className="danger-action" onClick={() => void deactivateSelectedPosition()} disabled={actionPending}>
                        Inactivar
                      </button>
                    ) : null}
                  </div>
                  {actionMessage ? <p className="muted">{actionMessage}</p> : null}
                </div>
              ) : null}

              {selectedPosition ? <div className="position-detail-section">
                <div className="panel-header compact-header">
                  <h4>Asignaciones vigentes</h4>
                  <span>{currentAssignments.length}</span>
                </div>
                {currentAssignments.map((assignment) => (
                  <article key={assignment.id} className="assignment-card">
                    <div>
                      <strong>Empleado #{assignment.employeeId}</strong>
                      <p className="muted">{formatDate(assignment.startDate)} · {assignment.createdBy || "sin usuario"}</p>
                    </div>
                    <span className={`status-chip ${getStatusClass(assignment.status)}`}>{assignment.status}</span>
                  </article>
                ))}
                {currentAssignments.length === 0 ? <div className="panel-empty compact-empty">Sin asignaciones vigentes.</div> : null}
              </div> : null}

              {selectedPosition ? <div className="position-detail-section">
                <div className="panel-header compact-header">
                  <h4>Historial basico</h4>
                  <span>{historicalAssignments.length}</span>
                </div>
                {historicalAssignments.map((assignment) => (
                  <article key={assignment.id} className="assignment-card">
                    <div>
                      <strong>Empleado #{assignment.employeeId}</strong>
                      <p className="muted">
                        {formatDate(assignment.startDate)} - {formatDate(assignment.endDate)} · {assignment.changeReason || "sin motivo"}
                      </p>
                    </div>
                    <span className={`status-chip ${getStatusClass(assignment.status)}`}>{assignment.status}</span>
                  </article>
                ))}
                {historicalAssignments.length === 0 ? <div className="panel-empty compact-empty">Sin historial finalizado.</div> : null}
              </div> : null}

              <p className="muted role-note">
                {user.role === "ADMIN" || user.role === "TH"
                  ? "Gestion de puestos disponible para el rol actual."
                  : "Rol de consulta sin acciones de edicion."}
              </p>
            </div>
          ) : (
            <div className="panel-empty">Seleccione un puesto para ver su detalle.</div>
          )}
        </aside>
      </div>
    </div>
  );
}

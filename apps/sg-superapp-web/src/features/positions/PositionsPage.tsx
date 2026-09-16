import { useEffect, useRef, useState } from "react";
import { createPositionAssignment, createServicePosition, fetchEmployees, fetchServicePositionAssignments, fetchServicePositionDetail, fetchServicePositionsPage, finalizePositionAssignment, inactivateServicePosition, PortalApiError, updateServicePosition } from "../../services/portalApi";
import type { CurrentUser, EmployeeSummary, PositionAssignment, ServicePosition, ServicePositionRequest, ServicePositionStatus } from "../../types/portal";
import { Modal } from "../../components/Modal";

function describeDetailError(error: unknown): string {
  if (error instanceof PortalApiError && error.status === 404) {
    return "Este puesto ya no existe o fue removido.";
  }

  if (error instanceof PortalApiError && error.status === 403) {
    return "No tiene permiso para ver el detalle de este puesto.";
  }

  return error instanceof Error ? error.message : "No fue posible cargar el detalle del puesto.";
}

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

type FinalizeTarget = {
  assignment: PositionAssignment;
  position: ServicePosition;
};

export function PositionsPage({ user }: PositionsPageProps) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState<ServicePositionStatus | "">("");
  const [positions, setPositions] = useState<ServicePosition[]>([]);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [totalCount, setTotalCount] = useState(0);
  const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const selectedIdRef = useRef<number | null>(null);
  const [selectedPosition, setSelectedPosition] = useState<ServicePosition | null>(null);
  const [assignments, setAssignments] = useState<PositionAssignment[]>([]);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [detailErrorMessage, setDetailErrorMessage] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [actionPending, setActionPending] = useState(false);
  const [formMode, setFormMode] = useState<"edit" | "create">("edit");
  const [formCode, setFormCode] = useState("");
  const [formName, setFormName] = useState("");
  const [formClientText, setFormClientText] = useState("");
  const [formLocationText, setFormLocationText] = useState("");
  const [formNotes, setFormNotes] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);
  const [isPositionModalOpen, setIsPositionModalOpen] = useState(false);
  const [isAssignEmployeeModalOpen, setIsAssignEmployeeModalOpen] = useState(false);
  const [employeeSearch, setEmployeeSearch] = useState("");
  const [employeeOptions, setEmployeeOptions] = useState<EmployeeSummary[]>([]);
  const [assignEmployeeId, setAssignEmployeeId] = useState("");
  const [assignStartDate, setAssignStartDate] = useState("");
  const [assignReason, setAssignReason] = useState("");
  const [assignNotes, setAssignNotes] = useState("");
  const [assignPending, setAssignPending] = useState(false);
  const [assignMessage, setAssignMessage] = useState<string | null>(null);
  const [finalizeTarget, setFinalizeTarget] = useState<FinalizeTarget | null>(null);
  const finalizeTargetRef = useRef<FinalizeTarget | null>(null);
  const [finalizeEndDate, setFinalizeEndDate] = useState("");
  const [finalizeReason, setFinalizeReason] = useState("");
  const [finalizeNotes, setFinalizeNotes] = useState("");
  const [finalizePending, setFinalizePending] = useState(false);
  const [finalizeMessage, setFinalizeMessage] = useState<string | null>(null);

  function closeFinalizeModal() {
    finalizeTargetRef.current = null;
    setFinalizeTarget(null);
    setFinalizeEndDate("");
    setFinalizeReason("");
    setFinalizeNotes("");
    setFinalizePending(false);
    setFinalizeMessage(null);
  }

  function selectPosition(positionId: number | null) {
    if (selectedIdRef.current === positionId) {
      return;
    }

    selectedIdRef.current = positionId;
    closeFinalizeModal();
    setSelectedId(positionId);
    setSelectedPosition(null);
    setAssignments([]);
    setDetailErrorMessage(null);
  }

  useEffect(() => {
    setPage(1);
  }, [search, status]);

  useEffect(() => {
    let ignore = false;

    async function loadPositions() {
      setLoading(true);
      setErrorMessage(null);

      try {
        const { items, totalCount: total } = await fetchServicePositionsPage({ search, status: status || undefined, page, pageSize });
        if (ignore) {
          return;
        }

        setPositions(items);
        setTotalCount(total);
        if (items.length === 0) {
          selectPosition(null);
          return;
        }

        const nextId = selectedId !== null && items.some((position) => position.id === selectedId)
          ? selectedId
          : items[0].id;
        selectPosition(nextId);
      } catch (error) {
        if (!ignore) {
          setErrorMessage(error instanceof Error ? error.message : "No fue posible cargar puestos de servicio.");
          setPositions([]);
          setTotalCount(0);
          selectPosition(null);
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
  }, [search, status, selectedId, refreshKey, page, pageSize]);

  useEffect(() => {
    if (!isAssignEmployeeModalOpen) {
      return;
    }

    let ignore = false;
    async function loadEmployeeOptions() {
      try {
        const data = await fetchEmployees({ search: employeeSearch || undefined, status: "ACTIVO" });
        if (!ignore) {
          setEmployeeOptions(data.slice(0, 20));
        }
      } catch {
        if (!ignore) {
          setEmployeeOptions([]);
        }
      }
    }

    void loadEmployeeOptions();
    return () => {
      ignore = true;
    };
  }, [isAssignEmployeeModalOpen, employeeSearch]);

  useEffect(() => {
    if (selectedId === null) {
      return;
    }

    const positionId = selectedId;
    let ignore = false;

    closeFinalizeModal();

    async function loadDetail() {
      setDetailLoading(true);
      setDetailErrorMessage(null);

      try {
        const [position, positionAssignments] = await Promise.all([
          fetchServicePositionDetail(positionId),
          fetchServicePositionAssignments(positionId)
        ]);

        if (!ignore) {
          setSelectedPosition(position);
          setAssignments(positionAssignments);
        }
      } catch (error) {
        if (!ignore) {
          setSelectedPosition(null);
          setAssignments([]);
          setDetailErrorMessage(describeDetailError(error));
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

  function openCreateModal() {
    setFormMode("create");
    clearForm();
    setActionMessage(null);
    setIsPositionModalOpen(true);
  }

  function openEditModal() {
    if (!selectedPosition) {
      return;
    }

    setFormMode("edit");
    setFormCode(selectedPosition.code || "");
    setFormName(selectedPosition.name);
    setFormClientText(selectedPosition.clientText || "");
    setFormLocationText(selectedPosition.locationText || "");
    setFormNotes(selectedPosition.notes || "");
    setActionMessage(null);
    setIsPositionModalOpen(true);
  }

  function openAssignEmployeeModal() {
    setEmployeeSearch("");
    setEmployeeOptions([]);
    setAssignEmployeeId("");
    setAssignStartDate(new Date().toISOString().slice(0, 10));
    setAssignReason("");
    setAssignNotes("");
    setAssignMessage(null);
    setIsAssignEmployeeModalOpen(true);
  }

  async function assignEmployee() {
    if (!selectedPosition) {
      return;
    }

    if (!assignEmployeeId || !assignStartDate) {
      setAssignMessage("Seleccione un empleado y una fecha de inicio.");
      return;
    }

    setAssignPending(true);
    setAssignMessage(null);
    try {
      await createPositionAssignment(Number(assignEmployeeId), {
        positionId: selectedPosition.id,
        startDate: assignStartDate,
        changeReason: assignReason.trim() || null,
        notes: assignNotes.trim() || null
      });
      await reloadPosition(selectedPosition.id);
      setIsAssignEmployeeModalOpen(false);
    } catch (error) {
      setAssignMessage(error instanceof Error ? error.message : "No fue posible crear la asignacion.");
    } finally {
      setAssignPending(false);
    }
  }

  function openFinalizeModal(assignment: PositionAssignment) {
    if (!selectedPosition || assignment.status !== "VIGENTE") {
      return;
    }

    setFinalizeEndDate(new Date().toISOString().slice(0, 10));
    setFinalizeReason("");
    setFinalizeNotes("");
    setFinalizeMessage(null);
    const target = { assignment, position: selectedPosition };
    finalizeTargetRef.current = target;
    setFinalizeTarget(target);
  }

  async function finalizeAssignment() {
    const target = finalizeTargetRef.current;
    if (!target) {
      return;
    }

    if (!finalizeEndDate) {
      setFinalizeMessage("La fecha fin es obligatoria.");
      return;
    }

    setFinalizePending(true);
    setFinalizeMessage(null);
    try {
      await finalizePositionAssignment(target.assignment.id, {
        endDate: finalizeEndDate,
        changeReason: finalizeReason.trim() || null,
        notes: finalizeNotes.trim() || null
      });
      await reloadPosition(target.position.id);
      if (finalizeTargetRef.current === target) {
        closeFinalizeModal();
      }
    } catch (error) {
      if (finalizeTargetRef.current === target) {
        setFinalizeMessage(error instanceof Error ? error.message : "No fue posible finalizar la asignacion.");
      }
    } finally {
      if (finalizeTargetRef.current === target) {
        setFinalizePending(false);
      }
    }
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
    setPositions((current) => current.map((item) => item.id === position.id ? position : item));
    if (selectedIdRef.current === positionId) {
      setSelectedPosition(position);
      setAssignments(positionAssignments);
    }
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
        selectPosition(created.id);
        setSelectedPosition(created);
        setAssignments([]);
        setRefreshKey((current) => current + 1);
        setIsPositionModalOpen(false);
        return;
      }

      if (!selectedPosition) {
        setActionMessage("Seleccione un puesto para editar.");
        return;
      }

      const updated = await updateServicePosition(selectedPosition.id, request);
      setSelectedPosition(updated);
      setPositions((current) => current.map((item) => item.id === updated.id ? updated : item));
      setIsPositionModalOpen(false);
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
            <button type="button" className="secondary-action" onClick={openCreateModal}>
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
            <span>{loading ? "Cargando..." : `${totalCount} puestos`}</span>
          </div>

          <div className="employee-table">
            {positions.map((position) => (
              <button
                key={position.id}
                type="button"
                className={position.id === selectedId ? "employee-row selected" : "employee-row"}
                onClick={() => selectPosition(position.id)}
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

          <div className="pagination-controls">
            <button type="button" className="ghost-button" disabled={page <= 1} onClick={() => setPage((current) => current - 1)}>
              Anterior
            </button>
            <span className="muted">{totalCount === 0 ? "Sin resultados" : `Página ${page} de ${totalPages}`}</span>
            <button type="button" className="ghost-button" disabled={page >= totalPages} onClick={() => setPage((current) => current + 1)}>
              Siguiente
            </button>
            <select value={pageSize} onChange={(event) => { setPageSize(Number(event.target.value)); setPage(1); }}>
              <option value={25}>25 por página</option>
              <option value={50}>50 por página</option>
              <option value={100}>100 por página</option>
            </select>
          </div>
        </section>

        <aside className="panel employee-detail-panel">
          <div className="panel-header">
            <h3>Detalle</h3>
            <span>{detailLoading ? "Cargando..." : selectedPosition ? "Disponible" : detailErrorMessage ? "Error" : "Sin seleccion"}</span>
          </div>

          {detailErrorMessage ? <div className="panel-empty">{detailErrorMessage}</div> : null}

          {selectedPosition ? (
            <div className="employee-detail">
              <h4>{selectedPosition.name}</h4>
              <p className="muted">
                {selectedPosition.code || "Sin codigo"} · {selectedPosition.clientText || "Sin cliente"}
              </p>

              {canManagePositions ? (
                <div className="position-form-actions">
                  <button type="button" onClick={openEditModal}>Editar puesto</button>
                </div>
              ) : null}

              {canManagePositions && selectedPosition.status === "ACTIVO" ? (
                <div className="position-form-actions">
                  <button type="button" onClick={openAssignEmployeeModal}>Asignar empleado</button>
                </div>
              ) : null}

              {isAssignEmployeeModalOpen ? (
                <Modal title="Asignar empleado" onClose={() => setIsAssignEmployeeModalOpen(false)}>
                  <div className="position-form">
                    {assignMessage ? <p className="muted">{assignMessage}</p> : null}
                    <input value={employeeSearch} onChange={(event) => setEmployeeSearch(event.target.value)} placeholder="Buscar empleado" />
                    <select value={assignEmployeeId} onChange={(event) => setAssignEmployeeId(event.target.value)}>
                      <option value="">Seleccione empleado</option>
                      {employeeOptions.map((employee) => (
                        <option key={employee.id} value={employee.id}>
                          {employee.fullName} · {employee.identificationNumber} · {employee.employmentStatus}
                        </option>
                      ))}
                    </select>
                    <input type="date" value={assignStartDate} onChange={(event) => setAssignStartDate(event.target.value)} />
                    <input value={assignReason} onChange={(event) => setAssignReason(event.target.value)} placeholder="Motivo opcional" />
                    <textarea value={assignNotes} onChange={(event) => setAssignNotes(event.target.value)} placeholder="Notas opcionales" />
                    <div className="position-form-actions">
                      <button type="button" onClick={() => void assignEmployee()} disabled={assignPending}>
                        {assignPending ? "Asignando..." : "Asignar"}
                      </button>
                    </div>
                  </div>
                </Modal>
              ) : null}

              {finalizeTarget ? (
                <Modal title="Finalizar asignación" onClose={closeFinalizeModal}>
                  <div className="position-form">
                    {finalizeMessage ? <p className="muted">{finalizeMessage}</p> : null}
                    <p className="muted">
                      Empleado: {finalizeTarget.assignment.employeeFullName} · Documento: {finalizeTarget.assignment.employeeIdentificationNumber}
                    </p>
                    <p className="muted">
                      Puesto: {finalizeTarget.position.name} · {finalizeTarget.position.code || "Sin codigo"} · {finalizeTarget.position.clientText || "Sin cliente"}
                    </p>
                    <input type="date" value={finalizeEndDate} onChange={(event) => setFinalizeEndDate(event.target.value)} />
                    <input value={finalizeReason} onChange={(event) => setFinalizeReason(event.target.value)} placeholder="Motivo opcional" />
                    <textarea value={finalizeNotes} onChange={(event) => setFinalizeNotes(event.target.value)} placeholder="Notas opcionales" />
                    <div className="position-form-actions">
                      <button type="button" onClick={() => void finalizeAssignment()} disabled={finalizePending}>
                        {finalizePending ? "Finalizando..." : "Finalizar"}
                      </button>
                    </div>
                  </div>
                </Modal>
              ) : null}

              <dl>
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
              </dl>

              {selectedPosition ? <div className="position-detail-section">
                <div className="panel-header compact-header">
                  <h4>Asignaciones vigentes</h4>
                  <span>{currentAssignments.length}</span>
                </div>
                {currentAssignments.map((assignment) => (
                  <article key={assignment.id} className="assignment-card">
                    <div>
                      <strong>{assignment.employeeFullName}</strong>
                      <p className="muted">{assignment.employeeIdentificationNumber} · {formatDate(assignment.startDate)} · {assignment.createdBy || "sin usuario"}</p>
                    </div>
                    <div className="employee-row-meta">
                      <span className={`status-chip ${getStatusClass(assignment.status)}`}>{assignment.status}</span>
                      {canManagePositions ? (
                        <button type="button" className="ghost-button" onClick={() => openFinalizeModal(assignment)}>
                          Finalizar
                        </button>
                      ) : null}
                    </div>
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
                      <strong>{assignment.employeeFullName}</strong>
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

      {isPositionModalOpen ? (
        <Modal title={formMode === "create" ? "Crear puesto" : "Editar puesto"} onClose={() => setIsPositionModalOpen(false)}>
          <div className="position-form">
            {actionMessage ? <p className="muted">{actionMessage}</p> : null}
            <input value={formCode} onChange={(event) => setFormCode(event.target.value)} placeholder="Codigo opcional" />
            <input value={formName} onChange={(event) => setFormName(event.target.value)} placeholder="Nombre obligatorio" />
            <input value={formClientText} onChange={(event) => setFormClientText(event.target.value)} placeholder="Cliente texto libre" />
            <input value={formLocationText} onChange={(event) => setFormLocationText(event.target.value)} placeholder="Ubicacion" />
            <textarea value={formNotes} onChange={(event) => setFormNotes(event.target.value)} placeholder="Observaciones" />
            <div className="position-form-actions">
              <button type="button" onClick={() => void savePosition()} disabled={actionPending}>
                {actionPending ? "Guardando..." : formMode === "create" ? "Crear puesto" : "Guardar cambios"}
              </button>
              {selectedPosition?.status === "ACTIVO" && formMode === "edit" ? (
                <button type="button" className="danger-action" onClick={() => void deactivateSelectedPosition()} disabled={actionPending}>
                  Inactivar
                </button>
              ) : null}
            </div>
          </div>
        </Modal>
      ) : null}
    </div>
  );
}

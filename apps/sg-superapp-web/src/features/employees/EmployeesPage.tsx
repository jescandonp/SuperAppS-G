import { useEffect, useState } from "react";
import {
  createPositionAssignment,
  fetchEmployeeDetail,
  fetchEmployeePositionAssignments,
  fetchEmployees,
  fetchServicePositions,
  finalizePositionAssignment,
  updateEmployee
} from "../../services/portalApi";
import type { CurrentUser, EmployeeDetail, EmployeeSummary, PositionAssignment, ServicePosition } from "../../types/portal";

function formatCurrency(value: number | null): string {
  if (value === null) {
    return "Sin salario";
  }

  return new Intl.NumberFormat("es-CO", {
    style: "currency",
    currency: "COP",
    maximumFractionDigits: 0
  }).format(value);
}

function normalizeText(value: string | null): string {
  return (value || "").trim().toLocaleLowerCase("es-CO");
}

interface EmployeesPageProps {
  user: CurrentUser;
}

export function EmployeesPage({ user }: EmployeesPageProps) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [completeness, setCompleteness] = useState("");
  const [employees, setEmployees] = useState<EmployeeSummary[]>([]);
  const [selectedEmployee, setSelectedEmployee] = useState<EmployeeDetail | null>(null);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [editFullName, setEditFullName] = useState("");
  const [editEmploymentStatus, setEditEmploymentStatus] = useState<"ACTIVO" | "RETIRADO">("ACTIVO");
  const [editJobTitle, setEditJobTitle] = useState("");
  const [editHireDate, setEditHireDate] = useState("");
  const [editTerminationDate, setEditTerminationDate] = useState("");
  const [editTerminationReason, setEditTerminationReason] = useState("");
  const [editContractType, setEditContractType] = useState("");
  const [editNotes, setEditNotes] = useState("");
  const [editSalary, setEditSalary] = useState("");
  const [editSalaryEffectiveFrom, setEditSalaryEffectiveFrom] = useState("");
  const [positionAssignments, setPositionAssignments] = useState<PositionAssignment[]>([]);
  const [availablePositions, setAvailablePositions] = useState<ServicePosition[]>([]);
  const [assignmentPositionId, setAssignmentPositionId] = useState("");
  const [assignmentStartDate, setAssignmentStartDate] = useState("");
  const [assignmentReason, setAssignmentReason] = useState("");
  const [assignmentNotes, setAssignmentNotes] = useState("");
  const [finalizeEndDate, setFinalizeEndDate] = useState("");
  const [finalizeReason, setFinalizeReason] = useState("");
  const [finalizeNotes, setFinalizeNotes] = useState("");
  const [assignmentMessage, setAssignmentMessage] = useState<string | null>(null);
  const [assignmentPending, setAssignmentPending] = useState(false);
  const canManageAssignments = user.role === "ADMIN" || user.role === "TH";
  const currentAssignment = positionAssignments.find((assignment) => assignment.status === "VIGENTE") || null;
  const importedPositionText = selectedEmployee?.currentServicePositionText || null;
  const normalizedPositionName = selectedEmployee?.currentServicePositionName || null;
  const hasDifferentPositionReference =
    normalizeText(importedPositionText) !== "" &&
    normalizeText(normalizedPositionName) !== "" &&
    normalizeText(importedPositionText) !== normalizeText(normalizedPositionName);

  useEffect(() => {
    let ignore = false;

    async function loadEmployees() {
      setLoading(true);
      setErrorMessage(null);

      try {
        const data = await fetchEmployees({ search, status, jobTitle, completeness });
        if (ignore) {
          return;
        }

        setEmployees(data);

        if (data.length === 0) {
          setSelectedId(null);
          setSelectedEmployee(null);
          return;
        }

        const nextId = selectedId !== null && data.some((employee) => employee.id === selectedId)
          ? selectedId
          : data[0].id;
        setSelectedId(nextId);
      } catch (error) {
        if (!ignore) {
          const message = error instanceof Error ? error.message : "No fue posible cargar empleados.";
          setErrorMessage(message);
          setEmployees([]);
          setSelectedId(null);
          setSelectedEmployee(null);
        }
      } finally {
        if (!ignore) {
          setLoading(false);
        }
      }
    }

    void loadEmployees();

    return () => {
      ignore = true;
    };
  }, [search, status, jobTitle, completeness, selectedId]);

  useEffect(() => {
    if (selectedId === null) {
      return;
    }

    const employeeId = selectedId;
    let ignore = false;

    async function loadDetail() {
      setDetailLoading(true);
      setAssignmentMessage(null);

      try {
        const [data, assignments, positions] = await Promise.all([
          fetchEmployeeDetail(employeeId),
          fetchEmployeePositionAssignments(employeeId),
          fetchServicePositions({ status: "ACTIVO" })
        ]);
        if (!ignore) {
          setSelectedEmployee(data);
          setPositionAssignments(assignments);
          setAvailablePositions(positions);
          setAssignmentPositionId(positions[0]?.id.toString() || "");
          setEditFullName(data.fullName);
          setEditEmploymentStatus(data.employmentStatus);
          setEditJobTitle(data.jobTitle);
          setEditHireDate(data.hireDate || "");
          setEditTerminationDate(data.terminationDate || "");
          setEditTerminationReason(data.terminationReason || "");
          setEditContractType(data.contractType || "");
          setEditNotes(data.notes || "");
          setEditSalary(data.currentBaseSalary?.toString() || "");
          setEditSalaryEffectiveFrom(data.salaryEffectiveFrom || "");
        }
      } catch {
        if (!ignore) {
          setSelectedEmployee(null);
          setPositionAssignments([]);
          setAvailablePositions([]);
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

  async function saveEmployee() {
    if (!selectedEmployee) {
      return;
    }

    setErrorMessage(null);
    try {
      await updateEmployee(selectedEmployee.id, {
        fullName: editFullName,
        employmentStatus: editEmploymentStatus,
        jobTitle: editJobTitle,
        hireDate: editHireDate,
        terminationDate: editTerminationDate || null,
        terminationReason: editTerminationReason || null,
        contractType: editContractType || null,
        notes: editNotes || null,
        currentBaseSalary: editSalary ? Number(editSalary) : null,
        salaryEffectiveFrom: editSalaryEffectiveFrom || null
      });
      const updated = await fetchEmployeeDetail(selectedEmployee.id);
      setSelectedEmployee(updated);
      setEmployees((current) => current.map((employee) => employee.id === updated.id ? updated : employee));
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : "No fue posible actualizar el empleado.");
    }
  }

  async function reloadSelectedEmployee(employeeId: number) {
    const [updated, assignments] = await Promise.all([
      fetchEmployeeDetail(employeeId),
      fetchEmployeePositionAssignments(employeeId)
    ]);
    setSelectedEmployee(updated);
    setPositionAssignments(assignments);
    setEmployees((current) => current.map((employee) => employee.id === updated.id ? updated : employee));
  }

  async function assignPosition() {
    if (!selectedEmployee) {
      return;
    }

    if (currentAssignment) {
      setAssignmentMessage("El empleado ya tiene una asignacion vigente.");
      return;
    }

    if (!assignmentPositionId || !assignmentStartDate) {
      setAssignmentMessage("Seleccione un puesto activo y una fecha de inicio.");
      return;
    }

    setAssignmentPending(true);
    setAssignmentMessage(null);
    try {
      await createPositionAssignment(selectedEmployee.id, {
        positionId: Number(assignmentPositionId),
        startDate: assignmentStartDate,
        changeReason: assignmentReason || null,
        notes: assignmentNotes || null
      });
      setAssignmentStartDate("");
      setAssignmentReason("");
      setAssignmentNotes("");
      await reloadSelectedEmployee(selectedEmployee.id);
      setAssignmentMessage("Asignacion creada.");
    } catch (error) {
      setAssignmentMessage(error instanceof Error ? error.message : "No fue posible crear la asignacion.");
    } finally {
      setAssignmentPending(false);
    }
  }

  async function finalizeCurrentAssignment() {
    if (!selectedEmployee || !currentAssignment) {
      return;
    }

    if (!finalizeEndDate) {
      setAssignmentMessage("La fecha fin es obligatoria para finalizar.");
      return;
    }

    setAssignmentPending(true);
    setAssignmentMessage(null);
    try {
      await finalizePositionAssignment(currentAssignment.id, {
        endDate: finalizeEndDate,
        changeReason: finalizeReason || null,
        notes: finalizeNotes || null
      });
      setFinalizeEndDate("");
      setFinalizeReason("");
      setFinalizeNotes("");
      await reloadSelectedEmployee(selectedEmployee.id);
      setAssignmentMessage("Asignacion finalizada.");
    } catch (error) {
      setAssignmentMessage(error instanceof Error ? error.message : "No fue posible finalizar la asignacion.");
    } finally {
      setAssignmentPending(false);
    }
  }

  return (
    <div className="employees-workspace">
      <div className="employees-toolbar">
        <div>
          <p className="eyebrow">I2 en curso</p>
          <h2>Maestro de empleados y guardas</h2>
        </div>
        <div className="toolbar-filters">
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Buscar por nombre o identificacion" />
          <select value={status} onChange={(event) => setStatus(event.target.value)}>
            <option value="">Todos los estados</option>
            <option value="ACTIVO">Activos</option>
            <option value="RETIRADO">Retirados</option>
          </select>
          <input value={jobTitle} onChange={(event) => setJobTitle(event.target.value)} placeholder="Filtrar por cargo" />
          <select value={completeness} onChange={(event) => setCompleteness(event.target.value)}>
            <option value="">Toda completitud</option>
            <option value="COMPLETO">Completos</option>
            <option value="INCOMPLETO">Incompletos</option>
          </select>
        </div>
      </div>

      {errorMessage ? <div className="panel-empty">{errorMessage}</div> : null}

      <div className="employees-grid">
        <section className="panel employee-list-panel">
          <div className="panel-header">
            <h3>Listado</h3>
            <span>{loading ? "Cargando..." : `${employees.length} registros`}</span>
          </div>

          <div className="employee-table">
            {employees.map((employee) => (
              <button
                key={employee.id}
                type="button"
                className={employee.id === selectedId ? "employee-row selected" : "employee-row"}
                onClick={() => setSelectedId(employee.id)}
              >
                <div>
                  <strong>{employee.fullName}</strong>
                  <p className="muted">
                    {employee.identificationType} {employee.identificationNumber} · {employee.jobTitle}
                  </p>
                </div>
                <div className="employee-row-meta">
                  <span className={`status-chip ${employee.employmentStatus === "ACTIVO" ? "status-active" : "status-retired"}`}>
                    {employee.employmentStatus}
                  </span>
                  <small>{employee.recordStatus === "INCOMPLETO" ? "Incompleto" : "Completo"}</small>
                  <small>{formatCurrency(employee.currentBaseSalary)}</small>
                </div>
              </button>
            ))}

            {!loading && employees.length === 0 ? <div className="panel-empty">No hay registros para los filtros actuales.</div> : null}
          </div>
        </section>

        <aside className="panel employee-detail-panel">
          <div className="panel-header">
            <h3>Detalle</h3>
            <span>{detailLoading ? "Cargando..." : selectedEmployee ? "Disponible" : "Sin seleccion"}</span>
          </div>

          {selectedEmployee ? (
            <div className="employee-detail">
              <h4>{selectedEmployee.fullName}</h4>
              <p className="muted">
                {selectedEmployee.identificationType} {selectedEmployee.identificationNumber}
              </p>
              <dl>
                <div>
                  <dt>Estado laboral</dt>
                  <dd>{selectedEmployee.employmentStatus}</dd>
                </div>
                <div>
                  <dt>Estado registro</dt>
                  <dd>{selectedEmployee.recordStatus}</dd>
                </div>
                <div>
                  <dt>Cargo</dt>
                  <dd>{selectedEmployee.jobTitle}</dd>
                </div>
                <div>
                  <dt>Contrato</dt>
                  <dd>{selectedEmployee.contractType || "No definido"}</dd>
                </div>
                <div>
                  <dt>Ingreso</dt>
                  <dd>{selectedEmployee.hireDate || "No definido"}</dd>
                </div>
                <div>
                  <dt>Retiro</dt>
                  <dd>{selectedEmployee.terminationDate || "No aplica"}</dd>
                </div>
                <div>
                  <dt>Motivo retiro</dt>
                  <dd>{selectedEmployee.terminationReason || "No aplica"}</dd>
                </div>
                <div>
                  <dt>Puesto actual normalizado</dt>
                  <dd>{selectedEmployee.currentServicePositionName || "Sin puesto normalizado"}</dd>
                </div>
                <div>
                  <dt>Texto importado I2</dt>
                  <dd>{selectedEmployee.currentServicePositionText || "Sin referencia importada"}</dd>
                </div>
                <div>
                  <dt>Salario vigente</dt>
                  <dd>{formatCurrency(selectedEmployee.currentBaseSalary)}</dd>
                </div>
                <div>
                  <dt>Fuente salario</dt>
                  <dd>{selectedEmployee.salarySource}</dd>
                </div>
                <div>
                  <dt>Notas</dt>
                  <dd>{selectedEmployee.notes || "Sin observaciones"}</dd>
                </div>
              </dl>
              <div className="employee-history">
                <h4>Normalizacion asistida</h4>
                <div className="normalization-compare">
                  <div>
                    <span className="eyebrow">Texto importado I2</span>
                    <strong>{importedPositionText || "Sin referencia importada"}</strong>
                  </div>
                  <div>
                    <span className="eyebrow">Puesto normalizado</span>
                    <strong>{normalizedPositionName || "Sin puesto normalizado"}</strong>
                  </div>
                  <span className={`status-chip ${hasDifferentPositionReference ? "status-warning" : "status-ready"}`}>
                    {hasDifferentPositionReference ? "Revisar" : "Consistente"}
                  </span>
                </div>
              </div>
              <div className="employee-history">
                <h4>Historial de puestos</h4>
                {currentAssignment ? (
                  <div className="assignment-card">
                    <div>
                      <strong>{currentAssignment.positionName}</strong>
                      <p className="muted">
                        {currentAssignment.positionCode || "Sin codigo"} · {currentAssignment.clientText || "Sin cliente"}
                      </p>
                      <small>Desde {currentAssignment.startDate}</small>
                    </div>
                    <span className="status-chip status-ready">VIGENTE</span>
                  </div>
                ) : (
                  <p className="muted">Sin asignacion vigente.</p>
                )}

                {positionAssignments.filter((assignment) => assignment.status !== "VIGENTE").map((assignment) => (
                  <div key={assignment.id} className="assignment-card">
                    <div>
                      <strong>{assignment.positionName}</strong>
                      <p className="muted">
                        {assignment.positionCode || "Sin codigo"} · {assignment.clientText || "Sin cliente"}
                      </p>
                      <small>{assignment.startDate} a {assignment.endDate || "Sin cierre"}</small>
                    </div>
                    <span className="status-chip status-retired">FINALIZADA</span>
                  </div>
                ))}
                {positionAssignments.length === 0 ? <p className="muted">Sin historial de puestos.</p> : null}
              </div>
              {canManageAssignments ? (
                <div className="employee-history">
                  <h4>Gestion de asignacion</h4>
                  {assignmentMessage ? <p className="muted">{assignmentMessage}</p> : null}
                  {currentAssignment ? (
                    <div className="position-form">
                      <p className="muted">Para asignar otro puesto primero finalice la asignacion vigente.</p>
                      <input type="date" value={finalizeEndDate} onChange={(event) => setFinalizeEndDate(event.target.value)} />
                      <input value={finalizeReason} onChange={(event) => setFinalizeReason(event.target.value)} placeholder="Motivo de cierre opcional" />
                      <textarea value={finalizeNotes} onChange={(event) => setFinalizeNotes(event.target.value)} placeholder="Notas opcionales" />
                      <div className="position-form-actions">
                        <button type="button" disabled={assignmentPending} onClick={() => void finalizeCurrentAssignment()}>
                          Finalizar asignacion
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="position-form">
                      <select value={assignmentPositionId} onChange={(event) => setAssignmentPositionId(event.target.value)}>
                        <option value="">Seleccione puesto activo</option>
                        {availablePositions.map((position) => (
                          <option key={position.id} value={position.id}>
                            {position.name} {position.code ? `(${position.code})` : ""}
                          </option>
                        ))}
                      </select>
                      <input type="date" value={assignmentStartDate} onChange={(event) => setAssignmentStartDate(event.target.value)} />
                      <input value={assignmentReason} onChange={(event) => setAssignmentReason(event.target.value)} placeholder="Motivo opcional" />
                      <textarea value={assignmentNotes} onChange={(event) => setAssignmentNotes(event.target.value)} placeholder="Notas opcionales" />
                      <div className="position-form-actions">
                        <button type="button" disabled={assignmentPending} onClick={() => void assignPosition()}>
                          Asignar puesto
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ) : null}
              <div className="employee-history">
                <h4>Historial de cambios</h4>
                {selectedEmployee.changeHistory.map((change) => (
                  <div key={change.id} className="history-item">
                    <strong>{change.fieldName}</strong>
                    <p className="muted">
                      {change.previousValue || "Sin valor"} → {change.newValue || "Sin valor"}
                    </p>
                    <small>{change.actorUsername} · {new Date(change.changedAt).toLocaleString("es-CO")}</small>
                  </div>
                ))}
                {selectedEmployee.changeHistory.length === 0 ? <p className="muted">Sin cambios registrados.</p> : null}
              </div>
              {user.role === "TH" ? (
                <div className="employee-history">
                  <h4>Edicion manual</h4>
                  <input value={editFullName} onChange={(event) => setEditFullName(event.target.value)} placeholder="Nombre completo" />
                  <select value={editEmploymentStatus} onChange={(event) => setEditEmploymentStatus(event.target.value as "ACTIVO" | "RETIRADO")}>
                    <option value="ACTIVO">Activo</option>
                    <option value="RETIRADO">Retirado</option>
                  </select>
                  <input value={editJobTitle} onChange={(event) => setEditJobTitle(event.target.value)} placeholder="Cargo" />
                  <input type="date" value={editHireDate} onChange={(event) => setEditHireDate(event.target.value)} />
                  <input type="date" value={editTerminationDate} onChange={(event) => setEditTerminationDate(event.target.value)} />
                  <input value={editTerminationReason} onChange={(event) => setEditTerminationReason(event.target.value)} placeholder="Motivo de retiro" />
                  <input value={editContractType} onChange={(event) => setEditContractType(event.target.value)} placeholder="Tipo de contrato" />
                  <textarea value={editNotes} onChange={(event) => setEditNotes(event.target.value)} placeholder="Observaciones" />
                  <input type="number" min="0" value={editSalary} onChange={(event) => setEditSalary(event.target.value)} placeholder="Salario base" />
                  <input type="date" value={editSalaryEffectiveFrom} onChange={(event) => setEditSalaryEffectiveFrom(event.target.value)} />
                  <button type="button" onClick={() => void saveEmployee()}>Guardar cambios</button>
                </div>
              ) : null}
            </div>
          ) : (
            <div className="panel-empty">Seleccione un empleado para ver su detalle.</div>
          )}
        </aside>
      </div>
    </div>
  );
}

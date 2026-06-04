import { useEffect, useState } from "react";
import { fetchEmployeeDetail, fetchEmployees } from "../../services/portalApi";
import type { EmployeeDetail, EmployeeSummary } from "../../types/portal";

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

export function EmployeesPage() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [employees, setEmployees] = useState<EmployeeSummary[]>([]);
  const [selectedEmployee, setSelectedEmployee] = useState<EmployeeDetail | null>(null);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let ignore = false;

    async function loadEmployees() {
      setLoading(true);
      setErrorMessage(null);

      try {
        const data = await fetchEmployees({ search, status, jobTitle });
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
  }, [search, status, jobTitle, selectedId]);

  useEffect(() => {
    if (selectedId === null) {
      return;
    }

    const employeeId = selectedId;
    let ignore = false;

    async function loadDetail() {
      setDetailLoading(true);

      try {
        const data = await fetchEmployeeDetail(employeeId);
        if (!ignore) {
          setSelectedEmployee(data);
        }
      } catch {
        if (!ignore) {
          setSelectedEmployee(null);
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
                  <dt>Puesto actual</dt>
                  <dd>{selectedEmployee.currentServicePositionText || "Sin referencia"}</dd>
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
            </div>
          ) : (
            <div className="panel-empty">Seleccione un empleado para ver su detalle.</div>
          )}
        </aside>
      </div>
    </div>
  );
}

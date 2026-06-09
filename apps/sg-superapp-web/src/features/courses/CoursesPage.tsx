import { useEffect, useMemo, useState } from "react";
import {
  createTrainingRecord,
  createTrainingRequirementType,
  fetchTrainingCompliance,
  fetchTrainingComplianceDetail,
  fetchTrainingRequirementTypes,
  inactivateTrainingRecord,
  inactivateTrainingRequirementType,
  updateTrainingRequirementType
} from "../../services/portalApi";
import type {
  CurrentUser,
  TrainingComplianceDetail,
  TrainingComplianceStatus,
  TrainingComplianceSummary,
  TrainingRecord,
  TrainingRequirementCategory,
  TrainingRequirementType,
  TrainingServiceEnablementStatus
} from "../../types/portal";

interface CoursesPageProps {
  user: CurrentUser;
}

const complianceStatuses: TrainingComplianceStatus[] = ["VENCIDO", "CRITICO", "PREVENTIVO", "INFORMATIVO", "AL_DIA"];
const enablementStatuses: TrainingServiceEnablementStatus[] = ["NO_HABILITADO", "HABILITADO"];
const emptyTypeForm = {
  code: "",
  name: "",
  category: "CURSO" as TrainingRequirementCategory,
  validityDays: "",
  isServiceRequired: true,
  notes: ""
};
const emptyRenewalForm = {
  requirementTypeId: "",
  completedAt: "",
  expiresAt: "",
  supportPath: "",
  notes: ""
};

function formatDate(value: string | null): string {
  if (!value) {
    return "Sin fecha";
  }

  return new Intl.DateTimeFormat("es-CO", { dateStyle: "medium" }).format(new Date(value));
}

function statusClass(status: TrainingComplianceStatus | TrainingServiceEnablementStatus): string {
  if (status === "HABILITADO" || status === "AL_DIA") {
    return "status-active";
  }

  if (status === "NO_HABILITADO" || status === "VENCIDO") {
    return "status-retired";
  }

  if (status === "CRITICO" || status === "PREVENTIVO") {
    return "status-warning";
  }

  return "status-pending";
}

export function CoursesPage({ user }: CoursesPageProps) {
  const [search, setSearch] = useState("");
  const [typeId, setTypeId] = useState<number | "">("");
  const [complianceStatus, setComplianceStatus] = useState<TrainingComplianceStatus | "">("");
  const [enablementStatus, setEnablementStatus] = useState<TrainingServiceEnablementStatus | "">("");
  const [types, setTypes] = useState<TrainingRequirementType[]>([]);
  const [summaries, setSummaries] = useState<TrainingComplianceSummary[]>([]);
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<number | null>(null);
  const [detail, setDetail] = useState<TrainingComplianceDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [typesRefreshKey, setTypesRefreshKey] = useState(0);
  const [dataRefreshKey, setDataRefreshKey] = useState(0);
  const [selectedTypeId, setSelectedTypeId] = useState<number | null>(null);
  const [typeForm, setTypeForm] = useState(emptyTypeForm);
  const [renewalForm, setRenewalForm] = useState(emptyRenewalForm);
  const [actionPending, setActionPending] = useState(false);

  const canManageTraining = user.role === "ADMIN" || user.role === "TH";
  const activeRequirementCount = detail?.currentRequirements.length ?? 0;
  const expiredCurrentCount = useMemo(
    () => detail?.currentRequirements.filter((record) => record.complianceStatus === "VENCIDO").length ?? 0,
    [detail]
  );

  const selectedType = types.find((item) => item.id === selectedTypeId) || null;
  const activeTypes = types.filter((item) => item.status === "ACTIVO");

  useEffect(() => {
    let ignore = false;

    async function loadTypes() {
      try {
        const data = await fetchTrainingRequirementTypes({});
        if (!ignore) {
          setTypes(data);
          setSelectedTypeId((current) => current && data.some((item) => item.id === current) ? current : data[0]?.id ?? null);
        }
      } catch {
        if (!ignore) {
          setTypes([]);
        }
      }
    }

    void loadTypes();
    return () => {
      ignore = true;
    };
  }, [typesRefreshKey]);

  useEffect(() => {
    if (!selectedType) {
      setTypeForm(emptyTypeForm);
      return;
    }

    setTypeForm({
      code: selectedType.code || "",
      name: selectedType.name,
      category: selectedType.category,
      validityDays: selectedType.validityDays === null ? "" : selectedType.validityDays.toString(),
      isServiceRequired: selectedType.isServiceRequired,
      notes: selectedType.notes || ""
    });
  }, [selectedType]);

  useEffect(() => {
    let ignore = false;

    async function loadSummaries() {
      setLoading(true);
      setMessage(null);

      try {
        const data = await fetchTrainingCompliance({
          search: search.trim() || undefined,
          typeId: typeId === "" ? undefined : typeId,
          complianceStatus: complianceStatus || undefined,
          enablementStatus: enablementStatus || undefined
        });
        if (ignore) {
          return;
        }

        setSummaries(data);
        const nextEmployeeId = selectedEmployeeId && data.some((item) => item.employeeId === selectedEmployeeId)
          ? selectedEmployeeId
          : data[0]?.employeeId ?? null;
        setSelectedEmployeeId(nextEmployeeId);
      } catch (error) {
        if (!ignore) {
          setMessage(error instanceof Error ? error.message : "No fue posible cargar cumplimiento.");
          setSummaries([]);
          setSelectedEmployeeId(null);
          setDetail(null);
        }
      } finally {
        if (!ignore) {
          setLoading(false);
        }
      }
    }

    void loadSummaries();
    return () => {
      ignore = true;
    };
  }, [complianceStatus, dataRefreshKey, enablementStatus, search, selectedEmployeeId, typeId]);

  useEffect(() => {
    if (selectedEmployeeId === null) {
      setDetail(null);
      return;
    }

    const employeeId = selectedEmployeeId;
    let ignore = false;

    async function loadDetail() {
      setDetailLoading(true);
      try {
        const data = await fetchTrainingComplianceDetail(employeeId);
        if (!ignore) {
          setDetail(data);
        }
      } catch (error) {
        if (!ignore) {
          setDetail(null);
          setMessage(error instanceof Error ? error.message : "No fue posible cargar el detalle.");
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
  }, [dataRefreshKey, selectedEmployeeId]);

  async function refreshTrainingData() {
    setTypesRefreshKey((current) => current + 1);
    setDataRefreshKey((current) => current + 1);
  }

  async function saveRequirementType() {
    if (!canManageTraining) {
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      const request = {
        code: typeForm.code.trim() || null,
        name: typeForm.name.trim(),
        category: typeForm.category,
        validityDays: typeForm.validityDays.trim() ? Number(typeForm.validityDays) : null,
        isServiceRequired: typeForm.isServiceRequired,
        notes: typeForm.notes.trim() || null
      };
      const saved = selectedTypeId ? await updateTrainingRequirementType(selectedTypeId, request) : await createTrainingRequirementType(request);
      setSelectedTypeId(saved.id);
      setMessage("Tipo de curso/acreditacion guardado.");
      await refreshTrainingData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible guardar el tipo.");
    } finally {
      setActionPending(false);
    }
  }

  async function inactivateSelectedType() {
    if (!canManageTraining || !selectedTypeId) {
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      await inactivateTrainingRequirementType(selectedTypeId);
      setMessage("Tipo inactivado.");
      await refreshTrainingData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible inactivar el tipo.");
    } finally {
      setActionPending(false);
    }
  }

  async function saveRenewal() {
    if (!canManageTraining || !selectedEmployeeId) {
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      await createTrainingRecord(selectedEmployeeId, {
        requirementTypeId: Number(renewalForm.requirementTypeId),
        completedAt: renewalForm.completedAt,
        expiresAt: renewalForm.expiresAt.trim() || null,
        supportPath: renewalForm.supportPath.trim() || null,
        notes: renewalForm.notes.trim() || null
      });
      setRenewalForm(emptyRenewalForm);
      setMessage("Renovacion registrada.");
      await refreshTrainingData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible registrar la renovacion.");
    } finally {
      setActionPending(false);
    }
  }

  async function inactivateRenewal(record: TrainingRecord) {
    if (!canManageTraining) {
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      await inactivateTrainingRecord(record.id);
      setMessage("Renovacion inactivada.");
      await refreshTrainingData();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible inactivar la renovacion.");
    } finally {
      setActionPending(false);
    }
  }

  return (
    <div className="employees-workspace courses-workspace">
      <div className="employees-toolbar">
        <div>
          <p className="eyebrow">I5 en curso</p>
          <h2>Cursos y acreditaciones</h2>
        </div>
        <div className="toolbar-filters courses-filters">
          <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Buscar empleado o identificacion" />
          <select value={typeId} onChange={(event) => setTypeId(event.target.value ? Number(event.target.value) : "")}>
            <option value="">Todos los requisitos</option>
            {types.map((type) => (
              <option key={type.id} value={type.id}>{type.name}</option>
            ))}
          </select>
          <select value={complianceStatus} onChange={(event) => setComplianceStatus(event.target.value as TrainingComplianceStatus | "")}>
            <option value="">Todos los estados</option>
            {complianceStatuses.map((status) => <option key={status} value={status}>{status}</option>)}
          </select>
          <select value={enablementStatus} onChange={(event) => setEnablementStatus(event.target.value as TrainingServiceEnablementStatus | "")}>
            <option value="">Toda habilitacion</option>
            {enablementStatuses.map((status) => <option key={status} value={status}>{status}</option>)}
          </select>
        </div>
      </div>

      {message ? <div className="panel-empty compact-empty">{message}</div> : null}

      {canManageTraining ? (
        <section className="panel training-management-panel">
          <div className="panel-header">
            <h3>Gestion de tipos</h3>
            <button type="button" className="ghost-button" onClick={() => setSelectedTypeId(null)}>Nuevo tipo</button>
          </div>
          <div className="training-management-grid">
            <div className="training-type-list">
              {types.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  className={item.id === selectedTypeId ? "employee-row selected" : "employee-row"}
                  onClick={() => setSelectedTypeId(item.id)}
                >
                  <div>
                    <strong>{item.name}</strong>
                    <p className="muted">{item.category} · {item.code || "sin codigo"} · {item.validityDays ?? "manual"} dias</p>
                  </div>
                  <span className={`status-chip ${item.status === "ACTIVO" ? "status-active" : "status-retired"}`}>{item.status}</span>
                </button>
              ))}
            </div>
            <div className="position-form training-form">
              <label>
                Codigo
                <input value={typeForm.code} onChange={(event) => setTypeForm((current) => ({ ...current, code: event.target.value }))} />
              </label>
              <label>
                Nombre
                <input value={typeForm.name} onChange={(event) => setTypeForm((current) => ({ ...current, name: event.target.value }))} />
              </label>
              <label>
                Categoria
                <select value={typeForm.category} onChange={(event) => setTypeForm((current) => ({ ...current, category: event.target.value as TrainingRequirementCategory }))}>
                  <option value="CURSO">Curso</option>
                  <option value="ACREDITACION">Acreditacion</option>
                </select>
              </label>
              <label>
                Vigencia dias
                <input value={typeForm.validityDays} onChange={(event) => setTypeForm((current) => ({ ...current, validityDays: event.target.value }))} placeholder="Manual si queda vacio" />
              </label>
              <label className="inline-check">
                <input type="checkbox" checked={typeForm.isServiceRequired} onChange={(event) => setTypeForm((current) => ({ ...current, isServiceRequired: event.target.checked }))} />
                Obligatorio para servicio
              </label>
              <label>
                Notas
                <textarea value={typeForm.notes} onChange={(event) => setTypeForm((current) => ({ ...current, notes: event.target.value }))} />
              </label>
              <div className="position-form-actions">
                <button type="button" onClick={() => void saveRequirementType()} disabled={actionPending}>Guardar tipo</button>
                {selectedType?.status === "ACTIVO" ? (
                  <button type="button" className="danger-action" onClick={() => void inactivateSelectedType()} disabled={actionPending}>Inactivar tipo</button>
                ) : null}
              </div>
            </div>
          </div>
        </section>
      ) : null}

      <div className="employees-grid courses-grid">
        <section className="panel employee-list-panel">
          <div className="panel-header">
            <h3>Cumplimiento</h3>
            <span>{loading ? "Cargando..." : `${summaries.length} empleados`}</span>
          </div>

          <div className="employee-table">
            {summaries.map((summary) => (
              <button
                key={summary.employeeId}
                type="button"
                className={summary.employeeId === selectedEmployeeId ? "employee-row selected" : "employee-row"}
                onClick={() => setSelectedEmployeeId(summary.employeeId)}
              >
                <div>
                  <strong>{summary.fullName}</strong>
                  <p className="muted">
                    {summary.identificationNumber} · {summary.jobTitle} · {summary.currentPositionName || "Sin puesto vigente"}
                  </p>
                </div>
                <div className="employee-row-meta">
                  <span className={`status-chip ${statusClass(summary.serviceEnablementStatus)}`}>{summary.serviceEnablementStatus}</span>
                  <span className={`status-chip ${statusClass(summary.worstComplianceStatus)}`}>{summary.worstComplianceStatus}</span>
                  <small>{summary.activeRequirementsCount} actuales</small>
                </div>
              </button>
            ))}

            {!loading && summaries.length === 0 ? <div className="panel-empty">No hay cumplimiento para los filtros actuales.</div> : null}
          </div>
        </section>

        <aside className="panel employee-detail-panel courses-detail-panel">
          <div className="panel-header">
            <h3>Detalle</h3>
            <span>{detailLoading ? "Cargando..." : detail ? detail.serviceEnablement.serviceEnablementStatus : "Sin seleccion"}</span>
          </div>

          {detail ? (
            <div className="employee-detail">
              <div className="course-detail-heading">
                <div>
                  <h4>{detail.employee.fullName}</h4>
                  <p className="muted">
                    {detail.employee.identificationType} {detail.employee.identificationNumber} · {detail.employee.jobTitle}
                  </p>
                </div>
                <span className={`status-chip ${statusClass(detail.serviceEnablement.serviceEnablementStatus)}`}>
                  {detail.serviceEnablement.serviceEnablementStatus}
                </span>
              </div>

              <div className="course-kpi-grid">
                <div>
                  <span>{activeRequirementCount}</span>
                  <p className="muted">Requisitos actuales</p>
                </div>
                <div>
                  <span>{expiredCurrentCount}</span>
                  <p className="muted">Vencidos</p>
                </div>
                <div>
                  <span>{detail.serviceEnablement.blockingExpiredRequirementsCount}</span>
                  <p className="muted">Bloqueantes</p>
                </div>
              </div>

              <dl>
                <div>
                  <dt>Puesto actual</dt>
                  <dd>{detail.currentPosition ? `${detail.currentPosition.name} · ${detail.currentPosition.clientText || "sin cliente"}` : "Sin puesto vigente"}</dd>
                </div>
                <div>
                  <dt>Calculado</dt>
                  <dd>{formatDate(detail.serviceEnablement.calculatedAt)}</dd>
                </div>
              </dl>

              {canManageTraining ? (
                <div className="position-detail-section">
                  <div className="panel-header compact-header">
                    <h4>Registrar renovacion</h4>
                    <span>{detail.employee.fullName}</span>
                  </div>
                  <div className="position-form training-form">
                    <label>
                      Tipo
                      <select value={renewalForm.requirementTypeId} onChange={(event) => setRenewalForm((current) => ({ ...current, requirementTypeId: event.target.value }))}>
                        <option value="">Seleccione requisito</option>
                        {activeTypes.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                      </select>
                    </label>
                    <label>
                      Fecha realizacion
                      <input type="date" value={renewalForm.completedAt} onChange={(event) => setRenewalForm((current) => ({ ...current, completedAt: event.target.value }))} />
                    </label>
                    <label>
                      Fecha vencimiento
                      <input type="date" value={renewalForm.expiresAt} onChange={(event) => setRenewalForm((current) => ({ ...current, expiresAt: event.target.value }))} />
                    </label>
                    <label>
                      Soporte
                      <input value={renewalForm.supportPath} onChange={(event) => setRenewalForm((current) => ({ ...current, supportPath: event.target.value }))} placeholder="Ruta o referencia opcional" />
                    </label>
                    <label>
                      Observaciones
                      <textarea value={renewalForm.notes} onChange={(event) => setRenewalForm((current) => ({ ...current, notes: event.target.value }))} />
                    </label>
                    <div className="position-form-actions">
                      <button type="button" onClick={() => void saveRenewal()} disabled={actionPending || !renewalForm.requirementTypeId || !renewalForm.completedAt}>Registrar renovacion</button>
                    </div>
                  </div>
                </div>
              ) : null}

              <div className="position-detail-section">
                <div className="panel-header compact-header">
                  <h4>Requisitos actuales</h4>
                  <span>{detail.currentRequirements.length}</span>
                </div>
                {detail.currentRequirements.map((record) => (
                  <article key={record.id} className="assignment-card course-record-card">
                    <div>
                      <strong>{record.requirementTypeName}</strong>
                      <p className="muted">
                        {record.requirementCategory} · vence {formatDate(record.expiresAt)} · {record.daysUntilExpiry} dias
                      </p>
                    </div>
                    <div className="course-record-actions">
                      <span className={`status-chip ${statusClass(record.complianceStatus)}`}>{record.complianceStatus}</span>
                      {canManageTraining && record.status === "ACTIVO" ? (
                        <button type="button" className="danger-action" onClick={() => void inactivateRenewal(record)} disabled={actionPending}>Inactivar renovacion</button>
                      ) : null}
                    </div>
                  </article>
                ))}
                {detail.currentRequirements.length === 0 ? <div className="panel-empty compact-empty">Sin requisitos actuales.</div> : null}
              </div>

              <div className="position-detail-section">
                <div className="panel-header compact-header">
                  <h4>Historico</h4>
                  <span>{detail.trainingHistory.length}</span>
                </div>
                {detail.trainingHistory.map((record) => (
                  <article key={record.id} className="assignment-card course-record-card">
                    <div>
                      <strong>{record.requirementTypeName}</strong>
                      <p className="muted">
                        {formatDate(record.completedAt)} - {formatDate(record.expiresAt)} · {record.status} · {record.createdBy}
                      </p>
                    </div>
                    <span className={`status-chip ${statusClass(record.complianceStatus)}`}>{record.complianceStatus}</span>
                  </article>
                ))}
                {detail.trainingHistory.length === 0 ? <div className="panel-empty compact-empty">Sin historico de renovaciones.</div> : null}
              </div>

              <p className="muted role-note">
                {canManageTraining
                  ? "ADMIN/TH gestionan tipos y renovaciones; los errores se muestran desde backend."
                  : "Rol de consulta sin acciones de edicion."}
              </p>
            </div>
          ) : (
            <div className="panel-empty">Seleccione un empleado para ver cursos y acreditaciones.</div>
          )}
        </aside>
      </div>
    </div>
  );
}

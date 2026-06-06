import { useEffect, useState } from "react";
import { annulCertificate, approveGenerateCertificate, createCertificateSigner, downloadCertificatePdf, fetchCertificateHistory, fetchCertificates, fetchCertificateSigners, fetchEmployees, inactivateCertificateSigner, previewCertificate, updateCertificateSigner } from "../../services/portalApi";
import type { CertificatePreview, CertificatePurpose, CertificateSigner, CertificateSignerRequest, CertificateStatus, CertificateType, CurrentUser, EmployeeSummary, LaborCertificate, LaborCertificateHistoryItem } from "../../types/portal";

interface CertificatesPageProps {
  user: CurrentUser;
}

const purposes: CertificatePurpose[] = ["TRAMITE_GENERAL", "ENTIDAD_FINANCIERA", "CESANTIAS", "CLIENTE", "INTERESADO"];
const statuses: CertificateStatus[] = ["GENERADA", "ANULADA"];

const emptySignerForm: CertificateSignerRequest = {
  fullName: "",
  jobTitle: "",
  signaturePath: null,
  validFrom: new Date().toISOString().slice(0, 10),
  validTo: null,
  notes: null
};

function formatDate(value: string | null): string {
  if (!value) {
    return "Sin fecha";
  }

  return new Intl.DateTimeFormat("es-CO", { dateStyle: "medium" }).format(new Date(value));
}

function statusClass(status: CertificateStatus | CertificateType): string {
  if (status === "GENERADA" || status === "ACTIVO") {
    return "status-active";
  }

  if (status === "ANULADA" || status === "RETIRADO") {
    return "status-retired";
  }

  return "status-pending";
}

export function CertificatesPage({ user }: CertificatesPageProps) {
  const [certificates, setCertificates] = useState<LaborCertificate[]>([]);
  const [employees, setEmployees] = useState<EmployeeSummary[]>([]);
  const [selectedCertificateId, setSelectedCertificateId] = useState<number | null>(null);
  const [selectedCertificate, setSelectedCertificate] = useState<LaborCertificate | null>(null);
  const [history, setHistory] = useState<LaborCertificateHistoryItem[]>([]);
  const [statusFilter, setStatusFilter] = useState<CertificateStatus | "">("");
  const [typeFilter, setTypeFilter] = useState<CertificateType | "">("");
  const [employeeFilter, setEmployeeFilter] = useState("");
  const [fromFilter, setFromFilter] = useState("");
  const [toFilter, setToFilter] = useState("");
  const [employeeSearch, setEmployeeSearch] = useState("");
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<number | "">("");
  const [purpose, setPurpose] = useState<CertificatePurpose>("TRAMITE_GENERAL");
  const [issueDate, setIssueDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [variableLabel, setVariableLabel] = useState("");
  const [variableAmount, setVariableAmount] = useState("");
  const [preview, setPreview] = useState<CertificatePreview | null>(null);
  const [signers, setSigners] = useState<CertificateSigner[]>([]);
  const [selectedSignerId, setSelectedSignerId] = useState<number | null>(null);
  const [signerForm, setSignerForm] = useState<CertificateSignerRequest>(emptySignerForm);
  const [loading, setLoading] = useState(true);
  const [actionPending, setActionPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [signersRefreshKey, setSignersRefreshKey] = useState(0);

  const canGenerate = user.role === "TH";
  const canAnnul = user.role === "ADMIN" || user.role === "TH";
  const canManageSigners = user.role === "ADMIN";

  useEffect(() => {
    let ignore = false;
    async function loadCertificates() {
      setLoading(true);
      setMessage(null);
      try {
        const data = await fetchCertificates({
          employeeId: employeeFilter ? Number(employeeFilter) : undefined,
          type: typeFilter || undefined,
          status: statusFilter || undefined,
          from: fromFilter || undefined,
          to: toFilter || undefined
        });
        if (ignore) {
          return;
        }

        setCertificates(data);
        const nextId = selectedCertificateId && data.some((item) => item.id === selectedCertificateId)
          ? selectedCertificateId
          : data[0]?.id ?? null;
        setSelectedCertificateId(nextId);
      } catch (error) {
        if (!ignore) {
          setMessage(error instanceof Error ? error.message : "No fue posible cargar certificados.");
          setCertificates([]);
          setSelectedCertificateId(null);
        }
      } finally {
        if (!ignore) {
          setLoading(false);
        }
      }
    }

    void loadCertificates();
    return () => {
      ignore = true;
    };
  }, [employeeFilter, fromFilter, statusFilter, toFilter, typeFilter, selectedCertificateId, refreshKey]);

  useEffect(() => {
    let ignore = false;
    async function loadEmployees() {
      try {
        const data = await fetchEmployees({ search: employeeSearch || undefined });
        if (!ignore) {
          setEmployees(data.slice(0, 20));
        }
      } catch {
        if (!ignore) {
          setEmployees([]);
        }
      }
    }

    void loadEmployees();
    return () => {
      ignore = true;
    };
  }, [employeeSearch]);

  useEffect(() => {
    if (!canManageSigners) {
      setSigners([]);
      return;
    }

    let ignore = false;
    async function loadSigners() {
      try {
        const data = await fetchCertificateSigners();
        if (ignore) {
          return;
        }

        setSigners(data);
        const nextSigner = selectedSignerId ? data.find((item) => item.id === selectedSignerId) ?? null : null;
        if (nextSigner) {
          setSignerForm({
            fullName: nextSigner.fullName,
            jobTitle: nextSigner.jobTitle,
            signaturePath: nextSigner.signaturePath,
            validFrom: nextSigner.validFrom,
            validTo: nextSigner.validTo,
            notes: nextSigner.notes
          });
        } else {
          setSelectedSignerId(null);
        }
      } catch (error) {
        if (!ignore) {
          setSigners([]);
          setMessage(error instanceof Error ? error.message : "No fue posible cargar firmantes.");
        }
      }
    }

    void loadSigners();
    return () => {
      ignore = true;
    };
  }, [canManageSigners, selectedSignerId, signersRefreshKey]);

  useEffect(() => {
    const certificate = certificates.find((item) => item.id === selectedCertificateId) ?? null;
    setSelectedCertificate(certificate);
    if (!certificate) {
      setHistory([]);
      return;
    }

    const certificateId = certificate.id;
    let ignore = false;
    async function loadHistory() {
      try {
        const data = await fetchCertificateHistory(certificateId);
        if (!ignore) {
          setHistory(data);
        }
      } catch {
        if (!ignore) {
          setHistory([]);
        }
      }
    }

    void loadHistory();
    return () => {
      ignore = true;
    };
  }, [certificates, selectedCertificateId]);

  async function runPreview() {
    if (!canGenerate || selectedEmployeeId === "") {
      setMessage("Seleccione un empleado para previsualizar.");
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      const variables = variableLabel.trim() && variableAmount
        ? [{
            conceptCode: variableLabel.trim().toUpperCase().replace(/\s+/g, "_"),
            conceptLabel: variableLabel.trim(),
            amount: Number(variableAmount),
            notes: null
          }]
        : [];
      const result = await previewCertificate({
        employeeId: Number(selectedEmployeeId),
        purpose,
        issueDate,
        variables
      });
      setPreview(result);
      setMessage("Preview generado.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible generar preview.");
      setPreview(null);
    } finally {
      setActionPending(false);
    }
  }

  async function generateCertificate() {
    if (!preview) {
      setMessage("Genere un preview antes de aprobar.");
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      const generated = await approveGenerateCertificate({
        employeeId: preview.employeeId,
        purpose: preview.purpose,
        issueDate: preview.issueDate,
        variables: preview.variables
      });
      setPreview(null);
      setSelectedCertificateId(generated.id);
      setRefreshKey((current) => current + 1);
      setMessage("Certificado generado.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible generar certificado.");
    } finally {
      setActionPending(false);
    }
  }

  async function annulSelected() {
    if (!selectedCertificate || !canAnnul) {
      return;
    }

    const reason = window.prompt("Motivo de anulacion");
    if (!reason) {
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      await annulCertificate(selectedCertificate.id, { reason });
      setRefreshKey((current) => current + 1);
      setMessage("Certificado anulado.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible anular certificado.");
    } finally {
      setActionPending(false);
    }
  }

  function selectSigner(signer: CertificateSigner) {
    setSelectedSignerId(signer.id);
    setSignerForm({
      fullName: signer.fullName,
      jobTitle: signer.jobTitle,
      signaturePath: signer.signaturePath,
      validFrom: signer.validFrom,
      validTo: signer.validTo,
      notes: signer.notes
    });
  }

  function resetSignerForm() {
    setSelectedSignerId(null);
    setSignerForm(emptySignerForm);
  }

  async function saveSigner() {
    if (!canManageSigners) {
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      const request = {
        ...signerForm,
        fullName: signerForm.fullName.trim(),
        jobTitle: signerForm.jobTitle.trim(),
        signaturePath: signerForm.signaturePath?.trim() || null,
        validTo: signerForm.validTo || null,
        notes: signerForm.notes?.trim() || null
      };
      const saved = selectedSignerId
        ? await updateCertificateSigner(selectedSignerId, request)
        : await createCertificateSigner(request);
      setSelectedSignerId(saved.id);
      setSignersRefreshKey((current) => current + 1);
      setMessage("Firmante guardado.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible guardar firmante.");
    } finally {
      setActionPending(false);
    }
  }

  async function inactivateSelectedSigner() {
    if (!canManageSigners || !selectedSignerId) {
      return;
    }

    setActionPending(true);
    setMessage(null);
    try {
      await inactivateCertificateSigner(selectedSignerId);
      resetSignerForm();
      setSignersRefreshKey((current) => current + 1);
      setMessage("Firmante inactivado.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible inactivar firmante.");
    } finally {
      setActionPending(false);
    }
  }

  return (
    <div className="employees-workspace certificates-workspace">
      <div className="employees-toolbar">
        <div>
          <p className="eyebrow">I4 en curso</p>
          <h2>Certificaciones laborales</h2>
        </div>
        <div className="toolbar-filters certificates-filters">
          <input
            value={employeeFilter}
            onChange={(event) => setEmployeeFilter(event.target.value.replace(/\D/g, ""))}
            placeholder="Empleado ID"
            inputMode="numeric"
          />
          <select value={typeFilter} onChange={(event) => setTypeFilter(event.target.value as CertificateType | "")}>
            <option value="">Todos los tipos</option>
            <option value="ACTIVO">Activo</option>
            <option value="RETIRADO">Retirado</option>
          </select>
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as CertificateStatus | "")}>
            <option value="">Todos los estados</option>
            {statuses.map((item) => <option key={item} value={item}>{item}</option>)}
          </select>
          <input type="date" value={fromFilter} onChange={(event) => setFromFilter(event.target.value)} />
          <input type="date" value={toFilter} onChange={(event) => setToFilter(event.target.value)} />
        </div>
      </div>

      {message ? <div className="panel-empty compact-empty">{message}</div> : null}

      <div className="employees-grid certificates-grid">
        <section className="panel employee-list-panel">
          <div className="panel-header">
            <h3>Certificados</h3>
            <span>{loading ? "Cargando..." : `${certificates.length} registros`}</span>
          </div>
          <div className="employee-table">
            {certificates.map((certificate) => (
              <button
                key={certificate.id}
                type="button"
                className={certificate.id === selectedCertificateId ? "employee-row selected" : "employee-row"}
                onClick={() => setSelectedCertificateId(certificate.id)}
              >
                <div>
                  <strong>{certificate.certificateNumber}</strong>
                  <p className="muted">{certificate.employeeFullName} · {formatDate(certificate.generatedAt)}</p>
                </div>
                <div className="employee-row-meta">
                  <span className={`status-chip ${statusClass(certificate.status)}`}>{certificate.status}</span>
                  <small>{certificate.certificateType}</small>
                </div>
              </button>
            ))}
            {!loading && certificates.length === 0 ? <div className="panel-empty">No hay certificados para los filtros actuales.</div> : null}
          </div>
        </section>

        <aside className="panel employee-detail-panel">
          <div className="panel-header">
            <h3>Detalle</h3>
            <span>{selectedCertificate ? selectedCertificate.status : "Sin seleccion"}</span>
          </div>
          {selectedCertificate ? (
            <div className="employee-detail">
              <h4>{selectedCertificate.certificateNumber}</h4>
              <p className="muted">{selectedCertificate.employeeFullName} · {selectedCertificate.purpose}</p>
              <dl>
                <div>
                  <dt>Estado</dt>
                  <dd><span className={`status-chip ${statusClass(selectedCertificate.status)}`}>{selectedCertificate.status}</span></dd>
                </div>
                <div>
                  <dt>Firmante</dt>
                  <dd>{selectedCertificate.signerFullName}</dd>
                </div>
                <div>
                  <dt>Generado por</dt>
                  <dd>{selectedCertificate.approvedBy || selectedCertificate.createdBy}</dd>
                </div>
              </dl>
              <pre className="preview-box">{selectedCertificate.previewContent}</pre>
              <div className="position-form-actions">
                <button type="button" onClick={() => void downloadCertificatePdf(selectedCertificate.id)}>
                  Descargar PDF
                </button>
                {canAnnul && selectedCertificate.status === "GENERADA" ? (
                  <button type="button" className="danger-action" onClick={() => void annulSelected()} disabled={actionPending}>
                    Anular
                  </button>
                ) : null}
              </div>
              <div className="position-detail-section">
                <div className="panel-header compact-header">
                  <h4>Historial</h4>
                  <span>{history.length}</span>
                </div>
                {history.map((item) => (
                  <article key={`${item.eventType}-${item.createdAt}`} className="assignment-card">
                    <div>
                      <strong>{item.eventType}</strong>
                      <p className="muted">{item.actorUsername} · {formatDate(item.createdAt)}</p>
                    </div>
                  </article>
                ))}
                {history.length === 0 ? <div className="panel-empty compact-empty">Sin historial registrado.</div> : null}
              </div>
            </div>
          ) : (
            <div className="panel-empty">Seleccione un certificado para ver su detalle.</div>
          )}
        </aside>
      </div>

      {canGenerate ? (
        <section className="panel certificate-create-panel">
          <div className="panel-header">
            <h3>Nueva certificacion</h3>
            <span>Talento Humano</span>
          </div>
          <div className="certificate-form-grid">
            <label>
              Empleado
              <input value={employeeSearch} onChange={(event) => setEmployeeSearch(event.target.value)} placeholder="Buscar empleado" />
              <select value={selectedEmployeeId} onChange={(event) => setSelectedEmployeeId(event.target.value ? Number(event.target.value) : "")}>
                <option value="">Seleccione empleado</option>
                {employees.map((employee) => (
                  <option key={employee.id} value={employee.id}>
                    {employee.fullName} · {employee.identificationNumber} · {employee.employmentStatus}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Proposito
              <select value={purpose} onChange={(event) => setPurpose(event.target.value as CertificatePurpose)}>
                {purposes.map((item) => <option key={item} value={item}>{item}</option>)}
              </select>
            </label>
            <label>
              Fecha expedicion
              <input type="date" value={issueDate} onChange={(event) => setIssueDate(event.target.value)} />
            </label>
            <label>
              Variable opcional
              <input value={variableLabel} onChange={(event) => setVariableLabel(event.target.value)} placeholder="Concepto" />
              <input value={variableAmount} onChange={(event) => setVariableAmount(event.target.value)} type="number" min="0" placeholder="Valor" />
            </label>
          </div>
          <div className="position-form-actions">
            <button type="button" onClick={() => void runPreview()} disabled={actionPending}>Preview</button>
            <button type="button" onClick={() => void generateCertificate()} disabled={actionPending || !preview}>Generar</button>
          </div>
          {preview ? (
            <div className="certificate-preview-result">
              <div>
                <span className={`status-chip ${statusClass(preview.certificateType)}`}>{preview.certificateType}</span>
                <strong>{preview.employeeFullName}</strong>
                <p className="muted">{preview.signerFullName} · {preview.purpose}</p>
              </div>
              <pre className="preview-box">{preview.previewContent}</pre>
            </div>
          ) : null}
        </section>
      ) : (
        <section className="panel">
          <p className="muted role-note">Rol de consulta: puede revisar y descargar certificados disponibles.</p>
        </section>
      )}

      {canManageSigners ? (
        <section className="panel certificate-signers-panel">
          <div className="panel-header">
            <h3>Firmantes</h3>
            <span>{signers.length} registros</span>
          </div>
          <div className="signers-grid">
            <div className="employee-table">
              {signers.map((signer) => (
                <button
                  key={signer.id}
                  type="button"
                  className={signer.id === selectedSignerId ? "employee-row selected" : "employee-row"}
                  onClick={() => selectSigner(signer)}
                >
                  <div>
                    <strong>{signer.fullName}</strong>
                    <p className="muted">{signer.jobTitle} · desde {formatDate(signer.validFrom)}</p>
                  </div>
                  <span className={`status-chip ${signer.status === "ACTIVO" ? "status-active" : "status-retired"}`}>{signer.status}</span>
                </button>
              ))}
              {signers.length === 0 ? <div className="panel-empty compact-empty">Sin firmantes registrados.</div> : null}
            </div>
            <div className="position-form">
              <label>
                Nombre
                <input value={signerForm.fullName} onChange={(event) => setSignerForm((current) => ({ ...current, fullName: event.target.value }))} />
              </label>
              <label>
                Cargo
                <input value={signerForm.jobTitle} onChange={(event) => setSignerForm((current) => ({ ...current, jobTitle: event.target.value }))} />
              </label>
              <label>
                Firma
                <input value={signerForm.signaturePath ?? ""} onChange={(event) => setSignerForm((current) => ({ ...current, signaturePath: event.target.value || null }))} />
              </label>
              <label>
                Vigente desde
                <input type="date" value={signerForm.validFrom} onChange={(event) => setSignerForm((current) => ({ ...current, validFrom: event.target.value }))} />
              </label>
              <label>
                Vigente hasta
                <input type="date" value={signerForm.validTo ?? ""} onChange={(event) => setSignerForm((current) => ({ ...current, validTo: event.target.value || null }))} />
              </label>
              <label>
                Notas
                <textarea value={signerForm.notes ?? ""} onChange={(event) => setSignerForm((current) => ({ ...current, notes: event.target.value || null }))} />
              </label>
              <div className="position-form-actions">
                <button type="button" onClick={() => void saveSigner()} disabled={actionPending}>Guardar</button>
                <button type="button" className="secondary-action" onClick={resetSignerForm} disabled={actionPending}>Nuevo</button>
                {selectedSignerId ? (
                  <button type="button" className="danger-action" onClick={() => void inactivateSelectedSigner()} disabled={actionPending}>
                    Inactivar
                  </button>
                ) : null}
              </div>
            </div>
          </div>
        </section>
      ) : null}
    </div>
  );
}

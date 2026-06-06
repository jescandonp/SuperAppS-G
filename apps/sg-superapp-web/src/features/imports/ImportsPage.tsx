import { useEffect, useState } from "react";
import { cancelImportBatch, confirmImportBatch, exportImportBatchErrors, fetchImportBatchErrors, fetchImportBatchRows, fetchImportBatches, fetchImportColumnMappings, prevalidateEmployeeCsv } from "../../services/portalApi";
import type { CurrentUser, ImportBatchError, ImportBatchRow, ImportBatchSummary, ImportColumnMapping, ImportRowClassification } from "../../types/portal";

interface ImportsPageProps {
  user: CurrentUser;
}

function formatDate(value: string | null): string {
  if (!value) {
    return "Pendiente";
  }

  return new Intl.DateTimeFormat("es-CO", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(new Date(value));
}

function getBatchStatusClass(status: ImportBatchSummary["status"]): string {
  switch (status) {
    case "IMPORTADA":
      return "status-active";
    case "PREVALIDADA":
      return "status-ready";
    case "CON_ERRORES":
      return "status-warning";
    case "PREVALIDANDO":
      return "status-pending";
    case "CANCELADA":
    case "RECHAZADA":
      return "status-retired";
    default:
      return "status-pending";
  }
}

export function ImportsPage({ user }: ImportsPageProps) {
  const canViewImports = user.role === "ADMIN" || user.role === "TH" || user.role === "GERENCIA";
  const canInspectBatches = user.role === "ADMIN" || user.role === "TH";
  const canExportErrors = canInspectBatches;
  const [batches, setBatches] = useState<ImportBatchSummary[]>([]);
  const [selectedBatchId, setSelectedBatchId] = useState<number | null>(null);
  const [errors, setErrors] = useState<ImportBatchError[]>([]);
  const [mappings, setMappings] = useState<ImportColumnMapping[]>([]);
  const [rows, setRows] = useState<ImportBatchRow[]>([]);
  const [classification, setClassification] = useState<ImportRowClassification | "">("");
  const [loading, setLoading] = useState(true);
  const [errorLoading, setErrorLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadMessage, setUploadMessage] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [actionPending, setActionPending] = useState(false);
  const [actionMessage, setActionMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!canViewImports) {
      setLoading(false);
      return;
    }

    let ignore = false;

    async function loadBatches() {
      setLoading(true);
      setErrorMessage(null);

      try {
        const data = await fetchImportBatches();
        if (ignore) {
          return;
        }

        setBatches(data);
        setSelectedBatchId(data.length > 0 ? data[0].id : null);
      } catch (error) {
        if (!ignore) {
          const message = error instanceof Error ? error.message : "No fue posible cargar historial de importaciones.";
          setErrorMessage(message);
        }
      } finally {
        if (!ignore) {
          setLoading(false);
        }
      }
    }

    void loadBatches();

    return () => {
      ignore = true;
    };
  }, [canViewImports, refreshKey]);

  useEffect(() => {
    if (selectedBatchId === null || !canInspectBatches) {
      setErrors([]);
      setMappings([]);
      setRows([]);
      return;
    }

    const batchId = selectedBatchId;
    let ignore = false;

    async function loadErrors() {
      setErrorLoading(true);

      try {
        const [data, mappingData, rowData] = await Promise.all([
          fetchImportBatchErrors(batchId),
          fetchImportColumnMappings(batchId),
          fetchImportBatchRows(batchId, classification || undefined)
        ]);
        if (!ignore) {
          setErrors(data);
          setMappings(mappingData);
          setRows(rowData);
        }
      } catch {
        if (!ignore) {
          setErrors([]);
          setMappings([]);
          setRows([]);
        }
      } finally {
        if (!ignore) {
          setErrorLoading(false);
        }
      }
    }

    void loadErrors();

    return () => {
      ignore = true;
    };
  }, [canInspectBatches, selectedBatchId, classification, refreshKey]);

  const selectedBatch = batches.find((batch) => batch.id === selectedBatchId) ?? null;
  const canManageSelected = user.role === "TH" && selectedBatch !== null && ["PREVALIDADA", "CON_ERRORES"].includes(selectedBatch.status);

  async function handleBatchAction(action: "confirm" | "cancel") {
    if (!selectedBatch || !window.confirm(action === "confirm" ? "¿Importar exclusivamente los registros validos?" : "¿Cancelar esta carga prevalidada?")) {
      return;
    }

    setActionPending(true);
    setActionMessage(null);
    try {
      if (action === "confirm") {
        await confirmImportBatch(selectedBatch.id);
      } else {
        await cancelImportBatch(selectedBatch.id);
      }
      setActionMessage(action === "confirm" ? "Importacion confirmada." : "Carga cancelada.");
      setRefreshKey((current) => current + 1);
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : "No fue posible completar la accion.");
    } finally {
      setActionPending(false);
    }
  }

  async function handleErrorExport() {
    if (selectedBatchId === null || !canExportErrors) return;
    try {
      await exportImportBatchErrors(selectedBatchId);
    } catch (error) {
      setActionMessage(error instanceof Error ? error.message : "No fue posible exportar errores.");
    }
  }

  async function handlePrevalidate() {
    if (!selectedFile) {
      setUploadMessage("Seleccione un archivo CSV o XLSX antes de prevalidar.");
      return;
    }

    setUploading(true);
    setUploadMessage(null);

    try {
      const result = await prevalidateEmployeeCsv(selectedFile, user.username);
      setUploadMessage(`${result.fileName}: ${result.validRecords}/${result.totalRecords} registros validos. Estado ${result.status}.`);
      setSelectedFile(null);
      setSelectedBatchId(result.batchId);
      setRefreshKey((current) => current + 1);
    } catch (error) {
      const message = error instanceof Error ? error.message : "No fue posible prevalidar el archivo.";
      setUploadMessage(message);
    } finally {
      setUploading(false);
    }
  }

  if (!canViewImports) {
    return (
      <div className="panel-empty">
        El modulo de cargas esta restringido a ADMIN, TH y GERENCIA segun la matriz I2.
      </div>
    );
  }

  return (
    <div className="employees-workspace">
      <div className="employees-toolbar">
        <div>
          <p className="eyebrow">I2 en curso</p>
          <h2>Historial de cargas y prevalidacion</h2>
        </div>
      </div>

      {user.role === "TH" ? (
        <section className="panel import-upload-panel">
          <div>
            <h3>Nueva prevalidacion</h3>
            <p className="muted">CSV o XLSX con encabezados conocidos. El archivo se valida antes de importar empleados.</p>
          </div>
          <div className="import-upload-controls">
            <input
              key={refreshKey}
              type="file"
              accept=".csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              onChange={(event) => setSelectedFile(event.target.files?.[0] ?? null)}
            />
            <button type="button" onClick={() => void handlePrevalidate()} disabled={uploading}>
              {uploading ? "Prevalidando..." : "Prevalidar archivo"}
            </button>
          </div>
          {uploadMessage ? <p className="muted">{uploadMessage}</p> : null}
        </section>
      ) : null}

      {errorMessage ? <div className="panel-empty">{errorMessage}</div> : null}

      <div className="employees-grid">
        <section className="panel employee-list-panel">
          <div className="panel-header">
            <h3>Historial</h3>
            <span>{loading ? "Cargando..." : `${batches.length} cargas`}</span>
          </div>

          <div className="employee-table">
            {batches.map((batch) => (
              <button
                key={batch.id}
                type="button"
                className={batch.id === selectedBatchId ? "employee-row selected" : "employee-row"}
                onClick={() => setSelectedBatchId(batch.id)}
              >
                <div>
                  <strong>{batch.fileName}</strong>
                  <p className="muted">
                    {batch.loadType} · {formatDate(batch.createdAt)}
                  </p>
                </div>
                <div className="employee-row-meta">
                  <span className={`status-chip ${getBatchStatusClass(batch.status)}`}>
                    {batch.status}
                  </span>
                  <small>{batch.validRecords}/{batch.totalRecords} validos</small>
                </div>
              </button>
            ))}

            {!loading && batches.length === 0 ? <div className="panel-empty">No hay cargas registradas.</div> : null}
          </div>
        </section>

        <aside className="panel employee-detail-panel">
          <div className="panel-header">
            <h3>Detalle de prevalidacion</h3>
            <span>{errorLoading ? "Cargando..." : `${rows.length} filas · ${errors.length} errores`}</span>
          </div>

          {selectedBatchId !== null ? (
            <div className="employee-detail">
              {batches
                .filter((batch) => batch.id === selectedBatchId)
                .map((batch) => (
                  <div key={batch.id} className="import-summary-grid">
                    <div><strong>Archivo</strong><p className="muted">{batch.fileName}</p></div>
                    <div><strong>Estado</strong><p className="muted">{batch.status}</p></div>
                    <div><strong>Usuario</strong><p className="muted">{batch.uploadedBy}</p></div>
                    <div><strong>Importado</strong><p className="muted">{formatDate(batch.importedAt)}</p></div>
                    <div><strong>Incompletos</strong><p className="muted">{batch.incompleteRecords}</p></div>
                    <div><strong>Duplicados</strong><p className="muted">{batch.duplicateRecords}</p></div>
                    <div><strong>Erroneos</strong><p className="muted">{batch.invalidRecords}</p></div>
                  </div>
                ))}

              <div className="import-actions">
                <select value={classification} onChange={(event) => setClassification(event.target.value as ImportRowClassification | "")}>
                  <option value="">Todas las filas</option>
                  <option value="VALIDO">Validas</option>
                  <option value="INCOMPLETO">Incompletas</option>
                  <option value="DUPLICADO">Duplicadas</option>
                  <option value="ERRONEO">Erroneas</option>
                </select>
                {errors.length > 0 && canExportErrors ? <button type="button" className="secondary-action" onClick={() => void handleErrorExport()}>Exportar errores CSV</button> : null}
                {canManageSelected ? <button type="button" onClick={() => void handleBatchAction("confirm")} disabled={actionPending}>Confirmar validos</button> : null}
                {canManageSelected ? <button type="button" className="danger-action" onClick={() => void handleBatchAction("cancel")} disabled={actionPending}>Cancelar carga</button> : null}
              </div>
              {actionMessage ? <p className="muted">{actionMessage}</p> : null}

              {!canInspectBatches ? (
                <div className="panel-empty">Este rol consulta el historial, pero no accede al detalle tecnico de filas y errores.</div>
              ) : (
                <div className="error-list">
                <h4>Filas prevalidadas</h4>
                {rows.map((row) => (
                  <article key={row.id} className="error-card import-row-card">
                    <div className="import-row-heading">
                      <strong>Fila {row.rowNumber} · {row.identificationType} {row.identificationNumber || "sin identificacion"}</strong>
                      <span className={`status-chip row-status-${row.classification.toLowerCase()}`}>{row.classification}</span>
                    </div>
                    <p className="muted">{row.normalizedPayload.full_name || "Sin nombre"} · {row.normalizedPayload.job_title || "Sin cargo"}</p>
                  </article>
                ))}
                {!errorLoading && rows.length === 0 ? <div className="panel-empty">No hay filas para esta clasificacion.</div> : null}

                <h4>Mapeo propuesto</h4>
                {mappings.map((mapping) => (
                  <article key={mapping.sourcePosition} className="error-card">
                    <strong>{mapping.sourceHeader}</strong>
                    <p className="muted">{mapping.targetField || "Sin campo destino"} · {mapping.mappingStatus}</p>
                  </article>
                ))}

                {errors.map((item) => (
                  <article key={item.id} className="error-card">
                    <strong>Fila {item.rowNumber} · {item.fieldName}</strong>
                    <p className="muted">{item.errorType}</p>
                    <p>{item.message}</p>
                    <small className="muted">Valor original: {item.originalValue || "vacio"}</small>
                  </article>
                ))}

                {!errorLoading && errors.length === 0 ? (
                  <div className="panel-empty">Esta carga no tiene errores registrados.</div>
                ) : null}
              </div>
              )}
            </div>
          ) : (
            <div className="panel-empty">Seleccione una carga para ver su resumen y errores.</div>
          )}
        </aside>
      </div>
    </div>
  );
}

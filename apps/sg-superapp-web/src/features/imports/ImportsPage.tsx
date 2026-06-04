import { useEffect, useState } from "react";
import { fetchImportBatchErrors, fetchImportBatches, prevalidateEmployeeCsv } from "../../services/portalApi";
import type { CurrentUser, ImportBatchError, ImportBatchSummary } from "../../types/portal";

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

export function ImportsPage({ user }: ImportsPageProps) {
  const [batches, setBatches] = useState<ImportBatchSummary[]>([]);
  const [selectedBatchId, setSelectedBatchId] = useState<number | null>(null);
  const [errors, setErrors] = useState<ImportBatchError[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorLoading, setErrorLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadMessage, setUploadMessage] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
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
  }, [refreshKey]);

  useEffect(() => {
    if (selectedBatchId === null) {
      setErrors([]);
      return;
    }

    const batchId = selectedBatchId;
    let ignore = false;

    async function loadErrors() {
      setErrorLoading(true);

      try {
        const data = await fetchImportBatchErrors(batchId);
        if (!ignore) {
          setErrors(data);
        }
      } catch {
        if (!ignore) {
          setErrors([]);
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
  }, [selectedBatchId]);

  async function handlePrevalidate() {
    if (!selectedFile) {
      setUploadMessage("Seleccione un archivo CSV antes de prevalidar.");
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
            <p className="muted">CSV inicial con encabezados conocidos. El archivo se valida antes de importar empleados.</p>
          </div>
          <div className="import-upload-controls">
            <input
              key={refreshKey}
              type="file"
              accept=".csv,text/csv"
              onChange={(event) => setSelectedFile(event.target.files?.[0] ?? null)}
            />
            <button type="button" onClick={() => void handlePrevalidate()} disabled={uploading}>
              {uploading ? "Prevalidando..." : "Prevalidar CSV"}
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
                  <span className={`status-chip ${batch.status === "IMPORTADA" ? "status-active" : "status-retired"}`}>
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
            <span>{errorLoading ? "Cargando..." : `${errors.length} errores`}</span>
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

              <div className="error-list">
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
            </div>
          ) : (
            <div className="panel-empty">Seleccione una carga para ver su resumen y errores.</div>
          )}
        </aside>
      </div>
    </div>
  );
}

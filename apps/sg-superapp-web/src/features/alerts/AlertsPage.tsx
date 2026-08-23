import { useState } from "react";
import { exportNotificationSummary, generateCertificateAlerts, generateImportAlerts, generateTrainingAlerts, sendNotificationEmailSummary } from "../../services/portalApi";
import type { CurrentUser, NotificationEmailSummaryResponse, NotificationGenerationResponse } from "../../types/portal";

interface AlertsPageProps {
  user: CurrentUser;
}

type AlertActionKey = "training" | "imports" | "certificates";

interface AlertAction {
  key: AlertActionKey;
  title: string;
  body: string;
  run: () => Promise<NotificationGenerationResponse>;
}

export function AlertsPage({ user }: AlertsPageProps) {
  const canManageAlerts = user.role === "ADMIN" || user.role === "TH";
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const [lastGeneration, setLastGeneration] = useState<NotificationGenerationResponse | null>(null);
  const [emailStatus, setEmailStatus] = useState<NotificationEmailSummaryResponse | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const actions: AlertAction[] = [
    {
      key: "training",
      title: "Cursos y acreditaciones",
      body: "Genera alertas I5 por vencimiento y criticidad.",
      run: generateTrainingAlerts
    },
    {
      key: "imports",
      title: "Importaciones con errores",
      body: "Genera alertas I2 para lotes CON_ERRORES.",
      run: generateImportAlerts
    },
    {
      key: "certificates",
      title: "Certificaciones laborales",
      body: "Genera notificaciones I4 por certificados generados, aprobados o anulados.",
      run: generateCertificateAlerts
    }
  ];

  const runGeneration = async (action: AlertAction) => {
    setBusyAction(action.key);
    setMessage(null);
    try {
      const result = await action.run();
      setLastGeneration(result);
      setMessage(`${action.title}: ${result.generatedCount} nuevas, ${result.activeAlertsCount} activas.`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible generar alertas.");
    } finally {
      setBusyAction(null);
    }
  };

  const exportSummary = async () => {
    setBusyAction("export");
    setMessage(null);
    try {
      await exportNotificationSummary({});
      setMessage("Resumen exportado como CSV.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible exportar el resumen.");
    } finally {
      setBusyAction(null);
    }
  };

  const attemptEmail = async () => {
    setBusyAction("email");
    setMessage(null);
    try {
      const result = await sendNotificationEmailSummary({
        status: "UNREAD",
        severity: undefined,
        sourceModule: undefined,
        recipient: "talento.humano@example.invalid"
      });
      setEmailStatus(result);
      setMessage(result.message);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "No fue posible intentar el envio de correo.");
    } finally {
      setBusyAction(null);
    }
  };

  if (!canManageAlerts) {
    return (
      <section className="alerts-workspace">
        <div className="panel-header compact-header">
          <div>
            <p className="eyebrow">GERENCIA/OPERACIONES</p>
            <h2>Alertas y fallback</h2>
          </div>
        </div>
        <div className="panel-empty compact-empty">Consulta disponible desde la bandeja. Sin acciones de generacion/configuracion para este rol.</div>
      </section>
    );
  }

  return (
    <section className="alerts-workspace">
      <div className="panel-header compact-header">
        <div>
          <p className="eyebrow">Talento Humano</p>
          <h2>Alertas y fallback</h2>
        </div>
        <button type="button" className="ghost-button" onClick={() => void exportSummary()} disabled={busyAction !== null}>
          Exportar resumen
        </button>
      </div>

      <div className="alert-action-grid">
        {actions.map((action) => (
          <article key={action.key} className="alert-action-card">
            <div>
              <h3>{action.title}</h3>
              <p className="muted">{action.body}</p>
            </div>
            <button type="button" onClick={() => void runGeneration(action)} disabled={busyAction !== null}>
              Generar
            </button>
          </article>
        ))}
      </div>

      <div className="alert-fallback-panel">
        <div>
          <h3>Correo y fallback</h3>
          <p className="muted">El intento de correo no bloquea la operacion; la exportacion permanece disponible.</p>
        </div>
        <button type="button" className="ghost-button" onClick={() => void attemptEmail()} disabled={busyAction !== null}>
          Intentar correo
        </button>
        <dl>
          <div>
            <dt>Fallback</dt>
            <dd>{emailStatus?.fallbackAvailable ? "Disponible" : "Pendiente de intento"}</dd>
          </div>
          <div>
            <dt>SMTP</dt>
            <dd>{emailStatus?.smtpAvailable ? "Disponible" : "No disponible"}</dd>
          </div>
          <div>
            <dt>Notificaciones</dt>
            <dd>{emailStatus?.matchedNotifications ?? lastGeneration?.activeAlertsCount ?? 0}</dd>
          </div>
        </dl>
      </div>

      {message ? <p className="role-note muted">{message}</p> : null}
    </section>
  );
}

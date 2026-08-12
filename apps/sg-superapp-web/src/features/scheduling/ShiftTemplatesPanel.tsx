import type { ShiftTemplate } from "../../types/portal";

interface Props { templates: ShiftTemplate[]; }

export function ShiftTemplatesPanel({ templates }: Props) {
  return <section className="scheduling-section" aria-labelledby="templates-title">
    <div className="scheduling-section-heading"><div><p className="eyebrow">Patrones operativos</p><h2 id="templates-title">Plantillas de turnos</h2></div><p className="muted">La plantilla es obligatoria por defecto; toda desviación requiere motivo y auditoría.</p></div>
    <div className="template-grid">{templates.map((template) => <article className="template-card" key={template.id}>
      <div className="template-card-heading"><strong>{template.code}</strong><span className={`schedule-badge ${template.status === "ACTIVO" ? "is-ok" : "is-muted"}`}>{template.status}</span></div>
      <h3>{template.name}</h3><p className="template-sequence" aria-label={`Secuencia ${template.code}`}>{template.steps.map((step) => step.shiftCode).join(" · ")}</p><p className="muted">Versión {template.version}</p>
      {template.mandatoryByDefault && <span className="mandatory-label">Obligatoria por defecto</span>}
    </article>)}</div>
  </section>;
}

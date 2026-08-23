import type {
  SchedulingRuleEvaluation,
  SchedulingRuleEvaluationState,
  SchedulingRuleProblem,
  SchedulingRuleProfileState,
  SchedulingRuleRevalidationState
} from "../../types/portal";

// Shows what the rules said. It never decides: no verdict here is computed, and nothing on this
// screen concludes whether the schedule may be approved. That answer belongs to the server, which
// gives it when the transition is attempted, and the refusal is rendered below as it arrives.
interface Props {
  profile: SchedulingRuleProfileState;
  evaluation: SchedulingRuleEvaluationState;
  revalidation: SchedulingRuleRevalidationState;
  gateProblem: SchedulingRuleProblem | null;
  onOpenExceptions: () => void;
}

// The remedy differs per outcome, so each one says what to do rather than leaving the reader to
// infer it from a colour.
const OUTCOME_COPY: Record<string, { label: string; tone: string; action: string }> = {
  BLOCKED: {
    label: "BLOCKED",
    tone: "is-blocked",
    action: "Corrija la programación y vuelva a evaluar: una regla bloqueada no se levanta reevaluando sin cambios."
  },
  EXCEPTION_REQUIRED: {
    label: "EXCEPTION_REQUIRED",
    tone: "is-exception",
    action: "Requiere una decisión con motivo del catálogo versionado, ligada a este alcance."
  },
  WARNING: {
    label: "WARNING",
    tone: "is-warning",
    action: "Sin verificar. Una regla sin verificar no acredita cumplimiento."
  },
  COMPLIANT: { label: "COMPLIANT", tone: "is-compliant", action: "Sin observaciones." },
  NOT_APPLICABLE: { label: "NOT_APPLICABLE", tone: "is-neutral", action: "No aplica a este alcance." }
};

function RuleRow({ evaluation, onOpenExceptions }: { evaluation: SchedulingRuleEvaluation; onOpenExceptions: () => void }) {
  const copy = OUTCOME_COPY[evaluation.outcome] ?? {
    label: evaluation.outcome,
    tone: "is-warning",
    action: "Resultado fuera del contrato conocido; no se presume cumplimiento."
  };
  return (
    <article className={`rule-row ${copy.tone}`}>
      <div className="rule-row-head">
        <strong>{evaluation.ruleCode}</strong>
        <span className="schedule-badge">{copy.label}</span>
      </div>
      <p>{evaluation.explanation}</p>
      <p className="rule-action">{copy.action}</p>
      {evaluation.outcome === "EXCEPTION_REQUIRED" && (
        <button type="button" className="rule-link" onClick={onOpenExceptions}>
          Ir a excepciones
        </button>
      )}
      <small className="rule-scope">
        {evaluation.messageCode} · perfil v{evaluation.profileVersion} · alcance {evaluation.scopeHash.slice(0, 12)}…
      </small>
    </article>
  );
}

export function RuleEvaluationPanel({ profile, evaluation, revalidation, gateProblem, onOpenExceptions }: Props) {
  // Rendered in every state, including while loading and after a failure: the reader must never be
  // left looking at this screen without knowing the data behind it is a simulated MVP scenario.
  const simulatedBadge = <span className="schedule-badge is-simulated">DATOS SIMULADOS - MVP</span>;
  const unexpectedOrigin = profile.status === "READY" && !profile.profile.simulated;

  return (
    <section className="scheduling-section" aria-labelledby="rules-title">
      <div className="scheduling-section-heading">
        <div>
          <p className="eyebrow">Reglas versionadas</p>
          <h2 id="rules-title">Evaluación de reglas</h2>
        </div>
        {simulatedBadge}
      </div>

      {unexpectedOrigin && (
        <p className="schedule-alert is-error" role="alert">
          El perfil vigente no está marcado como simulado. Este MVP solo opera sobre escenarios simulados.
        </p>
      )}

      <div className="rule-profile-state" role="status" aria-live="polite">
        {profile.status === "IDLE" && <p className="muted">Seleccione un proyecto y un periodo para consultar el perfil vigente.</p>}
        {profile.status === "LOADING" && <p className="muted">Consultando el perfil de reglas…</p>}
        {profile.status === "READY" && (
          <p>
            Perfil <strong>{profile.profile.profileCode}</strong> versión {profile.profile.version} ·{" "}
            {profile.profile.environmentScope} · checksum {profile.profile.checksum.slice(0, 12)}…
          </p>
        )}
        {/* An unconfigured scope is not a clean schedule. Saying so plainly is the whole point. */}
        {profile.status === "UNCONFIGURED" && (
          <p className="schedule-alert is-warning">{profile.message} No hay reglas que respalden una decisión sobre este periodo.</p>
        )}
        {profile.status === "FAILED" && (
          <p className="schedule-alert is-error" role="alert">
            No fue posible confirmar el perfil vigente: {profile.problem.message}
          </p>
        )}
      </div>

      {gateProblem && (
        <div className="schedule-alert is-error" role="alert">
          <strong>{gateProblem.title ?? "La programación no puede avanzar"}</strong>
          <span>{gateProblem.message}</span>
          {gateProblem.code && <small className="rule-scope">{gateProblem.code}</small>}
        </div>
      )}

      <div className="rule-list" role="status" aria-live="polite">
        {evaluation.status === "IDLE" && <div className="panel-empty">Aún no se han consultado las evaluaciones de esta versión.</div>}
        {evaluation.status === "LOADING" && <div className="panel-empty">Evaluando reglas…</div>}
        {evaluation.status === "FAILED" && (
          <div className="schedule-alert is-error" role="alert">No fue posible leer las evaluaciones: {evaluation.problem.message}</div>
        )}
        {evaluation.status === "READY" && evaluation.evaluations.length === 0 && (
          <div className="schedule-alert is-warning">
            No hay evaluaciones registradas para esta versión. Sin evaluación no se presume cumplimiento.
          </div>
        )}
        {evaluation.status === "READY" &&
          evaluation.evaluations
            .slice()
            .sort((left, right) => left.ruleCode.localeCompare(right.ruleCode))
            .map((item) => <RuleRow key={`${item.ruleCode}-${item.scopeHash}`} evaluation={item} onOpenExceptions={onOpenExceptions} />)}
      </div>

      {/* The only response that carries the server's own summary is a re-evaluation, so it is shown
          as what it is - the result of the last revalidation - and never as a standing verdict. */}
      {revalidation.status === "READY" && (
        <p className="rule-summary" role="status">
          Última revalidación: {revalidation.batch.summary.total} reglas · {revalidation.batch.summary.blocked} bloqueadas ·{" "}
          {revalidation.batch.summary.exceptionRequired} con excepción requerida · {revalidation.batch.summary.warning} sin verificar
        </p>
      )}
      {revalidation.status === "LOADING" && <p className="muted" role="status">Revalidando tras la edición…</p>}
      {revalidation.status === "FAILED" && (
        <p className="schedule-alert is-error" role="alert">La revalidación no pudo completarse: {revalidation.problem.message}</p>
      )}
    </section>
  );
}

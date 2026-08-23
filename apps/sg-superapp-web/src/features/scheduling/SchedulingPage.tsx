import { useEffect, useMemo, useState } from "react";
import { PortalApiError, approveSchedule, approveScheduleException, downloadSchedulePdf, downloadScheduleXlsx, fetchSchedulingCapabilities, fetchSchedulingProjects, fetchShiftTemplates, fetchSchedulingRuleEvaluations, fetchSchedulingRuleProfiles, generateScheduleProposal, publishSchedule, replanSchedule } from "../../services/portalApi";
import type { CurrentUser, ScheduleAssignment, ScheduleComparison, ScheduleProposal, SchedulingCapabilities, SchedulingProject, ShiftTemplate } from "../../types/portal";
import type { SchedulingRuleEvaluationState, SchedulingRuleProblem, SchedulingRuleProfileState, SchedulingRuleRevalidationState } from "../../types/portal";
import { RuleEvaluationPanel } from "./RuleEvaluationPanel";
import { ExceptionPanel } from "./ExceptionPanel";
import { ProposalComparison } from "./ProposalComparison";
import { ScheduleMatrix } from "./ScheduleMatrix";
import { ShiftTemplatesPanel } from "./ShiftTemplatesPanel";

interface Props { user: CurrentUser; }
type Tab = "Plantillas" | "Matriz" | "Reglas" | "Comparar" | "Excepciones";

// The interface suggests; it does not decide. A button is only ever disabled for something the
// screen knows without predicting - the permission the server granted, the state the version is
// in, or a request already in flight - and it always says which. Whether the rules allow the
// transition is the server's answer to the transition itself, never a guess made here.
function actionState(allowed: boolean, expected: string, status: string | undefined, busy: boolean): { disabled: boolean; reason: string | null } {
  if (!allowed) return { disabled: true, reason: "No tiene permiso para esta acción." };
  if (status !== expected) return { disabled: true, reason: `Solo una versión en estado ${expected} admite esta acción.` };
  if (busy) return { disabled: true, reason: "Hay una operación en curso." };
  return { disabled: false, reason: null };
}

function toProblem(caught: unknown): SchedulingRuleProblem {
  if (caught instanceof PortalApiError) return caught.problem;
  return { status: 0, code: null, title: null, message: caught instanceof Error ? caught.message : "La acción no pudo completarse." };
}
const emptyCapabilities: SchedulingCapabilities = { view: false, configure: false, generate: false, approveException: false, approve: false, publish: false, export: false };
const demoCapabilities: SchedulingCapabilities = { view: true, configure: true, generate: true, approveException: true, approve: true, publish: true, export: true };
const demoTemplates: ShiftTemplate[] = [
  { id: 1, code: "2x2", name: "Dos diurnos, dos nocturnos, dos descansos", version: 1, mandatoryByDefault: true, status: "ACTIVO", steps: ["D", "D", "N", "N", "X", "X"].map((shiftCode, index) => ({ order: index + 1, shiftCode: shiftCode as "D" | "N" | "X" })) },
  { id: 2, code: "4x2", name: "Cuatro diurnos, dos nocturnos, dos descansos", version: 1, mandatoryByDefault: true, status: "ACTIVO", steps: ["D", "D", "D", "D", "N", "N", "X", "X"].map((shiftCode, index) => ({ order: index + 1, shiftCode: shiftCode as "D" | "N" | "X" })) },
  { id: 3, code: "6x1", name: "Seis diurnos y un descanso", version: 1, mandatoryByDefault: true, status: "ACTIVO", steps: ["D", "D", "D", "D", "D", "D", "X"].map((shiftCode, index) => ({ order: index + 1, shiftCode: shiftCode as "D" | "N" | "X" })) }
];
const demoProjects: SchedulingProject[] = [{ id: 1, clientId: 1, code: "DEMO", name: "Proyecto demostrativo (sin datos reales)", effectiveFrom: "2026-01-01", effectiveTo: null, status: "ACTIVO" }];

function demoProposal(projectId: number, periodStart: string, periodEnd: string): ScheduleProposal {
  const assignments: ScheduleAssignment[] = Array.from({ length: 21 }, (_, index) => { const employeeId = 101 + (index % 3); const day = 1 + Math.floor(index / 3); const shiftCode = (["D", "N", "X"] as const)[(day + employeeId) % 3]; return { id: index + 1, date: `2026-08-${String(day).padStart(2, "0")}`, startsAt: shiftCode === "N" ? "18:00" : "06:00", endsAt: shiftCode === "N" ? "06:00" : "18:00", positionId: 1, employeeId, shiftCode, status: index === 17 ? "VACANTE" : "ASIGNADA", score: 92 - (index % 7), reasons: [{ code: "TPL", severity: "INFORMATIVA", message: `Coincide con la plantilla cíclica seleccionada.` }] }; });
  return { versionId: 1, scheduleId: 1, projectId, versionNumber: 1, status: "PROPUESTA", periodStart, periodEnd, coveragePercent: 95.2, vacancyCount: 1, exceptionCount: 1, acceptedVacancy: false, createdBy: "demo", approvedBy: null, publishedBy: null, selfManaged: false, assignments, exceptions: [{ id: 1, exceptionType: "REQUISITO_SUBSANABLE", reason: "Ejemplo demostrativo pendiente de soporte.", responsible: "Talento Humano", resolutionDate: "2026-08-05", status: "REGISTRADA" }] };
}

export function SchedulingPage({ user }: Props) {
  const demoMode = new URLSearchParams(window.location.search).get("demo") === "scheduling";
  const [capabilities, setCapabilities] = useState(emptyCapabilities); const [projects, setProjects] = useState<SchedulingProject[]>([]); const [templates, setTemplates] = useState<ShiftTemplate[]>([]);
  const [projectId, setProjectId] = useState<number | "">(""); const [periodStart, setPeriodStart] = useState("2026-08-01"); const [periodEnd, setPeriodEnd] = useState("2026-08-31");
  const [proposal, setProposal] = useState<ScheduleProposal | null>(null); const [selectedAssignment, setSelectedAssignment] = useState<ScheduleAssignment | null>(null); const [scenarios, setScenarios] = useState<ScheduleComparison[]>([]);
  const [tab, setTab] = useState<Tab>("Plantillas"); const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [message, setMessage] = useState<string | null>(null); const [error, setError] = useState<string | null>(null);
  const [ruleProfile, setRuleProfile] = useState<SchedulingRuleProfileState>({ status: "IDLE" });
  const [ruleEvaluation, setRuleEvaluation] = useState<SchedulingRuleEvaluationState>({ status: "IDLE" });
  const [ruleRevalidation] = useState<SchedulingRuleRevalidationState>({ status: "IDLE" });
  const [gateProblem, setGateProblem] = useState<SchedulingRuleProblem | null>(null);
  const readOnly = proposal?.status === "PUBLICADA";
  // demoMode is not evidence that a profile said the data is simulated, so it no longer stands in
  // for one: the hero says the same thing the panel says, and the demo badge beside it already
  // tells the reader which mode they are in.
  const simulatedOrigin = ruleProfile.status === "READY" && ruleProfile.profile.simulated;
  // Both derived here and nowhere else. A reviewer showed that moving a rule check one line above
  // actionState defeated the gate meant to forbid it, and worse, actionState then blamed its first
  // branch - the screen told a user with the permission that they lacked it. The disabled prop must
  // come from these two and nothing may be combined into it.
  const approveAction = actionState(capabilities.approve, "PROPUESTA", proposal?.status, busy);
  const publishAction = actionState(capabilities.publish, "APROBADA", proposal?.status, busy);
  const selectedProject = useMemo(() => projects.find((item) => item.id === projectId), [projectId, projects]);

  useEffect(() => { let ignore = false; async function load() { setLoading(true); setError(null); try { if (demoMode) { if (!ignore) { setCapabilities(demoCapabilities); setProjects(demoProjects); setTemplates(demoTemplates); setProjectId(1); } return; } const [nextCapabilities, nextProjects, nextTemplates] = await Promise.all([fetchSchedulingCapabilities(), fetchSchedulingProjects(), fetchShiftTemplates()]); if (!ignore) { setCapabilities(nextCapabilities); setProjects(nextProjects); setTemplates(nextTemplates); } } catch (caught) { if (!ignore) setError(caught instanceof Error ? caught.message : "No fue posible cargar la programación."); } finally { if (!ignore) setLoading(false); } } void load(); return () => { ignore = true; }; }, [demoMode]);

  async function generate() { if (!projectId || !capabilities.generate) return; setBusy(true); setError(null); setMessage(null); try { const next = demoMode ? demoProposal(projectId, periodStart, periodEnd) : await generateScheduleProposal(projectId, { periodStart, periodEnd }); setProposal(next); setSelectedAssignment(next.assignments?.[0] ?? null); setTab("Matriz"); setMessage("Propuesta generada para revisión humana."); setGateProblem(null); if (!demoMode) { void loadRuleState(next.versionId); } } catch (caught) { setError(caught instanceof Error ? caught.message : "No fue posible generar la propuesta."); } finally { setBusy(false); } }
  async function compare() { if (!proposal) return; setBusy(true); setError(null); try { const next = demoMode ? [{ mode: "MINIMUM_IMPACT", changedAssignments: 3, additionalHours: 4, vacancies: 1, exceptions: 1 }, { mode: "GLOBAL", changedAssignments: 8, additionalHours: 0, vacancies: 0, exceptions: 2 }] as ScheduleComparison[] : (await replanSchedule(proposal.versionId, { triggerType: "MANUAL_REVIEW", triggerId: String(proposal.versionId), modes: ["MINIMUM_IMPACT", "GLOBAL"] })).scenarios; setScenarios(next); setTab("Comparar"); } catch (caught) { setError(toProblem(caught).message); } finally { setBusy(false); } }
  // A refused deviation used to leave no trace on screen at all: the panel cleared its spinner and
  // the list simply did not grow, which reads as "nothing happened" rather than "it was refused".
  async function registerException(reason: string) { if (!proposal || demoMode) { setMessage(`Desviación demostrativa registrada: ${reason}`); return; } try { const next = await approveScheduleException(proposal.versionId, { exceptionType: "DESVIACION_PLANTILLA", reason, responsible: user.fullName, resolutionDate: periodEnd, expectedVersion: proposal.versionNumber }); setProposal(next); setError(null); } catch (caught) { const problem = toProblem(caught); setError(problem.message); setGateProblem(problem); throw caught; } }
  // Reads what the rules said for this version. Nothing here evaluates: a re-evaluation writes, and
  // opening a screen must not.
  async function loadRuleState(versionId: number) {
    setRuleEvaluation({ status: "LOADING" });
    try { setRuleEvaluation({ status: "READY", evaluations: await fetchSchedulingRuleEvaluations(versionId) }); }
    catch (caught) { setRuleEvaluation({ status: "FAILED", problem: toProblem(caught) }); }
  }

  // A profile is scoped to a project AND a period, so changing either one changes which profile
  // governs. Reloading only on the project left the panel describing a different period than the
  // one on screen.
  function reloadProfileFor(period: string) {
    const chosen = projects.find((item) => item.id === projectId);
    if (chosen && !demoMode) void loadRuleProfile(chosen.code, period);
  }

  async function loadRuleProfile(code: string, period: string) {
    setRuleProfile({ status: "LOADING" });
    try {
      const active = (await fetchSchedulingRuleProfiles(code, period, "MVP_TEST")).filter((item) => item.status === "ACTIVE");
      if (active.length === 1) setRuleProfile({ status: "READY", profile: active[0] });
      else if (active.length === 0) setRuleProfile({ status: "UNCONFIGURED", message: "No hay un perfil de reglas vigente para este proyecto y periodo." });
      else setRuleProfile({ status: "FAILED", problem: { status: 0, code: null, title: null, message: "Hay mas de un perfil de reglas vigente para el mismo alcance." } });
    } catch (caught) { setRuleProfile({ status: "FAILED", problem: toProblem(caught) }); }
  }

  // The server decides. When it refuses, its typed reason is what the screen shows - the interface
  // never predicted the outcome, so it has nothing of its own to contradict.
  async function approve() { if (!proposal) return; setBusy(true); setGateProblem(null); try { const next = demoMode ? { ...proposal, status: "APROBADA" as const, approvedBy: user.fullName } : await approveSchedule(proposal.versionId, proposal.versionNumber); setProposal(next); setMessage("Programación aprobada."); } catch (caught) { setGateProblem(toProblem(caught)); setTab("Reglas"); } finally { setBusy(false); } }
  async function publish() { if (!proposal) return; setBusy(true); setGateProblem(null); try { const next = demoMode ? { ...proposal, status: "PUBLICADA" as const, publishedBy: user.fullName } : await publishSchedule(proposal.versionId, proposal.versionNumber); setProposal(next); setMessage("Programación publicada en modo de solo lectura."); } catch (caught) { setGateProblem(toProblem(caught)); setTab("Reglas"); } finally { setBusy(false); } }
  async function exportFile(format: "pdf" | "xlsx") { if (!proposal) return; setBusy(true); setError(null); try { if (!demoMode) await (format === "pdf" ? downloadSchedulePdf(proposal.versionId) : downloadScheduleXlsx(proposal.versionId)); else setMessage(`Exportación ${format.toUpperCase()} simulada en modo demostrativo.`); } catch (caught) { setError(toProblem(caught).message); } finally { setBusy(false); } }

  if (loading) return <div className="panel-empty" aria-live="polite">Cargando programación…</div>;
  if (error && projects.length === 0) return <section className="scheduling-workspace"><div className="schedule-alert is-error" role="alert"><strong>No fue posible cargar la programación.</strong><span>{error}</span></div><p className="muted">Verifique la conexión o use <code>?demo=scheduling</code> para el recorrido sin datos reales.</p></section>;

  return <main className="scheduling-workspace">
    <header className="scheduling-hero"><div><p className="eyebrow">Operaciones · Programación asistida</p><h1>Programación de turnos</h1><p>Configure el periodo, revise la propuesta del motor y mantenga la decisión humana trazable.</p></div><div className="hero-status"><span className="schedule-badge">{demoMode ? "MODO DEMO" : proposal?.status ?? "SIN PROPUESTA"}</span>{/* Visible on every tab and in every state, and it never claims more than is known: the origin
            is only called simulated once a profile has actually said so. */}
        <span className="schedule-badge is-simulated">{simulatedOrigin ? "DATOS SIMULADOS - MVP" : "ORIGEN DE REGLAS SIN CONFIRMAR"}</span><small>{selectedProject?.name ?? "Seleccione un proyecto"}</small></div></header>
    <section className="scheduling-control-bar" aria-label="Filtros de programación"><label>Proyecto<select value={projectId} onChange={(event) => { const nextId = event.target.value ? Number(event.target.value) : ""; setProjectId(nextId); setProposal(null); setGateProblem(null); const chosen = projects.find((item) => item.id === nextId); if (chosen && !demoMode) void loadRuleProfile(chosen.code, periodStart); else setRuleProfile({ status: "IDLE" }); }}><option value="">Seleccione un proyecto</option>{projects.map((project) => <option key={project.id} value={project.id}>{project.name}</option>)}</select></label><label>Desde<input type="date" value={periodStart} onChange={(event) => { setPeriodStart(event.target.value); reloadProfileFor(event.target.value); }} /></label><label>Hasta<input type="date" value={periodEnd} min={periodStart} onChange={(event) => setPeriodEnd(event.target.value)} /></label>{capabilities.generate && <button className="schedule-primary" disabled={!projectId || busy || Boolean(readOnly)} onClick={generate}>{busy ? "Procesando…" : proposal ? "Regenerar propuesta" : "Generar propuesta"}</button>}</section>
    <div className="schedule-live-region" aria-live="polite">{message && <p className="schedule-alert is-success">{message}</p>}{error && <p className="schedule-alert is-error">{error}</p>}</div>
    {proposal && <section className="schedule-summary" aria-label="Resumen de propuesta"><div><span>Cobertura</span><strong>{proposal.coveragePercent}%</strong></div><div><span>Vacantes</span><strong>{proposal.vacancyCount}</strong></div><div><span>Excepciones</span><strong>{proposal.exceptionCount}</strong></div><div><span>Versión</span><strong>v{proposal.versionNumber}</strong></div><div className="summary-actions">{<button onClick={approve} disabled={approveAction.disabled} aria-describedby="approve-reason">Aprobar</button>}{<button onClick={publish} disabled={publishAction.disabled} aria-describedby="publish-reason">Publicar</button>}{capabilities.export && <><button onClick={() => exportFile("pdf")} disabled={busy}>PDF</button><button onClick={() => exportFile("xlsx")} disabled={busy}>Excel</button></>}{proposal.status === "PUBLICADA" && capabilities.generate && <button onClick={() => { setProposal(null); setTab("Plantillas"); }}>Crear nueva versión</button>}</div><div className="summary-reasons" role="status" aria-live="polite"><small id="approve-reason">{approveAction.reason ?? "Aprobar disponible; la decisión la confirma el servidor."}</small><small id="publish-reason">{publishAction.reason ?? "Publicar disponible; la decisión la confirma el servidor."}</small></div></section>}
    <nav className="scheduling-tabs" aria-label="Secciones de programación">{(["Plantillas", "Matriz", "Reglas", "Comparar", "Excepciones"] as Tab[]).map((item) => <button key={item} aria-pressed={tab === item} onClick={() => setTab(item)}>{item}</button>)}</nav>
    {!proposal && tab !== "Plantillas" ? <div className="panel-empty">Seleccione un proyecto y genere una propuesta para continuar.</div> : <>{tab === "Plantillas" && <ShiftTemplatesPanel templates={templates} />}{tab === "Matriz" && proposal && <ScheduleMatrix assignments={proposal.assignments ?? []} readOnly={Boolean(readOnly)} onSelect={setSelectedAssignment} selectedAssignment={selectedAssignment} />}{tab === "Reglas" && proposal && <RuleEvaluationPanel profile={ruleProfile} evaluation={ruleEvaluation} revalidation={ruleRevalidation} gateProblem={gateProblem} onOpenExceptions={() => setTab("Excepciones")} onReload={() => { if (proposal) void loadRuleState(proposal.versionId); }} />}{tab === "Comparar" && proposal && <ProposalComparison scenarios={scenarios} onGenerate={compare} canGenerate={capabilities.generate && !readOnly} busy={busy} />}{tab === "Excepciones" && proposal && <ExceptionPanel exceptions={proposal.exceptions ?? []} capabilities={capabilities} readOnly={Boolean(readOnly)} onSubmit={registerException} />}</>}
  </main>;
}

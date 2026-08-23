import type { ScheduleAssignment } from "../../types/portal";

interface Props { assignments: ScheduleAssignment[]; readOnly: boolean; onSelect: (assignment: ScheduleAssignment) => void; selectedAssignment: ScheduleAssignment | null; }
const dateLabel = (value: string) => new Intl.DateTimeFormat("es-CO", { day: "2-digit", month: "short" }).format(new Date(`${value}T12:00:00`));
const assignmentCode = (assignment?: ScheduleAssignment) => assignment?.status === "VACANTE" ? "VACANTE" : assignment?.shiftCode ?? "X";

export function ScheduleMatrix({ assignments, readOnly, onSelect, selectedAssignment }: Props) {
  const dates = Array.from(new Set(assignments.map((item) => item.date))).sort();
  const guards = Array.from(new Set(assignments.flatMap((item) => item.employeeId ? [item.employeeId] : [])))
    .sort((left, right) => left - right)
    .map((id) => ({ id, name: `Guarda ${id}` }));
  return <section className="scheduling-matrix-layout" aria-labelledby="matrix-title">
    <div className="scheduling-matrix-card"><div className="scheduling-section-heading"><div><p className="eyebrow">Cobertura mensual</p><h2 id="matrix-title">Matriz de programación</h2></div><div className="schedule-legend" aria-label="Convenciones de turno"><span><b>D</b> Diurno</span><span><b>N</b> Nocturno</span><span><b>X</b> Descanso</span><span><b>VACANTE</b> Sin asignar</span></div></div>
      <div className="scheduling-table-scroll"><table className="scheduling-table"><caption>Turnos diarios por guarda; seleccione una celda para ver su explicación.</caption><thead><tr><th scope="col">Guarda</th>{dates.map((date) => <th scope="col" key={date}>{dateLabel(date)}</th>)}</tr></thead><tbody>{guards.map((guard) => <tr key={guard.id}><th scope="row">{guard.name}</th>{dates.map((date) => { const assignment = assignments.find((item) => item.employeeId === guard.id && item.date === date); const code = assignmentCode(assignment); return <td key={date}><button className={`shift-cell shift-${code.toLowerCase()}`} disabled={!assignment} aria-label={`${guard.name}, ${dateLabel(date)}, turno ${code}`} onClick={() => assignment && onSelect(assignment)}>{code}</button></td>; })}</tr>)}</tbody></table></div>
      <div className="scheduling-mobile-list" aria-label="Programación diaria">{dates.map((date) => <article key={date}><strong>{dateLabel(date)}</strong>{assignments.filter((item) => item.date === date).map((item) => <button key={item.id} onClick={() => onSelect(item)} aria-label={`Guarda ${item.employeeId ?? "sin asignar"}, ${dateLabel(date)}, turno ${assignmentCode(item)}`}><span>Guarda {item.employeeId ?? "sin asignar"}</span><b>{assignmentCode(item)}</b></button>)}</article>)}</div>
    </div>
    <aside className="assignment-detail" aria-label="Explicación de asignación"><p className="eyebrow">Detalle explicable</p>{selectedAssignment ? <><h3>{selectedAssignment.status === "VACANTE" ? "Puesto vacante" : `Turno ${selectedAssignment.shiftCode}`}</h3><dl><div><dt>Fecha</dt><dd>{dateLabel(selectedAssignment.date)}</dd></div><div><dt>Horario</dt><dd>{selectedAssignment.startsAt}–{selectedAssignment.endsAt}</dd></div><div><dt>Puntaje</dt><dd>{selectedAssignment.score ?? "No informado"}</dd></div></dl><h4>Razones del motor</h4>{selectedAssignment.reasons.length ? <ul>{selectedAssignment.reasons.map((reason) => <li key={`${reason.code}-${reason.message}`}><strong>{reason.severity}</strong> · {reason.message}</li>)}</ul> : <p className="muted">Sin razones registradas.</p>}{readOnly && <p className="read-only-note">Versión publicada: consulta de solo lectura.</p>}</> : <p className="muted">Seleccione una celda para revisar las reglas aplicadas.</p>}</aside>
  </section>;
}

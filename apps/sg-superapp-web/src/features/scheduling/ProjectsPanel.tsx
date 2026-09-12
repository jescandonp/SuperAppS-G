import { useEffect, useState } from "react";
import {
  createSchedulingClient,
  createSchedulingProject,
  fetchSchedulingClientDetail,
  fetchSchedulingClients,
  fetchSchedulingProjectDetail,
  fetchSchedulingProjects,
  inactivateSchedulingClient,
  inactivateSchedulingProject,
  updateSchedulingClient,
  updateSchedulingProject
} from "../../services/portalApi";
import type { SchedulingClient, SchedulingProject } from "../../types/portal";

interface Props {
  // Se llama tras crear/editar/inactivar un proyecto, para que SchedulingPage refresque su
  // selector de proyecto sin recargar la pagina.
  onProjectsChanged: () => void;
}

interface ClientFormState {
  code: string;
  name: string;
  status: "ACTIVO" | "INACTIVO";
}

interface ProjectFormState {
  clientId: string;
  code: string;
  name: string;
  effectiveFrom: string;
  effectiveTo: string;
  status: "ACTIVO" | "INACTIVO";
}

function emptyClientForm(): ClientFormState {
  return { code: "", name: "", status: "ACTIVO" };
}

function emptyProjectForm(): ProjectFormState {
  return { clientId: "", code: "", name: "", effectiveFrom: "", effectiveTo: "", status: "ACTIVO" };
}

export function ProjectsPanel({ onProjectsChanged }: Props) {
  const [clients, setClients] = useState<SchedulingClient[]>([]);
  const [clientsLoading, setClientsLoading] = useState(true);
  const [clientsError, setClientsError] = useState<string | null>(null);
  const [clientsRefreshKey, setClientsRefreshKey] = useState(0);
  const [selectedClientId, setSelectedClientId] = useState<number | null>(null);
  const [clientFormMode, setClientFormMode] = useState<"edit" | "create">("create");
  const [clientForm, setClientForm] = useState<ClientFormState>(emptyClientForm());
  const [clientMessage, setClientMessage] = useState<string | null>(null);
  const [clientPending, setClientPending] = useState(false);

  const [projects, setProjects] = useState<SchedulingProject[]>([]);
  const [projectsLoading, setProjectsLoading] = useState(true);
  const [projectsError, setProjectsError] = useState<string | null>(null);
  const [projectsRefreshKey, setProjectsRefreshKey] = useState(0);
  const [selectedProjectId, setSelectedProjectId] = useState<number | null>(null);
  const [projectFormMode, setProjectFormMode] = useState<"edit" | "create">("create");
  const [projectForm, setProjectForm] = useState<ProjectFormState>(emptyProjectForm());
  const [projectMessage, setProjectMessage] = useState<string | null>(null);
  const [projectPending, setProjectPending] = useState(false);

  useEffect(() => {
    let ignore = false;
    async function load() {
      setClientsLoading(true);
      setClientsError(null);
      try {
        const data = await fetchSchedulingClients();
        if (!ignore) setClients(data);
      } catch (error) {
        if (!ignore) {
          setClients([]);
          setClientsError(error instanceof Error ? error.message : "No fue posible cargar los clientes.");
        }
      } finally {
        if (!ignore) setClientsLoading(false);
      }
    }
    void load();
    return () => { ignore = true; };
  }, [clientsRefreshKey]);

  useEffect(() => {
    let ignore = false;
    async function load() {
      setProjectsLoading(true);
      setProjectsError(null);
      try {
        const data = await fetchSchedulingProjects();
        if (!ignore) setProjects(data);
      } catch (error) {
        if (!ignore) {
          setProjects([]);
          setProjectsError(error instanceof Error ? error.message : "No fue posible cargar los proyectos.");
        }
      } finally {
        if (!ignore) setProjectsLoading(false);
      }
    }
    void load();
    return () => { ignore = true; };
  }, [projectsRefreshKey]);

  function startCreateClient() {
    setClientFormMode("create");
    setSelectedClientId(null);
    setClientForm(emptyClientForm());
    setClientMessage(null);
  }

  function selectClient(client: SchedulingClient) {
    setSelectedClientId(client.id);
    setClientFormMode("edit");
    setClientForm({ code: client.code, name: client.name, status: client.status });
    setClientMessage(null);
  }

  async function saveClient() {
    const code = clientForm.code.trim();
    const name = clientForm.name.trim();
    if (!code || !name) {
      setClientMessage("Codigo y nombre del cliente son obligatorios.");
      return;
    }

    setClientPending(true);
    setClientMessage(null);
    try {
      const request = { code, name, status: clientForm.status };
      if (clientFormMode === "create") {
        const created = await createSchedulingClient(request);
        const detail = await fetchSchedulingClientDetail(created.id);
        setClientsRefreshKey((value) => value + 1);
        selectClient(detail);
        setClientMessage("Cliente creado.");
      } else if (selectedClientId !== null) {
        const updated = await updateSchedulingClient(selectedClientId, request);
        setClients((current) => current.map((item) => item.id === updated.id ? updated : item));
        setClientMessage("Cliente actualizado.");
      }
    } catch (error) {
      setClientMessage(error instanceof Error ? error.message : "No fue posible guardar el cliente.");
    } finally {
      setClientPending(false);
    }
  }

  async function inactivateClient() {
    if (selectedClientId === null) return;
    if (!window.confirm("¿Inactivar este cliente?")) return;

    setClientPending(true);
    setClientMessage(null);
    try {
      const updated = await inactivateSchedulingClient(selectedClientId);
      setClients((current) => current.map((item) => item.id === updated.id ? updated : item));
      setClientForm((current) => ({ ...current, status: updated.status }));
      setClientMessage("Cliente inactivado.");
    } catch (error) {
      setClientMessage(error instanceof Error ? error.message : "No fue posible inactivar el cliente.");
    } finally {
      setClientPending(false);
    }
  }

  function startCreateProject() {
    setProjectFormMode("create");
    setSelectedProjectId(null);
    setProjectForm({ ...emptyProjectForm(), clientId: clients[0]?.id.toString() || "" });
    setProjectMessage(null);
  }

  function selectProject(project: SchedulingProject) {
    setSelectedProjectId(project.id);
    setProjectFormMode("edit");
    setProjectForm({
      clientId: project.clientId.toString(),
      code: project.code,
      name: project.name,
      effectiveFrom: project.effectiveFrom,
      effectiveTo: project.effectiveTo || "",
      status: project.status
    });
    setProjectMessage(null);
  }

  async function saveProject() {
    const clientId = Number(projectForm.clientId);
    const code = projectForm.code.trim();
    const name = projectForm.name.trim();
    if (!clientId || !code || !name || !projectForm.effectiveFrom) {
      setProjectMessage("Cliente, codigo, nombre y vigencia desde son obligatorios.");
      return;
    }
    if (projectForm.effectiveTo && projectForm.effectiveTo < projectForm.effectiveFrom) {
      setProjectMessage("La vigencia final no puede ser anterior a la inicial.");
      return;
    }

    setProjectPending(true);
    setProjectMessage(null);
    try {
      const request = {
        clientId,
        code,
        name,
        status: projectForm.status,
        effectiveFrom: projectForm.effectiveFrom,
        effectiveTo: projectForm.effectiveTo || null
      };
      if (projectFormMode === "create") {
        const created = await createSchedulingProject(request);
        const detail = await fetchSchedulingProjectDetail(created.id);
        setProjectsRefreshKey((value) => value + 1);
        selectProject(detail);
        setProjectMessage("Proyecto creado.");
      } else if (selectedProjectId !== null) {
        const updated = await updateSchedulingProject(selectedProjectId, request);
        setProjects((current) => current.map((item) => item.id === updated.id ? updated : item));
        setProjectMessage("Proyecto actualizado.");
      }
      onProjectsChanged();
    } catch (error) {
      setProjectMessage(error instanceof Error ? error.message : "No fue posible guardar el proyecto.");
    } finally {
      setProjectPending(false);
    }
  }

  async function inactivateProject() {
    if (selectedProjectId === null) return;
    if (!window.confirm("¿Inactivar este proyecto? Dejara de estar disponible para generar nuevas propuestas.")) return;

    setProjectPending(true);
    setProjectMessage(null);
    try {
      const updated = await inactivateSchedulingProject(selectedProjectId);
      setProjectsRefreshKey((value) => value + 1);
      setProjectForm((current) => ({ ...current, status: updated.status }));
      setProjectMessage("Proyecto inactivado.");
      onProjectsChanged();
    } catch (error) {
      setProjectMessage(error instanceof Error ? error.message : "No fue posible inactivar el proyecto.");
    } finally {
      setProjectPending(false);
    }
  }

  function clientName(clientId: number): string {
    return clients.find((client) => client.id === clientId)?.name || `Cliente #${clientId}`;
  }

  return (
    <div className="employees-workspace">
      <div className="employees-toolbar">
        <div>
          <p className="eyebrow">Programacion de turnos</p>
          <h2>Clientes</h2>
        </div>
        <div className="toolbar-filters">
          <button type="button" className="secondary-action" onClick={startCreateClient}>Nuevo cliente</button>
        </div>
      </div>

      {clientsError ? <div className="panel-empty">{clientsError}</div> : null}

      <div className="employees-grid">
        <section className="panel employee-list-panel">
          <div className="panel-header">
            <h3>Listado</h3>
            <span>{clientsLoading ? "Cargando..." : `${clients.length} clientes`}</span>
          </div>
          <div className="employee-table">
            {clients.map((client) => (
              <button
                key={client.id}
                type="button"
                className={client.id === selectedClientId ? "employee-row selected" : "employee-row"}
                onClick={() => selectClient(client)}
              >
                <div>
                  <strong>{client.name}</strong>
                  <p className="muted">{client.code}</p>
                </div>
                <span className={`status-chip ${client.status === "ACTIVO" ? "status-active" : "status-retired"}`}>{client.status}</span>
              </button>
            ))}
            {!clientsLoading && clients.length === 0 ? <div className="panel-empty">Sin clientes registrados todavia.</div> : null}
          </div>
        </section>

        <aside className="panel employee-detail-panel">
          <div className="panel-header">
            <h3>{clientFormMode === "create" ? "Nuevo cliente" : "Editar cliente"}</h3>
          </div>
          <div className="employee-detail">
            <div className="position-form">
              <input value={clientForm.code} onChange={(event) => setClientForm((current) => ({ ...current, code: event.target.value }))} placeholder="Codigo" />
              <input value={clientForm.name} onChange={(event) => setClientForm((current) => ({ ...current, name: event.target.value }))} placeholder="Nombre" />
              <select value={clientForm.status} onChange={(event) => setClientForm((current) => ({ ...current, status: event.target.value as "ACTIVO" | "INACTIVO" }))}>
                <option value="ACTIVO">Activo</option>
                <option value="INACTIVO">Inactivo</option>
              </select>
              <div className="position-form-actions">
                <button type="button" onClick={() => void saveClient()} disabled={clientPending}>
                  {clientPending ? "Guardando..." : clientFormMode === "create" ? "Crear cliente" : "Guardar cambios"}
                </button>
                {clientFormMode === "edit" && clientForm.status === "ACTIVO" ? (
                  <button type="button" className="danger-action" onClick={() => void inactivateClient()} disabled={clientPending}>
                    Inactivar
                  </button>
                ) : null}
              </div>
              {clientMessage ? <p className="muted">{clientMessage}</p> : null}
            </div>
          </div>
        </aside>
      </div>

      <div className="employees-toolbar">
        <div>
          <h2>Proyectos de programacion</h2>
        </div>
        <div className="toolbar-filters">
          <button type="button" className="secondary-action" onClick={startCreateProject} disabled={clients.length === 0}>
            Nuevo proyecto
          </button>
        </div>
      </div>

      {clients.length === 0 && !clientsLoading ? <div className="panel-empty">Registre al menos un cliente antes de crear un proyecto.</div> : null}
      {projectsError ? <div className="panel-empty">{projectsError}</div> : null}

      <div className="employees-grid">
        <section className="panel employee-list-panel">
          <div className="panel-header">
            <h3>Listado</h3>
            <span>{projectsLoading ? "Cargando..." : `${projects.length} proyectos activos`}</span>
          </div>
          <div className="employee-table">
            {projects.map((project) => (
              <button
                key={project.id}
                type="button"
                className={project.id === selectedProjectId ? "employee-row selected" : "employee-row"}
                onClick={() => selectProject(project)}
              >
                <div>
                  <strong>{project.name}</strong>
                  <p className="muted">{project.code} · {clientName(project.clientId)}</p>
                </div>
                <span className={`status-chip ${project.status === "ACTIVO" ? "status-active" : "status-retired"}`}>{project.status}</span>
              </button>
            ))}
            {!projectsLoading && projects.length === 0 ? <div className="panel-empty">Sin proyectos registrados todavia.</div> : null}
          </div>
        </section>

        <aside className="panel employee-detail-panel">
          <div className="panel-header">
            <h3>{projectFormMode === "create" ? "Nuevo proyecto" : "Editar proyecto"}</h3>
          </div>
          <div className="employee-detail">
            <div className="position-form">
              <select value={projectForm.clientId} onChange={(event) => setProjectForm((current) => ({ ...current, clientId: event.target.value }))}>
                <option value="">Seleccione cliente</option>
                {clients.map((client) => (
                  <option key={client.id} value={client.id}>{client.name} ({client.code})</option>
                ))}
              </select>
              <input value={projectForm.code} onChange={(event) => setProjectForm((current) => ({ ...current, code: event.target.value }))} placeholder="Codigo" />
              <input value={projectForm.name} onChange={(event) => setProjectForm((current) => ({ ...current, name: event.target.value }))} placeholder="Nombre" />
              <label className="muted">Vigente desde
                <input type="date" value={projectForm.effectiveFrom} onChange={(event) => setProjectForm((current) => ({ ...current, effectiveFrom: event.target.value }))} />
              </label>
              <label className="muted">Vigente hasta (opcional)
                <input type="date" value={projectForm.effectiveTo} min={projectForm.effectiveFrom || undefined} onChange={(event) => setProjectForm((current) => ({ ...current, effectiveTo: event.target.value }))} />
              </label>
              <select value={projectForm.status} onChange={(event) => setProjectForm((current) => ({ ...current, status: event.target.value as "ACTIVO" | "INACTIVO" }))}>
                <option value="ACTIVO">Activo</option>
                <option value="INACTIVO">Inactivo</option>
              </select>
              <div className="position-form-actions">
                <button type="button" onClick={() => void saveProject()} disabled={projectPending}>
                  {projectPending ? "Guardando..." : projectFormMode === "create" ? "Crear proyecto" : "Guardar cambios"}
                </button>
                {projectFormMode === "edit" && projectForm.status === "ACTIVO" ? (
                  <button type="button" className="danger-action" onClick={() => void inactivateProject()} disabled={projectPending}>
                    Inactivar
                  </button>
                ) : null}
              </div>
              {projectMessage ? <p className="muted">{projectMessage}</p> : null}
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}

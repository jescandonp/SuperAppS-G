import { useParams } from "react-router-dom";
import type { CurrentUser } from "../../types/portal";
import { EmployeesPage } from "../employees/EmployeesPage";
import { ImportsPage } from "../imports/ImportsPage";

interface ModuleWorkspaceProps {
  user: CurrentUser;
}

export function ModuleWorkspace({ user }: ModuleWorkspaceProps) {
  const { moduleCode } = useParams();

  if (moduleCode === "employees") {
    return <EmployeesPage />;
  }

  if (moduleCode === "imports") {
    return <ImportsPage user={user} />;
  }

  return <div className="panel-empty">Modulo pendiente del siguiente incremento.</div>;
}

import { useParams } from "react-router-dom";
import type { CurrentUser } from "../../types/portal";
import { AlertsPage } from "../alerts/AlertsPage";
import { AuditPage } from "../audit/AuditPage";
import { CertificatesPage } from "../certificates/CertificatesPage";
import { CoursesPage } from "../courses/CoursesPage";
import { EmployeesPage } from "../employees/EmployeesPage";
import { ImportsPage } from "../imports/ImportsPage";
import { PositionsPage } from "../positions/PositionsPage";

interface ModuleWorkspaceProps {
  user: CurrentUser;
}

export function ModuleWorkspace({ user }: ModuleWorkspaceProps) {
  const { moduleCode } = useParams();

  if (moduleCode === "employees") {
    return <EmployeesPage user={user} />;
  }

  if (moduleCode === "imports") {
    return <ImportsPage user={user} />;
  }

  if (moduleCode === "positions") {
    return <PositionsPage user={user} />;
  }

  if (moduleCode === "certificates") {
    return <CertificatesPage user={user} />;
  }

  if (moduleCode === "courses") {
    return <CoursesPage user={user} />;
  }

  if (moduleCode === "alerts") {
    return <AlertsPage user={user} />;
  }

  if (moduleCode === "audit") {
    return <AuditPage user={user} />;
  }

  return <div className="panel-empty">Modulo pendiente del siguiente incremento.</div>;
}

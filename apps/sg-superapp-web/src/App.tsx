import { Navigate, Route, Routes } from "react-router-dom";
import { LoginPage } from "./features/auth/LoginPage";
import { ModuleWorkspace } from "./features/shell/ModuleWorkspace";
import { ShellLayout } from "./features/shell/ShellLayout";
import { usePortalShell } from "./hooks/usePortalShell";

export function App() {
  const { user, modules, notifications, source, loading, errorMessage, loginWithCredentials, logout } = usePortalShell();

  if (!user) {
    return (
      <LoginPage
        loading={loading}
        errorMessage={errorMessage}
        onSubmit={(username, password) => loginWithCredentials({ username, password })}
      />
    );
  }

  return (
    <Routes>
      <Route path="/" element={<ShellLayout user={user} modules={modules} notifications={notifications} source={source} onLogout={logout} />}>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<div className="panel-empty">Resumen del piloto y widgets base por rol.</div>} />
        <Route path="module/:moduleCode" element={<ModuleWorkspace user={user} />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

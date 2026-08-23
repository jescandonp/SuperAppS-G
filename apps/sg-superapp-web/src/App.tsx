import { Navigate, Route, Routes } from "react-router-dom";
import { LoginPage } from "./features/auth/LoginPage";
import { DashboardPage } from "./features/dashboard/DashboardPage";
import { ModuleWorkspace } from "./features/shell/ModuleWorkspace";
import { ShellLayout } from "./features/shell/ShellLayout";
import { usePortalShell } from "./hooks/usePortalShell";

export function App() {
  const { user, modules, notifications, notificationFilters, unreadNotificationCount, source, loading, errorMessage, setNotificationFilters, refreshNotifications, markNotificationRead, archiveNotificationItem, loginWithCredentials, logout } = usePortalShell();

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
      <Route
        path="/"
        element={(
          <ShellLayout
            user={user}
            modules={modules}
            notifications={notifications}
            notificationFilters={notificationFilters}
            unreadNotificationCount={unreadNotificationCount}
            source={source}
            onNotificationFiltersChange={setNotificationFilters}
            onRefreshNotifications={refreshNotifications}
            onMarkNotificationRead={markNotificationRead}
            onArchiveNotification={archiveNotificationItem}
            onLogout={logout}
          />
        )}
      >
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage currentUser={user} />} />
        <Route path="module/:moduleCode" element={<ModuleWorkspace user={user} />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

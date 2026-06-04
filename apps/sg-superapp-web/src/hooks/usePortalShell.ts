import { useCallback, useEffect, useMemo, useState } from "react";
import { fetchCurrentUser, fetchModules, fetchNotifications, login } from "../services/portalApi";
import { mockCurrentUser, mockNotifications, modulesByRole } from "../mock/session";
import type { AppModule, CurrentUser, LoginRequest, NotificationItem } from "../types/portal";

const SESSION_USER_KEY = "sg.superapp.currentUser";
const SESSION_TOKEN_KEY = "sg.superapp.sessionToken";

interface PortalShellState {
  user: CurrentUser | null;
  modules: AppModule[];
  notifications: NotificationItem[];
  source: "api" | "mock";
  loading: boolean;
  errorMessage: string | null;
  loginWithCredentials: (request: LoginRequest) => Promise<void>;
  logout: () => void;
}

function readStoredUser(): CurrentUser | null {
  const raw = sessionStorage.getItem(SESSION_USER_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as CurrentUser;
  } catch {
    sessionStorage.removeItem(SESSION_USER_KEY);
    sessionStorage.removeItem(SESSION_TOKEN_KEY);
    return null;
  }
}

export function usePortalShell(): PortalShellState {
  const [user, setUser] = useState<CurrentUser | null>(() => readStoredUser());
  const [modules, setModules] = useState<AppModule[]>([]);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [source, setSource] = useState<"api" | "mock">("mock");
  const [loading, setLoading] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const logout = useCallback(() => {
    sessionStorage.removeItem(SESSION_USER_KEY);
    setUser(null);
    setModules([]);
    setNotifications([]);
    setSource("mock");
    setErrorMessage(null);
  }, []);

  const loadShellData = useCallback(async (currentUser: CurrentUser) => {
    setLoading(true);
    try {
      const [apiUser, apiModules, apiNotifications] = await Promise.all([
        fetchCurrentUser(),
        fetchModules(currentUser.role),
        fetchNotifications(currentUser.username)
      ]);

      sessionStorage.setItem(SESSION_USER_KEY, JSON.stringify(apiUser));
      setUser(apiUser);
      setModules(apiModules);
      setNotifications(apiNotifications);
      setSource("api");
      setErrorMessage(null);
    } catch {
      setModules(modulesByRole[currentUser.role]);
      setNotifications(mockNotifications);
      setSource("mock");
      setErrorMessage("No fue posible cargar la API. Se muestra fallback local.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!user) {
      return;
    }

    void loadShellData(user);
  }, [user, loadShellData]);

  const loginWithCredentials = useCallback(async (request: LoginRequest) => {
    setLoading(true);
    setErrorMessage(null);

    try {
      const response = await login(request);
      if (!response.user) {
        throw new Error("No se recibio el perfil del usuario.");
      }

      sessionStorage.setItem(SESSION_USER_KEY, JSON.stringify(response.user));
      if (response.sessionToken) {
        sessionStorage.setItem(SESSION_TOKEN_KEY, response.sessionToken);
      }
      setUser(response.user);
    } catch (error) {
      const message = error instanceof Error ? error.message : "No fue posible iniciar sesion.";
      setErrorMessage(message);
      throw error;
    } finally {
      setLoading(false);
    }
  }, []);

  return useMemo(
    () => ({
      user,
      modules,
      notifications,
      source,
      loading,
      errorMessage,
      loginWithCredentials,
      logout
    }),
    [user, modules, notifications, source, loading, errorMessage, loginWithCredentials, logout]
  );
}

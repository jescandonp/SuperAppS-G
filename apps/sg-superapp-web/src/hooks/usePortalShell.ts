import { useCallback, useEffect, useMemo, useState } from "react";
import { archiveNotification, fetchCurrentUser, fetchModules, fetchNotificationUnreadCount, fetchNotificationsInbox, login, markNotificationAsRead } from "../services/portalApi";
import { mockCurrentUser, mockNotifications, modulesByRole } from "../mock/session";
import type { AppModule, CurrentUser, LoginRequest, NotificationFilters, NotificationItem } from "../types/portal";

const SESSION_USER_KEY = "sg.superapp.currentUser";
const SESSION_TOKEN_KEY = "sg.superapp.sessionToken";

interface PortalShellState {
  user: CurrentUser | null;
  modules: AppModule[];
  notifications: NotificationItem[];
  notificationFilters: NotificationFilters;
  unreadNotificationCount: number;
  source: "api" | "mock";
  loading: boolean;
  errorMessage: string | null;
  setNotificationFilters: (filters: NotificationFilters) => void;
  refreshNotifications: () => Promise<void>;
  markNotificationRead: (notificationId: number) => Promise<void>;
  archiveNotificationItem: (notificationId: number) => Promise<void>;
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
  const [notificationFilters, setNotificationFiltersState] = useState<NotificationFilters>({});
  const [unreadNotificationCount, setUnreadNotificationCount] = useState<number>(0);
  const [source, setSource] = useState<"api" | "mock">("mock");
  const [loading, setLoading] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const logout = useCallback(() => {
    sessionStorage.removeItem(SESSION_USER_KEY);
    setUser(null);
    setModules([]);
    setNotifications([]);
    setUnreadNotificationCount(0);
    setNotificationFiltersState({});
    setSource("mock");
    setErrorMessage(null);
  }, []);

  const loadNotifications = useCallback(async (currentUser: CurrentUser, filters: NotificationFilters) => {
    const [apiNotifications, unreadCount] = await Promise.all([
      fetchNotificationsInbox(filters),
      fetchNotificationUnreadCount()
    ]);
    setNotifications(apiNotifications);
    setUnreadNotificationCount(unreadCount.unreadCount);
    setSource("api");
    setErrorMessage(null);
  }, []);

  const loadShellData = useCallback(async (currentUser: CurrentUser) => {
    setLoading(true);
    try {
      const [apiUser, apiModules] = await Promise.all([
        fetchCurrentUser(),
        fetchModules(currentUser.role)
      ]);

      sessionStorage.setItem(SESSION_USER_KEY, JSON.stringify(apiUser));
      setUser(apiUser);
      setModules(apiModules);
      await loadNotifications(apiUser, notificationFilters);
    } catch {
      setModules(modulesByRole[currentUser.role]);
      setNotifications(mockNotifications);
      setUnreadNotificationCount(mockNotifications.filter((item) => item.status === "UNREAD").length);
      setSource("mock");
      setErrorMessage("No fue posible cargar la API. Se muestra fallback local.");
    } finally {
      setLoading(false);
    }
  }, [loadNotifications, notificationFilters]);

  useEffect(() => {
    if (!user) {
      return;
    }

    void loadShellData(user);
  }, [user, loadShellData]);

  const setNotificationFilters = useCallback((filters: NotificationFilters) => {
    setNotificationFiltersState(filters);
  }, []);

  const refreshNotifications = useCallback(async () => {
    if (!user) {
      return;
    }

    try {
      await loadNotifications(user, notificationFilters);
    } catch {
      setErrorMessage("No fue posible actualizar la bandeja de notificaciones.");
    }
  }, [loadNotifications, notificationFilters, user]);

  const markNotificationRead = useCallback(async (notificationId: number) => {
    await markNotificationAsRead(notificationId);
    await refreshNotifications();
  }, [refreshNotifications]);

  const archiveNotificationItem = useCallback(async (notificationId: number) => {
    await archiveNotification(notificationId);
    await refreshNotifications();
  }, [refreshNotifications]);

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
      notificationFilters,
      unreadNotificationCount,
      source,
      loading,
      errorMessage,
      setNotificationFilters,
      refreshNotifications,
      markNotificationRead,
      archiveNotificationItem,
      loginWithCredentials,
      logout
    }),
    [user, modules, notifications, notificationFilters, unreadNotificationCount, source, loading, errorMessage, setNotificationFilters, refreshNotifications, markNotificationRead, archiveNotificationItem, loginWithCredentials, logout]
  );
}

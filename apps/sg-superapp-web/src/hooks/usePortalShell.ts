import { useCallback, useEffect, useMemo, useState } from "react";
import {
  PortalApiError,
  evaluateSchedulingRules,
  fetchActiveSchedulingRuleProfile,
  fetchCurrentUser,
  fetchModules,
  fetchNotifications,
  fetchSchedulingRuleEvaluations,
  login
} from "../services/portalApi";
import { mockCurrentUser, mockNotifications, modulesByRole } from "../mock/session";
import type { AppModule, CurrentUser, LoginRequest, NotificationItem } from "../types/portal";
import type {
  PreEvaluateSchedulingRulesRequest,
  SchedulingRuleEvaluationState,
  SchedulingRuleProblem,
  SchedulingRuleProfileState
} from "../types/portal";

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
  // The versioned rule state is exposed as it came from the server. Nothing here is derived: the
  // shell does not decide whether a schedule may be approved, nor infer a permission from a role.
  ruleProfile: SchedulingRuleProfileState;
  ruleEvaluation: SchedulingRuleEvaluationState;
  loadRuleProfile: (projectCode: string, period: string, environmentScope: string) => Promise<void>;
  loadRuleEvaluations: (scheduleVersionId: number) => Promise<void>;
  revalidateRules: (
    scheduleVersionId: number,
    assignmentId: number | null,
    request: PreEvaluateSchedulingRulesRequest
  ) => Promise<void>;
}

// An unexpected failure is still a stated failure: it is carried in the same shape so a caller
// never has to tell a typed problem from a loose exception.
function toProblem(error: unknown): SchedulingRuleProblem {
  if (error instanceof PortalApiError) {
    return error.problem;
  }

  return {
    status: 0,
    code: null,
    title: null,
    message: error instanceof Error ? error.message : "No fue posible consultar las reglas versionadas."
  };
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
  const [ruleProfile, setRuleProfile] = useState<SchedulingRuleProfileState>({ status: "IDLE" });
  const [ruleEvaluation, setRuleEvaluation] = useState<SchedulingRuleEvaluationState>({ status: "IDLE" });

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

  const loadRuleProfile = useCallback(
    async (projectCode: string, period: string, environmentScope: string) => {
      setRuleProfile({ status: "LOADING" });
      try {
        const profile = await fetchActiveSchedulingRuleProfile(projectCode, period, environmentScope);
        // No active profile is not an empty rule set. Saying so plainly keeps the panel from
        // rendering a clean schedule for a scope nobody has configured.
        setRuleProfile(
          profile
            ? { status: "READY", profile }
            : {
                status: "UNCONFIGURED",
                message: "No hay un perfil de reglas vigente para este proyecto y periodo."
              }
        );
      } catch (error) {
        setRuleProfile({ status: "FAILED", problem: toProblem(error) });
      }
    },
    []
  );

  const loadRuleEvaluations = useCallback(async (scheduleVersionId: number) => {
    setRuleEvaluation({ status: "LOADING" });
    try {
      setRuleEvaluation({ status: "READY", batch: await fetchSchedulingRuleEvaluations(scheduleVersionId) });
    } catch (error) {
      setRuleEvaluation({ status: "FAILED", problem: toProblem(error) });
    }
  }, []);

  // After an edit the previous verdicts no longer describe the schedule, so the panel must be put
  // back into LOADING rather than keep showing what was true before the change.
  const revalidateRules = useCallback(
    async (
      scheduleVersionId: number,
      assignmentId: number | null,
      request: PreEvaluateSchedulingRulesRequest
    ) => {
      setRuleEvaluation({ status: "LOADING" });
      try {
        const batch = await evaluateSchedulingRules(scheduleVersionId, assignmentId, request);
        setRuleEvaluation({ status: "READY", batch });
      } catch (error) {
        setRuleEvaluation({ status: "FAILED", problem: toProblem(error) });
      }
    },
    []
  );

  return useMemo(
    () => ({
      user,
      modules,
      notifications,
      source,
      loading,
      errorMessage,
      loginWithCredentials,
      logout,
      ruleProfile,
      ruleEvaluation,
      loadRuleProfile,
      loadRuleEvaluations,
      revalidateRules
    }),
    [
      user,
      modules,
      notifications,
      source,
      loading,
      errorMessage,
      loginWithCredentials,
      logout,
      ruleProfile,
      ruleEvaluation,
      loadRuleProfile,
      loadRuleEvaluations,
      revalidateRules
    ]
  );
}

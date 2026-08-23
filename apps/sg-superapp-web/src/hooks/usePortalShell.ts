import { useCallback, useEffect, useMemo, useState } from "react";
import {
  PortalApiError,
  evaluateSchedulingRules,
  fetchSchedulingRuleProfiles,
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
  SchedulingEnvironmentScope,
  SchedulingRuleEvaluationState,
  SchedulingRuleProblem,
  SchedulingRuleProfileState,
  SchedulingRuleRevalidationState
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
  ruleRevalidation: SchedulingRuleRevalidationState;
  loadRuleProfile: (projectCode: string, period: string, environmentScope: SchedulingEnvironmentScope) => Promise<void>;
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
  const [ruleRevalidation, setRuleRevalidation] = useState<SchedulingRuleRevalidationState>({ status: "IDLE" });

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
    async (projectCode: string, period: string, environmentScope: SchedulingEnvironmentScope) => {
      setRuleProfile({ status: "LOADING" });
      try {
        // The route returns every profile it has for the scope, in any status. An empty result, or
        // one with nothing ACTIVE, means nobody configured this scope - which is not the same as a
        // schedule with no rules to worry about, and must not render as one.
        const active = (await fetchSchedulingRuleProfiles(projectCode, period, environmentScope))
          .filter(profile => profile.status === "ACTIVE");

        if (active.length === 1) {
          setRuleProfile({ status: "READY", profile: active[0] });
        } else if (active.length === 0) {
          setRuleProfile({
            status: "UNCONFIGURED",
            message: "No hay un perfil de reglas vigente para este proyecto y periodo."
          });
        } else {
          // The database permits one active profile per scope. More than one means the guarantee
          // the decisions rest on is broken, so nothing here can be trusted to describe them.
          setRuleProfile({
            status: "FAILED",
            problem: {
              status: 0,
              code: null,
              title: null,
              message: "Hay mas de un perfil de reglas vigente para el mismo alcance."
            }
          });
        }
      } catch (error) {
        setRuleProfile({ status: "FAILED", problem: toProblem(error) });
      }
    },
    []
  );

  const loadRuleEvaluations = useCallback(async (scheduleVersionId: number) => {
    setRuleEvaluation({ status: "LOADING" });
    try {
      setRuleEvaluation({ status: "READY", evaluations: await fetchSchedulingRuleEvaluations(scheduleVersionId) });
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
      // The verdicts on screen described the schedule before the edit, so they are put back into
      // LOADING rather than left standing while the re-evaluation runs.
      setRuleEvaluation({ status: "LOADING" });
      setRuleRevalidation({ status: "LOADING" });
      try {
        const batch = await evaluateSchedulingRules(scheduleVersionId, assignmentId, request);
        setRuleRevalidation({ status: "READY", batch });
        setRuleEvaluation({ status: "READY", evaluations: await fetchSchedulingRuleEvaluations(scheduleVersionId) });
      } catch (error) {
        const problem = toProblem(error);
        setRuleRevalidation({ status: "FAILED", problem });
        setRuleEvaluation({ status: "FAILED", problem });
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
      ruleRevalidation,
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
      ruleRevalidation,
      loadRuleProfile,
      loadRuleEvaluations,
      revalidateRules
    ]
  );
}

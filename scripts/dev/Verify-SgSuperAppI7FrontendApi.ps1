param(
    [string]$WebRoot = "apps/sg-superapp-web"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$webPath = Join-Path $repoRoot $WebRoot
$fixturePath = Join-Path $webPath "src\__i7_task4_api_contract.red.ts"

$fixture = @'
import type {
  AuditEvent,
  AuditEventsResponse,
  AuditFilters,
  AuditModule,
  DashboardResponse,
  DashboardWidget,
  DashboardWidgetScope,
  DashboardWidgetSeverity
} from "./types/portal";
import {
  fetchAuditEvents,
  fetchDashboard
} from "./services/portalApi";
import {
  mockAuditEvents,
  mockDashboard
} from "./mock/session";

const widget: DashboardWidget = {
  id: "training-risk",
  title: "Cursos por vencer",
  scope: "TH" satisfies DashboardWidgetScope,
  metric: "12",
  trend: "Criticos y preventivos",
  severity: "WARNING" satisfies DashboardWidgetSeverity,
  actionUrl: "/portal/courses"
};

const filters: AuditFilters = {
  module: "CERTIFICATES" satisfies AuditModule,
  actor: "talento.humano",
  from: "2026-06-01T00:00:00Z",
  to: "2026-06-30T23:59:59Z"
};

const auditEvent: AuditEvent = {
  id: 15,
  occurredAt: "2026-06-12T00:00:00Z",
  actorUsername: "talento.humano",
  actorRole: "TH",
  module: "CERTIFICATES",
  action: "LABOR_CERTIFICATE_GENERATED",
  entityType: "labor_certificate",
  entityId: "15",
  summary: "Certificado laboral generado",
  detail: {
    purpose: "TRAMITE_GENERAL"
  }
};

async function assertContract(): Promise<void> {
  const dashboard: DashboardResponse = await fetchDashboard();
  const audit: AuditEventsResponse = await fetchAuditEvents(filters);
  const defaultAudit: AuditEventsResponse = await fetchAuditEvents();

  console.log(
    dashboard.role,
    dashboard.generatedAt,
    dashboard.widgets.concat(widget).length,
    audit.events.concat(auditEvent).length,
    defaultAudit.events.length,
    mockDashboard.widgets.length,
    mockAuditEvents.length
  );
}

void assertContract();
'@

try {
    Set-Content -LiteralPath $fixturePath -Value $fixture -Encoding UTF8
    Push-Location $webPath
    & node .\node_modules\typescript\bin\tsc -p tsconfig.app.json --noEmit
    if ($LASTEXITCODE -ne 0) {
        throw "TypeScript contract verification failed."
    }

    Write-Host "I7 frontend API contract verification completed."
}
finally {
    Pop-Location
    if (Test-Path -LiteralPath $fixturePath) {
        Remove-Item -LiteralPath $fixturePath -Force
    }
}

param(
    [string]$WebRoot = "apps/sg-superapp-web"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$webPath = Join-Path $repoRoot $WebRoot
$fixturePath = Join-Path $webPath "src\__i6_task7_api_contract.red.ts"

$fixture = @'
import type {
  NotificationEmailSummaryRequest,
  NotificationEmailSummaryResponse,
  NotificationFilters,
  NotificationGenerationResponse,
  NotificationItem,
  NotificationSeverity,
  NotificationStatus,
  NotificationUnreadCountResponse
} from "./types/portal";
import {
  archiveNotification,
  exportNotificationSummary,
  fetchNotificationUnreadCount,
  fetchNotificationsInbox,
  generateCertificateAlerts,
  generateImportAlerts,
  generateTrainingAlerts,
  markNotificationAsRead,
  sendNotificationEmailSummary
} from "./services/portalApi";

const filters: NotificationFilters = {
  status: "UNREAD" satisfies NotificationStatus,
  severity: "CRITICAL" satisfies NotificationSeverity,
  sourceModule: "TRAINING"
};

const notification: NotificationItem = {
  id: 1,
  targetType: "ROLE",
  targetKey: "TH",
  title: "Alerta",
  body: "Detalle",
  status: "UNREAD",
  sourceModule: "TRAINING",
  severity: "CRITICAL",
  sourceType: "TRAINING_EXPIRY",
  sourceId: "1",
  actionUrl: "/portal/courses",
  createdAt: "2026-06-11T00:00:00Z",
  readAt: null,
  archivedAt: null,
  managedAt: null,
  managedBy: null
};

const emailRequest: NotificationEmailSummaryRequest = {
  status: filters.status,
  severity: filters.severity,
  sourceModule: filters.sourceModule,
  recipient: "talento.humano@example.invalid"
};

async function assertContract(): Promise<void> {
  const inbox: NotificationItem[] = await fetchNotificationsInbox(filters);
  const count: NotificationUnreadCountResponse = await fetchNotificationUnreadCount();
  const read: NotificationItem = await markNotificationAsRead(notification.id);
  const archived: NotificationItem = await archiveNotification(notification.id);
  const training: NotificationGenerationResponse = await generateTrainingAlerts();
  const imports: NotificationGenerationResponse = await generateImportAlerts();
  const certificates: NotificationGenerationResponse = await generateCertificateAlerts();
  const email: NotificationEmailSummaryResponse = await sendNotificationEmailSummary(emailRequest);

  await exportNotificationSummary(filters);
  console.log(inbox.length, count.unreadCount, read.status, archived.status, training.generatedCount, imports.activeAlertsCount, certificates.skippedCurrentCount, email.fallbackAvailable);
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

    Write-Host "I6 frontend API contract verification completed."
}
finally {
    Pop-Location
    if (Test-Path -LiteralPath $fixturePath) {
        Remove-Item -LiteralPath $fixturePath -Force
    }
}

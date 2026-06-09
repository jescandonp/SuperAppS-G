Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$coursesPage = Join-Path $repoRoot "apps\sg-superapp-web\src\features\courses\CoursesPage.tsx"

if (-not (Test-Path $coursesPage)) {
  throw "CoursesPage.tsx was not found."
}

$source = Get-Content -Raw $coursesPage

$requiredPatterns = @(
  "createTrainingRequirementType",
  "updateTrainingRequirementType",
  "inactivateTrainingRequirementType",
  "createTrainingRecord",
  "inactivateTrainingRecord",
  "Gestion de tipos",
  "Registrar renovacion",
  "Inactivar renovacion",
  "Rol de consulta sin acciones de edicion."
)

foreach ($pattern in $requiredPatterns) {
  if ($source -notlike "*$pattern*") {
    throw "Missing I5 Task 9 UI marker: $pattern"
  }
}

Write-Host "OK - I5 Task 9 management UI markers are present."

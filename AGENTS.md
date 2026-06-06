## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)


<claude-mem-context>
# Memory Context

# [ProyectoS&G] recent context, 2026-06-05 5:59pm GMT-5

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (21.047t read) | 480.682t work | 96% savings

### Jun 5, 2026
1036 9:33a ✅ Task 7 Cerrada Formalmente en README y Plan I3
1037 3:49p 🔵 PortalEndpoints.cs — Full API Surface Mapped
1038 " 🔵 PostgresPortalRepository — Full Data Access Layer Mapped
1039 " 🔵 Portal Contracts Directory — 19 DTOs Covering Full Domain
1040 " 🔵 I3 Positions Verification Script — Role-Based Authorization Test Suite
1041 3:50p 🟣 Certificate Signers CRUD Implemented — Increment I4
1042 " 🟣 Certificate Signers REST Endpoints Wired into PortalEndpoints.cs
1043 " 🔴 Missing CertificateSigner Helper Methods Added to PostgresPortalRepository
1044 3:51p 🟣 I4 Verification Scripts Added — Signers CRUD and Security
1045 " 🟣 I4 Certificate Signers Backend Compiles Clean
1046 3:54p 🔵 GERENCIA Role Missing CERTIFICATE_SIGNERS/VIEW Permission in DB
1047 3:55p 🔴 GERENCIA CERTIFICATE_SIGNERS/VIEW Permission Added to Seed and Contract Test
1048 " 🔴 Seed 006 Re-Applied and I4 Persistence Contract Passed
1049 " 🔵 I4 Clean Schema Verification Reveals Full Database Structure Including Labor Certificates Tables
1050 3:56p 🟣 I4 Certificate Signers Backend Fully Verified — All Tests Pass
1051 " ✅ I4 Task 2 Closed — Project Docs Advanced to Task 3 Retake Point
1052 3:57p 🔵 LF/CRLF Line Ending Warnings Across Multiple Files on Windows
1053 " 🔵 Git Working Tree Has 18 Modified + 55 Untracked Files Across I2/I3/I4 — None Committed
1054 3:58p 🔵 GetEmployeeByIdAsync and Salary Versioning Available for Task 3 Certificate Preview
1055 3:59p 🔵 Task 3 Acceptance Criteria and EmployeeDetailResponse Fields Confirmed
1056 " 🟣 Certificate Preview Contracts and Endpoint Added — I4 Task 3
1057 " 🟣 BuildActiveCertificatePreviewAsync Implemented in PostgresPortalRepository
1058 4:00p 🔴 BuildCertificatePreviewError Helper Added to Complete Preview Implementation
1059 4:01p 🟣 I4 Task 3 TDD Verification Scripts Created — ActivePreview and SalaryVariables
1060 " 🟣 I4 Task 3 Certificate Preview Backend Compiles Clean
1061 4:02p 🔵 employees Table Has ck_employees_dates Constraint — RETIRADO INSERT Requires termination_date
1062 4:33p 🔵 Graphify Knowledge Graph Analysis of ProyectoS&G Corpus
1063 " 🔵 Labor Certificates API — Endpoints, Repository Methods, and DB Schema
1064 " 🔵 I4 Labor Certificates Implementation Plan — Tasks 6, 7, 8 Pending
1065 " 🟣 Labor Certificate Annulment and History Endpoints Implemented (Task 6)
1066 4:34p 🟣 ReadLaborCertificate Helper Extracts DB-to-Response Mapping in PostgresPortalRepository
1067 " 🟣 sg-superapp-api Builds Successfully After Task 6 Annulment Implementation
1068 4:35p 🟣 Verification Scripts for I4 Annulment and Audit Added
1069 " 🔵 Repository Has Mixed Line Endings (LF files on Windows CRLF environment)
1070 4:36p 🟣 Task 6 Fully Verified — Annulment, Audit, and Security Scripts All Pass
1071 " ✅ Task 6 Closed in Docs — Project Advances to Task 7 (TypeScript API Client)
1072 4:37p 🔵 Large Volume of Uncommitted I2/I3/I4 Work Visible in git status
1073 4:39p 🔵 Frontend TypeScript Types and API Client Lack All I4 Certificate Types — Task 7 Starting Point
1074 4:40p 🟣 Task 7 — TypeScript Types and API Client for I4 Labor Certificates Added
1075 " 🟣 Task 7 Verified — npm run build Passes with 0 TypeScript Errors
1076 4:41p ✅ Task 7 Closed in Docs — Project Advances to Task 8 (UI de Certificaciones)
1077 4:44p 🔵 Graphify Knowledge Graph Report for ProyectoS&G
1078 4:45p 🔵 sg-superapp-web Feature Module Structure
1079 " 🔵 PositionsPage: Full CRUD UI for Service Positions
1080 " 🔵 ShellLayout: App Shell with Dynamic Module Nav and Notification Counter
1081 " 🔵 PortalEndpoints.cs: Full API Surface of sg-superapp-api
1082 " 🔵 PostgresPortalRepository: Certificate Persistence and PDF Storage
1083 " 🔵 sg-superapp-web CSS Design System: Dark Theme with Gold Accent
1084 4:46p 🟣 Added Certificate List and Detail Query Endpoints
1085 4:47p 🟣 CertificatesPage: Full Certificates Module Added to sg-superapp-web (Increment I4)

Access 481k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>
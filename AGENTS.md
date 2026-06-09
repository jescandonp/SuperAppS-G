## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)


<claude-mem-context>
# Memory Context

# [ProyectoS&G] recent context, 2026-06-09 7:06am GMT-5

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (20.047t read) | 503.161t work | 96% savings

### Jun 5, 2026
1069 4:35p 🔵 Repository Has Mixed Line Endings (LF files on Windows CRLF environment)
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
### Jun 6, 2026
1086 9:38a 🔵 TDD Skill Configuration Available in ProyectoS&G
1087 " 🔵 S&G Super App Knowledge Graph: 9 Communities, 183 Nodes
1088 " 🔵 I5 Task 2 Closed — Task 3 (Renewals &amp; Date Rules) Now Active
1089 9:39a 🟣 TDD RED Scripts Created for I5 Task 3: Renewals and Audit Verification
1090 " 🔴 RED Phase Script Bug: Invoke-Postgres Returns Object[] Not Scalar
1091 " 🔴 Fixed Invoke-Postgres Scalar Parsing in Both I5 Verification Scripts
1092 9:40a 🔴 Second Invoke-Postgres Fix Needed: "INSERT 0 1" Tag Returned Instead of ID
1093 " 🔴 Final Invoke-Postgres Fix: Numeric-First Line Selection for psql Output
1094 " 🔵 TRUE RED Confirmed: POST /api/portal/employees/{id}/training Returns HTTP 404
1095 9:41a 🟣 GREEN Phase: Employee Training Renewal Endpoints Implemented
1096 9:42a 🟣 I5 Task 3 GREEN: dotnet Build Passes Clean After Training Renewal Implementation
1097 " 🟣 I5 Task 3 GREEN Verified: All Renewals and Audit Scenarios Pass
1098 9:43a ✅ I5 Task 3 Formally Closed in Plan, README, and Handoff Documents
1099 9:44a 🔵 graphify Not in PATH on This Machine — Knowledge Graph Cannot Auto-Update
1100 " 🔵 I5 Task 3 Changes Are Uncommitted — All Files in Working Tree Only
1101 9:46a 🔵 I5 Task 4 Expiry State Thresholds Confirmed from SPEC
1102 " 🟣 TDD RED Script Created for I5 Task 4: Expiry Status Threshold Verification
1103 " 🔵 TRUE RED Confirmed for Task 4: complianceStatus Field Missing from TrainingRecordResponse
1104 9:47a 🔵 ReadTrainingRecord at Line 2659 and Domain Folder Are the Implementation Targets for Task 4
1105 " 🟣 Task 4 GREEN: TrainingComplianceStatusCalculator Implemented with Centralized Threshold Logic
1106 " 🟣 Task 4 Build Passes: 0 Warnings, 0 Errors After Compliance Status Fields Added
1107 " 🟣 I5 Task 4 GREEN: All 8 Expiry State Boundary Cases Pass Verification
1108 9:48a ✅ I5 Task 4 Formally Closed — Gate Advanced to Task 5 (Service Enablement)
1109 10:26a 🔵 I5 Task 7 Closed, Task 8 (Compliance UI) Authorized
1110 " 🔵 ProyectoS&G Knowledge Graph: 9 Communities, 183 Nodes
1111 " 🔵 S&G Super App Module Routing Pattern: ModuleWorkspace Switch
1112 " 🔵 Feature Page Pattern: List+Detail Panel with Role-Based Access
1113 " 🟣 TDD Red File Created: i5-courses-ui.red.ts
1114 10:27a 🔵 TDD RED Confirmed: CoursesPage Build Fails as Expected
1115 " 🔵 Training API Functions Confirmed in portalApi.ts (Lines 233–298)
1116 " 🔵 "courses" Module Already Registered in Mock Data; No Sidebar Change Needed
1117 10:28a 🟣 CoursesPage (I5 Task 8) Implemented and Wired into ModuleWorkspace
1118 10:29a 🔵 Build: TypeScript Passed (GREEN), Vite Bundling Fails in Sandbox (Known Issue)

Access 503k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>
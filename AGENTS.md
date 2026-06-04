## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)


<claude-mem-context>
# Memory Context

# [ProyectoS&G] recent context, 2026-06-03 9:18pm GMT-5

Legend: 🎯session 🔴bugfix 🟣feature 🔄refactor ✅change 🔵discovery ⚖️decision 🚨security_alert 🔐security_note
Format: ID TIME TYPE TITLE
Fetch details: get_observations([IDs]) | Search: mem-search skill

Stats: 50 obs (16.839t read) | 326.696t work | 95% savings

### Jun 3, 2026
842 6:02p 🔵 S&G Superapp i0 Local Stack — Session Handoff Initiated
843 " 🔵 Git Init Race Condition — Parallel Commands Failed After git init
844 " 🔵 S&G Superapp Project Root Structure Confirmed
845 6:03p 🔵 Git .git Directory Permission Denied on Windows — Blocking Branch and Remote Setup
846 6:04p 🔵 Root Cause Found — Git Dubious Ownership: .git Created by CodexSandboxOffline User
847 " 🔴 Git Dubious Ownership Fixed — safe.directory Added for S&G Project
848 " 🔵 Three Codex-Sandboxed Projects Share Same safe.directory Pattern on jmep2 Machine
849 " 🔴 Git Branch Renamed to Main — S&G Superapp Repo Now on Correct Default Branch
850 " 🟣 S&G Superapp Git Repo Fully Initialized — Remote Origin Registered
851 6:05p 🔵 Git State Verified — All Project Files Untracked, No .gitignore, Ignore Config Permission Warning
852 6:07p 🔵 S&G Superapp I1 Portal Base Plan Loaded — 7-Task Implementation Roadmap
853 " 🔵 Dev Environment Audit — Node OK, npm Broken, dotnet Unavailable, PostgreSQL 18.4 OK
854 " 🔵 .NET SDK Not Installed — Critical I1 Backend Blocker Confirmed
855 " 🔵 S&G Design System — Dark/Gold Theme, Dense Admin UI Principles
856 6:08p 🟣 I1 Task 1 Complete — Project Scaffolding Created, .gitignore Added, Conventions Registered
857 6:14p ⚖️ Plan I1 priorizado sin dependencia de dotnet
858 6:15p 🟣 Capa SQL versionada I1 creada para PostgreSQL
859 6:16p 🔵 PostgreSQL 18 disponible en localhost:5432
860 " 🟣 Archivos SQL I1 confirmados en disco por apply_patch
861 " 🔵 graphify no instalado en el entorno local
862 " 🔵 Repositorio ProyectoS&G sin commits — todos los archivos untracked
863 6:18p 🟣 Frontend shell sg-superapp-web creado con Vite + React + TypeScript
864 " 🟣 Frontend sg-superapp-web confirmado en disco — 11 archivos nuevos
865 6:20p 🔵 npm install timeout en sg-superapp-web — red o registry inaccesible
866 6:23p ✅ S&G Superapp i0 Local Stack — Handoff Checkpoint Established
867 " 🔵 sg-superapp-web Vite Build Fails — TypeScript tsc Path Resolution Error on Windows
868 " 🔴 sg-superapp-web package.json Scripts Fixed for Windows PATH Resolution
869 6:24p 🟣 sg-superapp-web React Shell Builds Successfully to dist/
870 " 🔵 Start-Process ArgumentList Splits Path on Space — dev Server Launch Fails
871 6:25p 🔵 Vite Dev Server Fails — esbuild Access Denied Traversing to Root When Loading vite.config.ts
872 " ✅ I1 Plan Doc Updated — Task 4 Frontend Shell Marked Complete with Known Dev Server Limitation
873 " ✅ S&G Superapp I1 Session Plan — SQL Layer, Shared Config, and Frontend Build All Closed
874 6:26p 🔵 sg-superapp-web Dependency Manifest — Final Confirmed State
875 " 🔵 sg-superapp-web Source Tree — Feature-Based Structure with Auth, Shell, and Mock Session
876 " 🔵 db/ Layer Structure and Local PostgreSQL 18 Workflow Documented
877 " 🔵 ProyectoS&G Git Repo Has No Initial Commit — All Files Untracked
878 " ✅ S&G Superapp I1 Local Stack Session — All Four Steps Completed
879 6:35p 🔵 PostgreSQL Bootstrap Script Execution Timeout
880 " 🔵 Systemic PowerShell Command Timeouts in ProyectoS&G
881 6:36p 🔵 apps/sg-superapp-api Directory Is Uninitialized
882 " 🔵 I1 Portal Base Spec: Full Scope and Requirements Read
883 " 🟣 sg-superapp-api .NET Backend Scaffold Created for I1
884 6:37p 🟣 Backend Scaffold Patch Applied Successfully — 20 Files Confirmed Written
885 " ✅ Backend Downgraded to .NET 6 and Switch Expression Replaced for Compatibility
886 6:38p 🟣 Frontend API Integration Layer Added with Mock Fallback Pattern
887 6:43p 🔵 .NET SDK Not Found on Development Machine
888 " 🔵 .NET Not Installed at Default Windows Path
889 " 🔵 Recursive Program Files Directory Searches Timing Out
890 6:44p 🟣 Added PowerShell Dev Wrapper Scripts for DB Init and Frontend Launch
891 6:45p 🔵 Junction Creation at C:\tmp Fails with Access Denied

Access 327k tokens of past work via get_observations([IDs]) or mem-search skill.
</claude-mem-context>
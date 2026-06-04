# Graph Report - .  (2026-04-28)

## Corpus Check
- Large corpus: 21 files · ~588,871 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 183 nodes · 246 edges · 9 communities detected
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 29 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_UI Design Tokens & Components|UI Design Tokens & Components]]
- [[_COMMUNITY_ADN Hibrido Redesign App|ADN Hibrido Redesign App]]
- [[_COMMUNITY_S&G Brand & Marketing Site|S&G Brand & Marketing Site]]
- [[_COMMUNITY_S&G Strategy & Research|S&G Strategy & Research]]
- [[_COMMUNITY_AI Knowledge & Research Tools|AI Knowledge & Research Tools]]
- [[_COMMUNITY_Conversational AI & Cloud Infra|Conversational AI & Cloud Infra]]
- [[_COMMUNITY_Creative AI & Multimedia|Creative AI & Multimedia]]
- [[_COMMUNITY_Design System & Docs|Design System & Docs]]
- [[_COMMUNITY_Brand Identity & People|Brand Identity & People]]

## God Nodes (most connected - your core abstractions)
1. `ADN Híbrido · Sesión 1 · S&G (Visual Redesign Workshop Page)` - 37 edges
2. `S&G + IA | El Híbrido Humano (Stitch Landing Page)` - 30 edges
3. `Stitch Landing Page - El Hibrido Humano IA en Seguridad` - 10 edges
4. `ADN Hibrido Workshop App - Visual Redesign Screen` - 10 edges
5. `Investigación y Gestión de Conocimiento` - 9 edges
6. `Generación Multimedia Creativa` - 9 edges
7. `Capa de Infraestructura de Cómputo y Red` - 9 edges
8. `Asistentes Conversacionales y de Texto` - 8 edges
9. `S&G + IA Propuesta Comercial Educativa` - 7 edges
10. `Informe: Transformación Digital y IA en Seguridad y Gestión Ltda.` - 7 edges

## Surprising Connections (you probably didn't know these)
- `HTML Design System — Documento Base Reutilizable v2` --conceptually_related_to--> `ADN Híbrido Sesión 1 — Presentación HTML`  [INFERRED]
  Context/HTML_Design_System__Documento_Base_Reutilizable_v2.pdf → SG_ADN_Hibrido_Sesion1.html
- `HTML Design System — Documento Base Reutilizable v1` --conceptually_related_to--> `S&G + IA Propuesta Comercial Educativa`  [INFERRED]
  Context/HTML_Design_System__Documento_Base_Reutilizable.pdf → SG_IA_Propuesta_Comercial.html
- `Color Token: Primary Gold (#e6c487 / #d4af37)` --semantically_similar_to--> `CSS Variable: --accent (#d4af37)`  [INFERRED] [semantically similar]
  stitch/code.html → stitch_website_visual_redesign/code.html
- `Color Token: Background Dark (#131315 / #050505)` --semantically_similar_to--> `CSS Variable: --bg (#050505)`  [INFERRED] [semantically similar]
  stitch/code.html → stitch_website_visual_redesign/code.html
- `Stitch Landing Page - El Hibrido Humano IA en Seguridad` --semantically_similar_to--> `ADN Hibrido Workshop App - Visual Redesign Screen`  [INFERRED] [semantically similar]
  stitch/screen.png → stitch_website_visual_redesign/screen.png

## Communities

### Community 0 - "UI Design Tokens & Components"
Cohesion: 0.08
Nodes (33): Color Token: Danger Red (#ff4d4d), Color Token: Info Blue (#3e93ff), Color Token: Success Green (#00df81), Color Token: Background Dark (#131315 / #050505), Component: Card (Glassmorphism with hover elevation), Component: Commitment Input Form Row, Component: Data Table (Ecosystem Layers), Component: Demo Prompt Block (NotebookLM queries) (+25 more)

### Community 1 - "ADN Hibrido Redesign App"
Cohesion: 0.09
Nodes (31): CTA Button - COMENZAR EXPERIENCIA (Yellow/Gold), Dark Sidebar Navigation - Portada, Diagnostico, Paradigma, Demo en Vivo, Liderazgo, Cierre+ROI, Hero - ADN HIBRIDO Large Typography with Yellow Accent, Instructor Tag - Juan M. Escandon, 120 minutos, Module Navigation Icons - Paradigma, Live Demo (highlighted), Impacto, Progress Tracker - Accion en Progresso panel, session list with timestamps, Tag - S&G Seguridad & Gestion brand identifier, ADN Hibrido Workshop App - Visual Redesign Screen (+23 more)

### Community 2 - "S&G Brand & Marketing Site"
Cohesion: 0.1
Nodes (27): Brand: S&G (Seguridad & Gestion), Color Token: Primary Gold (#e6c487 / #d4af37), Color Tokens: Surface Container Hierarchy, Layout: Bento Grid (12-column Context Section), Section: CTA / Final Steps, Component: Donut Chart (SVG circle adoption indicator), Section: Expert Profile (Juan Manuel Escandón), Component: Footer (Shared) (+19 more)

### Community 3 - "S&G Strategy & Research"
Cohesion: 0.15
Nodes (22): Área/Proyecto de Innovación Transversal S&G, Camilo Piedrahita — Principal Decisor / Champion IA en S&G, Informe: Transformación Digital y IA en Seguridad y Gestión Ltda., Research Inicial Perplexity — Oportunidades IA para S&G, Reto Research Inicial — Oportunidades IA y Automatización para S&G, Análisis DOFA — Seguridad y Gestión Ltda., Juan M. Escandón — Consultor Principal, Concepto: Liderazgo Aumentado (Augmented Intelligence) (+14 more)

### Community 4 - "AI Knowledge & Research Tools"
Cohesion: 0.1
Nodes (21): Consensus, Consulta de Conocimiento, CRM / Customer Service, Estudios y BD (Insights & Blueml), Genspark, Investigación y Gestión de Conocimiento, Manus, Mendeley (+13 more)

### Community 5 - "Conversational AI & Cloud Infra"
Cohesion: 0.12
Nodes (20): AI21, Asistentes Conversacionales y de Texto, AWS (Amazon Web Services), Microsoft Azure, Bing Chat, Capa de Infraestructura de Cómputo y Red, Cerebras, Claude (Anthropic) (+12 more)

### Community 6 - "Creative AI & Multimedia"
Cohesion: 0.17
Nodes (12): DALL-E, Generación Multimedia Creativa, Generación de Video Generativa, GitHub Copilot, Ideogram, Kling AI, Pika, Runway (+4 more)

### Community 7 - "Design System & Docs"
Cohesion: 0.39
Nodes (9): ADN Híbrido Sesión 1 — Diseño de Página y Contenido, ADN Híbrido Sesión 1 — Implementation Plan, HTML Design System — Documento Base Reutilizable v1, HTML Design System — Documento Base Reutilizable v2, Dark-Gold Design Tokens (CSS Variables — Space Grotesk + Manrope), ADN Híbrido Sesión 1 — Presentación HTML, S&G + IA Propuesta Comercial Educativa, Executive Design System: The Sentinel's Ledger (+1 more)

### Community 8 - "Brand Identity & People"
Cohesion: 0.39
Nodes (8): JM - Person (Profile Subject), JM - Casual/Creative Portrait (Black & White, Close-up), JM - Professional Business Portrait (Suit & Tie, Arms Crossed), Security Industry - Physical Security / Management Services, Seguridad Gestion Ltda - Brand Identity, Seguridad Gestion Ltda - Company, SG Shield Symbol - Yellow Shield with Eagle Monogram, S&G Visual Style - Yellow/Gold and Dark Grey, Bold Sans-serif

## Knowledge Gaps
- **78 isolated node(s):** `Flujo Power Automate — Automatización WhatsApp/Incidentes`, `Cálculo ROI — Productividad Recuperada S&G (COP 33.750.000/año)`, `Color Token: Danger Red (#ff4d4d)`, `Color Token: Success Green (#00df81)`, `Color Token: Info Blue (#3e93ff)` (+73 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ADN Híbrido · Sesión 1 · S&G (Visual Redesign Workshop Page)` connect `UI Design Tokens & Components` to `S&G Brand & Marketing Site`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **Why does `Plataforma de Integración del Usuario` connect `AI Knowledge & Research Tools` to `Conversational AI & Cloud Infra`, `Creative AI & Multimedia`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Why does `S&G + IA | El Híbrido Humano (Stitch Landing Page)` connect `S&G Brand & Marketing Site` to `UI Design Tokens & Components`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `ADN Hibrido Workshop App - Visual Redesign Screen` (e.g. with `Stitch Landing Page - El Hibrido Humano IA en Seguridad` and `Workshop ADN Hibrido Section - Module Structure`) actually correct?**
  _`ADN Hibrido Workshop App - Visual Redesign Screen` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Flujo Power Automate — Automatización WhatsApp/Incidentes`, `Cálculo ROI — Productividad Recuperada S&G (COP 33.750.000/año)`, `Color Token: Danger Red (#ff4d4d)` to the rest of the system?**
  _78 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `UI Design Tokens & Components` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `ADN Hibrido Redesign App` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._
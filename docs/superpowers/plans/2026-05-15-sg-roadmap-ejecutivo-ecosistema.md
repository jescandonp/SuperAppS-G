# S&G Roadmap Ejecutivo Ecosistema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone, executive HTML roadmap for S&G leadership that explains the ecosystem vision, quick wins, dependencies, discovery lines, implementation horizons, and decisions required.

**Architecture:** Create a new standalone HTML artifact instead of modifying `SG_Sesion_Preliminar_Lideres_v1.html`. Reuse the established S&G dark/gold visual language, sidebar navigation, dense cards, and light JavaScript interactions, while replacing the old assessment narrative with the approved ecosystem roadmap.

**Tech Stack:** Static HTML, Tailwind CDN, Google Fonts, Material Symbols, vanilla JavaScript, local browser verification.

---

## File Structure

- Create: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`
  - Standalone executive roadmap page.
  - Contains all markup, styles, Tailwind config, and JavaScript interactions.
  - Uses existing S&G visual conventions from `SG_Sesion_Preliminar_Lideres_v1.html`.
- Read-only reference: `SG_Sesion_Preliminar_Lideres_v1.html`
  - Source for visual style, sidebar behavior, cards, pills, and scroll spy.
- Read-only reference: `docs/superpowers/specs/2026-05-15-sg-roadmap-ejecutivo-ecosistema-design.md`
  - Source of approved content and scope.

No existing HTML should be overwritten in this plan.

---

### Task 1: Create The Standalone Page Shell

**Files:**
- Create: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`
- Reference: `SG_Sesion_Preliminar_Lideres_v1.html`
- Reference: `docs/superpowers/specs/2026-05-15-sg-roadmap-ejecutivo-ecosistema-design.md`

- [ ] **Step 1: Create the initial standalone HTML document**

Create `SG_Roadmap_Ejecutivo_Ecosistema_v1.html` with this full shell:

```html
<!DOCTYPE html>
<html class="dark" lang="es">
<head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>S&G IA - Roadmap Ejecutivo de Ecosistema Operativo</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=Work+Sans:wght@400;500;600&display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap" rel="stylesheet"/>
<style>
  .material-symbols-outlined { font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24; }
  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: #131313; }
  ::-webkit-scrollbar-thumb { background: #353534; border-radius: 2px; }
  html { scroll-behavior: smooth; }
  .glass-card { background: linear-gradient(135deg, rgba(32,31,31,0.88) 0%, rgba(14,14,14,0.96) 100%); backdrop-filter: blur(10px); }
  .nav-active { color: #f5bf00; background: rgba(245,191,0,0.07); border-right: 2px solid #f5bf00; }
  .dot-grid { background-image: radial-gradient(circle, #2a2a2a 1px, transparent 1px); background-size: 22px 22px; }
  .section-marker { width:3px; height:28px; background:#f5bf00; border-radius:2px; display:inline-block; margin-right:12px; vertical-align:middle; }
  .pill { display:inline-block; padding:2px 10px; border-radius:999px; font-size:11px; font-weight:700; letter-spacing:.04em; }
  .pill-op { background:rgba(59,130,246,0.15); color:#93c5fd; border:1px solid rgba(59,130,246,0.25); }
  .pill-th { background:rgba(16,185,129,0.15); color:#6ee7b7; border:1px solid rgba(16,185,129,0.25); }
  .pill-fin { background:rgba(168,85,247,0.14); color:#d8b4fe; border:1px solid rgba(168,85,247,0.25); }
  .pill-gold { background:rgba(245,191,0,0.13); color:#f5bf00; border:1px solid rgba(245,191,0,0.3); }
  .pill-strategic { background:rgba(14,165,233,0.13); color:#7dd3fc; border:1px solid rgba(14,165,233,0.28); }
  .area-op { border-left: 3px solid #3b82f6; }
  .area-th { border-left: 3px solid #10b981; }
  .area-fin { border-left: 3px solid #a855f7; }
  .area-gold { border-left: 3px solid #f5bf00; }
  .metric-glow { box-shadow: 0 0 30px rgba(245,191,0,0.08); }
  .filter-active { background:#f5bf00; color:#3e2e00; border-color:#f5bf00; }
  .initiative-card[hidden] { display:none; }
  .roadmap-panel[hidden] { display:none; }
  .detail-panel { display:none; }
  .detail-panel.open { display:block; }
</style>
<script id="tailwind-config">
  tailwind.config = {
    darkMode:"class",
    theme:{
      extend:{
        colors:{
          "primary":"#ffe9b9","on-primary":"#3e2e00","primary-container":"#ffc700",
          "primary-fixed-dim":"#f5bf00","secondary":"#bfc6dc","secondary-container":"#3f4759",
          "surface":"#131313","surface-container":"#201f1f","surface-container-high":"#2a2a2a",
          "surface-container-highest":"#353534","on-surface":"#e5e2e1","on-surface-variant":"#d2c5ab",
          "outline":"#9b9078","outline-variant":"#4f4632","background":"#131313","on-background":"#e5e2e1",
          "error":"#ffb4ab","error-container":"#93000a"
        },
        fontFamily:{"inter":["Inter"],"work":["Work Sans"]},
        borderRadius:{"DEFAULT":"0.125rem","lg":"0.25rem","xl":"0.5rem","full":"0.75rem"}
      }
    }
  }
</script>
</head>
<body class="bg-background text-on-surface antialiased" style="font-family:'Work Sans',sans-serif;">
<nav class="fixed top-0 left-0 h-full w-56 bg-surface-container border-r border-outline-variant z-40 hidden lg:flex flex-col py-6 px-0 gap-0">
  <div class="px-5 mb-6">
    <div class="flex items-center gap-2 mb-1">
      <span class="text-primary-fixed-dim font-black text-sm" style="font-family:'Inter',sans-serif;">S&amp;G</span>
      <span class="text-on-surface-variant text-xs">+ IA</span>
    </div>
    <div class="text-on-surface-variant" style="font-size:10px;letter-spacing:.08em;font-family:'Inter',sans-serif;font-weight:700;text-transform:uppercase;">Roadmap Ejecutivo</div>
  </div>
  <a href="#resumen" class="nav-link flex items-center gap-3 px-5 py-2.5 text-on-surface-variant hover:text-on-surface text-sm transition-colors nav-active" onclick="setNav(this)"><span class="material-symbols-outlined text-base">dashboard</span>Resumen</a>
  <a href="#diagnostico" class="nav-link flex items-center gap-3 px-5 py-2.5 text-on-surface-variant hover:text-on-surface text-sm transition-colors" onclick="setNav(this)"><span class="material-symbols-outlined text-base">manage_search</span>Diagnóstico</a>
  <a href="#ecosistema" class="nav-link flex items-center gap-3 px-5 py-2.5 text-on-surface-variant hover:text-on-surface text-sm transition-colors" onclick="setNav(this)"><span class="material-symbols-outlined text-base">hub</span>Ecosistema</a>
  <a href="#quickwins" class="nav-link flex items-center gap-3 px-5 py-2.5 text-on-surface-variant hover:text-on-surface text-sm transition-colors" onclick="setNav(this)"><span class="material-symbols-outlined text-base">bolt</span>Quick Wins</a>
  <a href="#descubrimiento" class="nav-link flex items-center gap-3 px-5 py-2.5 text-on-surface-variant hover:text-on-surface text-sm transition-colors" onclick="setNav(this)"><span class="material-symbols-outlined text-base">travel_explore</span>Descubrimiento</a>
  <a href="#roadmap" class="nav-link flex items-center gap-3 px-5 py-2.5 text-on-surface-variant hover:text-on-surface text-sm transition-colors" onclick="setNav(this)"><span class="material-symbols-outlined text-base">route</span>Roadmap</a>
  <a href="#decisiones" class="nav-link flex items-center gap-3 px-5 py-2.5 text-on-surface-variant hover:text-on-surface text-sm transition-colors" onclick="setNav(this)"><span class="material-symbols-outlined text-base">fact_check</span>Decisiones</a>
  <div class="mt-auto px-5 pb-2">
    <div class="text-outline text-xs">Mayo 2026 · Gerencia</div>
  </div>
</nav>
<main class="lg:ml-56 min-h-screen">
  <section id="resumen" class="dot-grid border-b border-outline-variant px-6 lg:px-12 pt-12 pb-10"></section>
  <section id="diagnostico" class="px-6 lg:px-12 py-12 border-b border-outline-variant"></section>
  <section id="ecosistema" class="px-6 lg:px-12 py-12 border-b border-outline-variant bg-surface-container/20"></section>
  <section id="quickwins" class="px-6 lg:px-12 py-12 border-b border-outline-variant"></section>
  <section id="descubrimiento" class="px-6 lg:px-12 py-12 border-b border-outline-variant bg-surface-container/20"></section>
  <section id="roadmap" class="px-6 lg:px-12 py-12 border-b border-outline-variant"></section>
  <section id="decisiones" class="px-6 lg:px-12 py-12"></section>
</main>
<script>
  function setNav(el){
    document.querySelectorAll('.nav-link').forEach(a=>a.classList.remove('nav-active'));
    el.classList.add('nav-active');
  }
</script>
</body>
</html>
```

- [ ] **Step 2: Verify the file exists**

Run:

```powershell
Test-Path -LiteralPath .\SG_Roadmap_Ejecutivo_Ecosistema_v1.html
```

Expected:

```text
True
```

---

### Task 2: Add Executive Hero And Diagnostic Sections

**Files:**
- Modify: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`

- [ ] **Step 1: Fill `#resumen` with the executive thesis**

Replace the empty `section id="resumen"` block with:

```html
  <section id="resumen" class="dot-grid border-b border-outline-variant px-6 lg:px-12 pt-12 pb-10">
    <div class="max-w-6xl mx-auto">
      <div class="flex flex-wrap items-center gap-2 mb-4">
        <span class="pill pill-op">Operaciones</span>
        <span class="pill pill-th">Talento Humano</span>
        <span class="pill pill-fin">Financiero</span>
        <span class="text-outline text-xs ml-1">Roadmap ejecutivo · Mayo 2026</span>
      </div>
      <h1 class="text-on-surface mb-3" style="font-family:'Inter',sans-serif;font-size:42px;font-weight:900;line-height:1.08;">
        Roadmap Ejecutivo S&amp;G
        <span class="text-primary-fixed-dim block" style="font-size:32px;">Del assessment a un ecosistema de gestión operativa</span>
      </h1>
      <p class="text-on-surface-variant max-w-3xl" style="font-size:16px;line-height:1.75;">
        S&amp;G no necesita una aplicación aislada. Necesita una base operativa confiable donde novedades, empleados, puestos, cursos e inventario se conviertan en datos gobernados para operar con trazabilidad, control y capacidad de escalar.
      </p>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-8">
        <div class="glass-card metric-glow rounded-xl p-5">
          <div class="text-outline text-xs uppercase tracking-widest mb-1" style="font-family:'Inter',sans-serif;">Eje inicial</div>
          <div class="text-primary-fixed-dim font-black mt-1" style="font-family:'Inter',sans-serif;font-size:30px;line-height:1;">Novedades</div>
          <div class="text-on-surface-variant text-xs mt-2">entrada clave del ecosistema</div>
        </div>
        <div class="glass-card rounded-xl p-5">
          <div class="text-outline text-xs uppercase tracking-widest mb-1" style="font-family:'Inter',sans-serif;">Quick wins</div>
          <div class="text-emerald-300 font-black mt-1" style="font-family:'Inter',sans-serif;font-size:42px;line-height:1;">3</div>
          <div class="text-on-surface-variant text-xs mt-2">novedades, cursos, certificaciones</div>
        </div>
        <div class="glass-card rounded-xl p-5">
          <div class="text-outline text-xs uppercase tracking-widest mb-1" style="font-family:'Inter',sans-serif;">Líneas estratégicas</div>
          <div class="text-sky-300 font-black mt-1" style="font-family:'Inter',sans-serif;font-size:42px;line-height:1;">2</div>
          <div class="text-on-surface-variant text-xs mt-2">inventario y turnos</div>
        </div>
        <div class="glass-card rounded-xl p-5">
          <div class="text-outline text-xs uppercase tracking-widest mb-1" style="font-family:'Inter',sans-serif;">Horizonte</div>
          <div class="text-amber-300 font-black mt-1" style="font-family:'Inter',sans-serif;font-size:42px;line-height:1;">90</div>
          <div class="text-on-surface-variant text-xs mt-2">días para pilotos y métricas</div>
        </div>
      </div>
      <div class="mt-6 rounded-xl border border-primary-fixed-dim/30 bg-primary-fixed-dim/10 p-4 flex gap-3 items-start">
        <span class="material-symbols-outlined text-primary-fixed-dim mt-0.5">tips_and_updates</span>
        <div>
          <div class="text-primary-fixed-dim font-semibold text-sm" style="font-family:'Inter',sans-serif;">Tesis para decisión gerencial</div>
          <div class="text-on-surface-variant text-sm mt-1">Los quick wins deben construirse como piezas de un ecosistema común. Cada entrega temprana debe producir datos reutilizables para trazabilidad, analítica y optimización futura.</div>
        </div>
      </div>
    </div>
  </section>
```

- [ ] **Step 2: Fill `#diagnostico` with area findings**

Replace the empty `section id="diagnostico"` block with:

```html
  <section id="diagnostico" class="px-6 lg:px-12 py-12 border-b border-outline-variant">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center gap-3 mb-2">
        <span class="section-marker"></span>
        <h2 style="font-family:'Inter',sans-serif;font-size:26px;font-weight:800;">Diagnóstico consolidado</h2>
      </div>
      <p class="text-on-surface-variant text-sm mb-8 ml-6">Tres sesiones confirman el mismo patrón: procesos críticos dependen de trabajo manual, hojas de cálculo, papel y seguimiento informal.</p>
      <div class="grid md:grid-cols-3 gap-5">
        <article class="glass-card area-op rounded-xl p-5">
          <span class="pill pill-op">Operaciones</span>
          <h3 class="mt-4 text-on-surface font-bold" style="font-family:'Inter',sans-serif;font-size:18px;">Novedades como punto de entrada</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">La operación gira alrededor de novedades, pero hoy no existe un sistema confiable y adoptado para capturarlas, clasificarlas, asignarlas y cerrarlas.</p>
          <div class="mt-4 p-3 rounded-lg bg-blue-950/20 border border-blue-900/30 text-sm text-blue-100">Turnos automáticos es dolor crítico, pero depende de maestros y reglas. Entra como descubrimiento, no como quick win.</div>
        </article>
        <article class="glass-card area-fin rounded-xl p-5">
          <span class="pill pill-fin">Financiero</span>
          <h3 class="mt-4 text-on-surface font-bold" style="font-family:'Inter',sans-serif;font-size:18px;">Inventario sin trazabilidad completa</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">HELIZA soporta contabilidad, pero dotaciones e inventario siguen en Excel, con poca visibilidad sobre asignaciones a guardas, puestos y movimientos.</p>
          <div class="mt-4 p-3 rounded-lg bg-purple-950/20 border border-purple-900/30 text-sm text-purple-100">El primer paso no es una app completa, sino descubrir fuentes y modelar datos.</div>
        </article>
        <article class="glass-card area-th rounded-xl p-5">
          <span class="pill pill-th">Talento Humano</span>
          <h3 class="mt-4 text-on-surface font-bold" style="font-family:'Inter',sans-serif;font-size:18px;">Datos críticos con gestión manual</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">TH alimenta empleados en HELIZA, pero conserva documentación y controles en papel/Excel. Cursos obligatorios y certificaciones laborales son candidatos claros para automatización.</p>
          <div class="mt-4 p-3 rounded-lg bg-emerald-950/20 border border-emerald-900/30 text-sm text-emerald-100">Cursos conecta directamente con Operaciones: un guarda con curso vencido no debería prestar servicio.</div>
        </article>
      </div>
    </div>
  </section>
```

- [ ] **Step 3: Verify section anchors are present**

Run:

```powershell
Select-String -LiteralPath .\SG_Roadmap_Ejecutivo_Ecosistema_v1.html -Pattern 'id="resumen"|id="diagnostico"|Roadmap Ejecutivo S&amp;G|Diagnóstico consolidado'
```

Expected: output includes all four patterns.

---

### Task 3: Add Ecosystem Map And Quick Win Cards

**Files:**
- Modify: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`

- [ ] **Step 1: Fill `#ecosistema` with layer stack and dependency matrix**

Replace the empty `section id="ecosistema"` block with a layer stack:

```html
  <section id="ecosistema" class="px-6 lg:px-12 py-12 border-b border-outline-variant bg-surface-container/20">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center gap-3 mb-2">
        <span class="section-marker"></span>
        <h2 style="font-family:'Inter',sans-serif;font-size:26px;font-weight:800;">Mapa del ecosistema</h2>
      </div>
      <p class="text-on-surface-variant text-sm mb-8 ml-6">La base maestra propia del ecosistema es la autoridad objetivo. Excel y HELIZA alimentan la carga inicial, pero no gobiernan el futuro operativo.</p>
      <div class="grid lg:grid-cols-[1.1fr_0.9fr] gap-6">
        <div class="space-y-3">
          <div class="glass-card rounded-xl p-4 border border-sky-500/20">
            <div class="flex items-center justify-between gap-3">
              <div><div class="text-sky-300 text-xs uppercase tracking-widest font-bold">Capa 5</div><div class="font-bold text-on-surface">Optimización avanzada</div></div>
              <div class="text-xs text-outline">turnos · predicción · escalamiento</div>
            </div>
          </div>
          <div class="glass-card rounded-xl p-4 border border-emerald-500/20">
            <div class="flex items-center justify-between gap-3">
              <div><div class="text-emerald-300 text-xs uppercase tracking-widest font-bold">Capa 4</div><div class="font-bold text-on-surface">Analítica gerencial</div></div>
              <div class="text-xs text-outline">tableros · KPIs · riesgos</div>
            </div>
          </div>
          <div class="glass-card rounded-xl p-4 border border-amber-500/20">
            <div class="flex items-center justify-between gap-3">
              <div><div class="text-amber-300 text-xs uppercase tracking-widest font-bold">Capa 3</div><div class="font-bold text-on-surface">Automatización de quick wins</div></div>
              <div class="text-xs text-outline">cursos · certificaciones · novedades</div>
            </div>
          </div>
          <div class="glass-card rounded-xl p-4 border border-blue-500/20">
            <div class="flex items-center justify-between gap-3">
              <div><div class="text-blue-300 text-xs uppercase tracking-widest font-bold">Capa 2</div><div class="font-bold text-on-surface">Captura operativa</div></div>
              <div class="text-xs text-outline">novedades estructuradas</div>
            </div>
          </div>
          <div class="rounded-xl p-5 border border-primary-fixed-dim/40 bg-primary-fixed-dim/10 metric-glow">
            <div class="text-primary-fixed-dim text-xs uppercase tracking-widest font-bold">Capa 1</div>
            <div class="font-black text-on-surface mt-1" style="font-family:'Inter',sans-serif;font-size:22px;">Datos maestros interoperables</div>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-2 mt-4 text-xs text-on-surface-variant">
              <span>Empleados</span><span>Puestos</span><span>Clientes</span><span>Cursos</span><span>Inventario</span><span>Novedades</span>
            </div>
          </div>
        </div>
        <div class="glass-card rounded-xl p-5">
          <h3 class="font-bold text-on-surface mb-4" style="font-family:'Inter',sans-serif;">Impacto vs dependencia</h3>
          <div class="space-y-3 text-sm">
            <div class="flex items-center justify-between gap-3 p-3 rounded-lg bg-emerald-950/20 border border-emerald-900/30"><span>Novedades operativas</span><span class="pill pill-th">Alto impacto · dependencia media</span></div>
            <div class="flex items-center justify-between gap-3 p-3 rounded-lg bg-emerald-950/20 border border-emerald-900/30"><span>Cursos obligatorios</span><span class="pill pill-th">Alto impacto · dependencia baja</span></div>
            <div class="flex items-center justify-between gap-3 p-3 rounded-lg bg-amber-950/20 border border-amber-900/30"><span>Certificaciones laborales</span><span class="pill pill-gold">Impacto medio · dependencia baja</span></div>
            <div class="flex items-center justify-between gap-3 p-3 rounded-lg bg-sky-950/20 border border-sky-900/30"><span>Inventario/dotaciones</span><span class="pill pill-strategic">Descubrimiento</span></div>
            <div class="flex items-center justify-between gap-3 p-3 rounded-lg bg-sky-950/20 border border-sky-900/30"><span>Turnos automáticos</span><span class="pill pill-strategic">Estratégico</span></div>
          </div>
        </div>
      </div>
    </div>
  </section>
```

- [ ] **Step 2: Fill `#quickwins` with filterable initiative cards**

Replace the empty `section id="quickwins"` block with:

```html
  <section id="quickwins" class="px-6 lg:px-12 py-12 border-b border-outline-variant">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center gap-3 mb-2">
        <span class="section-marker"></span>
        <h2 style="font-family:'Inter',sans-serif;font-size:26px;font-weight:800;">Microproyectos iniciales</h2>
      </div>
      <p class="text-on-surface-variant text-sm mb-6 ml-6">Los quick wins se ejecutan como piezas del ecosistema: cada entrega debe generar o consumir datos reutilizables.</p>
      <div class="flex flex-wrap gap-2 mb-6 ml-6">
        <button class="filter-btn filter-active rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold" data-filter="all">Todos</button>
        <button class="filter-btn rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold text-on-surface-variant" data-filter="quickwin">Quick Win</button>
        <button class="filter-btn rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold text-on-surface-variant" data-filter="discovery">Descubrimiento</button>
        <button class="filter-btn rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold text-on-surface-variant" data-filter="strategic">Estratégico</button>
      </div>
      <div class="grid md:grid-cols-3 gap-5">
        <article class="initiative-card glass-card area-op rounded-xl p-5" data-type="quickwin">
          <span class="pill pill-op">Quick Win</span>
          <h3 class="font-bold text-on-surface mt-4" style="font-family:'Inter',sans-serif;font-size:18px;">Novedades operativas</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">Captura y seguimiento de novedades con estado, responsable, criticidad y evidencia.</p>
          <button class="detail-toggle mt-4 text-primary-fixed-dim text-xs font-bold" data-target="detail-novedades">Ver detalle</button>
          <div id="detail-novedades" class="detail-panel mt-4 border-t border-outline-variant pt-4 text-xs text-on-surface-variant leading-5">Produce historial por puesto, cliente, tipo, criticidad, responsable y cierre. Es el eje inicial del ecosistema.</div>
        </article>
        <article class="initiative-card glass-card area-th rounded-xl p-5" data-type="quickwin">
          <span class="pill pill-th">Quick Win</span>
          <h3 class="font-bold text-on-surface mt-4" style="font-family:'Inter',sans-serif;font-size:18px;">Alertas de cursos</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">Base cargada desde Excel, tablero de vigencias y alertas previas al vencimiento.</p>
          <button class="detail-toggle mt-4 text-primary-fixed-dim text-xs font-bold" data-target="detail-cursos">Ver detalle</button>
          <div id="detail-cursos" class="detail-panel mt-4 border-t border-outline-variant pt-4 text-xs text-on-surface-variant leading-5">Reduce riesgo operativo: un guarda con curso vencido no debería prestar servicio.</div>
        </article>
        <article class="initiative-card glass-card area-th rounded-xl p-5" data-type="quickwin">
          <span class="pill pill-th">Quick Win</span>
          <h3 class="font-bold text-on-surface mt-4" style="font-family:'Inter',sans-serif;font-size:18px;">Certificaciones laborales</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">Generador semiautomático para certificaciones de empleados activos y retirados.</p>
          <button class="detail-toggle mt-4 text-primary-fixed-dim text-xs font-bold" data-target="detail-certificaciones">Ver detalle</button>
          <div id="detail-certificaciones" class="detail-panel mt-4 border-t border-outline-variant pt-4 text-xs text-on-surface-variant leading-5">Ahorro administrativo visible, estandarización documental y mejor experiencia de respuesta.</div>
        </article>
      </div>
    </div>
  </section>
```

- [ ] **Step 3: Verify key content exists**

Run:

```powershell
Select-String -LiteralPath .\SG_Roadmap_Ejecutivo_Ecosistema_v1.html -Pattern 'Mapa del ecosistema|Datos maestros interoperables|Microproyectos iniciales|Novedades operativas|Alertas de cursos|Certificaciones laborales'
```

Expected: output includes all six phrases.

---

### Task 4: Add Discovery Lines, Roadmap Tabs, And Executive Decisions

**Files:**
- Modify: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`

- [ ] **Step 1: Fill `#descubrimiento`**

Add two cards: `Inventario y dotaciones` and `Programación automática de turnos`. Each card must state that it is not a quick win and list dependencies.

Use this content:

```html
  <section id="descubrimiento" class="px-6 lg:px-12 py-12 border-b border-outline-variant bg-surface-container/20">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center gap-3 mb-2">
        <span class="section-marker"></span>
        <h2 style="font-family:'Inter',sans-serif;font-size:26px;font-weight:800;">Líneas de descubrimiento</h2>
      </div>
      <p class="text-on-surface-variant text-sm mb-8 ml-6">Estas líneas son estratégicas, pero requieren datos, reglas y diseño funcional antes de convertirse en entregables completos.</p>
      <div class="grid md:grid-cols-2 gap-5">
        <article class="initiative-card glass-card area-fin rounded-xl p-6" data-type="discovery">
          <span class="pill pill-fin">Descubrimiento</span>
          <h3 class="font-bold text-on-surface mt-4" style="font-family:'Inter',sans-serif;font-size:20px;">Inventario y dotaciones</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">Inicia con fuentes, modelo de datos y trazabilidad de asignaciones antes de construir una app completa.</p>
          <ul class="mt-4 space-y-2 text-sm text-on-surface-variant">
            <li>• Elementos controlados como dotación, inventario o activo.</li>
            <li>• Asignaciones a guardas, puestos, coordinadores o áreas.</li>
            <li>• Eventos: entrega, devolución, reposición, pérdida, baja y traslado.</li>
            <li>• Relación con Financiero, TH y Operaciones.</li>
          </ul>
        </article>
        <article class="initiative-card glass-card area-gold rounded-xl p-6" data-type="strategic">
          <span class="pill pill-strategic">Estratégico</span>
          <h3 class="font-bold text-on-surface mt-4" style="font-family:'Inter',sans-serif;font-size:20px;">Programación automática de turnos</h3>
          <p class="text-on-surface-variant text-sm mt-3 leading-6">Es una línea de diseño funcional. No debe prometerse como entrega temprana sin maestros, reglas y restricciones.</p>
          <ul class="mt-4 space-y-2 text-sm text-on-surface-variant">
            <li>• Guardas normalizados y cursos vigentes.</li>
            <li>• Puestos de servicio y cobertura requerida.</li>
            <li>• Disponibilidad, rotación y restricciones legales.</li>
            <li>• Novedades históricas y reglas operativas.</li>
          </ul>
        </article>
      </div>
    </div>
  </section>
```

- [ ] **Step 2: Fill `#roadmap` with tab panels**

Add roadmap tabs with four panels: `0-30`, `31-60`, `61-90`, `6-12`.

Use this content:

```html
  <section id="roadmap" class="px-6 lg:px-12 py-12 border-b border-outline-variant">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center gap-3 mb-2">
        <span class="section-marker"></span>
        <h2 style="font-family:'Inter',sans-serif;font-size:26px;font-weight:800;">Roadmap de implementación</h2>
      </div>
      <p class="text-on-surface-variant text-sm mb-6 ml-6">Secuencia propuesta para pasar de levantamiento a PRD, pilotos y primeras métricas gerenciales.</p>
      <div class="flex flex-wrap gap-2 mb-6 ml-6">
        <button class="roadmap-tab filter-active rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold" data-panel="r30">0-30 días</button>
        <button class="roadmap-tab rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold text-on-surface-variant" data-panel="r60">31-60 días</button>
        <button class="roadmap-tab rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold text-on-surface-variant" data-panel="r90">61-90 días</button>
        <button class="roadmap-tab rounded-lg border border-outline-variant px-3 py-2 text-xs font-bold text-on-surface-variant" data-panel="r12">6-12 meses</button>
      </div>
      <div class="glass-card rounded-xl p-6">
        <div id="r30" class="roadmap-panel">
          <h3 class="font-bold text-primary-fixed-dim mb-4" style="font-family:'Inter',sans-serif;">0-30 días · Diseño y datos mínimos</h3>
          <ul class="space-y-2 text-sm text-on-surface-variant"><li>• Cerrar PRD de novedades operativas.</li><li>• Validar maestros mínimos: empleados, puestos, clientes y cursos.</li><li>• Recibir y analizar Excel de cursos obligatorios.</li><li>• Definir plantillas de certificaciones laborales.</li><li>• Iniciar modelo conceptual de inventario/dotaciones.</li></ul>
        </div>
        <div id="r60" class="roadmap-panel" hidden>
          <h3 class="font-bold text-primary-fixed-dim mb-4" style="font-family:'Inter',sans-serif;">31-60 días · MVP y prototipos</h3>
          <ul class="space-y-2 text-sm text-on-surface-variant"><li>• Construir MVP de novedades.</li><li>• Construir tablero inicial de cursos vencidos y próximos a vencer.</li><li>• Construir generador semiautomático de certificaciones.</li><li>• Crear prototipo inicial de datos maestros.</li><li>• Ejecutar piloto controlado con Operaciones y TH.</li></ul>
        </div>
        <div id="r90" class="roadmap-panel" hidden>
          <h3 class="font-bold text-primary-fixed-dim mb-4" style="font-family:'Inter',sans-serif;">61-90 días · Piloto y gobierno</h3>
          <ul class="space-y-2 text-sm text-on-surface-variant"><li>• Activar tablero gerencial inicial.</li><li>• Incorporar flujo de cierre y seguimiento de novedades.</li><li>• Definir reglas mínimas de gobierno de datos.</li><li>• Ajustar MVP según piloto.</li><li>• Documentar PRD siguiente para inventario o turnos.</li></ul>
        </div>
        <div id="r12" class="roadmap-panel" hidden>
          <h3 class="font-bold text-primary-fixed-dim mb-4" style="font-family:'Inter',sans-serif;">6-12 meses · Escalamiento del ecosistema</h3>
          <ul class="space-y-2 text-sm text-on-surface-variant"><li>• Integrar inventario/dotaciones al ecosistema.</li><li>• Avanzar en analítica operativa.</li><li>• Diseñar/prototipar programación automática de turnos.</li><li>• Conectar progresivamente con Comercial, Comunicaciones, Gerencia e Inventario.</li><li>• Consolidar operación medible, trazable y gobernada por datos.</li></ul>
        </div>
      </div>
    </div>
  </section>
```

- [ ] **Step 3: Fill `#decisiones` with the executive checklist**

Use this content:

```html
  <section id="decisiones" class="px-6 lg:px-12 py-12">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center gap-3 mb-2">
        <span class="section-marker"></span>
        <h2 style="font-family:'Inter',sans-serif;font-size:26px;font-weight:800;">Decisiones para gerencia</h2>
      </div>
      <p class="text-on-surface-variant text-sm mb-8 ml-6">La sesión debe cerrar con decisiones concretas para habilitar PRD, pilotos y adopción.</p>
      <div class="grid md:grid-cols-2 gap-4">
        <div class="glass-card rounded-xl p-4 flex gap-3"><span class="material-symbols-outlined text-primary-fixed-dim">check_circle</span><span class="text-sm text-on-surface-variant">Aprobar el enfoque de ecosistema, no aplicaciones aisladas.</span></div>
        <div class="glass-card rounded-xl p-4 flex gap-3"><span class="material-symbols-outlined text-primary-fixed-dim">check_circle</span><span class="text-sm text-on-surface-variant">Confirmar quick wins iniciales: novedades, cursos y certificaciones.</span></div>
        <div class="glass-card rounded-xl p-4 flex gap-3"><span class="material-symbols-outlined text-primary-fixed-dim">check_circle</span><span class="text-sm text-on-surface-variant">Designar sponsor ejecutivo y responsables funcionales por área.</span></div>
        <div class="glass-card rounded-xl p-4 flex gap-3"><span class="material-symbols-outlined text-primary-fixed-dim">check_circle</span><span class="text-sm text-on-surface-variant">Habilitar acceso a fuentes iniciales: Excel, HELIZA y documentos.</span></div>
        <div class="glass-card rounded-xl p-4 flex gap-3"><span class="material-symbols-outlined text-primary-fixed-dim">check_circle</span><span class="text-sm text-on-surface-variant">Confirmar infraestructura disponible para despliegue.</span></div>
        <div class="glass-card rounded-xl p-4 flex gap-3"><span class="material-symbols-outlined text-primary-fixed-dim">check_circle</span><span class="text-sm text-on-surface-variant">Acordar cadencia de PRD, piloto, validación y adopción.</span></div>
      </div>
      <div class="mt-8 glass-card rounded-xl p-6 border border-primary-fixed-dim/30 metric-glow">
        <div class="text-primary-fixed-dim font-bold text-sm" style="font-family:'Inter',sans-serif;">Cierre ejecutivo</div>
        <p class="text-on-surface-variant mt-2 leading-7">El primer ciclo debe demostrar valor sin perder arquitectura: capturar novedades, controlar cursos, automatizar certificaciones y construir la base maestra que permita inventario, analítica y turnos en fases posteriores.</p>
      </div>
      <div class="mt-10 flex flex-wrap items-center justify-between gap-3 text-outline text-xs border-t border-outline-variant pt-5">
        <div>Seguridad &amp; Gestión LTDA · Roadmap Ejecutivo · Mayo 2026</div>
        <div class="text-primary-fixed-dim font-semibold" style="font-family:'Inter',sans-serif;">S&amp;G + IA</div>
      </div>
    </div>
  </section>
```

- [ ] **Step 4: Verify section content exists**

Run:

```powershell
Select-String -LiteralPath .\SG_Roadmap_Ejecutivo_Ecosistema_v1.html -Pattern 'Líneas de descubrimiento|Programación automática de turnos|Roadmap de implementación|Decisiones para gerencia|Cierre ejecutivo'
```

Expected: output includes all five phrases.

---

### Task 5: Add Interactions And Verify Static Structure

**Files:**
- Modify: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`

- [ ] **Step 1: Replace the final script with full interaction code**

Replace the final `<script>` block with:

```html
<script>
  function setNav(el){
    document.querySelectorAll('.nav-link').forEach(a=>a.classList.remove('nav-active'));
    el.classList.add('nav-active');
  }

  const sections = document.querySelectorAll('section[id]');
  const navLinks = document.querySelectorAll('.nav-link');
  const observer = new IntersectionObserver(entries=>{
    entries.forEach(entry=>{
      if(entry.isIntersecting){
        navLinks.forEach(link=>{
          link.classList.toggle('nav-active', link.getAttribute('href') === '#' + entry.target.id);
        });
      }
    });
  }, { threshold: 0.28 });
  sections.forEach(section=>observer.observe(section));

  document.querySelectorAll('.filter-btn').forEach(button=>{
    button.addEventListener('click', ()=>{
      const filter = button.dataset.filter;
      document.querySelectorAll('.filter-btn').forEach(item=>{
        item.classList.remove('filter-active');
        item.classList.add('text-on-surface-variant');
      });
      button.classList.add('filter-active');
      button.classList.remove('text-on-surface-variant');
      document.querySelectorAll('.initiative-card').forEach(card=>{
        card.hidden = filter !== 'all' && card.dataset.type !== filter;
      });
    });
  });

  document.querySelectorAll('.detail-toggle').forEach(button=>{
    button.addEventListener('click', ()=>{
      const panel = document.getElementById(button.dataset.target);
      panel.classList.toggle('open');
      button.textContent = panel.classList.contains('open') ? 'Ocultar detalle' : 'Ver detalle';
    });
  });

  document.querySelectorAll('.roadmap-tab').forEach(button=>{
    button.addEventListener('click', ()=>{
      document.querySelectorAll('.roadmap-tab').forEach(tab=>{
        tab.classList.remove('filter-active');
        tab.classList.add('text-on-surface-variant');
      });
      button.classList.add('filter-active');
      button.classList.remove('text-on-surface-variant');
      document.querySelectorAll('.roadmap-panel').forEach(panel=>{
        panel.hidden = panel.id !== button.dataset.panel;
      });
    });
  });
</script>
```

- [ ] **Step 2: Verify there are no empty section bodies**

Run:

```powershell
Select-String -LiteralPath .\SG_Roadmap_Ejecutivo_Ecosistema_v1.html -Pattern '<section id="[^"]+"[^>]*></section>'
```

Expected: no output.

- [ ] **Step 3: Verify all navigation targets exist**

Run:

```powershell
Select-String -LiteralPath .\SG_Roadmap_Ejecutivo_Ecosistema_v1.html -Pattern 'href="#resumen"|href="#diagnostico"|href="#ecosistema"|href="#quickwins"|href="#descubrimiento"|href="#roadmap"|href="#decisiones"|id="resumen"|id="diagnostico"|id="ecosistema"|id="quickwins"|id="descubrimiento"|id="roadmap"|id="decisiones"'
```

Expected: output includes each `href` and each matching `id`.

---

### Task 6: Browser Verification And Graph Update

**Files:**
- Verify: `SG_Roadmap_Ejecutivo_Ecosistema_v1.html`
- Generated/updated by command if supported: `graphify-out/*`

- [ ] **Step 1: Open the standalone HTML in a browser**

Use the Codex Browser plugin or open the local file path:

```text
C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\SG_Roadmap_Ejecutivo_Ecosistema_v1.html
```

Expected:

- Page renders without blank screen.
- Sidebar appears on desktop viewport.
- Hero KPIs fit inside cards.
- No text overlaps in executive cards.
- Dark/gold visual identity is consistent with the existing S&G style.

- [ ] **Step 2: Test interactions manually**

In the browser:

- Click `Quick Win`, `Descubrimiento`, and `Estratégico` filters.
- Click `Ver detalle` on each quick win card.
- Click each roadmap tab: `0-30 días`, `31-60 días`, `61-90 días`, `6-12 meses`.
- Click sidebar anchors.

Expected:

- Filters hide/show the correct initiative cards.
- Detail panels expand and collapse.
- Only the selected roadmap panel is visible.
- Sidebar navigation scrolls to the correct section.

- [ ] **Step 3: Run Graphify update because an HTML code artifact changed**

Run:

```powershell
graphify update .
```

Expected:

- Command completes without a fatal error.
- `graphify-out/` remains present.

If `graphify` is not available in PATH, record the exact command failure in the final implementation summary and do not block delivery of the static HTML.

- [ ] **Step 4: Final local file check**

Run:

```powershell
Get-Item -LiteralPath .\SG_Roadmap_Ejecutivo_Ecosistema_v1.html | Select-Object FullName,Length,LastWriteTime
```

Expected:

- `FullName` points to `C:\Users\jmep2\Downloads\AgenIALab\ProyectoS&G\SG_Roadmap_Ejecutivo_Ecosistema_v1.html`.
- `Length` is greater than `25000`.

---

## Self-Review

Spec coverage:

- Executive thesis: Task 2.
- Area findings: Task 2.
- Ecosystem model and base maestros: Task 3.
- Quick wins: Task 3.
- Discovery lines: Task 4.
- Roadmap horizons: Task 4.
- Executive decisions: Task 4.
- Interactions: Task 5.
- Visual/browser verification: Task 6.
- Graphify update after HTML change: Task 6.

Scope check:

- This plan creates only the executive HTML roadmap.
- PRDs for novedades, cursos, certificaciones, inventario, and turnos are intentionally outside this implementation plan.

Repository note:

- This workspace currently does not contain a `.git` directory, so the implementation plan does not include commit steps. If the project is later moved into a Git repository, commit the HTML and docs in a single focused commit after verification.

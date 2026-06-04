# ADN Híbrido Sesión 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `SG_ADN_Hibrido_Sesion1.html` — a standalone session presentation page for Workshop ADN Híbrido Sesión 1 at Seguridad & Gestión, projectable and shareable as reference URL.

**Architecture:** Single HTML file with inline CSS and JS. Left sticky sidebar (220px) with section navigation + session timer. Right: 6 full-viewport-height scroll-snap sections. Design tokens reused verbatim from `SG_IA_Propuesta_Comercial.html`. Chart.js from CDN for survey visualizations.

**Tech Stack:** Vanilla HTML/CSS/JS · Chart.js 4.4.1 CDN · Google Fonts CDN (Space Grotesk, Manrope) · No build step · No dependencies beyond CDN

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `SG_ADN_Hibrido_Sesion1.html` | CREATE | Complete standalone page |
| `SG_IA_Propuesta_Comercial.html` | READ ONLY | Design tokens reference |
| `Files/Datos_Operativos_Prueba/REVISON PUESTOS ENERO 03 2026.xlsx` | READ ONLY | Demo data for NotebookLM exercise |

---

## Task 1: Scaffold + Design Tokens + Sidebar

**Files:**
- Create: `SG_ADN_Hibrido_Sesion1.html`

- [ ] **Step 1: Create the file with head, fonts, Chart.js, and all design tokens**

Create `SG_ADN_Hibrido_Sesion1.html` with this exact content as the starting scaffold:

```html
<!DOCTYPE html>
<html lang="es" data-theme="dark-gold">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>ADN Híbrido · Sesión 1 · S&G</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=Manrope:wght@300;400;500;600;700;800&display=swap" rel="stylesheet" />
  <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
  <style>
    :root {
      --bg:           #131315;
      --bg-elevated:  #1b1b1d;
      --bg-card:      #1f1f21;
      --border:       #2a2a2e;
      --border-hover: #3a3a3f;
      --text:         #c8c8cd;
      --text-muted:   #78787e;
      --text-heading: #ededef;
      --accent:       #e6c487;
      --accent-light: #f5dfa0;
      --accent-dim:   #c9a96e;
      --danger:       #e05252;
      --success:      #52c97a;
      --info:         #5b9ef9;
      --font-heading: "Space Grotesk", sans-serif;
      --font-body:    "Manrope", sans-serif;
      --transition:   all 0.3s ease;
      --sidebar-w:    240px;
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    html { scroll-behavior: smooth; height: 100%; }

    body {
      background: var(--bg);
      color: var(--text);
      font-family: var(--font-body);
      font-size: 1rem;
      line-height: 1.75;
      display: flex;
      height: 100%;
    }

    h1,h2,h3,h4,h5,h6 { font-family: var(--font-heading); color: var(--text-heading); line-height: 1.2; }
    a { color: var(--accent); text-decoration: none; }
    strong { color: var(--text-heading); font-weight: 600; }

    /* ── SIDEBAR ───────────────────────────────────── */
    .sidebar {
      width: var(--sidebar-w);
      flex-shrink: 0;
      position: fixed;
      top: 0; left: 0; bottom: 0;
      background: var(--bg-elevated);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      padding: 28px 20px 24px;
      z-index: 100;
      overflow-y: auto;
    }

    .sidebar-logo {
      font-family: var(--font-heading);
      font-size: 13px;
      font-weight: 700;
      color: var(--accent);
      letter-spacing: 0.08em;
      margin-bottom: 6px;
    }
    .sidebar-subtitle {
      font-size: 10px;
      color: var(--text-muted);
      letter-spacing: 0.1em;
      text-transform: uppercase;
      margin-bottom: 28px;
    }

    .nav-list { list-style: none; display: flex; flex-direction: column; gap: 4px; flex: 1; }

    .nav-item a {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 10px;
      border-radius: 6px;
      font-size: 12px;
      color: var(--text-muted);
      transition: var(--transition);
      text-decoration: none;
      border-left: 2px solid transparent;
    }
    .nav-item a:hover { color: var(--text-heading); background: rgba(255,255,255,0.04); }
    .nav-item a.active {
      color: var(--accent);
      background: color-mix(in srgb, var(--accent) 10%, transparent);
      border-left-color: var(--accent);
    }

    .nav-num {
      width: 20px; height: 20px;
      border-radius: 50%;
      background: var(--bg-card);
      border: 1px solid var(--border);
      display: flex; align-items: center; justify-content: center;
      font-size: 9px; font-weight: 700;
      flex-shrink: 0;
      transition: var(--transition);
    }
    .nav-item a.active .nav-num {
      background: var(--accent);
      color: var(--bg);
      border-color: var(--accent);
    }

    .sidebar-timer {
      margin-top: 24px;
      padding-top: 20px;
      border-top: 1px solid var(--border);
    }
    .timer-label { font-size: 9px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.1em; margin-bottom: 8px; }
    .timer-bar-track { background: var(--border); border-radius: 4px; height: 4px; margin-bottom: 6px; }
    .timer-bar-fill { background: var(--accent); height: 4px; border-radius: 4px; width: 0%; transition: width 0.5s ease; }
    .timer-text { font-family: var(--font-heading); font-size: 11px; color: var(--text-muted); }

    .sidebar-times {
      margin-top: 14px;
      display: flex;
      flex-direction: column;
      gap: 3px;
    }
    .sidebar-times span {
      font-size: 9px;
      color: var(--text-muted);
    }
    .sidebar-times span.active-time { color: var(--accent); }

    /* ── MAIN CONTENT ──────────────────────────────── */
    .main {
      margin-left: var(--sidebar-w);
      flex: 1;
      overflow-y: scroll;
      scroll-snap-type: y mandatory;
      height: 100vh;
    }

    /* ── SECTIONS ──────────────────────────────────── */
    .section {
      min-height: 100vh;
      scroll-snap-align: start;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 60px 56px;
      position: relative;
    }
    .section-inner { width: 100%; max-width: 860px; }

    .section-cover   { background: linear-gradient(160deg, var(--bg) 40%, var(--bg-elevated) 100%); }
    .section-dark    { background: var(--bg-elevated); }
    .section-card    { background: var(--bg); }
    .section-accent  { background: linear-gradient(160deg, color-mix(in srgb, var(--accent) 6%, var(--bg)) 0%, var(--bg) 60%); }

    /* ── TYPOGRAPHY HELPERS ────────────────────────── */
    .label {
      display: inline-flex; align-items: center; gap: 6px;
      font-size: 10px; font-weight: 600;
      letter-spacing: 0.16em; text-transform: uppercase;
      color: var(--accent); margin-bottom: 1rem;
    }
    .accent-line { width: 48px; height: 2px; background: var(--accent); margin-bottom: 1.4rem; }
    .stat-num { font-family: var(--font-heading); font-size: 3rem; font-weight: 700; color: var(--accent); line-height: 1; }
    .stat-num.xl { font-size: 4.5rem; }
    .separator { width: 100%; height: 1px; background: var(--border); margin: 32px 0; }

    /* ── CARDS ─────────────────────────────────────── */
    .card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 24px;
      transition: var(--transition);
    }
    .card:hover { border-color: var(--border-hover); transform: translateY(-2px); box-shadow: 0 8px 30px rgba(0,0,0,0.3); }
    .card-accent { border-color: var(--accent-dim); background: color-mix(in srgb, var(--accent) 5%, var(--bg-card)); }
    .card-highlight { border-color: var(--accent); border-width: 2px; background: color-mix(in srgb, var(--accent) 8%, var(--bg-card)); }

    /* ── GRIDS ─────────────────────────────────────── */
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
    .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 18px; }
    .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; }
    .grid-split { display: grid; grid-template-columns: 1.1fr 0.9fr; gap: 32px; align-items: start; }

    /* ── BUTTONS ───────────────────────────────────── */
    .btn-primary {
      display: inline-flex; align-items: center; gap: 8px;
      padding: 12px 24px; border-radius: 4px;
      background: var(--accent); color: var(--bg);
      font-family: var(--font-heading); font-weight: 600; font-size: 13px;
      letter-spacing: 0.04em; border: none; cursor: pointer;
      transition: var(--transition); text-decoration: none;
    }
    .btn-primary:hover { background: var(--accent-light); transform: translateY(-2px); }

    /* ── FLOW DIAGRAM ──────────────────────────────── */
    .flow {
      display: flex; align-items: center; gap: 0;
      flex-wrap: wrap; margin: 20px 0;
    }
    .flow-step {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px 18px;
      font-size: 13px;
      text-align: center;
      min-width: 110px;
    }
    .flow-step .step-icon { font-size: 20px; margin-bottom: 4px; }
    .flow-step .step-label { font-size: 10px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.08em; }
    .flow-step .step-title { font-family: var(--font-heading); font-size: 12px; color: var(--text-heading); font-weight: 600; }
    .flow-arrow {
      color: var(--accent); font-size: 18px; padding: 0 8px; flex-shrink: 0;
    }

    /* ── DEMO BLOCK ────────────────────────────────── */
    .demo-prompt {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 16px 20px;
      margin: 10px 0;
      font-family: monospace;
      font-size: 13px;
      color: var(--accent);
      position: relative;
    }
    .demo-prompt::before {
      content: '▶ Pregunta a NotebookLM';
      display: block;
      font-family: var(--font-body);
      font-size: 9px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.1em;
      margin-bottom: 6px;
    }

    /* ── TABLE ─────────────────────────────────────── */
    .data-table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .data-table th {
      text-align: left; padding: 10px 14px;
      background: var(--bg-elevated); color: var(--accent);
      font-family: var(--font-heading); font-size: 11px;
      letter-spacing: 0.08em; text-transform: uppercase;
      border-bottom: 1px solid var(--border);
    }
    .data-table td { padding: 10px 14px; border-bottom: 1px solid var(--border); color: var(--text); }
    .data-table tr:last-child td { border-bottom: none; }
    .data-table tr:hover td { background: rgba(255,255,255,0.02); }

    /* ── ROI CALC ──────────────────────────────────── */
    .roi-calc {
      background: color-mix(in srgb, var(--accent) 8%, var(--bg-card));
      border: 2px solid var(--accent);
      border-radius: 12px;
      padding: 28px 32px;
      text-align: center;
    }
    .roi-result {
      font-family: var(--font-heading);
      font-size: 3.5rem;
      font-weight: 700;
      color: var(--accent);
      line-height: 1;
      margin: 12px 0 6px;
    }

    /* ── COMMITMENT INPUT ──────────────────────────── */
    .commitment-row {
      display: flex; align-items: center; gap: 12px;
      padding: 12px 0; border-bottom: 1px solid var(--border);
    }
    .commitment-num {
      width: 28px; height: 28px; border-radius: 50%;
      background: var(--accent); color: var(--bg);
      font-family: var(--font-heading); font-size: 12px; font-weight: 700;
      display: flex; align-items: center; justify-content: center;
      flex-shrink: 0;
    }
    .commitment-input {
      flex: 1; background: var(--bg-card); border: 1px solid var(--border);
      border-radius: 6px; padding: 10px 14px;
      color: var(--text-heading); font-family: var(--font-body); font-size: 13px;
    }
    .commitment-input:focus { outline: none; border-color: var(--accent); }
    .commitment-input::placeholder { color: var(--text-muted); }

    /* ── PRINT ─────────────────────────────────────── */
    @media print {
      .sidebar { display: none; }
      .main { margin-left: 0; overflow: visible; height: auto; scroll-snap-type: none; }
      .section { min-height: auto; page-break-after: always; padding: 40px; }
    }
  </style>
</head>
<body>

  <!-- ═══════════════════════════════════════════════ SIDEBAR -->
  <aside class="sidebar" id="sidebar">
    <div class="sidebar-logo">S&amp;G · ADN HÍBRIDO</div>
    <div class="sidebar-subtitle">Sesión 1 de 3 · 24 Abr 2026</div>

    <ul class="nav-list" id="navList">
      <li class="nav-item"><a href="#s0" class="active"><span class="nav-num">0</span>Portada</a></li>
      <li class="nav-item"><a href="#s1"><span class="nav-num">1</span>Diagnóstico</a></li>
      <li class="nav-item"><a href="#s2"><span class="nav-num">2</span>Cambio de Paradigma</a></li>
      <li class="nav-item"><a href="#s3"><span class="nav-num">3</span>Demo en Vivo</a></li>
      <li class="nav-item"><a href="#s4"><span class="nav-num">4</span>Liderazgo Aumentado</a></li>
      <li class="nav-item"><a href="#s5"><span class="nav-num">5</span>Cierre + ROI</a></li>
    </ul>

    <div class="sidebar-timer">
      <div class="timer-label">Progreso de sesión</div>
      <div class="timer-bar-track"><div class="timer-bar-fill" id="timerFill"></div></div>
      <div class="timer-text" id="timerText">Sección 0 de 5</div>
    </div>

    <div class="sidebar-times" id="sidebarTimes">
      <span>00:00 — Portada</span>
      <span>00:02 — Diagnóstico</span>
      <span>00:15 — Bloque 1</span>
      <span>00:30 — Demo IA</span>
      <span>01:30 — Liderazgo</span>
      <span>01:50 — Cierre</span>
    </div>
  </aside>

  <!-- ═══════════════════════════════════════════════ MAIN -->
  <main class="main" id="mainScroll">
    <!-- sections will be added in subsequent tasks -->
    <section class="section section-cover" id="s0">
      <div class="section-inner">
        <p style="color:var(--text-muted)">Sección 0 — placeholder, reemplazar en Task 2</p>
      </div>
    </section>
  </main>

  <script>
    // ── Active nav on scroll ──────────────────────────
    const mainEl = document.getElementById('mainScroll');
    const sections = document.querySelectorAll('.section');
    const navLinks = document.querySelectorAll('.nav-item a');
    const timerFill = document.getElementById('timerFill');
    const timerText = document.getElementById('timerText');

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const id = entry.target.id;
          navLinks.forEach(a => a.classList.remove('active'));
          const active = document.querySelector(`.nav-item a[href="#${id}"]`);
          if (active) active.classList.add('active');
          // Update timer bar
          const idx = Array.from(sections).indexOf(entry.target);
          const pct = (idx / (sections.length - 1)) * 100;
          timerFill.style.width = pct + '%';
          timerText.textContent = `Sección ${idx} de ${sections.length - 1}`;
        }
      });
    }, { root: mainEl, threshold: 0.5 });

    sections.forEach(s => observer.observe(s));
  </script>
</body>
</html>
```

- [ ] **Step 2: Open the file in browser and verify**

Open `SG_ADN_Hibrido_Sesion1.html` in Chrome/Edge.
Expected: Dark background, gold sidebar on the left showing all 6 nav items, placeholder text in the main area, timer bar visible at bottom of sidebar.

- [ ] **Step 3: Commit scaffold**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: scaffold ADN Hibrido session page with sidebar nav"
```

---

## Task 2: Sección 0 — Portada

**Files:**
- Modify: `SG_ADN_Hibrido_Sesion1.html` — replace the `<section id="s0">` placeholder

- [ ] **Step 1: Replace the s0 placeholder with the full portada content**

Find this in `SG_ADN_Hibrido_Sesion1.html`:
```html
    <section class="section section-cover" id="s0">
      <div class="section-inner">
        <p style="color:var(--text-muted)">Sección 0 — placeholder, reemplazar en Task 2</p>
      </div>
    </section>
```

Replace with:
```html
    <!-- ══ S0: PORTADA ══════════════════════════════ -->
    <section class="section section-cover" id="s0">
      <div class="section-inner" style="text-align:center;max-width:700px;margin:0 auto;">
        <div style="margin-bottom:40px;">
          <div style="display:inline-flex;align-items:center;gap:12px;background:var(--bg-elevated);border:1px solid var(--border);border-radius:8px;padding:10px 20px;margin-bottom:32px;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
            <span style="font-family:var(--font-heading);font-size:12px;color:var(--accent);letter-spacing:0.1em;text-transform:uppercase;font-weight:600;">Workshop · Sesión 1 de 3 · 24 Abril 2026</span>
          </div>
        </div>

        <div class="label" style="justify-content:center;">
          <svg viewBox="0 0 12 12" fill="currentColor"><circle cx="6" cy="6" r="6"/></svg>
          S&amp;G · Seguridad &amp; Gestión
        </div>

        <h1 style="font-size:clamp(2rem,5vw,3.5rem);font-weight:700;color:var(--text-heading);margin-bottom:16px;line-height:1.1;">
          ADN <span style="color:var(--accent);">Híbrido</span>
        </h1>

        <div style="width:60px;height:3px;background:var(--accent);margin:0 auto 24px;"></div>

        <p style="font-size:1.15rem;color:var(--text);max-width:560px;margin:0 auto 40px;line-height:1.7;">
          Tu equipo ya tiene las herramientas.<br>
          <strong>Hoy aprende a usarlas diferente.</strong>
        </p>

        <div style="display:inline-flex;align-items:center;gap:16px;margin-bottom:56px;">
          <div style="text-align:right;">
            <div style="font-family:var(--font-heading);font-size:14px;font-weight:600;color:var(--text-heading);">Juan M. Escandón</div>
            <div style="font-size:11px;color:var(--text-muted);">Consultor &amp; Facilitador · ADN Híbrido</div>
          </div>
          <div style="width:1px;height:36px;background:var(--border);"></div>
          <div style="text-align:left;">
            <div style="font-size:11px;color:var(--text-muted);">Duración</div>
            <div style="font-family:var(--font-heading);font-size:14px;font-weight:600;color:var(--accent);">120 minutos</div>
          </div>
        </div>

        <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:540px;margin:0 auto;">
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:8px;padding:16px 12px;text-align:center;">
            <div style="font-size:22px;margin-bottom:6px;">🧠</div>
            <div style="font-size:10px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.08em;">Bloque 1</div>
            <div style="font-size:12px;color:var(--text-heading);font-weight:600;margin-top:2px;">Paradigma</div>
          </div>
          <div style="background:var(--bg-card);border:2px solid var(--accent-dim);border-radius:8px;padding:16px 12px;text-align:center;background:color-mix(in srgb, var(--accent) 6%, var(--bg-card));">
            <div style="font-size:22px;margin-bottom:6px;">⚡</div>
            <div style="font-size:10px;color:var(--accent);text-transform:uppercase;letter-spacing:0.08em;">Bloque 2</div>
            <div style="font-size:12px;color:var(--text-heading);font-weight:600;margin-top:2px;">Demo en Vivo</div>
          </div>
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:8px;padding:16px 12px;text-align:center;">
            <div style="font-size:22px;margin-bottom:6px;">🚀</div>
            <div style="font-size:10px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.08em;">Bloque 3</div>
            <div style="font-size:12px;color:var(--text-heading);font-weight:600;margin-top:2px;">Liderazgo</div>
          </div>
        </div>

        <div style="margin-top:48px;">
          <a href="#s1" class="btn-primary">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 5v14M5 12l7 7 7-7"/></svg>
            Empecemos
          </a>
        </div>
      </div>
    </section>
```

- [ ] **Step 2: Verify in browser**

Refresh `SG_ADN_Hibrido_Sesion1.html`.
Expected: Cover slide centered with "ADN Híbrido" title in gold, 3 bloque cards at bottom, "Empecemos" button, sidebar shows Portada as active.

- [ ] **Step 3: Commit**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: add portada section with 3-bloque preview"
```

---

## Task 3: Sección 1 — Diagnóstico (Survey Data)

**Files:**
- Modify: `SG_ADN_Hibrido_Sesion1.html` — add `<section id="s1">` before `</main>`

Survey data to embed (hardcoded from xlsx analysis):
- Camilo Piedrahita: 9h/sem, Avanzado M365, Curiosidad
- Andrés Rojas: 10h/sem, Intermedio, Curiosidad
- Marco Bernal: 3h/sem, Básico, **Escepticismo**
- Aux. Operativo: 10h/sem, Intermedio, Curiosidad
- Jonathan Pedroza: 2h/sem, Intermedio, Curiosidad
- Jenifer Soache: 20h/sem, Básico, Curiosidad

- [ ] **Step 1: Add the Diagnóstico section before `</main>`**

Add this block immediately after the closing `</section>` of s0, before `</main>`:

```html
    <!-- ══ S1: DIAGNÓSTICO ══════════════════════════ -->
    <section class="section section-dark" id="s1">
      <div class="section-inner">
        <div class="label">
          <svg viewBox="0 0 12 12" fill="currentColor"><circle cx="6" cy="6" r="6"/></svg>
          Diagnóstico · Encuesta Pre-Sesión
        </div>
        <h2 style="font-size:2rem;margin-bottom:8px;">Antes de empezar,<br>revisemos lo que <span style="color:var(--accent);">ustedes mismos</span> nos contaron</h2>
        <p style="color:var(--text-muted);margin-bottom:32px;font-size:0.95rem;">6 personas respondieron · 24 de abril de 2026</p>

        <!-- Stats grid -->
        <div class="grid-4" style="margin-bottom:28px;">
          <div class="card" style="text-align:center;padding:20px 16px;">
            <div class="stat-num xl">83<span style="font-size:2rem;">%</span></div>
            <div style="font-size:11px;color:var(--text-muted);margin-top:6px;text-transform:uppercase;letter-spacing:0.08em;">curiosidad por la IA</div>
          </div>
          <div class="card card-highlight" style="text-align:center;padding:20px 16px;">
            <div class="stat-num xl">9<span style="font-size:1.5rem;color:var(--text-muted);">h</span></div>
            <div style="font-size:11px;color:var(--text-muted);margin-top:6px;text-transform:uppercase;letter-spacing:0.08em;">promedio sem. en tareas manuales</div>
          </div>
          <div class="card" style="text-align:center;padding:20px 16px;border-color:var(--danger);">
            <div class="stat-num xl" style="color:var(--danger);">20<span style="font-size:1.5rem;">h</span></div>
            <div style="font-size:11px;color:var(--text-muted);margin-top:6px;text-transform:uppercase;letter-spacing:0.08em;">caso extremo · Gest. Humana</div>
          </div>
          <div class="card" style="text-align:center;padding:20px 16px;border-color:var(--info);">
            <div class="stat-num xl" style="color:var(--info);">100<span style="font-size:2rem;">%</span></div>
            <div style="font-size:11px;color:var(--text-muted);margin-top:6px;text-transform:uppercase;letter-spacing:0.08em;">usa WhatsApp para incidentes</div>
          </div>
        </div>

        <div class="grid-split" style="gap:24px;">
          <!-- Chart -->
          <div class="card" style="padding:20px;">
            <div style="font-family:var(--font-heading);font-size:12px;color:var(--accent);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:16px;">Horas semanales en tareas manuales</div>
            <canvas id="horasChart" height="160"></canvas>
          </div>

          <!-- Top tareas tediosas -->
          <div>
            <div class="card" style="margin-bottom:12px;">
              <div style="font-family:var(--font-heading);font-size:11px;color:var(--accent);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:12px;">Tareas más tediosas por área</div>
              <div style="display:flex;flex-direction:column;gap:8px;">
                <div style="display:flex;gap:10px;align-items:flex-start;">
                  <span style="font-size:9px;background:var(--bg-elevated);color:var(--accent);border-radius:4px;padding:2px 6px;white-space:nowrap;flex-shrink:0;font-weight:600;margin-top:2px;">OPS</span>
                  <span style="font-size:12px;color:var(--text);">Verificación de puestos, seguimiento de sprints, reuniones sin información</span>
                </div>
                <div style="display:flex;gap:10px;align-items:flex-start;">
                  <span style="font-size:9px;background:var(--bg-elevated);color:var(--info);border-radius:4px;padding:2px 6px;white-space:nowrap;flex-shrink:0;font-weight:600;margin-top:2px;">COM</span>
                  <span style="font-size:12px;color:var(--text);">Correos, envío y seguimiento de propuestas</span>
                </div>
                <div style="display:flex;gap:10px;align-items:flex-start;">
                  <span style="font-size:9px;background:var(--bg-elevated);color:var(--success);border-radius:4px;padding:2px 6px;white-space:nowrap;flex-shrink:0;font-weight:600;margin-top:2px;">FIN</span>
                  <span style="font-size:12px;color:var(--text);">Registros contables, respuesta a requerimientos, revisión de pendientes</span>
                </div>
                <div style="display:flex;gap:10px;align-items:flex-start;">
                  <span style="font-size:9px;background:var(--bg-elevated);color:var(--danger);border-radius:4px;padding:2px 6px;white-space:nowrap;flex-shrink:0;font-weight:600;margin-top:2px;">RH</span>
                  <span style="font-size:12px;color:var(--text);">Certificaciones, órdenes de examen, mensajes de cumpleaños</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- WhatsApp insight -->
        <div class="card card-highlight" style="margin-top:20px;padding:20px 24px;display:flex;align-items:center;gap:20px;">
          <div style="font-size:2.5rem;flex-shrink:0;">📱</div>
          <div>
            <div style="font-family:var(--font-heading);font-size:14px;font-weight:700;color:var(--accent);margin-bottom:4px;">El 100% del equipo usa WhatsApp para gestionar incidentes críticos.</div>
            <div style="font-size:13px;color:var(--text);">Hoy vamos a diseñar el flujo que convierte ese WhatsApp en un proceso automatizado, trazable y medible.</div>
          </div>
        </div>
      </div>
    </section>
```

- [ ] **Step 2: Add Chart.js initialization for horasChart inside the `<script>` block**

Find the closing `</script>` tag and add this before it:

```javascript
    // ── Horas Chart ───────────────────────────────────
    const horasCtx = document.getElementById('horasChart');
    if (horasCtx) {
      new Chart(horasCtx, {
        type: 'bar',
        data: {
          labels: ['Camilo', 'Andrés', 'Marco', 'Aux.Op', 'Jonathan', 'Jenifer'],
          datasets: [{
            label: 'Horas/semana en tareas manuales',
            data: [9, 10, 3, 10, 2, 20],
            backgroundColor: [
              'rgba(230,196,135,0.6)',
              'rgba(230,196,135,0.6)',
              'rgba(91,158,249,0.6)',
              'rgba(230,196,135,0.6)',
              'rgba(230,196,135,0.6)',
              'rgba(224,82,82,0.7)',
            ],
            borderColor: [
              '#e6c487','#e6c487','#5b9ef9','#e6c487','#e6c487','#e05252'
            ],
            borderWidth: 1,
            borderRadius: 4,
          }]
        },
        options: {
          responsive: true,
          plugins: {
            legend: { display: false },
            tooltip: {
              callbacks: {
                label: ctx => ` ${ctx.raw}h/semana`
              }
            }
          },
          scales: {
            x: { ticks: { color: '#78787e', font: { size: 11 } }, grid: { color: '#2a2a2e' } },
            y: {
              ticks: { color: '#78787e', font: { size: 11 }, callback: v => v + 'h' },
              grid: { color: '#2a2a2e' },
              beginAtZero: true
            }
          }
        }
      });
    }
```

- [ ] **Step 3: Verify in browser**

Scroll to Diagnóstico section.
Expected: 4 stat cards (83%, 9h, 20h in red, 100% in blue), bar chart with Jenifer's bar in red, tareas por área, WhatsApp insight card with gold border.

- [ ] **Step 4: Commit**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: add diagnostico section with survey charts and WhatsApp insight"
```

---

## Task 4: Sección 2 — Bloque 1: Cambio de Paradigma

**Files:**
- Modify: `SG_ADN_Hibrido_Sesion1.html` — add `<section id="s2">` before `</main>`

- [ ] **Step 1: Add section s2 before `</main>`**

```html
    <!-- ══ S2: BLOQUE 1 — CAMBIO DE PARADIGMA ═══════ -->
    <section class="section section-card" id="s2">
      <div class="section-inner">
        <div class="label">
          <svg viewBox="0 0 12 12" fill="currentColor"><circle cx="6" cy="6" r="6"/></svg>
          Bloque 1 · 00:15 – 00:30
        </div>
        <div class="accent-line"></div>
        <h2 style="font-size:2rem;margin-bottom:8px;">La IA no viene a <span style="color:var(--danger);">reemplazarte.</span><br>Viene a <span style="color:var(--accent);">copilotar</span> contigo.</h2>
        <p style="color:var(--text-muted);margin-bottom:32px;max-width:600px;">El error más común es ver la IA como una amenaza. El ADN Híbrido propone lo contrario: una simbiosis donde la máquina amplifica tu capacidad humana.</p>

        <!-- Captain analogy -->
        <div class="card card-accent" style="margin-bottom:24px;padding:24px;">
          <div style="display:grid;grid-template-columns:1fr auto 1fr;gap:20px;align-items:center;">
            <div style="text-align:center;padding:20px;background:var(--bg-elevated);border-radius:8px;border:1px solid var(--border);">
              <div style="font-size:2.5rem;margin-bottom:8px;">🧑‍✈️</div>
              <div style="font-family:var(--font-heading);font-size:14px;font-weight:700;color:var(--text-heading);">El Capitán</div>
              <div style="font-size:12px;color:var(--accent);margin-top:4px;">TÚ · El Humano</div>
              <div style="font-size:11px;color:var(--text-muted);margin-top:8px;">Visión · Decisión estratégica · Juicio ético · Relaciones · Creatividad</div>
            </div>
            <div style="text-align:center;">
              <div style="font-size:2rem;color:var(--accent);">+</div>
            </div>
            <div style="text-align:center;padding:20px;background:var(--bg-elevated);border-radius:8px;border:1px solid var(--border);">
              <div style="font-size:2.5rem;margin-bottom:8px;">🤖</div>
              <div style="font-family:var(--font-heading);font-size:14px;font-weight:700;color:var(--text-heading);">El Copiloto</div>
              <div style="font-size:12px;color:var(--info);margin-top:4px;">LA IA · NotebookLM + M365</div>
              <div style="font-size:11px;color:var(--text-muted);margin-top:8px;">Procesa datos · Automatiza · Sintetiza · Notifica · No se cansa</div>
            </div>
          </div>
        </div>

        <!-- 4 capas -->
        <div style="margin-bottom:8px;">
          <div style="font-family:var(--font-heading);font-size:12px;color:var(--accent);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:14px;">Las 4 Capas del ADN Híbrido</div>
          <table class="data-table">
            <thead>
              <tr><th>Capa</th><th>Función</th><th>Herramienta</th></tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>Comunicación</strong></td>
                <td>Flujo de trabajo en tiempo real</td>
                <td><span style="color:var(--info);">Teams · Outlook</span></td>
              </tr>
              <tr>
                <td><strong>Datos</strong></td>
                <td>Almacenar y estructurar información operativa</td>
                <td><span style="color:var(--success);">Excel · SharePoint</span></td>
              </tr>
              <tr>
                <td><strong>Inteligencia</strong></td>
                <td>Procesar, resumir y generar insights desde documentos</td>
                <td><span style="color:var(--accent);">NotebookLM</span></td>
              </tr>
              <tr>
                <td><strong>Automatización</strong></td>
                <td>Conectar procesos, eliminar tareas repetitivas</td>
                <td><span style="color:var(--danger);">Power Automate</span></td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- NotebookLM differentiator -->
        <div class="grid-2" style="margin-top:20px;">
          <div class="card" style="border-color:var(--border);padding:18px;">
            <div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:8px;">IA Genérica (ChatGPT / Copilot)</div>
            <div style="font-size:13px;color:var(--text);">Responde desde su entrenamiento general. Puede <span style="color:var(--danger);">alucinar</span>. No conoce tus documentos.</div>
          </div>
          <div class="card card-accent" style="padding:18px;">
            <div style="font-size:11px;color:var(--accent);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:8px;">NotebookLM · Anclado en TUS datos</div>
            <div style="font-size:13px;color:var(--text);">Solo responde desde los documentos que tú le das. <strong>Cita la fuente. No inventa.</strong> Relevante para el nivel operativo.</div>
          </div>
        </div>

        <div class="separator"></div>
        <p style="font-size:1rem;color:var(--accent);font-family:var(--font-heading);font-weight:600;text-align:center;">
          "Ustedes ya tienen todo esto. Solo falta encenderlo."
        </p>
      </div>
    </section>
```

- [ ] **Step 2: Verify in browser**

Scroll to Bloque 1.
Expected: Captain/Co-pilot analogy cards side by side, 4-layer table with color-coded tools, NotebookLM vs generic AI comparison.

- [ ] **Step 3: Commit**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: add bloque 1 paradigm shift with captain analogy and 4-layer table"
```

---

## Task 5: Sección 3 — Bloque 2: Demo en Vivo + Flujo WhatsApp

**Files:**
- Modify: `SG_ADN_Hibrido_Sesion1.html` — add `<section id="s3">` before `</main>`

- [ ] **Step 1: Add section s3 before `</main>`**

```html
    <!-- ══ S3: BLOQUE 2 — DEMO EN VIVO ══════════════ -->
    <section class="section section-accent" id="s3">
      <div class="section-inner">
        <div class="label">
          <svg viewBox="0 0 12 12" fill="currentColor"><circle cx="6" cy="6" r="6"/></svg>
          Bloque 2 · 00:30 – 01:30 · El corazón de la sesión
        </div>
        <h2 style="font-size:1.9rem;margin-bottom:24px;">Mapeo de Fugas + <span style="color:var(--accent);">Demo en Vivo</span></h2>

        <div class="grid-2" style="gap:24px;margin-bottom:28px;">
          <!-- Ejercicio mapeo -->
          <div>
            <div style="font-family:var(--font-heading);font-size:12px;color:var(--accent);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:14px;">⏱ 00:30–00:50 · Ejercicio: Identifica tu fuga</div>
            <div class="card" style="padding:20px;margin-bottom:12px;">
              <div style="font-size:13px;font-weight:600;color:var(--text-heading);margin-bottom:12px;">Cada persona responde:</div>
              <div style="display:flex;flex-direction:column;gap:10px;">
                <div style="display:flex;gap:10px;">
                  <div style="width:22px;height:22px;border-radius:50%;background:var(--accent);color:var(--bg);display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;flex-shrink:0;">1</div>
                  <div style="font-size:13px;color:var(--text);">¿Cuál es la tarea que más tiempo me consume y menos valor genera?</div>
                </div>
                <div style="display:flex;gap:10px;">
                  <div style="width:22px;height:22px;border-radius:50%;background:var(--accent);color:var(--bg);display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;flex-shrink:0;">2</div>
                  <div style="font-size:13px;color:var(--text);">¿Qué información necesito para hacerla? ¿De dónde viene?</div>
                </div>
                <div style="display:flex;gap:10px;">
                  <div style="width:22px;height:22px;border-radius:50%;background:var(--accent);color:var(--bg);display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;flex-shrink:0;">3</div>
                  <div style="font-size:13px;color:var(--text);">¿Qué debería pasar cuando termine? ¿Quién necesita saber?</div>
                </div>
              </div>
            </div>
            <div class="card card-accent" style="padding:16px;">
              <div style="font-size:11px;color:var(--accent);text-transform:uppercase;letter-spacing:0.08em;margin-bottom:8px;">Plantilla de flujo</div>
              <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
                <div style="background:var(--bg-elevated);border:1px solid var(--border);border-radius:6px;padding:8px 12px;font-size:12px;text-align:center;">
                  <div style="font-size:9px;color:var(--text-muted);margin-bottom:2px;">DISPARADOR</div>
                  <div style="color:var(--text-heading);font-weight:600;">¿Qué lo inicia?</div>
                </div>
                <span style="color:var(--accent);font-size:18px;">→</span>
                <div style="background:var(--bg-elevated);border:1px solid var(--border);border-radius:6px;padding:8px 12px;font-size:12px;text-align:center;">
                  <div style="font-size:9px;color:var(--text-muted);margin-bottom:2px;">ACCIÓN IA</div>
                  <div style="color:var(--text-heading);font-weight:600;">¿Qué procesa?</div>
                </div>
                <span style="color:var(--accent);font-size:18px;">→</span>
                <div style="background:var(--bg-elevated);border:1px solid var(--border);border-radius:6px;padding:8px 12px;font-size:12px;text-align:center;">
                  <div style="font-size:9px;color:var(--text-muted);margin-bottom:2px;">RESULTADO</div>
                  <div style="color:var(--text-heading);font-weight:600;">¿Qué produce?</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Demo NotebookLM -->
          <div>
            <div style="font-family:var(--font-heading);font-size:12px;color:var(--success);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:14px;">⚡ 00:50–01:15 · Demo: NotebookLM + Datos S&amp;G</div>
            <div class="card" style="border-color:var(--success);padding:20px;margin-bottom:12px;">
              <div style="font-size:12px;color:var(--success);font-weight:600;margin-bottom:12px;">Cargar en NotebookLM: "REVISION PUESTOS 2026"</div>
              <div style="font-size:11px;color:var(--text-muted);margin-bottom:10px;">77 puestos · Genesis / Axel / Yeison · Compromisos y observaciones</div>

              <div class="demo-prompt">
                "¿Cuáles son los 3 problemas más frecuentes en nuestros puestos de vigilancia?"
              </div>
              <div class="demo-prompt">
                "¿Qué compromisos tienen fecha de cumplimiento vencida esta semana?"
              </div>
              <div class="demo-prompt">
                "¿En qué puestos existe mayor riesgo de incidente o pérdida de contrato?"
              </div>

              <div style="margin-top:14px;padding:10px 14px;background:var(--bg-elevated);border-radius:6px;border-left:3px solid var(--success);">
                <div style="font-size:11px;color:var(--success);font-weight:600;">Efecto buscado</div>
                <div style="font-size:12px;color:var(--text);margin-top:4px;">Lo que tomaría <strong>2 horas en Excel</strong> → <strong style="color:var(--accent);">10 segundos con IA</strong></div>
              </div>
            </div>
          </div>
        </div>

        <!-- WhatsApp Automation Flow -->
        <div style="font-family:var(--font-heading);font-size:12px;color:var(--info);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:14px;">📱 01:15–01:30 · Diseño del Flujo: WhatsApp → Dashboard</div>
        <div class="card" style="border-color:var(--info);padding:20px;">
          <div style="font-size:12px;color:var(--text-muted);margin-bottom:16px;">Caso de uso: El 100% usa WhatsApp para incidentes. Este flujo lo convierte en proceso trazable y automatizado con herramientas que ya tienen.</div>
          <div class="flow">
            <div class="flow-step">
              <div class="step-icon">📱</div>
              <div class="step-label">Disparador</div>
              <div class="step-title">WhatsApp<br>Incidente</div>
            </div>
            <div class="flow-arrow">→</div>
            <div class="flow-step">
              <div class="step-icon">⚡</div>
              <div class="step-label">Detecta</div>
              <div class="step-title">Power<br>Automate</div>
            </div>
            <div class="flow-arrow">→</div>
            <div class="flow-step">
              <div class="step-icon">🤖</div>
              <div class="step-label">Categoriza</div>
              <div class="step-title">IA Clasifica<br>urgente/normal</div>
            </div>
            <div class="flow-arrow">→</div>
            <div class="flow-step">
              <div class="step-icon">📋</div>
              <div class="step-label">Registra</div>
              <div class="step-title">SharePoint<br>Lista</div>
            </div>
            <div class="flow-arrow">→</div>
            <div class="flow-step">
              <div class="step-icon">🔔</div>
              <div class="step-label">Notifica</div>
              <div class="step-title">Teams al<br>responsable</div>
            </div>
            <div class="flow-arrow">→</div>
            <div class="flow-step" style="border-color:var(--accent);">
              <div class="step-icon">📊</div>
              <div class="step-label">Dashboard</div>
              <div class="step-title">Power BI<br>Actualizado</div>
            </div>
          </div>
          <div style="margin-top:14px;display:flex;gap:16px;">
            <div style="padding:8px 14px;background:var(--bg-elevated);border-radius:6px;font-size:11px;color:var(--success);">✓ Sin apps nuevas</div>
            <div style="padding:8px 14px;background:var(--bg-elevated);border-radius:6px;font-size:11px;color:var(--success);">✓ Sin inversión adicional</div>
            <div style="padding:8px 14px;background:var(--bg-elevated);border-radius:6px;font-size:11px;color:var(--accent);">⏱ ~45 min de implementación</div>
          </div>
        </div>
      </div>
    </section>
```

- [ ] **Step 2: Verify in browser**

Scroll to Demo section.
Expected: Two-column layout with exercise questions on left, NotebookLM demo prompts on right, full WhatsApp automation flow at bottom with 6 steps connected by arrows.

- [ ] **Step 3: Commit**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: add bloque 2 demo section with NotebookLM prompts and WhatsApp flow"
```

---

## Task 6: Sección 4 — Liderazgo Aumentado

**Files:**
- Modify: `SG_ADN_Hibrido_Sesion1.html` — add `<section id="s4">` before `</main>`

- [ ] **Step 1: Add section s4 before `</main>`**

```html
    <!-- ══ S4: BLOQUE 3 — LIDERAZGO AUMENTADO ═══════ -->
    <section class="section section-dark" id="s4">
      <div class="section-inner">
        <div class="label">
          <svg viewBox="0 0 12 12" fill="currentColor"><circle cx="6" cy="6" r="6"/></svg>
          Bloque 3 · 01:30 – 01:50
        </div>
        <div class="accent-line"></div>
        <h2 style="font-size:2rem;margin-bottom:12px;max-width:640px;">Si el <span style="color:var(--accent);">70%</span> de tu tiempo operativo se automatiza,<br>¿a qué lo dedicas?</h2>
        <p style="color:var(--text-muted);margin-bottom:36px;max-width:580px;">La automatización no es el objetivo. Es la llave que abre el tiempo para lo que realmente importa.</p>

        <div class="grid-3" style="margin-bottom:32px;">
          <div class="card" style="text-align:center;padding:28px 20px;">
            <div style="font-size:3rem;margin-bottom:16px;">🎯</div>
            <div style="font-family:var(--font-heading);font-size:15px;font-weight:700;color:var(--text-heading);margin-bottom:8px;">Visión Estratégica</div>
            <div style="font-size:12px;color:var(--text-muted);">Planear el 2026–2030 con datos reales, no intuición. Pivotar rápido basado en evidencia.</div>
          </div>
          <div class="card card-accent" style="text-align:center;padding:28px 20px;">
            <div style="font-size:3rem;margin-bottom:16px;">🌱</div>
            <div style="font-family:var(--font-heading);font-size:15px;font-weight:700;color:var(--text-heading);margin-bottom:8px;">Desarrollo de Personas</div>
            <div style="font-size:12px;color:var(--text-muted);">Coaching real. Feedback con contexto. Acompañar al equipo sin el ruido de lo urgente.</div>
          </div>
          <div class="card" style="text-align:center;padding:28px 20px;">
            <div style="font-size:3rem;margin-bottom:16px;">💡</div>
            <div style="font-family:var(--font-heading);font-size:15px;font-weight:700;color:var(--text-heading);margin-bottom:8px;">Innovación Profunda</div>
            <div style="font-size:12px;color:var(--text-muted);">Nuevos servicios. Nuevos clientes. Ideas que hoy no llegan porque lo operativo las bloquea.</div>
          </div>
        </div>

        <div class="separator"></div>

        <div class="grid-2" style="gap:24px;">
          <div class="card" style="padding:22px;">
            <div style="font-size:11px;color:var(--danger);text-transform:uppercase;letter-spacing:0.1em;font-weight:600;margin-bottom:10px;">La empresa que NO integra IA para 2027</div>
            <div style="display:flex;flex-direction:column;gap:8px;">
              <div style="font-size:13px;color:var(--text);display:flex;gap:8px;"><span style="color:var(--danger);">✗</span> Opera más lento que sus competidores</div>
              <div style="font-size:13px;color:var(--text);display:flex;gap:8px;"><span style="color:var(--danger);">✗</span> Toma decisiones con datos de ayer</div>
              <div style="font-size:13px;color:var(--text);display:flex;gap:8px;"><span style="color:var(--danger);">✗</span> Pierde talento que busca mejores herramientas</div>
            </div>
          </div>
          <div class="card card-accent" style="padding:22px;">
            <div style="font-size:11px;color:var(--success);text-transform:uppercase;letter-spacing:0.1em;font-weight:600;margin-bottom:10px;">El líder con ADN Híbrido</div>
            <div style="display:flex;flex-direction:column;gap:8px;">
              <div style="font-size:13px;color:var(--text);display:flex;gap:8px;"><span style="color:var(--success);">✓</span> Decide con datos en tiempo real</div>
              <div style="font-size:13px;color:var(--text);display:flex;gap:8px;"><span style="color:var(--success);">✓</span> Escala su impacto sin escalar su estrés</div>
              <div style="font-size:13px;color:var(--text);display:flex;gap:8px;"><span style="color:var(--success);">✓</span> Lidera personas, no procesos manuales</div>
            </div>
          </div>
        </div>

        <div class="separator"></div>
        <blockquote style="border-left:3px solid var(--accent);padding-left:20px;">
          <p style="font-family:var(--font-heading);font-size:1.1rem;color:var(--text-heading);font-style:italic;">"El liderazgo aumentado no es tener más datos. Es tomar mejores decisiones con ellos."</p>
          <footer style="font-size:12px;color:var(--text-muted);margin-top:8px;">— Juan M. Escandón · ADN Híbrido</footer>
        </blockquote>
      </div>
    </section>
```

- [ ] **Step 2: Verify in browser**

Scroll to Liderazgo section.
Expected: Opening question with 70% in gold, 3 cards (Visión/Personas/Innovación), comparison grid contrast/hybrid leader, closing quote with gold left border.

- [ ] **Step 3: Commit**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: add bloque 3 liderazgo aumentado with vision cards and comparison"
```

---

## Task 7: Sección 5 — Cierre + ROI

**Files:**
- Modify: `SG_ADN_Hibrido_Sesion1.html` — add `<section id="s5">` before `</main>`

ROI calculation (hardcoded from spec):
- 6 personas × 9h promedio = 54h/sem en tareas manuales
- 50% recuperadas = 27h/sem → 1,350h/año
- $25,000 COP/hora → **$33,750,000 COP/año**

- [ ] **Step 1: Add section s5 before `</main>`**

```html
    <!-- ══ S5: CIERRE + ROI ══════════════════════════ -->
    <section class="section section-cover" id="s5">
      <div class="section-inner">
        <div class="label">
          <svg viewBox="0 0 12 12" fill="currentColor"><circle cx="6" cy="6" r="6"/></svg>
          Cierre · 01:50 – 02:00
        </div>
        <h2 style="font-size:2rem;margin-bottom:8px;">Lo que esta sesión<br>vale en <span style="color:var(--accent);">números</span></h2>
        <p style="color:var(--text-muted);margin-bottom:32px;">Calculado con los datos que ustedes mismos nos dieron en la encuesta.</p>

        <!-- ROI Calc -->
        <div class="roi-calc" style="margin-bottom:28px;">
          <div style="font-size:12px;color:var(--text-muted);margin-bottom:8px;">6 personas × 9h promedio = 54h/sem · 50% automatizadas = 27h/sem recuperadas</div>
          <div style="font-size:13px;color:var(--text-muted);">27h/sem × 50 semanas × $25.000 COP/h</div>
          <div class="roi-result">$33.750.000</div>
          <div style="font-size:14px;color:var(--accent);font-weight:600;">COP / año en productividad recuperada</div>
          <div style="font-size:11px;color:var(--text-muted);margin-top:8px;">Con una sola automatización. Sin apps nuevas. Sin inversión adicional.</div>
        </div>

        <div class="grid-2" style="gap:24px;margin-bottom:28px;">
          <!-- Compromisos -->
          <div>
            <div style="font-family:var(--font-heading);font-size:12px;color:var(--accent);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:14px;">Compromisos de la sesión</div>
            <div class="card" style="padding:20px;">
              <p style="font-size:12px;color:var(--text-muted);margin-bottom:16px;">Cada participante define 1 automatización a implementar esta semana:</p>
              <div class="commitment-row">
                <div class="commitment-num">1</div>
                <input class="commitment-input" type="text" placeholder="Tu automatización (ej: flujo WhatsApp → SharePoint)">
              </div>
              <div class="commitment-row">
                <div class="commitment-num">2</div>
                <input class="commitment-input" type="text" placeholder="Área / proceso">
              </div>
              <div class="commitment-row" style="border-bottom:none;">
                <div class="commitment-num">3</div>
                <input class="commitment-input" type="text" placeholder="Fecha de implementación">
              </div>
            </div>
          </div>

          <!-- Próximos pasos -->
          <div>
            <div style="font-family:var(--font-heading);font-size:12px;color:var(--accent);text-transform:uppercase;letter-spacing:0.1em;margin-bottom:14px;">Próximos pasos</div>
            <div class="card card-accent" style="padding:20px;margin-bottom:12px;">
              <div style="font-size:11px;color:var(--accent);text-transform:uppercase;letter-spacing:0.08em;margin-bottom:6px;">Sesión 2 — Optimización de Procesos</div>
              <div style="font-size:13px;color:var(--text);">Profundidad técnica en Power Automate. Flujos completos. Integración con SharePoint y Teams.</div>
            </div>
            <div class="card" style="padding:20px;">
              <div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.08em;margin-bottom:6px;">Sesión 3 — Liderazgo y Visión</div>
              <div style="font-size:13px;color:var(--text);">Dashboards de liderazgo. Análisis de sentimientos. Simulación de escenarios 2026–2030.</div>
            </div>
          </div>
        </div>

        <!-- Closing -->
        <div class="separator"></div>
        <div style="text-align:center;padding:20px 0;">
          <p style="font-size:0.95rem;color:var(--text-muted);margin-bottom:16px;">Comparte esta página con tu equipo · es la referencia de la sesión</p>
          <div style="display:inline-flex;align-items:center;gap:16px;padding:14px 24px;background:var(--bg-card);border:1px solid var(--border);border-radius:8px;">
            <div style="font-size:1.8rem;">📎</div>
            <div style="text-align:left;">
              <div style="font-size:10px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.1em;">Recurso de sesión</div>
              <div style="font-family:var(--font-heading);font-size:13px;color:var(--accent);font-weight:600;">ADN Híbrido · Sesión 1 · S&amp;G 2026</div>
            </div>
          </div>
          <div style="margin-top:28px;">
            <p style="font-family:var(--font-heading);font-size:1.3rem;color:var(--text-heading);">Hoy fue <span style="color:var(--accent);">la punta del iceberg.</span></p>
            <p style="font-size:0.9rem;color:var(--text-muted);margin-top:6px;">Juan M. Escandón · Consultor ADN Híbrido</p>
          </div>
        </div>
      </div>
    </section>
```

- [ ] **Step 2: Verify in browser**

Scroll to Cierre section.
Expected: Gold ROI box showing $33.750.000 COP, commitment input fields, 2 next session cards, closing statement "la punta del iceberg".

- [ ] **Step 3: Commit**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: add cierre section with ROI calc and commitment inputs"
```

---

## Task 8: Polish — Navegación, Smooth Scroll y Print

**Files:**
- Modify: `SG_ADN_Hibrido_Sesion1.html` — fix nav scroll behavior and add keyboard navigation

- [ ] **Step 1: Update the JavaScript to fix nav link scroll into mainEl**

The sidebar nav links (`href="#s0"` etc.) by default scroll the document. Since `.main` is the scrollable container, the links must scroll `mainEl` instead. Find the closing `</script>` and add before it:

```javascript
    // ── Sidebar nav click → scroll within mainEl ──────
    document.querySelectorAll('.nav-item a').forEach(link => {
      link.addEventListener('click', e => {
        e.preventDefault();
        const target = document.querySelector(link.getAttribute('href'));
        if (target) target.scrollIntoView({ behavior: 'smooth' });
      });
    });

    // ── Keyboard: ArrowDown/ArrowUp to jump sections ──
    document.addEventListener('keydown', e => {
      const active = document.querySelector('.nav-item a.active');
      if (!active) return;
      const items = Array.from(document.querySelectorAll('.nav-item a'));
      const idx = items.indexOf(active);
      if (e.key === 'ArrowDown' && idx < items.length - 1) {
        e.preventDefault();
        items[idx + 1].click();
      }
      if (e.key === 'ArrowUp' && idx > 0) {
        e.preventDefault();
        items[idx - 1].click();
      }
    });
```

- [ ] **Step 2: Verify keyboard navigation**

Open the file, click anywhere in the page, press ArrowDown repeatedly.
Expected: Page scrolls section by section, sidebar nav item updates to gold highlight on each section.

- [ ] **Step 3: Verify print layout**

Press Ctrl+P in Chrome.
Expected: Print preview shows sidebar hidden, each section on its own page, dark backgrounds preserved.

- [ ] **Step 4: Final commit**

```bash
git add SG_ADN_Hibrido_Sesion1.html
git commit -m "feat: add keyboard navigation and print layout for ADN Hibrido session page"
```

---

## Self-Review Checklist

- [x] **Spec coverage:**
  - Portada ✓ (Task 2)
  - Diagnóstico con datos reales encuesta ✓ (Task 3)
  - Chart.js horas semanales ✓ (Task 3)
  - WhatsApp insight ✓ (Task 3)
  - Bloque 1 paradigma + 4 capas ✓ (Task 4)
  - NotebookLM vs genérica ✓ (Task 4)
  - Ejercicio mapeo fugas ✓ (Task 5)
  - Demo NotebookLM con 3 preguntas reales ✓ (Task 5)
  - Flujo WhatsApp→Dashboard ✓ (Task 5)
  - Liderazgo aumentado ✓ (Task 6)
  - ROI $33.750.000 COP ✓ (Task 7)
  - Commitment inputs ✓ (Task 7)
  - Print CSS ✓ (Task 8)
  - Keyboard nav ✓ (Task 8)

- [x] **No placeholders:** All code blocks are complete and runnable.

- [x] **Type consistency:** CSS class names consistent across all tasks (`card`, `card-accent`, `card-highlight`, `flow`, `flow-step`, `demo-prompt`, `data-table`, `roi-calc`, `commitment-row`, `commitment-input`).

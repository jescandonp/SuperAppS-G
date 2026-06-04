---
name: Sentinel Enterprise
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#43474f'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#737780'
  outline-variant: '#c3c6d1'
  surface-tint: '#3a5f94'
  primary: '#001e40'
  on-primary: '#ffffff'
  primary-container: '#003366'
  on-primary-container: '#799dd6'
  inverse-primary: '#a7c8ff'
  secondary: '#765b00'
  on-secondary: '#ffffff'
  secondary-container: '#ffc703'
  on-secondary-container: '#6e5400'
  tertiary: '#1e1e1e'
  on-tertiary: '#ffffff'
  tertiary-container: '#333333'
  on-tertiary-container: '#9d9b9b'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d5e3ff'
  primary-fixed-dim: '#a7c8ff'
  on-primary-fixed: '#001b3c'
  on-primary-fixed-variant: '#1f477b'
  secondary-fixed: '#ffdf94'
  secondary-fixed-dim: '#f5bf00'
  on-secondary-fixed: '#251a00'
  on-secondary-fixed-variant: '#594400'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1b1b1c'
  on-tertiary-fixed-variant: '#474746'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
  status-success: '#107C10'
  status-warning: '#D83B01'
  status-error: '#A4262C'
  status-info: '#0078D4'
  surface-border: '#E1E4E8'
typography:
  display-lg:
    fontFamily: Montserrat
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Montserrat
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-md:
    fontFamily: Montserrat
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Montserrat
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
  headline-lg-mobile:
    fontFamily: Montserrat
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 4px
  gutter: 24px
  margin-desktop: 40px
  margin-mobile: 16px
  container-max-width: 1440px
---

## Brand & Style

The design system is engineered for a high-security Enterprise SaaS environment. The brand personality is **authoritative, secure, and meticulous**. It balances the weight of a traditional security firm with the streamlined efficiency of modern cloud software.

The visual style is **Corporate / Modern** with a focus on high-density information management. It employs a "safety-first" aesthetic: large amounts of white space to prevent cognitive overload, razor-sharp alignment to convey precision, and a restrained use of vibrant accents to highlight critical data points and system status.

## Colors

The palette is anchored by a **Deep Corporate Blue** (`#003366`), selected to evoke trust and institutional stability. The **Extracted Gold** (`#FFC700`) is utilized strictly as an action-oriented accent—used for primary calls-to-action and warning-level indicators to ensure they command immediate attention.

The UI relies heavily on a "layered white" approach. Surfaces use a range of near-whites and light greys to define content boundaries without the use of heavy lines. 

**Status Indicators:**
- **Success:** Deep emerald for positive validation.
- **Warning:** Burnt orange (distinct from the brand gold) for cautionary states.
- **Error:** High-contrast crimson for critical failures.

## Typography

This design system utilizes a dual-font strategy to balance brand impact with data legibility. 

**Montserrat** is reserved for headlines and prominent brand moments. Its geometric construction provides a modern, professional structure. 

**Inter** is the workhorse for all functional UI elements, including body text, data tables, and input fields. Inter’s tall x-height and exceptional legibility make it ideal for the high-density dashboards typical of an Enterprise portal.

- Use **uppercase labels** with slight letter spacing for category headers and table columns to create clear visual hierarchy.
- For numerical data in tables, ensure the use of tabular lining figures where available.

## Layout & Spacing

The layout follows a **Fixed-Fluid Hybrid Grid**. On desktop, the main content area is capped at 1440px to maintain readability, centered within the viewport. 

- **Grid System:** A 12-column grid is used for dashboard layouts. 
- **Spacing Rhythm:** All spacing is derived from a 4px base unit. 
    - Use **24px (gutter)** for standard separation between cards.
    - Use **16px** for internal padding within standard components.
    - Use **40px** for vertical section spacing.

**Responsive Behavior:**
- **Desktop (1024px+):** 12 columns, 40px margins. Side navigation is persistent.
- **Tablet (768px - 1023px):** 8 columns, 24px margins. Navigation collapses into a rail.
- **Mobile (Up to 767px):** 4 columns, 16px margins. Navigation moves to a bottom bar or hamburger menu.

## Elevation & Depth

To maintain a "secure and grounded" feel, the design system avoids heavy shadows in favor of **Tonal Layers and Low-Contrast Outlines**.

Depth is communicated through surface color shifts rather than physical distance:
1.  **Level 0 (Background):** `#F8F9FA` (Neutral light grey).
2.  **Level 1 (Cards/Content):** `#FFFFFF` (Pure white) with a 1px border of `#E1E4E8`.
3.  **Level 2 (Dropdowns/Modals):** `#FFFFFF` with a very soft, diffused shadow (`0px 4px 12px rgba(0,0,0,0.05)`).

This flat approach ensures the UI remains performant and looks professional on all display types, emphasizing content over decoration.

## Shapes

The design system uses a **Soft (0.25rem)** roundedness profile. This subtle rounding softens the industrial nature of the enterprise software while maintaining a crisp, disciplined look. 

- **Small Components:** Buttons, checkboxes, and input fields use `0.25rem` (4px).
- **Container Elements:** Large cards and dashboard widgets use `0.5rem` (8px).
- **Interactive States:** On hover, focus rings should follow the component's border radius exactly, with a 2px offset.

## Components

### Buttons
- **Primary:** Background `#FFC700`, Text `#1F1F1F`, Bold weight. High contrast for critical actions.
- **Secondary:** Background `#003366`, Text `#FFFFFF`. For standard portal actions.
- **Ghost:** Transparent background, Border `#E1E4E8`, Text `#003366`. For low-priority navigation.

### Input Fields
- Use a white background with a subtle `#E1E4E8` border. 
- Labels must always be visible (never use placeholder text as a label).
- Focus state: Border changes to `#003366` with a soft blue outer glow.

### Status Chips
- Small, rounded-pill indicators with a background opacity of 15% of the status color and 100% opacity for the text. 
- Example: "Active" would have a light green background and dark green text.

### Data Tables
- Header row: Light grey background (`#F8F9FA`), Uppercase labels.
- Rows: White background with a single-pixel bottom border.
- Hover state: Row background shifts to a very faint blue tint to aid row tracking.

### Cards
- Use for dashboard widgets. Must include a consistent header section with a 1px bottom divider and a `headline-sm` title.
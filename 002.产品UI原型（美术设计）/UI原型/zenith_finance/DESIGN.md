---
name: Zenith Finance
colors:
  surface: '#f8f9ff'
  surface-dim: '#ccdbf4'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d4e4fc'
  on-surface: '#0d1c2e'
  on-surface-variant: '#414750'
  inverse-surface: '#223144'
  inverse-on-surface: '#eaf1ff'
  outline: '#727782'
  outline-variant: '#c1c7d2'
  surface-tint: '#1960a3'
  primary: '#005394'
  on-primary: '#ffffff'
  primary-container: '#2b6cb0'
  on-primary-container: '#e1ecff'
  inverse-primary: '#a2c9ff'
  secondary: '#006d40'
  on-secondary: '#ffffff'
  secondary-container: '#8ef5b5'
  on-secondary-container: '#007243'
  tertiary: '#a70819'
  on-tertiary: '#ffffff'
  tertiary-container: '#ca2a2e'
  on-tertiary-container: '#ffe6e3'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d3e4ff'
  primary-fixed-dim: '#a2c9ff'
  on-primary-fixed: '#001c38'
  on-primary-fixed-variant: '#004881'
  secondary-fixed: '#91f8b8'
  secondary-fixed-dim: '#74db9d'
  on-secondary-fixed: '#002110'
  on-secondary-fixed-variant: '#00522f'
  tertiary-fixed: '#ffdad7'
  tertiary-fixed-dim: '#ffb3ad'
  on-tertiary-fixed: '#410004'
  on-tertiary-fixed-variant: '#930013'
  background: '#f8f9ff'
  on-background: '#0d1c2e'
  surface-variant: '#d4e4fc'
  bg-page: '#F7FAFC'
  bg-card: '#FFFFFF'
  primary-light: '#EBF4FF'
  warning-orange: '#ED8936'
  text-primary: '#1A202C'
  divider: '#E2E8F0'
  cat-blue: '#4299E1'
  cat-pink: '#ED64A6'
  cat-purple: '#805AD5'
  cat-teal: '#319795'
  cat-brown: '#8B6E4E'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 24px
  caption-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  display-lg-mobile:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 40px
---

## Brand & Style

The design system is anchored in the concept of "Financial Clarity through Minimalism." It aims to transform the often-stressful task of personal accounting into a calm, frictionless ritual. The personality is professional and secure, yet approachable enough for daily use.

The visual direction follows a **Modern Corporate** style with a heavy emphasis on **Minimalism**. The interface utilizes generous whitespace to reduce cognitive load, allowing financial figures to stand out as the primary focal point. Depth is achieved through subtle tonal layering rather than aggressive shadows, maintaining a "lightweight" feel consistent with the product's name. The overall aesthetic should evoke the precision of a Swiss bank combined with the friendliness of a modern productivity tool.

## Colors

This design system employs a "Functional Color" logic where every hue serves a specific informational purpose. 

- **Primary Blue** (#2B6CB0) is the anchor for trust, used for core navigation and primary actions.
- **Success Green** (#38A169) is strictly reserved for income and positive financial growth.
- **Danger Red** (#E53E3E) is used for expenses and critical alerts.
- **Warning Orange** (#ED8936) denotes budget thresholds and mid-level alerts.

Backgrounds utilize an off-white base (#F7FAFC) to differentiate the canvas from the pure white (#FFFFFF) functional cards. The category palette provides high-saturation accents to ensure icons are quickly recognizable during rapid entry.

## Typography

The system utilizes a dual-font approach to balance readability and numerical precision. **Inter** is the workhorse for all UI labels, body text, and headings, chosen for its neutral tone and exceptional legibility. 

A monospaced font (**JetBrains Mono**) is specifically mandated for all financial values (`label-mono`). This ensures that decimal points and digits align vertically in lists, allowing users to scan and compare costs rapidly. High-level headings use tight letter-spacing to maintain a modern, "tucked-in" look.

## Layout & Spacing

The layout is based on a **Fluid Grid** system that prioritizes thumb-reachability for mobile users. A strict 4px baseline grid governs all spacing increments.

- **Mobile**: Uses a single-column layout with 16px side margins. The Floating Action Button (FAB) is positioned in the bottom-right for the primary entry trigger.
- **Desktop/Tablet**: Content is constrained to a max-width container, centering the "Card" modules.
- **Information Density**: Daily transactions are grouped with date headers, using 8px spacing between items and 24px between date groups to ensure a clear visual rhythm.

## Elevation & Depth

Hierarchy is established through **Tonal Layers** and extremely **Ambient Shadows**. 

1.  **Level 0 (Base)**: The Page Background (#F7FAFC) serves as the floor.
2.  **Level 1 (Cards)**: Pure white surfaces with a 1px border (#E2E8F0) or a soft, diffused shadow (Blur: 12px, Y: 4px, Opacity: 4%) to separate from the background.
3.  **Level 2 (Overlays)**: Bottom Sheets and Modals use a semi-transparent dark mask (60% opacity) behind them to focus user attention. 
4.  **Floating Elements**: The FAB utilizes a higher elevation shadow (Blur: 16px, Y: 6px, Opacity: 15%) tinted with the Primary Blue to denote its priority.

## Shapes

The shape language is consistently **Rounded**, reflecting the "simple and friendly" brand personality. 

- Standard components (Buttons, Input fields) use a **0.5rem (8px)** radius.
- Container modules (Cards, Bottom Sheets) use a more pronounced **1rem (16px)** radius for a modern, tactile feel.
- Transaction category icons are rendered as circles or highly rounded squircles to differentiate them from functional UI buttons.

## Components

### Buttons
Primary buttons use the Primary Blue with white text. Ghost buttons use a 1px divider border. Success and Danger buttons are used specifically for "Add Income" and "Add Expense" actions respectively.

### Cards
Cards are the primary data container. They must have a white background, 16px rounded corners, and 16px internal padding. Lists within cards are separated by hairline dividers (#E2E8F0).

### Input Fields
Inputs are minimal: a simple bottom border or a subtle light-gray background. Upon focus, the border transitions to Primary Blue.

### Bottom Sheet
The core "Quick Record" interface. It slides from the bottom, covering 70% of the screen. It features an 8-column grid for category icons and a large, monospaced numeric input area.

### Chips/Tabs
Used for switching between "Income" and "Expense." Active states use the `primary-light` background with primary-colored text to maintain high contrast without visual heaviness.
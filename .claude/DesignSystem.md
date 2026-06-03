# FocusFlight — Design System

> A focus-timer app reimagined as a real-time flight experience.
> Every screen must feel **premium, minimal, Apple-like, and cinematic.**
> Calm and focused — never busy. When in doubt, remove something.
> *One thousand no's for every yes.*

---

## Voice & Mood

- Quiet confidence. No hype, no exclamation marks, no celebration confetti.
- Aviation framing throughout: sessions are "flights," focus styles are "seats," finishing is "landing." Keep the metaphor consistent but understated.
- Copy is short, plain, human. Sentence case.
  - e.g. `"Welcome to Phetchabun"` · `"Focus locked for 31:00."`

---

## Canonical Journey

> Keep these details **identical** across all screens — never improvise.

```
Home (route search)
  → Seat (focus style)
  → Boarding Pass / Check-in (animated tear)
  → Live Flight (Map / Window / Tail)
  → Landing (arrival summary)
```

### Fixed Facts — do not change unless explicitly asked

| Field | Value |
|---|---|
| Route | **VTE (Vientiane) → PHY (Phetchabun)** |
| Duration | **31 min** |
| Distance | **206 km** |
| Seat | **09F** |
| Date | **2026/05/31** |
| Status bar | iOS — time, airplane-mode, wifi, battery |
| Badge | **LIVE FLIGHT** where relevant |

---

## Color Palette

> Dark only. One accent — warm amber. Never introduce new hues; derive with `oklch()` if needed.

### Surface Tokens

| Token | Value | Use |
|---|---|---|
| `--surf-0` | `#000000` | Device black / true black |
| `--surf-1` | `#0c0d10` | App background |
| `--surf-2` | `#131519` | Raised panels, spec cards |
| `--surf-3` | `#191c22` | Controls, back buttons |
| `--card`   | `#16181d` | Cards, passes |
| `--glass`  | `rgba(20,22,27,.62)` | Blurred overlays — always pair with `backdrop-filter: blur()` |

### Border / Hairline Tokens

| Token | Value | Use |
|---|---|---|
| `--hair`   | `rgba(255,255,255,.09)` | Hairline borders (default) |
| `--hair-2` | `rgba(255,255,255,.16)` | Stronger hairlines |

### Text Tokens

| Token | Value | Use |
|---|---|---|
| `--tx-1` | `#f6f7f9` | Primary text (high contrast white) |
| `--tx-2` | `rgba(255,255,255,.60)` | Secondary text |
| `--tx-3` | `rgba(255,255,255,.38)` | Tertiary / labels |

### Accent Tokens

| Token | Value | Use |
|---|---|---|
| `--amber`      | `#F6A93B` | Primary accent |
| `--amber-2`    | `#FFC267` | Accent highlight / gradient top |
| `--amber-soft` | `rgba(246,169,59,.16)` | Accent glow, selected rings |

### Accent Rules

- Amber = the **one** primary action or live element per view (selected seat, plane marker, primary CTA, LIVE dot).
- White CTAs for neutral primary actions.
- Amber gradient `linear-gradient(180deg, --amber-2, --amber)` for the boarding / launch moment **only**.

---

## Typography

| Role | Stack |
|---|---|
| Display / UI | `-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", system-ui, sans-serif` |
| Mono (tickets, times, coords) | `ui-monospace, "SF Mono", Menlo, monospace` |

### Type Rules

- Display weights: **600–700**, tight tracking (`letter-spacing: -.02em` to `-.03em`) on big numbers and headlines.
- Labels: **10–11px**, uppercase, `letter-spacing: .10–.16em`, color `--tx-3`.
- Minimums: never below ~12px. Airport codes and timers must be **large and confident**.

---

## Shape, Depth & Spacing

| Property | Value |
|---|---|
| Card radius | `30px` (`--r-card`) |
| Panel radius | `20–24px` |
| Chip radius | `11–14px` |
| Pill radius | `999px` |
| Card shadow | `0 40px 90px -28px rgba(0,0,0,.78)` |
| Touch targets | ≥ 44px |

- Soft, deep shadows only — no hard edges.
- Generous negative space at all times.
- Glass surfaces = blur + thin `--hair-2` border, never a solid fill.

---

## Components

### Pill CTA
- Height: **58px**, `--r-pill` radius.
- Default: white background (`#fff`) with `#0a0b0d` text.
- Board / Launch moment: amber gradient fill.

### Boarding Pass
- Body: matte `--card`.
- Dashed perforation line, two notch holes punched at edges.
- Barcode: light `#e9eaed` bars, mono ticket number.
- **Tear animation**: barcode stub rotates `~-8°` + map dims to black on confirm.

### Seat Map
- Real cabin shape (rounded nose). Columns `A–F` with center aisle.
- **Window = Deep Work · Aisle = Flexible · Middle = Collaborative**
- Window seats: amber inset ring.
- Selected: amber gradient fill.
- Taken: `#0e0f12`.

### Live HUD
- Glass console or minimal scrim variant.
- Always include **Map / Window / Tail** segmented toggle.
- Scrubber with plane-icon knob to preview the 31-min session.

### LIVE Badge / Chip
- Blurred dark pill, pulsing amber dot, `white-space: nowrap`.

---

## Maps & Imagery

- Dark satellite / terrain backgrounds with a vertical gradient scrim to keep text legible.
- Route: thin white path — dashed for "remaining," solid amber for "flown."
- Endpoint dots: origin = white ring, destination = amber ring.
- Cabin views (window / tail): use **real photography** — never SVG aircraft illustrations.

---

## Layout & Engineering Conventions

- Portrait screens in iPhone frames; gallery lays frames in labeled sections on a dark canvas.
- Flex / grid with `gap` for any sibling row — not inline flow or per-element margins.
- Canonical HTML: explicit closing tags, quoted attributes.
- File split:
  - `styles.css` — system + frames
  - `screens.css` — flow screens
  - `live.css` — live flight + landing
  - `app.js` — behavior

---

## Avoid

| Anti-pattern | Reason |
|---|---|
| Gradient-soup backgrounds | Breaks the matte, cinematic feel |
| Emoji anywhere | Kills the quiet confidence tone |
| Rounded-card-with-left-accent-bar | Cliché UI pattern |
| Inter / Roboto | Not premium enough — use SF Pro |
| Multiple accent colors | Amber is the only accent — ever |
| Filler stats / sections | Premium = restraint |
| Anything loud | If it draws attention to itself, remove it |

---

*Design System for **Visual FocusFlight** — Flutter + GetX · Dark · Amber · Cinematic · 2026*

---
name: frontend-design
description: "Flutter + mobile UI design assistant for this project. Generates premium screens, widgets, and animations following the FocusFlight design system (dark, amber, cinematic). Pass a screen name or component to build. Examples: /frontend-design login screen, /frontend-design seat selection card, /frontend-design home dashboard"
---

# Frontend Design — FocusFlight Flutter UI

You are a senior Flutter UI engineer and mobile design specialist for the **FocusFlight** app.

## Project Design System

Always follow `.claude/DesignSystem.md` (read it first if needed). Key rules:

- **Dark only** — `#0C0D10` background, never white backgrounds
- **One accent** — amber `#F6A93B` / `#FFC267` only. Never introduce new hues.
- **Premium, minimal, Apple-like, cinematic** — restraint over feature richness
- **Aviation metaphor** — flights, seats, boarding, landing
- **Sentence case copy** — never ALL CAPS headlines, never exclamation marks

## Color Tokens (use AppColors.*)

```dart
surf0 = #000000  surf1 = #0C0D10  surf2 = #131519
card  = #16181D  surf3 = #191C22
tx1   = #F6F7F9  tx2   = 60% white  tx3 = 38% white
amber = #F6A93B  amber2 = #FFC267  amberSoft = 16% amber
hair  = 9% white  hair2 = 16% white
```

## Architecture Rules

- MVVM + GetX — views in `lib/app/views/`, controllers in `lib/app/controllers/`
- Every screen is `GetView<XController>` or `StatefulWidget` when animation-only
- Reusable widgets go in `lib/app/widgets/`
- Routes declared in `lib/app/routes/app_pages.dart`

## UI Quality Checklist (apply before output)

- [ ] Touch targets ≥ 44px
- [ ] No raw hex — use AppColors tokens
- [ ] Amber is the ONLY accent (never add blue, green, red)
- [ ] Entry animation (fade + slide) on new screens
- [ ] Animated border on text field focus (hair → amber)
- [ ] Press-scale (0.97) on primary buttons
- [ ] SafeArea + resizeToAvoidBottomInset on all screens
- [ ] `const` constructors where possible

## What to Build

Build the Flutter widget or screen described in `$ARGUMENTS`.

1. Read the DesignSystem.md for the specific screen context
2. Run a quick UI/UX search if needed:
   ```bash
   python3 .claude/skills/ui-ux-pro-max/scripts/search.py "$ARGUMENTS mobile dark premium" --design-system
   python3 .claude/skills/ui-ux-pro-max/scripts/search.py "$ARGUMENTS" --stack flutter
   ```
3. Generate complete, production-ready Dart code
4. Include animations where appropriate
5. No placeholder TODOs — deliver complete implementation

Output only the Dart file(s). No explanation unless asked.

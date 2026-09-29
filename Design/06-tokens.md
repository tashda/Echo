# Tokens

Values that views use. The code equivalents live in `Echo/Sources/Shared/DesignSystem/` (`SpacingToken.swift`, `LayoutToken.swift`, `ColorToken.swift`, `TypographyToken.swift`). If a number or colour isn't here or in those files, add it as a token first.

## Spacing scale (existing)

2 · 4 · 6 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64 pt (`SpacingTokens`).

## Window and cards

| Token | Value | Status |
|---|---|---|
| Canvas | `windowBackgroundColor` (grey), translucent alternative | Decided |
| Card fill | `textBackgroundColor` | Decided |
| Card corner | 16pt, continuous (`cardCornerRadius`); the Card Corners setting: 10 / 12 / 16 / 20 / 26pt, read via `\.workspaceCardCornerRadius` | Decided |
| Card shadow | Floating: black 12%, radius 10, y 4, plus a 0.5pt separator edge at 35% | Decided |
| Gutter between panes | 6pt default; setting offers 4 / 6 / 8pt | Decided |

## Rail

| Token | Value | Status |
|---|---|---|
| Item size | 34pt (medium); small 28, large 40 | Decided |
| Item spacing | 4pt | Decided (as in the Design Lab) |
| Pill padding | 4pt | Decided (as in the Design Lab) |
| Rail width | item + 2 × padding (42pt at medium) | Decided (as in the Design Lab) |
| Gap between pills | at least 12pt | Decided (as in the Design Lab) |
| Selection disc | `textBackgroundColor` + shadow 16%, radius 1.5, liquid stretch, inset 3pt inside its item | Decided |
| Selected monogram | the server's connection colour, bold | Decided |

## Tree

| Token | Value | Status |
|---|---|---|
| Server card | the editor card's tokens: `textBackgroundColor`, 12pt corners, 0.5pt edge at 35%, `workspaceCard` shadow | Decided |
| Server card spacing | 4pt below the last row; the gutter setting between cards | Decided |
| Density | compact / small / default / large (see `SidebarRow`) | Decided |
| Indent per level | 14pt (`SidebarRowConstants.indentStep`) | Decided (S1) |
| Row corner | 8pt (`LayoutTokens.Workspace.treeRowCornerRadius`) | Decided (S1) |
| Row slot | 20 / 23 / 27 / 34pt by density; the row is about 1pt shorter | Decided (S1) |
| Chevron | 9pt bold, quaternary (`SidebarRowConstants.chevronFont`) | Decided (S1) |
| Icon | 13pt hierarchical at the default density | Decided (S1) |
| Section heading | 11pt semibold secondary, 4pt extra above (`treeSectionTopPadding`) | Decided (S1) |
| Server header | 13pt bold primary; product and version 11pt tertiary | Decided (S1) |
| Selection fill | the row's accent at 18%, 30% with Increase Contrast (`Sidebar.selectedTintOpacity`) | Decided (S1; replaces the grey fill) |

## Floating surfaces

| Token | Value | Status |
|---|---|---|
| Widths | 260 · 320 · 420pt | Leaning |
| Padding | 12pt | Leaning |
| Card corner | 18pt | Leaning |
| Row height / corner | 28pt / 10pt | Leaning |

## Motion

| Token | Value | Status |
|---|---|---|
| House spring | `.bouncy(duration: 0.45, extraBounce: 0.08)` | Decided |
| Fast speed | durations × 0.7 | Decided |
| Hover / press | 0.12–0.16s ease-out | Decided |
| Reduce Motion | 0.18s ease-in-out, no bounce, no pulse | Decided |
| Connecting pulse | opacity 1.0 ↔ 0.15 with scale 1.0 ↔ 0.9, 0.7s each way (the first 1.0 ↔ 0.3 was too subtle) | Decided |

## Colour

- Use semantic system colours (`labelColor`, `secondaryLabelColor`, `separator`, `textBackgroundColor`, `.primary.opacity(…)`), so Increase Contrast and dark mode work. *Decided.*
- No literal `Color.white` / `Color.black` / `Color(white:)` in views. The tab strip and a few tree fills still do this and must move to tokens. *Decided.*
- The accent follows the setting (system, connection colour or custom). *Decided.*

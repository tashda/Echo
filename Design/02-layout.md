# Layout: canvas and cards

Echo does not use the system sidebar for the Explorer. The window is our own shell, inspired by Outlook's Mac layout but built with native materials. *Decided.*

```
┌ window ──────────────────────────────────────────────────────────┐
│ ● ● ●                         toolbar (system glass groups)      │
│ ╭──╮                  ╭ tab strip ─────────────────╮             │
│ │18│  postgres18      ╰────────────────────────────╯             │
│ │TI│   › Databases    ╭ editor card ───────────────────────────╮ │
│ │16│     › employees  │                                        │ │
│ ╰──╯       Tables  6  ╰────────────────────────────────────────╯ │
│            ...        ╭ results card ──────────────────────────╮ │
│ ╭──╮                  │                                        │ │
│ │▢ │                  │                                        │ │
│ │◷ │                  ├ footer ────────────────────────────────┤ │
│ ╰──╯                  ╰────────────────────────────────────────╯ │
└──────────────────────────────────────────────────────────────────┘
  rail   tree on canvas            cards on canvas         inspector →
```

## Canvas

- **Default: system grey** (`windowBackground`). *Decided.*
- **Alternative: translucent** (behind-window blur). It is kept in mind during development and may become a setting. *Decided.*
- **Dark mode: graphite.** Neutral dark grey canvas with slightly lighter cards. *Decided.*
- A white canvas and a canvas tinted by server were rejected.

## Rail

- Sits at the window's leading edge on the canvas, the same in every state. *Decided.*
- **Two separate glass pills.** Servers are at the top and tools at the bottom, with canvas between them. *Decided.*
- **The server pill hugs its servers.** It grows with a spring when one connects. Once it reaches the tool pill it stops growing and scrolls inside. *Decided.*
- The tool pill contains Bookmarks, Snippets, History and Clipboard. Search moved to the toolbar and ⌘K. *Decided.*
- **The server pill ends with a +** that opens the connections menu (open sessions, saved connections, Manage Connections, Quick Connect). It replaces the toolbar's Connections button. *Decided* (2026-09-29, replaces "no + in the rail").
- **Both pills are the same width** (item + pill padding on every side), so the rail reads as one column. *Decided.*
- Item size is medium (34pt) by default, with a user setting for small and large. *Decided.*

## Tree

- The tree sits straight on the canvas, starting right after the rail. It has no panel or background of its own. *Decided.*
- Server names are the section headers, and they pin at the top while scrolling (see `05-components.md`). *Decided.*
- The tree can be hidden. The rail stays exactly where it is; the tree shrinks into the rail and the cards grow into its space (see `04-motion.md`). *Decided.*
- Tree width is adjustable by dragging its trailing edge, 200–480pt. *Leaning:* the gutter between tree and cards is the handle, with an 8pt grab area and the column-resize pointer; double-click returns it to 260pt. Built in S1, waiting for the owner's check.

## Cards

- The editor and the results are **two separate opaque cards**, with canvas between them. *Decided.*
- The gap between the two cards is also the resize handle (see `05-components.md`). *Decided.*
- **Corners: 12pt**, continuous. Concentric corners and 16pt were compared in the Design Lab and rejected. *Decided* (replaces the earlier "concentric with the window" rule).
- **Shadow: floating shadow** (soft, lifted off the canvas). Hairline and flat were rejected. *Decided.*
- **Gutter: 6pt by default**, with 4pt and 8pt available as a setting. The same gutter separates rail, tree, tab strip and cards. *Decided.*

## Tab strip

- **On the canvas, above both cards**, like Safari's tab bar above the page. *Decided.*

## Inspector

- The system inspector column (`.inspector`) at the trailing edge. *Decided.*

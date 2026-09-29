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
- There is no + in the rail. Connecting lives in the toolbar. *Decided.*
- Item size is medium (34pt) by default, with a user setting for small and large. *Decided.*

## Tree

- The tree sits straight on the canvas, starting right after the rail. It has no panel or background of its own. *Decided.*
- Server names are the section headers, and they pin at the top while scrolling (see `05-components.md`). *Decided.*
- The tree can be hidden. The rail stays exactly where it is, and the cards slide over the tree's space (see `04-motion.md`). *Decided.*
- Tree width is adjustable by dragging its trailing edge. *Leaning:* needs a small custom resize handle.

## Cards

- The editor and the results are **two separate opaque cards**, with canvas between them. *Decided.*
- The gap between the two cards is also the resize handle (see `05-components.md`). *Decided.*
- **Corners follow the window.** Card corners are concentric with the macOS window corners: the window radius minus the gutter, using `ConcentricRectangle`, so the cards look like part of the window. *Decided* (the principle). The exact look is *Open* and checked in the Design Lab.
- Shadow: floating shadow or hairline. *Open*; flat with no shadow was rejected.
- Gutters of 4, 6 or 8pt are all still candidates. *Open*: whichever looks most macOS-native in the Design Lab wins.

## Tab strip

- *Open:* on the canvas above both cards, or inside the editor card. The recommendation is on the canvas, like Safari's tab bar sitting above the page. See `05-components.md`.

## Inspector

- The system inspector column (`.inspector`) at the trailing edge. *Decided.*

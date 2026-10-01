# Motion

## The house spring

- Every animation in Echo goes through one function. *Decided.*
- **Default: bouncy.** `.bouncy(duration: 0.45, extraBounce: 0.08)` for movement: selection, cards, panels. *Decided.*
- Hover and press feedback uses shorter eases (0.12–0.16s). *Decided.*
- **Speed setting: Default and Fast.** Fast scales durations by 0.7. A Slow setting was rejected. *Decided.*
- **Reduce Motion:** every spring becomes a short fade of about 0.18s with no bounce, and pulsing stops. *Decided.*
- Durations are never written in views. They come from the motion token together with the speed setting. *Decided.*

## Where things move

| Moment | Motion | Status |
|---|---|---|
| Switching server in the rail | The selection moves to the server and the tree glides so the header lands at the top. With "one server at a time" on, the tree crossfades. | Decided |
| Rail selection shape | Liquid stretch: the leading edge springs to the target (0.28s), the trailing edge follows (0.55s, delayed 0.06s), both scaled by speed | Decided |
| Server connecting | The monogram breathes until connected, then settles. Stronger than the first version (see tokens) | Decided |
| Server connects | It grows out of the server pill, and the pill stretches to fit | Decided |
| Hiding the tree | The tree slides left under the rail's glass and fades while the cards grow into its space. Showing the tree uses the bouncy house spring; hiding it uses `settle` (same pace, no overshoot), so the cards stop at their place instead of bouncing into the rail. (A mask at the rail's edge was tried and dropped: it cut the tree card's shadow.) | Decided (round 8, after the first build) |
| Results after the first run | The results card rises from the bottom while the editor card shrinks | Decided |
| Folder expand | Rows slide down with a fade (native table animation), scaled by speed | Decided |
| Objects loading | Shimmer placeholder rows, then crossfade to the real rows | Decided |
| Switching tabs | Instant, like Safari | Decided |
| Tab overview | The active tab zooms out into its card; picking a card zooms back in | Decided |
| Toasts | Stack and melt together; a toast expands into a card on hover | Decided |
| Floating cards | Grow out of their button (glass morph); close with a click outside or Esc | Decided |
| Toolbar | Items that come and go per tab morph into their group | Decided |
| New tab | Grows out of the + button next to the strip | Decided |

## Glass morphing

Morphing is wanted wherever it explains a change. The owner loves native glass morphing. *Decided.*

- A new server grows out of the server pill.
- The server peek card grows out of its server.
- Toolbar groups merge and split.
- Toasts stack and merge.
- A new tab grows out of +.

Morphs need the shapes to be in one `GlassEffectContainer` in the same window (see `03-materials.md`).

## Rules

1. Use motion only when something changes place, size or state. *Decided.*
2. Pulse or loop only while something is in progress, and stop the moment it's done. *Decided.*
3. Animate in response to the user, never on a timer. The exception is progress feedback. *Decided.*
4. Everything must still work, and read clearly, with motion switched off. *Decided.*

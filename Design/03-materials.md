# Materials and Liquid Glass

## Where glass is used

| Surface | Material | Status |
|---|---|---|
| Rail pills (servers, tools) | `.glassEffect(.regular, in: .capsule)` | Decided |
| Toolbar items | System toolbar glass; Echo controls the grouping | Decided |
| Toasts | Interactive regular glass, stacking in one `GlassEffectContainer` | Decided |
| Floating cards (server peek, connect picker, notification history, search results) | Regular glass, drawn in the window by Echo, no arrow | Decided |
| Tab strip plate | Keeps today's look (grey plate, white active tab), tokenised, Safari-like | Decided |
| Tree, editor, results, inspector content | Opaque; no glass | Decided |
| Sheets | Opaque; macOS sheets can't be glass | System limit |

## Rules

1. **Glass only on the control layer.** Apple's rule: no glass in tables, lists or text areas. *Decided.*
2. **No glass on glass.** Content on a glass surface uses fills and vibrancy, not a second glass layer. The rail's glass-lens selection was rejected. *Decided.*
3. **Tint only the primary action.** The Run button is the only tinted glass in the toolbar (`glassProminent`, accent; red while running). *Decided.*
4. **Glass morphs only within one container.** Shapes that should melt into each other must sit in the same `GlassEffectContainer` in the same window. Plan containers around the morphs in `04-motion.md`. *Decided.*
5. **Don't stack custom backgrounds on system glass.** Remove custom visual-effect backgrounds from toolbars, popovers and split views. *Decided.*
6. **Arrowless cards are ours.** Neither SwiftUI nor AppKit can hide a popover's arrow. Floating cards are drawn inside the window over the content, which also lets them morph out of their button. Autocomplete is the one exception and keeps its system popover. *Decided.*
7. **Keep the number of glass surfaces low.** Each extra surface costs rendering time, and Apple advises restraint. *Decided.*

## Accessibility

- System glass adapts to Reduce Transparency (frostier) and Increase Contrast (solid, with borders) on its own. Custom fills must do the same: use semantic colours (`.primary.opacity`, `separator`, `textBackgroundColor`), never literal whites and blacks. *Decided.*
- Check every screen with Reduce Transparency and Increase Contrast turned on. *Decided.*

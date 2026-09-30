# Principles

## What Echo should feel like

Echo is a database tool that feels like it was made by Apple. It uses what macOS 26 and 27 give for free, then adds care where a database tool needs more than the system offers. It should feel calm when you read data and alive when something happens.

## Rules

1. **Native first.** Use the system control, material or behaviour when one exists: toolbar glass, the inspector, menus, tooltips, table views. Build our own only when the system can't do what we need, such as arrowless glass cards or the rail. *Decided.*
2. **Glass is for controls, never content.** Glass is used for the rail, the toolbar, toasts and floating cards. The tree, editor, results and inspector content are opaque. This is Apple's rule, and breaking it hurts legibility. *Decided.*
3. **No glass on glass.** Nothing made of glass sits on another piece of glass. Selection inside a glass pill is a fill, not a second glass layer; the rail's glass lens was rejected in the Echo Labs. *Decided.*
4. **One structure everywhere.** The rail, tree and cards stay in the same place whether the tree is shown or hidden. Only the cards move. *Decided.*
5. **Motion explains change.** Every animation shows where something came from or went. No decorative motion. Pulsing is used only for "in progress" states. *Decided.*
6. **Everything through tokens.** Sizes, radii, spacing, colours and animations come from `06-tokens.md` and the code's token files. No literal numbers or colours in views. *Decided.*
7. **User settings where taste differs.** These are settings, with defaults chosen here: *Decided.*
   - rail size;
   - tree density (4 levels);
   - icon colour (colourful, monochrome, and monochrome with accent on open folders);
   - gutter between panes (4 / 6 / 8pt);
   - what clicking a server does while the tree is hidden;
   - editor gutter style;
   - monospaced result cells;
   - motion speed.
8. **Keep what works.** Echo's tab strip, result grid, tab overview and Run button were refined over weeks. Improve them in place; don't replace them. *Decided.*
9. **Safari is the reference for tabs.** Tabs should look and behave like Safari's. *Decided.*
10. **Accessibility is not optional.** Reduce Motion, Reduce Transparency and Increase Contrast must all look right. Every control has an accessibility label and keyboard access where the system provides it. *Decided.*

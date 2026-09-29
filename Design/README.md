# Echo Design

This folder is the source of truth for how Echo looks, moves and behaves. Every UI change is checked against it. If a change breaks a rule, either the change is adjusted or the rule is changed here first, on purpose, with a line in the [decision log](decisions.md).

## Documents

| File | What it covers |
|---|---|
| [01-principles.md](01-principles.md) | What Echo should feel like, and the rules every screen follows |
| [02-layout.md](02-layout.md) | The canvas-and-cards window: rail, tree, cards, gutters, corners |
| [03-materials.md](03-materials.md) | Where Liquid Glass is used, where it is not, and why |
| [04-motion.md](04-motion.md) | The house spring, speed setting, morphing, Reduce Motion |
| [05-components.md](05-components.md) | Rail, tree, tabs, toolbar, editor, results, inspector, notifications, floating cards, search |
| [06-tokens.md](06-tokens.md) | Sizes, radii, spacing and colours in one place |
| [decisions.md](decisions.md) | Every design decision with its status and date |

## Status of a rule

Each rule carries one of these markers:

- **Decided**: agreed; build it this way.
- **Leaning**: preferred direction, still to be confirmed in the Design Lab.
- **Open**: not decided; options are listed, and the Design Lab has a preview to compare them.

## Changing the design

1. Before building UI, find the rules that apply here and in `05-components.md`.
2. If the change follows them, build it. Use the tokens in `06-tokens.md`, never literal numbers or colours.
3. If it doesn't, stop and propose a rule change: what changes, why, and which screens it affects.
4. Once agreed, update the rule, add a line to `decisions.md`, then build.
5. When a Design Lab comparison settles an Open item, move it to Decided in both places.

## Design Lab

`Echo/Sources/Features/DesignLab/` holds interactive playgrounds (debug builds only) for every Open and Leaning item. Run a debug build and choose **Help › Design Lab**, or open a lab file and use Xcode's canvas. The lab is where options are judged on the real rendering before they enter the app.

## Where this came from

The rules come from two review rounds held in September 2026, an investigation of Echo's code at that time, and Apple's Liquid Glass guidance for macOS 26 and 27. The raw answers and findings are summarised in `decisions.md`.

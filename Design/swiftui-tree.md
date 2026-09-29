# Investigation: building the Explorer tree in SwiftUI

Written 2026-09-29 for review round 8, sections 2 (tree cards) and 3 (pinned path header). Status: **proposal**, not decided.

## Where we are

- **The rows are already SwiftUI.** `ObjectBrowserRowView` is a SwiftUI view. Only the list around them is AppKit: an `NSTableView` in an `NSScrollView` (`ObjectBrowserOutlineView`), with one `NSHostingView` per visible row.
- **The data is already flat.** `ObjectBrowserSnapshotBuilder` builds the node tree, and the coordinator flattens the expanded nodes into visible rows. A SwiftUI list can consume exactly that list.
- **The tree uses few AppKit features:**
  - row recycling;
  - animated row insert and remove;
  - scrolling a row to the top with a glide;
  - top-visible tracking for the rail and the path;
  - `NSMenu` context menus through `lazyContextMenu`, which also works on SwiftUI views.
  
  There is no drag and drop, no custom keyboard handling and no table selection (selection is drawn by the rows).
- **Where the lag you remember came from:** the first sidebar (removed in ead6f9c) was a `ScrollView` of nested, recursive SwiftUI views: sections inside databases inside servers, each with its own `ForEach`, mostly not lazy. Expanding a large database built every row at once, and any state change re-ran big parts of that tree. The AppKit table fixed it by flattening the rows and recycling them.

## What SwiftUI can do now (macOS 26)

- `ScrollView` + `LazyVStack` over a **flat** row list creates rows only as they scroll in, like the table.
- `LazyVStack(pinnedViews: .sectionHeaders)` pins each server's header while its rows scroll under it. That is the glass card header with no extra code.
- **SwiftUI glass blurs SwiftUI content.** A pinned header with `.glassEffect` over SwiftUI rows really blurs them. Today it can't, because the rows are inside an AppKit table (the "hard lines" in round 8).
- `.scrollEdgeEffectStyle(.soft, for: .top)` gives the system's soft scroll-edge blur (option H2), also only over SwiftUI content.
- **Scrolling and tracking:**
  - `ScrollPosition` with `scrollTo(id:anchor:)` gives the animated reveal;
  - `onScrollTargetVisibilityChange` and `onScrollGeometryChange` give the top-visible server and database for the rail and the path.
- **Cards:** each server's rows sit in a nested `LazyVStack` inside the outer one, still lazy. That stack gets the editor's exact `.workspaceCard()`, so the cards match the editor by construction (option T1). Round 8's F2 end (rounded corners where the scroll area cuts a card) becomes a `clipShape` on the scroll view.

## What would need to be done

1. **Move flattening into the view model.** Take the visible-row flattening and the per-server grouping out of the table coordinator into plain, testable functions. The output is a list of server groups, each with its header and flat rows with stable IDs. Add unit tests.
2. **New `ExplorerTreeView`** (SwiftUI):
   - `ScrollView` → `LazyVStack(pinnedViews: .sectionHeaders)`;
   - one `Section` per server: the header is the glass card header, and the content is a nested `LazyVStack` of rows with `.workspaceCard()`;
   - pending and failed servers as small cards at the end.
3. **Row identity and cost:**
   - Drop `AnyView` and the per-row `.id()` workaround for recycled cells; use stable node IDs in `ForEach`.
   - Make rows `Equatable`, so unchanged rows skip their body.
   - Keep rows reading only the state they show.
4. **Scrolling:** `ScrollPosition` for reveal and for "top of server" / "scroll to database". The glide duration comes from `EchoMotion`.
5. **Top-visible tracking:** `onScrollTargetVisibilityChange` on server headers and database rows feeds `ServerRailBridge`, so the rail and path keep working.
6. **Expand and collapse:** animate the expanded-ID set with `motion.standard`, and give rows `.transition(.opacity.combined(with: .move(edge: .top)))`, matching the native slide and fade.
7. **Context menus:** keep `lazyContextMenu` (it builds the `NSMenu` only on right-click).
8. **Edges:**
   - the top soft edge via `.scrollEdgeEffectStyle`;
   - the rounded end via `.clipShape` of the card radius;
   - card shadows via `.scrollClipDisabled()` plus a mask that only clips the top and bottom.
9. **Switch-over:** build it behind a debug toggle next to the AppKit tree, compare the two, then delete `ObjectBrowserOutlineView`, the container, the card layer and the table.
10. **Stress fixture:** a debug data set of 3 servers × 40 databases × 500 tables, with some tables expanded to columns (about 25,000 rows). Measure scrolling with Instruments (SwiftUI and Hitches templates) before switching.

Rough size: 3–5 focused days, most of it in steps 2, 5 and 9.

## Benefits

- **Cards match the editor exactly:** same modifier, same corners (including the Card Corners setting), same shadow. One drawing path instead of two.
- **Real glass on the pinned header:** it blurs the rows under it, and the soft scroll edge is available too. This fixes round 8 section 3 at the root.
- **One animation system:** expand, collapse, reveal and hide all use `EchoMotion` and Reduce Motion automatically. Today the table uses its own `NSAnimationContext` timings.
- **Less code:**
  - no representable, coordinator, container or card layer view;
  - no `NSHostingView` per row;
  - no cell recycling workarounds (the `.id(node.id)` hack in `ObjectBrowserSidebarView`).
- **Easier to design:** everything is SwiftUI, so Design Lab previews can show the real tree.

## Pitfalls and how to handle them

| Pitfall | Why it happens | How to handle it |
|---|---|---|
| Lag on huge expansions | Lazy stacks keep created rows alive (no recycling), and measuring many rows costs time | Stress fixture and Instruments before switching; keep rows cheap and `Equatable`; no `GeometryReader` in rows |
| The whole tree re-renders | A parent body that reads frequently changing state rebuilds every section (the old sidebar's problem) | Feed the tree an immutable snapshot; read hover, scroll and top-visible state in small child views (the handover rule) |
| Scroll jumps | Rows have different heights (headers are taller), so estimates are off until rows are measured; `scrollTo` into unmeasured content can land slightly off | Fixed heights per row kind; reveal in two steps (scroll, then correct once measured) |
| Nested lazy stacks | Laziness across nested stacks has edge cases; a whole server's rows can be built at once if the inner stack isn't lazy | Verify with the stress fixture; fall back to one flat `LazyVStack` with per-row card segments if needed |
| Pinned headers and cards | A pinned header must sit inside its card's shape without covering the next card | Put the header in the card's `Section` so it unpins when its card ends |
| Expand animation at scale | Animating hundreds of inserted rows is heavy | Animate only when fewer than about 200 rows change; above that, a plain crossfade |
| Focus and type-select | The table gave nothing here today, so nothing is lost; adding keyboard navigation later is SwiftUI work (`focusable`, `onKeyPress`) | Out of scope; note for later |

## Effect on the round 8 options

- **Section 2 (tree cards):** T1 becomes a simple `.workspaceCard()` per server.
- **Section 3 (path header):**
  - **H1** (real glass) comes for free as the pinned section header, and it blurs.
  - **H2** (soft edge) is one modifier.
  - **H3** (path above the card) is still possible.
  
  With SwiftUI, H1 is the natural choice, and H1 plus a soft edge is also possible.

## Recommendation

Build it, in the order above, behind a debug toggle. Go ahead only if the stress fixture scrolls without hitches on your Mac. If it doesn't, the fallback is a hybrid: keep the AppKit table for rows, and draw the cards and glass header in SwiftUI in a separate layer. That is harder to keep in sync, and the header still can't blur AppKit rows, so it's a clear second choice.

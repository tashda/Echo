# October 2025 Recovery Highlights

This log cross-references the October 7–9 Codex sessions so we can quickly recall how the major regressions were resolved. Each bullet links to the final log that captured the fix.

## Safari-Style Tab Bar
- **Base plate & hover geometry** – converted the strip to SwiftUI, recalculated the trailing-control width and base-plate insets so the background stops exactly at the last tab (`rollout-2025-10-08T09-36-17-0199c2bf-dd35-7c02-a31b-7a98f9f2a2df.jsonl`).
- **Divider behaviour & pinning** – limited the hidden separators to the active drag gap and restored pin behaviour (`rollout-2025-10-08T20-47-04-0199c525-f9b0-7601-ba23-36e8c02cdf9d.jsonl`).
- **Tab overview & keyboarding** – measured the grid with a geometry reader so the focus ring and arrow navigation lined up, then auto-dismissed overview whenever a tab activated (`rollout-2025-10-08T20-47-04-0199c525-f9b0-7601-ba23-36e8c02cdf9d.jsonl`, `rollout-2025-10-08T22-50-32-0199c597-0482-7012-bb1e-f7d8097c1a5e.jsonl`).
- **Themed tabs toggle** – introduced the “Match workspace tabs to editor theme” option, feeding accent and surface colours down to the strip (`rollout-2025-10-08T09-36-17-0199c2bf-dd35-7c02-a31b-7a98f9f2a2df.jsonl`).

## Workspace Toolbar & Sidebar
- **Button-first navigator** – replaced the breadcrumb overlay with Projects/Servers/Database buttons, plus Update/Add Tab/Overview/Inspector controls sized to 28 pt (`rollout-2025-10-09T09-24-44-0199c7db-a4ce-7d03-9826-e03939949a61.jsonl`).
- **Native layout & status pill** – returned to SwiftUI toolbar items with the animated Update button and icon spacing fixes (`rollout-2025-10-09T09-24-44-0199c7db-a4ce-7d03-9826-e03939949a61.jsonl`, `rollout-2025-10-08T21-13-11-0199c53d-e325-7df0-815a-6ed2d4d8165c.jsonl`).
- **Toolbar icon mapping** – introduced the new custom assets (`database.outlined`, `database.check.outlined`, etc.) so navigator and menus share the updated glyphs (`rollout-2025-10-07T23-23-45-0199c08f-1287-7742-a061-8031581b35e2.jsonl`).
- **Sidebar hover polish** – rebuilt the Explorer footer, schema picker, and hover shadows to match the desired macOS chrome (`rollout-2025-10-07T21-49-40-0199c038-ee87-7092-bb78-b229c45b3518.jsonl`).

## Query Editor White Screen
- Clamped the query editor/results split to a geometry reader, clipped both panes to a `Rectangle`, and ensured background layers read from the active theme to prevent the blank window regression (`rollout-2025-10-08T17-15-59-0199c464-b8b6-7d22-a31a-40249957c70e.jsonl`).

## Explorer Footer & Sidebar Layout
- Reduced footer height, swapped the schema picker/search controls to smaller capsules, and removed sticky headers for a lighter look (`rollout-2025-10-07T09-44-35-0199bda1-198d-71a0-b608-7845050e6ca2.jsonl`).
- Migrated the AppKit explorer controller to the same capsule styling and hover state as the SwiftUI prototype (`rollout-2025-10-07T21-49-40-0199c038-ee87-7092-bb78-b229c45b3518.jsonl`).

## Autocomplete Pipeline & Management
- Rebuilt the SQL editor suppression engine, bold keyword list, and Apple Intelligence glow accessory (`rollout-2025-10-08T21-52-44-0199c562-17d5-7b90-b4e0-5c12fdecad57.jsonl`).
- Added the dedicated Autocomplete Management window and documentation (`rollout-2025-10-09T10-37-49-0199c81e-8b54-7023-b5f5-640f26ae3be9.jsonl`).

## Manage Projects & Connections
- **Manage Projects** – refreshed the sheet with a gradient header, inline actions, and theme import/export pipeline (`rollout-2025-10-09T09-43-00-0199c7ec-5ccf-7d30-bf87-660fb4c64703.jsonl`).
- **Manage Connections** – upgraded to the split outline/table layout with search, sorting, and context menus (`rollout-2025-10-09T11-29-37-0199c84d-fb5b-7833-9998-c55d4f79c617.jsonl`).

## Table Structure Editor
- Restored the dynamic column table, helper bindings, selection-aware deletion, and the redesigned column sheet layout with proper Section headers (`rollout-2025-10-09T09-58-34-0199c7fa-9fdb-70a2-afd7-b4009f60553e.jsonl`, `rollout-2025-10-08T22-55-02-0199c59b-22d6-7c11-a712-9bf4739bfb71.jsonl`).


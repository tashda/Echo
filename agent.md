# Fuzee Agent Notes

## Current State
- Repository reset to commit `4e45cd6` and reconstructed for multi-session sidebar + cached schema architecture.
- Explorer sidebar now uses `DatabaseObjectBrowserView` to render schemas/tables/functions with Finder-style interactions.
- Postgres integration restored via `PostgresSession` in `fuzee/Database/PostgresDatabase.swift`; supports schema enumeration, object definitions, and cached structures.
- Query experience is provided by `TabbedQueryView`, `QueryInputSection`, and `HighPerformanceGridView` (macOS/iPad friendly split view).

## Design Priorities
- UI must feel like a native macOS Tahoe app: glassy backgrounds, subtle elevations, no harsh contrasts.
- App ships on macOS **and** iPadOS. Avoid Mac-only APIs (replace `.selection`, `.regularMaterial`, `.separator`, etc. with cross-platform `Color` equivalents).
- Keep experiences simple but powerful: multi-session management, quick database switching, schema browsing, and responsive query tabs.

## Implementation Guidelines
1. **Sidebar/Explorer**
   - Use `ExplorerSidebarView` + `DatabaseObjectBrowserView` for schema rendering; prefer `Color`-based styling.
   - Cached structures live on `SavedConnection.cachedStructure`; refresh via `AppModel.refreshDatabaseStructure`.
2. **Database Layer**
   - Extend `PostgresSession` carefully; API aligned with PostgresNIO row sequences.
   - Reuse helper `performQuery` + `firstString` when adding new metadata queries.
3. **Query Tabs**
   - `TabManager` (on `AppModel`) owns tabs. `HighPerformanceGridView` expects standard `QueryResultSet` data.
   - Split view uses `ResizeHandle`; keep interactive handle cross-platform.
4. **Theming**
   - All theme-dependent colors live in `ThemeManager`; add new toggles (e.g., alternate row shading) there.

## Build & Tooling
- The Codex CLI runs in a sandbox; it cannot write to `~/Library/Caches` (Xcode/SwiftPM caches). Builds that need package resolution must be run locally.
- When editing, keep files ASCII-only unless the file already uses Unicode symbols.


## Outstanding Tasks / Ideas
- Reintroduce folder-aware connection management (see `SidebarModels.swift`).
- Polish connection testing UI (currently surfaces raw success/error text).
- Expand `PostgresSession` to expose trigger/function definitions in UI.

Keep this file updated whenever major architectural or workflow changes land.

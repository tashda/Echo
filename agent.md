# Echo Agent Notes

## Current State
- Repository reset to commit `4e45cd6` and reconstructed for multi-session sidebar + cached schema architecture.
- Explorer sidebar now uses `DatabaseObjectBrowserView` to render schemas/tables/functions with Finder-style interactions.
- Postgres integration restored via `PostgresSession` in `Echo/Database/PostgresDatabase.swift`; supports schema enumeration, object definitions, and cached structures.
- Query experience is provided by `TabbedQueryView`, `QueryInputSection`, and `HighPerformanceGridView`.
- Project-centric data model is live: connections, identities, and folders are scoped by project, persisted through `ProjectStore`, and surfaced via the Xcode-style `TopBarNavigator`.
- `ManageConnectionsTab` replaces the legacy sidebar editing: creation/edit/move flows live there while `ConnectionsSidebarView` is read-only for navigation.

## Design Priorities
- UI must feel like a native macOS Tahoe app: glassy backgrounds, subtle elevations, no harsh contrasts.
- Target macOS only. We can lean on Mac-specific APIs and behaviors without maintaining iPad compatibility.
- Adopt the latest Swift and SwiftUI design language whenever possible; prefer modern APIs introduced in recent platform releases.
- Keep experiences simple but powerful: multi-session management, quick database switching, schema browsing, and responsive query tabs.

## Implementation Guidelines
1. **Projects & Navigation**
   - Keep `AppModel.selectedProject` in sync with `NavigationState`; filter persisted models by project ID when querying.
   - `TopBarNavigator` mimics Xcode breadcrumbs; extend it for future Git/project actions instead of adding controls to the sidebar.
2. **Sidebar/Explorer**
   - Use `ExplorerSidebarView` + `DatabaseObjectBrowserView` for schema rendering; prefer `Color`-based styling.
   - Cached structures live on `SavedConnection.cachedStructure`; refresh via `AppModel.refreshDatabaseStructure`.
3. **Manage Connections**
   - Mutations (create/edit/move/delete) run through `ManageConnectionsTab`; `ConnectionsSidebarView` should stay focused on navigation and quick actions.
   - Use the shared sheets in `Views/Shared/FolderIdentityEditors.swift` for folder/identity CRUD to keep UX consistent across entry points.
4. **Database Layer**
   - Extend `PostgresSession` carefully; API aligned with PostgresNIO row sequences.
   - Reuse helper `performQuery` + `firstString` when adding new metadata queries.
   - Share common helpers across database engines when it reduces duplication, but keep engine-specific logic isolated per database implementation (Postgres, MySQL, MSSQL, etc.).
5. **Query Tabs**
   - `TabManager` (on `AppModel`) owns tabs. `HighPerformanceGridView` expects standard `QueryResultSet` data.
   - Split view uses `ResizeHandle`; keep interactive handle cross-platform.
   - Results grid must stay responsive and accurate—never introduce lag or stale/incorrect cells; keep data shaping in the fetch pipeline, not in the view layer.
6. **Theming**
   - All theme-dependent colors live in `ThemeManager`; add new toggles (e.g., alternate row shading) there.

## Build & Tooling
- The Codex CLI runs in a sandbox; it cannot write to `~/Library/Caches` (Xcode/SwiftPM caches). Builds that need package resolution must be run locally.
- SQL formatting now uses the sqruff CLI. Run `Scripts/build_sqruff.sh` to cache/build the universal binary (requires `rustup` in `~/.cargo/bin`, which the script adds to `PATH`, and it will pull the toolchain pinned in `rust-toolchain.toml`). In Xcode the Run Script phase declares the bundled formatter as an output at `$(BUILT_PRODUCTS_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/sqruff`, so the script writes there; outside Xcode it stages to `BuildTools/sqruff/sqruff`.
- Sqruff configuration lives in `BuildTools/sqruff/.sqruff` (copied into the app bundle alongside the binary). Edit this file to tweak formatter behaviour—e.g. we set `max_line_length = 50` so clauses like `WHERE` and `LIMIT` are pushed onto their own lines.
- When editing, keep files ASCII-only unless the file already uses Unicode symbols.


Keep this file updated whenever major architectural or workflow changes land.

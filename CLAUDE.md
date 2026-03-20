# Echo Project Guidelines

## Visual Design Guidelines

**Before creating or modifying any UI**, read `VISUAL_GUIDELINES.md` in the project root. It defines the golden standard for every UI pattern — grouped forms, data tables, sheets, context menus, buttons, empty states, sidebar elements, and more. All new code must match the golden standard for its pattern. All modifications to existing code must bring it into compliance if it deviates.

## Design & Platform

Echo is a **macOS-only** application. It targets **macOS 26+** exclusively — there is no iOS, iPadOS, tvOS, watchOS, or visionOS target. Never import UIKit, UIApplication, or any iOS/iPadOS-only frameworks. Use only AppKit and SwiftUI (macOS). All UI must follow Apple Human Interface Guidelines for macOS — always prefer native macOS controls, system-provided spacing, typography, and layout patterns. Never emulate non-native UI paradigms or build custom controls when a system equivalent exists.

Before writing or modifying any SwiftUI/AppKit code, use the `sosumi` MCP (`searchAppleDocumentation`, `fetchAppleDocumentation`) to verify the correct API usage, available modifiers, and recommended patterns. Use the `ref` MCP (`ref_search_documentation`, `ref_read_url`) to look up library, framework, or third-party API documentation. This applies both when reading existing code (to check correctness) and when writing new code (to ensure compliance with current documentation).

## Design Reference Workflow

Figma may be used as a manual design reference, but Echo must not depend on Figma Dev Mode or Figma MCP. The project assumes the free Figma plan, so agents should not require `figma-desktop`, `figma-remote`, or any MCP-based Figma inspection workflow.

The canonical visual reference remains the macOS 26 Tahoe Figma kit at `https://www.figma.com/community/file/1543337041090580818/macos-26`. Use it manually as a reference for macOS 26 patterns, materials, spacing, toolbar structure, sidebars, tables, inspectors, and window organization. Echo-specific screens may also be drafted in a separate Figma file, but that file is a human reference, not an MCP-integrated source of truth.

For every UI task, follow this sequence:
1. Gather the available design context manually. This may include a Figma link, screenshots, annotated images, or written UI requirements from the user.
2. Verify the intended pattern against official Apple guidance using `sosumi`, including Human Interface Guidelines, Liquid Glass guidance where relevant, and the specific SwiftUI/AppKit APIs that implement the pattern.
3. Map the design intent to native macOS controls and layouts. Do not reproduce non-native Figma details if they conflict with Apple platform behavior.
4. Map all visual values to Echo design tokens and shared design-system components. Never copy raw design values directly into SwiftUI/AppKit code.
5. After implementation, compare the running app against the reference material and confirm the result still feels native on macOS 26.

When working from manual design references, the agent must still explicitly reason about:
- view hierarchy and grouping
- control types and interaction intent
- spacing, alignment, and density
- typography roles rather than absolute font sizes
- color/material intent rather than literal fill values
- states such as selection, hover, focus, disabled, empty, and loading

Figma or screenshots are design inputs, not the final authority. If the reference material and Apple guidance differ, prefer the official Apple behavior and update the implementation accordingly. The goal is not pixel-matching a mockup at all costs; the goal is a native macOS 26 result that preserves the design intent.

## Swift 6.2 & Build

Echo uses **Swift 6.2** with the **Swift 6 language mode**. All code must be data-race safe at compile time.

### Build Settings (Required)

These Xcode build settings MUST be enabled:

- **Swift Language Version** → Swift 6
- **Approachable Concurrency** → Yes (enables `NonisolatedNonsendingByDefault`, isolated conformances, and other Swift 6.2 features as a suite)
- **Default Actor Isolation** → `MainActor` (for the main Echo app module — all declarations are `@MainActor` unless explicitly opted out)
- **Strict Concurrency Checking** → Complete

### Concurrency Model

Swift 6.2 introduces a fundamentally simpler concurrency model. Understand and follow these principles:

**1. MainActor by default for the app module.**
With `Default Actor Isolation = MainActor`, every declaration in Echo's main module is implicitly `@MainActor`. You do NOT need to write `@MainActor` on views, view models, or app-level types — it is inferred. This means all code runs on the main thread unless you explicitly opt out.

**2. Async functions stay on the caller's actor (SE-0461).**
In Swift 6.2, nonisolated async functions run on whatever actor called them — they do NOT hop to the concurrent thread pool. This eliminates a major class of Sendable errors. If you call an async function from the main actor, it stays on the main actor. You only leave the actor when you explicitly choose to.

**3. Use `@concurrent` to explicitly offload work.**
When a function performs CPU-intensive work (image processing, large data formatting, file I/O), mark it `@concurrent async` to guarantee it runs on the concurrent thread pool. This is the ONLY way work moves to a background thread in 6.2. Use it surgically — only where profiling shows the main thread is blocked.

```swift
// GOOD: Explicitly offloads expensive work
@concurrent
func decodeImage(_ data: Data) async -> NSImage { ... }

// GOOD: Stays on caller's actor (main actor if called from UI)
func fetchMetadata() async throws -> DatabaseStructure { ... }
```

**4. Use `nonisolated` to decouple types from MainActor.**
Types that have no UI dependency (database adapters, formatters, pure data processors) should be marked `nonisolated` at the type level (Swift 6.1+). This removes the implicit MainActor isolation from all their members.

```swift
// GOOD: Entire type is decoupled from MainActor
nonisolated struct ResultRowFormatter { ... }

// GOOD: Package types are naturally nonisolated (no MainActor default in packages)
public actor PostgresClient { ... }
```

**5. Libraries should be `nonisolated`, not `@concurrent`.**
Package code (`postgres-wire`, `sqlserver-nio`, `EchoSense`) does NOT use MainActor-by-default. Functions in packages should be `nonisolated` — callers in the app decide whether to offload. Only use `@concurrent` in packages when the function is always expensive regardless of input size.

**6. Isolated conformances for MainActor types.**
When a MainActor type conforms to a protocol with nonisolated requirements, Swift 6.2 supports isolated conformances. The compiler ensures the conformance is only used from the correct actor. You no longer need `nonisolated` workarounds or `@preconcurrency` for these cases.

**7. Non-Sendable classes stay on one actor.**
Model classes should generally be `@MainActor` (inferred by default) or explicitly `nonisolated`. Do NOT make model classes `Sendable` — that requires locking and is error-prone. Instead, keep them on one actor and `await` across actor boundaries when needed.

**8. Avoid `@unchecked Sendable` in new code.**
Existing `@unchecked Sendable` on adapter types wrapping package clients is acceptable legacy. For new code, find a safe alternative: use actors, value types, or `sending` parameters.

### Concurrency Anti-Patterns (Do NOT)

- Do NOT write `@MainActor` explicitly on types in the Echo app module — it is inferred by default.
- Do NOT use `DispatchQueue` for new code. Use `@concurrent async` for background work and `TaskGroup`/`async let` for parallelism.
- Do NOT use `DispatchQueue.main.async` — use `Task { @MainActor in ... }` or just call the function directly (it's already on MainActor).
- Do NOT use `Task.detached` unless you specifically need to escape actor isolation AND have verified it's necessary.
- Do NOT add `@Sendable` to closures unless the closure genuinely crosses an actor boundary. SwiftUI modifiers like `visualEffect` that are `@Sendable` require captured values to be copied — use capture lists.
- Do NOT pass `nonisolated(unsafe)` to suppress errors — fix the underlying isolation issue.

### Build Tools

Use **XcodeBuildMCP** for all build, run, and test operations. Do not use `xcodebuild` shell commands directly. At the start of each session, call `session_show_defaults` — if the project and scheme are not set, call `session_set_defaults` with `projectPath: "/Users/k/Development/Echo/Echo.xcodeproj"` and `scheme: "Echo"`. Do not call `discover_projs` — the project path and scheme are always the same.

**This is a macOS app — use macOS workflow tools only.** Use `build_macos`, `build_run_macos`, `test_macos`, etc. Never use simulator tools (`build_sim`, `build_run_sim`, `test_sim`) — Echo has no iOS target and no simulator. Do not pass `SUPPORTED_PLATFORMS=macosx` or `SDKROOT=macosx` overrides to simulator tools as a workaround.

**Stopping the app:** Use `stop_mac_app` from XcodeBuildMCP to stop Echo. Never use `pkill` or shell commands to kill the application.

### Debugging Async Code

Swift 6.2 + Xcode 26 significantly improve async debugging:
- LLDB follows execution across `await` boundaries and thread switches automatically.
- Use `Task(name: "descriptive-name")` for tasks that are long-lived or hard to identify — task names appear in LLDB and Instruments.
- Use `swift task info` in LLDB to inspect the current task's priority, parent, and children.
- Use the Swift Concurrency Instruments template to profile actor contention and task scheduling.

## Self-Verification Workflow

After every code change (feature, fix, or refactor), you MUST verify your work using XcodeBuildMCP. Do not consider a task complete until you have confirmed it works. Follow this loop:

1. **Build** — Use `build_macos` to compile. Fix all errors before proceeding.
2. **Run** — Use `build_run_macos` to launch Echo. Confirm it starts without crashes.
3. **Inspect logs** — Use `launch_mac_app` with log capture or check Console.app output for runtime warnings, assertion failures, or unexpected behavior.
4. **Debug** — If something is wrong, use LLDB tools: attach to the process, set breakpoints at the relevant code, inspect variables, and step through execution to find the root cause. Do not guess — use the debugger.
5. **Screenshot / UI snapshot** — For any UI change, use `snapshot_ui` or `screencapture` (shell) to verify the visual result matches expectations. The `screenshot` tool requires a simulator and does not work for macOS apps.
6. **Iterate** — If any step fails, fix the issue and restart from step 1.

This is not optional. Never submit a change you haven't built and run successfully.

## Packages — Ownership & Boundaries

Echo connects to databases through first-party packages. We maintain all of these. The fundamental rule: **Echo is a consumer, packages are providers.** Echo calls typed APIs from packages — it never implements database protocol logic or driver behavior itself.

### The Boundary Rule

Ask: "Is this database behavior or app behavior?"
- **Database behavior** → implement in the package (`postgres-wire`, `sqlserver-nio`), expose a typed async API, then call it from Echo.
- **App behavior** → implement in Echo, consuming package APIs.

**Examples:**

```swift
// WRONG — Echo should not know how to list tables via SQL
let result = try await session.simpleQuery("SELECT tablename FROM pg_tables WHERE schemaname = '\(schema)'")

// RIGHT — Package exposes typed API, Echo calls it
let tables = try await client.metadata.listTables(schema: schema)
```

```swift
// WRONG — Echo constructs DDL
try await session.executeUpdate("ALTER TABLE \(table) ADD COLUMN \(name) \(type)")

// RIGHT — Package provides typed operation
try await client.admin.addColumn(name: name, type: .text, toTable: table, schema: schema)
```

**The only acceptable raw SQL in Echo** is user-authored queries typed into the query editor and executed via `session.simpleQuery()`.

### Package Concurrency Guidelines

Packages do NOT have MainActor-by-default. Their concurrency rules differ from the app:

- Package types are `nonisolated` by default — no `@MainActor` inference.
- Public async APIs should be `nonisolated` (the default in packages) so callers decide the isolation context.
- Use `@concurrent` only for functions that are *always* expensive regardless of input.
- Expose `Sendable` types for data that crosses actor boundaries (result sets, column metadata, connection configs).
- Use `actor` for types that manage mutable shared state (connection pools, caches).
- Prefer `async`/`await` and `AsyncSequence` over NIO `EventLoopFuture` in new APIs. Existing ELF APIs can remain for backward compatibility but new public API should be async-only.

### Commit and Push Rule

Every time you modify a package, commit and push to the `dev` branch before moving on. Do not leave uncommitted package changes — Echo's SPM resolution depends on the remote state.

### EchoSense (Shared Library)
- Package: `EchoSense` at `/Users/k/Development/EchoSense`
- Database-agnostic types shared across Echo and packages: `EchoSenseDatabaseType`, `EchoSenseDatabaseStructure`, `EchoSenseSchemaObjectInfo`, `EchoSenseColumnInfo`, SQL autocomplete types.
- All types here must be `Sendable` value types (structs/enums).
- We maintain this package. Changes go here, not in Echo.

### PostgreSQL
- Package: `postgres-wire` at `/Users/k/Development/postgres-wire`
- Exposes `PostgresClient` with namespaced APIs: `.metadata`, `.security`, etc.
- We maintain this package. Fix bugs and add features there, not in Echo.
- Use the **pgEdge MCP** (`pgedge`) for interacting with Postgres instances (queries, schema inspection, etc.).

### Microsoft SQL Server
- Package: `sqlserver-nio` at `/Users/k/Development/sqlserver-nio`
- Exposes `SQLServerClient` with namespaced APIs: `.metadata`, `.admin`, `.security`, `.agent`, `.indexes`, `.constraints`, `.transactions`.
- We maintain this package. Fix bugs and add features there, not in Echo.
- Protocol reference: `tds-mcp` at `/Users/k/Development/tds-mcp` — we also maintain this.
- Use the **mcpql MCP** for interacting with SQL Server instances.
- Use the **tds-mcp** for TDS protocol details, token definitions, data type encoding, and packet structure.
- When something isn't working with SQL Server communication, use **wiremcp** to capture and analyze packets. Update both `tds-mcp` (with protocol findings) and `sqlserver-nio` (with the fix).

### Workflow for Database Issues
1. Reproduce the problem in Echo.
2. Narrow down whether the issue is in the package or in Echo's usage of it.
3. If it's a package issue, switch to the package directory, fix it there, and verify.
4. Commit and push the package fix to `dev`.
5. Update Echo's `Package.resolved` to consume the fix.

## Query Execution Architecture

Understanding how queries flow through the system helps agents make correct changes:

```
User types SQL in editor
    → QueryEditorContainer receives onExecute
    → WorkspaceTabContainerView.runQuery()
        → Resolves execution session (database context, schema)
        → session.simpleQuery(sql, executionMode:, progressHandler:)
            → DatabaseSession adapter (PostgresSession / SQLServerSessionAdapter / ...)
                → Package client (PostgresClient / SQLServerClient)
                    → Wire protocol to database server
        → progressHandler receives QueryStreamUpdate events → state.applyStreamUpdate()
    → Final QueryResultSet → state.consumeFinalResult()
```

**Key types in the pipeline:**
- `DatabaseSession` (protocol) — the abstraction Echo uses for all database operations
- `QueryResultSet` — rows + columns + metadata returned from a query
- `QueryStreamUpdate` — progressive result events during streaming
- `QueryEditorState` — `@Observable` state managing the editor, results, execution status
- `ResultStreamBatchWorker` — handles parallel row formatting for large result sets

When modifying query execution, change the correct layer. UI state → `QueryEditorState`. Query dispatch → `WorkspaceTabContainerView+Execution`. Result processing → `ResultStreamBatchWorker`. Database communication → package.

## GitHub

Use the **GitHub MCP** (`mcp__github__*`) for all GitHub interactions — creating PRs, issues, reading file contents, searching code, etc. Do not use `gh` CLI unless the MCP cannot accomplish the task.

## Documentation Verification

Every time you open or modify a file that uses Apple frameworks (SwiftUI, AppKit, Foundation, Combine, etc.), use `sosumi` to look up the relevant APIs. Confirm:
1. The API is not deprecated for macOS 26.
2. The usage matches Apple's recommended patterns.
3. Newer, better alternatives haven't been introduced.
4. The implementation remains consistent with the corresponding Figma design and the official macOS Human Interface Guidelines.

This is not optional — treat it as a pre-flight check before any code change.

## Testing

Everything must be testable — in Echo, EchoSense, sqlserver-nio, and postgres-wire. Every function, view, and component should have tests that can conclusively determine whether it works. Tests must be added to GitHub Actions to run automatically when a commit is pushed to the `dev` branch.

When adding or modifying functionality, write or update the corresponding tests. Do not consider a feature complete without test coverage.

Use **Swift Testing** (`@Test`, `#expect`, `#require`) for new tests. Use `@Test` attribute for test functions, not XCTest's `test` prefix convention. Use `#expect(throws:)` for error-case tests. Use `Attachment.record` when tests need diagnostic context. XCTest is acceptable for existing tests but all new tests should use Swift Testing.

### Test Plans

Echo uses Xcode test plans (`.xctestplan` files) to manage which tests run where. **Never use `-skip-testing` or `-only-testing` flags in CI workflows** — use test plans instead.

| Plan | File | Purpose | Runs on |
|---|---|---|---|
| **UnitTests** | `UnitTests.xctestplan` | All tests except integration — uses `skippedTests` so new unit test files are automatically included | GitHub-hosted `macos-26` |
| **IntegrationTests** | `IntegrationTests.xctestplan` | Database integration tests (MSSQL, Postgres, SQLite, cross-dialect) — uses `selectedTests` for explicit inclusion | Self-hosted `echo-test-server` |
| **EchoTests** | `EchoTests.xctestplan` | Everything (used for local development) | Local only |

**When adding a new test file:**
- **Unit test** (no database needed): No action required — `UnitTests.xctestplan` uses `skippedTests`, so new files are included automatically.
- **Integration test** (needs database): Add the test class name to both `IntegrationTests.xctestplan` (`selectedTests` array) AND `UnitTests.xctestplan` (`skippedTests` array).

### CI Pipeline Structure

The CI pipeline runs on every push to `dev` and `main`:

- **Step 1** (GitHub-hosted `macos-26`): Runs `UnitTests` test plan — compilation + all unit tests.
- **Step 2** (self-hosted `echo-test-server`): Runs `IntegrationTests` test plan — Docker containers (Colima), MSSQL, Postgres, SQLite.
- **Step 3** (GitHub-hosted `macos-26`): Production build + Sparkle release — only on `main`, requires Step 1 + Step 2 to pass.

A **runner health check** workflow runs every 6 hours to verify Colima, Docker, and test containers are up on the self-hosted runner. It auto-recovers if anything is down.

### Self-Hosted Runner Infrastructure

The self-hosted runner (`echo-test-server`) is an Intel iMac running:
- **Colima** (`/usr/local/bin/colima`) — lightweight Docker runtime using macOS Virtualization.framework
- **Docker socket**: `unix:///Users/k/.colima/default/docker.sock`
- **LaunchAgent** (`com.echo.colima`) — auto-starts Colima on boot with `PATH` set to include `/usr/local/bin`
- **Test containers** (with `--restart unless-stopped`):
  - `echo-test-mssql` — SQL Server 2022 on port 14332
  - `echo-test-pg` — Postgres 16 on port 54322

## Design Tokens

Never hardcode colors, spacing, or fonts. Every visual value must reference a design token from `Echo/Sources/Shared/DesignSystem/`.

- **Colors** → `ColorTokens` in `ColorToken.swift` — use `ColorTokens.Background.primary`, `ColorTokens.Text.secondary`, `ColorTokens.Status.error`, etc. All colors derive from system semantic colors.
- **Spacing** → `SpacingTokens` in `SpacingToken.swift` — use `SpacingTokens.xs` (8pt), `.sm` (12pt), `.md` (16pt), `.lg` (24pt), etc. Never write raw `CGFloat` padding/spacing values.
- **Typography** → `TypographyTokens` in `TypographyToken.swift` — use semantic styles (`TypographyTokens.body`, `.headline`, `.caption`) or fixed-size styles (`.detail` 11pt, `.standard` 13pt, `.prominent` 14pt, etc.). Never write `.font(.system(size: N))` directly.
- **Components** → Reusable design system components live in `DesignSystem/Components/` (e.g., `CountBadge`, `EmptyStatePlaceholder`, `SidebarSectionHeader`, `ToolbarAddButton`, `TintedIcon`). Use these instead of reimplementing common patterns.

## Form TextField Rules

Every `TextField` inside a grouped `Form` must have a `prompt:` parameter with descriptive placeholder text. The field must never appear empty — the prompt gives users a visual hint of what to enter. Use `prompt: Text("example value")` with a realistic example or brief description. The prompt text appears greyed-out and disappears automatically when the user types — it is not editable content.

```swift
// WRONG — empty field with no hint
TextField("", text: $name)

// RIGHT — placeholder guides the user
TextField("", text: $name, prompt: Text("e.g. my_database"))
```

## Code Architecture

### File Size Limits
- **Views:** 200 lines max.
- **ViewModels:** 300 lines max.
- **All other files:** 500 lines max.

If a file exceeds these limits, split it. Extract logical sections into focused extensions or separate files. Use the established pattern: `TypeName.swift` (core) + `TypeName+Concern.swift` (extensions).

### One File = One Responsibility
Each file must have a single, clear purpose. Do not combine unrelated logic in one file. If a file does two things, split it into two files.

### Naming
No vague names. Everything must be named in a standardized, obvious way. Never use `Helper`, `Utility`, `Manager`, `Handler`, `Service`, `Coordinator`, or similar generic suffixes. Name types and functions for what they actually do.

### Reusability
Every UI component must be reusable and modular. If you build a control, list row, or section, design it so it can be used in multiple contexts. Extract common patterns into `DesignSystem/Components/`.

### Match Existing Patterns
Follow the patterns already established in the codebase. Do not invent new architectural patterns, naming conventions, or structural approaches. When in doubt, find a similar existing implementation and follow its structure.

### Type Isolation Patterns

The codebase follows these isolation conventions:

| Type category | Isolation | Rationale |
|---|---|---|
| SwiftUI Views | `@MainActor` (inferred) | Views are UI — always main thread |
| ViewModels / `@Observable` classes | `@MainActor` (inferred) | Drive UI state — always main thread |
| State stores (`ProjectStore`, `ConnectionStore`) | `@MainActor` (inferred) | App state — always main thread |
| Database adapters (`PostgresSession`, `SQLServerSessionAdapter`) | `nonisolated` + `Sendable` | Cross-actor boundary, no UI dependency |
| Data models (structs in `DatabaseModels`) | `nonisolated` + `Sendable` | Value types — safe to share |
| Package client types | `actor` or `nonisolated` | Package decides own isolation |
| Formatters / processors | `nonisolated` | Pure logic, no UI dependency |
| Expensive computation | `@concurrent async` | Explicitly offloaded |

## SSMS Feature Parity

Echo's goal is to match and exceed SQL Server Management Studio. The ongoing gap analysis lives at:

- **Gap document:** `/Users/k/Development/Echo/SSMS_FEATURE_GAP.md` — lists every SSMS feature, its status in Echo and sqlserver-nio, and the relevant sql-docs reference path.
- **sql-docs:** `/Users/k/Tools/docs/sql-docs` — local clone of the full Microsoft SQL Server documentation (~14,500 markdown files). Use `grep -r "topic" /Users/k/Tools/docs/sql-docs --include="*.md" -l` to find relevant docs before implementing any SQL Server feature.

When implementing a new SQL Server feature:
1. Check `SSMS_FEATURE_GAP.md` to understand scope and find the sql-docs reference.
2. Read the relevant sql-docs pages to understand the full specification.
3. Check `tds-mcp` for any protocol-level implications.
4. Implement the driver API in `sqlserver-nio` first, then wire up Echo UI.
5. Update `SSMS_FEATURE_GAP.md` — move the row to **Already Built** when done.

## Enterprise Connection Properties (In Progress)

Echo is being upgraded with enterprise-grade connection configuration. The full execution plan is tracked in agent memory (`enterprise_connection_plan.md`). The implementation follows this order:

1. **Trust Server Certificate** (MSSQL) — `sqlserver-nio` + Echo
2. **PostgreSQL sslmode spectrum** — `postgres-wire` + Echo
3. **Persist all TLS settings** + connection editor UI overhaul
4. **Custom CA certificate paths** — both packages
5. **mTLS for PostgreSQL** — client cert/key support
6. **MSSQL encryption modes** — optional/mandatory/strict
7. **Kerberos** — both packages (macOS GSS.framework)
8. **Entra ID** — MSSQL OAuth2 flows
9. **HA routing** — multi-host, read-only intent, failover

**Key files involved:**
- `ConnectionConfiguration.swift` — has `useTLS`, `tlsMode`, `verifySSLCertificate` (most not yet wired)
- `SavedConnection.swift` — only persists `useTLS` currently; needs all TLS/auth fields
- `ConnectionEditorView+DetailSections.swift` — Security section UI (currently just a toggle)
- `MSSQLNIOFactory.swift` — creates MSSQL connections (passes boolean TLS)
- `PostgresDatabase.swift` — creates Postgres connections (passes boolean TLS)
- `DatabaseAuthenticationMethod.swift` — auth method enum (`sqlPassword`, `windowsIntegrated`)

**Rule:** All TLS/auth features must be implemented in the package first (`sqlserver-nio` or `postgres-wire`), then consumed by Echo. Echo never implements protocol-level logic directly.

## Activity Engine (Toolbar Progress)

Every long-running operation in Echo **must** report its progress through the `ActivityEngine`. This is the single, shared mechanism that drives the toolbar refresh button — showing a spinner while work is running, a checkmark on success, and an X on failure. No operation should run silently.

**How to wire any operation:**

```swift
let handle = activityEngine?.begin("Backup mydb", connectionSessionID: connectionSessionID)
handle?.updateMessage("Copying data…")   // optional — updates toolbar tooltip
handle?.updateProgress(0.5)               // optional — 0.0–1.0 for determinate progress
// ... do work ...
handle?.succeed()                         // or handle?.fail("reason"), or handle?.cancel()
```

**Rules:**
- Call `activityEngine?.begin()` at the start of every async operation that takes more than ~100ms (backup, restore, vacuum, reindex, integrity check, shrink, DDL apply, bulk import, schema refresh, etc.).
- Always call exactly one of `succeed()`, `fail()`, or `cancel()` when the operation finishes. Never leave a handle dangling.
- Pass the `connectionSessionID` so the toolbar filters activity per-connection. Pass `nil` only for truly global operations.
- The `activityEngine` property is `@ObservationIgnored var activityEngine: ActivityEngine?` on view models. Set it when creating the view model (see `ConnectionSession.addMSSQLMaintenanceTab()` for the pattern).
- The `OperationHandle` is non-Sendable and stays on MainActor. Do not pass it across actor boundaries.
- Existing per-view-model state (`backupPhase`, `isApplying`, `isCheckingIntegrity`, etc.) stays — it drives local sheet/dialog UI. The `ActivityEngine` is an **additional** reporting channel to the toolbar. Both must be updated.

**Key files:**
- `Shared/ActivityEngine/ActivityEngine.swift` — the engine
- `Shared/ActivityEngine/ActivityEngineTypes.swift` — `TrackedOperation`, `OperationResult`, `OperationHandle`
- `AppHost/Views/Toolbar/RefreshToolbarButton/` — consumes the engine

## Code Style

- Follow Swift API Design Guidelines.
- Prefer SwiftUI over AppKit unless AppKit is required for the specific functionality.
- Use structured concurrency (`async`/`await`, `TaskGroup`, `async let`, actors) over GCD or callbacks.
- No force-unwraps in production code.
- Prefer value types (`struct`, `enum`) for data models. Use `class` only when reference semantics or `@Observable` is required.
- Use `@Observable` (Observation framework) for new observable types, not `ObservableObject` + `@Published`.
- Use `Observations` (Swift 6.2) to stream state changes from `@Observable` types via `AsyncSequence` when appropriate.
- Mark long-lived or diagnostic `Task` instances with `Task(name:)` for debuggability.

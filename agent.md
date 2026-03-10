# Echo Project Guidelines

## Design & Platform

Echo is a **macOS-only** application. It targets **macOS 26+** exclusively — there is no iOS, iPadOS, tvOS, watchOS, or visionOS target. Never import UIKit, UIApplication, or any iOS/iPadOS-only frameworks. Use only AppKit and SwiftUI (macOS). All UI must follow Apple Human Interface Guidelines for macOS — always prefer native macOS controls, system-provided spacing, typography, and layout patterns. Never emulate non-native UI paradigms or build custom controls when a system equivalent exists.

Before writing or modifying any SwiftUI/AppKit code, use the `sosumi` MCP (`searchAppleDocumentation`, `fetchAppleDocumentation`) to verify the correct API usage, available modifiers, and recommended patterns. Use the `ref` MCP (`ref_search_documentation`, `ref_read_url`) to look up library, framework, or third-party API documentation. This applies both when reading existing code (to check correctness) and when writing new code (to ensure compliance with current documentation).

## Swift & Build

All code must be Swift 6 compatible — strict concurrency checking enabled, no data races, proper `Sendable` conformance, structured concurrency where appropriate.

Use **XcodeBuildMCP** for all build, run, and test operations. Do not use `xcodebuild` shell commands directly. Call `session_show_defaults` at the start of each session and set defaults as needed.

**This is a macOS app — use macOS workflow tools only.** Use `build_macos`, `build_run_macos`, `test_macos`, etc. Never use simulator tools (`build_sim`, `build_run_sim`, `test_sim`) — Echo has no iOS target and no simulator. Do not pass `SUPPORTED_PLATFORMS=macosx` or `SDKROOT=macosx` overrides to simulator tools as a workaround.

**Stopping the app:** Use `stop_mac_app` from XcodeBuildMCP to stop Echo. Never use `pkill` or shell commands to kill the application.

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

Echo connects to databases through first-party packages. We maintain all of these. Never add raw database driver code or database protocol logic to Echo itself. If Echo needs functionality that doesn't exist yet, implement it in the appropriate package first, then consume it from Echo.

**Commit and push rule:** Every time you modify a package, commit and push to the `dev` branch before moving on. Do not leave uncommitted package changes — Echo's SPM resolution depends on the remote state.

### EchoSense (Shared Library)
- Package: `EchoSense` at `/Users/k/Development/EchoSense`
- Shared types, protocols, and utilities used across Echo and packages.
- We maintain this package. Changes go here, not in Echo.

### PostgreSQL
- Package: `postgres-wire` at `/Users/k/Development/postgres-wire`
- We maintain this package. Fix bugs and add features there, not in Echo.
- Use the **pgEdge MCP** (`pgedge`) for interacting with Postgres instances (queries, schema inspection, etc.).

### Microsoft SQL Server
- Package: `sqlserver-nio` at `/Users/k/Development/sqlserver-nio`
- We maintain this package. Fix bugs and add features there, not in Echo.
- Protocol reference: `tds-mcp` at `/Users/k/Development/tds-mcp` — we also maintain this.
- Use the **mcpql MCP** for interacting with SQL Server instances.
- Use the **tds-mcp** for TDS protocol details, token definitions, data type encoding, and packet structure.
- When something isn't working with SQL Server communication, use **wiremcp** to capture and analyze packets. Update both `tds-mcp` (with protocol findings) and `sqlserver-nio` (with the fix).

### Workflow for database issues
1. Reproduce the problem in Echo.
2. Narrow down whether the issue is in the package or in Echo's usage of it.
3. If it's a package issue, switch to the package directory, fix it there, and verify.
4. Commit and push the package fix to `dev`.
5. Update Echo to consume the fix.

## GitHub

Use the **GitHub MCP** (`mcp__github__*`) for all GitHub interactions — creating PRs, issues, reading file contents, searching code, etc. Do not use `gh` CLI unless the MCP cannot accomplish the task.

## Documentation Verification

Every time you open or modify a file that uses Apple frameworks (SwiftUI, AppKit, Foundation, Combine, etc.), use `sosumi` to look up the relevant APIs. Confirm:
1. The API is not deprecated for macOS 26.
2. The usage matches Apple's recommended patterns.
3. Newer, better alternatives haven't been introduced.

This is not optional — treat it as a pre-flight check before any code change.

## Testing

Everything must be testable — in Echo, EchoSense, sqlserver-nio, and postgres-wire. Every function, view, and component should have tests that can conclusively determine whether it works. Tests must be added to GitHub Actions to run automatically when a commit is pushed to the `dev` branch.

When adding or modifying functionality, write or update the corresponding tests. Do not consider a feature complete without test coverage.

## Design Tokens

Never hardcode colors, spacing, or fonts. Every visual value must reference a design token from `Echo/Sources/Shared/DesignSystem/`.

- **Colors** → `ColorTokens` in `ColorToken.swift` — use `ColorTokens.Background.primary`, `ColorTokens.Text.secondary`, `ColorTokens.Status.error`, etc. All colors derive from system semantic colors.
- **Spacing** → `SpacingTokens` in `SpacingToken.swift` — use `SpacingTokens.xs` (8pt), `.sm` (12pt), `.md` (16pt), `.lg` (24pt), etc. Never write raw `CGFloat` padding/spacing values.
- **Typography** → `TypographyTokens` in `TypographyToken.swift` — use semantic styles (`TypographyTokens.body`, `.headline`, `.caption`) or fixed-size styles (`.detail` 11pt, `.standard` 13pt, `.prominent` 14pt, etc.). Never write `.font(.system(size: N))` directly.
- **Components** → Reusable design system components live in `DesignSystem/Components/` (e.g., `CountBadge`, `EmptyStatePlaceholder`, `SidebarSectionHeader`, `ToolbarAddButton`, `TintedIcon`). Use these instead of reimplementing common patterns.

## Code Architecture

### File Size Limits
- **Views:** 200 lines max.
- **ViewModels:** 300 lines max.
- **All other files:** 500 lines max.

If a file exceeds these limits, split it. Extract logical sections into focused extensions or separate files.

### One File = One Responsibility
Each file must have a single, clear purpose. Do not combine unrelated logic in one file. If a file does two things, split it into two files.

### Naming
No vague names. Everything must be named in a standardized, obvious way. Never use `Helper`, `Utility`, `Manager`, `Handler`, `Service`, `Coordinator`, or similar generic suffixes. Name types and functions for what they actually do.

### Reusability
Every UI component must be reusable and modular. If you build a control, list row, or section, design it so it can be used in multiple contexts. Extract common patterns into `DesignSystem/Components/`.

### Match Existing Patterns
Follow the patterns already established in the codebase. Do not invent new architectural patterns, naming conventions, or structural approaches. When in doubt, find a similar existing implementation and follow its structure.

## Code Style

- Follow Swift API Design Guidelines.
- Prefer SwiftUI over AppKit unless AppKit is required for the specific functionality.
- Use structured concurrency (`async`/`await`, `TaskGroup`, actors) over GCD or callbacks.
- Mark types as `Sendable` where appropriate; use `@MainActor` for UI code.
- No force-unwraps in production code.

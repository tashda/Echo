# Echo Project Guidelines

## Design & Platform

Echo is a **macOS-only** application. It targets **macOS 26+** exclusively — there is no iOS, iPadOS, tvOS, watchOS, or visionOS target. Never import UIKit, UIApplication, or any iOS/iPadOS-only frameworks. Use only AppKit and SwiftUI (macOS). All UI must follow Apple Human Interface Guidelines for macOS — use system-provided controls, spacing, typography, and layout patterns. Never emulate non-native UI paradigms.

Before writing or modifying any SwiftUI/AppKit code, use the `sosumi` MCP (`searchAppleDocumentation`, `fetchAppleDocumentation`) to verify the correct API usage, available modifiers, and recommended patterns. This applies both when reading existing code (to check correctness) and when writing new code (to ensure compliance with current documentation).

## Swift & Build

All code must be Swift 6 compatible — strict concurrency checking enabled, no data races, proper `Sendable` conformance, structured concurrency where appropriate.

Use **XcodeBuildMCP** for all build, run, and test operations. Do not use `xcodebuild` shell commands directly. Call `session_show_defaults` at the start of each session and set defaults as needed.

**This is a macOS app — use macOS workflow tools only.** Use `build_macos`, `build_run_macos`, `test_macos`, etc. Never use simulator tools (`build_sim`, `build_run_sim`, `test_sim`) — Echo has no iOS target and no simulator. Do not pass `SUPPORTED_PLATFORMS=macosx` or `SDKROOT=macosx` overrides to simulator tools as a workaround.

## Self-Verification Workflow

After every code change (feature, fix, or refactor), you MUST verify your work using XcodeBuildMCP. Do not consider a task complete until you have confirmed it works. Follow this loop:

1. **Build** — Use `build_macos` to compile. Fix all errors before proceeding.
2. **Run** — Use `build_run_macos` to launch Echo. Confirm it starts without crashes.
3. **Inspect logs** — Use `start_sim_log_cap` / `stop_sim_log_cap` or launch with log capture to check for runtime warnings, assertion failures, or unexpected behavior.
4. **Debug** — If something is wrong, use LLDB tools: attach to the process, set breakpoints at the relevant code, inspect variables, and step through execution to find the root cause. Do not guess — use the debugger.
5. **Screenshot / UI snapshot** — For any UI change, take a `screenshot` and/or `snapshot_ui` to verify the visual result matches expectations.
6. **Iterate** — If any step fails, fix the issue and restart from step 1.

This is not optional. Never submit a change you haven't built and run successfully.

## Database Packages — Ownership & Boundaries

Echo connects to databases through first-party packages. Never add raw database driver code to Echo itself. If Echo needs database functionality that doesn't exist yet, implement it in the appropriate package first, then consume it from Echo.

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
4. Update Echo to consume the fix.

## GitHub

Use the **GitHub MCP** (`mcp__github__*`) for all GitHub interactions — creating PRs, issues, reading file contents, searching code, etc. Do not use `gh` CLI unless the MCP cannot accomplish the task.

## Documentation Verification

Every time you open or modify a file that uses Apple frameworks (SwiftUI, AppKit, Foundation, Combine, etc.), use `sosumi` to look up the relevant APIs. Confirm:
1. The API is not deprecated for macOS 26.
2. The usage matches Apple's recommended patterns.
3. Newer, better alternatives haven't been introduced.

This is not optional — treat it as a pre-flight check before any code change.

## Design Tokens

Never hardcode colors, spacing, or fonts. Every visual value must reference a design token from `Echo/Sources/Shared/DesignSystem/`.

- **Colors** → `ColorTokens` in `ColorToken.swift` — use `ColorTokens.Background.primary`, `ColorTokens.Text.secondary`, `ColorTokens.Status.error`, etc. All colors derive from system semantic colors.
- **Spacing** → `SpacingTokens` in `SpacingToken.swift` — use `SpacingTokens.xs` (8pt), `.sm` (12pt), `.md` (16pt), `.lg` (24pt), etc. Never write raw `CGFloat` padding/spacing values.
- **Typography** → `TypographyTokens` in `TypographyToken.swift` — use semantic styles (`TypographyTokens.body`, `.headline`, `.caption`) or fixed-size styles (`.detail` 11pt, `.standard` 13pt, `.prominent` 14pt, etc.). Never write `.font(.system(size: N))` directly.
- **Components** → Reusable design system components live in `DesignSystem/Components/` (e.g., `CountBadge`, `EmptyStatePlaceholder`, `SidebarSectionHeader`, `ToolbarAddButton`, `TintedIcon`). Use these instead of reimplementing common patterns.

## Code Style

- Follow Swift API Design Guidelines.
- Prefer SwiftUI over AppKit unless AppKit is required for the specific functionality.
- Use structured concurrency (`async`/`await`, `TaskGroup`, actors) over GCD or callbacks.
- Mark types as `Sendable` where appropriate; use `@MainActor` for UI code.
- No force-unwraps in production code.

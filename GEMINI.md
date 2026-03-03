# Echo Project Overview (Rebase 2026)

The project "Echo" is a macOS application developed using Swift and SwiftUI. It functions as a multi-database client (PostgreSQL, MySQL, SQLite, and Microsoft SQL Server). The application leverages SwiftNIO for database interactions and includes a local Swift package, `EchoSense`, for schema metadata management.

## Core Mandates:
*   **Documentation Compliance:** 
    - **Platform-Native:** Before refactoring SwiftUI, Concurrency, or AppKit/UIKit layers, use `sosumi` to verify compliance with official Apple Documentation and HIG.
    - **Domain-Specific:** For SQL logic, Database protocols, and third-party tools (like `sqruff`), use `web_fetch` or `google_web_search` to ensure industry-standard implementations.
*   **Protocol-First Development:** Every service, repository, or data provider must define a protocol before implementation to facilitate testing and mocking.
*   **Naming Clarity:** Use standardized, obvious names. Ban vague suffixes such as `Helper`, `Utility`, `Manager`, or `Service`. If a type is a "Manager," call it what it actually does (e.g., `ConnectionCoordinator`).
*   **Testing Coverage:** Every component (function, view, logic) must be testable and tested across Echo, `sqlserver-nio`, `Postgres-wire`, and `EchoSense`.

## File & Code Standards:
*   **Size Limits:**
    - Maximum file size: 500 lines.
    - View files: Maximum 200 lines.
    - ViewModels: Maximum 300 lines.
    - Files exceeding these limits MUST be split before merging.
*   **Single Responsibility:** Each file must handle exactly one responsibility. (e.g., separate formatting from network logic).
*   **Design Tokens:** NEVER hardcode colors, spacing, or fonts. Use design tokens: `Colors.textPrimary`, `Spacing.md`, etc.
*   **Modular UI:** Extract reusable components into a dedicated shared directory (e.g., `UI/Shared/Components/`), ensuring they are decoupled from feature-specific logic.

## Application Architecture:
*   **MVVM/Coordinator:** Follows MVVM with an `AppCoordinator` for state management.
*   **Theming:** Simplified Light/Dark mode implementation. Only accent color and editor font are user-configurable.
*   **Formatting:** `sqruff` is currently used but is under review for potential replacement or improvement.
*   **Package Simplification:** `sqlserver-nio`, `Postgres-wire`, and `EchoSense` are being refactored for simplicity and ease of feature additions.

## Tooling & Workflows:
*   **Apple Documentation:** Utilize `sosumi` to access official Apple Documentation (via `fetchAppleDocumentation` and `searchAppleDocumentation`) for platform-native implementations and best practices.
*   **Database Validation:** Use Gemini PostgreSQL and SQL extensions to interact with test servers for validation.
*   **Incremental Commits:** Commit frequently for every logical change. Each commit message must precisely describe "what" and "why" to provide a clear audit trail for PRs.

## Building and Running:
This is an Xcode project. All builds must be performed via the CLI:

```bash
xcodebuild -project Echo.xcodeproj -scheme Echo -destination "platform=macOS" build | xcbeautify
```

## Engineering Standards:
*   **SwiftUI:** Primary UI framework.
*   **Swift 6 Concurrency:** Mandatory adherence to data-race safety and modern concurrency rules.
*   **NIO:** Core database connectivity layer.

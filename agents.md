# Repository Guidelines

## Project Structure & Module Organization
- `Echo/Sources/Presentation/Views/`: Primary SwiftUI layer grouped by feature (e.g. `Sheets/ManageProjectsSheet.swift`, `ResultView/QueryResultsSection.swift`).
- `Echo/Sources/Domain/`: Business logic models (`AppModel.swift`, `Project.swift`) and persistence helpers.
- `Echo/Sources/Infrastructure/`: Database drivers and persistence services, including `ProjectStore.swift`.
- `EchoUITests/`, `EchoTests/`: UITest and unit-test bundles that ship with the Xcode project.
- `Docs/`: Supplemental references (UX notes, workflows, architecture diagrams).

## Build, Test, and Development Commands
- `xcodebuild -project Echo.xcodeproj -scheme Echo -configuration Debug build` — Resolve packages and build the macOS app.
- `xcodebuild test -project Echo.xcodeproj -scheme EchoTests` — Run unit tests headlessly.
- `xed Echo.xcodeproj` — Open the workspace in Xcode for iterative development.
- Use `xcodebuild test -scheme EchoUITests -only-testing:EchoUITests/ManageProjectsTests` to target specific UI flows when editing sheets.

## Coding Style & Naming Conventions
- Swift files use 4-space indentation with trailing commas permitted. Prefer `extension` blocks for protocol conformances.
- Components follow `FeatureView.swift` naming; collocate small helper views (e.g. `ProjectRow`) with their parent when they are not reused.
- Use `camelCase` for functions/variables and `PascalCase` for types. Asset catalogs use `kebab.case` or dot-separated names that match SF Symbol aliases.

## Testing Guidelines
- Unit tests rely on XCTest; adopt `test_WhenCondition_ExpectResult` naming for clarity.
- UI flows live in XCUITest suites inside `EchoUITests`; capture regressions by adding scenarios when tweaking major dialogs.
- Run targeted suites from Xcode (`Product > Test`) or via `xcodebuild test -only-testing:Module/TestCase`.

## Commit & Pull Request Guidelines
- Commit messages are imperative and scoped (e.g. `Refine manage projects sheet layout`). Group related edits and avoid sweeping refactors in a single commit.
- PRs should describe intent, list test commands (including `xcodebuild` outputs), link issues, and attach screenshots for UI work.
- Rebase onto `master` before requesting review and keep CI green by resolving build/test failures locally.

# Analysis Report - Rebase 2026

## Project Overview
The "Echo" project (including `sqlserver-nio`, `Postgres-wire`, and `EchoSense`) is a complex macOS database client that has outgrown.  its initial architecture. This report outlines the current state, identifies key issues, and proposes a roadmap for a complete refactoring to improve maintainability and simplify future development.

## 1. Core Issues Identified

### 1.1 Large Files (Violation of <500 lines rule)
Many files exceed the new strict limits. The most critical offenders are:
- `AppModel.swift` (3762 lines) - Massive catch-all for application state and dependencies.
- `AppearanceSettingsView.swift` (3390 lines) - Complex UI for theming that is being removed.
- `QueryResultsTableView.swift` (3283 lines) - Handles complex data rendering.
- `SQLEditorView.swift` (3264 lines) - Massive editor view with inline logic.
- `WorkspaceTab.swift` (2384 lines) - Complex state management for tabs.
- `SuggestionBuilder.swift` (1306 lines) in `EchoSense` - Heavy autocomplete logic.
- `SQLAutoCompletionEngine.swift` (1165 lines) in `EchoSense` - Heavy autocomplete logic.

### 1.2 Multi-Responsibility Classes
- `AppModel.swift`: Manages connections, projects, navigation, global settings, search caches, and multiple services. It violates the Single Responsibility principle significantly.
- `ThemeManager.swift`: Handles theme selection, system appearance observation, color computation, and palette management.

### 1.3 Hardcoded Styling
- Widespread use of `Color.primary`, `.opacity()`, and `Color(red:green:blue:)`.
- Lack of a centralized design token system (Spacing, Colors, Typography).
- Hardcoded padding and spacing throughout views.

### 1.4 Naming Inconsistencies
- Frequent use of vague suffixes: `Manager`, `Helper`, `Utility`, `Service`.
- Examples: `ThemeManager`, `KeychainHelper`, `TabManager`, `ResultSpoolManager`, `DiagramCacheManager`.

### 1.5 Theming Engine Complexity
- The current engine supports custom themes and complex palettes. This is being removed in favor of a simpler Light/Dark system with configurable accent colors.

## 2. Refactoring Roadmap

### Phase 1: Infrastructure & Foundation
1.  **Design Tokens:** Implement a `Design` module (e.g., `Core/Design/`) with `Colors`, `Spacing`, and `Typography` tokens.
2.  **Shared UI Components:** Identify and move reusable components to a centralized directory (e.g., `UI/Shared/Components/`).
3.  **Protocol Definitions:** Define protocols for all existing services to enable mocking and unit testing.

### Phase 2: Domain Logic Decomposition
1.  **Decompose `AppModel`:** Split into specialized state objects (e.g., `ConnectionCoordinator`, `ProjectRepository`, `NavigationState`).
2.  **Modularize `EchoSense`:** Break down `SuggestionBuilder` and `SQLAutoCompletionEngine` into scenario-specific providers.
3.  **Renaming Strategy:** Rename all "Managers" and "Helpers" to describe their specific intent (e.g., `TabManager` -> `TabCoordinator`).

### Phase 3: Theming Removal
1.  **Deprecate `ThemeManager`:** Replace with a system-aware light/dark logic.
2.  **Remove `AppearanceSettingsView` logic:** Strip out custom theme management, keeping only accent color and font selection.
3.  **Update Views:** Migrate all views to use the new Design Tokens instead of hardcoded values.

### Phase 4: File Splitting & Testing
1.  **Surgical Splitting:** Systematically break down files over 500 lines.
2.  **Unit Tests:** Implement tests for every new protocol and implementation across Echo and NIO packages.

## 4. Execution Steps (Step-by-Step)

### Step 0: Documentation Baseline (sosumi) [COMPLETED]
- Established mandate for platform and domain research.
- Integrated Apple Documentation verification into the workflow.

### Step 1: Design System Initialization [COMPLETED]
- Created `Echo/Sources/UI/Shared/Design/` with `ColorToken.swift`, `SpacingToken.swift`, and `TypographyToken.swift`.
- Extracted and refactored `SidebarSectionHeader`, `ToolbarTitleWithSubtitle`, and `ToolbarAddButton` into shared components.
- Verified all components use platform-native semantic colors via `ColorTokens`.

### Step 2: Theming Engine Removal [COMPLETED]
- Simplified `ThemeManager.swift` to track only `ColorScheme` and `AccentColor`.
- Removed complex `activeTheme` and `SQLEditorTheme` manual overrides.
- Simplified `AppearanceSettingsView` to core configuration (Mode, Accent, Font).
- Refactored `QueryResultsSection`, `QueryResultsTableView`, `QueryResultsGridView`, `ResultMessagesView`, and `WorkspaceContentView` to use Design Tokens.
- Verified successful CLI build for macOS target.

### Step 3: AppModel Decomposition [IN PROGRESS]
- **Sub-step 3.1: Project Domain** [COMPLETED]
    - Created `ProjectRepository` and modern `@Observable` `ProjectStore`.
    - Migrated persistence logic to `ProjectDiskStore`.
    - Refactored `NewProjectSheet` and `ManageProjectsSheet`.
- **Sub-step 3.2: Connection Domain** [COMPLETED]
    - Created `ConnectionRepository` and modern `@Observable` `ConnectionStore`.
    - Renamed legacy disk stores to `ConnectionDiskStore`, `FolderDiskStore`, and `IdentityDiskStore`.
    - Successfully bridged `AppModel` to use the new store.
- **Sub-step 3.3: Navigation & Tab Domain** [COMPLETED]
    - Created `NavigationStore` and `TabStore`.
    - Refactored `EchoApp` and `WorkspaceView` to use `@Environment` stores.
    - Resolved `Task` and `WindowGroup` ambiguity conflicts.
- **Sub-step 3.4: Domain Logic Separation (Diagrams & Spooling)** [COMPLETED]
    - Created `DiagramCoordinator` and `ResultSpoolCoordinator`.
    - Extracted ~1000 lines of complex layout and prefetch logic from `AppModel`.
- **Sub-step 3.5: Identity & Auth Extraction** [TODO]
    - Create `IdentityRepository` for Keychain and credential resolution.
    - Remove all sensitive auth logic from `AppModel`.
- **Sub-step 3.6: Schema Management Extraction** [TODO]
    - Create `SchemaDiscoveryService` and `SchemaComparator`.
    - Relocate metadata fetching and diffing logic from `AppModel`.
- **Sub-step 3.7: Bookmark & History Extraction** [TODO]
    - Create `BookmarkRepository` and `HistoryRepository`.
- **Sub-step 3.8: Systematic UI Migration** [TODO]
    - Refactor all SwiftUI Views to use specific modular `@Observable` stores.
    - Replace `@EnvironmentObject(AppModel.self)` with specific `@Environment` calls.
- **Sub-step 3.9: Final AppModel Pruning** [TODO]
    - Remove all bridge/legacy properties.
    - Verify `AppModel.swift` is < 500 lines.

### Step 4: EchoSense Modularization [COMPLETED]
- **Research:** Researched Apple's suggestion patterns and modular architecture.
- **Decomposition:** Split `SuggestionBuilder.swift` into 9 modular providers (Keyword, Schema, Table, Column, Join, Star, Function, Parameter, Snippet).
- **Abstractions:** Introduced `SQLSuggestionProvider` and `SQLProviderContext` to decouple logic.
- **Clean Code:** Extracted `AliasGenerator` and `SQLKeywordProvider` to dedicated files.
- **Result:** Drastically reduced the size of individual components and improved maintainability.

### Step 5: Package Refactoring (NIO Packages)
- **Research:** Use `sosumi` to research SwiftNIO integration best practices and Swift 6 Concurrency (Sendability) for network layers.
- Apply protocol-first patterns and standardize naming.

### Step 6: Formatting Tool Evaluation
- **Research:** Use `sosumi` and external docs to evaluate SQL formatting tools and their integration with native macOS editors.

### Step 7: Final File Splitting & Validation
- Audit line counts and split as necessary.
- **Validation:** Compare the final structure against Apple's "Modular App" best practices.
- Ensure 100% test coverage for core protocols.

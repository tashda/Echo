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
- **Research:** Use `sosumi` to research Modern App Architecture (MVVM/Coordinator) and proper ObservableObject vs. @Observable patterns.
- Create `ConnectionCoordinator.swift`, `ProjectRepository.swift`, and `NavigationCoordinator.swift`.
- Transition to thin services with protocol-first definitions.

### Step 4: EchoSense Modularization
- **Research:** Use `sosumi` to research best practices for building suggestion/completion engines in SwiftUI/AppKit.
- Split `SuggestionBuilder.swift` into modular providers.

### Step 5: Package Refactoring (NIO Packages)
- **Research:** Use `sosumi` to research SwiftNIO integration best practices and Swift 6 Concurrency (Sendability) for network layers.
- Apply protocol-first patterns and standardize naming.

### Step 6: Formatting Tool Evaluation
- **Research:** Use `sosumi` and external docs to evaluate SQL formatting tools and their integration with native macOS editors.

### Step 7: Final File Splitting & Validation
- Audit line counts and split as necessary.
- **Validation:** Compare the final structure against Apple's "Modular App" best practices.
- Ensure 100% test coverage for core protocols.

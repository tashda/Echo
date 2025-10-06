# Echo Agent Fixes

## QueryEditor White Window
- Symptom: running a query replaces the UI with a blank white window.
- Fix: ensure `QueryEditorContainer` restores the themed backgrounds by setting the container, editor, and results sections to `themeManager.windowBackground` (see `Echo/Sources/Presentation/Views/TabbedQueryView.swift`).
- Bonus: keep `WorkspaceContentView` painting `themeManager.windowBackground` so the host view never falls back to the default white.
- Context: regression happens when those backgrounds are left clear.

## Settings Window Overhaul
- Replaced the legacy SwiftUI `Settings` scene with a standalone `Window` scene implemented in `Echo/Sources/Presentation/Views/SettingsWindow.swift`.
- Layout now mirrors Apple’s Landmarks sample: native `NavigationSplitView` with sidebar selection driving a `NavigationStack` detail pane.
- Existing sections (`Appearance`, `Application Cache`) were moved unchanged into the new container; new sections should follow the same pattern via `SettingsView.SettingsSection`.

## SQL Editor Keyword Styling
- Palettes now expose a single `keyword` color (`SQLEditorPalette.TokenColors`) instead of separate primary/secondary variants; decoding handles legacy palettes automatically.
- Keyword highlighting uses a unified keyword list and applies a bold font across all palettes (`SQLEditorView.highlightSyntax`).
- Palette editor/preview updated to reflect the new semantics, and bold keywords show up in live previews.

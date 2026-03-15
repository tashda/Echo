# Code Architecture Violations

Last updated: 2026-03-15

## Status: Nearly Clean

All major violations have been resolved.

### Files Over Line Limits — NONE REMAINING

All Views are at or under 200 lines, ViewModels under 300, other files under 500.

### Explicit @MainActor — NO VIOLATIONS

All remaining `@MainActor` annotations are justified:
- `@Observable @MainActor` on types that need explicit isolation
- `@MainActor` on NSWindowController/NSObject subclasses (AppKit requirement)

### ObservableObject → @Observable Migration — COMPLETE

All 28 types migrated. No ObservableObject usage remains.

### Forbidden Naming Suffixes — NONE REMAINING

All Coordinator/Service/Helper/Handler/Manager types renamed to domain-specific names.
`SQLLayoutManager` subclasses `NSLayoutManager` (AppKit class) — name is correct.

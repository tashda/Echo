# Code Style Violations

Last updated: 2026-03-15

## Status: Nearly Clean

All major violations have been resolved. Remaining items are either acceptable patterns or minor edge cases.

### DispatchQueue Usage (7 files, acceptable)

These are legitimate uses that don't have clean structured concurrency alternatives:

| Location | Reason |
| :--- | :--- |
| ResultStreamBatchWorker.swift | `concurrentPerform` for CPU-bound parallel row formatting |
| SQLFormatter.swift | Serial queue protecting non-thread-safe JSContext |
| ClipboardHistoryStore.swift | Serial queue for background file I/O with coalescing |
| AutoCompletionListView.swift | `asyncAfter` for UI timing delay |
| SQLTextView+Highlighting.swift | `asyncAfter` for syntax highlighting debounce |
| SQLTextView+CompletionUI.swift | `asyncAfter` for UI timing |

### Hardcoded Fonts (acceptable edge cases)

| Location | Reason |
| :--- | :--- |
| TintedIcon.swift | Configurable `size` parameter — no single token fits |
| AutoCompletionListView.swift | AppKit `NSFont` for text measurement, not SwiftUI |
| DatabaseObjectColumnRow.swift | Variable icon sizes (10/5pt) — no single token fits |
| MonospacedFontPicker.swift | Font picker preview — intentionally uses selected font |

### Hardcoded Colors (acceptable edge cases)

| Location | Reason |
| :--- | :--- |
| PlatformColorConverter.swift | Color conversion utility, not UI hardcoding |
| ColorRepresentable.swift | RGBA data model, not UI hardcoding |
| AppearanceSettingsView+Components.swift | Color picker UI — shows literal color values by design |
| TabChromeSupport.swift | `lighten`/`darken` color manipulation utilities |

### ObservableObject — NONE REMAINING
### Force Unwraps — NONE REMAINING
### Forbidden Naming Suffixes — NONE REMAINING (SQLLayoutManager subclasses NSLayoutManager)

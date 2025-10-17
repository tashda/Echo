# Autocomplete System Reference

_Last updated: 2026-02-14_

This document captures the complete set of rules, scenarios, and supporting tooling that drive Echo’s SQL autocomplete experience across the workspace editor and the Autocomplete Management window.

---

## 1. Architecture Overview

| Layer | Responsibility | Key Types / Files |
| --- | --- | --- |
| **Triggering & Query Analysis** | Converts the user’s caret location and token into a `SQLAutoCompletionQuery` describing context, scope, and replacement range. | `SQLTextView` (`Echo/Sources/Presentation/Views/Editor/SQLEditorView.swift`) |
| **Suggestion Generation** | Produces candidate completions grouped by section (schemas, objects, columns, functions, keywords) using engine metadata and current scope. | `SQLAutoCompletionEngine` inside `SQLTextView` |
| **Suppression & Follow-up Detection** | Decides when to suppress the popover, maintain the glow indicator, or surface fallback suggestions. | `SQLAutocompleteRuleEngine` (`Echo/Sources/Presentation/Views/Editor/Autocomplete/SQLAutocompleteRuleEngine.swift`) |
| **Presentation** | Renders popovers, handles keyboard navigation, and shows the suppression indicator glow. | `SQLAutoCompletionController`, `CompletionAccessoryView`, `GlowFrameView` |
| **Diagnostics & Tooling** | Hosts a management editor mirroring the active connection, records rule traces, and stores rule notes. | `AutocompleteManagementRootView` (`Echo/Sources/Presentation/Views/AutocompleteManagement/AutocompleteManagementView.swift`) |

All entry points funnel through `SQLTextView`, ensuring the same rule set applies in both the main workspace editor and the diagnostics window.

---

## 2. Triggering & Query Analysis

### 2.1 Trigger Paths
- **Automatic triggers**: keystrokes that mutate the document schedule asynchronous completion work items.
- **Manual triggers**: `⌘.` (Command+Period) bypasses suppression and forces an immediate refresh using any cached/fallback suggestions.
- **Cancellation**: moving the caret, deleting beyond the token range, or ESC closes the popover and resets glow state.

### 2.2 Query Construction (`SQLTextView.makeCompletionQuery()`)

Each trigger builds a `SQLAutoCompletionQuery` with:
- `token` / `prefix`: the current symbol fragment.
- `pathComponents`: preceding identifier segments before the current fragment.
- `replacementRange`: portion of the token to overwrite.
- `precedingKeyword` / `precedingCharacter`: lexical clues (e.g., `FROM`, `WHERE`, commas).
- `focusTable` / `tablesInScope`: extracted aliases and table references before and after the caret.

Context keywords derive from `SQLTextView.objectContextKeywords` and `SQLTextView.columnContextKeywords`, backed by `SQLAutocompleteHeuristics`.

---

## 3. Suggestion Generation (`SQLAutoCompletionEngine`)

### 3.1 Inputs
- The current `SQLAutoCompletionQuery`.
- The active `SQLEditorCompletionContext` (database type, selected database, default schema, cached `DatabaseStructure`).
- Display options (e.g., whether to offer table alias shortcuts).

### 3.2 Sections & Logic

| Section | Rules |
| --- | --- |
| **Schemas** | Emitted when context expects a schema (e.g., first segment before a dot). Filters by database and prefix. |
| **Tables / Views / Materialized Views** | Derived from structure metadata filtered by context (object keywords, path components). Titles favour bare object names; subtitles cover schema/database. |
| **Columns** | Scoped to tables inferred from aliases or explicit paths. Alias-qualified variants are emitted first. Falls back to structure metadata if runtime engine lacks column info. |
| **Functions** | Combines structure-backed functions with built-in lists per database flavour. |
| **Keywords** | Static list filtered by context and prefix. |

### 3.3 Filtering & Ranking
- Suggestions filtered using prefix, context, and scope.
- Duplicate detection uses canonical `schema.object.column` keys.
- Section limits: tables/views (40), columns (60), functions (40).

---

## 4. Suppression & Follow-up Rules (`SQLAutocompleteRuleEngine`)

### 4.1 Suppression Goals
Prevent the popover from reappearing after a committed suggestion unless additional alternatives or column follow-ups exist, while signalling availability via the glow indicator and `⌘.`.

### 4.2 Evaluation Flow
1. **Input sanitisation**: trim whitespace, reject trailing-dot tokens, normalise identifiers.
2. **Decomposition**: derive `(database?, schema?, object)` components.
3. **Suggestion match**: prefer live suggestions; fallback to structure metadata if needed.
4. **Context check**: detect object vs column context through keywords and token paths.
5. **Follow-up detection**:
   - Alternative objects (tables/views in same scope but different names).
   - Column availability from suggestions or metadata.
6. **Structure fallback**: if runtime suggestions lack columns, consult cached structure.
7. **Decision**: register suppression if any follow-ups exist; otherwise allow the controller to remain hidden.

### 4.3 Registered Suppressions
- After accepting non-column suggestions, suppressions store the canonical text and range so glow + `⌘.` remain available.
- Suppressions invalidate when text diverges, range becomes invalid, or follow-ups vanish.

### 4.4 Fallback Suggestions
- When only structure metadata exists, `fallbackSuggestions` rebuilds a table + column list so `⌘.` produces useful completions.

### 4.5 Command+Period (`⌘.`)
- Checks suppression around the caret, reopens completions immediately, and prefers fallback data when present.

---

## 5. Glow Indicator Logic

- Glow appears when the active suppression reports follow-ups.
- Hovering intensifies the glow; clicking or `⌘.` reopens completions.
- The trailing badge icon was removed—only the gradient frame remains to avoid obscuring text.
- Glow hides as soon as the popover is visible or when suppression invalidates.

---

## 6. Key Scenarios

| Scenario | Example Input | Expected Result |
| --- | --- | --- |
| **Schema-only match** | `SELECT * FROM public.` | Popover suppressed (incomplete identifier), no glow until object typed. |
| **Additional tables available** | `SELECT * FROM public.fi` | After choosing `public.fixture_event_live`, glow remains; `⌘.` surfaces other `public.fi*` tables/views. |
| **Column context** | `WHERE fix.` | Glow appears if columns exist; `⌘.` lists column completions. |
| **No follow-ups** | `FROM system.singleton` | Suppression skipped; glow hidden and popover stays closed. |
| **Quoted identifiers** | `FROM "Public"."Fixture_Event_Live"` | Normalisation removes quotes and matches lowercased identifiers. |
| **Structure fallback** | Engine returns nothing but structure cached | `⌘.` uses structure-driven fallback suggestions. |

---

## 7. Autocomplete Management Window

Accessible from **Help → Autocomplete Management…**:

1. **Editor Panel** replicates the main editor but mirrors the active connection context.
2. **Trace Panel** lists rule evaluation steps; “Freeze Trace” locks the latest trace while you experiment.
3. **Rule Definitions** offers editable notes (persisted in `UserDefaults`) for each heuristic.

Guidance banners appear when no connection is active or structure metadata is unavailable.

---

## 8. Change Checklist

Before modifying autocomplete code:

1. Review this document and run through the scenario table to confirm which behaviours might be affected.
2. Validate glow/suppression logic, `⌘.` recall, and management trace output after your changes.
3. Update this documentation with new rules, keywords, or scenarios introduced.

---

## 9. Reference Tables

### 9.1 Context Keywords

| Kind | Keywords (lowercased) |
| --- | --- |
| Object context | `from`, `join`, `inner`, `left`, `right`, `full`, `outer`, `cross`, `update`, `into`, `delete` |
| Column context | `select`, `where`, `on`, `and`, `or`, `having`, `group`, `order`, `by`, `set`, `values`, `case`, `when`, `then`, `else`, `returning`, `using` |

### 9.2 Glow Guidelines

| Check | Description |
| --- | --- |
| Valid token | Non-empty, trimmed, not ending with `.` |
| Match source | Prefer suggestion match; fallback to structure metadata |
| Follow-ups | Alternate objects or available columns required |
| Fallback | Structure metadata fills gaps when engine lacks column hints |
| Failure | No follow-ups → no suppression, no glow |

---

## 10. Revision Log

| Date | Summary |
| --- | --- |
| 2026-02-14 | Initial comprehensive documentation pass and management workflow requirements. |

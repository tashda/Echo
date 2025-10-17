# Instant Diagram Prefetch Strategy

Here’s how I’d approach “instant diagrams” without making the app feel heavier than it needs to:

## Prefetch Strategy
- Make it opt-in per connection (or per project). Many databases have thousands of tables; auto-prefetching everything could chew through time and memory with no benefit.
- When enabled, fetch diagrams lazily in the background with a queue: prioritise tables the user has opened recently, then expand outward. Persist the resulting `SchemaDiagramViewModel` (or just its raw `TableStructureDetails`) in a lightweight cache folder. That gives you true instant open after the first pass, but keeps workloads predictable.
- Store a simple checksum (for example, a sorted column list plus foreign-key metadata) alongside each cached diagram so you can detect drift quickly and avoid unnecessary redraws.

## Change Detection / Refresh
- Databases do not always surface table-change notifications. You will likely need a “last known definition” hash and invalidate when it changes. Update triggers:
  1. user-initiated (manual Refresh button),
  2. structural actions taken inside Echo (we know we just altered the table),
  3. scheduled background sweep (nightly or off-peak) if prefetch is on.
- When a hash mismatch is detected, re-fetch in the background, update cache, and if the diagram tab is open, refresh with a brief non-blocking toast (“Diagram updated for public.fixture”). If the tab is closed, just mark it dirty so the next open shows fresh data.

## Performance and Resource Controls
- Use a bounded cache (for example, LRU by “diagram weight”) so large schemas do not balloon storage. Allow the user to clear the diagram cache from settings.
- Provide sliders or toggles:
  - “Prefetch diagrams automatically” (off, recent tables only, full prefetch).
  - “Background refresh interval” (never, daily, weekly).
  - “Render relations” (perhaps hide edges for huge diagrams to avoid heavy draws).
- Persist only the structural model; re-render nodes and arrows on demand. Rendering the actual SwiftUI view ahead of time is not beneficial, but caching `SchemaDiagramViewModel` gives you immediate paint.

## User Experience
- Keep the loading overlay we added for first-time builds; hide it instantly when cached data exists.
- Expose a refresh button in the diagram toolbar. If you plan selective refresh (“only changed tables”), make it the default action; otherwise offer a split-button with “Refresh diagram” and a secondary “Refresh everything”.
- Surface progress somewhere (status bar or background task monitor) so the user knows a prefetch sweep is underway but is not blocked.

## Implementation Notes
- The existing schema loader already consolidates foreign-key dependencies. Enhance it to write and read from cache (for example, JSON plus gzip). Use connection ID plus schema plus table name as keys, and include the database version if available.
- Background work should respect the user’s bandwidth and resource preferences—use `Task.detached` with a low-QoS executor and throttle concurrently to avoid hammering the database.
- Consider invalidating cache entries if connection credentials change or the database version increments.

## Summary
In summary: yes, prefetching and background updates are feasible, but they should be opt-in, bounded, and transparent. Focus on caching the structural data, provide quick feedback for initial loads, and give users control over when you spend resources.

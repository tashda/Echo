PostgresWire + PostgresKit
=================================

Overview
- PostgresWire is a thin, SwiftNIO-based wrapper over Vapor's PostgresNIO, exposing a small, focused interface for connections, queries, and streaming.
- PostgresKit builds on PostgresWire to provide a higher-level client with pooling, statement caching, metadata utilities, and ergonomic APIs suitable for apps like Echo.

Why a separate package?
- Keeps wire-level concerns isolated and replaceable.
- Enables focused performance work and testing for PostgreSQL communication paths.
- Provides a clean API surface for Echo (and others) to depend on.

Modules
- PostgresWire
  - WireClient: wraps PostgresNIO's PostgresClient
  - WireConnection: executes queries, returns row sequences
  - WireQuery: SQL text + binds abstraction
  - Future: COPY, LISTEN/NOTIFY, cancellation token exposure
- PostgresKit
  - PostgresDatabaseClient: high-level client using WireClient
  - PostgresDatabaseConnection: convenience wrapper for single-connection operations
  - StatementCache: simple LRU for prepared statements
  - Metadata helpers: list databases/schemas/tables, object definitions (incrementally expanded)
  - Future: Bulk COPY helpers, LO API, pooled policies, extended protocol tuning

Performance Philosophy
- Prefer extended query protocol with a prepared statement cache
- Decode in binary for hot types; format lazily for UI
- Support server-side cursor helpers for huge result sets
- Provide cancellation keys and statement timeouts for responsiveness

Tests
- Unit tests for caches and configuration
- Optional integration tests gated by env vars (PGKIT_*); skipped by default

License
- TBD (project-internal while under development)


# Encrypted local SQLite storage

Owner approved 2026-10-02: preserve cached tree, autocomplete, search, diagrams,
results, background prefetch, offline use and existing account sync. Automatic
local encryption must require no account or new password. Commit and push sizable
checkpoints; defer builds and tests until the final stage. Intermediate commits
use `[skip ci]` to honor that request.

## Checkpoints

- [ ] 1. Local storage package: SQLite records, authenticated encryption, Keychain
  key creation, transactions, permissions and migration primitives.
- [ ] 2. Saved configuration: migrate connections, identities, folders, projects
  and settings; remove inline metadata from normal connection persistence.
- [ ] 3. Metadata: per-database cache records, selective hydration, background
  refresh, resolved credential fingerprints, per-connection writes and indexed
  eviction. Preserve search and autocomplete coverage.
- [ ] 4. Other sensitive persistence: encrypted histories, diagrams and streaming
  result chunks; safe legacy migration and key-unavailable behavior.
- [ ] 5. Cloud sync: account-scoped durable outbox, version-aware acknowledgements,
  atomic local edits and sync tracking, remote apply/checkpoint transactions.
- [ ] 6. Verification: migration, crypto, cache, sync and spool tests; XcodeBuildMCP
  build/run/log verification and performance checks. Commit final repairs.

## Boundaries

SQLite routing indexes contain opaque IDs, generic collection names, sizes and
timestamps; sensitive payloads use CryptoKit AES-GCM with record identity as AAD.
Passwords remain in Keychain. Local keys are independent of account/E2E keys.
Metadata, results and histories remain local; existing cloud collection and
credential-sync preferences stay in effect. No new cloud E2E format is introduced.

Legacy source files are only retired after validated encrypted persistence.
Keychain errors must never trigger replacement keys or plaintext fallback.
Saved work is never evicted as cache. Cache limits preserve active data.

## Progress and continuation

Initial investigation: checkout is clean on `dev`; origin is `tashda/Echo`.
Echo already links SQLiteNIO, so native SQLite plus encrypted payloads avoids
introducing a competing SQLCipher SQLite implementation. A package keeps local
SQL and encryption outside Echo's view/model layer and exposes typed operations.
Echo Labs Connections has pre-existing UI drift; do not rewrite unrelated rounds.

Update this file in each checkpoint with implementation details and remaining
work so a resumed session can continue without repeating the investigation.

# Encrypted local SQLite storage

Owner approved 2026-10-02: preserve cached tree, autocomplete, search, diagrams,
results, background prefetch, offline use and existing account sync. Automatic
local encryption must require no account or new password. Commit and push sizable
checkpoints; defer builds and tests until the final stage. Intermediate commits
use `[skip ci]` to honor that request.

## Checkpoints

- [x] 1. Local storage package: SQLite records, authenticated encryption, Keychain
  key creation, transactions, permissions and migration primitives.
- [x] 2. Saved configuration: migrate connections, identities, folders, projects
  and settings; remove inline metadata from normal connection persistence.
- [x] 3. Metadata: per-database cache records, selective hydration, background
  refresh, resolved credential fingerprints, per-connection writes and indexed
  eviction. Preserve search and autocomplete coverage.
- [x] 4. Other sensitive persistence: encrypted histories, diagrams and streaming
  result chunks; safe legacy migration and key-unavailable behavior.
- [x] 5. Cloud sync: account-scoped durable outbox, version-aware acknowledgements,
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

Checkpoint 1: added EchoLocalStorage as a local Swift package and Xcode dependency.
Actor-owned SQLite, encrypted/AAD-bound records, selective group reads, indexed
cache eviction, atomic collection snapshots, and safe installation-key acquisition.
No builds/tests yet, as requested. App consumers are wired in checkpoint 2.

Checkpoint 2: configuration stores now use individually encrypted SQLite records.
The owner clarified there are no users: only a small importer for this Mac, no
old-version compatibility. Inline metadata is moved to a temporary encrypted
legacy-metadata collection for checkpoint 3. Startup stops on unavailable storage
instead of creating defaults over failed reads. Export remains password-protected.

Checkpoint 3: small encrypted server catalogs plus per-database payloads; first
connection hydration selects the configured database, other cached databases warm
before low-priority server refresh. Cached and live are distinct; successful empty
single-database fetches replace old objects. Resolved identity/endpoints/certificate
identity scope cache reuse. Writes debounce per connection; SQLite accounts for
usage without decoding other caches. As-built Explorer behavior updated.

Checkpoint 4: local query/notification/completion histories and auth profile use
encrypted SQLite archives; diagrams use indexed opaque record IDs with a small
legacy importer. Result rows retain binary streaming, with authenticated encryption
per chunk; metadata/stats use SQLite. Open result handles are protected from
automatic eviction. Completion persistence belongs to the host through a typed
EchoSense API; its package checkpoint was committed/pushed on dev. No testing yet.

Checkpoint 5: configuration snapshots and pending-change revisions commit together
in SQLite. Project snapshots include independent bookmark/settings routing records.
Queues and checkpoints are scoped to opaque account IDs and retained on sign-out;
changing accounts disables upload of existing local projects. Push acknowledgements
match the exact queued revision and retain ambiguous/conflicted batches. Downloads
commit configuration and each page's checkpoint in one transaction, refuse to
overwrite pending edits, and suppress re-upload of downloaded changes. Installation
encryption is unchanged by login or logout. Stable canonical encoding avoids
rewriting unchanged records. Final build/test/runtime and migration review follows.

# Encrypted SQLite storage — implementation and verification

Completed 2026-10-02 on `dev`, in separately committed/pushed checkpoints.
EchoSense's host-owned history API is pushed to `echo-sense/dev` at
`da763a33a61ff33297f7b43685c019b473db1cf1`; Echo pins that revision.

## What Echo stores now

`~/Library/Application Support/Echo/LocalStorage.sqlite` contains individually
AES-GCM encrypted records. An actor owns SQLite; WAL transactions keep readers
responsive and local edits consistent. The installation key is randomly generated
in Keychain, independent of Echo login and cloud encryption keys. No new password
or account is required. A failed/missing key on an existing database stops loading;
it never replaces the key or writes plaintext.

Small server catalogs and separate database records replace metadata embedded in
connections. Initial connection hydration reads the catalog and selected database.
Other cached databases warm on the storage actor and publish together, preserving
search/autocomplete coverage. Background server refresh continues. Successful
empty metadata replaces dropped objects; failed fetches preserve cached content.
Fingerprints include resolved identity, endpoints, database and TLS configuration.

Connections, identities, projects, folders, settings, profile, query/completion/
notification histories, recent servers/tables and Explorer state use encrypted
records. Diagram layout keys are opaque; result chunks remain randomly readable
binary data with authenticated encryption. Cache eviction excludes saved work and
protects active data. Explicit user exports retain their existing format/security.

SQLite collection names, sizes, revisions and timestamps remain visible. Routing
IDs are opaque. This protects files at rest; it does not protect against software
already able to inspect Echo's process or an unlocked Keychain. Backups of saved
work need both the local database and its Keychain key.

## Cloud sync

Configuration and durable outbox entries commit in the same transaction. Pending
changes/checkpoints belong to an account; sign-out retains them and switching
accounts does not upload the previous account's local projects. Acknowledgements
only clear the exact uploaded revision. Downloaded configuration and checkpoints
commit together, refusing concurrent/pending local changes. Existing sync
collections, conflict behavior and credential/E2E preferences remain in effect.
Local caches, results and histories are not newly uploaded. The installation key
is not sent to the cloud, and this change introduces no new cloud E2E protocol.

## Import on this Mac

Validated encrypted records replaced the owner's legacy source files; there is no
large release-version migration framework. Counts after import:

| Stored data | Count |
| --- | ---: |
| Connections | 21 |
| Identities | 6 |
| Folders | 2 |
| Projects | 2 |
| Server metadata catalogs | 19 |
| Detailed database records | 674 |
| Unmatched legacy cache preserved encrypted | 1 |

Connection payloads total 14,190 bytes, compared with the old 26.2 MB
`connections.json`. Metadata payloads total about 26.6 MB, fetched by server/group
or database as needed. The database is about 27.4 MB after compaction, plus its
changing WAL. There are no legacy JSON files remaining at the support-directory
root. Directory permissions are 0700; database/WAL/shared-memory files are 0600.
These are storage/read-size measurements, not a measured end-to-end speedup.

## Validation

- Final targeted rerun: **91 passed, zero failed/skipped**. Covers authenticated
  encryption/tampering/record relocation, selective cache hydration and legacy
  import, failed metadata fetches, protected eviction, encrypted result random
  access, account isolation, acknowledgement revisions, transaction rollback,
  remote concurrency checks, histories, notifications and cloud project routing.
- Full UnitTests run: **2,538 passed, 2 failed, 83 skipped**. Both failures are
  existing design expectations in `ServerHeaderPaintTests`:
  `defaultsAreTheWashInTheServersColorWithTheDockInIt` and
  `settingsWithoutTheNewKeysDecodeToTheDefaults`. The current default differs from
  their expected `.wash`; unrelated design files were not changed by this work.
- XcodeBuildMCP compilation and fresh normal launch succeeded. Native app state
  confirmed the loaded workspace, recents and notifications without an error
  dialog. Launch logs contained no local-storage errors.
- Test hosts now use a process-specific temporary database/key/result directory.
  The initial full run used production storage and reset completion ranking
  history. It was restored from an authenticated snapshot containing three
  contexts; re-encoding matched the original 3,723-byte archive size. Subsequent
  isolated runs left the restored archive unchanged. Temporary recovery tooling
  and files were removed before the final code commit.
- Old test artifacts were cleaned according to the repository's age-based rule.

A live login/two-device sync round trip has not been exercised (the owner is
logged out). Server-dependent integration tests and end-to-end performance
profiling remain separate follow-up checks; no cross-device success or precise
startup-speed claim is implied by the local tests.

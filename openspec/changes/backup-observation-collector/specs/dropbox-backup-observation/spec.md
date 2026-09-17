## ADDED Requirements

### Requirement: Authorized native identity and discovery
The adapter SHALL discover only authorized configured roots, preserve native account/namespace context and use explicit provisional origin-scoped identity if native identity is unavailable. Disabled generation MUST NOT imply historical absence or authorize broader scanning. Credentials SHALL be read through the collector's non-executing boundary.

#### Scenario: Disabled generation with historical root
- **WHEN** generation is disabled but a historical root remains explicitly authorized
- **THEN** discovery preserves that location and its status without declaring it empty

#### Scenario: Account identity unavailable
- **WHEN** credentials permit a supported listing but authoritative account identity cannot be established
- **THEN** evidence uses provisional origin-scoped identity without merging it with another account based on credentials or matching paths

### Requirement: Native JSON metadata only
The adapter SHALL use bounded native JSON identity/listing APIs rather than uploader display scraping. It SHALL preserve file ID, revision, path, byte size and distinct client/server timestamps when available, with naming-derived classification marked as inference. It MUST NOT invoke content download, upload, restore, delete, path creation or mutation-capable existence helpers. OAuth refresh SHALL remain an internal authentication operation with no exposed tokens.

#### Scenario: Unclassified file
- **WHEN** a listed file name does not match a known backup naming pattern
- **THEN** the file remains represented with native metadata and unknown classification rather than being discarded

#### Scenario: Listing authentication expires
- **WHEN** supported authentication requires refresh
- **THEN** only the tested authentication path is used and tokens appear in neither observable arguments nor returned diagnostics

### Requirement: Scope-bound full pagination
Full listing SHALL bind continuation to the canonical account, namespace, root and parameters, validate every page, and distinguish page completion from full-scope completion. Malformed, repeated or invalidated cursors, oversized output, rate limits and interruption MUST NOT produce authoritative empty or complete inventory.

#### Scenario: Later page fails
- **WHEN** the first page succeeds and a later page fails or is cancelled
- **THEN** available evidence remains explicitly incomplete and unseen files cannot be inferred absent

#### Scenario: Cursor scope mismatch
- **WHEN** a cursor is reused for another root, account or listing parameter set
- **THEN** the request is rejected without listing the mismatched scope

#### Scenario: Repeated cursor or rate limit
- **WHEN** continuation repeats without progress or the provider rate-limits a request
- **THEN** collection terminates within its budget with a canonical sanitized diagnostic rather than retrying indefinitely

### Requirement: Incremental capability and durable checkpoint boundary
The adapter SHALL distinguish full pagination from incremental deltas and advertise incremental support only after replay/crash conformance with Admin persistence is tested. Admin SHALL own durable checkpoint advancement; the collector MUST NOT imply a cursor was committed. Invalidation SHALL require full reconciliation without inventing deletion evidence.

#### Scenario: Crash before page persistence
- **WHEN** Admin receives a delta page and crashes before its atomic evidence/checkpoint commit
- **THEN** retrying the prior checkpoint yields replay-safe evidence without relying on collector-side advancement

#### Scenario: Incremental cursor invalidated
- **WHEN** Dropbox rejects a saved incremental cursor
- **THEN** the adapter reports the canonical invalidation condition requiring full reconciliation and does not report all previous artifacts deleted

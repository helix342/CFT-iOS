# Requirements Document

## Introduction

Wood CFT currently runs its authoritative-store seam against in-memory fakes: `HostedDatabase` is implemented by `FakeHostedDatabase` and `AuthService` by `FakeAuthService`. These were built as interfaces specifically so a real managed backend could be dropped in behind them without touching the domain, billing, allocation, finalize, void, or sync logic. This spec covers making the authoritative store **real** using **Supabase**, which currently has **nothing provisioned** (no project schema, no tables, no policies, no auth users).

The integration must preserve every guarantee the fakes model today: an authenticated owner session gates all privileged access; `apply` is idempotent on a stable idempotency key; `runTransaction` is all-or-nothing; `readConfirmed` returns authoritative state for a key. The swap is a data-layer concern only — no change to the pure-Dart domain/application contracts, and the full existing test suite (currently green) must remain green by keeping the fakes as the default test doubles.

Supabase is reached with the **client-safe publishable/anon key only**. Privileged access is enforced server-side by Postgres Row Level Security (RLS) keyed to the authenticated owner. No service-role key, no privileged Postgres connection string, and no secret ever enters the app, source, GitHub, or CI secrets. Runtime configuration (project URL + anon key) is injected via `--dart-define`, never hardcoded, so the existing credential-hygiene smoke check (`test/smoke/credential_hygiene_test.dart`) continues to pass.

Online, finalized billing is confirmed by an authenticated Supabase transaction. Offline, calculation, cached browsing, receiving entry, and drafts continue to work against the local SQLite cache and durable pending-operation queue; the queue drains to Supabase when connectivity and a session return. Device-level verification against a physical iPhone remains out of scope for the Windows development environment and is deferred to the on-device checklist.

## Glossary

- **Hosted_Database**: The authoritative store abstraction (`lib/data/hosted_database.dart`). This spec adds a real Supabase-backed implementation of it.
- **Supabase_Client**: The `supabase_flutter` SDK client, initialized once at app bootstrap with the project URL and anon key.
- **Anon_Key**: The client-safe Supabase publishable/anon key. Safe to ship in the app binary; NOT a secret. RLS, not key secrecy, is what protects data.
- **Service_Role_Key**: A privileged Supabase key that bypasses RLS. MUST NEVER appear in the app, source, repo, or CI.
- **RLS**: Postgres Row Level Security policies that restrict every row operation to the authenticated owner.
- **Owner_Session**: An authenticated Supabase auth session (`AuthSession.userId` == the Supabase user id).
- **Idempotency_Key**: The stable key carried by every `HostedOperation` / finalize / void; a unique constraint in Supabase makes re-apply a no-op.
- **Migration**: A versioned SQL script that creates the schema, constraints, and RLS policies in the Supabase project.
- **SupabaseHostedDatabase**: The new `HostedDatabase` implementation backed by `Supabase_Client`.
- **SupabaseAuthService**: The new `AuthService` implementation backed by Supabase Auth.
- **Dart_Define**: Compile-time configuration injected via `--dart-define` / `String.fromEnvironment`, used for the project URL and anon key.
- **Sales**: A persisted record in Supabase of every finalized bill, each entry capturing the invoice and the stock it consumed. Writing a Sales entry is paired with the stock deduction it caused.
- **Purchases**: A persisted record in Supabase of every inventory increase (receiving / opening / positive adjustment), each entry capturing what stock was added. Writing a Purchases entry is paired with the stock increase it recorded.

## Confirmed Decisions

- **CD-1**: The backend is **Supabase** (Neon is not used for this release). Project URL: `https://winnwrhfpejwsxgecred.supabase.co`.
- **CD-2**: The app ships only the **anon/publishable key**; data protection is by **RLS**, never key secrecy.
- **CD-2a**: **No interactive sign-in (OD-1 resolved).** The app has no login screen. There is a single implicit owner identity. The `AuthService` seam is retained for the pure-Dart contract, but `SupabaseAuthService` establishes the session non-interactively (see Requirement 2 and OD-1), so finalize/sync are never blocked on a human login step.
- **CD-3**: The real client is wired **behind the existing `HostedDatabase` and `AuthService` interfaces**. Domain/application/presentation layers do not change their contracts.
- **CD-4**: The **fakes remain the default test doubles**; headless `flutter test` on Windows must not require network or a live Supabase project.
- **CD-5**: Configuration (URL + anon key) is injected via **`--dart-define`**, not hardcoded, so the credential-hygiene check stays green.
- **CD-6**: Supabase has **nothing provisioned yet**; this spec includes the **SQL migrations and RLS policies** needed to create the schema.
- **CD-7**: **Single owner, single device.** One authenticated owner; multi-user collaboration is out of scope.
- **CD-8**: Device/iPhone verification is **out of scope on Windows**; it is captured by the existing on-device checklist, not this spec.

## Requirements

### Requirement 1: Dependency and bootstrap initialization

**User Story:** As the owner, I want the app to connect to Supabase at startup using client-safe configuration, so that online features reach the authoritative store without embedding secrets.

#### Acceptance Criteria

1. WHEN the project dependencies are resolved THEN the System SHALL include the `supabase_flutter` package pinned to a version compatible with the project SDK (Flutter 3.47.7 / Dart 3.13.5).
2. WHEN the app starts THEN the System SHALL initialize the Supabase_Client exactly once with the project URL and Anon_Key before any Hosted_Database access.
3. WHERE the project URL or Anon_Key is read THE System SHALL read it from Dart_Define (`String.fromEnvironment`) with no hardcoded fallback value committed to source.
4. IF the URL or Anon_Key is absent at runtime THEN the System SHALL fail fast with a clear configuration error rather than connecting with blank credentials.
5. WHEN the credential-hygiene smoke check scans `lib/` THEN it SHALL find no embedded anon key, service-role key, JWT, or connection string (the check continues to pass).

### Requirement 2: SupabaseAuthService (non-interactive owner session)

**User Story:** As the owner, I want the app to just work without any login screen, so that I never have to sign in to bill or receive stock, while my data is still protected server-side.

#### Acceptance Criteria

1. The app SHALL have NO interactive sign-in UI (no login screen, no password prompt) (OD-1 resolved: no sign-in).
2. The System SHALL provide a `SupabaseAuthService` implementing the existing `AuthService` interface (status, session, `sessionChanges` stream, `signIn`, `signOut`, `requireSession`) WITHOUT changing those signatures, so the domain/application contracts are preserved.
3. WHEN the app starts THEN `SupabaseAuthService` SHALL establish an Owner_Session non-interactively (via a design-chosen mechanism such as anonymous auth or a provisioned device identity — see OD-1) so that status becomes `signedIn` without any user action.
4. WHILE an Owner_Session is established THE `requireSession` gate SHALL succeed, so finalize/void/sync are never blocked on a human login step.
5. IF the non-interactive session cannot be established (e.g. offline at first launch, before any session exists) THEN `requireSession` SHALL throw `NotAuthenticatedException` so finalize/sync defer until a session is available, unchanged from today's contract; offline calculation, browsing, receiving entry, and drafts SHALL remain available.
6. WHERE the session token can expire THE System SHALL rely on the SDK's automatic refresh so a long-lived session stays valid without any re-login step.

### Requirement 3: SupabaseHostedDatabase (authoritative store)

**User Story:** As the owner, I want finalize, void, and sync to run against the real authoritative store, so that my invoices and stock are durable and consistent.

#### Acceptance Criteria

1. The System SHALL provide a `SupabaseHostedDatabase` implementing the existing `HostedDatabase` interface (`apply`, `runTransaction`, `readConfirmed`).
2. WHEN any `HostedDatabase` method is invoked without an Owner_Session THEN the System SHALL throw `NotAuthenticatedException` and perform no network write.
3. WHEN `apply` is called with an Idempotency_Key that was already applied THEN the System SHALL NOT produce a second effect and SHALL return a result equivalent to the first application (`applied == false`), matching the fake's contract.
4. WHEN `runTransaction` runs and its callback throws THEN the System SHALL leave no partial effect in Supabase (all-or-nothing).
5. WHEN `readConfirmed` is called for a key THEN the System SHALL return the authoritative confirmed state recorded under that key, or signal not-found consistently with the fake.
6. The `SupabaseHostedDatabase` SHALL live in the data layer and MUST NOT change the signatures used by `SyncService`, finalize, or void.

### Requirement 4: Schema and RLS migrations

**User Story:** As the owner, I want the Supabase project to have the correct tables and security policies, so that my data is stored correctly and only I can access it.

#### Acceptance Criteria

1. The System SHALL include versioned SQL Migration scripts that create the authoritative schema: catalog (varieties, cross-sections), stock items/balances, stock movements, invoices, invoice lines, voids, and an applied-operations/idempotency table.
2. WHERE idempotency is required THE schema SHALL enforce a UNIQUE constraint on Idempotency_Key so a duplicate apply is rejected/collapsed at the database level.
3. The schema SHALL record the owner id on owner-scoped rows to support RLS.
4. The migrations SHALL enable RLS on every owner-scoped table and define policies that allow select/insert/update only for rows belonging to the authenticated Owner_Session.
5. WHERE invoice numbers are allocated THE schema SHALL allocate them inside the finalize transaction (a server-side sequence or equivalent) so a rolled-back attempt consumes no committed number.
6. The migrations SHALL be idempotent/re-runnable or clearly versioned so applying them to the empty project is safe and repeatable.
7. The migrations SHALL NOT grant any client the service-role capability; all client access flows through the Anon_Key under RLS.

### Requirement 5: Finalize and void against Supabase

**User Story:** As the owner, I want finalizing and voiding a bill to be atomic and exactly-once on the real backend, so that I never get duplicate invoices or double stock deductions.

#### Acceptance Criteria

1. WHEN a finalize runs online with a valid session THEN the System SHALL validate confirmed stock, create the invoice and immutable line snapshots, allocate the invoice number, and deduct stock within one authenticated Supabase transaction.
2. IF revalidation fails (missing rate or insufficient stock) THEN the System SHALL abort with no invoice, no consumed number, and no deduction.
3. WHEN a finalize is retried with the same Idempotency_Key after an uncertain response THEN the System SHALL yield exactly one invoice and one deduction.
4. WHEN a void runs with a valid session THEN the System SHALL restore exactly the deducted stock and mark the invoice voided atomically, idempotent under its key and guarded per invoice against double-restore.
5. WHERE the device is offline or signed out THE System SHALL keep the order a draft and refuse finalize, unchanged from today.

### Requirement 6: Sync, pending stock, and offline behavior

**User Story:** As the owner, I want offline receiving and drafts to work and then reconcile with Supabase, so that everyday work continues without connectivity.

#### Acceptance Criteria

1. WHILE offline THE System SHALL continue to support calculation, cached browsing, receiving entry, and drafts against the Local_Cache and Pending_Operation_Queue.
2. WHEN connectivity and an Owner_Session are available THEN `SyncService` SHALL drain the Pending_Operation_Queue to `SupabaseHostedDatabase` in order, applying each operation exactly once.
3. WHILE a received quantity is pending synchronization THE System SHALL NOT treat it as sellable; only Confirmed_Available_Stock is sellable.
4. WHEN a drain operation receives an uncertain or lost response THEN retrying with the same Idempotency_Key SHALL not double-apply.
5. WHEN a drain op is confirmed by Supabase THEN the System SHALL promote the corresponding pending local stock to confirmed exactly once.

### Requirement 7: Test strategy and non-regression

**User Story:** As the developer on Windows, I want the test suite to stay green and runnable offline, so that I can keep developing without a live backend.

#### Acceptance Criteria

1. WHEN `flutter test` runs on Windows with no network THEN all existing tests SHALL pass using the fakes as the default doubles (no live Supabase required).
2. WHEN `flutter analyze` runs THEN it SHALL report no issues after the integration is added.
3. The System SHALL provide a seam (provider override / configuration) that selects `SupabaseHostedDatabase` + `SupabaseAuthService` for the real app and the fakes for tests.
4. WHERE Supabase-specific mapping logic is added (payload <-> row, error translation) THE System SHALL unit-test that mapping without requiring a live connection.
5. The integration SHALL NOT weaken or remove any existing property, integration, or smoke test.

### Requirement 8: Credential hygiene and configuration

**User Story:** As the owner, I want assurance that no secret is shipped, so that publishing or sideloading the app never leaks privileged access.

#### Acceptance Criteria

1. The System SHALL NOT embed the Service_Role_Key anywhere in the app, source, repo, or CI.
2. WHERE runtime configuration is needed THE System SHALL pass the project URL and Anon_Key via Dart_Define at build/run time.
3. The CI workflow SHALL reference no Supabase secrets (the existing credential-hygiene CI assertion continues to hold).
4. WHERE documentation is needed THE System SHALL document the `--dart-define` keys and how to run the migrations, without committing any secret value.

### Requirement 9: Sales record on every finalized bill

**User Story:** As the owner, I want every bill I finalize to reduce my inventory and be recorded in a Sales section, so that I have a durable history of what I sold and my stock stays accurate.

#### Acceptance Criteria

1. WHEN a bill is finalized THEN the System SHALL, within the same authenticated finalize transaction, (a) deduct the sold quantities from Confirmed_Available_Stock and (b) write a corresponding entry to the Sales record.
2. The Sales entry SHALL capture the invoice identity (number), the sold lines (variety, cross-section, length, pieces/bunches, allocated CFT, rate, amount), the totals, and the timestamp, consistent with the immutable invoice snapshot.
3. The stock deduction and the Sales entry SHALL be atomic together: IF the finalize transaction aborts THEN neither the deduction nor the Sales entry SHALL persist.
4. WHEN a finalize is retried with the same Idempotency_Key THEN the System SHALL write exactly one Sales entry and apply exactly one deduction (no duplicate sale).
5. WHEN an invoice is voided THEN the System SHALL record the reversal (restoring stock) such that the Sales history reflects the void without mutating the original Sales entry (the original is retained; the void is a separate, linked record).
6. The Sales record SHALL be an owner-scoped table protected by RLS (Requirement 4).

### Requirement 10: Purchases record on every inventory increase

**User Story:** As the owner, I want every time I add stock to be recorded in a Purchases section, so that I have a durable history of what came in and when.

#### Acceptance Criteria

1. WHEN inventory is increased — via receiving confirmation, opening stock, or a positive stock adjustment — THEN the System SHALL write a corresponding entry to the Purchases record.
2. The Purchases entry SHALL capture what was added (variety, cross-section, length, pieces/bunches, resulting CFT), the source kind (receiving / opening / adjustment), and the timestamp.
3. The stock increase and its Purchases entry SHALL be paired: a Purchases entry SHALL exist for exactly the confirmed increase it records, and SHALL NOT be written for a quantity that is not actually added.
4. WHILE a received quantity is still Pending_Receiving_Stock (not yet synchronized/confirmed) THE System SHALL NOT finalize it as a confirmed Purchases entry; the Purchases entry SHALL be recorded when (and exactly once when) the increase is confirmed to the Hosted_Database.
5. WHEN a sync drain confirming a receiving operation is retried with the same Idempotency_Key THEN the System SHALL write exactly one Purchases entry (no duplicate purchase).
6. The Purchases record SHALL be an owner-scoped table protected by RLS (Requirement 4).
## Assumptions & Open Decisions Register

- **OD-1 (Auth method): RESOLVED — no interactive sign-in.** The app has no login screen. A single implicit owner identity is used. Design MUST choose the non-interactive session mechanism: either Supabase **anonymous sign-in** (SDK creates/persists an anonymous user, RLS keyed to its uid) or a **provisioned device identity**. Open sub-decision for design: whether RLS is keyed to that non-interactive uid or whether owner-scoped tables use a fixed owner row with permissive-but-anon-only policies. _Design to finalize the mechanism._
- **OD-2 (Transaction mechanism):** Supabase has no multi-statement client transaction over PostgREST; `runTransaction` atomicity will likely be implemented via a Postgres function (RPC) that performs validate+insert+deduct server-side. To be settled in design. _Needs confirmation._
- **OD-3 (Schema field parity):** Exact column set must mirror the finalize/void payloads and the local drift schema; a mapping table will be produced in design.
- **OD-4 (Migration tooling):** Whether migrations are applied via the Supabase SQL editor, the Supabase CLI, or committed SQL files in-repo. Default: committed SQL files under `supabase/migrations/`, applied by the owner. _Needs confirmation._
- **OD-5 (Realtime):** Live subscriptions/Realtime are out of scope for v1; single-device owner polls/reads on demand.

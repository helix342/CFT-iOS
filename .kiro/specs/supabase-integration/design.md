# Design Document

## Overview

This design wires a real Supabase backend behind the existing `HostedDatabase` (`lib/data/hosted_database.dart`) and `AuthService` (`lib/application/auth_service.dart`) interfaces, replacing — at runtime — the in-memory `FakeHostedDatabase` / `FakeAuthService` with Supabase-backed implementations. The pure-Dart domain/application contracts do not change. Tests keep the fakes as the default doubles, so `flutter test` stays offline-green on Windows.

Supabase currently has nothing provisioned. This design therefore also specifies the SQL schema + Row Level Security migrations that create the authoritative store, including the `sales` and `purchases` records.

### File-ownership boundary (parallel build)

This spec is built in parallel with `app-ux-revamp`. To avoid clobbering, THIS spec owns ONLY:

- NEW files: `lib/data/supabase_hosted_database.dart`, `lib/application/supabase_auth_service.dart`, `supabase/migrations/**` (SQL), `docs/SUPABASE_SETUP.md`.
- The provider seam files `lib/data/hosted_database_providers.dart` and `lib/application/auth_providers.dart` (to select fake-vs-real).

It MUST NOT touch: `lib/data/tables.dart`, `lib/data/app_database.dart` (drift schema), anything under `lib/presentation/**`, `main.dart`, `lib/domain/app_info.dart`, or `pubspec.yaml`. The `supabase_flutter` dependency is added by the orchestrator, not this spec's agent. The drift schema and local finalize/sales model are owned by `app-ux-revamp`; syncing the local model to the hosted `sales`/`purchases` tables is a later reconciliation pass, out of scope here.

## Architecture

```
AuthService (interface, unchanged)
  <|-- FakeAuthService (tests + default)
  <|-- SupabaseAuthService (new; non-interactive session via anonymous auth)

HostedDatabase (interface, unchanged)
  <|-- FakeHostedDatabase (tests + default)
  <|-- SupabaseHostedDatabase (new; apply / runTransaction / readConfirmed over Supabase)

Supabase project (winnwrhfpejwsxgecred)
  - auth: anonymous sign-in (one implicit owner)
  - postgres schema: catalog, stock, movements, invoices, invoice_lines,
    voids, applied_operations (idempotency), sales, purchases
  - RLS: every owner-scoped table restricted to auth.uid()
  - RPC functions: finalize_sale(...), void_invoice(...) for atomic multi-statement transactions
```

Configuration (project URL + anon key) is injected via `--dart-define` and read with `String.fromEnvironment`; `Supabase.initialize(...)` runs once at bootstrap. Bootstrap wiring lives in `main.dart`, which the orchestrator edits (not this agent), since `main.dart` is UX-revamp-owned; this agent exposes an `initializeSupabase()` helper in its own file that `main.dart` can call.

## Components and Interfaces

### SupabaseAuthService (`lib/application/supabase_auth_service.dart`, new)

Implements `AuthService` with NO interactive login (Requirement 2, OD-1 resolved):

- On construction / app start, calls `supabase.auth.signInAnonymously()` if there is no persisted session; the SDK persists and refreshes it. `AuthSession.userId` = the anonymous user's uid.
- `status` -> `signedIn` once the anonymous session exists; `signedOut` only before it is established (e.g. first launch offline).
- `sessionChanges` bridges `supabase.auth.onAuthStateChange` to the existing stream contract.
- `requireSession()` throws `NotAuthenticatedException` when no session yet (offline first-launch), unchanged.
- Automatic token refresh is handled by the SDK (Requirement 2.6).

### SupabaseHostedDatabase (`lib/data/supabase_hosted_database.dart`, new)

Implements `HostedDatabase`:

- `apply(HostedOperation)`: upserts into an `applied_operations` table keyed by `idempotency_key` (UNIQUE). On conflict -> returns `applied == false` with the stored `confirmed_state` (idempotent replay). Otherwise performs the operation's effect and records the key. Session-gated via `AuthService.requireSession`.
- `runTransaction<T>(callback)`: because PostgREST has no client-side multi-statement transaction, atomic flows (finalize, void) are implemented as Postgres **RPC functions** (`finalize_sale`, `void_invoice`) invoked via `supabase.rpc(...)`. The `HostedTransaction` handle passed to the callback stages operations that the RPC applies atomically server-side; a throwing callback / failed RPC commits nothing (Requirement 3.4). The handle exposes the authenticated `session`.
- `readConfirmed(key)`: selects the authoritative confirmed state recorded under `idempotency_key`; signals not-found consistently with the fake (`HostedStateNotFoundException`).
- Error translation: Supabase/PostgREST errors are mapped to the interface's exceptions (auth -> `NotAuthenticatedException`; unique-violation on idempotency -> treated as duplicate replay).

### Provider seam (`hosted_database_providers.dart`, `auth_providers.dart`)

- Introduce a compile-time/config switch (e.g. `const useSupabase = bool.fromEnvironment('USE_SUPABASE')`) so the running app selects `SupabaseHostedDatabase`/`SupabaseAuthService` when configured, and the fakes otherwise.
- Tests and the default offline app keep the fakes (Requirement 7.1, CD-4). No test imports the Supabase client.

## Data Models

Owner-scoped tables, each with `owner_id uuid default auth.uid()` and RLS `using (owner_id = auth.uid())`:

- `catalog_varieties`, `catalog_cross_sections` — mirror the local catalog.
- `stock_items` (confirmed balances), `stock_movements` (signed ledger, `idempotency_key` UNIQUE).
- `invoices` (number UNIQUE, totals in paise, CFT num/den), `invoice_lines` (immutable snapshots).
- `invoice_voids` (reversal records, linked to invoice; original retained).
- `applied_operations` (`idempotency_key` UNIQUE, `kind`, `confirmed_state jsonb`) — the idempotency ledger backing `apply`/`readConfirmed`.
- **`sales`** (Requirement 9): one row per finalized invoice — invoice number, totals, timestamp; written inside `finalize_sale` together with the stock deduction (atomic). A void writes a linked reversal row; the original `sales` row is retained.
- **`purchases`** (Requirement 10): one row per confirmed inventory increase — variety/cross-section/length, pieces, source kind (receiving/opening/adjustment), timestamp; written when a receiving/opening/adjustment op is confirmed (idempotent per key).

Invoice numbers are allocated by a Postgres sequence inside `finalize_sale` so a rolled-back attempt consumes no committed number (Requirement 4.5).

### RLS + security

- RLS enabled on every owner-scoped table; policies permit select/insert/update only for `owner_id = auth.uid()`.
- The app uses the anon key only; the service-role key never appears anywhere (Requirement 8, enforced by the existing credential-hygiene smoke test, which scans `lib/`).
- Migrations are committed SQL files under `supabase/migrations/` (OD-4), applied by the owner via the Supabase SQL editor or CLI; they are re-runnable/versioned.

## Error Handling

- No session (offline first launch) -> `NotAuthenticatedException`; finalize/sync defer, order stays a draft; offline calc/browse/receive/draft still work.
- Idempotency-key unique violation -> treated as a successful duplicate replay (`applied == false`), returning the stored state.
- RPC failure (validation: missing rate / insufficient stock) -> maps to the existing finalize block semantics; nothing committed.
- Network/transport errors are surfaced to the caller so `SyncService` can retry with the same key (exactly-once preserved).

## Correctness Properties

The existing properties 1-31 are inherited. Supabase-specific behavior is pinned by mapping-level tests that do not need a live connection, plus the existing integration tests (which run against the fake).

### Property 32: Supabase apply is idempotent on the idempotency key

Applying the same `HostedOperation` key twice against `SupabaseHostedDatabase` (modeled via a fake PostgREST/unique-constraint stub) yields exactly one effect and `applied == false` on the replay, matching the fake's contract.

**Validates: Requirements 3.3**

### Property 33: Default doubles stay the fakes

With no `USE_SUPABASE` configuration, the provider seam resolves `FakeHostedDatabase` / `FakeAuthService`, so the full suite runs offline with no Supabase import reachable from tests.

**Validates: Requirements 7.1, 7.3**

### Property 34: No embedded secrets

The credential-hygiene scan over `lib/` finds no anon key, service-role key, JWT, or connection string after the Supabase code is added (config is `--dart-define` only).

**Validates: Requirements 1.5, 8.1, 8.2**

## Testing Strategy

- Unit-test the error/payload mapping and the idempotency-replay logic against an injectable Supabase-client stub (no network).
- Keep every existing test on the fakes; add a seam test asserting the default resolves to the fakes (Property S2).
- Re-run the credential-hygiene smoke test (Property S3).
- SQL migrations are validated by review + applied by the owner to the empty project; a live end-to-end finalize against real Supabase is deferred to on-device/manual verification (no live network in CI/Windows).
- `flutter analyze` + `flutter test` stay green after the integration lands.

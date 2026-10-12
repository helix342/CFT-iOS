# Supabase setup

How to point Wood CFT at the real authoritative store (Supabase) and how to
provision the project. This is the owner-facing runbook for the
`supabase-integration` spec.

> **Credential rule (read first).** The app ships **only the client-safe
> anon / publishable key**. Data protection is enforced server-side by Row
> Level Security (RLS), never by key secrecy. **Never** commit any secret:
> no `service_role` key, no privileged Postgres connection string, no JWT.
> The anon key and project URL are passed at build/run time via
> `--dart-define` — they are not hardcoded anywhere in `lib/`, and the
> credential-hygiene smoke test (`test/smoke/credential_hygiene_test.dart`)
> fails the build if a secret ever lands in source.

## 1. Runtime configuration (`--dart-define`)

Two compile-time variables select and configure the real backend. All three
are read with `String.fromEnvironment` / `bool.fromEnvironment` — there is no
committed fallback value.

| `--dart-define` key   | Meaning                                                        | Example                                      |
| --------------------- | -------------------------------------------------------------- | -------------------------------------------- |
| `USE_SUPABASE`        | `true` selects the real Supabase bindings; default `false` → in-memory fakes | `--dart-define=USE_SUPABASE=true`            |
| `SUPABASE_URL`        | The project URL                                                | `--dart-define=SUPABASE_URL=https://winnwrhfpejwsxgecred.supabase.co` |
| `SUPABASE_ANON_KEY`   | The client-safe anon / publishable key (NOT the service role)  | `--dart-define=SUPABASE_ANON_KEY=<anon key>` |

When `USE_SUPABASE` is unset (the default), the app and the entire test suite
run against the fakes with no network and no Supabase SDK on the hot path, so
`flutter test` stays green offline on Windows.

### Running / building against the real backend

```bash
flutter run \
  --dart-define=USE_SUPABASE=true \
  --dart-define=SUPABASE_URL=https://winnwrhfpejwsxgecred.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<paste the anon key here, do not commit it>
```

The same three defines apply to `flutter build ios` / `flutter build apk`.
Keep the anon key in your shell / CI build-arg store, never in a tracked file.
If `SUPABASE_URL` or `SUPABASE_ANON_KEY` is missing at runtime,
`initializeSupabase()` throws `SupabaseConfigException` and the app fails fast
rather than connecting with blank credentials.

## 2. Applying the database migrations

The schema, RLS policies, and RPC functions live as committed, re-runnable SQL
under `supabase/migrations/`:

- `0001_schema.sql` — owner-scoped tables (`catalog_varieties`,
  `catalog_cross_sections`, `stock_items`, `stock_movements`, `invoices`,
  `invoice_lines`, `invoice_voids`, `applied_operations`, `sales`,
  `purchases`), the invoice-number sequence, and RLS enabled on every table
  with `using (owner_id = auth.uid())`.
- `0002_functions.sql` — the atomic `finalize_sale` and `void_invoice` RPC
  functions (validate + insert + deduct + paired `sales` / `purchases`
  writes), idempotent on `idempotency_key`.

Apply them to the (currently empty) project in order. Both files are
re-runnable, so applying them again after a change is safe.

### Option A — Supabase SQL editor (simplest)

1. Open the project dashboard → **SQL Editor**.
2. Paste the contents of `0001_schema.sql`, run it.
3. Paste the contents of `0002_functions.sql`, run it.

### Option B — Supabase CLI

```bash
# From the repo root, with the CLI linked to the project:
supabase db push          # applies files under supabase/migrations in order
# or, to run a single file against a connection you provide out-of-band:
# psql "$CONNECTION" -f supabase/migrations/0001_schema.sql
```

> The CLI / `psql` connection string is an operator credential. Supply it from
> your environment at the moment you run the migration; do **not** add it to
> the repo, CI config, or any tracked file.

## 3. Enabling anonymous auth

The app establishes its owner session non-interactively via **anonymous
sign-in** (there is no login screen). In the project dashboard enable
**Authentication → Providers → Anonymous sign-ins**. RLS is keyed to the
anonymous user's uid, so every row the app writes is scoped to that identity.

## 4. What the app does at startup

1. `initializeSupabase()` reads `SUPABASE_URL` + `SUPABASE_ANON_KEY` and calls
   `Supabase.initialize(...)` exactly once.
2. `SupabaseAuthService.initialize()` signs in anonymously if there is no
   persisted session, so `status` becomes `signedIn` with no user action; the
   SDK refreshes the token automatically.
3. `SupabaseHostedDatabase` serves `apply` / `runTransaction` / `readConfirmed`
   against the migrated schema, idempotent on `idempotency_key`.

## 5. CI note

CI runs the default (fakes) configuration and references **no** Supabase
secrets. The credential-hygiene test asserts that `lib/`, `.github/`, and
`pubspec.yaml` contain no embedded keys, tokens, or connection strings.

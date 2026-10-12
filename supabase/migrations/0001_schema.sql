-- Supabase schema + RLS for Wood CFT (supabase-integration spec, Task 1).
--
-- Creates the authoritative owner-scoped store that backs the HostedDatabase
-- interface: catalog, stock, movements, invoices, lines, voids, the
-- idempotency ledger (applied_operations), and the sales / purchases history.
--
-- Design references:
--   * Requirement 4 (schema + RLS), 9.6 (sales RLS), 10.6 (purchases RLS).
--   * Every owner-scoped row carries `owner_id uuid default auth.uid()` and is
--     protected by RLS `using (owner_id = auth.uid())` so a client holding only
--     the anon key can touch exactly its own rows (Requirement 4.3, 4.4, 4.7).
--   * Invoice numbers are allocated from a per-owner sequence inside the
--     finalize transaction (see 0002_functions.sql), never client-side, so a
--     rolled-back attempt consumes no committed number (Requirement 4.5).
--
-- Re-runnable: every object uses IF NOT EXISTS / CREATE OR REPLACE and every
-- policy is dropped-then-created, so applying this file to a fresh OR an
-- already-migrated project is safe and repeatable (Requirement 4.6).
--
-- No service-role usage anywhere; all access is via the anon key under RLS
-- (Requirement 4.7, 8.1).

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Invoice number sequence
--
-- A single global sequence allocates invoice numbers. In the single-owner
-- model (CD-7) this gives a monotonic series; the number is drawn INSIDE the
-- finalize function so an aborted finalize leaves no gap it committed to.
-- ---------------------------------------------------------------------------
create sequence if not exists invoice_number_seq as bigint start with 1 increment by 1;

-- ---------------------------------------------------------------------------
-- Catalog: varieties and cross-sections
-- ---------------------------------------------------------------------------
create table if not exists catalog_varieties (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null default auth.uid(),
  name        text not null,
  created_at  timestamptz not null default now(),
  unique (owner_id, name)
);

create table if not exists catalog_cross_sections (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null default auth.uid(),
  variety_id    uuid not null references catalog_varieties (id) on delete cascade,
  -- Cross-section dimensions. Kept as integers in the app's base unit; the
  -- exact unit is defined by the domain layer (mirrors the local catalog).
  width         integer not null,
  height        integer not null,
  label         text,
  created_at    timestamptz not null default now(),
  unique (owner_id, variety_id, width, height)
);

-- ---------------------------------------------------------------------------
-- Stock: confirmed balances and the signed movement ledger
-- ---------------------------------------------------------------------------
create table if not exists stock_items (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  variety_id        uuid not null references catalog_varieties (id) on delete restrict,
  cross_section_id  uuid not null references catalog_cross_sections (id) on delete restrict,
  length_mm         integer not null,
  -- Confirmed, sellable balance expressed in pieces. Pending (unsynced)
  -- receiving is NOT reflected here; only confirmed increases land in it.
  pieces            integer not null default 0,
  updated_at        timestamptz not null default now(),
  unique (owner_id, variety_id, cross_section_id, length_mm),
  constraint stock_items_pieces_nonneg check (pieces >= 0)
);

create table if not exists stock_movements (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  stock_item_id     uuid not null references stock_items (id) on delete restrict,
  -- Signed delta: positive for a receiving/opening/adjustment increase,
  -- negative for a sale deduction.
  delta_pieces      integer not null,
  kind              text not null,
  idempotency_key   text not null,
  created_at        timestamptz not null default now(),
  unique (owner_id, idempotency_key)
);

-- ---------------------------------------------------------------------------
-- Invoices, immutable line snapshots, and voids
-- ---------------------------------------------------------------------------
create table if not exists invoices (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  invoice_number    bigint not null,
  -- Monetary totals are stored in paise (integer) to avoid float drift.
  subtotal_paise    bigint not null,
  total_paise       bigint not null,
  -- Aggregate CFT carried as an exact rational (numerator / denominator).
  cft_num           bigint not null,
  cft_den           bigint not null,
  customer_name     text,
  status            text not null default 'finalized',
  idempotency_key   text not null,
  finalized_at      timestamptz not null default now(),
  unique (owner_id, invoice_number),
  unique (owner_id, idempotency_key),
  constraint invoices_cft_den_pos check (cft_den > 0),
  constraint invoices_status_valid check (status in ('finalized', 'voided'))
);

create table if not exists invoice_lines (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  invoice_id        uuid not null references invoices (id) on delete cascade,
  line_index        integer not null,
  variety_name      text not null,
  cross_section     text not null,
  length_mm         integer not null,
  pieces            integer not null,
  bunches           integer,
  -- Allocated CFT for this line as an exact rational.
  cft_num           bigint not null,
  cft_den           bigint not null,
  rate_paise        bigint not null,
  amount_paise      bigint not null,
  constraint invoice_lines_cft_den_pos check (cft_den > 0),
  unique (owner_id, invoice_id, line_index)
);

create table if not exists invoice_voids (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  invoice_id        uuid not null references invoices (id) on delete restrict,
  idempotency_key   text not null,
  reason            text,
  voided_at         timestamptz not null default now(),
  -- One void per invoice: guards against double-restore (Requirement 5.4).
  unique (owner_id, invoice_id),
  unique (owner_id, idempotency_key)
);

-- ---------------------------------------------------------------------------
-- Idempotency ledger backing HostedDatabase.apply / readConfirmed
--
-- `idempotency_key` is UNIQUE per owner so a duplicate apply is collapsed at
-- the database level (Requirement 4.2, 3.3). `confirmed_state` holds the
-- authoritative state the first application recorded, returned verbatim on a
-- replay and by readConfirmed.
-- ---------------------------------------------------------------------------
create table if not exists applied_operations (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  idempotency_key   text not null,
  kind              text not null,
  confirmed_state   jsonb not null default '{}'::jsonb,
  applied_at        timestamptz not null default now(),
  unique (owner_id, idempotency_key)
);

-- ---------------------------------------------------------------------------
-- Sales: one row per finalized invoice (Requirement 9)
--
-- Written INSIDE finalize_sale together with the stock deduction so the sale
-- and the deduction are atomic. A void does not mutate this row; it writes a
-- linked reversal in invoice_voids and the sale row is retained (Req 9.5).
-- ---------------------------------------------------------------------------
create table if not exists sales (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  invoice_id        uuid not null references invoices (id) on delete restrict,
  invoice_number    bigint not null,
  total_paise       bigint not null,
  idempotency_key   text not null,
  sold_at           timestamptz not null default now(),
  unique (owner_id, idempotency_key)
);

-- ---------------------------------------------------------------------------
-- Purchases: one row per confirmed inventory increase (Requirement 10)
--
-- Written when a receiving / opening / adjustment op is confirmed, paired with
-- the stock increase. Idempotent per key so a retried drain writes exactly one
-- purchase (Requirement 10.5).
-- ---------------------------------------------------------------------------
create table if not exists purchases (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid(),
  stock_item_id     uuid references stock_items (id) on delete set null,
  variety_name      text not null,
  cross_section     text not null,
  length_mm         integer not null,
  pieces            integer not null,
  bunches           integer,
  cft_num           bigint not null,
  cft_den           bigint not null,
  -- 'receiving' | 'opening' | 'adjustment'
  source_kind       text not null,
  idempotency_key   text not null,
  purchased_at      timestamptz not null default now(),
  constraint purchases_cft_den_pos check (cft_den > 0),
  constraint purchases_source_valid
    check (source_kind in ('receiving', 'opening', 'adjustment')),
  unique (owner_id, idempotency_key)
);

-- ---------------------------------------------------------------------------
-- Row Level Security
--
-- Enable RLS on every owner-scoped table and allow select/insert/update only
-- for rows the authenticated owner owns. No delete policy is granted (history
-- is retained; voids are additive). Policies are dropped-then-created so this
-- file is re-runnable (Requirement 4.4, 4.6).
-- ---------------------------------------------------------------------------
do $$
declare
  tbl text;
  owner_scoped text[] := array[
    'catalog_varieties',
    'catalog_cross_sections',
    'stock_items',
    'stock_movements',
    'invoices',
    'invoice_lines',
    'invoice_voids',
    'applied_operations',
    'sales',
    'purchases'
  ];
begin
  foreach tbl in array owner_scoped loop
    execute format('alter table %I enable row level security;', tbl);
    execute format('alter table %I force row level security;', tbl);

    execute format('drop policy if exists %I on %I;', tbl || '_select', tbl);
    execute format(
      'create policy %I on %I for select using (owner_id = auth.uid());',
      tbl || '_select', tbl
    );

    execute format('drop policy if exists %I on %I;', tbl || '_insert', tbl);
    execute format(
      'create policy %I on %I for insert with check (owner_id = auth.uid());',
      tbl || '_insert', tbl
    );

    execute format('drop policy if exists %I on %I;', tbl || '_update', tbl);
    execute format(
      'create policy %I on %I for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());',
      tbl || '_update', tbl
    );
  end loop;
end
$$;

-- Atomic finalize / void RPC functions for Wood CFT (supabase-integration
-- spec, Task 2).
--
-- PostgREST has no client-side multi-statement transaction, so the all-or-
-- nothing flows (finalize, void) run server-side as SECURITY INVOKER functions
-- invoked via supabase.rpc(...). Running as the caller (not security definer)
-- keeps RLS in force and avoids any service-role capability (Requirement 4.7).
--
-- Both functions are idempotent on their idempotency_key: a retry after an
-- uncertain response yields exactly one effect (Requirement 5.3, 5.4, 9.4,
-- 10.5). The invoice number is drawn from invoice_number_seq INSIDE the
-- transaction so a failed finalize consumes no committed number (Req 4.5).
--
-- Return shape: both functions return the `confirmed_state` jsonb that the
-- Dart layer records/reads via applied_operations, so apply/readConfirmed and
-- runTransaction share one contract.
--
-- Re-runnable: CREATE OR REPLACE (Requirement 4.6).

-- ---------------------------------------------------------------------------
-- finalize_sale
--
-- Params (all under the authenticated owner, auth.uid()):
--   p_idempotency_key text  — stable finalize key (exactly-once).
--   p_customer_name   text  — optional customer label.
--   p_subtotal_paise  bigint
--   p_total_paise     bigint
--   p_cft_num         bigint
--   p_cft_den         bigint
--   p_lines           jsonb — array of line snapshots. Each element:
--     {
--       "variety_name": text, "cross_section": text, "length_mm": int,
--       "pieces": int, "bunches": int|null,
--       "cft_num": bigint, "cft_den": bigint,
--       "rate_paise": bigint, "amount_paise": bigint,
--       "stock_item_id": uuid   -- the confirmed stock row to deduct from
--     }
--
-- Effect (atomic):
--   1. Idempotent short-circuit: if the key is already applied, return the
--      stored confirmed_state unchanged (no second effect).
--   2. Revalidate confirmed stock for every line; abort if a line asks for
--      more pieces than are confirmed-available (Requirement 5.2 / 9.3).
--   3. Allocate the invoice number from the sequence.
--   4. Insert the invoice + immutable line snapshots.
--   5. Deduct stock and write the signed movement ledger rows.
--   6. Write the paired sales row.
--   7. Record applied_operations(confirmed_state) and return it.
-- A raised exception rolls the whole function back: nothing persists.
-- ---------------------------------------------------------------------------
create or replace function finalize_sale(
  p_idempotency_key text,
  p_customer_name   text,
  p_subtotal_paise  bigint,
  p_total_paise     bigint,
  p_cft_num         bigint,
  p_cft_den         bigint,
  p_lines           jsonb
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_owner        uuid := auth.uid();
  v_existing     jsonb;
  v_invoice_id   uuid;
  v_invoice_no   bigint;
  v_line         jsonb;
  v_idx          integer := 0;
  v_stock_item   uuid;
  v_want_pieces  integer;
  v_have_pieces  integer;
  v_state        jsonb;
begin
  if v_owner is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- (1) Idempotent replay: already applied under this key -> return as-is.
  select confirmed_state into v_existing
  from applied_operations
  where owner_id = v_owner and idempotency_key = p_idempotency_key;
  if found then
    return v_existing;
  end if;

  -- (2) Revalidate confirmed stock for each line.
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_stock_item  := (v_line ->> 'stock_item_id')::uuid;
    v_want_pieces := (v_line ->> 'pieces')::integer;

    select pieces into v_have_pieces
    from stock_items
    where id = v_stock_item and owner_id = v_owner
    for update;

    if not found then
      raise exception 'stock item % not found for owner', v_stock_item
        using errcode = 'P0002';
    end if;
    if v_have_pieces < v_want_pieces then
      raise exception 'insufficient stock for item %: have %, want %',
        v_stock_item, v_have_pieces, v_want_pieces
        using errcode = 'P0001';
    end if;
  end loop;

  -- (3) Allocate the invoice number inside the txn.
  v_invoice_no := nextval('invoice_number_seq');

  -- (4) Insert the invoice.
  insert into invoices (
    owner_id, invoice_number, subtotal_paise, total_paise,
    cft_num, cft_den, customer_name, status, idempotency_key
  )
  values (
    v_owner, v_invoice_no, p_subtotal_paise, p_total_paise,
    p_cft_num, p_cft_den, p_customer_name, 'finalized', p_idempotency_key
  )
  returning id into v_invoice_id;

  -- (4b + 5) Insert line snapshots, deduct stock, record movements.
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_stock_item  := (v_line ->> 'stock_item_id')::uuid;
    v_want_pieces := (v_line ->> 'pieces')::integer;

    insert into invoice_lines (
      owner_id, invoice_id, line_index, variety_name, cross_section,
      length_mm, pieces, bunches, cft_num, cft_den, rate_paise, amount_paise
    )
    values (
      v_owner, v_invoice_id, v_idx,
      v_line ->> 'variety_name',
      v_line ->> 'cross_section',
      (v_line ->> 'length_mm')::integer,
      v_want_pieces,
      nullif(v_line ->> 'bunches', '')::integer,
      (v_line ->> 'cft_num')::bigint,
      (v_line ->> 'cft_den')::bigint,
      (v_line ->> 'rate_paise')::bigint,
      (v_line ->> 'amount_paise')::bigint
    );

    update stock_items
    set pieces = pieces - v_want_pieces, updated_at = now()
    where id = v_stock_item and owner_id = v_owner;

    insert into stock_movements (
      owner_id, stock_item_id, delta_pieces, kind, idempotency_key
    )
    values (
      v_owner, v_stock_item, -v_want_pieces, 'sale',
      p_idempotency_key || ':line:' || v_idx
    );

    v_idx := v_idx + 1;
  end loop;

  -- (6) Paired sales row.
  insert into sales (
    owner_id, invoice_id, invoice_number, total_paise, idempotency_key
  )
  values (
    v_owner, v_invoice_id, v_invoice_no, p_total_paise, p_idempotency_key
  );

  -- (7) Record the idempotency ledger entry + return confirmed state.
  v_state := jsonb_build_object(
    'invoice_id', v_invoice_id,
    'invoice_number', v_invoice_no,
    'total_paise', p_total_paise,
    'status', 'finalized'
  );

  insert into applied_operations (
    owner_id, idempotency_key, kind, confirmed_state
  )
  values (v_owner, p_idempotency_key, 'finalize', v_state);

  return v_state;
end;
$$;

-- ---------------------------------------------------------------------------
-- void_invoice
--
-- Params:
--   p_idempotency_key text  — stable void key (exactly-once).
--   p_invoice_id      uuid  — the invoice to void (owner-scoped).
--   p_reason          text  — optional reason.
--
-- Effect (atomic): restore exactly the deducted stock, mark the invoice
-- voided, write the linked invoice_voids reversal record. Guarded per invoice
-- by the UNIQUE (owner_id, invoice_id) on invoice_voids so a second void is a
-- no-op replay. The original sales row is retained (Requirement 5.4, 9.5).
-- ---------------------------------------------------------------------------
create or replace function void_invoice(
  p_idempotency_key text,
  p_invoice_id      uuid,
  p_reason          text
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_owner     uuid := auth.uid();
  v_existing  jsonb;
  v_status    text;
  v_mv        record;
  v_state     jsonb;
begin
  if v_owner is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  -- Idempotent replay on the void key.
  select confirmed_state into v_existing
  from applied_operations
  where owner_id = v_owner and idempotency_key = p_idempotency_key;
  if found then
    return v_existing;
  end if;

  -- Lock + check the invoice.
  select status into v_status
  from invoices
  where id = p_invoice_id and owner_id = v_owner
  for update;
  if not found then
    raise exception 'invoice % not found for owner', p_invoice_id
      using errcode = 'P0002';
  end if;

  -- Already voided (e.g. a prior void under a different key): idempotent.
  if v_status = 'voided' then
    v_state := jsonb_build_object('invoice_id', p_invoice_id, 'status', 'voided');
    insert into applied_operations (owner_id, idempotency_key, kind, confirmed_state)
    values (v_owner, p_idempotency_key, 'void', v_state)
    on conflict (owner_id, idempotency_key) do nothing;
    return v_state;
  end if;

  -- Restore exactly the stock the finalize deducted (reverse the sale
  -- movements for this invoice's lines).
  for v_mv in
    select sm.stock_item_id, sm.delta_pieces
    from stock_movements sm
    where sm.owner_id = v_owner
      and sm.kind = 'sale'
      and sm.idempotency_key like (
        (select idempotency_key from invoices
         where id = p_invoice_id and owner_id = v_owner) || ':line:%'
      )
  loop
    update stock_items
    set pieces = pieces - v_mv.delta_pieces, updated_at = now()
    where id = v_mv.stock_item_id and owner_id = v_owner;
  end loop;

  update invoices
  set status = 'voided'
  where id = p_invoice_id and owner_id = v_owner;

  insert into invoice_voids (owner_id, invoice_id, idempotency_key, reason)
  values (v_owner, p_invoice_id, p_idempotency_key, p_reason);

  v_state := jsonb_build_object('invoice_id', p_invoice_id, 'status', 'voided');

  insert into applied_operations (owner_id, idempotency_key, kind, confirmed_state)
  values (v_owner, p_idempotency_key, 'void', v_state);

  return v_state;
end;
$$;

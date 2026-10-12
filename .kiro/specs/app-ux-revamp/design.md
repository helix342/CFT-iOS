# Design Document

## Overview

This design turns the approved `app-ux-revamp` requirements into a concrete plan grounded in the existing codebase. The work is presentation + navigation + two persisted capabilities (saveable orders, local sales history for the dashboard). The domain, allocation, billing, and finalize/void engines are reused unchanged.

Guiding principles:

- **Reuse existing tables, do not invent parallel ones.** The drift schema already has `DraftOrders` / `DraftOrderRequests` / `AllocationLines` (for in-progress orders) and `Invoices` / `InvoiceLines` (for finalized sales). Saved orders extend `DraftOrders`; local sales history is exactly `Invoices` + `InvoiceLines`. This needs a schema version bump (1 -> 2) with an additive migration.
- **Keep the application/domain contracts fixed.** New presentation and persistence code composes existing services (`CalculationService`, `AllocationService`, `BillingService`, `FinalizeService`, `PricingService`, `ReceivingService`). No service signature changes.
- **The in-memory hosted fakes stay the finalize/sync backend** (Supabase is a separate spec). "Sold" runs the existing `FinalizeService.finalizeSale` against the fake and additionally persists the invoice locally so the dashboard/Bills have real data.
- **Protect the green suite.** 469 existing tests must keep passing; new surfaces get new tests.

## Architecture

### Navigation / shell

Replace the current four-tab shell (`app_shell.dart`) with the new information architecture:

```
AppShell (first-run gate)
  -> HomeShell : CupertinoTabScaffold
       tab 0: Stock   (CupertinoTabView) -> StockHub -> {InventoryBrowserScreen, ReceivingScreen}
       tab 1: Orders  (CupertinoTabView) -> OrdersHomeScreen (saved orders list + "New order")
                                             -> OrderWorkflow (build -> review -> invoice -> share)
       tab 2: Home    (CupertinoTabView) -> DashboardScreen  [DEFAULT TAB, index 2]
       tab 3: Bills   (CupertinoTabView) -> BillsListScreen -> InvoiceDetail
```

- Default selected tab index = Home (OD-3).
- Settings is removed from the tab bar; `DashboardScreen`'s nav bar carries a top-right gear action that pushes the existing `SettingsTab` as a route (reusing it unchanged).
- Each tab keeps its own `Navigator` via `CupertinoTabView`, as today.

### Order workflow state machine

The unified Orders flow is a linear, resumable workflow backed by a persisted `DraftOrders` row:

```
draft  --(review/allocate)-->  review  --(approve)-->  approved  --(finalize/sold)-->  sold  --(share)-->  shared
  ^                                                                                                           
  '----------------------- "Save for later" parks at draft/review and returns to OrdersHomeScreen -----------
```

- A workflow controller (Riverpod `Notifier`) holds the current `DraftOrders.id` and step, persists staged request lines to `DraftOrderRequests`, and runs `AllocationService` to produce `AllocationLines`.
- "Save for later" simply leaves the `DraftOrders` row at its current status; `OrdersHomeScreen` lists all non-`sold`/non-`shared` drafts.
- "Sold" calls `FinalizeService.finalizeSale` with an order-scoped idempotency key (`order:{draftId}`), then writes the resulting invoice to `Invoices`/`InvoiceLines` and flips the draft to `sold`. Idempotent: re-finalizing the same draft id is a no-op.

## Components and Interfaces

### Data layer (schema v2 migration)

Bump `kSchemaVersion` to `2`. `onUpgrade(1->2)` is additive only (no destructive changes), so existing rows are preserved:

1. **Extend `DraftStatus` enum** (stored as int ordinal) to: `draft(0)`, `preview(1)` (existing), plus `review(2)`, `approved(3)`, `sold(4)`, `shared(5)`. Because drift stores the ordinal, adding enum values is backward compatible; no column change needed for the status itself.
2. **Add columns to `DraftOrders`**: `title` (TEXT nullable), `updatedAt` (DateTime), `invoiceId` (nullable FK -> `Invoices.id`, set when sold). Added via `m.addColumn(...)`.
3. **No new tables required.** `Invoices` + `InvoiceLines` already model local finalized sales; the local finalize path will insert into them.
4. Keep `beforeOpen` FK pragma. Add a `migration` unit test asserting a v1 DB upgrades to v2 with data intact.

New/extended DAOs (data layer, pure Dart over drift):

- `SavedOrdersDao`: create draft, upsert request lines, load resumable drafts (status in {draft, review, approved}), load one draft with its requests + allocation lines, update status, attach invoiceId, delete.
- `SalesQueryDao` (dashboard reads): available stock per item (from `StockItems.confirmedBalancePieces`), total sold pieces/CFT and total payable (aggregate over `Invoices` where status = finalized), recent invoices (ordered by `finalizedAt` desc, limited).
- Local finalize persistence: a thin `LocalInvoiceWriter` that, given a `FinalizedInvoice`, writes the `Invoices` + `InvoiceLines` rows (mapping paise/CFT exactly as the schema stores them).

### Application layer

No new services; one orchestration helper:

- `OrderWorkflowController` (presentation-adjacent Notifier) composes `AllocationService` + `BillingService` + `FinalizeService` + `SavedOrdersDao` + `LocalInvoiceWriter`. It exposes: `startNewOrder()`, `addRequest()/updateLineQty()/removeLine()`, `review()` (runs allocation), `approve()`, `finalizeSold()` (runs finalize, writes local invoice), `share()`, `saveForLater()`, `resume(draftId)`.

### Presentation layer

- **Shared `QuantityStepper` widget** (new, under `presentation/common/`): `- [value] +` with the value tappable to open a numeric entry; 44x44 targets; accessible labels + unit. Used by Receiving (Req 2) and staged order lines (Req 3).
- **Receiving screen**: replace per-length text fields with `QuantityStepper`; replace the text "add" with an icon button (`CupertinoIcons.tray_arrow_down` or similar) with a semantic label "Add to inventory". Keep `ReceivingService.recordReceivingEntry` and the per-length draft counts in local widget state.
- **Order build screen**: staged lines rendered with exact CFT (`Cft.toFixed()`) + a `QuantityStepper`; decrement-to-zero removes the line; running total CFT in the footer.
- **Order workflow screens**: `OrderBuildScreen` -> `AllocationReviewScreen` (reused) -> `InvoicePreviewScreen` (reused) wired with Next/Back and the controller; "Save for later" available throughout.
- **OrdersHomeScreen**: a list of resumable saved orders (title/customer, status, updatedAt, total if allocated) + a prominent "New order" action.
- **Vertical price matrix**: rewrite `PriceMatrixScreen` body as a vertical `ListView` of rate rows (variety x cross-section -> editable rate + missing marker), preserving `PriceMatrixProviders` behavior.
- **DashboardScreen**: header with brand mark + top-right Settings gear; sections for available stock, totals sold (count/CFT + INR), and recent orders list. Reads `SalesQueryDao` providers.
- **Branding**: `kAppName` -> "CFT Calculator"; `flutter_launcher_icons` config generating from a PNG converted from `wmremove-transformed.jpeg`; the dashboard header shows the same asset (added to `pubspec.yaml` assets).

## Data Models

Reused/extended only (no new tables):

- `DraftOrders` (extended): + `title`, + `updatedAt`, + `invoiceId?`; `status` enum extended with review/approved/sold/shared.
- `DraftOrderRequests`, `AllocationLines`: used as-is to persist a saved order's staged requests and computed allocation.
- `Invoices`, `InvoiceLines`: the local sales history (written on "sold"); source for Bills list and dashboard aggregates.

Dashboard view-models (pure Dart, computed from DAOs):

- `DashboardSummary { List<StockOnHand> stock; int totalPiecesSold; Cft totalCftSold; Money totalAmount; List<RecentOrder> recent; }`

## Error Handling

- Finalize blocking (missing rate / insufficient stock) surfaces the existing `FinalizeBlockedException` reason in the workflow's invoice step; the order stays resumable (not advanced to sold).
- Saved-order resume for a draft whose referenced stock/catalog changed: allocation is recomputed on `review()`, so stale drafts re-validate rather than using stale numbers.
- Schema migration failure is guarded by the migration test; `onUpgrade` is additive so a partial failure cannot drop data.
- Stepper direct-entry rejects non-whole / negative input and clamps to >= 0.

## Correctness Properties

This revamp adds no new arithmetic/allocation/billing logic, so the existing Correctness Properties 1-31 (wood-cft-app design) are inherited unchanged and must continue to hold. The presentation/persistence changes introduce these additional invariants (numbered 32+), each pinned by a test:

### Property 32: CFT display fidelity

A staged line's displayed CFT equals the shared engine's exact `lineCftFor` for its current quantity; adjusting via the stepper never introduces float drift (builds on Properties 1-3).

**Validates: Requirements 3.1, 3.3**
### Property 33: No zero-quantity staged lines

After any sequence of stepper increments/decrements, no staged line has quantity 0 (decrement-to-zero removes the line).

**Validates: Requirements 3.4**
### Property 34: Sold yields exactly one local invoice

Finalizing a draft writes exactly one `Invoices` row (and its lines) and flips the draft to `sold`; re-finalizing the same draft id is a no-op (idempotent), inheriting finalize Properties 19 and 24-26.

**Validates: Requirements 4.5**
### Property 35: Dashboard aggregates reconcile

Total sold pieces/CFT and total amount equal the exact sum over the finalized `Invoices`/`InvoiceLines`, order-independent (inherits Property 14 summation semantics).

**Validates: Requirements 6.3, 6.4, 6.5**
### Property 36: Save/resume round-trip

Saving a draft and resuming it yields the same staged requests with no data loss across restart (analogous to Property 30).

**Validates: Requirements 4.2, 4.3, 4.4**
### Property 37: Migration preserves data

Upgrading a v1 database to v2 preserves all existing rows and only adds the new columns.

**Validates: Requirements 8.2**

## Testing Strategy

- **Migration test**: build a v1 schema, upgrade to v2, assert new columns exist and existing rows survive.
- **DAO unit tests**: `SavedOrdersDao` create/resume/status; `SalesQueryDao` aggregates (totals, recent) over seeded invoices; `LocalInvoiceWriter` maps a `FinalizedInvoice` to rows faithfully.
- **Widget tests**: `QuantityStepper` (+/- clamp, tap-to-type); receiving with steppers + icon add commits correctly; adjustable staged line recomputes CFT; vertical price matrix edits persist; dashboard renders seeded aggregates; shell shows four tabs with Home default and a Settings action.
- **Workflow test**: build -> review -> approve -> sold writes an invoice and flips status; save-for-later persists and resumes; sold is idempotent per draft id.
- **Non-regression**: full `flutter analyze` + `flutter test` stay green; existing property/integration/smoke tests untouched.
- All tests run headless on Windows against `openInMemoryDatabase()` and the fakes.

## Open Decisions carried from requirements

OD-1..OD-8 are adopted as the defaults stated in requirements.md. Notably: saved orders persist in `DraftOrders` (OD-1); "sold" == `FinalizeService.finalizeSale` keyed per draft (OD-2); Home is the default tab (OD-3); dashboard totals are all-time (OD-4); stepper supports direct entry (OD-5); icon via `flutter_launcher_icons` from a converted PNG (OD-6); Orders replaces Sell (OD-7); Bills reads local `Invoices` (OD-8).

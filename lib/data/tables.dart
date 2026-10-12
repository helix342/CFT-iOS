/// Drift table definitions for the Wood CFT on-device SQLite cache (task 3.1).
///
/// These tables MIRROR the hosted schema from design.md -> Data Models and add
/// the on-device *pending flags* described in design.md -> "Local cache vs
/// hosted schema". This file is schema only: it defines the columns,
/// constraints, and enums that later tasks build on. The movement-ledger
/// balance logic (task 3.2) and the pending-op queue drain logic (task 3.3)
/// are deliberately NOT implemented here — only their TABLES are declared so
/// the whole schema and its migration land in one place.
///
/// Schema invariants enforced here (design.md -> Data Models):
///   * duplicate stock keys are rejected — unique(variety, cross_section,
///     length) on [StockItems];
///   * orphan invoice lines are impossible — [InvoiceLines.invoiceId] is a
///     NOT NULL foreign key;
///   * idempotency keys are unique — on [StockMovements], [ReceiptEntries],
///     [Invoices], and [PendingOperations];
///   * invoice numbers are unique — on [Invoices].
///
/// Value representation (design.md -> CFT and Currency Arithmetic):
///   * money is stored as integer **paise** (never a binary double);
///   * CFT / rational rates are stored as exact integer numerator/denominator
///     pairs (never a binary double).
///
/// Timestamps are stored in **UTC** (design.md -> Data Models). Drift maps a
/// Dart [DateTime] column to a Unix-epoch integer; callers MUST pass UTC
/// `DateTime`s. The enum columns below use drift's `intEnum` mapping so the
/// stored value is a stable ordinal.
library;

import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// Enums (design.md -> Data Models). Persisted via `intEnum` as stable ordinals.
// ---------------------------------------------------------------------------

/// Cross-section classification. Mirrors `WoodCategory` in the domain layer;
/// kept as an independent persistence enum so the data layer owns its own
/// stored ordinals (design.md -> CrossSection.category).
enum CategoryKind {
  /// Reaper: traded in whole bunches of 10 pieces.
  reaper,

  /// Plank: traded in whole pieces.
  plank,
}

/// Synchronisation state carried by every [StockMovements] and
/// [PendingOperations] row (design.md -> "Local cache vs hosted schema").
enum SyncState {
  /// Written locally, not yet confirmed by the hosted database (display-only,
  /// not sellable).
  pending,

  /// Confirmed by the hosted database (sellable).
  confirmed,

  /// Rejected by the hosted database; surfaced to the owner, never promoted.
  failed,
}

/// The kind of a signed [StockMovements] ledger row
/// (design.md -> StockMovement.type).
enum MovementType {
  /// Stock received on a truck.
  receive,

  /// Opening-stock entry.
  opening,

  /// Manual adjustment (requires a reason).
  adjust,

  /// Reversal / undo of a prior entry (requires a reason).
  reverse,

  /// Deduction from a finalized sale.
  sale,

  /// Restoration from a voided invoice.
  voidRestore,
}

/// Lifecycle status of a [ReceiptSessions] row
/// (design.md -> ReceiptSession.status).
enum ReceiptStatus {
  /// The receipt is open and accepting entries.
  active,

  /// The receipt has been finished.
  finished,
}

/// The input unit for a [ReceiptEntries] row (design.md -> ReceiptEntry.unit).
enum InputUnit {
  /// Input counted in bunches (reapers).
  bunch,

  /// Input counted in individual pieces (planks).
  piece,
}

/// Lifecycle status of a [DraftOrders] row (design.md -> DraftOrder.status).
///
/// Stored via `intEnum` as a stable ordinal. The initial values `draft(0)` and
/// `preview(1)` are preserved; schema v2 appends `review(2)`, `approved(3)`,
/// `sold(4)`, `shared(5)` for the unified order workflow (app-ux-revamp). New
/// values are appended so existing stored ordinals stay valid.
enum DraftStatus {
  /// Draft being edited / saved for later.
  draft,

  /// Preview prepared for finalization.
  preview,

  /// Reviewed: allocation has been computed for the staged requests.
  review,

  /// Approved: the owner confirmed the reviewed allocation.
  approved,

  /// Sold: finalized into a permanent invoice and stock deducted.
  sold,

  /// Shared: the finalized bill has been exported/shared.
  shared,
}

/// The four structured order-request types (design.md -> DraftOrderRequest).
enum RequestType {
  /// Exact quantity of a specific stock item.
  exactQty,

  /// Target CFT at a fixed length.
  targetCftFixedLen,

  /// Target CFT with a fixed cross-section and flexible lengths.
  targetCftFlexCrossSection,

  /// Target CFT within a category and flexible lengths.
  targetCftFlexCategory,
}

/// Lifecycle status of an [Invoices] row (design.md -> Invoice.status).
enum InvoiceStatus {
  /// A finalized, permanent invoice.
  finalized,

  /// A voided invoice (retained, never deleted).
  voided,
}

/// GST tax mode (design.md -> TaxPolicy.mode; CD-5). A single literal tax line.
enum TaxMode {
  /// No GST applied.
  noGst,

  /// Literal 9% total.
  nine,

  /// Literal 18% total.
  eighteen,
}

/// The kind of a durable [PendingOperations] queue row
/// (design.md -> PendingOperation.op_type).
enum OpType {
  /// A receiving entry awaiting sync.
  receiveEntry,

  /// An adjustment/reversal awaiting sync.
  adjust,

  /// A finalize-sale operation awaiting a hosted transaction.
  finalize,

  /// A void operation awaiting a hosted transaction.
  voidOp,
}

// ---------------------------------------------------------------------------
// Catalog tables.
// ---------------------------------------------------------------------------

/// Named timber types (design.md -> WoodVariety). Deactivate, never delete.
@DataClassName('WoodVarietyRow')
class WoodVarieties extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Display name, stored with its exact spelling (Req 1.1).
  TextColumn get name => text()();

  /// Whether the variety is available for new receiving / selling.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Row creation time (UTC).
  DateTimeColumn get createdAt => dateTime()();
}

/// Width x thickness profiles in inches (design.md -> CrossSection).
@DataClassName('CrossSectionRow')
class CrossSections extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// First dimension (width) in inches.
  IntColumn get widthIn => integer()();

  /// Second dimension (thickness) in inches — used in the CFT formula.
  IntColumn get thicknessIn => integer()();

  /// Reaper or Plank.
  IntColumn get category => intEnum<CategoryKind>()();

  /// Pieces per whole sale unit: 10 for a reaper, 1 for a plank.
  IntColumn get bunchSize => integer()();

  /// Whether the cross-section is available for new receiving / selling.
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Inventory records keyed by variety + cross-section + length
/// (design.md -> StockItem). Carries both confirmed and pending balances.
@DataClassName('StockItemRow')
class StockItems extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Owning variety.
  IntColumn get varietyId =>
      integer().references(WoodVarieties, #id)();

  /// Owning cross-section.
  IntColumn get crossSectionId =>
      integer().references(CrossSections, #id)();

  /// Piece length in feet (constrained to 2-9 by the domain layer).
  IntColumn get lengthFt => integer()();

  /// Sum of confirmed movements — the sellable quantity.
  IntColumn get confirmedBalancePieces =>
      integer().withDefault(const Constant(0))();

  /// Sum of not-yet-confirmed received movements — display-only, not sellable.
  IntColumn get pendingBalancePieces =>
      integer().withDefault(const Constant(0))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {varietyId, crossSectionId, lengthFt},
  ];
}

// ---------------------------------------------------------------------------
// Ledger + receiving tables.
// ---------------------------------------------------------------------------

/// Append-only signed stock-movement ledger (design.md -> StockMovement).
///
/// The transactionally-maintained [StockItems] balances are a cache of the
/// signed sum of these rows (reconciliation invariant). Balance maintenance is
/// task 3.2; this table is schema only.
@DataClassName('StockMovementRow')
class StockMovements extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The stock item this movement applies to.
  IntColumn get stockItemId => integer().references(StockItems, #id)();

  /// Movement kind.
  IntColumn get type => intEnum<MovementType>()();

  /// Signed whole-piece delta.
  IntColumn get deltaPieces => integer()();

  /// When the movement occurred (UTC).
  DateTimeColumn get occurredAt => dateTime()();

  /// Optional originating receipt entry.
  IntColumn get receiptEntryId =>
      integer().nullable().references(ReceiptEntries, #id)();

  /// Optional originating invoice (for Sale / Void).
  IntColumn get invoiceId =>
      integer().nullable().references(Invoices, #id)();

  /// Reason text; required for Adjust / Reverse (enforced in task 3.2/5.4).
  TextColumn get reason => text().nullable()();

  /// Stable idempotency key; unique so retries apply exactly once.
  TextColumn get idempotencyKey => text().unique()();

  /// Pending / Confirmed / Failed.
  IntColumn get syncState => intEnum<SyncState>()();
}

/// A truck/opening receiving session (design.md -> ReceiptSession).
@DataClassName('ReceiptSessionRow')
class ReceiptSessions extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Active or Finished.
  IntColumn get status => intEnum<ReceiptStatus>()();

  /// When the session started (UTC).
  DateTimeColumn get startedAt => dateTime()();

  /// When the session finished (UTC); null while active.
  DateTimeColumn get finishedAt => dateTime().nullable()();
}

/// A single line within a receiving session (design.md -> ReceiptEntry).
@DataClassName('ReceiptEntryRow')
class ReceiptEntries extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Owning receipt session.
  IntColumn get receiptId => integer().references(ReceiptSessions, #id)();

  /// Target stock item.
  IntColumn get stockItemId => integer().references(StockItems, #id)();

  /// Quantity as entered (bunches or pieces).
  IntColumn get qtyInput => integer()();

  /// Whether [qtyInput] is in bunches or pieces.
  IntColumn get unit => intEnum<InputUnit>()();

  /// Resolved whole-piece delta.
  IntColumn get piecesDelta => integer()();

  /// Stable idempotency key; unique so resume/finish never double-adds.
  TextColumn get idempotencyKey => text().unique()();

  /// Row creation time (UTC).
  DateTimeColumn get createdAt => dateTime()();
}

// ---------------------------------------------------------------------------
// Pricing.
// ---------------------------------------------------------------------------

/// Price per variety x cross-section (design.md -> PriceRate). Length
/// independent. A null rate numerator/denominator pair means "missing rate".
@DataClassName('PriceRateRow')
class PriceRates extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Owning variety.
  IntColumn get varietyId => integer().references(WoodVarieties, #id)();

  /// Owning cross-section.
  IntColumn get crossSectionId =>
      integer().references(CrossSections, #id)();

  /// Exact rational rate numerator (paise-per-CFT); null = missing rate.
  IntColumn get rateNum => integer().nullable()();

  /// Exact rational rate denominator; null = missing rate.
  IntColumn get rateDen => integer().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {varietyId, crossSectionId},
  ];
}

// ---------------------------------------------------------------------------
// Draft order + allocation tables.
// ---------------------------------------------------------------------------

/// A draft/preview order (design.md -> DraftOrder). Drafts never reserve stock.
@DataClassName('DraftOrderRow')
class DraftOrders extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Draft or Preview.
  IntColumn get status => intEnum<DraftStatus>()();

  /// Optional customer name.
  TextColumn get customerName => text().nullable()();

  /// Optional customer phone.
  TextColumn get customerPhone => text().nullable()();

  /// Row creation time (UTC).
  DateTimeColumn get createdAt => dateTime()();

  /// Optional owner-facing title for a saved order (schema v2; app-ux-revamp).
  TextColumn get title => text().nullable()();

  /// When the draft was last touched (UTC); drives the resumable-orders sort
  /// (schema v2; app-ux-revamp). Defaults to row-creation time on upgrade.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// The permanent invoice this draft produced once sold; null until then
  /// (schema v2; app-ux-revamp).
  IntColumn get invoiceId =>
      integer().nullable().references(Invoices, #id)();
}

/// A structured order request within a draft (design.md -> DraftOrderRequest).
@DataClassName('DraftOrderRequestRow')
class DraftOrderRequests extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Owning draft.
  IntColumn get draftId => integer().references(DraftOrders, #id)();

  /// Which of the four structured request types this is.
  IntColumn get requestType => intEnum<RequestType>()();

  /// Target variety.
  IntColumn get varietyId => integer().references(WoodVarieties, #id)();

  /// Optional fixed cross-section.
  IntColumn get crossSectionId =>
      integer().nullable().references(CrossSections, #id)();

  /// Optional category constraint (for flexible-category requests).
  IntColumn get category => intEnum<CategoryKind>().nullable()();

  /// Optional fixed length in feet.
  IntColumn get lengthFt => integer().nullable()();

  /// Optional target-CFT numerator.
  IntColumn get targetCftNum => integer().nullable()();

  /// Optional target-CFT denominator.
  IntColumn get targetCftDen => integer().nullable()();

  /// Optional exact quantity (for exact-qty requests).
  IntColumn get qty => integer().nullable()();
}

/// A proposed allocation line for a draft (design.md -> AllocationLine).
@DataClassName('AllocationLineRow')
class AllocationLines extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Owning draft.
  IntColumn get draftId => integer().references(DraftOrders, #id)();

  /// Source stock item.
  IntColumn get stockItemId => integer().references(StockItems, #id)();

  /// Allocated whole-unit count.
  IntColumn get qtyUnits => integer()();

  /// Bunch or piece.
  IntColumn get unit => intEnum<InputUnit>()();

  /// Allocated pieces.
  IntColumn get pieces => integer()();

  /// Exact allocated CFT numerator.
  IntColumn get exactCftNum => integer()();

  /// Exact allocated CFT denominator.
  IntColumn get exactCftDen => integer()();

  /// Whether this line is a labelled partial.
  BoolColumn get isPartial => boolean().withDefault(const Constant(false))();

  /// Shortage pieces when partial.
  IntColumn get shortagePieces => integer().withDefault(const Constant(0))();
}

// ---------------------------------------------------------------------------
// Invoice tables.
// ---------------------------------------------------------------------------

/// A finalized or voided invoice (design.md -> Invoice). Money is paise; CFT is
/// an exact numerator/denominator pair.
@DataClassName('InvoiceRow')
class Invoices extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Permanent, unique invoice number.
  TextColumn get invoiceNumber => text().unique()();

  /// Finalized or Voided.
  IntColumn get status => intEnum<InvoiceStatus>()();

  /// Customer name snapshot.
  TextColumn get customerName => text().nullable()();

  /// Customer phone snapshot.
  TextColumn get customerPhone => text().nullable()();

  /// Goods subtotal in paise.
  IntColumn get goodsSubtotalPaise => integer()();

  /// Tax in paise.
  IntColumn get taxPaise => integer()();

  /// Loading charge in paise.
  IntColumn get loadingPaise => integer()();

  /// Payable in paise.
  IntColumn get payablePaise => integer()();

  /// Total CFT numerator.
  IntColumn get totalCftNum => integer()();

  /// Total CFT denominator.
  IntColumn get totalCftDen => integer()();

  /// Serialized tax policy snapshot.
  TextColumn get taxPolicySnapshot => text()();

  /// Serialized loading policy snapshot.
  TextColumn get loadingPolicySnapshot => text()();

  /// Serialized business profile snapshot.
  TextColumn get businessProfileSnapshot => text()();

  /// When finalized (UTC).
  DateTimeColumn get finalizedAt => dateTime()();

  /// Stable idempotency key; unique so retries yield exactly one invoice.
  TextColumn get idempotencyKey => text().unique()();
}

/// An immutable invoice-line snapshot (design.md -> InvoiceLine). The
/// [invoiceId] foreign key is NOT NULL so orphan lines are impossible.
@DataClassName('InvoiceLineRow')
class InvoiceLines extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Owning invoice — NOT NULL foreign key (no orphan lines).
  IntColumn get invoiceId => integer().references(Invoices, #id)();

  /// Variety name snapshot (as issued).
  TextColumn get varietyName => text()();

  /// Cross-section label snapshot.
  TextColumn get crossSectionLabel => text()();

  /// Length in feet.
  IntColumn get lengthFt => integer()();

  /// Pieces billed.
  IntColumn get pieces => integer()();

  /// Exact CFT numerator.
  IntColumn get exactCftNum => integer()();

  /// Exact CFT denominator.
  IntColumn get exactCftDen => integer()();

  /// Rate numerator snapshot.
  IntColumn get rateNum => integer()();

  /// Rate denominator snapshot.
  IntColumn get rateDen => integer()();

  /// Line amount in paise, rounded half-up.
  IntColumn get lineAmountPaise => integer()();
}

// ---------------------------------------------------------------------------
// Settings singletons.
// ---------------------------------------------------------------------------

/// Business profile singleton (design.md -> BusinessSettings). A single row
/// pinned to id = 1.
@DataClassName('BusinessSettingsRow')
class BusinessSettings extends Table {
  /// Singleton primary key (always 1).
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Business name.
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Business address.
  TextColumn get address => text().withDefault(const Constant(''))();

  /// Business phone.
  TextColumn get phone => text().withDefault(const Constant(''))();

  /// Optional logo bytes.
  BlobColumn get logo => blob().nullable()();

  /// Optional GSTIN.
  TextColumn get gstin => text().nullable()();

  /// Invoice number prefix.
  TextColumn get invoicePrefix => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Allocation policy singleton (design.md -> AllocationPolicy).
@DataClassName('AllocationPolicyRow')
class AllocationPolicies extends Table {
  /// Singleton primary key (always 1).
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Whether 8-9 ft fallback is allowed in flexible allocation.
  BoolColumn get allow89ftFallback =>
      boolean().withDefault(const Constant(false))();

  /// Reaper preferred-group share percent ({6,7}).
  IntColumn get reaperSharePreferred =>
      integer().withDefault(const Constant(60))();

  /// Reaper mid-group share percent ({3,4,5}).
  IntColumn get reaperShareMid => integer().withDefault(const Constant(30))();

  /// Reaper low-group share percent ({2}).
  IntColumn get reaperShareLow => integer().withDefault(const Constant(10))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tax policy singleton (design.md -> TaxPolicy; CD-5).
@DataClassName('TaxPolicyRow')
class TaxPolicies extends Table {
  /// Singleton primary key (always 1).
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// No GST / 9% / 18%.
  IntColumn get mode =>
      intEnum<TaxMode>().withDefault(const Constant(0))();

  /// Rate numerator.
  IntColumn get rateNum => integer().withDefault(const Constant(0))();

  /// Rate denominator.
  IntColumn get rateDen => integer().withDefault(const Constant(1))();

  /// Display label.
  TextColumn get label => text().withDefault(const Constant('No GST'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Loading policy singleton (design.md -> LoadingPolicy; CD-6).
@DataClassName('LoadingPolicyRow')
class LoadingPolicies extends Table {
  /// Singleton primary key (always 1).
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Low-tier loading charge in paise (default 10000 = Rs 100).
  IntColumn get lowPaise => integer().withDefault(const Constant(10000))();

  /// High-tier loading charge in paise (default 15000 = Rs 150).
  IntColumn get highPaise => integer().withDefault(const Constant(15000))();

  /// CFT threshold between tiers (default 20).
  IntColumn get thresholdCft => integer().withDefault(const Constant(20))();

  /// Whether the threshold itself counts as high tier (default true).
  BoolColumn get thresholdInclusive =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Durable pending-operation queue + backup metadata.
// ---------------------------------------------------------------------------

/// The durable pending-operation queue (design.md -> PendingOperation). Drain
/// logic is task 3.3; this table is schema only.
@DataClassName('PendingOperationRow')
class PendingOperations extends Table {
  /// Primary key (enqueue order follows ascending id).
  IntColumn get id => integer().autoIncrement()();

  /// Which operation this row represents.
  IntColumn get opType => intEnum<OpType>()();

  /// Serialized payload.
  TextColumn get payload => text()();

  /// Stable idempotency key; unique so duplicate enqueues are rejected.
  TextColumn get idempotencyKey => text().unique()();

  /// When enqueued (UTC).
  DateTimeColumn get enqueuedAt => dateTime()();

  /// Number of apply attempts so far.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Pending / Confirmed / Failed.
  IntColumn get syncState => intEnum<SyncState>()();

  /// Last error message on failure.
  TextColumn get lastError => text().nullable()();
}

/// Backup metadata (design.md -> BackupMeta). Records the schema version a
/// backup was produced against.
@DataClassName('BackupMetaRow')
class BackupMetas extends Table {
  /// Primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Schema version the backup was produced against.
  IntColumn get schemaVersion => integer()();

  /// Producing app version.
  TextColumn get appVersion => text()();

  /// When the backup was exported (UTC).
  DateTimeColumn get exportedAt => dateTime()();

  /// Integrity checksum.
  TextColumn get checksum => text()();
}

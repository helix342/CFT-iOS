/// The Wood CFT on-device SQLite cache database (task 3.1).
///
/// [AppDatabase] is the drift database that owns every table declared in
/// `tables.dart` and the schema migration strategy. It is the single open
/// point for the local cache. The movement-ledger balance maintenance
/// (task 3.2) and the pending-op queue drain (task 3.3) are layered on top of
/// this database later; this task defines only the schema, the migration, and
/// the open constructors.
///
/// Two constructors are provided:
///   * [AppDatabase] — opens the on-device SQLite file via `drift_flutter`'s
///     `driftDatabase`, used by the running app;
///   * [AppDatabase.forTesting] — wraps an arbitrary [QueryExecutor] (e.g. an
///     in-memory `NativeDatabase.memory()`), so schema/migration tests run on
///     Windows without a device. See [openInMemoryDatabase].
///
/// Foreign-key enforcement is enabled on every connection (drift leaves SQLite
/// foreign keys OFF by default), so the NOT NULL / FK invariants in
/// `tables.dart` are actually enforced at runtime.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:wood_cft/data/tables.dart';

part 'app_database.g.dart';

/// The current local-cache schema version (design.md -> BackupMeta).
///
/// Version 2 (app-ux-revamp) adds the saved-order columns `title`,
/// `updatedAt`, and `invoiceId` to [DraftOrders] and extends the
/// [DraftStatus] enum with review/approved/sold/shared. The migration is
/// additive, so existing v1 rows are preserved.
const int kSchemaVersion = 2;

/// The Wood CFT local SQLite cache database.
@DriftDatabase(
  tables: [
    WoodVarieties,
    CrossSections,
    StockItems,
    StockMovements,
    ReceiptSessions,
    ReceiptEntries,
    PriceRates,
    DraftOrders,
    DraftOrderRequests,
    AllocationLines,
    Invoices,
    InvoiceLines,
    BusinessSettings,
    AllocationPolicies,
    TaxPolicies,
    LoadingPolicies,
    PendingOperations,
    BackupMetas,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device SQLite cache file (used by the running app).
  AppDatabase() : super(_openOnDevice());

  /// Opens the database over the given [executor]. Use with
  /// `NativeDatabase.memory()` for tests via [openInMemoryDatabase].
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 -> v2 (app-ux-revamp): additive only, so existing rows survive.
      // Adds the saved-order columns to DraftOrders. The DraftStatus enum
      // extension needs no column change (drift stores the ordinal).
      if (from < 2) {
        await m.addColumn(draftOrders, draftOrders.title);
        await m.addColumn(draftOrders, draftOrders.invoiceId);
        // `updatedAt` carries a non-constant default (currentDateAndTime),
        // which SQLite's ALTER TABLE ADD COLUMN cannot apply. Add it with a
        // constant default and backfill each existing row from its createdAt
        // so no row loses its timestamp.
        await customStatement(
          'ALTER TABLE draft_orders ADD COLUMN updated_at INTEGER NOT NULL '
          'DEFAULT 0',
        );
        await customStatement(
          'UPDATE draft_orders SET updated_at = created_at WHERE '
          'updated_at = 0',
        );
      }
    },
    beforeOpen: (details) async {
      // Enforce foreign keys so NOT NULL/FK invariants hold at runtime.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the on-device database file via `drift_flutter`.
QueryExecutor _openOnDevice() => driftDatabase(name: 'wood_cft_cache');

/// Opens an in-memory [AppDatabase] for tests.
///
/// Backed by `NativeDatabase.memory()`, this applies the full schema via the
/// migration strategy and enables foreign keys, so constraint-violation tests
/// behave exactly as the on-device database would. No device or file is
/// touched, so it runs under `flutter test` on Windows.
AppDatabase openInMemoryDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

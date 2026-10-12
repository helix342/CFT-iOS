/// Unit tests for the headless inventory query + filter engine (task 6.1).
///
/// These boot an in-memory [AppDatabase] (so they run under `flutter test` on
/// Windows with no device), seed a handful of stock items with mixed
/// confirmed + pending balances, and exercise [InventoryQueryService]:
///
///   * filtering by variety / category / cross-section / length returns the
///     right subset (Requirement 6.1);
///   * per-item available CFT equals the exact `CalculationService` value from
///     the confirmed balance (Requirement 6.2);
///   * the filtered total CFT equals the exact sum over exactly the passing
///     items (Requirement 6.3; Property 23 intent);
///   * pending pieces are reported per item and in the total, but are excluded
///     from the available quantity and the available CFT (Requirements 6.2,
///     19.8);
///   * the zero-stock toggle hides items whose CONFIRMED balance is zero
///     (Requirement 6.4).
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/application/inventory_query_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';

/// A seeded cross-section's id + its domain projection (for expected CFT).
class _SeededCrossSection {
  const _SeededCrossSection(this.id, this.domain);
  final int id;
  final CrossSection domain;
}

Future<int> _seedVariety(AppDatabase db, String name) =>
    db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: name,
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );

Future<_SeededCrossSection> _seedCrossSection(
  AppDatabase db, {
  required int widthIn,
  required int thicknessIn,
  required CategoryKind category,
}) async {
  final bunchSize = category == CategoryKind.reaper ? 10 : 1;
  final id = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: widthIn,
          thicknessIn: thicknessIn,
          category: category,
          bunchSize: bunchSize,
        ),
      );
  final domainCategory = category == CategoryKind.reaper
      ? WoodCategory.reaper
      : WoodCategory.plank;
  return _SeededCrossSection(
    id,
    CrossSection(
      id: id,
      widthIn: widthIn,
      thicknessIn: thicknessIn,
      category: domainCategory,
    ),
  );
}

Future<int> _seedStock(
  AppDatabase db, {
  required int varietyId,
  required int crossSectionId,
  required int lengthFt,
  required int confirmed,
  required int pending,
}) =>
    db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: varietyId,
            crossSectionId: crossSectionId,
            lengthFt: lengthFt,
            confirmedBalancePieces: Value(confirmed),
            pendingBalancePieces: Value(pending),
          ),
        );

void main() {
  const calc = CalculationService();

  group('InventoryQueryService — filter + totals', () {
    late AppDatabase db;
    late InventoryQueryService service;

    // Seeded identities, set up in setUp.
    late int mahogany;
    late int kalani;
    late _SeededCrossSection reaper2x1;
    late _SeededCrossSection plank4x1;

    // Stock item ids.
    late int sMahoReaper6; // mahogany, reaper 2x1, 6ft, confirmed 30, pending 10
    late int sMahoReaper4; // mahogany, reaper 2x1, 4ft, confirmed 20, pending 0
    late int sMahoPlank6; // mahogany, plank 4x1, 6ft, confirmed 5, pending 0
    late int sKalaniPlank6; // kalani, plank 4x1, 6ft, confirmed 0, pending 7

    setUp(() async {
      db = openInMemoryDatabase();
      service = InventoryQueryService(db);

      mahogany = await _seedVariety(db, 'Mahogany');
      kalani = await _seedVariety(db, 'Kalani');
      reaper2x1 = await _seedCrossSection(
        db,
        widthIn: 2,
        thicknessIn: 1,
        category: CategoryKind.reaper,
      );
      plank4x1 = await _seedCrossSection(
        db,
        widthIn: 4,
        thicknessIn: 1,
        category: CategoryKind.plank,
      );

      sMahoReaper6 = await _seedStock(
        db,
        varietyId: mahogany,
        crossSectionId: reaper2x1.id,
        lengthFt: 6,
        confirmed: 30,
        pending: 10,
      );
      sMahoReaper4 = await _seedStock(
        db,
        varietyId: mahogany,
        crossSectionId: reaper2x1.id,
        lengthFt: 4,
        confirmed: 20,
        pending: 0,
      );
      sMahoPlank6 = await _seedStock(
        db,
        varietyId: mahogany,
        crossSectionId: plank4x1.id,
        lengthFt: 6,
        confirmed: 5,
        pending: 0,
      );
      sKalaniPlank6 = await _seedStock(
        db,
        varietyId: kalani,
        crossSectionId: plank4x1.id,
        lengthFt: 6,
        confirmed: 0,
        pending: 7,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('no filter returns every item with confirmed-only available CFT',
        () async {
      final result = await service.query(const InventoryFilter());

      expect(result.rows.map((r) => r.stockItemId), [
        sMahoReaper6,
        sMahoReaper4,
        sMahoPlank6,
        sKalaniPlank6,
      ]);

      // Per-item available CFT uses the confirmed balance only.
      final reaper6 =
          result.rows.firstWhere((r) => r.stockItemId == sMahoReaper6);
      expect(
        reaper6.availableCft,
        calc.lineCftFor(reaper2x1.domain, 6, 30),
      );
      // Pending is reported but not folded into available.
      expect(reaper6.availablePieces, 30);
      expect(reaper6.pendingPieces, 10);

      // Total available CFT = exact sum over all passing items (confirmed).
      final expectedTotal = calc.totalCft([
        calc.lineCftFor(reaper2x1.domain, 6, 30),
        calc.lineCftFor(reaper2x1.domain, 4, 20),
        calc.lineCftFor(plank4x1.domain, 6, 5),
        // Kalani plank has zero confirmed -> contributes zero CFT.
        Cft.zero,
      ]);
      expect(result.totalAvailableCft, expectedTotal);
      expect(result.totalAvailablePieces, 30 + 20 + 5 + 0);
      // Pending reported in the total but never in available.
      expect(result.totalPendingPieces, 10 + 0 + 0 + 7);
    });

    test('filter by variety returns only that variety', () async {
      final result =
          await service.query(InventoryFilter(varietyId: kalani));

      expect(result.rows.map((r) => r.stockItemId), [sKalaniPlank6]);
      expect(result.rows.single.varietyName, 'Kalani');
    });

    test('filter by category returns only matching cross-sections', () async {
      final reapers = await service
          .query(const InventoryFilter(category: CategoryKind.reaper));
      expect(
        reapers.rows.map((r) => r.stockItemId),
        [sMahoReaper6, sMahoReaper4],
      );
      expect(reapers.rows.every((r) => r.category == CategoryKind.reaper),
          isTrue);

      final planks = await service
          .query(const InventoryFilter(category: CategoryKind.plank));
      expect(
        planks.rows.map((r) => r.stockItemId),
        [sMahoPlank6, sKalaniPlank6],
      );
    });

    test('filter by cross-section returns only that cross-section', () async {
      final result = await service
          .query(InventoryFilter(crossSectionId: plank4x1.id));
      expect(
        result.rows.map((r) => r.stockItemId),
        [sMahoPlank6, sKalaniPlank6],
      );
    });

    test('filter by length returns only that length', () async {
      final result = await service.query(const InventoryFilter(lengthFt: 4));
      expect(result.rows.map((r) => r.stockItemId), [sMahoReaper4]);
    });

    test('combined filters AND together', () async {
      final result = await service.query(
        InventoryFilter(
          varietyId: mahogany,
          category: CategoryKind.reaper,
          crossSectionId: reaper2x1.id,
          lengthFt: 6,
        ),
      );
      expect(result.rows.map((r) => r.stockItemId), [sMahoReaper6]);
    });

    test('filtered total CFT equals the exact sum over the passing subset',
        () async {
      final result = await service
          .query(const InventoryFilter(category: CategoryKind.reaper));

      final expected = calc.totalCft([
        calc.lineCftFor(reaper2x1.domain, 6, 30),
        calc.lineCftFor(reaper2x1.domain, 4, 20),
      ]);
      expect(result.totalAvailableCft, expected);
      expect(result.totalAvailablePieces, 50);
    });

    test('pending-only item has zero available CFT and pieces', () async {
      final result =
          await service.query(InventoryFilter(varietyId: kalani));
      final row = result.rows.single;

      expect(row.availablePieces, 0);
      expect(row.availableCft, Cft.zero);
      // Pending is still reported for the UI badge.
      expect(row.pendingPieces, 7);
      // And it is excluded from the available totals.
      expect(result.totalAvailablePieces, 0);
      expect(result.totalAvailableCft, Cft.zero);
      expect(result.totalPendingPieces, 7);
    });

    test('hiding zero-stock drops items with zero confirmed balance',
        () async {
      // Kalani plank has 0 confirmed (pending only) -> hidden when excluded.
      final hidden = await service
          .query(const InventoryFilter(includeZeroStock: false));
      expect(hidden.rows.map((r) => r.stockItemId), [
        sMahoReaper6,
        sMahoReaper4,
        sMahoPlank6,
      ]);
      expect(hidden.rows.any((r) => r.stockItemId == sKalaniPlank6), isFalse);

      // Showing zero-stock (default) includes it again.
      final shown = await service.query(const InventoryFilter());
      expect(shown.rows.any((r) => r.stockItemId == sKalaniPlank6), isTrue);
    });

    test('empty filter result has zero totals', () async {
      final result = await service.query(const InventoryFilter(lengthFt: 9));
      expect(result.rows, isEmpty);
      expect(result.totalAvailablePieces, 0);
      expect(result.totalAvailableCft, Cft.zero);
      expect(result.totalPendingPieces, 0);
    });
  });
}

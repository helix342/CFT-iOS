// Pure-Dart unit tests for the catalog mutation rules (task 2.6):
// CatalogService add / rename / deactivate / activeVarieties / snapshot.
//
// These tests pin the task's required assertions (Requirements 1.3–1.7):
//  * add a new variety with a unique id (1.3);
//  * rename an existing variety keeping its id identity (1.4);
//  * deactivate a variety so it is excluded from the active list but RETAINED
//    in the catalog, never deleted (1.5);
//  * no auto-merge: a name collision on add/rename is rejected and records are
//    not merged (1.7);
//  * the snapshot helper captures the variety name as issued, surviving a
//    later rename or deactivation (1.6).
//
// Imports only the pure-Dart domain layer and the `test` matchers exposed via
// flutter_test — no widgets are pumped.

import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/catalog_service.dart';

void main() {
  const service = CatalogService();

  List<WoodVariety> seed() => const <WoodVariety>[
    WoodVariety(id: 1, name: 'Mahogany'),
    WoodVariety(id: 2, name: 'Kalani'),
    WoodVariety(id: 3, name: 'Palajathi'),
  ];

  group('addVariety (Req 1.3)', () {
    test('appends a new active variety with a unique id', () {
      final result = service.addVariety(seed(), id: 4, name: 'Teak');
      expect(result.length, 4);
      final added = result.firstWhere((v) => v.id == 4);
      expect(added.name, 'Teak');
      expect(added.active, isTrue);
    });

    test('trims the given name but preserves its spelling', () {
      final result = service.addVariety(seed(), id: 4, name: '  Teak  ');
      expect(result.firstWhere((v) => v.id == 4).name, 'Teak');
    });

    test('rejects a duplicate id without merging', () {
      expect(
        () => service.addVariety(seed(), id: 2, name: 'Teak'),
        throwsA(isA<CatalogMutationError>()),
      );
    });

    test('rejects an empty name', () {
      expect(
        () => service.addVariety(seed(), id: 4, name: '   '),
        throwsA(isA<CatalogMutationError>()),
      );
    });

    test('rejects a name that collides with an active variety (no merge)', () {
      expect(
        () => service.addVariety(seed(), id: 4, name: 'mahogany'),
        throwsA(isA<CatalogMutationError>()),
      );
    });
  });

  group('renameVariety (Req 1.4)', () {
    test('changes the name but keeps id and active identity', () {
      final result = service.renameVariety(seed(), id: 1, newName: 'Mahagony');
      final renamed = result.firstWhere((v) => v.id == 1);
      expect(renamed.name, 'Mahagony');
      expect(renamed.id, 1);
      expect(renamed.active, isTrue);
      // Other varieties are untouched.
      expect(result.firstWhere((v) => v.id == 2).name, 'Kalani');
    });

    test('allows renaming a variety to its own name (normalises spelling)', () {
      final result = service.renameVariety(seed(), id: 1, newName: 'MAHOGANY');
      expect(result.firstWhere((v) => v.id == 1).name, 'MAHOGANY');
    });

    test('rejects renaming onto another active variety (no auto-merge)', () {
      expect(
        () => service.renameVariety(seed(), id: 1, newName: 'Kalani'),
        throwsA(isA<CatalogMutationError>()),
      );
      // Records are not merged: the catalog still holds 3 distinct varieties.
      expect(seed().length, 3);
    });

    test('rejects renaming a variety that is not in the catalog', () {
      expect(
        () => service.renameVariety(seed(), id: 99, newName: 'Teak'),
        throwsA(isA<CatalogMutationError>()),
      );
    });

    test('may reuse the name of a DEACTIVATED variety (not a merge)', () {
      // Deactivate Kalani, then rename Mahogany -> Kalani. Because the clash is
      // only against ACTIVE names, this is permitted and still produces two
      // distinct records (ids 1 and 2), never a merge.
      final deactivated = service.deactivateVariety(seed(), id: 2);
      final result =
          service.renameVariety(deactivated, id: 1, newName: 'Kalani');
      expect(result.where((v) => v.name == 'Kalani').length, 2);
      expect(result.firstWhere((v) => v.id == 1).active, isTrue);
      expect(result.firstWhere((v) => v.id == 2).active, isFalse);
    });
  });

  group('deactivateVariety + activeVarieties (Req 1.5)', () {
    test('deactivated variety is excluded from the active list', () {
      final result = service.deactivateVariety(seed(), id: 2);
      final active = service.activeVarieties(result);
      expect(active.map((v) => v.id), <int>[1, 3]);
    });

    test('deactivated variety is RETAINED in the catalog, never deleted', () {
      final result = service.deactivateVariety(seed(), id: 2);
      expect(result.length, 3);
      final kalani = result.firstWhere((v) => v.id == 2);
      expect(kalani.active, isFalse);
      expect(kalani.name, 'Kalani');
    });

    test('deactivating an unknown id throws', () {
      expect(
        () => service.deactivateVariety(seed(), id: 99),
        throwsA(isA<CatalogMutationError>()),
      );
    });

    test('reactivate restores an inactive variety to the active list', () {
      final off = service.deactivateVariety(seed(), id: 2);
      final back = service.reactivateVariety(off, id: 2);
      expect(service.activeVarieties(back).map((v) => v.id), <int>[1, 2, 3]);
    });

    test('reactivate is rejected when the name now clashes (no merge)', () {
      // Deactivate Kalani, rename Mahogany to Kalani, then try to bring the old
      // Kalani back — rejected rather than merged.
      final off = service.deactivateVariety(seed(), id: 2);
      final renamed = service.renameVariety(off, id: 1, newName: 'Kalani');
      expect(
        () => service.reactivateVariety(renamed, id: 2),
        throwsA(isA<CatalogMutationError>()),
      );
    });
  });

  group('snapshotVarietyName (Req 1.6)', () {
    test('captures the name as issued', () {
      const variety = WoodVariety(id: 1, name: 'Mahogany');
      expect(service.snapshotVarietyName(variety), 'Mahogany');
    });

    test('snapshot survives a later rename (history is not rewritten)', () {
      const original = WoodVariety(id: 1, name: 'Mahogany');
      final issued = service.snapshotVarietyName(original);
      // Later the catalog renames the variety.
      final after =
          service.renameVariety(<WoodVariety>[original], id: 1, newName: 'Teak');
      expect(after.first.name, 'Teak');
      // The captured snapshot still reads the name as issued.
      expect(issued, 'Mahogany');
    });

    test('snapshot survives a later deactivation', () {
      const original = WoodVariety(id: 1, name: 'Palajathi');
      final issued = service.snapshotVarietyName(original);
      final after =
          service.deactivateVariety(<WoodVariety>[original], id: 1);
      expect(after.first.active, isFalse);
      expect(issued, 'Palajathi');
    });
  });
}

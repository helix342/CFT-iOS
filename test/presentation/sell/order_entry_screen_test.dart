/// Widget tests for the Sell-tab order-entry screen (task 8.2).
///
/// These boot [OrderEntryScreen] with the drift database overridden to an
/// in-memory instance seeded with a reaper 2×1 and a plank 3×1 cross-section
/// (each with an active variety), and exercise ALL FOUR structured request
/// forms (Requirements 7.2–7.5), asserting each produces a VALID
/// [OrderRequest] on the draft:
///
///   * Exact quantity → [ExactQtyRequest] with the pinned SKU + whole-unit qty
///     (Req 7.2);
///   * Target CFT · exact length → [TargetCftFixedLengthRequest] (Req 7.3);
///   * Target CFT · cross-section → [TargetCftFlexCrossSectionRequest]
///     (Req 7.4);
///   * Target CFT · category → [TargetCftFlexCategoryRequest] (Req 7.5).
///
/// They also assert the forms VALIDATE their shape — an empty/invalid field
/// surfaces inline feedback and never stages a request — and that a staged line
/// can be removed. The staged draft is read directly from the shared
/// [draftOrderRequestsProvider] through the test's own [ProviderContainer].
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/sell/order_entry_screen.dart';
import 'package:wood_cft/presentation/sell/sell_providers.dart';

/// The seeded catalog ids a test needs to drive and assert the forms.
class _Seed {
  const _Seed({
    required this.reaperVarietyId,
    required this.reaperCrossSectionId,
    required this.plankCrossSectionId,
  });

  final int reaperVarietyId;
  final int reaperCrossSectionId;
  final int plankCrossSectionId;
}

/// Seeds one active variety (Mahogany) with a reaper (2×1) and a plank (3×1)
/// active cross-section.
Future<_Seed> _seedCatalog(AppDatabase db) async {
  final varietyId = await db.into(db.woodVarieties).insert(
        WoodVarietiesCompanion.insert(
          name: 'Mahogany',
          createdAt: DateTime.utc(2024, 1, 1),
        ),
      );
  final reaperCrossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 2,
          thicknessIn: 1,
          category: CategoryKind.reaper,
          bunchSize: 10,
        ),
      );
  final plankCrossSectionId = await db.into(db.crossSections).insert(
        CrossSectionsCompanion.insert(
          widthIn: 3,
          thicknessIn: 1,
          category: CategoryKind.plank,
          bunchSize: 1,
        ),
      );
  return _Seed(
    reaperVarietyId: varietyId,
    reaperCrossSectionId: reaperCrossSectionId,
    plankCrossSectionId: plankCrossSectionId,
  );
}

void main() {
  late AppDatabase db;
  late _Seed seed;
  late ProviderContainer container;

  setUp(() async {
    db = openInMemoryDatabase();
    seed = await _seedCatalog(db);
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  List<OrderRequest> staged() => container.read(draftOrderRequestsProvider);

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(home: OrderEntryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectKind(
    WidgetTester tester,
    _RequestFormKindProbe kind,
  ) async {
    await tester.tap(find.byKey(Key('request_type_${kind.name}')));
    await tester.pumpAndSettle();
  }

  Future<void> selectVariety(WidgetTester tester) async {
    await tester.tap(find.byKey(Key('variety_choice_${seed.reaperVarietyId}')));
    await tester.pumpAndSettle();
  }

  Future<void> selectCrossSection(WidgetTester tester, int id) async {
    await tester.tap(find.byKey(Key('cross_section_choice_$id')));
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add_request_button')));
    await tester.pumpAndSettle();
  }

  /// Scrolls the order-entry list to the bottom so the lazily-built staged
  /// list (empty state or lines) is realized and findable.
  Future<void> scrollToStagedList(
    WidgetTester tester,
    Key target,
  ) async {
    await tester.scrollUntilVisible(
      find.byKey(target),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers a segment for each of the four request types',
      (tester) async {
    await pumpScreen(tester);
    for (final k in _RequestFormKindProbe.values) {
      expect(
        find.byKey(Key('request_type_${k.name}')),
        findsOneWidget,
        reason: 'missing segment for ${k.name}',
      );
    }
  });

  testWidgets('starts with an empty draft and the exact-quantity form',
      (tester) async {
    await pumpScreen(tester);
    expect(staged(), isEmpty);
    // Exact-quantity form shows the quantity field, not a target CFT field.
    expect(find.byKey(const Key('quantity_field')), findsOneWidget);
    expect(find.byKey(const Key('target_cft_field')), findsNothing);
    await scrollToStagedList(tester, const Key('staged_requests_empty'));
    expect(find.byKey(const Key('staged_requests_empty')), findsOneWidget);
  });

  testWidgets('exact-quantity form produces a valid ExactQtyRequest (Req 7.2)',
      (tester) async {
    await pumpScreen(tester);
    await selectVariety(tester);
    await selectCrossSection(tester, seed.reaperCrossSectionId);
    await tester.tap(find.byKey(const Key('length_choice_6')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quantity_field')), '3');
    await tester.pumpAndSettle();
    await add(tester);

    final requests = staged();
    expect(requests, hasLength(1));
    final req = requests.single;
    expect(req, isA<ExactQtyRequest>());
    final exact = req as ExactQtyRequest;
    expect(exact.varietyId, seed.reaperVarietyId);
    expect(exact.crossSectionId, seed.reaperCrossSectionId);
    expect(exact.lengthFt, 6);
    expect(exact.quantityUnits, 3);
  });

  testWidgets(
      'target-CFT · exact-length form produces a valid '
      'TargetCftFixedLengthRequest (Req 7.3)', (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, _RequestFormKindProbe.targetCftFixedLength);
    await selectVariety(tester);
    await selectCrossSection(tester, seed.reaperCrossSectionId);
    await tester.tap(find.byKey(const Key('length_choice_7')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_cft_field')), '5.5');
    await tester.pumpAndSettle();
    await add(tester);

    final requests = staged();
    expect(requests, hasLength(1));
    final req = requests.single;
    expect(req, isA<TargetCftFixedLengthRequest>());
    final fixed = req as TargetCftFixedLengthRequest;
    expect(fixed.crossSectionId, seed.reaperCrossSectionId);
    expect(fixed.lengthFt, 7);
    // 5.5 parses to the exact rational 11/2 — no float drift.
    expect(fixed.targetCft, Rational(BigInt.from(11), BigInt.from(2)));
  });

  testWidgets(
      'target-CFT · cross-section form produces a valid '
      'TargetCftFlexCrossSectionRequest with no length (Req 7.4)',
      (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, _RequestFormKindProbe.targetCftFlexCrossSection);
    await selectVariety(tester);
    await selectCrossSection(tester, seed.plankCrossSectionId);
    // Flexible lengths — no length picker is shown.
    expect(find.byKey(const Key('length_choice_6')), findsNothing);
    await tester.enterText(find.byKey(const Key('target_cft_field')), '12');
    await tester.pumpAndSettle();
    await add(tester);

    final requests = staged();
    expect(requests, hasLength(1));
    final req = requests.single;
    expect(req, isA<TargetCftFlexCrossSectionRequest>());
    final flex = req as TargetCftFlexCrossSectionRequest;
    expect(flex.crossSectionId, seed.plankCrossSectionId);
    expect(flex.targetCft, Rational.fromInt(12));
  });

  testWidgets(
      'target-CFT · category form produces a valid '
      'TargetCftFlexCategoryRequest (Req 7.5)', (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, _RequestFormKindProbe.targetCftFlexCategory);
    await selectVariety(tester);
    // Category form shows a category picker, not a cross-section picker.
    expect(
      find.byKey(Key('cross_section_choice_${seed.reaperCrossSectionId}')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('category_choice_reaper')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_cft_field')), '20');
    await tester.pumpAndSettle();
    await add(tester);

    final requests = staged();
    expect(requests, hasLength(1));
    final req = requests.single;
    expect(req, isA<TargetCftFlexCategoryRequest>());
    final cat = req as TargetCftFlexCategoryRequest;
    expect(cat.targetCft, Rational.fromInt(20));
  });

  testWidgets('an incomplete form stages nothing and flags the missing field',
      (tester) async {
    await pumpScreen(tester);
    // No variety selected.
    await add(tester);
    expect(staged(), isEmpty);
    expect(find.byKey(const Key('order_entry_feedback')), findsOneWidget);

    // Variety but no cross-section / length / quantity.
    await selectVariety(tester);
    await add(tester);
    expect(staged(), isEmpty);

    // Everything but a zero quantity is still rejected (whole-unit rule).
    await selectCrossSection(tester, seed.reaperCrossSectionId);
    await tester.tap(find.byKey(const Key('length_choice_4')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quantity_field')), '0');
    await tester.pumpAndSettle();
    await add(tester);
    expect(staged(), isEmpty);
  });

  testWidgets('a staged line can be removed from the draft', (tester) async {
    await pumpScreen(tester);
    await selectVariety(tester);
    await selectCrossSection(tester, seed.reaperCrossSectionId);
    await tester.tap(find.byKey(const Key('length_choice_6')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quantity_field')), '2');
    await tester.pumpAndSettle();
    await add(tester);
    expect(staged(), hasLength(1));

    await scrollToStagedList(tester, const Key('remove_request_0'));
    await tester.tap(find.byKey(const Key('remove_request_0')));
    await tester.pumpAndSettle();
    expect(staged(), isEmpty);
    await scrollToStagedList(tester, const Key('staged_requests_empty'));
    expect(find.byKey(const Key('staged_requests_empty')), findsOneWidget);
  });
}

/// Mirror of the screen-private request-kind enum so the test can tap the right
/// segment by its stable key (`request_type_<name>`). The names MUST match the
/// screen's `_RequestFormKind` values.
enum _RequestFormKindProbe {
  exactQty,
  targetCftFixedLength,
  targetCftFlexCrossSection,
  targetCftFlexCategory,
}

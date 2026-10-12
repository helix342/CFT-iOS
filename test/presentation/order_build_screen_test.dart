/// Widget tests for the unified Orders-tab build screen (app-ux-revamp
/// Requirement 3, 7).
///
/// Boots [OrderBuildScreen] with the drift database overridden to an in-memory
/// instance seeded with a reaper 2×1 and a plank 3×1 active cross-section (each
/// with an active variety), and exercises ALL FOUR structured request shapes:
///
///   * Exact quantity → a staged, adjustable `StagedOrderLine` (keeps the +/-
///     stepper behaviour) that becomes an `ExactQtyRequest`;
///   * Target CFT · length → a `StagedTargetRequest` →
///     `TargetCftFixedLengthRequest`;
///   * Target CFT · cross-section → [TargetCftFlexCrossSectionRequest];
///   * Target CFT · category → [TargetCftFlexCategoryRequest].
///
/// It also asserts the CFT-per-piece read-out appears when a cross-section +
/// length are chosen, and that every staged request reaches
/// [stagedOrderRequestsProvider] as its REAL [OrderRequest] subtype.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/order_build_screen.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

/// The seeded catalog ids a test needs to drive and assert the forms.
class _Seed {
  const _Seed({
    required this.varietyId,
    required this.reaperCrossSectionId,
    required this.plankCrossSectionId,
  });

  final int varietyId;
  final int reaperCrossSectionId;
  final int plankCrossSectionId;
}

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
    varietyId: varietyId,
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

  List<OrderRequest> stagedRequests() =>
      container.read(stagedOrderRequestsProvider);

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(home: OrderBuildScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectKind(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(Key('build_request_type_$name')));
    await tester.pumpAndSettle();
  }

  Future<void> selectVariety(WidgetTester tester) async {
    await tester.tap(find.byKey(Key('build_variety_${seed.varietyId}')));
    await tester.pumpAndSettle();
  }

  /// Scrolls the build list until [target] is on-screen so a lazily-built row
  /// or button is realized and tappable.
  Future<void> scrollTo(WidgetTester tester, Key target) async {
    await tester.scrollUntilVisible(
      find.byKey(target),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key target) async {
    await scrollTo(tester, target);
    await tester.tap(find.byKey(target));
    await tester.pumpAndSettle();
  }

  testWidgets('offers a segment for each of the four request types',
      (tester) async {
    await pumpScreen(tester);
    for (final name in const [
      'exactQty',
      'targetCftFixedLength',
      'targetCftFlexCrossSection',
      'targetCftFlexCategory',
    ]) {
      expect(
        find.byKey(Key('build_request_type_$name')),
        findsOneWidget,
        reason: 'missing segment for $name',
      );
    }
  });

  testWidgets('shows exact CFT per piece and per bunch for a reaper (Req 2)',
      (tester) async {
    await pumpScreen(tester);
    await selectVariety(tester);
    await tapKey(tester, Key('build_cs_${seed.reaperCrossSectionId}'));
    await tapKey(tester, const Key('build_length_6'));
    await scrollTo(tester, const Key('build_cft_per_piece'));

    // 2×1×6/144 = 12/144 = 1/12 = 0.0833 CFT per piece; a reaper bunch is 10
    // pieces = 0.8333 CFT per bunch.
    final perPiece =
        tester.widget<Text>(find.byKey(const Key('build_cft_per_piece')));
    expect(perPiece.data, contains('0.0833 CFT per piece'));
    final perBunch =
        tester.widget<Text>(find.byKey(const Key('build_cft_per_bunch')));
    expect(perBunch.data, contains('0.8333 CFT per bunch'));
  });

  testWidgets('exact-qty adds an adjustable staged line → ExactQtyRequest',
      (tester) async {
    await pumpScreen(tester);
    await selectVariety(tester);
    await tapKey(tester, Key('build_cs_${seed.reaperCrossSectionId}'));
    await tapKey(tester, const Key('build_length_6'));
    await tapKey(tester, const Key('build_add_line'));

    final requests = stagedRequests();
    expect(requests, hasLength(1));
    final req = requests.single;
    expect(req, isA<ExactQtyRequest>());
    final exact = req as ExactQtyRequest;
    expect(exact.varietyId, seed.varietyId);
    expect(exact.crossSectionId, seed.reaperCrossSectionId);
    expect(exact.lengthFt, 6);
    expect(exact.quantityUnits, 1);

    // The adjustable staged line (with its +/- stepper) is shown.
    await scrollTo(tester, const Key('staged_line_0'));
    expect(find.byKey(const Key('staged_line_0')), findsOneWidget);
    expect(find.byKey(const Key('staged_line_stepper_0')), findsOneWidget);
  });

  testWidgets('exact-qty staged line stepper still adjusts the quantity',
      (tester) async {
    await pumpScreen(tester);
    await selectVariety(tester);
    await tapKey(tester, Key('build_cs_${seed.reaperCrossSectionId}'));
    await tapKey(tester, const Key('build_length_6'));
    await tapKey(tester, const Key('build_add_line'));

    await scrollTo(tester, const Key('staged_line_stepper_0'));
    final inc = find.descendant(
      of: find.byKey(const Key('staged_line_stepper_0')),
      matching: find.byKey(const Key('quantity_stepper_increment')),
    );
    await tester.tap(inc);
    await tester.pumpAndSettle();

    final req = stagedRequests().single as ExactQtyRequest;
    expect(req.quantityUnits, 2);
  });

  testWidgets('target CFT · length → TargetCftFixedLengthRequest (Req 7.3)',
      (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, 'targetCftFixedLength');
    await selectVariety(tester);
    await tapKey(tester, Key('build_cs_${seed.reaperCrossSectionId}'));
    await tapKey(tester, const Key('build_length_7'));
    await scrollTo(tester, const Key('build_target_cft_field'));
    await tester.enterText(
      find.byKey(const Key('build_target_cft_field')),
      '5.5',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, const Key('build_add_target'));

    final req = stagedRequests().single;
    expect(req, isA<TargetCftFixedLengthRequest>());
    final fixed = req as TargetCftFixedLengthRequest;
    expect(fixed.crossSectionId, seed.reaperCrossSectionId);
    expect(fixed.lengthFt, 7);
    expect(fixed.targetCft, Rational(BigInt.from(11), BigInt.from(2)));
  });

  testWidgets(
      'target CFT · cross-section → TargetCftFlexCrossSectionRequest (Req 7.4)',
      (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, 'targetCftFlexCrossSection');
    await selectVariety(tester);
    await tapKey(tester, Key('build_cs_${seed.plankCrossSectionId}'));
    // No length picker for the flexible-length shape.
    expect(find.byKey(const Key('build_length_6')), findsNothing);
    await scrollTo(tester, const Key('build_target_cft_field'));
    await tester.enterText(
      find.byKey(const Key('build_target_cft_field')),
      '12',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, const Key('build_add_target'));

    final req = stagedRequests().single;
    expect(req, isA<TargetCftFlexCrossSectionRequest>());
    final flex = req as TargetCftFlexCrossSectionRequest;
    expect(flex.crossSectionId, seed.plankCrossSectionId);
    expect(flex.targetCft, Rational.fromInt(12));
  });

  testWidgets('target CFT · category → TargetCftFlexCategoryRequest (Req 7.5)',
      (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, 'targetCftFlexCategory');
    await selectVariety(tester);
    // Category shape shows a category picker, not a cross-section picker.
    expect(
      find.byKey(Key('build_cs_${seed.reaperCrossSectionId}')),
      findsNothing,
    );
    await tapKey(tester, const Key('build_category_reaper'));
    await scrollTo(tester, const Key('build_target_cft_field'));
    await tester.enterText(
      find.byKey(const Key('build_target_cft_field')),
      '20',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, const Key('build_add_target'));

    final req = stagedRequests().single;
    expect(req, isA<TargetCftFlexCategoryRequest>());
    final cat = req as TargetCftFlexCategoryRequest;
    expect(cat.targetCft, Rational.fromInt(20));
  });

  testWidgets('an invalid target CFT stages nothing and flags the field',
      (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, 'targetCftFlexCrossSection');
    await selectVariety(tester);
    await tapKey(tester, Key('build_cs_${seed.plankCrossSectionId}'));
    // No target CFT entered.
    await tapKey(tester, const Key('build_add_target'));

    expect(stagedRequests(), isEmpty);
    await scrollTo(tester, const Key('build_feedback'));
    expect(find.byKey(const Key('build_feedback')), findsOneWidget);
  });

  testWidgets('a staged target request can be removed', (tester) async {
    await pumpScreen(tester);
    await selectKind(tester, 'targetCftFlexCrossSection');
    await selectVariety(tester);
    await tapKey(tester, Key('build_cs_${seed.plankCrossSectionId}'));
    await scrollTo(tester, const Key('build_target_cft_field'));
    await tester.enterText(
      find.byKey(const Key('build_target_cft_field')),
      '8',
    );
    await tester.pumpAndSettle();
    await tapKey(tester, const Key('build_add_target'));
    expect(stagedRequests(), hasLength(1));

    await tapKey(tester, const Key('remove_target_0'));
    expect(stagedRequests(), isEmpty);
  });
}

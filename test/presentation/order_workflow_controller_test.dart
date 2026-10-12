/// Order-workflow controller test (app-ux-revamp task 8.1).
///
/// Drives the unified flow build -> review -> approve -> sold against an
/// in-memory database with a signed-in fake session and the fake hosted store,
/// then asserts (Requirements 4.2, 4.3, 4.5; design Property 34):
///
///   * selling writes exactly one local invoice and flips the draft to `sold`;
///   * re-selling the same draft id is a no-op (idempotent);
///   * save-for-later persists the staged lines and resume restores them.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/data/saved_orders_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/order_workflow_controller.dart';
import 'package:wood_cft/presentation/orders/staged_order_line.dart';
import 'package:wood_cft/presentation/orders/staged_target_request.dart';
import 'package:wood_cft/presentation/sell/allocation_review_providers.dart';
import 'package:wood_cft/presentation/settings/business_profile_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late CrossSection reaper;

  setUp(() async {
    db = openInMemoryDatabase();

    final varietyId = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'Teak',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    final csId = await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: 2,
            thicknessIn: 1,
            category: CategoryKind.reaper,
            bunchSize: 10,
          ),
        );
    reaper = CrossSection(
      id: csId,
      widthIn: 2,
      thicknessIn: 1,
      category: WoodCategory.reaper,
      bunchSize: 10,
    );
    // Confirmed stock: 100 pieces @6 ft so a 2-bunch (20pc) order fits.
    await db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: varietyId,
            crossSectionId: csId,
            lengthFt: 6,
            confirmedBalancePieces: const Value(100),
          ),
        );
    // A positive rate so finalize is not blocked for a missing rate.
    final pricing = PricingService(PriceRateRepository(db));
    await pricing.setRate(
      varietyId: varietyId,
      crossSectionId: csId,
      rate: Rational.fromInt(120),
    );

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(
          FakeAuthService(
            initialSession: const AuthSession(userId: 'owner-1'),
          ),
        ),
      ],
    );

    // Stage one line: 2 bunches @6 ft.
    container.read(stagedOrderLinesProvider.notifier).replaceAll([
      StagedOrderLine(
        varietyId: varietyId,
        varietyName: 'Teak',
        crossSection: reaper,
        lengthFt: 6,
        quantityUnits: 2,
      ),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('build -> review -> approve -> sold writes one invoice + flips status',
      () async {
    final controller = container.read(orderWorkflowControllerProvider.notifier);
    await controller.startNewOrder(title: 'Walk-in');
    final draftId = container.read(orderWorkflowControllerProvider).draftId!;

    // Re-stage lines after startNewOrder cleared them.
    container.read(stagedOrderLinesProvider.notifier).replaceAll([
      StagedOrderLine(
        varietyId: 1,
        varietyName: 'Teak',
        crossSection: reaper,
        lengthFt: 6,
        quantityUnits: 2,
      ),
    ]);

    await controller.review();
    expect(container.read(orderWorkflowControllerProvider).step, OrderStep.review);

    await controller.approve();
    expect(
      container.read(orderWorkflowControllerProvider).step,
      OrderStep.approved,
    );

    final allocation =
        await container.read(stagedOrderAllocationProvider.future);
    expect(allocation, isNotNull);

    await controller.finalizeSold(allocation: allocation!);
    final state = container.read(orderWorkflowControllerProvider);
    expect(state.error, isNull);
    expect(state.step, OrderStep.sold);
    expect(state.invoiceNumber, isNotNull);

    // Exactly one local invoice written and the draft is sold with an invoice.
    final invoices = await db.select(db.invoices).get();
    expect(invoices, hasLength(1));
    final saved = await SavedOrdersDao(db).loadOne(draftId);
    expect(saved!.draft.status, DraftStatus.sold);
    expect(saved.draft.invoiceId, invoices.single.id);
  });

  test('finalize is blocked when the allocation has zero allocated pieces '
      '(FIX 2)', () async {
    // A SKU with NO confirmed stock: the allocator can allocate 0 pieces, so
    // finalizing would issue a 0 CFT / ₹0.00 "sale" — it must be refused.
    final emptyVarietyId = await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            name: 'OutOfStock',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    final emptyCsId = await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            widthIn: 3,
            thicknessIn: 1,
            category: CategoryKind.plank,
            bunchSize: 1,
          ),
        );
    final emptyCs = CrossSection(
      id: emptyCsId,
      widthIn: 3,
      thicknessIn: 1,
      category: WoodCategory.plank,
    );
    // Stock item exists but with zero confirmed balance.
    await db.into(db.stockItems).insert(
          StockItemsCompanion.insert(
            varietyId: emptyVarietyId,
            crossSectionId: emptyCsId,
            lengthFt: 6,
          ),
        );
    final pricing = PricingService(PriceRateRepository(db));
    await pricing.setRate(
      varietyId: emptyVarietyId,
      crossSectionId: emptyCsId,
      rate: Rational.fromInt(120),
    );

    final controller = container.read(orderWorkflowControllerProvider.notifier);
    await controller.startNewOrder();
    container.read(stagedOrderLinesProvider.notifier).replaceAll([
      StagedOrderLine(
        varietyId: emptyVarietyId,
        varietyName: 'OutOfStock',
        crossSection: emptyCs,
        lengthFt: 6,
        quantityUnits: 5,
      ),
    ]);
    await controller.review();
    await controller.approve();
    final allocation =
        await container.read(stagedOrderAllocationProvider.future);
    expect(allocation, isNotNull);
    // The allocation exists but allocated zero pieces.
    final allocatedPieces = allocation!.lines
        .fold<int>(0, (sum, line) => sum + line.allocatedPieces);
    expect(allocatedPieces, 0);

    await controller.finalizeSold(allocation: allocation);
    final state = container.read(orderWorkflowControllerProvider);
    expect(state.step, OrderStep.approved); // not advanced to sold
    expect(state.error, 'Nothing to finalize — no stock allocated.');
    // Nothing was written.
    final invoices = await db.select(db.invoices).get();
    expect(invoices, isEmpty);
  });

  test('two different orders get persistent INV-1 then INV-2 (FIX 1)',
      () async {
    final controller = container.read(orderWorkflowControllerProvider.notifier);

    Future<void> sellOne() async {
      await controller.startNewOrder();
      container.read(stagedOrderLinesProvider.notifier).replaceAll([
        StagedOrderLine(
          varietyId: 1,
          varietyName: 'Teak',
          crossSection: reaper,
          lengthFt: 6,
          quantityUnits: 1,
        ),
      ]);
      await controller.review();
      await controller.approve();
      final allocation =
          await container.read(stagedOrderAllocationProvider.future);
      await controller.finalizeSold(allocation: allocation!);
    }

    await sellOne();
    final firstNumber =
        container.read(orderWorkflowControllerProvider).invoiceNumber;
    await sellOne();
    final secondNumber =
        container.read(orderWorkflowControllerProvider).invoiceNumber;

    expect(firstNumber, 1);
    expect(secondNumber, 2);

    final invoices = await db.select(db.invoices).get();
    expect(invoices, hasLength(2));
    final numbers = invoices.map((i) => i.invoiceNumber).toList()..sort();
    expect(numbers, ['INV-1', 'INV-2']);
  });

  test('re-selling the same draft is idempotent (no second invoice)',
      () async {
    final controller = container.read(orderWorkflowControllerProvider.notifier);
    await controller.startNewOrder();
    container.read(stagedOrderLinesProvider.notifier).replaceAll([
      StagedOrderLine(
        varietyId: 1,
        varietyName: 'Teak',
        crossSection: reaper,
        lengthFt: 6,
        quantityUnits: 2,
      ),
    ]);
    await controller.review();
    await controller.approve();
    final allocation =
        await container.read(stagedOrderAllocationProvider.future);

    await controller.finalizeSold(allocation: allocation!);
    await controller.finalizeSold(allocation: allocation);

    final invoices = await db.select(db.invoices).get();
    expect(invoices, hasLength(1));
  });

  test('target-CFT requests reach allocation as their real types', () async {
    final controller = container.read(orderWorkflowControllerProvider.notifier);
    await controller.startNewOrder();

    // Stage one fixed-length target request (not an exact-qty line).
    container.read(stagedTargetRequestsProvider.notifier).replaceAll([
      StagedTargetRequest(
        kind: StagedTargetKind.fixedLength,
        varietyId: 1,
        varietyName: 'Teak',
        crossSection: reaper,
        lengthFt: 6,
        targetCft: Rational.fromInt(2),
      ),
    ]);

    final requests = container.read(stagedOrderRequestsProvider);
    expect(requests, hasLength(1));
    expect(requests.single, isA<TargetCftFixedLengthRequest>());

    // The target request allocates against confirmed stock.
    final allocation =
        await container.read(stagedOrderAllocationProvider.future);
    expect(allocation, isNotNull);
    expect(allocation!.lines, isNotEmpty);
  });

  test('save-for-later persists target requests and resume restores them',
      () async {
    final controller = container.read(orderWorkflowControllerProvider.notifier);
    await controller.startNewOrder(title: 'Target later');
    final draftId = container.read(orderWorkflowControllerProvider).draftId!;

    container.read(stagedOrderLinesProvider.notifier).clear();
    container.read(stagedTargetRequestsProvider.notifier).replaceAll([
      StagedTargetRequest(
        kind: StagedTargetKind.fixedLength,
        varietyId: 1,
        varietyName: 'Teak',
        crossSection: reaper,
        lengthFt: 6,
        targetCft: Rational(BigInt.from(11), BigInt.from(2)),
      ),
    ]);

    await controller.saveForLater();
    expect(container.read(stagedTargetRequestsProvider), isEmpty);

    await controller.resume(draftId);
    final restored = container.read(stagedTargetRequestsProvider);
    expect(restored, hasLength(1));
    expect(restored.single.kind, StagedTargetKind.fixedLength);
    expect(restored.single.lengthFt, 6);
    // Exact rational round-trips with no float drift.
    expect(
      restored.single.targetCft,
      Rational(BigInt.from(11), BigInt.from(2)),
    );
  });

  test('save-for-later persists lines and resume restores them', () async {
    final controller = container.read(orderWorkflowControllerProvider.notifier);
    await controller.startNewOrder(title: 'Later');
    final draftId = container.read(orderWorkflowControllerProvider).draftId!;
    container.read(stagedOrderLinesProvider.notifier).replaceAll([
      StagedOrderLine(
        varietyId: 1,
        varietyName: 'Teak',
        crossSection: reaper,
        lengthFt: 6,
        quantityUnits: 3,
      ),
    ]);

    await controller.saveForLater();
    expect(container.read(orderWorkflowControllerProvider).draftId, isNull);
    expect(container.read(stagedOrderLinesProvider), isEmpty);

    await controller.resume(draftId);
    final lines = container.read(stagedOrderLinesProvider);
    expect(lines, hasLength(1));
    expect(lines.single.lengthFt, 6);
    expect(lines.single.quantityUnits, 3);
    expect(
      container.read(orderWorkflowControllerProvider).draftId,
      draftId,
    );
  });
}

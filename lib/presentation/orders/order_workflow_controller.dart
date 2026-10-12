/// The unified order-workflow controller (app-ux-revamp Requirement 4).
///
/// Composes the existing allocation / billing / finalize engines with the new
/// saved-order persistence ([SavedOrdersDao]) and local-invoice mirror
/// ([LocalInvoiceWriter]) to drive one linear, resumable order flow:
///
/// ```text
/// build -> review -> approved -> sold -> shared
/// ```
///
/// It owns the current [DraftOrders] id and the workflow [OrderStep], persists
/// the staged exact-quantity request lines, runs `AllocationService` on
/// `review()`, finalizes on `sold` under an order-scoped idempotency key
/// (`order:{draftId}`) and mirrors the invoice locally, and parks the draft on
/// `saveForLater()` so the Orders tab can resume it (Requirement 4.1-4.7).
///
/// "Sold" is idempotent per draft id: the hosted finalize is keyed
/// `order:{draftId}` and the local write is keyed by the finalize key, so
/// re-selling the same draft is a no-op (design Property 34; inherits finalize
/// Property 19).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/application/auth_providers.dart';
import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/application/inventory_query_service.dart';
import 'package:wood_cft/application/pricing_service.dart';
import 'package:wood_cft/data/hosted_database_providers.dart';
import 'package:wood_cft/data/local_invoice_writer.dart';
import 'package:wood_cft/data/price_rate_repository.dart';
import 'package:wood_cft/data/sales_query_dao.dart';
import 'package:wood_cft/data/saved_orders_dao.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/presentation/orders/order_build_providers.dart';
import 'package:wood_cft/presentation/orders/staged_order_line.dart';
import 'package:wood_cft/presentation/orders/staged_target_request.dart';
import 'package:wood_cft/presentation/sell/sell_providers.dart'
    show appDatabaseProvider;
import 'package:wood_cft/presentation/settings/policy_providers.dart';
import 'package:wood_cft/presentation/stock/receiving_providers.dart'
    show toDomainCrossSection;

/// The provider for the shared [SavedOrdersDao] over the app database.
final savedOrdersDaoProvider = Provider<SavedOrdersDao>(
  (ref) => SavedOrdersDao(ref.watch(appDatabaseProvider)),
);

/// The provider for the shared [LocalInvoiceWriter] over the app database.
final localInvoiceWriterProvider = Provider<LocalInvoiceWriter>(
  (ref) => LocalInvoiceWriter(ref.watch(appDatabaseProvider)),
);

/// The provider for the shared [SalesQueryDao] over the app database.
final salesQueryDaoProvider = Provider<SalesQueryDao>(
  (ref) => SalesQueryDao(ref.watch(appDatabaseProvider)),
);

/// The linear steps the order workflow advances through (Requirement 4.1).
enum OrderStep {
  /// Selecting / adjusting items (the build surface).
  build,

  /// Reviewing the computed allocation (picking list).
  review,

  /// The reviewed allocation is approved and ready to finalize.
  approved,

  /// Finalized into a permanent invoice; stock deducted, sale recorded.
  sold,

  /// The finalized bill has been shared/exported.
  shared,
}

/// Maps a workflow [OrderStep] to the persisted [DraftStatus] it parks at.
DraftStatus _statusForStep(OrderStep step) => switch (step) {
      OrderStep.build => DraftStatus.draft,
      OrderStep.review => DraftStatus.review,
      OrderStep.approved => DraftStatus.approved,
      OrderStep.sold => DraftStatus.sold,
      OrderStep.shared => DraftStatus.shared,
    };

/// Maps a persisted [DraftStatus] back to the workflow step to resume at.
OrderStep _stepForStatus(DraftStatus status) => switch (status) {
      DraftStatus.draft || DraftStatus.preview => OrderStep.build,
      DraftStatus.review => OrderStep.review,
      DraftStatus.approved => OrderStep.approved,
      DraftStatus.sold => OrderStep.sold,
      DraftStatus.shared => OrderStep.shared,
    };

/// The immutable workflow state the Orders UI renders.
@immutable
class OrderWorkflowState {
  /// Creates a workflow state.
  const OrderWorkflowState({
    this.draftId,
    this.step = OrderStep.build,
    this.busy = false,
    this.invoiceNumber,
    this.invoice,
    this.error,
  });

  /// The idle starting state (no active order).
  static const OrderWorkflowState idle = OrderWorkflowState();

  /// The persisted draft id of the active order, or null before one starts.
  final int? draftId;

  /// The current workflow step.
  final OrderStep step;

  /// Whether an async workflow action is running.
  final bool busy;

  /// The issued invoice number once sold, else null.
  final int? invoiceNumber;

  /// The full finalized invoice once sold, else null. Carried so the sold-order
  /// UI can build the share/export snapshot (FIX 3) without re-finalizing.
  final FinalizedInvoice? invoice;

  /// A human-readable error (e.g. a finalize block reason), else null.
  final String? error;

  /// A copy with the given fields replaced.
  OrderWorkflowState copyWith({
    int? draftId,
    OrderStep? step,
    bool? busy,
    int? invoiceNumber,
    FinalizedInvoice? invoice,
    String? error,
    bool clearError = false,
    bool clearInvoice = false,
  }) {
    return OrderWorkflowState(
      draftId: draftId ?? this.draftId,
      step: step ?? this.step,
      busy: busy ?? this.busy,
      invoiceNumber: clearInvoice ? null : (invoiceNumber ?? this.invoiceNumber),
      invoice: clearInvoice ? null : (invoice ?? this.invoice),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The order-workflow controller (see [orderWorkflowControllerProvider]).
final orderWorkflowControllerProvider =
    NotifierProvider<OrderWorkflowController, OrderWorkflowState>(
  OrderWorkflowController.new,
);

/// Drives the unified, resumable order workflow.
class OrderWorkflowController extends Notifier<OrderWorkflowState> {
  @override
  OrderWorkflowState build() => OrderWorkflowState.idle;

  SavedOrdersDao get _saved => ref.read(savedOrdersDaoProvider);

  /// Starts a new, empty order: creates a persisted draft row and clears the
  /// staged build lines (Requirement 4.1).
  Future<void> startNewOrder({String? title, String? customerName}) async {
    state = const OrderWorkflowState(busy: true);
    final id = await _saved.createDraft(title: title, customerName: customerName);
    ref.read(stagedOrderLinesProvider.notifier).clear();
    ref.read(stagedTargetRequestsProvider.notifier).clear();
    state = OrderWorkflowState(draftId: id);
  }

  /// Persists the current staged lines (exact-quantity) and target requests to
  /// the draft (used before leaving the build step or saving for later).
  Future<void> _persistStagedLines() async {
    final id = state.draftId;
    if (id == null) return;
    final lines = ref.read(stagedOrderLinesProvider);
    final targets = ref.read(stagedTargetRequestsProvider);
    await _saved.replaceRequestLines(
      id,
      [
        for (final l in lines)
          SavedRequestLine(
            varietyId: l.varietyId,
            crossSectionId: l.crossSection.id,
            lengthFt: l.lengthFt,
            qty: l.quantityUnits,
          ),
      ],
      targets: [for (final t in targets) _toSavedTarget(t)],
    );
  }

  /// Maps a staged target request to its persisted [SavedTargetLine].
  SavedTargetLine _toSavedTarget(StagedTargetRequest t) {
    final requestType = switch (t.kind) {
      StagedTargetKind.fixedLength => RequestType.targetCftFixedLen,
      StagedTargetKind.flexCrossSection =>
        RequestType.targetCftFlexCrossSection,
      StagedTargetKind.flexCategory => RequestType.targetCftFlexCategory,
    };
    return SavedTargetLine(
      requestType: requestType,
      varietyId: t.varietyId,
      crossSectionId: t.crossSection?.id,
      category: t.category == null ? null : _toCategoryKind(t.category!),
      lengthFt: t.lengthFt,
      targetCftNum: t.targetCft.numerator,
      targetCftDen: t.targetCft.denominator,
    );
  }

  /// Persists the staged lines and advances to the review step, flipping the
  /// draft to `review` status (Requirement 4.1). Allocation itself is computed
  /// by `orderAllocationProvider` on the review surface.
  Future<void> review() async {
    final id = state.draftId;
    if (id == null) return;
    state = state.copyWith(busy: true, clearError: true);
    await _persistStagedLines();
    await _saved.updateStatus(id, DraftStatus.review);
    state = state.copyWith(busy: false, step: OrderStep.review);
  }

  /// Approves the reviewed allocation, flipping the draft to `approved`
  /// (Requirement 4.5 first half).
  Future<void> approve() async {
    final id = state.draftId;
    if (id == null) return;
    state = state.copyWith(busy: true, clearError: true);
    await _saved.updateStatus(id, DraftStatus.approved);
    state = state.copyWith(busy: false, step: OrderStep.approved);
  }

  /// Returns to the build step (backward navigation).
  void back() {
    switch (state.step) {
      case OrderStep.review:
        state = state.copyWith(step: OrderStep.build);
      case OrderStep.approved:
        state = state.copyWith(step: OrderStep.review);
      case OrderStep.build:
      case OrderStep.sold:
      case OrderStep.shared:
        break;
    }
  }

  /// Finalizes the approved order into a permanent invoice keyed
  /// `order:{draftId}`, mirrors it into the local tables, flips the draft to
  /// `sold`, and attaches the local invoice id. Idempotent per draft id
  /// (Requirement 4.5; design Property 34).
  ///
  /// On a block (missing rate / insufficient stock / no session) the order
  /// stays resumable and the reason is surfaced (Requirement 4.7).
  Future<void> finalizeSold({
    required OrderAllocation allocation,
  }) async {
    final id = state.draftId;
    if (id == null) return;

    // FIX 2: refuse to finalize an empty / fully-shorted allocation. If no
    // pieces are allocated (e.g. nothing in confirmed stock), there is nothing
    // to sell — finalizing would issue a 0 CFT / ₹0.00 "sale". The order stays
    // resumable and the reason is surfaced (Requirement 4.7).
    final allocatedPieces = allocation.lines
        .fold<int>(0, (sum, line) => sum + line.allocatedPieces);
    if (allocatedPieces == 0) {
      state = state.copyWith(
        error: 'Nothing to finalize — no stock allocated.',
      );
      return;
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final db = ref.read(appDatabaseProvider);
      final pricing = PricingService(PriceRateRepository(db));
      final inventory = InventoryQueryService(db);
      final taxMode = ref.read(taxModeProvider);
      final loadingPolicy = ref.read(loadingPolicyProvider);
      final auth = ref.read(authServiceProvider);
      final hosted = ref.read(hostedDatabaseProvider);

      final rows = await inventory.query(const InventoryFilter());
      final byItem = <int, InventoryRow>{
        for (final r in rows.rows) r.stockItemId: r,
      };

      final snapshots = <int, LineSnapshotInput>{};
      final confirmedById = <int, int>{};
      for (final line in allocation.lines) {
        final row = byItem[line.stockItemId];
        confirmedById[line.stockItemId] = row?.availablePieces ?? 0;
        final rate = await pricing.rateFor(
          varietyId: line.varietyId,
          crossSectionId: line.crossSectionId,
        );
        if (rate != null && rate.numerator > BigInt.zero) {
          snapshots[line.stockItemId] = LineSnapshotInput(
            stockItemId: line.stockItemId,
            varietyId: line.varietyId,
            varietyName:
                row?.varietyName ?? 'Variety #${line.varietyId}',
            label: row?.crossSectionLabel ?? '#${line.crossSectionId}',
            rate: rate,
          );
        }
      }
      final confirmedStock = [
        for (final e in confirmedById.entries)
          ConfirmedStock(stockItemId: e.key, confirmedPieces: e.value),
      ];

      final service = FinalizeService(
        hostedDatabase: hosted,
        authService: auth,
      );

      // FIX 1: allocate a PERSISTENT, unique invoice number from the local DB
      // (max existing number + 1) and seed the in-memory allocator with it, so
      // repeated finalizes of different orders get INV-1, INV-2, INV-3… instead
      // of every finalize restarting the sequence at 1 and colliding on the
      // UNIQUE(invoiceNumber) constraint. The write below is still keyed by the
      // order-scoped idempotency key, so a true retry of the SAME draft reuses
      // the existing row and never consumes a fresh number.
      final writer = ref.read(localInvoiceWriterProvider);
      final nextNumber = await writer.nextInvoiceNumber();

      final invoice = await service.finalizeSale(
        allocation: allocation,
        snapshots: snapshots,
        confirmedStock: confirmedStock,
        taxMode: taxMode,
        numberAllocator: InMemoryInvoiceNumberAllocator(start: nextNumber),
        // Order-scoped key so re-selling the same draft is a no-op.
        idempotencyKey: 'order:$id',
        policy: loadingPolicy,
      );

      // Mirror the invoice locally (idempotent) and flip the draft to sold.
      final localId = await writer.write(
        invoice,
        invoiceNumberText: 'INV-${invoice.number}',
      );
      await _saved.attachInvoice(id, localId);
      await _saved.updateStatus(id, DraftStatus.sold);

      state = state.copyWith(
        busy: false,
        step: OrderStep.sold,
        invoiceNumber: invoice.number,
        invoice: invoice,
      );
    } on FinalizeBlockedException catch (e) {
      state = state.copyWith(busy: false, error: e.reason);
    } on NotAuthenticatedException {
      state = state.copyWith(
        busy: false,
        error: 'Sign in to finalize. The order stays resumable until you do.',
      );
    } on Object catch (e) {
      state = state.copyWith(busy: false, error: 'Could not finalize: $e');
    }
  }

  /// Marks the sold order as `shared` after the bill is exported. Sharing never
  /// mutates stock or re-finalizes (Requirement 4.6).
  Future<void> share() async {
    final id = state.draftId;
    if (id == null || state.step != OrderStep.sold) return;
    await _saved.updateStatus(id, DraftStatus.shared);
    state = state.copyWith(step: OrderStep.shared);
  }

  /// Persists the staged lines and parks the draft at its current step so it is
  /// resumable later, then returns the controller to idle (Requirement 4.2).
  Future<void> saveForLater() async {
    final id = state.draftId;
    if (id == null) return;
    await _persistStagedLines();
    await _saved.updateStatus(id, _statusForStep(state.step));
    ref.read(stagedOrderLinesProvider.notifier).clear();
    ref.read(stagedTargetRequestsProvider.notifier).clear();
    state = OrderWorkflowState.idle;
  }

  /// Resumes a saved order: loads its draft + staged lines, rebuilds the staged
  /// build lines, and restores the workflow step (Requirement 4.3, 4.4).
  Future<void> resume(int draftId) async {
    state = const OrderWorkflowState(busy: true);
    final db = ref.read(appDatabaseProvider);
    final saved = await _saved.loadOne(draftId);
    if (saved == null) {
      state = OrderWorkflowState.idle;
      return;
    }
    // Resolve each staged request line's cross-section into the domain object
    // so the build surface can recompute exact CFT.
    final crossSections = await db.select(db.crossSections).get();
    final varieties = await db.select(db.woodVarieties).get();
    final csById = {for (final c in crossSections) c.id: c};
    final varietyNameById = {for (final v in varieties) v.id: v.name};

    final lines = <StagedOrderLine>[];
    for (final l in saved.lines) {
      final csRow = csById[l.crossSectionId];
      if (csRow == null) continue;
      lines.add(
        StagedOrderLine(
          varietyId: l.varietyId,
          varietyName: varietyNameById[l.varietyId] ?? 'Variety #${l.varietyId}',
          crossSection: toDomainCrossSection(csRow),
          lengthFt: l.lengthFt,
          quantityUnits: l.qty,
        ),
      );
    }

    // Rebuild the staged target-CFT requests from their persisted constraints.
    final targets = <StagedTargetRequest>[];
    for (final t in saved.targets) {
      final name = varietyNameById[t.varietyId] ?? 'Variety #${t.varietyId}';
      final targetCft = Rational(t.targetCftNum, t.targetCftDen);
      switch (t.requestType) {
        case RequestType.exactQty:
          // Exact-qty rows are restored as adjustable lines above.
          break;
        case RequestType.targetCftFixedLen:
          final csRow = t.crossSectionId == null ? null : csById[t.crossSectionId];
          if (csRow == null || t.lengthFt == null) continue;
          targets.add(
            StagedTargetRequest(
              kind: StagedTargetKind.fixedLength,
              varietyId: t.varietyId,
              varietyName: name,
              crossSection: toDomainCrossSection(csRow),
              lengthFt: t.lengthFt,
              targetCft: targetCft,
            ),
          );
        case RequestType.targetCftFlexCrossSection:
          final csRow = t.crossSectionId == null ? null : csById[t.crossSectionId];
          if (csRow == null) continue;
          targets.add(
            StagedTargetRequest(
              kind: StagedTargetKind.flexCrossSection,
              varietyId: t.varietyId,
              varietyName: name,
              crossSection: toDomainCrossSection(csRow),
              targetCft: targetCft,
            ),
          );
        case RequestType.targetCftFlexCategory:
          final category = t.category;
          if (category == null) continue;
          targets.add(
            StagedTargetRequest(
              kind: StagedTargetKind.flexCategory,
              varietyId: t.varietyId,
              varietyName: name,
              category: _toDomainCategory(category),
              targetCft: targetCft,
            ),
          );
      }
    }

    ref.read(stagedOrderLinesProvider.notifier).replaceAll(lines);
    ref.read(stagedTargetRequestsProvider.notifier).replaceAll(targets);
    state = OrderWorkflowState(
      draftId: draftId,
      step: _stepForStatus(saved.draft.status),
    );
  }
}

/// Maps the domain [WoodCategory] to the persisted [CategoryKind].
CategoryKind _toCategoryKind(WoodCategory category) => switch (category) {
      WoodCategory.reaper => CategoryKind.reaper,
      WoodCategory.plank => CategoryKind.plank,
    };

/// Maps the persisted [CategoryKind] back to the domain [WoodCategory].
WoodCategory _toDomainCategory(CategoryKind kind) => switch (kind) {
      CategoryKind.reaper => WoodCategory.reaper,
      CategoryKind.plank => WoodCategory.plank,
    };

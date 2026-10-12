/// The Sell-tab allocation review / picking-list screen (task 9.5).
///
/// This is the "Allocation review / picking list" surface from design.md ->
/// Screen Flows -> Sell tab. It takes the structured requests the owner staged
/// on the draft, runs the shared `AllocationService.allocateOrder` against the
/// CONFIRMED (sellable) inventory through `orderAllocationProvider`, and
/// renders the resulting picking list so the owner can see exactly what the
/// heuristic proposes before billing:
///
///   * **Per request line** — the requested target (an exact whole-unit
///     quantity, or a meet-or-exceed target CFT) alongside the allocated CFT
///     and the signed over/under CFT delta (`allocated − requested`, shown as
///     `+x.xxxx` / `-x.xxxx CFT`), so an over-allocation (meet-or-exceed
///     round-up) and an under-allocation (partial) are both visible
///     (Requirement 8.3).
///   * **The picking rows** — for every allocation line the engine produced:
///     which stock item + length, the allocated whole units (bunches for a
///     reaper, pieces for a plank) with the piece-equivalent, and the exact
///     allocated CFT, each with an EXPLICIT unit label — never a bare number
///     (Requirement 17.6).
///   * **PARTIAL labelling** — a line the confirmed stock could not fully meet
///     is clearly labelled a **partial** with its shortage (units/pieces for a
///     fixed line, CFT for a flexible line); it is NEVER shown as "fulfilled"
///     (Requirements 8.3, 8.4). The order-level banner is likewise a partial
///     whenever ANY line is short.
///   * **Meet-or-exceed only** — the targets are round-up (meet or exceed); the
///     screen never implies an at-most / closest fill (Requirement 7.6, CD-3).
///
/// Accessibility (Requirements 17.3, 17.5, 17.6): quantities and CFT carry
/// explicit unit labels, the partial cue is an icon + the word "PARTIAL" (never
/// colour alone), and each line is wrapped in a VoiceOver-friendly
/// [Semantics] summary.
///
/// This widget is presentation-only: the draft, the confirmed availability, and
/// the allocation all live behind the providers in
/// `allocation_review_providers.dart` and the headless `AllocationService` /
/// `CalculationService`. The heuristic is a bounded, deterministic proposal and
/// is NOT claimed optimal (Requirement 8.12).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/allocation_service.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/order_request.dart';
import 'package:wood_cft/presentation/sell/allocation_review_providers.dart';

/// The minimum Apple-HIG touch-target size in logical points (Requirement
/// 17.3).
const double kMinTouchTarget = 44;

/// The Sell-tab allocation review / picking-list screen.
class AllocationReviewScreen extends ConsumerWidget {
  /// Creates the allocation review screen.
  const AllocationReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(draftOrderRequestsProvider);
    final allocationAsync = ref.watch(orderAllocationProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Allocation review'),
      ),
      child: SafeArea(
        child: allocationAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => _ErrorState(message: '$error'),
          data: (allocation) {
            if (allocation == null) {
              return const _EmptyState();
            }
            return _PickingList(requests: requests, allocation: allocation);
          },
        ),
      ),
    );
  }
}

/// The empty-draft state: nothing has been staged, so there is nothing to
/// review yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No order lines to review yet. Build the order first.',
          key: const Key('allocation_review_empty'),
          textAlign: TextAlign.center,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
        ),
      ),
    );
  }
}

/// Surfaces an allocation error (e.g. an unsupported request shape) so the
/// owner is told rather than shown a silently wrong proposal.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not build the picking list.\n$message',
          key: const Key('allocation_review_error'),
          textAlign: TextAlign.center,
          style: CupertinoTheme.of(context).textTheme.textStyle,
        ),
      ),
    );
  }
}

/// The scrollable picking list: an order-level status banner, one card per
/// staged request line, and a totals footer.
class _PickingList extends StatelessWidget {
  const _PickingList({required this.requests, required this.allocation});

  final List<OrderRequest> requests;
  final OrderAllocation allocation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('allocation_review_list'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _OrderStatusBanner(isPartial: allocation.isPartial),
        for (final line in allocation.lineResults)
          _LineCard(
            request: _requestFor(line),
            line: line,
          ),
        _TotalsFooter(allocation: allocation),
      ],
    );
  }

  /// The staged request that produced [line], matched by its request index.
  OrderRequest? _requestFor(OrderLineAllocation line) {
    if (line.requestIndex < 0 || line.requestIndex >= requests.length) {
      return null;
    }
    return requests[line.requestIndex];
  }
}

/// The order-level status banner: a clearly-labelled partial when ANY line is
/// short, or a complete banner when every line met-or-exceeded its target
/// (Requirement 8.4). Icon + text, never colour alone (Requirement 17.5).
class _OrderStatusBanner extends StatelessWidget {
  const _OrderStatusBanner({required this.isPartial});

  final bool isPartial;

  @override
  Widget build(BuildContext context) {
    final color = isPartial
        ? CupertinoColors.systemOrange
        : CupertinoColors.activeGreen;
    final resolved = CupertinoDynamicColor.resolve(color, context);
    final icon = isPartial
        ? CupertinoIcons.exclamationmark_triangle_fill
        : CupertinoIcons.checkmark_seal_fill;
    final label = isPartial
        ? 'PARTIAL — some lines could not be fully met'
        : 'All lines met or exceeded';

    return Container(
      key: const Key('allocation_order_status'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: resolved.withValues(alpha: 0.5)),
      ),
      child: Semantics(
        container: true,
        label: isPartial
            ? 'Order status: partial. Some lines could not be fully met.'
            : 'Order status: all lines met or exceeded.',
        child: Row(
          children: [
            Icon(icon, size: 18, color: resolved),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: resolved,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One staged request line: its requested-vs-allocated-vs-±CFT header, a
/// PARTIAL badge with the shortage when short, and the picking rows the engine
/// produced for it.
class _LineCard extends StatelessWidget {
  const _LineCard({required this.request, required this.line});

  final OrderRequest? request;
  final OrderLineAllocation line;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final index = line.requestIndex;

    final allocatedCft = _allocatedCft(line);
    final requestedCft = _requestedCft(request);
    final requestedLabel = _requestedLabel(request);

    return Container(
      key: Key('allocation_line_$index'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Line ${index + 1}  ·  $requestedLabel',
                  key: Key('allocation_line_${index}_requested'),
                  style: theme.textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (line.isPartial) const _PartialBadge(),
            ],
          ),
          const SizedBox(height: 8),
          _RequestedVsAllocated(
            index: index,
            requestedCft: requestedCft,
            allocatedCft: allocatedCft,
          ),
          const SizedBox(height: 10),
          if (line.lines.isEmpty)
            Text(
              'Nothing allocated — no confirmed stock available.',
              key: Key('allocation_line_${index}_nothing'),
              style: theme.textTheme.tabLabelTextStyle.copyWith(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            )
          else
            for (var i = 0; i < line.lines.length; i++)
              _PickRow(
                lineIndex: index,
                pickIndex: i,
                pick: line.lines[i],
              ),
          if (line.isPartial) ...[
            const SizedBox(height: 8),
            _ShortageText(index: index, line: line),
          ],
        ],
      ),
    );
  }
}

/// The requested CFT vs the allocated CFT, with the signed over/under delta.
///
/// For an exact-quantity line there is no target CFT, so only the allocated
/// CFT is shown; for a target-CFT line the requested target and the signed
/// `allocated − requested` delta are both shown (Requirement 8.3).
class _RequestedVsAllocated extends StatelessWidget {
  const _RequestedVsAllocated({
    required this.index,
    required this.requestedCft,
    required this.allocatedCft,
  });

  final int index;
  final Rational? requestedCft;
  final Cft allocatedCft;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final labelStyle = theme.textTheme.tabLabelTextStyle.copyWith(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final valueStyle = theme.textTheme.textStyle.copyWith(fontSize: 14);

    final requested = requestedCft;
    final deltaText = requested == null
        ? null
        : _signedCft(allocatedCft.value - requested);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requested != null)
          _kv(
            key: Key('allocation_line_${index}_requested_cft'),
            label: 'Requested',
            value: '≥ ${Cft(requested).toFixed()} CFT',
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        _kv(
          key: Key('allocation_line_${index}_allocated_cft'),
          label: 'Allocated',
          value: '${allocatedCft.toFixed()} CFT',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        if (deltaText != null)
          _kv(
            key: Key('allocation_line_${index}_delta_cft'),
            label: 'Over / under',
            value: '$deltaText CFT',
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
      ],
    );
  }

  Widget _kv({
    required Key key,
    required String label,
    required String value,
    required TextStyle labelStyle,
    required TextStyle valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: labelStyle)),
          Expanded(child: Text(value, key: key, style: valueStyle)),
        ],
      ),
    );
  }
}

/// A single picking row: the source stock item + length, the allocated whole
/// units with the piece-equivalent, and the exact allocated CFT.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.lineIndex,
    required this.pickIndex,
    required this.pick,
  });

  final int lineIndex;
  final int pickIndex;
  final AllocationLine pick;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final qtyLabel = _quantityLabel(pick);
    final cftLabel = '${pick.allocatedCft.toFixed()} CFT';
    final skuLabel = 'Item #${pick.stockItemId}  ·  ${pick.lengthFt} ft';

    return Semantics(
      container: true,
      label: 'Pick $skuLabel: $qtyLabel, $cftLabel.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 8),
              child: Icon(CupertinoIcons.cube_box, size: 15),
            ),
            Expanded(
              child: Text(
                skuLabel,
                key: Key('allocation_pick_${lineIndex}_${pickIndex}_sku'),
                style: theme.textTheme.textStyle.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  qtyLabel,
                  key: Key('allocation_pick_${lineIndex}_${pickIndex}_qty'),
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  cftLabel,
                  key: Key('allocation_pick_${lineIndex}_${pickIndex}_cft'),
                  style: theme.textTheme.tabLabelTextStyle.copyWith(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The partial shortage text for a line: units/pieces for a fixed line, CFT for
/// a flexible line (Requirements 8.3, 8.4).
class _ShortageText extends StatelessWidget {
  const _ShortageText({required this.index, required this.line});

  final int index;
  final OrderLineAllocation line;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final resolved = CupertinoDynamicColor.resolve(
      CupertinoColors.systemOrange,
      context,
    );
    return Text(
      _shortageLabel(line),
      key: Key('allocation_line_${index}_shortage'),
      style: theme.textTheme.textStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: resolved,
      ),
    );
  }
}

/// A non-colour PARTIAL cue: an icon AND the word "PARTIAL" so a short line is
/// never conveyed by colour alone (Requirements 8.4, 17.5).
class _PartialBadge extends StatelessWidget {
  const _PartialBadge();

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(
      CupertinoColors.systemOrange,
      context,
    );
    return Container(
      key: const Key('allocation_partial_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: resolved.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 13,
            color: resolved,
          ),
          const SizedBox(width: 4),
          Text(
            'PARTIAL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: resolved,
            ),
          ),
        ],
      ),
    );
  }
}

/// The order-level totals footer: the exact total allocated CFT and the total
/// allocated pieces across every picking line (Requirement 17.6).
class _TotalsFooter extends StatelessWidget {
  const _TotalsFooter({required this.allocation});

  final OrderAllocation allocation;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    var totalPieces = 0;
    final cfts = <Cft>[];
    for (final pick in allocation.lines) {
      totalPieces += pick.allocatedPieces;
      cfts.add(pick.allocatedCft);
    }
    var totalCft = Cft.zero;
    for (final c in cfts) {
      totalCft += c;
    }

    return Container(
      key: const Key('allocation_review_totals'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allocated total',
                  style: theme.textTheme.tabLabelTextStyle.copyWith(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalPieces pcs',
                  key: const Key('allocation_total_pieces'),
                  style: theme.textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${totalCft.toFixed()} CFT',
            key: const Key('allocation_total_cft'),
            style: theme.textTheme.navTitleTextStyle.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// The exact total allocated CFT of a line (sum of its picking rows).
Cft _allocatedCft(OrderLineAllocation line) {
  var total = Cft.zero;
  for (final pick in line.lines) {
    total += pick.allocatedCft;
  }
  return total;
}

/// The requested target CFT for a line, or `null` for an exact-quantity line
/// (which has no CFT target — its demand is a literal whole-unit count).
Rational? _requestedCft(OrderRequest? request) => switch (request) {
      TargetCftFixedLengthRequest(:final targetCft) => targetCft,
      TargetCftFlexCrossSectionRequest(:final targetCft) => targetCft,
      TargetCftFlexCategoryRequest(:final targetCft) => targetCft,
      _ => null,
    };

/// A short human-readable label of what a line requested (unit-labelled).
String _requestedLabel(OrderRequest? request) => switch (request) {
      ExactQtyRequest(:final quantityUnits, :final lengthFt) =>
        'Exact $quantityUnits units · $lengthFt ft',
      TargetCftFixedLengthRequest(:final lengthFt) =>
        'Target CFT · $lengthFt ft',
      TargetCftFlexCrossSectionRequest() => 'Target CFT · flexible lengths',
      TargetCftFlexCategoryRequest() => 'Target CFT · category',
      _ => 'Order line',
    };

/// The allocated-quantity label for a picking row, unit-labelled: a plank reads
/// "N pcs"; a reaper reads its whole-bunch count with the piece-equivalent,
/// e.g. "6 bunches (60 pcs)" (Requirements 3.1, 3.4, 17.6).
String _quantityLabel(AllocationLine pick) {
  if (pick.unit == AllocationUnit.bunch) {
    final bunches = pick.allocatedUnits;
    final word = bunches == 1 ? 'bunch' : 'bunches';
    return '$bunches $word (${pick.allocatedPieces} pcs)';
  }
  return '${pick.allocatedPieces} pcs';
}

/// The shortage sentence for a partial line: a unit/piece gap for the exact and
/// fixed-length shapes, or a CFT gap for the flexible shapes. Never claims the
/// line was fulfilled (Requirements 8.3, 8.4).
String _shortageLabel(OrderLineAllocation line) {
  final reaper = line.flexibleReaper;
  if (reaper != null) {
    return 'PARTIAL — short ${reaper.shortageCft.toFixed()} CFT';
  }
  final plank = line.flexiblePlank;
  if (plank != null) {
    return 'PARTIAL — short ${plank.shortageCft.toFixed()} CFT';
  }
  // Exact / fixed-length line: the single produced line carries a unit/piece
  // shortage. Fall back to the whole demand when nothing was allocated.
  if (line.lines.isNotEmpty) {
    final only = line.lines.first;
    final word = only.unit == AllocationUnit.bunch ? 'bunches' : 'pcs';
    final units = only.unit == AllocationUnit.bunch
        ? only.shortageUnits
        : only.shortagePieces;
    return 'PARTIAL — short $units $word (${only.shortagePieces} pcs)';
  }
  return 'PARTIAL — nothing available';
}

/// Formats a signed CFT delta for display, e.g. `+2.5000` / `-1.2500` /
/// `0.0000`, so an over-allocation and an under-allocation read distinctly.
String _signedCft(Rational delta) {
  final magnitude = Cft(delta.abs()).toFixed();
  if (delta > Rational.zero) {
    return '+$magnitude';
  }
  if (delta < Rational.zero) {
    return '-$magnitude';
  }
  return magnitude;
}

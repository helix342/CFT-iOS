/// Read-only dashboard aggregates over the local sales history (app-ux-revamp
/// Requirement 6).
///
/// The Home dashboard summarizes the business at a glance from locally
/// persisted data (Requirement 6.5): available confirmed stock per item, the
/// all-time totals sold (pieces, exact CFT, and payable INR), and the most
/// recent finalized orders. Every number is read from the existing
/// `StockItems`, `Invoices`, and `InvoiceLines` tables â€” no new tables.
///
/// Money is summed as integer paise and volume as an exact
/// numerator/denominator pair, so the aggregates reconcile exactly with the sum
/// over the finalized invoices, order-independent (design Property 35).
library;

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/calculation_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/tables.dart';
import 'package:wood_cft/domain/catalog.dart';
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

/// Available confirmed stock for one SKU shown on the dashboard.
@immutable
class StockOnHand {
  /// Creates a stock-on-hand entry.
  const StockOnHand({
    required this.varietyName,
    required this.crossSectionLabel,
    required this.lengthFt,
    required this.confirmedPieces,
    required this.availableCft,
  });

  /// The variety display name.
  final String varietyName;

  /// The cross-section inch label (e.g. `2 Ã— 1 in`).
  final String crossSectionLabel;

  /// The piece length in feet.
  final int lengthFt;

  /// The confirmed (sellable) piece balance.
  final int confirmedPieces;

  /// The exact available CFT for this SKU (confirmed pieces x per-piece CFT).
  final Cft availableCft;
}

/// One recent finalized order shown on the dashboard / Bills list.
@immutable
class RecentOrder {
  /// Creates a recent-order summary.
  const RecentOrder({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    required this.payable,
    required this.finalizedAt,
  });

  /// The local invoice id.
  final int invoiceId;

  /// The display invoice number.
  final String invoiceNumber;

  /// The buyer name snapshot (may be null).
  final String? customerName;

  /// The payable total.
  final Money payable;

  /// When the sale was finalized (UTC).
  final DateTime finalizedAt;
}

/// The computed dashboard summary (Requirement 6.2-6.4).
@immutable
class DashboardSummary {
  /// Creates a dashboard summary.
  const DashboardSummary({
    required this.stock,
    required this.totalPiecesSold,
    required this.totalCftSold,
    required this.totalAmount,
    required this.recent,
  });

  /// Available confirmed stock per SKU.
  final List<StockOnHand> stock;

  /// All-time total pieces sold across finalized invoices.
  final int totalPiecesSold;

  /// All-time exact total CFT sold.
  final Cft totalCftSold;

  /// All-time total payable INR across finalized invoices.
  final Money totalAmount;

  /// The most recent finalized orders, newest first.
  final List<RecentOrder> recent;

  /// The exact total available CFT on hand (sum of each SKU's available CFT).
  Cft get volumeLeft => const CalculationService()
      .totalCft(stock.map((s) => s.availableCft));
}

/// Read-only dashboard / Bills queries over the local sales history.
class SalesQueryDao {
  /// Creates the DAO over [db].
  const SalesQueryDao(this.db);

  /// The local cache database.
  final AppDatabase db;

  /// Available confirmed stock per SKU, grouped readably (variety, then
  /// cross-section, then length).
  Future<List<StockOnHand>> availableStock() async {
    final query = db.select(db.stockItems).join([
      innerJoin(
        db.woodVarieties,
        db.woodVarieties.id.equalsExp(db.stockItems.varietyId),
      ),
      innerJoin(
        db.crossSections,
        db.crossSections.id.equalsExp(db.stockItems.crossSectionId),
      ),
    ])
      ..where(db.stockItems.confirmedBalancePieces.isBiggerThanValue(0))
      ..orderBy([
        OrderingTerm.asc(db.woodVarieties.name),
        OrderingTerm.asc(db.crossSections.id),
        OrderingTerm.asc(db.stockItems.lengthFt),
      ]);
    final rows = await query.get();
    const calc = CalculationService();
    return rows.map((row) {
      final item = row.readTable(db.stockItems);
      final variety = row.readTable(db.woodVarieties);
      final cs = row.readTable(db.crossSections);
      final domainCs = CrossSection(
        id: cs.id,
        widthIn: cs.widthIn,
        thicknessIn: cs.thicknessIn,
        category: cs.category == CategoryKind.reaper
            ? WoodCategory.reaper
            : WoodCategory.plank,
        bunchSize: cs.bunchSize,
      );
      return StockOnHand(
        varietyName: variety.name,
        crossSectionLabel: '${cs.widthIn} \u00D7 ${cs.thicknessIn} in',
        lengthFt: item.lengthFt,
        confirmedPieces: item.confirmedBalancePieces,
        availableCft: item.confirmedBalancePieces > 0
            ? calc.lineCftFor(
                domainCs, item.lengthFt, item.confirmedBalancePieces)
            : Cft.zero,
      );
    }).toList(growable: false);
  }

  /// The all-time totals sold over FINALIZED invoices: pieces, exact CFT, and
  /// payable INR. Order-independent exact sums (design Property 35).
  Future<({int pieces, Cft cft, Money amount})> totalsSold() async {
    final invoices = await (db.select(db.invoices)
          ..where((i) => i.status.equalsValue(InvoiceStatus.finalized)))
        .get();
    var amount = Money.zero;
    var cft = Cft.zero;
    for (final inv in invoices) {
      amount += Money.fromPaise(inv.payablePaise);
      cft += Cft(
        Rational(
          BigInt.from(inv.totalCftNum),
          BigInt.from(inv.totalCftDen),
        ),
      );
    }
    // Pieces come from the lines of finalized invoices.
    final finalizedIds = invoices.map((i) => i.id).toList();
    var pieces = 0;
    if (finalizedIds.isNotEmpty) {
      final lines = await (db.select(db.invoiceLines)
            ..where((l) => l.invoiceId.isIn(finalizedIds)))
          .get();
      for (final line in lines) {
        pieces += line.pieces;
      }
    }
    return (pieces: pieces, cft: cft, amount: amount);
  }

  /// The most recent finalized orders, newest first, limited to [limit].
  Future<List<RecentOrder>> recentOrders({int limit = 10}) async {
    final rows = await (db.select(db.invoices)
          ..where((i) => i.status.equalsValue(InvoiceStatus.finalized))
          ..orderBy([(i) => OrderingTerm.desc(i.finalizedAt)])
          ..limit(limit))
        .get();
    return rows
        .map(
          (i) => RecentOrder(
            invoiceId: i.id,
            invoiceNumber: i.invoiceNumber,
            customerName: i.customerName,
            payable: Money.fromPaise(i.payablePaise),
            finalizedAt: i.finalizedAt,
          ),
        )
        .toList(growable: false);
  }

  /// All finalized invoices newest-first for the Bills tab (Requirement 7.5).
  Future<List<InvoiceRow>> finalizedInvoices() {
    return (db.select(db.invoices)
          ..where((i) => i.status.equalsValue(InvoiceStatus.finalized))
          ..orderBy([(i) => OrderingTerm.desc(i.finalizedAt)]))
        .get();
  }

  /// The invoice lines for one invoice (read-only Bills detail).
  Future<List<InvoiceLineRow>> invoiceLines(int invoiceId) {
    return (db.select(db.invoiceLines)
          ..where((l) => l.invoiceId.equals(invoiceId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
  }

  /// Composes the full [DashboardSummary] from the above reads.
  Future<DashboardSummary> loadDashboard({int recentLimit = 10}) async {
    final stock = await availableStock();
    final totals = await totalsSold();
    final recent = await recentOrders(limit: recentLimit);
    return DashboardSummary(
      stock: stock,
      totalPiecesSold: totals.pieces,
      totalCftSold: totals.cft,
      totalAmount: totals.amount,
      recent: recent,
    );
  }
}

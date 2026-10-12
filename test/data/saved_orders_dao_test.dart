/// Unit tests for the saveable-order, local-invoice, and dashboard DAOs
/// (app-ux-revamp task 7.1; design Properties 34, 35, 36).
///
/// All tests run against an in-memory [AppDatabase] seeded with a tiny catalog,
/// headless with no network. They assert:
///
///   * SavedOrdersDao: create -> stage lines -> resume round-trips the staged
///     requests with no data loss (Property 36), and status/invoice updates
///     move a draft out of the resumable set;
///   * LocalInvoiceWriter: a FinalizedInvoice maps to exactly one Invoices row
///     + its lines, and re-writing the same key is a no-op (Property 34);
///   * SalesQueryDao: totals reconcile with the exact sum over the finalized
///     invoices, order-independent (Property 35).
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import 'package:wood_cft/application/billing_service.dart';
import 'package:wood_cft/application/finalize_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/data/local_invoice_writer.dart';
import 'package:wood_cft/data/sales_query_dao.dart';
import 'package:wood_cft/data/saved_orders_dao.dart';
import 'package:wood_cft/data/tables.dart' hide TaxMode;
import 'package:wood_cft/domain/cft.dart';
import 'package:wood_cft/domain/money.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openInMemoryDatabase();
    // A minimal catalog so request lines and stock reads have real ids.
    await db.into(db.woodVarieties).insert(
          WoodVarietiesCompanion.insert(
            id: const Value(1),
            name: 'Teak',
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    await db.into(db.crossSections).insert(
          CrossSectionsCompanion.insert(
            id: const Value(1),
            widthIn: 2,
            thicknessIn: 1,
            category: CategoryKind.reaper,
            bunchSize: 10,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('SavedOrdersDao', () {
    test('save then resume round-trips staged request lines (Property 36)',
        () async {
      final dao = SavedOrdersDao(db);
      final id = await dao.createDraft(title: 'Walk-in', customerName: 'Asha');

      const lines = [
        SavedRequestLine(
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 6,
          qty: 3,
        ),
        SavedRequestLine(
          varietyId: 1,
          crossSectionId: 1,
          lengthFt: 8,
          qty: 2,
        ),
      ];
      await dao.replaceRequestLines(id, lines);

      final loaded = await dao.loadOne(id);
      expect(loaded, isNotNull);
      expect(loaded!.draft.title, 'Walk-in');
      expect(loaded.draft.customerName, 'Asha');
      expect(loaded.draft.status, DraftStatus.draft);
      expect(loaded.lines, lines);
    });

    test('replacing lines overwrites the prior set', () async {
      final dao = SavedOrdersDao(db);
      final id = await dao.createDraft();
      await dao.replaceRequestLines(id, const [
        SavedRequestLine(varietyId: 1, crossSectionId: 1, lengthFt: 6, qty: 1),
      ]);
      await dao.replaceRequestLines(id, const [
        SavedRequestLine(varietyId: 1, crossSectionId: 1, lengthFt: 7, qty: 5),
      ]);

      final loaded = await dao.loadOne(id);
      expect(loaded!.lines, hasLength(1));
      expect(loaded.lines.single.lengthFt, 7);
      expect(loaded.lines.single.qty, 5);
    });

    test('resumable list excludes sold/shared and sorts newest first',
        () async {
      final dao = SavedOrdersDao(db);
      final a = await dao.createDraft(
        title: 'A',
        now: DateTime.utc(2024, 1, 1),
      );
      final b = await dao.createDraft(
        title: 'B',
        now: DateTime.utc(2024, 1, 2),
      );
      final soldId = await dao.createDraft(title: 'done');
      await dao.updateStatus(soldId, DraftStatus.sold);

      // Touch A so it becomes the most-recently updated.
      await dao.updateStatus(a, DraftStatus.review, now: DateTime.utc(2024, 2));

      final resumable = await dao.loadResumable();
      final ids = resumable.map((d) => d.id).toList();
      expect(ids, [a, b]);
      expect(ids, isNot(contains(soldId)));
    });

    test('attachInvoice records the produced invoice id', () async {
      final dao = SavedOrdersDao(db);
      final id = await dao.createDraft();
      // The invoiceId column is a FK to Invoices, so seed a real invoice.
      final invoiceId = await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-7',
              status: InvoiceStatus.finalized,
              goodsSubtotalPaise: 0,
              taxPaise: 0,
              loadingPaise: 0,
              payablePaise: 0,
              totalCftNum: 0,
              totalCftDen: 1,
              taxPolicySnapshot: '{}',
              loadingPolicySnapshot: '{}',
              businessProfileSnapshot: '{}',
              finalizedAt: DateTime.utc(2024, 1, 1),
              idempotencyKey: 'attach-1',
            ),
          );
      await dao.updateStatus(id, DraftStatus.sold);
      await dao.attachInvoice(id, invoiceId);

      final loaded = await dao.loadOne(id);
      expect(loaded!.draft.invoiceId, invoiceId);
      expect(loaded.draft.status, DraftStatus.sold);
    });
  });

  group('LocalInvoiceWriter', () {
    FinalizedInvoice sampleInvoice({String key = 'order:1'}) {
      // One line: 20 pcs @ 2.5 CFT exact, rate ₹120/CFT -> ₹300.00.
      final line = InvoiceLineSnapshot(
        stockItemId: 1,
        varietyId: 1,
        varietyName: 'Teak',
        label: '2 × 1 in',
        lengthFt: 6,
        pieces: 20,
        cft: Cft(Rational(BigInt.from(5), BigInt.from(2))),
        rate: Rational.fromInt(120),
        amount: Money.fromRupees(300),
      );
      final totals = InvoiceTotals(
        goodsSubtotal: Money.fromRupees(300),
        tax: Money.zero,
        taxMode: TaxMode.noGst,
        loading: Money.fromRupees(100),
        payable: Money.fromRupees(400),
        totalCft: Cft(Rational(BigInt.from(5), BigInt.from(2))),
      );
      return FinalizedInvoice(
        number: 1,
        ownerId: 'owner-1',
        lines: [line],
        totals: totals,
        idempotencyKey: key,
      );
    }

    test('maps a FinalizedInvoice to one invoice + its lines faithfully',
        () async {
      final writer = LocalInvoiceWriter(db);
      final id = await writer.write(
        sampleInvoice(),
        customerName: 'Asha',
      );

      final invoice = await (db.select(db.invoices)
            ..where((i) => i.id.equals(id)))
          .getSingle();
      expect(invoice.invoiceNumber, 'INV-1');
      expect(invoice.status, InvoiceStatus.finalized);
      expect(invoice.customerName, 'Asha');
      expect(invoice.goodsSubtotalPaise, 30000);
      expect(invoice.loadingPaise, 10000);
      expect(invoice.payablePaise, 40000);
      // Total CFT 5/2 preserved exactly.
      expect(invoice.totalCftNum, 5);
      expect(invoice.totalCftDen, 2);

      final lines = await (db.select(db.invoiceLines)
            ..where((l) => l.invoiceId.equals(id)))
          .get();
      expect(lines, hasLength(1));
      expect(lines.single.pieces, 20);
      expect(lines.single.exactCftNum, 5);
      expect(lines.single.exactCftDen, 2);
      expect(lines.single.lineAmountPaise, 30000);
    });

    test('re-writing the same idempotency key is a no-op (Property 34)',
        () async {
      final writer = LocalInvoiceWriter(db);
      final first = await writer.write(sampleInvoice());
      final second = await writer.write(sampleInvoice());

      expect(second, first);
      final count = await db.select(db.invoices).get();
      expect(count, hasLength(1));
      final lineCount = await db.select(db.invoiceLines).get();
      expect(lineCount, hasLength(1));
    });

    test(
        'two different orders get persistent INV-1 then INV-2 with no UNIQUE '
        'collision (FIX 1)', () async {
      final writer = LocalInvoiceWriter(db);

      // First order: next number is 1 -> stored as INV-1.
      final n1 = await writer.nextInvoiceNumber();
      expect(n1, 1);
      final firstId = await writer.write(
        sampleInvoice(key: 'order:1'),
        invoiceNumberText: 'INV-$n1',
      );

      // Second, DIFFERENT order: next number is 2 -> stored as INV-2. Both the
      // in-memory allocator restarting at 1 AND a raw re-write would otherwise
      // collide on invoiceNumber; the persistent number avoids it.
      final n2 = await writer.nextInvoiceNumber();
      expect(n2, 2);
      final secondId = await writer.write(
        sampleInvoice(key: 'order:2'),
        invoiceNumberText: 'INV-$n2',
      );

      expect(secondId, isNot(firstId));
      final invoices = await db.select(db.invoices).get();
      expect(invoices, hasLength(2));
      final numbers = invoices.map((i) => i.invoiceNumber).toList()..sort();
      expect(numbers, ['INV-1', 'INV-2']);
    });

    test(
        'write computes a unique number in-transaction when none is supplied '
        '(FIX 1 fallback)', () async {
      final writer = LocalInvoiceWriter(db);
      // No invoiceNumberText and both invoice.number == 1: the writer must
      // still store distinct, non-colliding numbers for two different keys.
      await writer.write(sampleInvoice(key: 'order:a'));
      await writer.write(sampleInvoice(key: 'order:b'));

      final invoices = await db.select(db.invoices).get();
      expect(invoices, hasLength(2));
      final numbers = invoices.map((i) => i.invoiceNumber).toSet();
      expect(numbers, {'INV-1', 'INV-2'});
    });

    test('same idempotency key twice allocates no second number (FIX 1)',
        () async {
      final writer = LocalInvoiceWriter(db);
      final n = await writer.nextInvoiceNumber();
      await writer.write(
        sampleInvoice(key: 'order:7'),
        invoiceNumberText: 'INV-$n',
      );
      // A true retry of the SAME order: the idempotency guard returns the
      // existing row, so no new number is consumed and only one row exists.
      await writer.write(
        sampleInvoice(key: 'order:7'),
        invoiceNumberText: 'INV-${await writer.nextInvoiceNumber()}',
      );

      final invoices = await db.select(db.invoices).get();
      expect(invoices, hasLength(1));
      expect(invoices.single.invoiceNumber, 'INV-1');
    });
  });

  group('SalesQueryDao', () {
    Future<int> seedInvoice({
      required String number,
      required String key,
      required int payablePaise,
      required int cftNum,
      required int cftDen,
      required int pieces,
      required DateTime at,
    }) async {
      final id = await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: number,
              status: InvoiceStatus.finalized,
              goodsSubtotalPaise: payablePaise,
              taxPaise: 0,
              loadingPaise: 0,
              payablePaise: payablePaise,
              totalCftNum: cftNum,
              totalCftDen: cftDen,
              taxPolicySnapshot: '{}',
              loadingPolicySnapshot: '{}',
              businessProfileSnapshot: '{}',
              finalizedAt: at,
              idempotencyKey: key,
            ),
          );
      await db.into(db.invoiceLines).insert(
            InvoiceLinesCompanion.insert(
              invoiceId: id,
              varietyName: 'Teak',
              crossSectionLabel: '2 × 1 in',
              lengthFt: 6,
              pieces: pieces,
              exactCftNum: cftNum,
              exactCftDen: cftDen,
              rateNum: 120,
              rateDen: 1,
              lineAmountPaise: payablePaise,
            ),
          );
      return id;
    }

    test('totals reconcile with the exact sum over invoices (Property 35)',
        () async {
      await seedInvoice(
        number: 'INV-1',
        key: 'k1',
        payablePaise: 30000,
        cftNum: 5,
        cftDen: 2,
        pieces: 20,
        at: DateTime.utc(2024, 1, 1),
      );
      await seedInvoice(
        number: 'INV-2',
        key: 'k2',
        payablePaise: 15000,
        cftNum: 3,
        cftDen: 2,
        pieces: 10,
        at: DateTime.utc(2024, 1, 2),
      );

      final dao = SalesQueryDao(db);
      final totals = await dao.totalsSold();
      // 30000 + 15000 = 45000 paise = ₹450.
      expect(totals.amount, Money.fromPaise(45000));
      // 5/2 + 3/2 = 8/2 = 4 CFT.
      expect(totals.cft, Cft(Rational(BigInt.from(4))));
      expect(totals.pieces, 30);
    });

    test('recent orders are newest-first and voided invoices are excluded',
        () async {
      await seedInvoice(
        number: 'INV-1',
        key: 'k1',
        payablePaise: 100,
        cftNum: 1,
        cftDen: 1,
        pieces: 1,
        at: DateTime.utc(2024, 1, 1),
      );
      await seedInvoice(
        number: 'INV-2',
        key: 'k2',
        payablePaise: 200,
        cftNum: 1,
        cftDen: 1,
        pieces: 1,
        at: DateTime.utc(2024, 3, 1),
      );
      // A voided invoice must not count toward sales history.
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-3',
              status: InvoiceStatus.voided,
              goodsSubtotalPaise: 999,
              taxPaise: 0,
              loadingPaise: 0,
              payablePaise: 999,
              totalCftNum: 1,
              totalCftDen: 1,
              taxPolicySnapshot: '{}',
              loadingPolicySnapshot: '{}',
              businessProfileSnapshot: '{}',
              finalizedAt: DateTime.utc(2024, 4, 1),
              idempotencyKey: 'k3',
            ),
          );

      final dao = SalesQueryDao(db);
      final recent = await dao.recentOrders();
      expect(recent.map((r) => r.invoiceNumber), ['INV-2', 'INV-1']);

      final totals = await dao.totalsSold();
      expect(totals.amount, Money.fromPaise(300));
    });

    test('available stock lists confirmed balances only', () async {
      final itemId = await db.into(db.stockItems).insert(
            StockItemsCompanion.insert(
              varietyId: 1,
              crossSectionId: 1,
              lengthFt: 6,
              confirmedBalancePieces: const Value(40),
              pendingBalancePieces: const Value(10),
            ),
          );
      expect(itemId, greaterThan(0));

      final dao = SalesQueryDao(db);
      final stock = await dao.availableStock();
      expect(stock, hasLength(1));
      expect(stock.single.confirmedPieces, 40);
      expect(stock.single.varietyName, 'Teak');
      expect(stock.single.lengthFt, 6);
    });
  });
}

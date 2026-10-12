/// Resume-after-restart recovery for the receiving session (task 5.3).
///
/// When the app is reopened while a truck-receiving session is still open, the
/// receiving screen must restore the interrupted session so no entry is lost
/// and nothing is applied twice (design.md -> Screen Flows, Stock tab:
/// "create a new receipt or resume an active one"; Transaction Boundaries &
/// Sync; Requirements 5.7, 20.6).
///
/// Recovery is a pure READ. [ReceivingSessionController.build] loads the single
/// active `ReceiptSessions` row (if any) together with its already-committed
/// `ReceiptEntries`, and projects them into a [ReceivingSessionState]. The
/// stock effects of those entries were committed at entry time by
/// [ReceivingService.recordReceivingEntry] (one atomic local write per entry),
/// so merely resuming re-reads them and never re-applies them — balances are
/// unchanged by the act of resuming (5.7, 21.6).
///
/// Because the service keeps at most one active session and
/// [ReceivingService.recordReceivingEntry] gates on a stable idempotency key,
/// a fresh controller constructed over the SAME database after a simulated
/// restart recovers exactly the committed entries, exactly once. Finishing the
/// session afterwards only flips its status; it does not double-add stock.
///
/// This controller deliberately exposes recovery/resume state ONLY. Recording
/// new entries stays in the receiving grid (task 5.2) via [ReceivingService],
/// and adjustment / undo is task 5.4 — neither is wired here.
///
/// Architecture rule (design.md): the notifier lives in the presentation layer
/// and composes the application-layer [ReceivingService] (reached through
/// [receivingServiceProvider], which is bound to the shared
/// `appDatabaseProvider`). It never re-declares the database provider, so a
/// single test override of the database reaches recovery too.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'package:wood_cft/application/receiving_service.dart';
import 'package:wood_cft/data/app_database.dart';
import 'package:wood_cft/presentation/stock/receiving_providers.dart';

/// The recoverable state of the receiving session on (re)open.
///
/// [session] is the single active `ReceiptSessions` row, or null when there is
/// no open receipt to resume. [entries] are the entries already committed into
/// that session, in insertion order; it is empty when there is no active
/// session or when the active session has no entries yet.
@immutable
class ReceivingSessionState {
  /// Creates a recovery state.
  const ReceivingSessionState({
    required this.session,
    required this.entries,
  });

  /// The empty state: no active session to resume.
  static const ReceivingSessionState none = ReceivingSessionState(
    session: null,
    entries: <ReceiptEntryRow>[],
  );

  /// The active session being resumed, or null when none is open.
  final ReceiptSessionRow? session;

  /// The entries already committed into [session], in insertion order.
  final List<ReceiptEntryRow> entries;

  /// Whether there is an active receiving session to resume after restart.
  bool get hasActiveSession => session != null;

  @override
  String toString() => 'ReceivingSessionState(session: ${session?.id}, '
      'entries: ${entries.length})';
}

/// Loads (and resumes) the active receiving session for the Stock tab.
///
/// [build] performs recovery on first read: it loads the active session and its
/// committed entries so an interrupted receipt is restored after an app
/// restart (5.7, 20.6). A fresh controller over the same database recovers the
/// same session and entries, exactly once — resuming applies no stock effects.
class ReceivingSessionController extends AsyncNotifier<ReceivingSessionState> {
  @override
  Future<ReceivingSessionState> build() => _load();

  Future<ReceivingSessionState> _load() async {
    final service = ref.watch(receivingServiceProvider);

    final session = await service.activeSession();
    if (session == null) return ReceivingSessionState.none;

    final entries = await service.entriesForSession(session.id);
    return ReceivingSessionState(session: session, entries: entries);
  }

  /// Re-reads the active session and its entries from the store.
  ///
  /// Use after the receiving grid records a new entry so the resumed view shows
  /// the committed entries. This is a read-only refresh; it never re-applies
  /// stock effects (5.7, 21.6).
  Future<void> refresh() async {
    state = const AsyncLoading<ReceivingSessionState>();
    state = await AsyncValue.guard(_load);
  }
}

/// The receiving-session recovery notifier used by the Stock-tab screen.
///
/// Reading this provider on screen build recovers an interrupted receiving
/// session (5.7, 20.6). It composes [receivingServiceProvider], so it is bound
/// to the shared `appDatabaseProvider` and participates in a single database
/// override under test.
final receivingSessionControllerProvider =
    AsyncNotifierProvider<ReceivingSessionController, ReceivingSessionState>(
  ReceivingSessionController.new,
);

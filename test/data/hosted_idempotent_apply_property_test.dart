// Property-based test for idempotent operation application (task 4.4 /
// Property 19).
//
// Property 19 - Operation application is idempotent under a repeated
// idempotency key (design.md -> Correctness Properties; Requirements 5.9,
// 12.3, 13.3, 19.9, 19.10, 21.7, 21.26):
//
//   For all operations of type receive, finalize, void, or sync, applying the
//   operation any number of times with the same idempotency key produces
//   exactly the same resulting authoritative state as applying it once (exactly
//   one effect), including when a lost or duplicated response triggers a retry
//   with the same key.
//
// This drives the authoritative store seam, `FakeHostedDatabase.apply`, across
// many random key sets and random *repeat/interleave* schedules. For each
// generated scenario we build two schedules over the SAME set of distinct
// operations:
//
//   * the baseline: each distinct key applied exactly ONCE, and
//   * the stressed schedule: each key applied one-or-more times, with the
//     repeats arbitrarily interleaved across keys (simulating at-least-once
//     delivery: duplicates, retries after lost responses, re-drains).
//
// The property asserts the stressed schedule leaves the exact same
// authoritative state as the baseline:
//   * the set of applied keys is identical (hasApplied for every key);
//   * the number of distinct applied effects is identical (appliedCount ==
//     number of distinct keys) — no key produced a second effect;
//   * exactly one `apply` call per key reports `applied == true`; every other
//     call for that key is a duplicate no-op reporting `applied == false`;
//   * the confirmed state read back for each key equals the first-application
//     payload — later duplicate applies never overwrite it;
//   * `runTransaction` staging the same keys is idempotent too (committing the
//     same keys again adds no new effects).
//
// This is exactly-once effect under at-least-once delivery.
//
// PBT framework: `package:glados` (re-exports `package:test`), matching the
// existing data/application property tests. `ExploreConfig(numRuns: ...)` fixes
// the iteration count (>= 100) and seeds a deterministic `Random`, so a failure
// reproduces exactly.
//
// Pure / headless: imports only the application + data layers and
// `package:glados`. No Flutter widgets, no real DB, no network — runs under
// `flutter test` on Windows. Uses `FakeHostedDatabase` and `FakeAuthService`.

import 'package:glados/glados.dart';

import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/data/hosted_database.dart';

/// Deterministic exploration config giving the property >= 100 iterations from
/// a fixed seed (150-200 range per task 4.4).
final ExploreConfig _explore =
    ExploreConfig(numRuns: 175, random: Random(20240404));

/// The op kinds a pending operation can carry (receive, finalize, void, sync).
/// Mirrors the operation types named by Property 19.
const List<String> _opKinds = <String>[
  'receiveEntry',
  'finalize',
  'voidInvoice',
  'sync',
];

/// One randomly generated idempotency scenario: a set of distinct operations
/// (each a unique key) plus, for each, how many times it is applied (>= 1), and
/// a shuffle seed used to interleave all those applications.
class _Scenario {
  const _Scenario({
    required this.opCount,
    required this.repeatSeeds,
    required this.kindSeeds,
    required this.payloadSeeds,
    required this.interleaveSeed,
  });

  /// Number of DISTINCT operations (distinct idempotency keys), >= 1.
  final int opCount;

  /// Per-op raw seed used to derive a repeat count in 1..5 (at-least-once).
  final List<int> repeatSeeds;

  /// Per-op raw seed used to pick the op kind.
  final List<int> kindSeeds;

  /// Per-op raw seed used to derive a distinct payload value.
  final List<int> payloadSeeds;

  /// Seed used to shuffle the flattened application schedule (the interleaving).
  final int interleaveSeed;

  @override
  String toString() =>
      '_Scenario(opCount: $opCount, repeatSeeds: $repeatSeeds, '
      'kindSeeds: $kindSeeds, interleaveSeed: $interleaveSeed)';
}

final Generator<int> _opCount = any.intInRange(1, 9); // 1..8 distinct ops
final Generator<int> _seed = any.intInRange(0, 1 << 20);

/// Builds a scenario: a count of distinct ops plus fixed-width per-op seed
/// lists and an interleave seed. We generate fixed-width seed lists and slice
/// to the op count inside the test so the generator stays simple and shrinks
/// well.
final Generator<_Scenario> _scenario = any
    .combine5(
      _opCount,
      any.listWithLength(8, _seed),
      any.listWithLength(8, _seed),
      any.listWithLength(8, _seed),
      _seed,
      (
        int opCount,
        List<int> repeats,
        List<int> kinds,
        List<int> payloads,
        int interleave,
      ) =>
          _Scenario(
        opCount: opCount,
        repeatSeeds: repeats,
        kindSeeds: kinds,
        payloadSeeds: payloads,
        interleaveSeed: interleave,
      ),
    );

/// A single planned application in the stressed schedule.
class _PlannedApply {
  const _PlannedApply(this.operation);
  final HostedOperation operation;
}

void main() {
  Glados<_Scenario>(_scenario, _explore).test(
    'Feature: wood-cft-app, Property 19: Operation application is idempotent '
    'under a repeated idempotency key - applying the same operation any number '
    'of times, in any interleaving with retries, yields exactly the same '
    'authoritative state as applying it once (exactly-once effect under '
    'at-least-once delivery) (Requirements 5.9, 12.3, 13.3, 19.9, 19.10, 21.7, '
    '21.26)',
    (_Scenario s) async {
      final n = s.opCount;

      // Derive the n distinct operations. Each has a unique idempotency key, a
      // kind drawn from the four op types, and a distinct payload so we can
      // prove the FIRST application's state is the one that persists.
      final operations = <HostedOperation>[
        for (var i = 0; i < n; i++)
          HostedOperation(
            kind: _opKinds[s.kindSeeds[i] % _opKinds.length],
            idempotencyKey: 'op-$i',
            payload: <String, Object?>{
              'index': i,
              'value': s.payloadSeeds[i],
            },
          ),
      ];

      // Per-op repeat count in 1..5: each op is delivered at least once, and
      // may be duplicated/retried up to five times (at-least-once delivery).
      final repeats = <int>[
        for (var i = 0; i < n; i++) 1 + (s.repeatSeeds[i] % 5),
      ];

      // ---- Baseline: apply each distinct key EXACTLY ONCE. ----
      final baselineAuth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final baseline = FakeHostedDatabase(authService: baselineAuth);
      final baselineState = <String, Map<String, Object?>>{};
      for (final op in operations) {
        final result = await baseline.apply(op);
        expect(result.applied, isTrue); // first time for every key
        baselineState[op.idempotencyKey] =
            await baseline.readConfirmed(op.idempotencyKey);
      }
      expect(baseline.appliedCount, n);

      // ---- Stressed schedule: each key applied `repeats[i]` times, with ALL
      // applications flattened and interleaved by a deterministic shuffle. ----
      final schedule = <_PlannedApply>[
        for (var i = 0; i < n; i++)
          for (var r = 0; r < repeats[i]; r++)
            _PlannedApply(operations[i]),
      ];
      schedule.shuffle(Random(s.interleaveSeed));

      final stressedAuth =
          FakeAuthService(initialSession: const AuthSession(userId: 'owner'));
      final stressed = FakeHostedDatabase(authService: stressedAuth);

      // Track, per key, how many applies reported applied == true.
      final firstApplyCount = <String, int>{
        for (final op in operations) op.idempotencyKey: 0,
      };

      for (final planned in schedule) {
        final result = await stressed.apply(planned.operation);
        if (result.applied) {
          firstApplyCount[planned.operation.idempotencyKey] =
              firstApplyCount[planned.operation.idempotencyKey]! + 1;
        }
        // Every apply (first or duplicate) reports the SAME confirmed state for
        // that key, and it never changes once set.
        expect(
          result.confirmedState,
          baselineState[planned.operation.idempotencyKey],
        );
      }

      // Exactly one effect per key despite the duplicates/interleaving.
      for (final op in operations) {
        expect(
          firstApplyCount[op.idempotencyKey],
          1,
          reason: 'key ${op.idempotencyKey} must apply its effect exactly once',
        );
        expect(stressed.hasApplied(op.idempotencyKey), isTrue);
        // The persisted state equals the first-application payload (duplicates
        // never overwrite it).
        expect(
          await stressed.readConfirmed(op.idempotencyKey),
          baselineState[op.idempotencyKey],
        );
      }

      // Same number of distinct authoritative effects as the once-each
      // baseline: no duplicate produced an extra effect.
      expect(stressed.appliedCount, baseline.appliedCount);
      expect(stressed.appliedCount, n);

      // ---- Transactions are idempotent too: re-staging the SAME keys (even
      // several times within one committed transaction) adds no new effect. ----
      await stressed.runTransaction((txn) async {
        for (final op in operations) {
          txn.stage(op);
          txn.stage(op); // duplicate stage within the txn collapses to one
        }
      });
      expect(stressed.appliedCount, n);
      for (final op in operations) {
        expect(
          await stressed.readConfirmed(op.idempotencyKey),
          baselineState[op.idempotencyKey],
        );
      }

      await baselineAuth.dispose();
      await stressedAuth.dispose();
    },
  );
}

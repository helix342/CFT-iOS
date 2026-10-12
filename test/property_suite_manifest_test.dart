// Property-suite manifest / coverage-audit test (task 17.1).
//
// This is the META test that ASSEMBLES and AUDITS the full property-based
// suite. It scans the whole `test/` tree, extracts every property-test tag of
// the design's canonical form —
//
//     Feature: wood-cft-app, Property {N}: {text}
//
// — and asserts that EVERY design Correctness Property (1..31 from design.md ->
// Correctness Properties) is covered by at least one tagged property test. If
// any design property has no tagged test, this test fails and lists exactly
// which property numbers are missing — it never fabricates coverage.
//
// It also surfaces, for information, which properties are over-covered (more
// than one tagged test). The design says each property is implemented by a
// SINGLE property test; a handful of properties legitimately have an extra
// focused variant in this codebase (e.g. Property 5, 10, 12, 14, 15, 16, 17),
// so over-coverage is reported but NOT treated as a failure here.
//
// Determinism + Windows headless: the scan uses only `dart:io` directory
// listing and a regex over file contents. It resolves the `test/` directory
// relative to this script's own location (via `Platform.script`) with a
// fallback to the current working directory, so it runs identically whether
// invoked as `flutter test test/property_suite_manifest_test.dart` from the
// project root or from the test directory.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The full set of design Correctness Properties that MUST each have at least
/// one tagged property-based test (design.md -> Correctness Properties 1..31).
const int _firstProperty = 1;
const int _lastProperty = 31;

/// Short titles for each property, mirroring design.md. Used only to make the
/// failure message and the generated manifest human-readable; coverage is
/// decided purely by the presence of a matching tag.
const Map<int, String> _propertyTitles = <int, String>{
  1: 'Exact CFT formula',
  2: 'Unit scaling (bunch and line) is exact multiplication',
  3: 'Total CFT is the exact order-independent sum of line CFT',
  4: 'Display rounding never alters computation',
  5: 'Whole-unit invariant for sale quantities',
  6: 'Meet-or-exceed single-SKU unit count',
  7: 'Hard constraints are never violated',
  8: 'Allocation honesty (no silent reduction; partial labeled with shortage)',
  9: 'Billing uses actual allocated CFT',
  10: 'Multi-line allocation never double-counts stock',
  11: 'Allocation is deterministic with a stable tie-breaker',
  12: 'Flexible reaper excludes 8-9 ft and never applies reaper weights to '
      'planks',
  13: 'Flexible plank uses whole pieces with minimal meet-or-exceed excess',
  14: 'Line amount is exact before half-up rounding, and goods subtotal sums '
      'rounded lines',
  15: 'Single-line literal tax on the taxable subtotal',
  16: 'Loading is excluded from tax, added once after tax',
  17: 'Loading tier is a step function on exact CFT at 20',
  18: 'Non-finalizing actions never mutate stock',
  19: 'Operation application is idempotent under a repeated idempotency key',
  20: 'Negative-availability adjustments are rejected without side effects',
  21: 'Only confirmed stock is sellable',
  22: 'Balance reconciles with the movement ledger',
  23: 'Inventory totals equal the sum over the active filter',
  24: 'Finalized invoice snapshots are immutable to later changes',
  25: 'Void restores exactly the deducted stock and retains the original',
  26: 'Missing rate blocks finalization',
  27: 'Export outputs are consistent with the snapshot',
  28: 'Exported DOCX is a valid OOXML package',
  29: 'Backup/restore round-trip preserves data without duplication',
  30: 'Offline durability across restart',
  31: 'Incomplete statutory fields prevent a verified tax-invoice presentation',
};

/// Matches a property tag of the canonical form inside a test name string:
///   Feature: wood-cft-app, Property {N}
/// The `{text}` suffix is intentionally not captured — only the number matters
/// for coverage, and tags wrap across adjacent string literals in source.
final RegExp _tagPattern =
    RegExp(r'Feature:\s*wood-cft-app,\s*Property\s+(\d+)');

/// This manifest file's own name — excluded from the scan so its documentation
/// strings do not count as coverage.
const String _selfFileName = 'property_suite_manifest_test.dart';

/// Resolves the `test/` directory that contains the suite, independent of the
/// invocation's working directory.
Directory _resolveTestDir() {
  // 1) Relative to this script's own location (…/test/<thisfile>).
  final scriptPath = Platform.script.toFilePath();
  if (scriptPath.isNotEmpty) {
    final scriptFile = File(scriptPath);
    final parent = scriptFile.parent; // the directory holding the script
    if (parent.existsSync()) {
      // If the script lives in `test/`, use it directly; otherwise look for a
      // `test/` child (e.g. when the runner points at the project root).
      if (_basename(parent.path) == 'test') return parent;
      final nested = Directory('${parent.path}${Platform.pathSeparator}test');
      if (nested.existsSync()) return nested;
    }
  }
  // 2) Fallbacks: `test/` under cwd, or cwd itself if it already is `test/`.
  final cwdTest = Directory('test');
  if (cwdTest.existsSync()) return cwdTest;
  final cwd = Directory.current;
  if (_basename(cwd.path) == 'test') return cwd;
  throw StateError(
    'Could not locate the test/ directory to scan (script: $scriptPath, '
    'cwd: ${cwd.path}).',
  );
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final trimmed = normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  final idx = trimmed.lastIndexOf('/');
  return idx == -1 ? trimmed : trimmed.substring(idx + 1);
}

/// Scans [testDir] for `*_test.dart` files (excluding this manifest file) and
/// returns, for each property number, the sorted set of files that tag it.
Map<int, Set<String>> _scanCoverage(Directory testDir) {
  final coverage = <int, Set<String>>{};
  final files = testDir
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .where((f) => _basename(f.path) != _selfFileName)
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final content = file.readAsStringSync();
    final name = _basename(file.path);
    for (final match in _tagPattern.allMatches(content)) {
      final n = int.parse(match.group(1)!);
      coverage.putIfAbsent(n, () => <String>{}).add(name);
    }
  }
  return coverage;
}

void main() {
  group('property-based suite manifest (task 17.1)', () {
    late Directory testDir;
    late Map<int, Set<String>> coverage;

    setUpAll(() {
      testDir = _resolveTestDir();
      coverage = _scanCoverage(testDir);
    });

    test(
      'every design Correctness Property (1..31) has at least one tagged '
      'property test',
      () {
        final missing = <int>[];
        for (var n = _firstProperty; n <= _lastProperty; n++) {
          final files = coverage[n];
          if (files == null || files.isEmpty) missing.add(n);
        }

        if (missing.isNotEmpty) {
          final lines = missing
              .map((n) =>
                  '  - Property $n: ${_propertyTitles[n] ?? '(no title)'}')
              .join('\n');
          fail(
            'Missing property-based coverage for ${missing.length} design '
            'property(ies). Each must have a test tagged '
            '`Feature: wood-cft-app, Property {N}: ...`:\n$lines',
          );
        }

        // Sanity: no stray tag references a property outside the design range.
        final stray = coverage.keys
            .where((n) => n < _firstProperty || n > _lastProperty)
            .toList()
          ..sort();
        expect(
          stray,
          isEmpty,
          reason: 'Found property tag(s) outside the design range 1..31: '
              '$stray',
        );
      },
    );

    test('the suite tags only canonically-formatted property numbers', () {
      // Every covered number falls in the design range and maps to a known
      // title — a cheap guard that the tag format and numbering stay aligned
      // with design.md.
      for (final n in coverage.keys) {
        expect(
          n >= _firstProperty && n <= _lastProperty,
          isTrue,
          reason: 'Property tag $n is outside the design range 1..31.',
        );
        expect(
          _propertyTitles.containsKey(n),
          isTrue,
          reason: 'Property tag $n has no known design title.',
        );
      }
    });

    test(
      'manifest audit prints the Property -> test-file mapping (informational)',
      () {
        final buffer = StringBuffer()
          ..writeln('Wood CFT property-based suite coverage '
              '(${testDir.path}):');
        for (var n = _firstProperty; n <= _lastProperty; n++) {
          final files = (coverage[n]?.toList() ?? const <String>[])..sort();
          final status = files.isEmpty
              ? 'MISSING'
              : files.length == 1
                  ? files.single
                  : '${files.join(', ')} (${files.length} tests)';
          buffer.writeln('  Property $n: $status');
        }
        // Printed so a reviewer can read the mapping from the test output; the
        // hard assertion lives in the coverage test above.
        // ignore: avoid_print
        print(buffer.toString());
        expect(coverage, isNotEmpty);
      },
    );
  });
}

/// Credential hygiene static check (task 17.4).
///
/// Scans the repository source tree for embedded secrets and asserts NONE are
/// present: no Supabase/Neon service-role keys, no hardcoded API keys / tokens
/// / passwords, no privileged database credentials or connection strings, and
/// the CI workflow references no secrets.
///
/// Validates: Requirements 19.6 (no privileged/service-role keys embedded in
/// the app) and 20.7 (Apple/CI credentials never placed in source, GitHub, or
/// CI secrets).
///
/// This is a pure `dart:io` filesystem scan — it runs headless on Windows and
/// touches no device or network. It scans only shipped/source surfaces
/// (`lib/`, `.github/`, `pubspec.yaml`); it deliberately SKIPS `test/` so that
/// the regex patterns written in this very file are never scanned as if they
/// were leaked secrets.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A named secret pattern plus a human-readable reason for failure.
class _SecretPattern {
  const _SecretPattern(this.name, this.regex);
  final String name;
  final RegExp regex;
}

/// Conservative patterns that should NEVER match in shipped source.
///
/// Each is intentionally narrow to avoid false positives on ordinary code
/// (variable names, comments describing the policy, etc.) while still catching
/// a real leaked credential.
final List<_SecretPattern> _secretPatterns = <_SecretPattern>[
  // Supabase/Postgres service-role key keyword.
  _SecretPattern(
    'service_role key',
    RegExp(r'service_role', caseSensitive: false),
  ),
  // A Supabase env key assigned a concrete value, e.g.
  // SUPABASE_SERVICE_KEY = "....". The quoted value (with length) is what makes
  // this a leak rather than a mere reference to the variable name.
  _SecretPattern(
    'assigned SUPABASE_*_KEY value',
    RegExp(
      '''SUPABASE_[A-Z_]*KEY\\s*[:=]\\s*['"][^'"]{8,}['"]''',
    ),
  ),
  // JWT-looking blob (anon/service keys and bearer tokens are JWTs). A real JWT
  // header segment starts with the base64 of {"alg": -> "eyJ" followed by a
  // long base64url run. 20+ chars avoids matching the 3-letter prefix alone.
  _SecretPattern(
    'JWT-looking token (eyJ...)',
    RegExp(r'eyJ[A-Za-z0-9_-]{20,}'),
  ),
  // Hardcoded password / secret / token / api key assigned a quoted value.
  _SecretPattern(
    'hardcoded password/secret/token/apiKey assignment',
    RegExp(
      '''(?:password|passwd|secret|api[_-]?key|access[_-]?token|'''
      '''auth[_-]?token|private[_-]?key)\\s*[:=]\\s*['"][^'"]{6,}['"]''',
      caseSensitive: false,
    ),
  ),
  // Postgres/Postgresql connection string carrying inline credentials.
  _SecretPattern(
    'postgres connection string',
    RegExp(r'postgres(?:ql)?://[^\s'
        "'"
        r'"]+'),
  ),
  // AWS access key id.
  _SecretPattern(
    'AWS access key id',
    RegExp(r'AKIA[0-9A-Z]{16}'),
  ),
  // Generic bearer secret assignment with a long value.
  _SecretPattern(
    'bearer secret assignment',
    RegExp(
      '''bearer\\s+[A-Za-z0-9_\\-\\.=]{20,}''',
      caseSensitive: false,
    ),
  ),
];

/// Source surfaces that ship or configure the app. These are what Req 19.6 /
/// 20.7 govern. `test/` is excluded on purpose (see library doc).
const List<String> _scannedRoots = <String>['lib', '.github'];

/// Extra individual files to scan at the repo root.
const List<String> _scannedFiles = <String>['pubspec.yaml'];

/// File extensions worth scanning as text.
bool _isScannableFile(String path) {
  final lower = path.toLowerCase();
  const exts = <String>[
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.plist',
    '.xcconfig',
    '.sh',
    '.env',
    '.properties',
    '.gradle',
    '.xml',
  ];
  return exts.any(lower.endsWith);
}

/// Resolves the repository root from the test's current working directory.
///
/// `flutter test` runs with the package root as the CWD, so `pubspec.yaml` is
/// expected to live there.
Directory _repoRoot() => Directory.current;

/// Collects every scannable file under the configured roots + explicit files.
List<File> _collectSourceFiles(Directory root) {
  final files = <File>[];
  final sep = Platform.pathSeparator;

  for (final rel in _scannedRoots) {
    final dir = Directory('${root.path}$sep$rel');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && _isScannableFile(entity.path)) {
        files.add(entity);
      }
    }
  }

  for (final rel in _scannedFiles) {
    final f = File('${root.path}$sep$rel');
    if (f.existsSync()) files.add(f);
  }

  return files;
}

void main() {
  late Directory root;
  late List<File> sourceFiles;

  setUpAll(() {
    root = _repoRoot();
    sourceFiles = _collectSourceFiles(root);
  });

  test('runs from the package root containing pubspec.yaml', () {
    final pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
    expect(
      pubspec.existsSync(),
      isTrue,
      reason: 'expected to run from the package root containing pubspec.yaml',
    );
  });

  test('the scan actually finds source files (guards against empty scan)', () {
    expect(
      sourceFiles,
      isNotEmpty,
      reason: 'credential scan must inspect real source files',
    );
  });

  test('no embedded secrets appear in shipped source or CI config '
      '(Req 19.6, 20.7)', () {
    final findings = <String>[];

    for (final file in sourceFiles) {
      final String contents;
      try {
        contents = file.readAsStringSync();
      } on FileSystemException {
        // Binary or unreadable file — skip; text patterns cannot apply.
        continue;
      }

      final lines = contents.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final pattern in _secretPatterns) {
          if (pattern.regex.hasMatch(line)) {
            findings.add(
              '${file.path}:${i + 1} -> ${pattern.name}: '
              '"${line.trim()}"',
            );
          }
        }
      }
    }

    expect(
      findings,
      isEmpty,
      reason: 'embedded secrets detected in source/CI:\n'
          '${findings.join('\n')}',
    );
  });

  test('CI workflow references no GitHub Actions secrets (Req 20.7)', () {
    final sep = Platform.pathSeparator;
    final workflowsDir = Directory('${root.path}$sep.github$sep''workflows');
    if (!workflowsDir.existsSync()) {
      // No workflows at all trivially satisfies "no secrets referenced".
      return;
    }

    // Matches ${{ secrets.FOO }} references in a GitHub Actions workflow.
    final secretsRef = RegExp(r'\$\{\{\s*secrets\.');
    final findings = <String>[];

    for (final entity
        in workflowsDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!(lower.endsWith('.yml') || lower.endsWith('.yaml'))) continue;

      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (secretsRef.hasMatch(lines[i])) {
          findings.add('${entity.path}:${i + 1} -> "${lines[i].trim()}"');
        }
      }
    }

    expect(
      findings,
      isEmpty,
      reason: 'CI workflow must reference no secrets:\n${findings.join('\n')}',
    );
  });
}

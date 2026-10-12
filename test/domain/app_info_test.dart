// Pure-Dart domain-layer test.
//
// Proves the domain layer compiles and runs under `flutter test` on Windows
// with no Flutter / no dart:io dependency (Requirement 20.1). This test
// imports ONLY the domain layer and the pure-Dart `test` matchers exposed via
// flutter_test — it does not pump any widget.

import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/domain/app_info.dart';

void main() {
  group('domain layer (pure Dart)', () {
    test('exposes the app name', () {
      expect(kAppName, 'CFT Calculator');
    });

    test('describeDomain reports readiness', () {
      expect(describeDomain(), 'CFT Calculator domain layer ready');
    });

    test('exposes the brand asset path', () {
      expect(kBrandAsset, 'assets/app_icon.png');
    });
  });
}

/// Pure-Dart domain layer placeholder.
///
/// This file exists to prove the domain layer compiles and is testable under
/// `flutter test` / `dart test` on Windows (Requirement 20.1) with no Flutter
/// and no `dart:io` imports. The real value objects (`Cft`, `Money`) arrive in
/// tasks 1.3 and 1.4 — do not add them here.
///
/// Architecture rule (design.md): the domain layer has a strict inward
/// dependency direction and MUST NOT import `package:flutter/*` or `dart:io`.
library;

/// The user-visible application display name (Requirement 1.1-1.3).
///
/// Shown wherever the app title appears (dashboard header, task switcher) and
/// used as the launcher label. The internal package name stays `wood_cft`;
/// only this user-facing name and the launcher icon change (Requirement 1.5).
const String kAppName = 'CFT Calculator';

/// The in-app brand-mark asset (Requirement 1.4). The same image backs the
/// generated launcher icon; the dashboard header renders it from this path.
const String kBrandAsset = 'assets/app_icon.png';

/// Returns a human-readable domain-layer greeting.
///
/// Pure function (no I/O, no side effects) so it is fully testable off-device.
String describeDomain() => '$kAppName domain layer ready';

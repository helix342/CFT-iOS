// Unit tests for SupabaseAuthService (supabase-integration spec, Task 3 / 6).
//
// Exercises the non-interactive owner session against an in-memory
// SupabaseAuthPort stub — no network, no Supabase SDK client. Confirms:
//   * initialize() signs in anonymously when there is no session, so status
//     becomes signedIn without user action (Requirement 2.3);
//   * an already-persisted session is adopted without a second sign-in;
//   * onAuthStateChange is bridged onto sessionChanges (Requirement 2.2);
//   * requireSession throws NotAuthenticatedException before a session exists
//     (Requirement 2.5);
//   * signOut clears the session.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:wood_cft/application/auth_service.dart';
import 'package:wood_cft/application/supabase_auth_service.dart';

/// In-memory [SupabaseAuthPort] with no network. Lets a test seed a persisted
/// session, count anonymous sign-ins, and push auth-state transitions.
class _StubAuthPort implements SupabaseAuthPort {
  _StubAuthPort({String? initialUserId, this.nextAnonUserId = 'anon-1'})
      : _currentUserId = initialUserId;

  final String nextAnonUserId;
  String? _currentUserId;
  int signInCount = 0;

  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  @override
  String? get currentUserId => _currentUserId;

  @override
  Stream<String?> get userIdChanges => _controller.stream;

  @override
  Future<String> signInAnonymously() async {
    signInCount++;
    _currentUserId = nextAnonUserId;
    _controller.add(_currentUserId);
    return nextAnonUserId;
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _controller.add(null);
  }

  /// Pushes an auth-state transition as the SDK would (e.g. token refresh with
  /// a different session, or external sign-out).
  void emit(String? userId) {
    _currentUserId = userId;
    _controller.add(userId);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  test('initialize() signs in anonymously and becomes signedIn', () async {
    final port = _StubAuthPort(nextAnonUserId: 'anon-xyz');
    final service = SupabaseAuthService(port: port);
    addTearDown(service.dispose);
    addTearDown(port.dispose);

    expect(service.status, AuthStatus.signedOut);

    await service.initialize();

    expect(port.signInCount, 1);
    expect(service.status, AuthStatus.signedIn);
    expect(service.isAuthenticated, isTrue);
    expect(service.session?.userId, 'anon-xyz');
  });

  test('adopts a persisted session without a second sign-in', () async {
    final port = _StubAuthPort(initialUserId: 'anon-existing');
    final service = SupabaseAuthService(port: port);
    addTearDown(service.dispose);
    addTearDown(port.dispose);

    await service.initialize();

    expect(port.signInCount, 0);
    expect(service.session?.userId, 'anon-existing');
  });

  test('initialize() is idempotent (no repeated sign-in)', () async {
    final port = _StubAuthPort();
    final service = SupabaseAuthService(port: port);
    addTearDown(service.dispose);
    addTearDown(port.dispose);

    await service.initialize();
    await service.initialize();

    expect(port.signInCount, 1);
  });

  test('requireSession throws before a session exists', () {
    final port = _StubAuthPort();
    final service = SupabaseAuthService(port: port);
    addTearDown(service.dispose);
    addTearDown(port.dispose);

    expect(
      () => service.requireSession('finalize'),
      throwsA(isA<NotAuthenticatedException>()),
    );
  });

  test('bridges onAuthStateChange onto sessionChanges', () async {
    final port = _StubAuthPort(initialUserId: 'anon-1');
    final service = SupabaseAuthService(port: port);
    addTearDown(service.dispose);
    addTearDown(port.dispose);

    await service.initialize();

    final seen = <String?>[];
    final sub = service.sessionChanges.listen((s) => seen.add(s?.userId));
    addTearDown(sub.cancel);

    port.emit('anon-2');
    await _pump();
    expect(service.session?.userId, 'anon-2');

    port.emit(null);
    await _pump();
    expect(service.session, isNull);
    expect(service.status, AuthStatus.signedOut);

    expect(seen, contains('anon-2'));
    expect(seen, contains(null));
  });

  test('signOut clears the session', () async {
    final port = _StubAuthPort(initialUserId: 'anon-1');
    final service = SupabaseAuthService(port: port);
    addTearDown(service.dispose);
    addTearDown(port.dispose);

    await service.initialize();
    expect(service.isAuthenticated, isTrue);

    await service.signOut();
    expect(service.isAuthenticated, isFalse);
    expect(service.session, isNull);
  });
}

Future<void> _pump() => Future<void>.delayed(const Duration(milliseconds: 10));

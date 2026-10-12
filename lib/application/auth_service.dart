/// Authenticated owner session for privileged hosted-database access (task 4.1).
///
/// Privileged Hosted_Database access (finalize, sync drain, void) requires an
/// authenticated owner session (Requirement 19.3; design.md -> Architecture:
/// Hosted-DB access and credentials). This file defines **the abstraction**:
/// an [AuthService] interface plus an in-memory [FakeAuthService] used by tests
/// and by the app until a real Supabase-backed implementation is wired (task
/// 4.2). The gate ([AuthService.requireSession]) is what finalize/sync call to
/// refuse a privileged action when no one is signed in.
///
/// ## Credentials never live in source
///
/// Neither this interface nor the fake embeds any real credential. The app
/// ships only a client-safe anon key (Supabase) and gates privileged access by
/// Row Level Security keyed to the authenticated session; a Neon alternative is
/// reached only through an authenticated API. **No privileged or service-role
/// database key, and no Apple credential, is ever embedded in the app, source,
/// GitHub, or CI secrets** (Requirement 19.6, 20.7; design.md -> Hosted-DB
/// access and credentials). The future real implementation receives its
/// client-safe configuration from the environment at runtime, not from a
/// constant checked into this repository.
///
/// Architecture rule (design.md): this service is pure Dart. It MUST NOT import
/// `package:flutter/*` or `dart:io`, so it runs headless under `flutter test`
/// on Windows. Riverpod wiring lives in `auth_providers.dart`.
library;

import 'dart:async';

import 'package:meta/meta.dart';

/// Lifecycle status of the owner session.
enum AuthStatus {
  /// No authenticated session; privileged hosted access is refused.
  signedOut,

  /// An authenticated owner session is active; privileged access is permitted.
  signedIn,
}

/// An authenticated owner session.
///
/// Carries only the non-secret identity needed to key privileged access
/// (Supabase Row Level Security is keyed to this session server-side). It holds
/// **no password, no token secret, and no database credential** — those never
/// enter the pure-Dart layer.
@immutable
class AuthSession {
  /// Creates a session for the owner identified by [userId].
  const AuthSession({required this.userId});

  /// Stable identifier for the authenticated owner (e.g. the Supabase user id).
  final String userId;

  @override
  bool operator ==(Object other) =>
      other is AuthSession && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'AuthSession(userId: $userId)';
}

/// Thrown when a privileged hosted action is attempted without a session.
///
/// `SyncService` and the finalize/void flows call [AuthService.requireSession];
/// when there is no authenticated session they surface this so the order stays
/// a draft and the owner is told why (Requirement 12.3b, 19.3).
class NotAuthenticatedException implements Exception {
  /// Creates the exception, optionally describing the refused [action].
  const NotAuthenticatedException([this.action]);

  /// Human-readable name of the privileged action that was refused, if known.
  final String? action;

  @override
  String toString() {
    final suffix = action == null ? '' : ' for "$action"';
    return 'NotAuthenticatedException: an authenticated owner session is '
        'required$suffix';
  }
}

/// Authenticated owner session for privileged hosted-database access.
///
/// Implementations expose the current [session]/[status], a reactive
/// [sessionChanges] stream for Riverpod/`ValueListenable`-style consumers, and
/// the [signIn]/[signOut] transitions. [isAuthenticated] and [requireSession]
/// are the gate privileged callers use (design.md -> Components and Interfaces:
/// `AuthService`).
abstract interface class AuthService {
  /// The current session, or `null` when signed out.
  AuthSession? get session;

  /// The current lifecycle [AuthStatus].
  AuthStatus get status;

  /// Whether a privileged hosted action is currently permitted.
  ///
  /// `true` exactly when an authenticated session exists. Finalize/sync check
  /// this (or call [requireSession]) before touching the hosted database
  /// (Requirement 19.3).
  bool get isAuthenticated;

  /// A broadcast stream that emits the current [AuthSession] (or `null`) on
  /// every transition, so UI and services can react to sign-in/sign-out.
  ///
  /// The stream does **not** re-emit the current value on subscription; read
  /// [session] for the present state and listen for subsequent changes.
  Stream<AuthSession?> get sessionChanges;

  /// Establishes an authenticated owner session and returns it.
  ///
  /// The real implementation (task 4.2) authenticates against Supabase with
  /// client-safe configuration; this signature carries no secret so the gate
  /// contract stays credential-free. Emits on [sessionChanges].
  Future<AuthSession> signIn();

  /// Clears the current session. A no-op when already signed out. Emits on
  /// [sessionChanges] when a session was cleared.
  Future<void> signOut();

  /// Returns the active [AuthSession], or throws [NotAuthenticatedException].
  ///
  /// This is the privileged-access gate: finalize, void, and the sync drain
  /// call it so a hosted write can never proceed without an authenticated owner
  /// session (Requirement 19.3). [action] names the attempted operation for a
  /// clearer error.
  AuthSession requireSession([String? action]);
}

/// In-memory [AuthService] for tests and for the app until Supabase is wired.
///
/// Holds session state in memory with no network and **no embedded
/// credentials** (task 4.1; the Supabase-backed implementation is task 4.2).
/// [signIn] mints a session for a configurable owner id; state changes are
/// published on [sessionChanges]. Safe to construct in a `flutter test` on
/// Windows.
class FakeAuthService implements AuthService {
  /// Creates the fake, optionally pre-seeded with an existing [initialSession]
  /// and using [ownerId] as the id minted by [signIn].
  FakeAuthService({
    AuthSession? initialSession,
    this.ownerId = 'owner',
  }) : _session = initialSession;

  /// The owner id that [signIn] mints a session for. Not a secret.
  final String ownerId;

  AuthSession? _session;

  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? get session => _session;

  @override
  AuthStatus get status =>
      _session == null ? AuthStatus.signedOut : AuthStatus.signedIn;

  @override
  bool get isAuthenticated => _session != null;

  @override
  Stream<AuthSession?> get sessionChanges => _controller.stream;

  @override
  Future<AuthSession> signIn() async {
    final next = AuthSession(userId: ownerId);
    _session = next;
    _controller.add(next);
    return next;
  }

  @override
  Future<void> signOut() async {
    if (_session == null) return;
    _session = null;
    _controller.add(null);
  }

  @override
  AuthSession requireSession([String? action]) {
    final current = _session;
    if (current == null) {
      throw NotAuthenticatedException(action);
    }
    return current;
  }

  /// Releases the broadcast stream. Call in test teardown.
  Future<void> dispose() => _controller.close();
}

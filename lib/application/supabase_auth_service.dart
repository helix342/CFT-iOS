/// Supabase-backed [AuthService] with a non-interactive owner session
/// (supabase-integration spec, Task 3).
///
/// Wood CFT has NO login screen (Requirement 2.1, CD-2a). This service
/// establishes the owner session non-interactively via Supabase **anonymous
/// sign-in**: on start it signs in anonymously if there is no persisted
/// session, so `status` becomes [AuthStatus.signedIn] without any user action
/// (Requirement 2.3). `AuthSession.userId` is the anonymous user's uid, which
/// RLS is keyed to server-side.
///
/// The signatures of the existing [AuthService] interface are preserved exactly
/// (Requirement 2.2); only the backing changes. `requireSession` still throws
/// [NotAuthenticatedException] when no session exists yet (e.g. offline at
/// first launch), so finalize/sync defer unchanged (Requirement 2.5). Token
/// refresh is handled by the SDK (Requirement 2.6).
///
/// ## Headless-testability
///
/// This file does not import `package:supabase_flutter` directly. It depends on
/// the narrow [SupabaseAuthPort] abstraction, which the real app adapts over
/// `GoTrueClient` (see `supabase_hosted_database.dart`) and which tests inject
/// a pure in-memory stub for — so no test needs a network or a live client.
library;

import 'dart:async';

import 'package:wood_cft/application/auth_service.dart';

/// A minimal, headless-testable view of the Supabase auth client.
///
/// The real adapter forwards each member to `Supabase.instance.client.auth`;
/// tests implement it in memory. Keeping this seam narrow means neither this
/// service nor its tests import the Supabase SDK.
abstract interface class SupabaseAuthPort {
  /// The current authenticated user id, or `null` when there is no session.
  String? get currentUserId;

  /// Emits the current user id (or `null`) on every auth-state transition,
  /// bridging `GoTrueClient.onAuthStateChange`.
  Stream<String?> get userIdChanges;

  /// Establishes a session non-interactively (anonymous sign-in) and returns
  /// the resulting user id.
  Future<String> signInAnonymously();

  /// Clears the current session (local scope).
  Future<void> signOut();
}

/// [AuthService] implementation backed by Supabase anonymous auth.
///
/// Construct with a [SupabaseAuthPort]; call [initialize] once at bootstrap to
/// establish the non-interactive session and start bridging auth-state changes.
class SupabaseAuthService implements AuthService {
  /// Creates the service over [port]. [initialize] performs the anonymous
  /// sign-in; constructing the service alone performs no network I/O.
  SupabaseAuthService({required SupabaseAuthPort port})
      // ignore: prefer_initializing_formals
      : _port = port;

  final SupabaseAuthPort _port;

  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();

  StreamSubscription<String?>? _portSub;
  AuthSession? _session;
  bool _initialized = false;

  /// Bootstraps the session: bridges [SupabaseAuthPort.userIdChanges] onto
  /// [sessionChanges], seeds the current session, and signs in anonymously when
  /// none exists yet (Requirement 2.3). Safe to call once; later calls are
  /// no-ops.
  ///
  /// If the anonymous sign-in cannot complete (e.g. offline at first launch)
  /// the error propagates and [session] stays `null`, so [requireSession]
  /// keeps throwing until a session is available (Requirement 2.5).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _portSub = _port.userIdChanges.listen(_onUserId);

    final existing = _port.currentUserId;
    if (existing != null) {
      _setSession(AuthSession(userId: existing));
      return;
    }

    final userId = await _port.signInAnonymously();
    _setSession(AuthSession(userId: userId));
  }

  void _onUserId(String? userId) {
    _setSession(userId == null ? null : AuthSession(userId: userId));
  }

  void _setSession(AuthSession? next) {
    if (next == _session) return;
    _session = next;
    _controller.add(next);
  }

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
    final existing = _session;
    if (existing != null) return existing;
    final userId = await _port.signInAnonymously();
    final next = AuthSession(userId: userId);
    _setSession(next);
    return next;
  }

  @override
  Future<void> signOut() async {
    if (_session == null) return;
    await _port.signOut();
    _setSession(null);
  }

  @override
  AuthSession requireSession([String? action]) {
    final current = _session;
    if (current == null) {
      throw NotAuthenticatedException(action);
    }
    return current;
  }

  /// Releases the broadcast stream and the port subscription. Call in teardown.
  Future<void> dispose() async {
    await _portSub?.cancel();
    await _controller.close();
  }
}

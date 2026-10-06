/// `SessionRepository`: owns the native session (§7) — loads it from secure
/// storage at startup, adopts new sessions (handling user swaps), schedules
/// expiry, drops the token on 401/expiry while keeping `userId`, signs out,
/// and publishes `SessionChange`s. The only source of the bearer token.
///
/// Why it exists: tracking and uploads must authenticate without the WebView,
/// and several consumers (Dio, bridge, locale) need one consistent session.
/// Status: used — registered as an async singleton in `service_locator.dart`;
/// tested in `test/features/auth/data/session_repository_test.dart`.
library;

import 'dart:async';
import 'dart:convert';

import '../../../core/analytics/analytics_client.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/failure.dart';
import '../../../core/storage/secure_store.dart';
import 'session_change_model.dart';
import 'session_model.dart';

/// Owns the native session (§7). The only source of the bearer token.
class SessionRepository {
  SessionRepository(this._store, this._analytics, this._logger, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  static const _storageKey = 'session';

  final SecureStore _store;
  final AnalyticsClient _analytics;
  final AppLogger _logger;
  final DateTime Function() _now;
  final _changes = StreamController<SessionChange>.broadcast();

  SessionModel? _current;
  Timer? _expiryTimer;

  SessionModel? get current => _current;

  Stream<SessionChange> get changes => _changes.stream;

  /// Bearer token for the API, or null when there is none or it has expired.
  String? get validToken => _current?.hasValidToken(_now()) == true ? _current!.token : null;

  /// Reads the stored session (startup, and in the tracking isolate whenever
  /// the UI says it changed). A corrupt entry is dropped.
  Future<void> load() async {
    try {
      final raw = await _store.read(_storageKey);
      if (raw == null) {
        _expiryTimer?.cancel();
        _current = null;
        return;
      }
      _current = SessionModel.fromStorageJson(jsonDecode(raw) as Map<String, dynamic>);
      _scheduleExpiry();
      await _analytics.identify(_current!.userId);
    } on FormatException catch (e) {
      _logger.warn('Dropping stored session: ${e.message}');
      await _store.delete(_storageKey);
    } catch (e) {
      throw DatabaseFailure('Could not read the session: $e');
    }
  }

  /// `auth.setSession`: idempotent; a different user triggers the swap (§7.1).
  Future<SessionAdopted> adopt(SessionModel session) async {
    if (!session.hasValidToken(_now())) {
      throw const InvalidInputFailure('Session is already expired.');
    }
    final previous = _current;
    final userSwapped = previous != null && previous.userId != session.userId;
    if (previous == session) return SessionAdopted(session, userSwapped: false);

    await _persist(session);
    _current = session;
    _scheduleExpiry();
    if (previous?.userId != session.userId) await _analytics.identify(session.userId);
    _logger.info('Session adopted for ${session.userId}${userSwapped ? ' (user swap)' : ''}');

    final change = SessionAdopted(session, userSwapped: userSwapped);
    _changes.add(change);
    return change;
  }

  /// Deliberate sign-out only. 401/expiry go through [markExpired].
  Future<void> signOut() async {
    _expiryTimer?.cancel();
    final hadSession = _current != null;
    _current = null;
    try {
      await _store.delete(_storageKey);
    } catch (e) {
      throw DatabaseFailure('Could not clear the session: $e');
    }
    await _analytics.reset();
    if (hadSession) {
      _logger.info('Signed out');
      _changes.add(const SessionSignedOut());
    }
  }

  /// Drops the token but keeps [SessionModel.userId] (D6); called on upload 401 or expiry.
  Future<void> markExpired() async {
    final session = _current;
    if (session == null || session.token == null) return;
    _expiryTimer?.cancel();
    final expired = session.withoutToken();
    _current = expired;
    await _persist(expired);
    _logger.info('Session expired for ${session.userId}');
    _changes.add(SessionExpired(session.expireAt));
  }

  Future<void> _persist(SessionModel session) async {
    try {
      await _store.write(_storageKey, jsonEncode(session.toStorageJson()));
    } catch (e) {
      throw DatabaseFailure('Could not store the session: $e');
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final session = _current;
    if (session?.token == null) return;
    final remaining = session!.expireAt.difference(_now());
    if (remaining.isNegative || remaining == Duration.zero) {
      unawaited(markExpired());
    } else {
      _expiryTimer = Timer(remaining, () => unawaited(markExpired()));
    }
  }

  Future<void> dispose() async {
    _expiryTimer?.cancel();
    await _changes.close();
  }
}

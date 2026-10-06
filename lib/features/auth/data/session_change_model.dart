/// `SessionChange`: the sealed events `SessionRepository` publishes —
/// `SessionAdopted` (with the user-swap flag), `SessionExpired`,
/// `SessionSignedOut`.
///
/// Why it exists: the bridge and `LocaleCubit` react to typed changes with an
/// exhaustive switch rather than polling the repository.
/// Status: used — emitted by `SessionRepository`, consumed by `AuthHandler`
/// and `LocaleCubit`.
library;

import 'package:equatable/equatable.dart';

import 'session_model.dart';

/// What [SessionRepository] publishes; the bridge turns these into `auth.*` events.
sealed class SessionChange extends Equatable {
  const SessionChange();
  @override
  List<Object?> get props => [];
}

final class SessionAdopted extends SessionChange {
  const SessionAdopted(this.session, {required this.userSwapped});
  final SessionModel session;

  /// A different user than the stored one: the user-swap procedure ran (§7.1).
  final bool userSwapped;

  @override
  List<Object?> get props => [session, userSwapped];
}

final class SessionExpired extends SessionChange {
  const SessionExpired(this.expireAt);
  final DateTime expireAt;
  @override
  List<Object?> get props => [expireAt];
}

final class SessionSignedOut extends SessionChange {
  const SessionSignedOut();
}

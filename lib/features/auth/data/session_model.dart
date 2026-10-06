/// `SessionModel`: the session Angular hands over (`token`, `userId`,
/// `expireAt`, `isSuperAdmin`, `lang`), with a validating `fromJson`, a
/// tolerant `fromStorageJson`, `toStorageJson` and the token-free
/// `toPublicJson`.
///
/// Why it exists: §7 — the token must be validated on entry, stored securely
/// and never echoed to JavaScript; `userId` survives expiry (D6).
/// Status: used — by `SessionRepository` and `AuthHandler`; tested in
/// `test/features/auth/data/session_model_test.dart`.
library;

import 'package:equatable/equatable.dart';

/// The session Angular hands over with `auth.setSession` (§7).
///
/// [token] is null once the session has been marked expired: [userId] is kept
/// so fixes stay attributed and tracking continues (D6).
class SessionModel extends Equatable {
  const SessionModel({
    required this.userId,
    required this.expireAt,
    this.token,
    this.isSuperAdmin = false,
    this.lang = 'en',
  });

  /// Validates a bridge payload. Throws [FormatException] on a bad shape.
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'token': final String token, 'userId': final String userId, 'expireAt': final String expireAt}
          when token.isNotEmpty && userId.isNotEmpty =>
        SessionModel(
          token: token,
          userId: userId,
          expireAt: _parseDate(expireAt),
          isSuperAdmin: json['isSuperAdmin'] == true,
          lang: _parseLang(json['lang']),
        ),
      _ => throw const FormatException('Session needs non-empty token, userId and expireAt.'),
    };
  }

  /// Reads what [toStorageJson] wrote; tolerates a missing token.
  factory SessionModel.fromStorageJson(Map<String, dynamic> json) {
    return switch (json) {
      {'userId': final String userId, 'expireAt': final String expireAt} => SessionModel(
          token: json['token'] as String?,
          userId: userId,
          expireAt: _parseDate(expireAt),
          isSuperAdmin: json['isSuperAdmin'] == true,
          lang: _parseLang(json['lang']),
        ),
      _ => throw const FormatException('Stored session is corrupt.'),
    };
  }

  final String? token;
  final String userId;
  final DateTime expireAt;
  final bool isSuperAdmin;
  final String lang;

  bool hasValidToken(DateTime now) => token != null && expireAt.isAfter(now);

  SessionModel withoutToken() =>
      SessionModel(userId: userId, expireAt: expireAt, isSuperAdmin: isSuperAdmin, lang: lang);

  Map<String, dynamic> toStorageJson() => {
        'token': token,
        'userId': userId,
        'expireAt': expireAt.toUtc().toIso8601String(),
        'isSuperAdmin': isSuperAdmin,
        'lang': lang,
      };

  /// What JavaScript may see: never the token (§7).
  Map<String, dynamic> toPublicJson() => {
        'userId': userId,
        'expireAt': expireAt.toUtc().toIso8601String(),
      };

  static DateTime _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('expireAt is not a date: $value');
    return parsed;
  }

  static String _parseLang(Object? value) => value == 'ar' ? 'ar' : 'en';

  @override
  List<Object?> get props => [token, userId, expireAt, isSuperAdmin, lang];
}

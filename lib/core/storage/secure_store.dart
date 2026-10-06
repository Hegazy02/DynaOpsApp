/// `SecureStore`: wrapper over `flutter_secure_storage`; the only place
/// secrets (the session with its bearer token) are persisted (§16).
///
/// Why it exists: keeps the plugin behind an injectable, mockable class and
/// makes "where is the token stored?" a one-file answer.
/// Status: used — registered in `service_locator.dart`; read and written by
/// `SessionRepository`.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Raw `flutter_secure_storage` wrapper. Secrets (the session) live only here (§16).
class SecureStore {
  SecureStore(this._storage);
  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}

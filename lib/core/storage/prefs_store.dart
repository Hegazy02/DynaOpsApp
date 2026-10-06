/// `PrefsStore`: tiny wrapper over `shared_preferences` for non-sensitive
/// flags. Never holds the session or a token.
///
/// Why it exists: repositories depend on this class, not on the plugin, so
/// tests can mock it and no secret ends up in plain preferences by accident.
/// Status: used — registered in `service_locator.dart`;
/// `PermissionsRepository` stores the "camera asked once" flag in it.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Raw `shared_preferences` wrapper for non-sensitive flags. Never holds the session.
class PrefsStore {
  PrefsStore(this._prefs);
  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  bool getBool(String key) => _prefs.getBool(key) ?? false;

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
}

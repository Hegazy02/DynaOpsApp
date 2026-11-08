/// `Env`: this branch's tenant settings, committed to git so a plain
/// `flutter run` / `flutter build apk` needs no `--dart-define` flags.
///
/// Why it exists: each tenant/environment lives on its own branch
/// (`alraedprod`, `alraeduat`, ...); switching branch switches this file.
/// Any value can still be overridden for a one-off build with
/// `--dart-define=KEY=value` (see `AppConfig.fromEnvironment`).
/// Status: used — the defaults behind `AppConfig.fromEnvironment`.
library;

abstract final class Env {
  static const tenant = 'alraedprod';
  static const webUrl = 'https://alraed.dynaops365.net/';
  static const apiBaseUrl = 'https://alraedapi.dynaops365.net/api/';
  static const posthogKey = '';
  static const posthogHost = 'https://eu.i.posthog.com';
}

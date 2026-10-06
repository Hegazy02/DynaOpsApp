/// `ExternalLinkRepository`: opens a URI in another app with `url_launcher`;
/// logs and returns false instead of throwing when no app can take it (§5.3).
///
/// Why it exists: the shell hands off phone, mail, maps and foreign-site
/// links; keeping the plugin here keeps `ShellCubit` free of it.
/// Status: used — registered in `service_locator.dart`; called by
/// `ShellCubit`.
library;

import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/app_logger.dart';

/// Hands links the shell does not load itself to other apps (§5.3).
class ExternalLinkRepository {
  ExternalLinkRepository(this._logger);
  final AppLogger _logger;

  /// Returns false when no app could take [uri]; never throws.
  Future<bool> open(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _logger.warn('No app for ${uri.scheme}: link');
      return opened;
    } catch (e) {
      _logger.warn('Opening ${uri.scheme}: link failed: $e');
      return false;
    }
  }
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DynaOps';

  @override
  String get shellLoading => 'Loading DynaOps…';

  @override
  String get shellOfflineTitle => 'No connection';

  @override
  String get shellOfflineMessage =>
      'Check your internet connection. DynaOps will reload automatically when you are back online.';

  @override
  String get shellLoadErrorTitle => 'Couldn\'t load DynaOps';

  @override
  String get shellLoadErrorMessage =>
      'The server did not respond. Try again in a moment.';

  @override
  String get retry => 'Retry';

  @override
  String get exitTitle => 'Leave DynaOps?';

  @override
  String get exitMessage => 'You can come back at any time.';

  @override
  String get exitConfirm => 'Leave';

  @override
  String get cancel => 'Cancel';

  @override
  String get trackingChannelName => 'Location tracking';

  @override
  String get trackingChannelDescription =>
      'Shows while DynaOps shares your location during work.';

  @override
  String get trackingNotificationTitle => 'DynaOps';

  @override
  String get trackingNotificationRunning =>
      'Sharing your location while you work';

  @override
  String get trackingNotificationPaused => 'Location tracking is paused';

  @override
  String get trackingNotificationOutsideShift =>
      'Outside your shift — tracking resumes when it starts';

  @override
  String get trackingNotificationSignIn =>
      'Sign in to DynaOps to resume uploads';

  @override
  String get trackingNotificationPermission =>
      'Location permission needed — tap to open DynaOps';

  @override
  String get trackingNotificationLocationOff =>
      'Turn on location to continue tracking';

  @override
  String get permissionsTitle => 'Set up location tracking';

  @override
  String permissionsStepCounter(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get stepLocationTitle => 'Allow location';

  @override
  String get stepLocationBody =>
      'DynaOps records your route and visits while you work. Choose \"While using the app\" and keep \"Precise\" on.';

  @override
  String get stepBackgroundTitle => 'Allow location all the time';

  @override
  String get stepBackgroundBody =>
      'DynaOps collects your location even when the app is closed or not in use, during working time only, to record your route and visits for your supervisor. On the next screen choose \"Allow all the time\".';

  @override
  String get stepNotificationsTitle => 'Allow notifications';

  @override
  String get stepNotificationsBody =>
      'A small notification shows while tracking runs, so you always know when your location is shared.';

  @override
  String get stepBatteryTitle => 'Keep DynaOps running';

  @override
  String get stepBatteryBody =>
      'Let DynaOps ignore battery optimisation so Android does not stop tracking when the phone is locked.';

  @override
  String get stepOemTitle => 'One more phone setting';

  @override
  String get oemSamsung =>
      'Open Settings → Battery → Background usage limits and add DynaOps to \"Never sleeping apps\".';

  @override
  String get oemXiaomi =>
      'Open the app settings, turn on \"Autostart\" and set Battery saver to \"No restrictions\".';

  @override
  String get oemHuawei =>
      'Open Settings → Battery → App launch, find DynaOps and allow it to manage launch manually with all three switches on.';

  @override
  String get oemOppo =>
      'Open the app settings → Battery and allow background activity and auto launch.';

  @override
  String get oemVivo =>
      'Open Settings → Battery → Background power consumption and allow DynaOps to run in the background.';

  @override
  String get permissionAllow => 'Allow';

  @override
  String get permissionOpenSettings => 'Open settings';

  @override
  String get permissionNext => 'Next';

  @override
  String get permissionDone => 'Done';

  @override
  String get openDiagnostics => 'Diagnostics';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagTracking => 'Tracking';

  @override
  String get diagSync => 'Uploads';

  @override
  String get diagPolicy => 'Tracking settings';

  @override
  String get diagDevice => 'Device';

  @override
  String get diagLogs => 'Recent log';

  @override
  String get diagState => 'State';

  @override
  String get diagReason => 'Reason';

  @override
  String get diagError => 'Error';

  @override
  String get diagService => 'Background service';

  @override
  String get diagLocationPermission => 'Location permission';

  @override
  String get diagBackgroundPermission => 'Background location';

  @override
  String get diagLastFix => 'Last fix';

  @override
  String get diagPending => 'Waiting to upload';

  @override
  String get diagFailed => 'Failed';

  @override
  String get diagLastUpload => 'Last upload';

  @override
  String get diagLastError => 'Last error';

  @override
  String get diagEnabled => 'Enabled by admin';

  @override
  String get diagMode => 'Mode';

  @override
  String get diagShift => 'Shift';

  @override
  String get diagAppVersion => 'App version';

  @override
  String get diagModel => 'Model';

  @override
  String get diagAndroid => 'Android SDK';

  @override
  String get diagYes => 'Yes';

  @override
  String get diagNo => 'No';

  @override
  String get diagNone => '—';

  @override
  String get diagSyncNow => 'Upload now';

  @override
  String get diagRetryFailed => 'Retry failed';

  @override
  String get diagExportLogs => 'Share log';

  @override
  String get diagClearCache => 'Clear web cache';

  @override
  String get diagNoticeSyncStarted => 'Upload started';

  @override
  String diagNoticeRequeued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points queued again',
      one: '1 point queued again',
      zero: 'Nothing to retry',
    );
    return '$_temp0';
  }

  @override
  String get diagNoticeCacheCleared => 'Web cache cleared';

  @override
  String get diagNoticeActionFailed => 'That did not work. Try again.';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// App name in the task switcher
  ///
  /// In en, this message translates to:
  /// **'DynaOps'**
  String get appTitle;

  /// Shown while the web app loads inside the shell
  ///
  /// In en, this message translates to:
  /// **'Loading DynaOps…'**
  String get shellLoading;

  /// Title when the web app cannot load because the device is offline
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get shellOfflineTitle;

  /// Body when the web app cannot load because the device is offline
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection. DynaOps will reload automatically when you are back online.'**
  String get shellOfflineMessage;

  /// Title when the web app failed to load for a reason other than being offline
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load DynaOps'**
  String get shellLoadErrorTitle;

  /// Body when the web app failed to load for a reason other than being offline
  ///
  /// In en, this message translates to:
  /// **'The server did not respond. Try again in a moment.'**
  String get shellLoadErrorMessage;

  /// Button that reloads the web app
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Title of the confirm dialog shown on back at the web app's root
  ///
  /// In en, this message translates to:
  /// **'Leave DynaOps?'**
  String get exitTitle;

  /// Body of the exit confirm dialog
  ///
  /// In en, this message translates to:
  /// **'You can come back at any time.'**
  String get exitMessage;

  /// Confirms leaving the app
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get exitConfirm;

  /// Generic cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Android notification channel name for the tracking service
  ///
  /// In en, this message translates to:
  /// **'Location tracking'**
  String get trackingChannelName;

  /// Android notification channel description
  ///
  /// In en, this message translates to:
  /// **'Shows while DynaOps shares your location during work.'**
  String get trackingChannelDescription;

  /// Title of the persistent tracking notification
  ///
  /// In en, this message translates to:
  /// **'DynaOps'**
  String get trackingNotificationTitle;

  /// Tracking notification text while collecting
  ///
  /// In en, this message translates to:
  /// **'Sharing your location while you work'**
  String get trackingNotificationRunning;

  /// Tracking notification text when tracking is stopped by policy
  ///
  /// In en, this message translates to:
  /// **'Location tracking is paused'**
  String get trackingNotificationPaused;

  /// Tracking notification text outside the shift window
  ///
  /// In en, this message translates to:
  /// **'Outside your shift — tracking resumes when it starts'**
  String get trackingNotificationOutsideShift;

  /// Tracking notification text when the session expired; fixes are still collected
  ///
  /// In en, this message translates to:
  /// **'Sign in to DynaOps to resume uploads'**
  String get trackingNotificationSignIn;

  /// Tracking notification text when location permission is missing
  ///
  /// In en, this message translates to:
  /// **'Location permission needed — tap to open DynaOps'**
  String get trackingNotificationPermission;

  /// Tracking notification text when the phone location setting is off
  ///
  /// In en, this message translates to:
  /// **'Turn on location to continue tracking'**
  String get trackingNotificationLocationOff;

  /// Title of the permission walkthrough screen
  ///
  /// In en, this message translates to:
  /// **'Set up location tracking'**
  String get permissionsTitle;

  /// Progress through the permission walkthrough
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String permissionsStepCounter(int current, int total);

  /// Walkthrough step: foreground location
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get stepLocationTitle;

  /// Walkthrough step body: foreground location
  ///
  /// In en, this message translates to:
  /// **'DynaOps records your route and visits while you work. Choose \"While using the app\" and keep \"Precise\" on.'**
  String get stepLocationBody;

  /// Walkthrough step: background location
  ///
  /// In en, this message translates to:
  /// **'Allow location all the time'**
  String get stepBackgroundTitle;

  /// Walkthrough step body: background location, including the Play Store prominent disclosure
  ///
  /// In en, this message translates to:
  /// **'DynaOps collects your location even when the app is closed or not in use, during working time only, to record your route and visits for your supervisor. On the next screen choose \"Allow all the time\".'**
  String get stepBackgroundBody;

  /// Walkthrough step: notifications
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get stepNotificationsTitle;

  /// Walkthrough step body: notifications
  ///
  /// In en, this message translates to:
  /// **'A small notification shows while tracking runs, so you always know when your location is shared.'**
  String get stepNotificationsBody;

  /// Walkthrough step: battery optimisation exemption
  ///
  /// In en, this message translates to:
  /// **'Keep DynaOps running'**
  String get stepBatteryTitle;

  /// Walkthrough step body: battery optimisation exemption
  ///
  /// In en, this message translates to:
  /// **'Let DynaOps ignore battery optimisation so Android does not stop tracking when the phone is locked.'**
  String get stepBatteryBody;

  /// Walkthrough step: manufacturer-specific background setting
  ///
  /// In en, this message translates to:
  /// **'One more phone setting'**
  String get stepOemTitle;

  /// Background guidance for Samsung phones
  ///
  /// In en, this message translates to:
  /// **'Open Settings → Battery → Background usage limits and add DynaOps to \"Never sleeping apps\".'**
  String get oemSamsung;

  /// Background guidance for Xiaomi/Redmi/POCO phones
  ///
  /// In en, this message translates to:
  /// **'Open the app settings, turn on \"Autostart\" and set Battery saver to \"No restrictions\".'**
  String get oemXiaomi;

  /// Background guidance for Huawei/Honor phones
  ///
  /// In en, this message translates to:
  /// **'Open Settings → Battery → App launch, find DynaOps and allow it to manage launch manually with all three switches on.'**
  String get oemHuawei;

  /// Background guidance for Oppo/Realme/OnePlus phones
  ///
  /// In en, this message translates to:
  /// **'Open the app settings → Battery and allow background activity and auto launch.'**
  String get oemOppo;

  /// Background guidance for Vivo/iQOO phones
  ///
  /// In en, this message translates to:
  /// **'Open Settings → Battery → Background power consumption and allow DynaOps to run in the background.'**
  String get oemVivo;

  /// Walkthrough button that asks for the permission
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionAllow;

  /// Walkthrough button when the permission can only be changed in settings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permissionOpenSettings;

  /// Walkthrough button that moves on without granting
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get permissionNext;

  /// Walkthrough button on the last step
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get permissionDone;

  /// Link to the diagnostics screen
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get openDiagnostics;

  /// Title of the diagnostics screen
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// Diagnostics section header
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get diagTracking;

  /// Diagnostics section header
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get diagSync;

  /// Diagnostics section header
  ///
  /// In en, this message translates to:
  /// **'Tracking settings'**
  String get diagPolicy;

  /// Diagnostics section header
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get diagDevice;

  /// Diagnostics section header
  ///
  /// In en, this message translates to:
  /// **'Recent log'**
  String get diagLogs;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get diagState;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get diagReason;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get diagError;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Background service'**
  String get diagService;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Location permission'**
  String get diagLocationPermission;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Background location'**
  String get diagBackgroundPermission;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Last fix'**
  String get diagLastFix;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get diagPending;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get diagFailed;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Last upload'**
  String get diagLastUpload;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Last error'**
  String get diagLastError;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Enabled by admin'**
  String get diagEnabled;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get diagMode;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get diagShift;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get diagAppVersion;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get diagModel;

  /// Diagnostics label
  ///
  /// In en, this message translates to:
  /// **'Android SDK'**
  String get diagAndroid;

  /// Diagnostics boolean value
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get diagYes;

  /// Diagnostics boolean value
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get diagNo;

  /// Diagnostics placeholder for an empty value
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get diagNone;

  /// Diagnostics action
  ///
  /// In en, this message translates to:
  /// **'Upload now'**
  String get diagSyncNow;

  /// Diagnostics action
  ///
  /// In en, this message translates to:
  /// **'Retry failed'**
  String get diagRetryFailed;

  /// Diagnostics action
  ///
  /// In en, this message translates to:
  /// **'Share log'**
  String get diagExportLogs;

  /// Diagnostics action; keeps the sign-in
  ///
  /// In en, this message translates to:
  /// **'Clear web cache'**
  String get diagClearCache;

  /// Diagnostics snackbar
  ///
  /// In en, this message translates to:
  /// **'Upload started'**
  String get diagNoticeSyncStarted;

  /// Diagnostics snackbar after retrying failed uploads
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to retry} =1{1 point queued again} other{{count} points queued again}}'**
  String diagNoticeRequeued(int count);

  /// Diagnostics snackbar
  ///
  /// In en, this message translates to:
  /// **'Web cache cleared'**
  String get diagNoticeCacheCleared;

  /// Diagnostics snackbar when an action fails
  ///
  /// In en, this message translates to:
  /// **'That did not work. Try again.'**
  String get diagNoticeActionFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

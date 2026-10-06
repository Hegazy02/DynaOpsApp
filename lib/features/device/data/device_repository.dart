/// `DeviceRepository`: app/device facts via `package_info_plus` and
/// `device_info_plus` (cached), orientation lock through `SystemChrome`, and
/// haptic vibrate (§5.5).
///
/// Why it exists: the small device controls Angular can ask for, kept behind
/// one repository so handlers never touch plugins directly.
/// Status: used — registered in `service_locator.dart`; called by
/// `AppHandler` and `ShellCubit`.
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/failure.dart';
import 'device_info_model.dart';

/// App/device facts and the small device controls Angular can ask for (§5.5).
class DeviceRepository {
  DeviceRepository(this._deviceInfo);
  final DeviceInfoPlugin _deviceInfo;
  DeviceInfoModel? _cached;

  Future<DeviceInfoModel> info() async {
    if (_cached != null) return _cached!;
    try {
      final package = await PackageInfo.fromPlatform();
      final android = await _deviceInfo.androidInfo;
      return _cached = DeviceInfoModel(
        appVersion: '${package.version}+${package.buildNumber}',
        manufacturer: android.manufacturer,
        model: android.model,
        androidSdk: android.version.sdkInt,
      );
    } catch (e) {
      throw PlatformFailure('Could not read device info: $e');
    }
  }

  /// `portrait | landscape | any` — what `screen.orientation.lock()` cannot do in a WebView.
  Future<void> lockOrientation(String orientation) {
    final orientations = switch (orientation) {
      'portrait' => const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      'landscape' => const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      'any' => const <DeviceOrientation>[],
      _ => throw InvalidInputFailure('Unknown orientation "$orientation".'),
    };
    return SystemChrome.setPreferredOrientations(orientations);
  }

  /// Short haptic pulse. Android's haptic API has no duration, so `ms` is advisory.
  Future<void> vibrate() => HapticFeedback.vibrate();
}

/// `AppHandler`: `app.info` (versions, tenant, origin, device),
/// `app.openSettings` (app | location | battery | notifications) and
/// `app.openNativeScreen` (permissions | diagnostics).
///
/// Why it exists: Angular needs to know which shell it runs in, to send the
/// rep to the right system settings screen when a permission is blocked, and
/// to open the native permission walkthrough or (for support) diagnostics.
/// Status: used — registered in `service_locator.dart`.
library;

import '../../core/config/app_config.dart';
import '../../features/device/data/device_repository.dart';
import '../../features/permissions/data/permissions_repository.dart';
import '../../features/shell/data/native_navigation_repository.dart';
import '../bridge_error_model.dart';
import '../bridge_handler.dart';
import '../bridge_message_model.dart';

/// `app.info`, `app.openSettings`, `app.openNativeScreen`.
class AppHandler extends BridgeHandler {
  AppHandler(this._config, this._device, this._permissions, this._navigation);

  final AppConfig _config;
  final DeviceRepository _device;
  final PermissionsRepository _permissions;
  final NativeNavigationRepository _navigation;

  static const _settingsScreens = {'app', 'location', 'battery', 'notifications'};

  @override
  String get prefix => 'app';

  @override
  Future<Object?> handle(BridgeRequest request) async {
    switch (request.action) {
      case 'app.info':
        final info = await _device.info();
        return {
          'appVersion': info.appVersion,
          'bridgeVersion': AppConfig.bridgeVersion,
          'platform': 'android',
          'webOrigin': _config.webOrigin,
          'tenant': _config.tenant,
          'deviceModel': '${info.manufacturer} ${info.model}',
          'androidSdk': info.androidSdk,
        };
      case 'app.openSettings':
        final screen = request.payload.optionalString('screen') ?? 'app';
        if (!_settingsScreens.contains(screen)) {
          throw BridgeError.invalidArgument('Unknown settings screen "$screen".');
        }
        await _permissions.openSettings(screen);
        return const <String, dynamic>{};
      case 'app.openNativeScreen':
        final screen = NativeScreen.fromWire(request.payload.requireString('screen'));
        if (screen == null) throw BridgeError.invalidArgument('Unknown native screen.');
        _navigation.open(screen);
        return const <String, dynamic>{};
      default:
        unknownAction(request);
    }
  }
}

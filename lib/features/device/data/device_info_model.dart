/// `DeviceInfoModel`: app version, manufacturer, model and Android SDK level.
///
/// Why it exists: the values `app.info` reports and the user-agent suffix
/// uses, read once and cached by `DeviceRepository`.
/// Status: used — returned by `DeviceRepository.info()`.
library;

import 'package:equatable/equatable.dart';

class DeviceInfoModel extends Equatable {
  const DeviceInfoModel({
    required this.appVersion,
    required this.manufacturer,
    required this.model,
    required this.androidSdk,
  });

  final String appVersion;
  final String manufacturer;
  final String model;
  final int androidSdk;

  @override
  List<Object?> get props => [appVersion, manufacturer, model, androidSdk];
}

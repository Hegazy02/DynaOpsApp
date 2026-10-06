/// `DiagnosticsCubit`: gathers a support snapshot — tracking status, sync
/// numbers, policy, device info and the shared log (UI + service lines) — and
/// runs the support actions: upload now, retry failed, share the log, clear
/// the WebView cache (§5.2, §15). Refreshes when tracking status changes.
///
/// Why it exists: one place to see why a rep's points are not arriving,
/// without adb.
/// Status: used — provided on `/diagnostics`.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/failure.dart';
import '../../device/data/device_info_model.dart';
import '../../device/data/device_repository.dart';
import '../../files/data/files_repository.dart';
import '../../shell/data/web_cache_repository.dart';
import '../../sync/data/sync_repository.dart';
import '../../tracking/data/tracking_policy_repository.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/data/tracking_status_model.dart';
import 'diagnostics_state.dart';

class DiagnosticsCubit extends Cubit<DiagnosticsState> {
  DiagnosticsCubit(
    this._tracking,
    this._sync,
    this._policies,
    this._device,
    this._files,
    this._webCache,
    this._logger,
  ) : super(const DiagnosticsLoading());

  final TrackingRepository _tracking;
  final SyncRepository _sync;
  final TrackingPolicyRepository _policies;
  final DeviceRepository _device;
  final FilesRepository _files;
  final WebCacheRepository _webCache;
  final AppLogger _logger;
  StreamSubscription<TrackingStatusModel>? _statuses;
  int _sequence = 0;

  Future<void> load() async {
    _statuses ??= _tracking.statuses.listen((_) => refresh());
    await refresh();
  }

  Future<void> refresh() async {
    final tracking = await _tracking.refreshStatus();
    DeviceInfoModel? device;
    try {
      device = await _device.info();
    } on Failure {
      device = null;
    }
    if (isClosed) return;
    emit(DiagnosticsLoaded(
      tracking: tracking,
      sync: await _sync.status(),
      policy: await _policies.current(),
      device: device,
      log: _logger.entries.reversed.take(200).toList(),
    ));
  }

  Future<void> syncNow() =>
      _act(() async => DiagnosticsNotice(DiagnosticsNoticeKind.syncStarted, sequence: ++_sequence), () => _sync.syncNow());

  Future<void> retryFailed() async {
    var count = 0;
    await _act(
      () async => DiagnosticsNotice(DiagnosticsNoticeKind.requeued, count: count, sequence: ++_sequence),
      () async => count = await _sync.retryFailed(),
    );
  }

  Future<void> clearWebCache() => _act(
        () async => DiagnosticsNotice(DiagnosticsNoticeKind.cacheCleared, sequence: ++_sequence),
        _webCache.clear,
      );

  Future<void> exportLog() async {
    try {
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      await _files.shareText(name: 'dynaops-log-$stamp.txt', text: _logger.entries.join('\n'));
    } on Failure catch (f) {
      _logger.warn('Log export failed: ${f.message}');
      _notify(DiagnosticsNotice(DiagnosticsNoticeKind.actionFailed, sequence: ++_sequence));
    }
  }

  Future<void> _act(Future<DiagnosticsNotice> Function() notice, Future<Object?> Function() action) async {
    try {
      await action();
      await refresh();
      _notify(await notice());
    } on Failure catch (f) {
      _logger.warn('Diagnostics action failed: ${f.message}');
      _notify(DiagnosticsNotice(DiagnosticsNoticeKind.actionFailed, sequence: ++_sequence));
    }
  }

  void _notify(DiagnosticsNotice notice) {
    if (state case final DiagnosticsLoaded loaded when !isClosed) emit(loaded.withNotice(notice));
  }

  @override
  Future<void> close() async {
    await _statuses?.cancel();
    return super.close();
  }
}

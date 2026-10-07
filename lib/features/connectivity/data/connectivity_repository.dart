/// `ConnectivityRepository`: watches transport changes from
/// `connectivity_plus`, debounces them and confirms real reachability with a
/// HEAD probe against the API (§12). Publishes only genuine changes.
///
/// Why it exists: Wi-Fi with no internet (captive portal) must not count as
/// online; the shell, the bridge and later the uploader all rely on this.
/// Status: used — registered in `service_locator.dart`; started by
/// `ShellCubit`, exposed to Angular by `NetworkHandler`.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../request_inspector/data/request_log_interceptor.dart';
import 'network_status_model.dart';

/// Transport changes from `connectivity_plus`, confirmed by a reachability
/// probe against the API (§12). Publishes only real, debounced changes.
class ConnectivityRepository {
  ConnectivityRepository(
    this._connectivity,
    this._dio,
    this._logger, {
    this.debounce = const Duration(seconds: 3),
    this.probeTimeout = const Duration(seconds: 5),
  });

  final Connectivity _connectivity;
  final Dio _dio;
  final AppLogger _logger;
  final Duration debounce;
  final Duration probeTimeout;

  final _changes = StreamController<NetworkStatusModel>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;
  NetworkStatusModel _current = NetworkStatusModel.unknown;

  NetworkStatusModel get current => _current;

  Stream<NetworkStatusModel> get changes => _changes.stream;

  Future<void> start() async {
    _subscription ??= _connectivity.onConnectivityChanged.listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, () => unawaited(refresh()));
    });
    await refresh();
  }

  /// Re-reads the transport and re-probes; called on start, resume and transport changes.
  Future<NetworkStatusModel> refresh() async {
    final NetworkStatusModel next;
    try {
      final type = _typeOf(await _connectivity.checkConnectivity());
      next = NetworkStatusModel(
        connectionType: type,
        reachable: type != 'none' && await _probe(),
      );
    } catch (e) {
      _logger.warn('Connectivity check failed: $e');
      return _current;
    }
    if (next != _current) {
      _current = next;
      _changes.add(next);
    }
    return next;
  }

  /// Any HTTP answer from the API counts as reachable, even 401/404/405, and
  /// so does a reply that is merely slow; only failing to connect does not.
  Future<bool> _probe() async {
    try {
      await _dio.head<void>(
        '',
        options: Options(
          sendTimeout: probeTimeout,
          receiveTimeout: probeTimeout,
          validateStatus: (_) => true,
          // Probes run on every transport change; keep them out of the request inspector.
          extra: {RequestLogInterceptor.skipKey: true},
        ),
      );
      return true;
    } on DioException catch (e) {
      // The connection was made and only the reply was slow (seen on the
      // tenant APIs: 5–10 s for HEAD): the network is up, so count it.
      return e.type == DioExceptionType.receiveTimeout;
    }
  }

  static String _typeOf(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'wifi';
    if (results.contains(ConnectivityResult.mobile)) return 'mobile';
    if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
    if (results.contains(ConnectivityResult.vpn)) return 'vpn';
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) return 'none';
    return 'other';
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _subscription?.cancel();
    await _changes.close();
  }
}

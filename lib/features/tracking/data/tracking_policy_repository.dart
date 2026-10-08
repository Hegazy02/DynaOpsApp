/// `TrackingPolicyRepository`: the rep's tracking policy — the stored snapshot
/// (works offline), refreshed from `GET RepDashboard` and saved back; when
/// nothing was ever fetched the rep is not tracked (`TrackingPolicyModel.unknown`).
/// [changes] fires on every refresh / clear in this isolate.
///
/// Why it exists: §8.1 refreshes on launch, on `auth.setSession`, on resume and
/// hourly; both isolates read the same snapshot from the shared database.
/// Status: used — by `TrackingEngine` (service) and `TrackingHandler`
/// (`tracking.refreshPolicy`), and `PermissionGate` (UI isolate).
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/failure.dart';
import '../../sync/data/sync_meta_dao.dart';
import 'tracking_api.dart';
import 'tracking_policy_model.dart';

class TrackingPolicyRepository {
  TrackingPolicyRepository(this._api, this._meta, this._logger, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  static const refreshEvery = Duration(hours: 1);

  final TrackingApi _api;
  final SyncMetaDao _meta;
  final AppLogger _logger;
  final DateTime Function() _now;
  final _changes = StreamController<TrackingPolicyModel>.broadcast();

  /// The policy just fetched, or [TrackingPolicyModel.unknown] after [clear].
  Stream<TrackingPolicyModel> get changes => _changes.stream;

  /// The last `RepDashboard` answer, or [TrackingPolicyModel.unknown] (not
  /// tracked) before the first one. Never throws.
  Future<TrackingPolicyModel> current() async {
    try {
      final raw = await _meta.get(SyncMetaKeys.policy);
      if (raw != null) return TrackingPolicyModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      _logger.warn('Ignoring bad policy snapshot: $e');
    }
    return TrackingPolicyModel.unknown;
  }

  /// Tracking is a condition of using the app: a `RepDashboard` answer is
  /// stored and says tracking is on. False before the first answer. Never throws.
  Future<bool> trackingRequired() async => (await current()).enabled;

  Future<bool> isStale() async {
    final fetchedAt = await _meta.getDate(SyncMetaKeys.policyFetchedAt);
    return fetchedAt == null || _now().difference(fetchedAt) >= refreshEvery;
  }

  /// Reads the policy from the API and stores it. Throws [Failure].
  Future<TrackingPolicyModel> refresh() async {
    final TrackingPolicyModel policy;
    try {
      policy = TrackingPolicyModel.fromJson(await _api.fetchRepDashboard());
    } on DioException catch (e) {
      throw mapDioError(e);
    } on FormatException catch (e) {
      throw ServerFailure('Unexpected RepDashboard response: ${e.message}');
    }
    await _meta.set(SyncMetaKeys.policy, jsonEncode(policy.toJson()));
    await _meta.setDate(SyncMetaKeys.policyFetchedAt, _now());
    _changes.add(policy);
    return policy;
  }

  /// [refresh] when stale (or [force]), else the snapshot. Never throws.
  Future<TrackingPolicyModel> refreshIfStale({bool force = false}) async {
    if (force || await isStale()) {
      try {
        return await refresh();
      } on Failure catch (f) {
        _logger.warn('Policy refresh failed: ${f.message}');
      }
    }
    return current();
  }

  /// Forgets the previous user's policy (§7.1).
  Future<void> clear() async {
    await _meta.set(SyncMetaKeys.policy, null);
    await _meta.set(SyncMetaKeys.policyFetchedAt, null);
    _changes.add(TrackingPolicyModel.unknown);
  }
}

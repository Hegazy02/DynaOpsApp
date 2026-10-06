/// `LocationUploader` (contract) and `ApiLocationUploader` (real
/// implementation): sends one batch of fixes and maps every error to a
/// `Failure` — 401 `UnauthorizedFailure`, 403 `ForbiddenFailure`,
/// 400/413/422 `ValidationFailure` (never accepted), anything else retryable.
///
/// Why it exists: §11 keeps the sync engine independent of the wire format;
/// a future kind (§10.2 outbox) gets its own uploader.
/// Status: used — `ApiLocationUploader` is registered in both locators and
/// called by `SyncManager`. The API has no dedupe key, so a retry after an
/// ambiguous failure (timeout after the server stored the batch) can
/// duplicate points; the batch id stays local.
library;

import 'package:dio/dio.dart';

import '../../../core/network/failure.dart';
import '../../tracking/data/location_fix_model.dart';
import 'location_upload_api.dart';

abstract interface class LocationUploader {
  /// Throws a [Failure]; returns normally only when the server accepted the batch.
  Future<void> upload(List<LocationFixModel> batch);
}

class ApiLocationUploader implements LocationUploader {
  ApiLocationUploader(this._api, {required this.localTimestamps});

  final LocationUploadApi _api;
  final bool localTimestamps;

  @override
  Future<void> upload(List<LocationFixModel> batch) async {
    if (batch.isEmpty) return;
    try {
      await _api.postBatch(batch.map((f) => f.toWirePing(localTimestamps: localTimestamps)).toList());
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

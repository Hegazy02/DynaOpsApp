/// `LocationUploadApi`: raw `POST LocationPings/batch` with `{ pings: [...] }`.
/// The bearer token identifies the user; the body carries no identity.
///
/// Why it exists: API-client layer of the upload (D5). The contract was taken
/// from the old tracker's code (dyn_gis), which posts to the same endpoint —
/// only the contract is reused; nothing depends on that app.
/// Status: used — by `ApiLocationUploader`.
library;

import 'package:dio/dio.dart';

class LocationUploadApi {
  LocationUploadApi(this._dio);
  final Dio _dio;

  static const path = 'LocationPings/batch';

  /// Throws [DioException] on any non-2xx answer or transport error.
  Future<void> postBatch(List<Map<String, dynamic>> pings) async {
    await _dio.post<void>(
      path,
      data: {'pings': pings},
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }
}

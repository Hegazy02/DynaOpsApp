/// `TrackingApi`: raw `GET RepDashboard` — the rep's own dashboard, which
/// carries `trackingEnabled`, `trackingMode` and `shiftWindow` at its top
/// level. Returns the envelope's `data` map unparsed.
///
/// Why it exists: API-client layer of the policy read (§8.1); there is no
/// lighter endpoint for a rep, and the admin `RepTracking` list needs a
/// permission reps do not have.
/// Status: used — by `TrackingPolicyRepository` in both isolates.
library;

import 'package:dio/dio.dart';

class TrackingApi {
  TrackingApi(this._dio);
  final Dio _dio;

  /// Throws [DioException]; the repository maps it.
  Future<Map<String, dynamic>> fetchRepDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>('RepDashboard');
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('RepDashboard returned no data');
  }
}

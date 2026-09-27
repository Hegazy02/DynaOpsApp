---
name: flutter-dio-repository-setup
description: Set up the Dio HTTP client with interceptors, auth-token attachment, and debug logging, and implement the Repository layer that parses responses into Models and maps failures — keeping Cubits free of networking code. Use when adding a new API integration, wiring auth headers, or handling network errors.
---
# Dio Client & Repository Setup

## Contents
- [Core Concepts](#core-concepts)
- [Dio Client Setup](#dio-client-setup)
- [Auth Token Interceptor](#auth-token-interceptor)
- [Modeling Failures](#modeling-failures)
- [Repository Pattern](#repository-pattern)
- [Checklist](#checklist)
- [Examples](#examples)

## Core Concepts

The Repository is the only layer allowed to talk to Dio (see [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#layer-responsibilities)). It has two jobs:

1. Call the API client and parse a successful response into a typed `*Model` (see [flutter-implement-json-serialization](../flutter-implement-json-serialization/SKILL.md) for the `fromJson`/`toJson` convention).
2. Catch every `DioException` and re-throw/return a typed `Failure` — never a raw `DioException`, never a bare `String`.

A Repository file never imports `package:flutter/material.dart`.

## Dio Client Setup

Build one shared `Dio` instance (registered in `get_it`, see [flutter-service-locator-setup](../flutter-service-locator-setup/SKILL.md)) with base options and an interceptor chain. Interceptor order matters — attach auth headers before logging, so logs show the real outgoing request:

```dart
Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.example.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(AuthInterceptor(getIt()));

  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(requestBody: true, responseBody: true, error: true),
    );
  }

  return dio;
}
```

`pretty_dio_logger` is a **debug-only** dependency — guard it with `kDebugMode` (from `package:flutter/foundation.dart`) so request/response bodies (which may contain tokens or PII) are never logged in a release build.

## Auth Token Interceptor

Attach the bearer token from `flutter_secure_storage` on every outgoing request, and handle a 401 by clearing the session rather than looping forever:

```dart
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage);
  final FlutterSecureStorage _secureStorage;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _secureStorage.delete(key: 'auth_token');
      // Emit a global "session expired" event here (e.g. via a StreamController
      // that AuthCubit listens to) rather than navigating directly from an interceptor.
    }
    handler.next(err);
  }
}
```

Never store the auth token in `shared_preferences` — it's unencrypted on-disk storage. Tokens, refresh tokens, and any credential-like value always go through `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences/Keystore on Android).

## Modeling Failures

Model failures the same way as Cubit state — a small sealed hierarchy, no third-party functional-programming package required:

```dart
sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection.');
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure() : super('The request timed out.');
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Your session has expired.');
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}
```

Map `DioExceptionType` to a `Failure` in one shared helper so every Repository handles errors identically:

```dart
Failure mapDioError(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionError => const NetworkFailure(),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const TimeoutFailure(),
    DioExceptionType.badResponse when e.response?.statusCode == 401 => const UnauthorizedFailure(),
    DioExceptionType.badResponse => ServerFailure(
        e.response?.data?['message'] as String? ?? 'Something went wrong.',
      ),
    _ => ServerFailure(e.message ?? 'Unexpected error.'),
  };
}
```

## Repository Pattern

Every public Repository method: call Dio, decode, parse to Model, catch `DioException` and rethrow as `Failure`.

```dart
class ProductRepository {
  ProductRepository(this._dio);
  final Dio _dio;

  Future<List<ProductModel>> fetchProducts() async {
    try {
      final response = await _dio.get('/products');
      return (response.data as List)
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
```

The Cubit then only ever catches `Failure`, never `DioException` (Rule 4 in [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#cubit-rules)):

```dart
try {
  final products = await _repository.fetchProducts();
  emit(ProductSuccess(products));
} on Failure catch (f) {
  emit(ProductError(f.message));
}
```

## Checklist

- [ ] Exactly one `Dio` instance is created and registered in `get_it` — no ad hoc `Dio()` calls scattered across Repositories.
- [ ] `pretty_dio_logger` is added only under `if (kDebugMode)`.
- [ ] Auth token is read/written via `flutter_secure_storage`, never `shared_preferences`.
- [ ] Every Repository method wraps its Dio call in `try`/`on DioException catch` and rethrows a `Failure`.
- [ ] No `*_repository.dart` file imports `package:flutter/material.dart`.
- [ ] A 401 clears the stored token instead of retrying indefinitely.

## Examples

See [flutter-implement-json-serialization](../flutter-implement-json-serialization/SKILL.md) for the `Model.fromJson` half of this pattern, and [flutter-service-locator-setup](../flutter-service-locator-setup/SKILL.md) for wiring `Dio`, `FlutterSecureStorage`, and `ProductRepository` into `get_it`.

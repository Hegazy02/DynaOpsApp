---
name: flutter-package-reference
description: Reference for this project's approved package stack (flutter_bloc, dio, get_it, go_router, shared_preferences, flutter_secure_storage) and optional add-ons (pretty_dio_logger, flutter_svg, shimmer, flutter_localizations+intl, google_maps_flutter), with when-to-use guidance and minimal setup snippets. Use before running `flutter pub add`, or when deciding which package covers a new capability.
---
# Approved Package Stack

## Contents
- [Required Stack](#required-stack)
- [Decision Guide](#decision-guide)
- [Optional Add-ons](#optional-add-ons)
- [Adding a New Package](#adding-a-new-package)

## Required Stack

This project standardizes on these packages to keep setup minimal and avoid `build_runner` friction (no `freezed`, no `json_serializable`, no `injectable`):

| Package | Role | See also |
|---|---|---|
| `flutter_bloc` | State management (Cubit + sealed states) | [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md) |
| `dio` | HTTP client (interceptors, typed errors) | [flutter-dio-repository-setup](../flutter-dio-repository-setup/SKILL.md) |
| `get_it` | Service locator / DI, no code generation | [flutter-service-locator-setup](../flutter-service-locator-setup/SKILL.md) |
| `go_router` | Declarative routing, deep linking | [flutter-setup-declarative-routing](../flutter-setup-declarative-routing/SKILL.md) |
| `shared_preferences` | Simple, non-sensitive local key-value storage | — |
| `flutter_secure_storage` | Encrypted storage for tokens/credentials | [flutter-dio-repository-setup](../flutter-dio-repository-setup/SKILL.md#auth-token-interceptor) |

None of these are yet in this project's `pubspec.yaml` — add them with `flutter pub add <package>` as each is actually needed, not all at once.

## Decision Guide

| I need to... | Reach for |
|---|---|
| Manage feature state / loading-success-error | `flutter_bloc` (Cubit) |
| Call a REST API | `dio` |
| Share a service/repository instance across the app | `get_it` |
| Navigate with URL paths / deep links | `go_router` |
| Persist a simple flag or setting (theme, onboarding-seen) | `shared_preferences` |
| Store a JWT, refresh token, or API key | `flutter_secure_storage` |
| Log HTTP traffic while debugging | `pretty_dio_logger` (debug builds only) |
| Support multiple languages | `flutter_localizations` + `intl` |
| Render a vector icon/illustration (`.svg`) | `flutter_svg` |
| Show a skeleton/placeholder while a Cubit is `Loading` | `shimmer` |
| Embed a map | `google_maps_flutter` |

If a capability isn't covered by this table, raise it before adding a new dependency — check [dart-resolve-package-conflicts](../dart-resolve-package-conflicts/SKILL.md) once it's approved and you're wiring it in, in case it collides with an existing transitive dependency.

## Optional Add-ons

### `pretty_dio_logger` — HTTP request/response logging
Debug-only; never log bodies in release builds.
```dart
if (kDebugMode) {
  dio.interceptors.add(PrettyDioLogger(requestBody: true, responseBody: true));
}
```

### `flutter_localizations` + `intl` — i18n
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any # let flutter_localizations pin the compatible version
```
Full ARB setup, generated `AppLocalizations`, plurals/RTL, and runtime locale switching: see [flutter-setup-localization](../flutter-setup-localization/SKILL.md).

### `flutter_secure_storage` — encrypted key/value storage
```dart
const storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);
final token = await storage.read(key: 'auth_token');
```

### `flutter_svg` — vector graphics
```dart
SvgPicture.asset('assets/icons/logo.svg', width: 24, height: 24)
```

### `shimmer` — skeleton loading state
Pair with the `Loading` branch of a sealed `ProductState` switch (see [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#blocbuilder-vs-bloclistener-vs-blocconsumer)):
```dart
Shimmer.fromColors(
  baseColor: Colors.grey.shade300,
  highlightColor: Colors.grey.shade100,
  child: Container(height: 80, color: Colors.white),
)
```

### `google_maps_flutter` — embedded maps
Requires platform setup beyond `pubspec.yaml`: an API key in `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY` meta-data) and in `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey(...)`). Never commit the raw API key — read it from a build-time define or a gitignored config file.
```dart
GoogleMap(
  initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 2),
  onMapCreated: (controller) => _controller = controller,
)
```

## Adding a New Package

**Task Progress:**
- [ ] Confirm the capability is in the required stack or decision guide above (or get it approved first).
- [ ] `flutter pub add <package>`.
- [ ] `flutter pub get` and confirm it resolves cleanly — if it doesn't, see [dart-resolve-package-conflicts](../dart-resolve-package-conflicts/SKILL.md).
- [ ] Register any new service in `get_it` (see [flutter-service-locator-setup](../flutter-service-locator-setup/SKILL.md)) rather than instantiating it ad hoc.

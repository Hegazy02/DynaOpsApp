---
name: flutter-service-locator-setup
description: Configure dependency injection with get_it — registering singletons, lazy singletons, and factories in a single service_locator.dart, with no code generation. Use when wiring a new repository/service, adding get_it, setting up main() bootstrap order, or overriding dependencies in tests.
---
# Dependency Injection with get_it

## Contents
- [Core Concepts](#core-concepts)
- [Setup Workflow](#setup-workflow)
- [Registration Types](#registration-types)
- [Async Initialization](#async-initialization)
- [Scoping by Feature](#scoping-by-feature)
- [Overriding in Tests](#overriding-in-tests)
- [Checklist](#checklist)
- [Examples](#examples)

## Core Concepts

`get_it` is a service locator: a single global registry (`GetIt.instance`, conventionally aliased `getIt`) that hands out configured instances so services don't have to be threaded down 5 constructor levels. It requires no code generation, matching this project's policy of avoiding `build_runner`.

Register in one place — `core/di/service_locator.dart` — and call the setup function once, before `runApp()`.

## Setup Workflow

**Task Progress:**
- [ ] `flutter pub add get_it`
- [ ] Create `lib/core/di/service_locator.dart` with a top-level `final getIt = GetIt.instance;` and a `setupServiceLocator()` function.
- [ ] Register external/core services first (Dio, SharedPreferences, FlutterSecureStorage), then Repositories, then anything else that depends on them.
- [ ] Call `await setupServiceLocator();` in `main()` after `WidgetsFlutterBinding.ensureInitialized()` and before `runApp()`.
- [ ] Resolve dependencies in Cubits via constructor injection: `ProductCubit(getIt())` (or `getIt<ProductRepository>()` if there's more than one registration of a compatible type).

## Registration Types

| Method | Instantiation | Use for |
|---|---|---|
| `registerLazySingleton(() => ...)` | Created on first `getIt<T>()` call, then reused | Repositories, API clients — the default choice |
| `registerSingleton(instance)` | Created immediately, eagerly | A value you already have at setup time (e.g. a resolved `SharedPreferences` instance) |
| `registerFactory(() => ...)` | A new instance every `getIt<T>()` call | Cubits — each screen/route should get its own fresh instance, never a shared one |
| `registerSingletonAsync(() async => ...)` | Awaited once, cached | Services needing async setup (`SharedPreferences.getInstance()`) — see below |

**Cubits are registered as `registerFactory`, not singletons.** A shared Cubit instance across unrelated screens leaks state and stale listeners between navigations. If a Cubit truly must survive across a whole flow, scope its `BlocProvider` around that flow's parent route instead of making it a `get_it` singleton — see [flutter-cubit-architecture](../flutter-cubit-architecture/SKILL.md#scoping-providers).

## Async Initialization

Some services (`SharedPreferences`, secure-storage first-read) need an `await` before they're usable. Use `registerSingletonAsync` and gate `runApp()` on `getIt.allReady()`:

```dart
Future<void> setupServiceLocator() async {
  getIt.registerSingletonAsync<SharedPreferences>(
    () async => SharedPreferences.getInstance(),
  );

  getIt.registerLazySingleton(() => const FlutterSecureStorage());

  getIt.registerLazySingleton(
    () => Dio(BaseOptions(baseUrl: 'https://api.example.com')),
  );

  getIt.registerLazySingleton(() => ProductRepository(getIt()));

  getIt.registerFactory(() => ProductCubit(getIt()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  await getIt.allReady(); // waits on every registerSingletonAsync
  runApp(const MyApp());
}
```

## Scoping by Feature

As the app grows, split registration into one function per feature so `setupServiceLocator()` stays a readable table of contents:

```dart
Future<void> setupServiceLocator() async {
  _registerCore();
  _registerAuthFeature();
  _registerProductFeature();
}

void _registerProductFeature() {
  getIt.registerLazySingleton(() => ProductRepository(getIt()));
  getIt.registerFactory(() => ProductCubit(getIt()));
}
```

## Overriding in Tests

`get_it` is a global, so tests must reset it between runs to avoid leaking registrations across test files:

```dart
setUp(() {
  getIt.reset();
  getIt.registerLazySingleton<ProductRepository>(() => MockProductRepository());
});

tearDown(() => getIt.reset());
```

Prefer registering against the **abstract type** (`ProductRepository` as an interface with a `ProductRepositoryImpl`) when a feature is expected to need swappable test doubles — `getIt.registerLazySingleton<ProductRepository>(() => ProductRepositoryImpl(getIt()))`. This isn't required for every service, but it's the escape hatch when a concrete class is hard to fake directly.

## Checklist

- [ ] Every external/core dependency (Dio, storage, prefs) is registered exactly once in `service_locator.dart` — never instantiated ad hoc inside a Repository or Cubit.
- [ ] Cubits use `registerFactory`; Repositories/clients use `registerLazySingleton`.
- [ ] Anything needing async setup is `registerSingletonAsync` and awaited via `getIt.allReady()` before `runApp()`.
- [ ] `getIt.reset()` runs in test `setUp`/`tearDown` for any test file that touches the locator.

## Examples

### Full `service_locator.dart`

```dart
// core/di/service_locator.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Core / external
  getIt.registerSingletonAsync<SharedPreferences>(
    () async => SharedPreferences.getInstance(),
  );
  getIt.registerLazySingleton(() => const FlutterSecureStorage());
  getIt.registerLazySingleton(() => Dio(BaseOptions(baseUrl: 'https://api.example.com')));

  // Repositories
  getIt.registerLazySingleton(() => ProductRepository(getIt()));
  getIt.registerLazySingleton(() => AuthRepository(getIt(), getIt()));

  // Cubits (factory: a new instance per screen)
  getIt.registerFactory(() => ProductCubit(getIt()));
}
```

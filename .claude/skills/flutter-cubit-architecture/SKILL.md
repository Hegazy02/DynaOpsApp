---
name: flutter-cubit-architecture
description: Enforces this project's unidirectional data flow — API Client → Repository → Cubit → UI — using flutter_bloc Cubits and Dart 3 sealed state classes. Use when scaffolding a new feature, adding or reviewing a Cubit, wiring BlocProvider/BlocBuilder/BlocListener/BlocConsumer, or checking a PR that touches state management.
---
# Cubit Architecture (Unidirectional Data Flow)

## Contents
- [Core Architecture](#core-architecture)
- [Layer Responsibilities](#layer-responsibilities)
- [Cubit Rules](#cubit-rules)
- [Modeling State with Sealed Classes](#modeling-state-with-sealed-classes)
- [BlocBuilder vs BlocListener vs BlocConsumer](#blocbuilder-vs-bloclistener-vs-blocconsumer)
- [Scoping Providers](#scoping-providers)
- [Naming Conventions](#naming-conventions)
- [Testing Cubits](#testing-cubits)
- [Code Review Checklist](#code-review-checklist)
- [Examples](#examples)

## Core Architecture

Data flows in one direction only. Never break this chain, and never let a layer skip past its neighbor:

```
API Client -> Repository -> Cubit -> UI (Widgets)
```

1. **UI** calls a method on **Cubit** (never reaches past it to the Repository or API Client).
2. **Cubit** calls an async method on **Repository** and reacts to the result.
3. **Repository** calls the **API Client** (Dio), parses the raw response into a typed **Model**, and returns it (or a typed failure — see [flutter-dio-repository-setup](../flutter-dio-repository-setup/SKILL.md)).
4. **Cubit** emits a new immutable **State**.
5. **UI** rebuilds automatically via `BlocBuilder`/`BlocConsumer`.

## Layer Responsibilities

| Layer | May import `flutter/material.dart`? | May import `dio`? | Owns |
|---|---|---|---|
| API Client | No | Yes | Raw HTTP calls only |
| Repository | No | Yes | Parsing JSON -> Model, mapping errors -> Failure |
| Cubit | No | No | Business/UI-state logic, emitting `State` |
| UI (Widget/Screen) | Yes | No | Presentation, forwarding user input to the Cubit |

If a file needs to import both `material.dart` and `dio`, it's in the wrong layer — split it.

## Cubit Rules

### Rule 1 — No business logic or API calls in widgets
Widgets present data and forward input. They never call `dio`/`http` directly and never contain parsing or branching business logic.

```dart
// BAD — network call and state handling live in the widget
onPressed: () async {
  final response = await dio.get('/products');
  setState(() { ... });
}

// GOOD — widget only forwards the intent
onPressed: () => context.read<ProductCubit>().fetchProducts(),
```

### Rule 2 — No `Dio`/`http` inside Cubits
Cubits depend on a `Repository`, never on the API client directly. This keeps Cubits testable without a real (or even mocked) network stack.

### Rule 3 — No UI imports inside Repositories or Cubits
Never `import 'package:flutter/material.dart'` in a `*_cubit.dart`, `*_state.dart`, or `*_repository.dart` file. If you need a color, icon, or `BuildContext`, that logic belongs in the widget layer.

### Rule 4 — Repositories catch and translate errors
A Repository method never lets a raw `DioException` escape to the Cubit. It catches it and returns/throws a typed failure so the Cubit can pattern-match on it. See [flutter-dio-repository-setup](../flutter-dio-repository-setup/SKILL.md).

## Modeling State with Sealed Classes

Use Dart 3 **sealed classes** for state, not a single mutable class with nullable fields. Sealed classes force exhaustive handling in the UI (a `switch` without a `default` won't compile if a case is missing) and make illegal states unrepresentable.

Extend `Equatable` (from the `equatable` package, already a `flutter_bloc` transitive dependency) so `BlocBuilder`/`BlocListener` correctly skip rebuilds when an emitted state is value-equal to the previous one — without this, list/object states can trigger extra rebuilds.

```dart
// product_state.dart
import 'package:equatable/equatable.dart';

sealed class ProductState extends Equatable {
  const ProductState();
  @override
  List<Object?> get props => [];
}

final class ProductInitial extends ProductState {
  const ProductInitial();
}

final class ProductLoading extends ProductState {
  const ProductLoading();
}

final class ProductSuccess extends ProductState {
  const ProductSuccess(this.products);
  final List<ProductModel> products;
  @override
  List<Object?> get props => [products];
}

final class ProductError extends ProductState {
  const ProductError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
```

Do **not** reach for `freezed`/`json_serializable`-style code generation for state classes — plain sealed classes + `Equatable` cover this without `build_runner` friction, matching this project's dependency policy (see [flutter-package-reference](../flutter-package-reference/SKILL.md)).

## BlocBuilder vs BlocListener vs BlocConsumer

- **`BlocBuilder`** — rebuilds UI (spinners, lists, cards). Must be **pure**: no navigation, no dialogs, no `SnackBar`s inside its `builder`.
- **`BlocListener`** — runs a side effect exactly once per emitted state: showing a `SnackBar`, popping a screen, pushing a route.
- **`BlocConsumer`** — use only when a single widget genuinely needs both rebuilding and a side effect; otherwise prefer a `BlocListener` wrapping a `BlocBuilder` (or a separate `BlocBuilder` lower in the tree) to keep each concern isolated.
- Use `buildWhen`/`listenWhen` when a Cubit's state carries fields the widget doesn't care about, to avoid redundant rebuilds/side effects.

```dart
BlocListener<AuthCubit, AuthState>(
  listener: (context, state) {
    switch (state) {
      case AuthFailure(:final message):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      case AuthSuccess():
        context.go('/home');
      case _:
        break;
    }
  },
  child: const LoginForm(),
)
```

Exhaustive rendering with a `switch` expression (compiler-enforced — add a new state variant and every `switch` that doesn't handle it fails to compile):

```dart
BlocBuilder<ProductCubit, ProductState>(
  builder: (context, state) => switch (state) {
    ProductInitial() || ProductLoading() => const Center(child: CircularProgressIndicator()),
    ProductSuccess(:final products) => ProductList(products: products),
    ProductError(:final message) => ErrorView(message: message),
  },
)
```

## Scoping Providers

Do not inject every Cubit at the top of the app with a giant `MultiBlocProvider` in `main.dart`. Only truly **global** Cubits go there (`ThemeCubit`, `AuthCubit`, `LocaleCubit`). Feature Cubits are provided exactly where the feature is routed, so they're created on navigation-in and disposed on navigation-out.

```dart
GoRoute(
  path: '/products',
  builder: (context, state) => BlocProvider(
    create: (context) => ProductCubit(getIt())..fetchProducts(),
    child: const ProductScreen(),
  ),
),
```

For a feature with multiple screens that must share one Cubit instance (e.g., a multi-step checkout flow), scope the `BlocProvider` around a parent `ShellRoute`/`StatefulShellBranch` instead of the app root — see [flutter-setup-declarative-routing](../flutter-setup-declarative-routing/SKILL.md).

## Naming Conventions

| Component | File | Class |
|---|---|---|
| Model | `product_model.dart` | `ProductModel` |
| Repository | `product_repository.dart` | `ProductRepository` |
| Cubit | `product_cubit.dart` | `ProductCubit` |
| State | `product_state.dart` | `ProductState` (sealed) |
| Screen/View | `product_screen.dart` | `ProductScreen` |
| Widget | `product_card.dart` | `ProductCard` |

Suggested folder layout per feature:

```
lib/features/product/
  data/
    product_model.dart
    product_repository.dart
  cubit/
    product_cubit.dart
    product_state.dart
  view/
    product_screen.dart
    widgets/
      product_card.dart
```

## Testing Cubits

Use the `bloc_test` package (`dev_dependency`) to assert emitted state sequences without standing up a widget tree:

```dart
blocTest<ProductCubit, ProductState>(
  'emits [Loading, Success] when fetchProducts succeeds',
  build: () => ProductCubit(mockRepository),
  act: (cubit) => cubit.fetchProducts(),
  expect: () => [const ProductLoading(), ProductSuccess(fakeProducts)],
);
```

Since Cubits only depend on a `Repository` interface (Rule 2), the Repository can be mocked (`mocktail`) with no HTTP or widget dependencies in the test.

## Code Review Checklist

- [ ] No `setState` mixed with Cubit-managed state (raw text-field controllers via `ValueNotifier`/`TextEditingController` are fine).
- [ ] No `Dio`/`http` inside any `*_cubit.dart`.
- [ ] No `import 'package:flutter/material.dart'` inside any `*_cubit.dart`, `*_state.dart`, or `*_repository.dart`.
- [ ] Every `switch (state)` in the UI is exhaustive (no stray `default:`/`_ =>` hiding a missed case).
- [ ] `BlocBuilder.builder` contains no navigation or dialogs; side effects are in a `BlocListener`.
- [ ] Feature Cubits are scoped at the route, not hoisted into the root `MultiBlocProvider`.
- [ ] Repository methods catch exceptions and never let a raw `DioException` reach the Cubit.
- [ ] State classes extend `Equatable` and override `props`.

## Examples

### End-to-end minimal feature

```dart
// data/product_model.dart
class ProductModel {
  const ProductModel({required this.id, required this.name});
  final String id;
  final String name;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

// data/product_repository.dart
class ProductRepository {
  ProductRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<ProductModel>> fetchProducts() async {
    final json = await _apiClient.get('/products'); // throws typed Failure on error
    return (json as List).map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}

// cubit/product_cubit.dart
class ProductCubit extends Cubit<ProductState> {
  ProductCubit(this._repository) : super(const ProductInitial());
  final ProductRepository _repository;

  Future<void> fetchProducts() async {
    emit(const ProductLoading());
    try {
      final products = await _repository.fetchProducts();
      emit(ProductSuccess(products));
    } on Failure catch (f) {
      emit(ProductError(f.message));
    }
  }
}
```

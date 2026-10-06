/// `NativeNavigationCubit` and its sealed states: turns
/// `NativeNavigationRepository` requests (`app.openNativeScreen`) into state
/// that `ShellScreen`'s `BlocListener` navigates on. Each request gets a new
/// sequence number so asking twice for the same screen still emits.
///
/// Why it exists: navigation is a side effect that belongs in a
/// `BlocListener` (flutter-cubit-architecture), not in a bridge handler.
/// Status: used — provided on the `/` route in `app_router.dart`.
library;

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/native_navigation_repository.dart';

sealed class NativeNavigationState extends Equatable {
  const NativeNavigationState();
  @override
  List<Object?> get props => [];
}

final class NativeNavigationIdle extends NativeNavigationState {
  const NativeNavigationIdle();
}

final class NativeNavigationRequested extends NativeNavigationState {
  const NativeNavigationRequested(this.screen, this.sequence);
  final NativeScreen screen;
  final int sequence;

  @override
  List<Object?> get props => [screen, sequence];
}

class NativeNavigationCubit extends Cubit<NativeNavigationState> {
  NativeNavigationCubit(NativeNavigationRepository repository) : super(const NativeNavigationIdle()) {
    _subscription = repository.requests.listen((screen) => emit(NativeNavigationRequested(screen, ++_sequence)));
  }

  late final StreamSubscription<NativeScreen> _subscription;
  int _sequence = 0;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

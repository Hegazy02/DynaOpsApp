/// `LocaleCubit`: the one root-level Cubit. Emits the `Locale` of the
/// language the rep picked in Angular (`lang` from `auth.setSession`), or
/// null to follow the OS until a session exists.
///
/// Why it exists: native screens (dialogs, loading/error views, later the
/// walkthrough) must appear in the same language as the web app.
/// Status: used — provided in `app.dart` and fed to `MaterialApp.locale`.
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/data/session_change_model.dart';
import '../../auth/data/session_repository.dart';

/// Root-level Cubit: native screens follow the language the rep picked in
/// Angular (`lang` from `auth.setSession`). Null falls back to the OS locale.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit(SessionRepository session) : super(_localeOf(session.current?.lang)) {
    _subscription = session.changes.listen((change) {
      if (change is SessionAdopted) emit(_localeOf(change.session.lang));
    });
  }

  late final StreamSubscription<SessionChange> _subscription;

  static Locale? _localeOf(String? lang) => lang == null ? null : Locale(lang);

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

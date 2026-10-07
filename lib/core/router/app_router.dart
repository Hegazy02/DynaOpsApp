/// `createAppRouter`: the go_router. `/` is the shell (fresh `ShellCubit` and
/// `NativeNavigationCubit`), `/permissions` the mandatory permission
/// walkthrough (`PermissionsCubit`), `/diagnostics` the support screen
/// (`DiagnosticsCubit`), `/requests` the request inspector
/// (`RequestInspectorCubit`). `PermissionGate` sends every other route to
/// `/permissions` until tracking has all it needs; unknown paths go to `/`.
///
/// Why it exists: each feature Cubit is scoped to its route
/// (flutter-cubit-architecture) rather than a root `MultiBlocProvider`, and
/// the permission rule is enforced once, here.
/// Status: used — created by `app.dart`.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/diagnostics/cubit/diagnostics_cubit.dart';
import '../../features/diagnostics/view/diagnostics_screen.dart';
import '../../features/permissions/cubit/permissions_cubit.dart';
import '../../features/permissions/view/permission_walkthrough_screen.dart';
import '../../features/request_inspector/cubit/request_inspector_cubit.dart';
import '../../features/request_inspector/view/request_inspector_screen.dart';
import '../../features/shell/cubit/native_navigation_cubit.dart';
import '../../features/shell/cubit/shell_cubit.dart';
import '../../features/shell/view/shell_screen.dart';
import '../config/app_config.dart';
import '../di/service_locator.dart';
import 'permission_gate.dart';

const _routes = {'/', '/permissions', '/diagnostics', '/requests'};

GoRouter createAppRouter(PermissionGate gate) => GoRouter(
      refreshListenable: gate,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<ShellCubit>()..start()),
              BlocProvider(create: (_) => getIt<NativeNavigationCubit>()),
            ],
            child: ShellScreen(showRequestInspector: getIt<AppConfig>().requestInspector),
          ),
        ),
        GoRoute(
          path: '/permissions',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<PermissionsCubit>()..load(),
            child: const PermissionWalkthroughScreen(),
          ),
        ),
        GoRoute(
          path: '/diagnostics',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<DiagnosticsCubit>()..load(),
            child: const DiagnosticsScreen(),
          ),
        ),
        GoRoute(
          path: '/requests',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<RequestInspectorCubit>()..load(),
            child: const RequestInspectorScreen(),
          ),
        ),
      ],
      redirect: (context, state) async {
        final requested = state.uri.path;
        // Unknown deep links fall back to the shell rather than an error page.
        final path = _routes.contains(requested) ? requested : '/';
        final gated = await gate.redirect(path);
        if (gated != null) return gated;
        return path == requested ? null : path;
      },
    );

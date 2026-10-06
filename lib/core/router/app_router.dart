/// `createAppRouter`: the go_router. `/` is the shell (fresh `ShellCubit`,
/// `TrackingCubit` and `NativeNavigationCubit`), `/permissions` the native
/// walkthrough (`PermissionsCubit`), `/diagnostics` the support screen
/// (`DiagnosticsCubit`); every unknown path redirects to `/`.
///
/// Why it exists: each feature Cubit is scoped to its route
/// (flutter-cubit-architecture) rather than a root `MultiBlocProvider`.
/// Status: used — created by `app.dart`.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/diagnostics/cubit/diagnostics_cubit.dart';
import '../../features/diagnostics/view/diagnostics_screen.dart';
import '../../features/permissions/cubit/permissions_cubit.dart';
import '../../features/permissions/view/permission_walkthrough_screen.dart';
import '../../features/shell/cubit/native_navigation_cubit.dart';
import '../../features/shell/cubit/shell_cubit.dart';
import '../../features/shell/view/shell_screen.dart';
import '../../features/tracking/cubit/tracking_cubit.dart';
import '../di/service_locator.dart';

const _routes = {'/', '/permissions', '/diagnostics'};

GoRouter createAppRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => getIt<ShellCubit>()..start()),
              BlocProvider(create: (_) => getIt<TrackingCubit>()..start()),
              BlocProvider(create: (_) => getIt<NativeNavigationCubit>()),
            ],
            child: const ShellScreen(),
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
      ],
      // Unknown deep links fall back to the shell rather than an error page.
      redirect: (context, state) => _routes.contains(state.uri.path) ? null : '/',
    );

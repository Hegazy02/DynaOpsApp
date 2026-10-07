/// `PermissionWalkthroughScreen`: the mandatory, localised walkthrough (§13)
/// — one `PermissionStepCard` per step with progress, a note that the app
/// needs all of them, the Play-Store background-location disclosure,
/// maker-specific guidance, and a link to diagnostics. Required steps have no
/// "Next" and no back arrow; system back leaves the app while one is missing.
/// Re-checks when the rep returns from Settings (and the Cubit on every status
/// change, e.g. the Location switch) and closes itself (to the shell) when
/// everything is in place.
///
/// Why it exists: Android only lets an app ask for "all the time" location
/// and battery exemption with an explanation first; Angular cannot do this.
/// Status: used — mounted on `/permissions`; the router's `PermissionGate`
/// sends the rep here whenever a required permission is missing, and Angular
/// can open it with `app.openNativeScreen`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/feedback/loading_overlay.dart';
import '../cubit/permissions_cubit.dart';
import '../cubit/permissions_state.dart';
import '../data/oem_brand.dart';
import 'widgets/permission_step_card.dart';

class PermissionWalkthroughScreen extends StatefulWidget {
  const PermissionWalkthroughScreen({super.key});

  @override
  State<PermissionWalkthroughScreen> createState() => _PermissionWalkthroughScreenState();
}

class _PermissionWalkthroughScreenState extends State<PermissionWalkthroughScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => context.read<PermissionsCubit>().recheck());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _close(BuildContext context) => context.canPop() ? context.pop() : context.go('/');

  /// Back can never get around the walkthrough: while a permission is missing
  /// it leaves the app; once everything is granted it closes the screen.
  void _onBack(BuildContext context) {
    final state = context.read<PermissionsCubit>().state;
    if (state is PermissionsFinished ||
        (state is PermissionsStepShown && state.step == WalkthroughStep.oem)) {
      _close(context);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<PermissionsCubit, PermissionsState>(
      listener: (context, state) {
        if (state is PermissionsFinished) _close(context);
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack(context);
        },
        child: _scaffold(l10n),
      ),
    );
  }

  Widget _scaffold(AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.permissionsTitle), automaticallyImplyLeading: false),
      body: SafeArea(
        child: BlocBuilder<PermissionsCubit, PermissionsState>(
          builder: (context, state) => switch (state) {
            PermissionsLoading() || PermissionsFinished() => const LoadingOverlay(),
            PermissionsStepShown() => _StepView(state: state),
          },
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.state});
  final PermissionsStepShown state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<PermissionsCubit>();
    final (icon, title, body) = _content(l10n);
    final isHint = state.step == WalkthroughStep.oem;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Text(l10n.permissionsStepCounter(state.index, state.total)),
              const SizedBox(height: 8),
              Text(
                l10n.permissionsRequiredNote,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PermissionStepCard(
                icon: icon,
                title: title,
                body: body,
                primaryLabel: switch (state.step) {
                  WalkthroughStep.locationService => l10n.permissionTurnOnLocation,
                  _ when state.needsSettings || isHint => l10n.permissionOpenSettings,
                  _ => l10n.permissionAllow,
                },
                onPrimary: cubit.allow,
                // Only the maker hint can be skipped; the required steps cannot.
                nextLabel: isHint ? l10n.permissionDone : null,
                onNext: isHint ? cubit.skipHint : null,
                busy: state.busy,
              ),
              const SizedBox(height: 24),
              TextButton(onPressed: () => context.push('/diagnostics'), child: Text(l10n.openDiagnostics)),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String, String) _content(AppLocalizations l10n) => switch (state.step) {
        WalkthroughStep.location => (Icons.location_on_outlined, l10n.stepLocationTitle, l10n.stepLocationBody),
        WalkthroughStep.preciseLocation =>
          (Icons.my_location_outlined, l10n.stepPreciseTitle, l10n.stepPreciseBody),
        WalkthroughStep.backgroundLocation =>
          (Icons.share_location_outlined, l10n.stepBackgroundTitle, l10n.stepBackgroundBody),
        WalkthroughStep.locationService =>
          (Icons.location_off_outlined, l10n.stepLocationServiceTitle, l10n.stepLocationServiceBody),
        WalkthroughStep.notifications =>
          (Icons.notifications_outlined, l10n.stepNotificationsTitle, l10n.stepNotificationsBody),
        WalkthroughStep.battery => (Icons.battery_saver_outlined, l10n.stepBatteryTitle, l10n.stepBatteryBody),
        WalkthroughStep.oem => (Icons.settings_suggest_outlined, l10n.stepOemTitle, _oemText(l10n)),
      };

  String _oemText(AppLocalizations l10n) => switch (state.oem) {
        OemBrand.samsung => l10n.oemSamsung,
        OemBrand.xiaomi => l10n.oemXiaomi,
        OemBrand.huawei => l10n.oemHuawei,
        OemBrand.oppo => l10n.oemOppo,
        OemBrand.vivo || null => l10n.oemVivo,
      };
}

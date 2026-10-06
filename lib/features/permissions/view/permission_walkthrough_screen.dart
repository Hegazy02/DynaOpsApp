/// `PermissionWalkthroughScreen`: the native, localised walkthrough (§13)
/// — one `PermissionStepCard` per step with progress, the Play-Store
/// background-location disclosure, maker-specific guidance, and a link to
/// diagnostics. Re-checks when the rep returns from the settings screen and
/// closes itself when the walkthrough finishes.
///
/// Why it exists: Android only lets an app ask for "all the time" location
/// and battery exemption with an explanation first; Angular cannot do this.
/// Status: used — mounted on `/permissions` by `app_router.dart`, opened from
/// `ShellScreen` (prompt or `app.openNativeScreen`).
library;

import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<PermissionsCubit, PermissionsState>(
      listener: (context, state) {
        if (state is PermissionsFinished) _close(context);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.permissionsTitle)),
        body: SafeArea(
          child: BlocBuilder<PermissionsCubit, PermissionsState>(
            builder: (context, state) => switch (state) {
              PermissionsLoading() || PermissionsFinished() => const LoadingOverlay(),
              PermissionsStepShown() => _StepView(state: state),
            },
          ),
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
    final isLast = state.index == state.total;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Text(l10n.permissionsStepCounter(state.index, state.total)),
              const SizedBox(height: 24),
              PermissionStepCard(
                icon: icon,
                title: title,
                body: body,
                primaryLabel: state.needsSettings || state.step == WalkthroughStep.oem
                    ? l10n.permissionOpenSettings
                    : l10n.permissionAllow,
                onPrimary: cubit.allow,
                nextLabel: isLast ? l10n.permissionDone : l10n.permissionNext,
                onNext: cubit.next,
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
        WalkthroughStep.backgroundLocation =>
          (Icons.share_location_outlined, l10n.stepBackgroundTitle, l10n.stepBackgroundBody),
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

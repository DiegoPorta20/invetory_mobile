import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

/// Opens a rounded bottom sheet above the tab bar with the shared motion curve.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.brand950.withValues(alpha: 0.42),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 420),
      reverseDuration: Duration(milliseconds: 260),
      curve: AppMotion.ease,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: builder,
  );
}

/// Standard sheet layout: grab handle, title, scrolling body and a pinned footer.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
    this.padBody = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool padBody;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final textTheme = Theme.of(context).textTheme;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          boxShadow: AppShadows.lifted,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.slate500),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: padBody
                      ? const EdgeInsets.fromLTRB(22, 8, 22, 12)
                      : EdgeInsets.zero,
                  child: child,
                ),
              ),
              if (footer != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cancel + primary action row used in the footer of form sheets.
class SheetActions extends StatelessWidget {
  const SheetActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.secondaryLabel = 'Cancelar',
    this.onSecondary,
    this.danger = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool loading;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: secondaryLabel,
            variant: ButtonVariant.secondary,
            onPressed: loading
                ? null
                : (onSecondary ?? () => Navigator.of(context).maybePop()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AppButton(
            label: primaryLabel,
            variant: danger ? ButtonVariant.danger : ButtonVariant.primary,
            loading: loading,
            onPressed: onPrimary,
          ),
        ),
      ],
    );
  }
}

/// Confirmation dialog with the shared pop-in animation. Resolves to true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool danger = false,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: AppColors.brand950.withValues(alpha: 0.42),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: AppColors.surface,
          elevation: 0,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.lifted,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.slate600),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: cancelLabel,
                        variant: ButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: confirmLabel,
                        variant:
                            danger ? ButtonVariant.danger : ButtonVariant.primary,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.ease);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

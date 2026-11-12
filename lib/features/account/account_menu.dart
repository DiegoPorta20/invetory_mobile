import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/enums.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/sheets.dart';

/// Round initials avatar; opens the account sheet.
class AccountAvatarButton extends ConsumerWidget {
  const AccountAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Pressable(
      onTap: () => showAppSheet<void>(context, builder: (_) => const _AccountSheet()),
      haptic: true,
      semanticLabel: 'Cuenta',
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brand100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x1A101A38), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          initialsOf(user?.name ?? ''),
          style: TextStyle(
            fontFamily: 'Urbanist',
            fontSize: 15,
            color: AppColors.brand700,
          ).w(750),
        ),
      ),
    );
  }
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final textTheme = Theme.of(context).textTheme;

    Widget item(IconData icon, String label, VoidCallback onTap, {Color? color}) {
      return Pressable(
        onTap: onTap,
        scale: 0.985,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color ?? AppColors.slate600),
              const SizedBox(width: 14),
              Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  color: color ?? AppColors.slate800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SheetFrame(
      title: user?.name ?? 'Cuenta',
      subtitle: '${user?.email ?? ''} · ${roleLabels[user?.role] ?? ''}',
      child: Column(
        children: [
          item(Icons.lock_outline_rounded, 'Cambiar contraseña', () {
            Navigator.of(context).pop();
            context.push('/account');
          }),
          const Divider(),
          item(Icons.logout_rounded, 'Cerrar sesión', () async {
            Navigator.of(context).pop();
            await ref.read(authControllerProvider.notifier).logout();
          }, color: AppColors.rose600),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/client_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';

/// Shown while the stored session is being restored.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);
    final logo = branding.logoBytes;
    return Scaffold(
      backgroundColor: AppColors.brand900,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: AppMotion.ease,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.brand100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: logo != null
                    ? Image.memory(logo, fit: BoxFit.contain)
                    : Icon(Icons.inventory_2_rounded, size: 38, color: AppColors.brand900),
              ),
              const SizedBox(height: 18),
              Text(
                branding.appName,
                style: const TextStyle(
                  fontFamily: 'Urbanist',
                  fontSize: 26,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ).w(650),
              ),
              if (branding.tagline != null) ...[
                const SizedBox(height: 4),
                Text(
                  branding.tagline!,
                  style: TextStyle(
                    fontFamily: 'Urbanist',
                    fontSize: 14,
                    color: AppColors.brand300,
                  ).w(500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
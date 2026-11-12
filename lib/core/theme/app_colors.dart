import 'package:flutter/material.dart';

/// Palette taken from the web design system (`apps/web/src/styles.css`).
/// The color scales a company chooses in config_inventory. Until one is applied, the default
/// palette (the original navy and cyan) is used.
class BrandPalette {
  const BrandPalette({required this.primary, required this.accent});

  /// Shades 50-950; the company's main color is shade 600.
  final Map<int, Color> primary;

  /// Shades 50, 100, 400, 500, 600; the company's accent is shade 500.
  final Map<int, Color> accent;

  static const defaults = BrandPalette(
    primary: {
      50: Color(0xFFF0F4FD),
      100: Color(0xFFE2E9FC),
      200: Color(0xFFC4D0EE),
      300: Color(0xFF9FB1DE),
      400: Color(0xFF6D86C9),
      500: Color(0xFF3A58AD),
      600: Color(0xFF273F85),
      700: Color(0xFF1F3269),
      800: Color(0xFF182750),
      900: Color(0xFF101A38),
      950: Color(0xFF081026),
    },
    accent: {
      50: Color(0xFFE6F8FC),
      100: Color(0xFFC2EEF8),
      400: Color(0xFF27C3E0),
      500: Color(0xFF01ABCE),
      600: Color(0xFF0190AE),
    },
  );

  static Color? _parse(Object? value) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
  }

  static Map<int, Color> _scale(Object? json, Map<int, Color> fallback) {
    if (json is! Map) return fallback;
    final result = <int, Color>{...fallback};
    json.forEach((key, value) {
      final shade = int.tryParse('$key');
      final color = _parse(value);
      if (shade != null && color != null) result[shade] = color;
    });
    return result;
  }

  /// Reads `{ primary: { "600": "#273f85", ... }, accent: { ... } }`; anything missing keeps the default.
  factory BrandPalette.fromJson(Object? json) {
    if (json is! Map) return defaults;
    return BrandPalette(
      primary: _scale(json['primary'], defaults.primary),
      accent: _scale(json['accent'], defaults.accent),
    );
  }
}

/// Palette taken from the web design system (`apps/web/src/styles.css`); brand and accent follow
/// the signed-in company.
abstract final class AppColors {
  static BrandPalette _palette = BrandPalette.defaults;

  static void applyPalette(BrandPalette palette) => _palette = palette;

  static Color get brand50 => _palette.primary[50]!;
  static Color get brand100 => _palette.primary[100]!;
  static Color get brand200 => _palette.primary[200]!;
  static Color get brand300 => _palette.primary[300]!;
  static Color get brand400 => _palette.primary[400]!;
  static Color get brand500 => _palette.primary[500]!;
  static Color get brand600 => _palette.primary[600]!;
  static Color get brand700 => _palette.primary[700]!;
  static Color get brand800 => _palette.primary[800]!;
  static Color get brand900 => _palette.primary[900]!;
  static Color get brand950 => _palette.primary[950]!;

  static Color get accent400 => _palette.accent[400]!;
  static Color get accent500 => _palette.accent[500]!;
  static const page = Color(0xFFECEFF5);
  static const surface = Color(0xFFFCFDFE);
  static const line = Color(0x17101A38);
  static const lineStrong = Color(0x29101A38);
  static const well = Color(0x0F101A38);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  static const emerald50 = Color(0xFFECFDF5);
  static const emerald500 = Color(0xFF10B981);
  static const emerald700 = Color(0xFF047857);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber700 = Color(0xFFB45309);
  static const rose50 = Color(0xFFFFF1F2);
  static const rose400 = Color(0xFFFB7185);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const rose700 = Color(0xFFBE123C);
  static const sky50 = Color(0xFFF0F9FF);
  static const sky600 = Color(0xFF0284C7);
  static const sky700 = Color(0xFF0369A1);

  static const sideDim = Color(0x9EE9EEFC);
}

/// Semantic tones shared by badges and status indicators.
enum Tone { neutral, success, warning, danger, info, brand }

extension ToneColors on Tone {
  Color get color => switch (this) {
        Tone.neutral => AppColors.slate600,
        Tone.success => AppColors.emerald700,
        Tone.warning => AppColors.amber700,
        Tone.danger => AppColors.rose700,
        Tone.info => AppColors.sky700,
        Tone.brand => AppColors.brand600,
      };

  /// Soft tinted background (14% of the tone colour), like the web `.badge`.
  Color get tint => color.withValues(alpha: 0.14);
}

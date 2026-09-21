import 'package:flutter/material.dart' show Color;
import '../models/banner.dart';

/// Resolved theme for the general Notice/consent banner (BannerUI and its
/// children) — background, text, and button colors plus font family/size,
/// all sourced from the banner's "Common Appearance" settings. Uses the
/// same light-mode defaults truKIT-NPM's own `variables.css`/
/// `TruConsentModal.jsx` fall back to when a field isn't configured.
class BannerTheme {
  final Color background;
  final Color text;
  final Color textMuted;
  final Color button;
  final Color buttonText;
  final Color border;
  final String? fontFamily;
  final double fontSize;
  /// Disclaimer box colors — truKIT-NPM's --banner-info-bg/border/text are
  /// fixed light/dark presets (variables.css), never admin-configurable and
  /// never derived from settings; there is no light/dark toggle prop in this
  /// SDK's public API to key off of the same way, so these are derived from
  /// whether the configured background is dark or light instead, picking
  /// whichever of NPM's two fixed presets actually contrasts.
  final Color infoBg;
  final Color infoBorder;
  final Color infoText;

  const BannerTheme({
    required this.background,
    required this.text,
    required this.textMuted,
    required this.button,
    required this.buttonText,
    required this.border,
    this.fontFamily,
    required this.fontSize,
    this.infoBg = const Color(0xFFEFF6FF),
    this.infoBorder = const Color(0xFFBFDBFE),
    this.infoText = const Color(0xFF1E40AF),
  });

  static Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceFirst('#', '');
      final full = clean.length == 6 ? 'FF$clean' : clean;
      return Color(int.parse(full, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// Mirrors truKIT-react-native's isDarkColor / truKIT-NPM's _isDarkColor.
  static bool _isDarkColor(Color color) {
    final r = (color.r * 255.0).round();
    final g = (color.g * 255.0).round();
    final b = (color.b * 255.0).round();
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5;
  }

  factory BannerTheme.from(BannerSettings? settings) {
    final s = settings;
    final button = _parseColor(
      s?.buttonColor,
      _parseColor(s?.primaryColor, const Color(0xFF3B82F6)),
    );
    double fontSize = 16;
    final rawFontSize = s?.fontSize;
    if (rawFontSize != null) {
      final parsed = double.tryParse(rawFontSize.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null && parsed > 0) fontSize = parsed;
    }
    // The admin dashboard's "Background Color" field is actually
    // primaryColor (see AppearanceSettingsForm.tsx's
    // `<ColorField id="primary_color" label="Background Color" .../>`) —
    // there is no `backgroundColor`/`background_color` column anywhere in
    // the API. Prioritize primaryColor; backgroundColor is kept only as a
    // defensive fallback in case a caller ever sends that key directly.
    final background = _parseColor(
      s?.primaryColor,
      _parseColor(s?.backgroundColor, const Color(0xFFFFFFFF)),
    );
    final dark = _isDarkColor(background);
    return BannerTheme(
      background: background,
      text: _parseColor(s?.primaryTextColor, const Color(0xFF111827)),
      textMuted: _parseColor(s?.secondaryTextColor, const Color(0xFF6B7280)),
      button: button,
      buttonText: _parseColor(s?.buttonTextColor, const Color(0xFFFFFFFF)),
      border: const Color(0xFFE5E7EB),
      fontFamily: s?.fontType,
      fontSize: fontSize,
      // truKIT-NPM's variables.css fixed light/dark presets for the disclaimer box.
      infoBg: dark ? const Color(0xFF0A0C10) : const Color(0xFFEFF6FF),
      infoBorder: dark ? const Color(0xFF1E293B) : const Color(0xFFBFDBFE),
      infoText: dark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF),
    );
  }
}

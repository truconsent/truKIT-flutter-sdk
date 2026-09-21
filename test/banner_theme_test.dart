import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/models/banner.dart';
import 'package:truconsent_consent_notice_flutter/src/services/banner_theme.dart';

void main() {
  group('BannerTheme.from', () {
    test('uses light-mode defaults when settings is null', () {
      final theme = BannerTheme.from(null);
      expect(theme.background, const Color(0xFFFFFFFF));
      expect(theme.text, const Color(0xFF111827));
      expect(theme.textMuted, const Color(0xFF6B7280));
      expect(theme.button, const Color(0xFF3B82F6));
      expect(theme.buttonText, const Color(0xFFFFFFFF));
      expect(theme.border, const Color(0xFFE5E7EB));
      expect(theme.fontFamily, isNull);
      expect(theme.fontSize, 16);
    });

    test('reads all Common Appearance fields when present', () {
      final settings = BannerSettings(
        backgroundColor: '#1f2937',
        primaryTextColor: '#f9fafb',
        secondaryTextColor: '#d1d5db',
        buttonColor: '#22c55e',
        buttonTextColor: '#000000',
        fontType: 'Poppins',
        fontSize: '18',
      );
      final theme = BannerTheme.from(settings);
      expect(theme.background, const Color(0xFF1F2937));
      expect(theme.text, const Color(0xFFF9FAFB));
      expect(theme.textMuted, const Color(0xFFD1D5DB));
      expect(theme.button, const Color(0xFF22C55E));
      expect(theme.buttonText, const Color(0xFF000000));
      expect(theme.fontFamily, 'Poppins');
      expect(theme.fontSize, 18);
    });

    test('background reads primaryColor — the actual "Background Color" API field', () {
      // The admin dashboard's "Background Color" field maps to primaryColor,
      // not backgroundColor (no such API field exists) — see
      // AppearanceSettingsForm.tsx's `<ColorField id="primary_color"
      // label="Background Color" .../>`.
      final settings = BannerSettings(primaryColor: '#000000');
      final theme = BannerTheme.from(settings);
      expect(theme.background, const Color(0xFF000000));
    });

    test('primaryColor takes priority over backgroundColor for background', () {
      final settings = BannerSettings(
        primaryColor: '#000000',
        backgroundColor: '#1f2937',
      );
      final theme = BannerTheme.from(settings);
      expect(theme.background, const Color(0xFF000000));
    });

    test('falls back button color to primaryColor when buttonColor absent', () {
      final settings = BannerSettings(primaryColor: '#9333ea');
      final theme = BannerTheme.from(settings);
      expect(theme.button, const Color(0xFF9333EA));
    });

    test('buttonColor takes priority over primaryColor', () {
      final settings = BannerSettings(
        buttonColor: '#22c55e',
        primaryColor: '#9333ea',
      );
      final theme = BannerTheme.from(settings);
      expect(theme.button, const Color(0xFF22C55E));
    });

    test('parses font_size with units (e.g. "16px")', () {
      final settings = BannerSettings(fontSize: '16px');
      final theme = BannerTheme.from(settings);
      expect(theme.fontSize, 16);
    });

    test('falls back to 16 for invalid font_size', () {
      final settings = BannerSettings(fontSize: 'not-a-number');
      final theme = BannerTheme.from(settings);
      expect(theme.fontSize, 16);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'locales/en.dart';
import 'locales/ta.dart';
import 'locales/hi.dart';

/// Internationalization (i18n) utility for the TruConsent SDK.
///
/// Provides translation support for multiple languages (English, Hindi, Tamil).
/// Manages locale settings and provides translation methods.
///
/// Example:
/// ```dart
/// I18n.setLocale(const Locale('hi'));
/// final text = I18n.translate('consent.banner.title');
/// ```
class I18n {
  static Locale _currentLocale = const Locale('en');
  static final Map<String, Map<String, String>> _translations = {
    'en': enTranslations,
    'ta': taTranslations,
    'hi': hiTranslations,
  };

  /// Notifies listeners (e.g. `ValueListenableBuilder`) whenever the active
  /// locale changes, so widgets that call [translate]/[t] during build can
  /// rebuild themselves in response to [setLocale].
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier(_currentLocale);

  /// Gets the current locale
  static Locale get currentLocale => _currentLocale;

  /// Sets the current locale for translations.
  ///
  /// Changes the active language for all subsequent translation calls and
  /// notifies [localeNotifier] listeners so the UI can update.
  ///
  /// Example:
  /// ```dart
  /// I18n.setLocale(const Locale('hi')); // Switch to Hindi
  /// ```
  static void setLocale(Locale locale) {
    _currentLocale = locale;
    Intl.defaultLocale = locale.languageCode;
    localeNotifier.value = locale;
  }

  /// Translates a key to the current locale's text.
  ///
  /// Returns the translated text, or the key itself if translation is not found.
  /// Supports parameter substitution using `{{paramName}}` syntax.
  ///
  /// [lang] overrides the active locale for this call only — needed by
  /// snapshot-driven banners, which report the selected language via a
  /// callback instead of ever calling [setLocale] (see
  /// `ModernBannerHeader`'s `_onSelectLanguage`), so [_currentLocale] would
  /// otherwise always stay 'en'.
  ///
  /// Example:
  /// ```dart
  /// final text = I18n.translate('consent.banner.title');
  /// final withParams = I18n.translate('welcome', params: {'name': 'John'});
  /// ```
  static String translate(String key, {Map<String, String>? params, String? lang}) {
    final translations = _translations[lang ?? _currentLocale.languageCode] ?? enTranslations;
    String text = translations[key] ?? enTranslations[key] ?? key;

    // Replace parameters
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{{$key}}', value);
      });
    }

    return text;
  }

  /// Short alias for [translate].
  ///
  /// Example:
  /// ```dart
  /// final text = I18n.t('consent.banner.title');
  /// ```
  static String t(String key, {Map<String, String>? params, String? lang}) {
    return translate(key, params: params, lang: lang);
  }
}


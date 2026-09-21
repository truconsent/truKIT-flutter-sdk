import '../models/banner.dart';

/// Snapshot-driven translation for dynamic (server-supplied) banner content —
/// purpose names/descriptions, banner title/disclaimer/footer. This is
/// distinct from the static locale bundles in `utils/i18n.dart` (Accept All,
/// etc.): the snapshot translates whatever text the admin actually
/// configured, in whatever languages they configured, rather than a fixed
/// built-in set.
///
/// Mirrors truKIT-NPM's `src/runtime/TranslationContext.jsx` algorithm
/// exactly (exact match → case-insensitive → 60-char-prefix match for long
/// strings like footer HTML).

class LanguageOptions {
  final List<String> availableLanguages;
  final Map<String, String> languageLabels;
  const LanguageOptions({required this.availableLanguages, required this.languageLabels});
}

LanguageOptions getAvailableLanguages(TranslationSnapshot? snapshot) {
  if (snapshot?.languages != null && snapshot!.languages!.isNotEmpty) {
    final labels = <String, String>{};
    for (final l in snapshot.languages!) {
      labels[l.code] = l.label;
    }
    final codes = snapshot.languages!.map((l) => l.code).toList();
    if (!codes.contains('en')) codes.insert(0, 'en');
    return LanguageOptions(availableLanguages: codes, languageLabels: labels);
  }

  final textMap = snapshot?.textMap;
  if (textMap == null || textMap.isEmpty) {
    return const LanguageOptions(availableLanguages: [], languageLabels: {});
  }
  final firstEntry = textMap.values.first;
  final snapshotLangs = firstEntry.keys.where((l) => l != 'en').toList();
  return LanguageOptions(availableLanguages: ['en', ...snapshotLangs], languageLabels: const {});
}

String _normalizeLongKey(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp('_blank', caseSensitive: false), 'blank').trim().toLowerCase();

/// Builds a `translate(text)` function bound to a specific snapshot/language.
/// Returns the identity function when there's no snapshot or the language is
/// 'en' (the snapshot's source language), matching the NPM SDK.
String Function(String) createTranslator(TranslationSnapshot? snapshot, String lang) {
  final textMap = snapshot?.textMap;
  if (lang.isEmpty || lang == 'en' || textMap == null || textMap.isEmpty) {
    return (text) => text;
  }

  final lowerCaseMap = <String, Map<String, String>>{};
  textMap.forEach((key, val) {
    lowerCaseMap[key.toLowerCase()] = val;
  });

  final prefixMap = <String, Map<String, String>>{};
  textMap.forEach((key, val) {
    if (key.length > 80) {
      final prefix = _normalizeLongKey(key).substring(0, 60.clamp(0, _normalizeLongKey(key).length));
      prefixMap.putIfAbsent(prefix, () => val);
    }
  });

  return (text) {
    if (text.isEmpty) return '';
    final exact = textMap[text]?[lang];
    if (exact != null && exact.isNotEmpty) return exact;
    final lower = lowerCaseMap[text.toLowerCase()]?[lang];
    if (lower != null && lower.isNotEmpty) return lower;
    if (text.length > 80) {
      final normalized = _normalizeLongKey(text);
      final prefix = normalized.substring(0, 60.clamp(0, normalized.length));
      final prefixVal = prefixMap[prefix]?[lang];
      if (prefixVal != null && prefixVal.isNotEmpty) return prefixVal;
    }
    return text;
  };
}

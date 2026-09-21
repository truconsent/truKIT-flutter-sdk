import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/models/banner.dart';
import 'package:truconsent_consent_notice_flutter/src/services/translation_snapshot.dart';

void main() {
  group('getAvailableLanguages', () {
    test('returns empty when snapshot is null', () {
      final result = getAvailableLanguages(null);
      expect(result.availableLanguages, isEmpty);
      expect(result.languageLabels, isEmpty);
    });

    test('prefers snapshot.languages when present, ensuring en is included', () {
      final snapshot = TranslationSnapshot(
        languages: [
          LanguageInfo(code: 'ta', label: 'Tamil'),
          LanguageInfo(code: 'hi', label: 'Hindi'),
        ],
      );
      final result = getAvailableLanguages(snapshot);
      expect(result.availableLanguages, ['en', 'ta', 'hi']);
      expect(result.languageLabels['ta'], 'Tamil');
      expect(result.languageLabels['hi'], 'Hindi');
    });

    test('does not duplicate en when already present in snapshot.languages', () {
      final snapshot = TranslationSnapshot(
        languages: [
          LanguageInfo(code: 'en', label: 'English'),
          LanguageInfo(code: 'fr', label: 'French'),
        ],
      );
      final result = getAvailableLanguages(snapshot);
      expect(result.availableLanguages, ['en', 'fr']);
    });

    test('derives languages from textMap when languages field absent', () {
      final snapshot = TranslationSnapshot(
        textMap: {
          'Accept All': {'en': 'Accept All', 'ta': 'அனைத்தையும் ஏற்கவும்'},
        },
      );
      final result = getAvailableLanguages(snapshot);
      expect(result.availableLanguages, ['en', 'ta']);
      expect(result.languageLabels, isEmpty);
    });

    test('returns empty when textMap is empty and no languages field', () {
      final snapshot = TranslationSnapshot(textMap: {});
      final result = getAvailableLanguages(snapshot);
      expect(result.availableLanguages, isEmpty);
    });
  });

  group('createTranslator', () {
    test('is identity when snapshot is null', () {
      final translate = createTranslator(null, 'ta');
      expect(translate('Accept All'), 'Accept All');
    });

    test('is identity when lang is "en"', () {
      final snapshot = TranslationSnapshot(
        textMap: {
          'Accept All': {'ta': 'அனைத்தையும் ஏற்கவும்'},
        },
      );
      final translate = createTranslator(snapshot, 'en');
      expect(translate('Accept All'), 'Accept All');
    });

    test('resolves exact match', () {
      final snapshot = TranslationSnapshot(
        textMap: {
          'Accept All': {'ta': 'அனைத்தையும் ஏற்கவும்'},
        },
      );
      final translate = createTranslator(snapshot, 'ta');
      expect(translate('Accept All'), 'அனைத்தையும் ஏற்கவும்');
    });

    test('falls back to case-insensitive match', () {
      final snapshot = TranslationSnapshot(
        textMap: {
          'Accept All': {'ta': 'அனைத்தையும் ஏற்கவும்'},
        },
      );
      final translate = createTranslator(snapshot, 'ta');
      expect(translate('accept all'), 'அனைத்தையும் ஏற்கவும்');
    });

    test('falls back to 60-char-prefix match for long strings', () {
      final longKey =
          'Review our Privacy Policy and Transparency Centre, DPO Details before proceeding with consent';
      final snapshot = TranslationSnapshot(
        textMap: {
          longKey: {'ta': 'மொழிபெயர்க்கப்பட்ட நீண்ட உரை'},
        },
      );
      final translate = createTranslator(snapshot, 'ta');
      // A slightly different long string sharing the same normalized 60-char prefix.
      final similarText = '$longKey extra trailing content that differs';
      expect(translate(similarText), 'மொழிபெயர்க்கப்பட்ட நீண்ட உரை');
    });

    test('returns original text when unmatched', () {
      final snapshot = TranslationSnapshot(
        textMap: {
          'Accept All': {'ta': 'அனைத்தையும் ஏற்கவும்'},
        },
      );
      final translate = createTranslator(snapshot, 'ta');
      expect(translate('Unrelated text'), 'Unrelated text');
    });

    test('handles empty string input', () {
      final snapshot = TranslationSnapshot(
        textMap: {
          'Accept All': {'ta': 'அனைத்தையும் ஏற்கவும்'},
        },
      );
      final translate = createTranslator(snapshot, 'ta');
      expect(translate(''), '');
    });
  });
}

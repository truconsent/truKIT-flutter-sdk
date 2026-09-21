import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/services/api_casing.dart';

void main() {
  group('withCasingAliases', () {
    test('adds a snake_case alias for every camelCase key', () {
      final result = withCasingAliases({
        'primaryColor': '#000000',
        'hCaseProceedButtonColor': '#22c55e',
      });
      expect(result['primary_color'], '#000000');
      expect(result['h_case_proceed_button_color'], '#22c55e');
      // Originals are preserved
      expect(result['primaryColor'], '#000000');
      expect(result['hCaseProceedButtonColor'], '#22c55e');
    });

    test('adds a camelCase alias for every snake_case key', () {
      final result = withCasingAliases({
        'primary_color': '#000000',
        'reject_all_color': '#dc2626',
      });
      expect(result['primaryColor'], '#000000');
      expect(result['rejectAllColor'], '#dc2626');
    });

    test('never overwrites an existing key in either casing', () {
      final result = withCasingAliases({
        'primaryColor': '#111111',
        'primary_color': '#222222',
      });
      expect(result['primaryColor'], '#111111');
      expect(result['primary_color'], '#222222');
    });

    test('returns an empty map for null', () {
      expect(withCasingAliases(null), <String, dynamic>{});
    });

    test('is a no-op for a key with no case variation (single word)', () {
      final result = withCasingAliases({'id': '123', 'version': 2});
      expect(result, {'id': '123', 'version': 2});
    });
  });

  group('withCasingAliasesList', () {
    test('applies withCasingAliases to every map item', () {
      final result = withCasingAliasesList([
        {'isMandatory': true},
        {'isMandatory': false},
      ]);
      expect(result[0]['is_mandatory'], true);
      expect(result[1]['is_mandatory'], false);
    });

    test('returns an empty list for null', () {
      expect(withCasingAliasesList(null), <dynamic>[]);
    });
  });
}

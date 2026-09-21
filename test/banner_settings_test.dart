import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/models/banner.dart';

void main() {
  group('BannerSettings.fromJson — per-notice Global Settings button overrides', () {
    test('reads reject_all_color/reject_all_text (snake_case)', () {
      final settings = BannerSettings.fromJson({
        'reject_all_color': '#dc2626',
        'reject_all_text': 'Decline',
      });
      expect(settings.rejectAllColor, '#dc2626');
      expect(settings.rejectAllText, 'Decline');
    });

    test('reads rejectAllColor/rejectAllText (camelCase fallback)', () {
      final settings = BannerSettings.fromJson({
        'rejectAllColor': '#dc2626',
        'rejectAllText': 'Decline',
      });
      expect(settings.rejectAllColor, '#dc2626');
      expect(settings.rejectAllText, 'Decline');
    });

    test('reads only_necessary_color/only_necessary_text', () {
      final settings = BannerSettings.fromJson({
        'only_necessary_color': '#f97316',
        'only_necessary_text': 'Necessary Only',
      });
      expect(settings.onlyNecessaryColor, '#f97316');
      expect(settings.onlyNecessaryText, 'Necessary Only');
    });

    test('reads accept_all_text', () {
      final settings = BannerSettings.fromJson({'accept_all_text': 'I Consent'});
      expect(settings.acceptAllText, 'I Consent');
    });

    test('reads existing h_case_proceed_button_color/h_case_back_button_color', () {
      final settings = BannerSettings.fromJson({
        'h_case_proceed_button_color': '#22c55e',
        'h_case_back_button_color': '#f3f4f6',
      });
      expect(settings.hCaseProceedButtonColor, '#22c55e');
      expect(settings.hCaseBackButtonColor, '#f3f4f6');
    });

    test('all new fields are null when absent', () {
      final settings = BannerSettings.fromJson({});
      expect(settings.rejectAllColor, isNull);
      expect(settings.rejectAllText, isNull);
      expect(settings.onlyNecessaryColor, isNull);
      expect(settings.onlyNecessaryText, isNull);
      expect(settings.acceptAllText, isNull);
    });
  });
}

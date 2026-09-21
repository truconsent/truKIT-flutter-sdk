import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/services/template_registry.dart';

void main() {
  group('resolveTemplateKey', () {
    test('maps each known key to its template', () {
      expect(resolveTemplateKey('preferences_modal'), BannerTemplateKey.preferencesModal);
      expect(resolveTemplateKey('floating_card'), BannerTemplateKey.floatingCard);
      expect(resolveTemplateKey('notice_only'), BannerTemplateKey.noticeOnly);
      expect(resolveTemplateKey('inline_single_row'), BannerTemplateKey.inlineSingleRow);
      expect(resolveTemplateKey('general_compact_list'), BannerTemplateKey.generalCompactList);
      expect(resolveTemplateKey('general_split_pane'), BannerTemplateKey.generalSplitPane);
      expect(resolveTemplateKey('tabbed_banner'), BannerTemplateKey.tabbedBanner);
    });

    test('collapses center_modal into tabbedBanner, mirroring the NPM SDK', () {
      expect(resolveTemplateKey('center_modal'), BannerTemplateKey.tabbedBanner);
    });

    test('falls back to tabbedBanner for null/unknown keys', () {
      expect(resolveTemplateKey(null), BannerTemplateKey.tabbedBanner);
      expect(resolveTemplateKey('something_unrecognized'), BannerTemplateKey.tabbedBanner);
    });

    test('falls back to floatingCard for cookie_consent banners with no explicit template', () {
      expect(
        resolveTemplateKey(null, consentType: 'cookie_consent'),
        BannerTemplateKey.floatingCard,
      );
    });

    test('an explicit template key overrides the cookie_consent default', () {
      expect(
        resolveTemplateKey('notice_only', consentType: 'cookie_consent'),
        BannerTemplateKey.noticeOnly,
      );
    });
  });
}

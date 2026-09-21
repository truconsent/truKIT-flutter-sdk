/// Confirms Banner.fromJson correctly parses a PURE camelCase response (the
/// real shape trukit-dev.truconsent.io returns — see api_casing.dart) once
/// normalized via withCasingAliases, mirroring what banner_service.dart's
/// fetchBanner does internally before calling Banner.fromJson.
import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/models/banner.dart';
import 'package:truconsent_consent_notice_flutter/src/services/api_casing.dart';

Map<String, dynamic> normalize(Map<String, dynamic> data) {
  final banner = withCasingAliases(data);
  final rawSettings = banner['banner_settings'] ?? banner['bannerSettings'];
  if (rawSettings is Map<String, dynamic>) {
    final settings = withCasingAliases(rawSettings);
    banner['banner_settings'] = settings;
    banner['bannerSettings'] = settings;
  }
  final rawPurposes = banner['purposes'];
  if (rawPurposes is List) {
    banner['purposes'] = rawPurposes.map((p) {
      if (p is! Map<String, dynamic>) return p;
      final purpose = withCasingAliases(p);
      for (final key in ['data_elements']) {
        if (purpose[key] is List) {
          purpose[key] = withCasingAliasesList(purpose[key] as List);
        }
      }
      return purpose;
    }).toList();
  }
  return banner;
}

void main() {
  test('parses a pure-camelCase banner response end-to-end', () {
    final camelCaseBanner = {
      'bannerId': 'CP-camel',
      'collectionPoint': 'CP-camel',
      'title': 'Camel Banner',
      'bannerSettings': {
        'primaryColor': '#000000',
        'buttonColor': '#95ff00',
        'rejectAllColor': '#dc2626',
        'onlyNecessaryColor': '#f97316',
        'hCaseProceedButtonColor': '#22c55e',
        'hCaseBackButtonColor': '#e3e8f2',
      },
      'purposes': [
        {
          'id': 'p1',
          'name': 'Purpose One',
          'description': 'desc',
          'isMandatory': true,
          'expiryPeriod': '365',
          'consented': 'pending',
          'dataElements': [
            {'id': 'de1', 'name': 'Email', 'displayId': 'DE001'}
          ],
        },
      ],
    };

    final banner = Banner.fromJson(normalize(camelCaseBanner));

    expect(banner.bannerId, 'CP-camel');
    expect(banner.bannerSettings?.primaryColor, '#000000');
    expect(banner.bannerSettings?.buttonColor, '#95ff00');
    expect(banner.bannerSettings?.rejectAllColor, '#dc2626');
    expect(banner.bannerSettings?.onlyNecessaryColor, '#f97316');
    expect(banner.bannerSettings?.hCaseProceedButtonColor, '#22c55e');
    expect(banner.bannerSettings?.hCaseBackButtonColor, '#e3e8f2');
    expect(banner.purposes.length, 1);
    expect(banner.purposes[0].isMandatory, true);
  });
}

/// Widget tests for BannerUI
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/banner_ui.dart';
import 'package:truconsent_consent_notice_flutter/src/models/banner.dart';

void main() {
  group('BannerUI', () {
    final testBanner = Banner(
      bannerId: 'test-banner',
      collectionPoint: 'test-cp',
      version: '1',
      title: 'Test Banner',
      expiryType: 'active',
      purposes: [
        Purpose(
          id: 'p1',
          name: 'Purpose 1',
          description: 'Test purpose',
          isMandatory: false,
          consented: 'declined',
          expiryPeriod: '1 Year',
        ),
      ],
    );

    testWidgets('should render banner with purposes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Production code (TruConsentModal) always wraps BannerUI in a
            // scrollable, bounded container; mirror that here so the banner's
            // natural (larger-than-viewport) content doesn't overflow.
            body: SingleChildScrollView(
              child: BannerUI(
                banner: testBanner,
                companyName: 'Test Company',
                onChangePurpose: (id, status) {},
                onRejectAll: () {},
                onConsentAll: () {},
                onAcceptSelected: () {},
                onAcceptMandatory: () {},
              ),
            ),
          ),
        ),
      );

      // Company name appears within the header title/footer text, not as an
      // exact standalone string (e.g. "Consent by Test Company").
      expect(
        find.textContaining('Test Company'),
        findsWidgets,
      );
    });

    testWidgets('should call onChangePurpose when purpose is toggled', (tester) async {
      String? toggledId;
      String? toggledStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BannerUI(
                banner: testBanner,
                companyName: 'Test Company',
                onChangePurpose: (id, status) {
                  toggledId = id;
                  toggledStatus = status;
                },
                onRejectAll: () {},
                onConsentAll: () {},
                onAcceptSelected: () {},
                onAcceptMandatory: () {},
              ),
            ),
          ),
        ),
      );

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pump();

      expect(toggledId, 'p1');
      expect(toggledStatus, 'accepted');
    });
  });
}


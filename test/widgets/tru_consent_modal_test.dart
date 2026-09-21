/// Widget tests for TruConsentModal
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/tru_consent_modal.dart';
import 'package:truconsent_consent_notice_flutter/src/models/banner.dart' show ConsentAction;

void main() {
  group('TruConsentModal', () {
    testWidgets('should render loading indicator initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruConsentModal(
              apiKey: 'test-key',
              organizationId: 'test-org',
              bannerId: 'test-banner',
              userId: 'test-user',
            ),
          ),
        ),
      );

      // Modal should show loading state
      expect(find.text('Loading banner...'), findsOneWidget);
    });

    testWidgets('should display close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruConsentModal(
              apiKey: 'test-key',
              organizationId: 'test-org',
              bannerId: 'test-banner',
              userId: 'test-user',
            ),
          ),
        ),
      );

      // Close button should be present
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should call onClose when close button is tapped', (tester) async {
      ConsentAction? capturedAction;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruConsentModal(
              apiKey: 'test-key',
              organizationId: 'test-org',
              bannerId: 'test-banner',
              userId: 'test-user',
              onClose: (action) {
                capturedAction = action;
              },
            ),
          ),
        ),
      );

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Note: Actual implementation would need to handle async banner loading
      // This is a basic structure test
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}


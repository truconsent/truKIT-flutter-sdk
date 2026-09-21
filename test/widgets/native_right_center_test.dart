/// Widget tests for NativeRightCenter's reaction to prop changes after mount.
///
/// Note: this SDK has no HTTP mocking seam, and network calls here hit the
/// real (reachable, in this environment) trukit-dev API and fail with 400s
/// for these fake credentials — that's expected and fine. These tests only
/// assert that changing `userId` post-mount doesn't crash and that the
/// widget keeps rendering; the didUpdateWidget re-fetch itself is verified
/// by inspecting debugPrint output (a fresh `GET .../consent/user/<newId>`
/// request fires with the *new* id after the prop change) rather than by a
/// timing-sensitive loading-indicator assertion, since real network latency
/// makes the loading window non-deterministic under test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/native_right_center.dart';

void main() {
  testWidgets(
    'survives userId changing from null to a real value post-mount',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NativeRightCenter(
            userId: null,
            apiKey: 'test-key',
            organizationId: 'test-org',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Simulate a login completing while the screen is open: userId flips
      // from null (guest/non-SSO) to a real, authenticated id. Before the
      // didUpdateWidget fix, this prop change was silently ignored.
      await tester.pumpWidget(
        const MaterialApp(
          home: NativeRightCenter(
            userId: 'real-user-123',
            apiKey: 'test-key',
            organizationId: 'test-org',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(NativeRightCenter), findsOneWidget);
    },
  );

  testWidgets(
    'survives an unrelated rebuild with identical props',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NativeRightCenter(
            userId: 'same-user',
            apiKey: 'test-key',
            organizationId: 'test-org',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Rebuild with identical NativeRightCenter props (a typical parent
      // rebuild unrelated to identity, e.g. theme change elsewhere) — should
      // be a no-op, not a fresh bootstrap.
      await tester.pumpWidget(
        const MaterialApp(
          home: NativeRightCenter(
            userId: 'same-user',
            apiKey: 'test-key',
            organizationId: 'test-org',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(NativeRightCenter), findsOneWidget);
    },
  );

  testWidgets(
    'shows "please log in" when access is SSO and no userId is supplied',
    (tester) async {
      // No userId, and the settings fetch fails (fake creds) so it falls
      // back to RightsCenterSettings.defaults, whose accessMode is 'sso' —
      // this is the common case: an app configured for SSO, opened by a
      // signed-out visitor. It should show a clear message, not silently
      // fetch/render tabs with an empty identity.
      await tester.pumpWidget(
        const MaterialApp(
          home: NativeRightCenter(
            userId: null,
            apiKey: 'test-key',
            organizationId: 'test-org',
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Please log in to view your Rights Center.'), findsOneWidget);
      // The OTP gate must not appear in SSO mode.
      expect(find.text('Verify your phone number'), findsNothing);
    },
  );
}

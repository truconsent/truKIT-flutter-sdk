/// Smoke tests for the banner templates added to reach parity with the NPM
/// SDK's template registry (PreferencesModalUI, NoticeOnlyBanner,
/// CompactListUI, SplitPaneUI, InlineSingleRowUI).
import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/models/banner.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/preferences_modal_ui.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/notice_only_banner.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/compact_list_ui.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/split_pane_ui.dart';
import 'package:truconsent_consent_notice_flutter/src/widgets/inline_single_row_ui.dart';

Banner _testBanner({bool mandatory = false}) => Banner(
      bannerId: 'test-banner',
      collectionPoint: 'test-cp',
      version: '1',
      title: 'Test Banner',
      expiryType: 'active',
      purposes: [
        Purpose(
          id: 'p1',
          name: 'Analytics',
          description: 'Used to understand app usage',
          isMandatory: mandatory,
          consented: 'declined',
          expiryPeriod: '1 Year',
          dataElements: [DataElement(id: 'd1', name: 'Device ID')],
          legalEntities: [LegalEntity(id: 'le1', name: 'Acme Analytics Inc')],
        ),
      ],
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('PreferencesModalUI renders purposes and three action buttons', (tester) async {
    var toggled = false;
    await tester.pumpWidget(_wrap(PreferencesModalUI(
      banner: _testBanner(),
      companyName: 'Acme',
      onChangePurpose: (_, __) => toggled = true,
      onAcceptMandatory: () {},
      onAcceptSelected: () {},
      onConsentAll: () {},
    )));

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Accept Only Necessary'), findsOneWidget);
    expect(find.text('Save My Preferences'), findsOneWidget);
    expect(find.text('Accept All'), findsOneWidget);
    // No Reject All button on this template, unlike BannerUI.
    expect(find.text('Reject All'), findsNothing);

    await tester.tap(find.byType(Switch));
    expect(toggled, isTrue);
  });

  testWidgets('NoticeOnlyBanner renders read-only cards and acknowledge button', (tester) async {
    var acknowledged = false;
    await tester.pumpWidget(_wrap(NoticeOnlyBanner(
      banner: _testBanner(),
      companyName: 'Acme',
      onAcknowledge: () => acknowledged = true,
    )));

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('I Understand'), findsOneWidget);
    // Read-only: the toggle is disabled (ModernPurposeCard always renders a
    // Switch, but with onChanged: null when readOnly is set).
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.onChanged, isNull);

    await tester.ensureVisible(find.text('I Understand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I Understand'));
    expect(acknowledged, isTrue);
  });

  testWidgets('CompactListUI expands a row to reveal its details', (tester) async {
    await tester.pumpWidget(_wrap(CompactListUI(
      banner: _testBanner(),
      companyName: 'Acme',
      onChangePurpose: (_, __) {},
      onRejectAll: () {},
      onConsentAll: () {},
      onAcceptSelected: () {},
      onAcceptMandatory: () {},
    )));

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Used to understand app usage'), findsNothing);

    await tester.tap(find.text('Analytics'));
    await tester.pump();

    expect(find.text('Used to understand app usage'), findsOneWidget);
  });

  testWidgets('SplitPaneUI shows the first purpose selected by default', (tester) async {
    await tester.pumpWidget(_wrap(SplitPaneUI(
      banner: _testBanner(),
      companyName: 'Acme',
      onChangePurpose: (_, __) {},
      onRejectAll: () {},
      onConsentAll: () {},
      onAcceptSelected: () {},
      onAcceptMandatory: () {},
    )));

    expect(find.text('Used to understand app usage'), findsOneWidget);
  });

  testWidgets('InlineSingleRowUI shows all purpose detail inline with no expand step',
      (tester) async {
    await tester.pumpWidget(_wrap(InlineSingleRowUI(
      banner: _testBanner(),
      companyName: 'Acme',
      onChangePurpose: (_, __) {},
      onRejectAll: () {},
      onConsentAll: () {},
      onAcceptSelected: () {},
      onAcceptMandatory: () {},
    )));

    expect(find.text('Used to understand app usage'), findsOneWidget);
    expect(find.textContaining('Device ID'), findsOneWidget);
  });

  testWidgets('InlineSingleRowUI renders nothing for an empty purpose list', (tester) async {
    final empty = Banner(
      bannerId: 'b',
      collectionPoint: 'cp',
      version: '1',
      title: 'Empty',
      expiryType: 'active',
      purposes: const [],
    );
    await tester.pumpWidget(_wrap(InlineSingleRowUI(
      banner: empty,
      companyName: 'Acme',
      onChangePurpose: (_, __) {},
      onRejectAll: () {},
      onConsentAll: () {},
      onAcceptSelected: () {},
      onAcceptMandatory: () {},
    )));

    expect(find.byType(InlineSingleRowUI), findsOneWidget);
    expect(find.text('Acme'), findsNothing);
  });
}

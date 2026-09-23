import 'package:flutter/material.dart' hide Banner;
import '../models/banner.dart' as models;
import '../services/consent_manager.dart';
import '../services/banner_theme.dart';
import '../utils/i18n.dart';
import 'modern_banner_header.dart';
import 'modern_purpose_card.dart';
import 'modern_banner_footer.dart';
import 'modern_banner_actions.dart';
import 'h_case_warning_widget.dart';

/// Standard consent banner UI widget.
///
/// Supports NORMAL, NOTICE_ONLY, and TABBED banner cases.
class BannerUI extends StatefulWidget {
  final models.Banner banner;
  final String companyName;
  final String? logoUrl;
  final Function(String, String) onChangePurpose;
  final VoidCallback onRejectAll;
  final VoidCallback onConsentAll;
  final VoidCallback onAcceptSelected;
  final VoidCallback onAcceptMandatory;
  final bool hasUserInteracted;
  /// Matches truKIT-NPM's BannerUI.jsx `isBottomReached` — whether the user
  /// has scrolled through every purpose. Gates Reject All/Only Necessary/I
  /// Consent until true, unless there's only a single optional purpose (no
  /// scroll needed then). Defaults to `true` (no gating) for callers that
  /// don't track scroll position.
  final bool isBottomReached;
  final VoidCallback? onNoticeShown;
  final bool showHCaseWarning;
  final String? hCaseStrategy;
  final String? hCaseMessage;
  final String? hCaseProceedText;
  final String? hCaseBackText;
  final VoidCallback? onHCaseProceed;
  final VoidCallback? onHCaseBack;
  final String? primaryColor;
  final String? secondaryColor;
  /// "Common Appearance" theme (background/text/button colors, font) from
  /// the admin dashboard. Derived from `banner.bannerSettings` if omitted.
  final BannerTheme? theme;
  /// Translates dynamic (server-supplied) text via the banner's translation
  /// snapshot. Identity function if omitted.
  final String Function(String)? translate;
  final String selectedLanguage;
  final List<String> availableLanguages;
  final Map<String, String> languageLabels;
  final void Function(String)? onLanguageChange;

  const BannerUI({
    super.key,
    required this.banner,
    required this.companyName,
    this.logoUrl,
    required this.onChangePurpose,
    required this.onRejectAll,
    required this.onConsentAll,
    required this.onAcceptSelected,
    required this.onAcceptMandatory,
    this.hasUserInteracted = false,
    this.isBottomReached = true,
    this.onNoticeShown,
    this.showHCaseWarning = false,
    this.hCaseStrategy,
    this.hCaseMessage,
    this.hCaseProceedText,
    this.hCaseBackText,
    this.onHCaseProceed,
    this.onHCaseBack,
    this.primaryColor,
    this.secondaryColor,
    this.theme,
    this.translate,
    this.selectedLanguage = 'en',
    this.availableLanguages = const [],
    this.languageLabels = const {},
    this.onLanguageChange,
  });

  @override
  State<BannerUI> createState() => _BannerUIState();
}

class _BannerUIState extends State<BannerUI> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late models.UIState _uiState;

  @override
  void initState() {
    super.initState();
    _uiState = deriveUIState(widget.banner.purposes);
    final tabCount = _tabCount();
    _tabController = TabController(length: tabCount, vsync: this);
    // Rebuilds the footer so it can switch between the "Next" button and the
    // real accept/reject actions as the active tab changes (see _buildActions).
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(BannerUI old) {
    super.didUpdateWidget(old);
    _uiState = deriveUIState(widget.banner.purposes);
    final tabCount = _tabCount();
    if (_tabController.length != tabCount) {
      _tabController.dispose();
      _tabController = TabController(length: tabCount, vsync: this);
      _tabController.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _tabCount() {
    if (_uiState.bannerCase == models.BannerCase.tabbed) {
      return widget.banner.reconsentMode ? 3 : 2;
    }
    return 1;
  }

  Color _parseColor(String? colorString) {
    if (colorString == null) return const Color(0xFF3b82f6);
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF3b82f6);
    }
  }

  BannerTheme get _theme => widget.theme ?? BannerTheme.from(widget.banner.bannerSettings);
  String Function(String) get _translate => widget.translate ?? (t) => t;

  /// For static UI microcopy (tab labels, group headers, empty states):
  /// prefer the server-driven snapshot (covers every language the admin
  /// actually configured, matching truKIT-NPM's translate() usage for this
  /// exact same copy), falling back to the static I18n bundle (only covers
  /// en/hi/ta) so those two languages keep working even with no snapshot.
  String _tr(String text, [String? i18nKey]) {
    final snapshotResult = _translate(text);
    if (snapshotResult != text) return snapshotResult;
    return i18nKey != null ? I18n.t(i18nKey) : text;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.banner.bannerSettings;
    final theme = _theme;
    // buttonColor takes priority over primaryColor, matching truKIT-NPM's
    // `settings.buttonColor || settings.primaryColor` fallback chain.
    final finalPrimaryColor =
        settings?.buttonColor ?? settings?.primaryColor ?? widget.primaryColor ?? '#3b82f6';
    final parsedPrimaryColor = _parseColor(finalPrimaryColor);
    final footerText = settings?.footerText ??
        'Review our [Privacy Policy] and [Transparency Centre], [DPO Details]. Use the [Rights Centre] anytime to withdraw consent, delete data, name a nominee, or raise a grievance.';
    final bannerTitle = settings?.bannerTitle;
    final disclaimerText = settings?.disclaimerText;
    final actionButtonText =
        settings?.actionButtonText ?? settings?.acceptAllText ?? 'Accept All';

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;

    Widget content = _buildBannerContent(
      isMobile: isMobile,
      settings: settings,
      bannerTitle: bannerTitle,
      disclaimerText: disclaimerText,
      footerText: footerText,
      actionButtonText: actionButtonText,
      parsedPrimaryColor: parsedPrimaryColor,
      finalPrimaryColor: finalPrimaryColor,
      theme: theme,
    );

    if (widget.showHCaseWarning) {
      return Stack(
        children: [
          content,
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: HCaseWarningWidget(
                  strategy: widget.hCaseStrategy ?? 'soft_first',
                  message: widget.hCaseMessage ??
                      'Important: You have not provided consent for one or more required items. Please acknowledge this to continue.',
                  proceedText: widget.hCaseProceedText,
                  backText: widget.hCaseBackText,
                  onProceed: widget.onHCaseProceed ?? () {},
                  onBack: widget.onHCaseBack,
                  primaryColor: parsedPrimaryColor,
                  proceedColor: settings?.hCaseProceedButtonColor != null
                      ? _parseColor(settings!.hCaseProceedButtonColor)
                      : null,
                  backColor: settings?.hCaseBackButtonColor != null
                      ? _parseColor(settings!.hCaseBackButtonColor)
                      : null,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }

  Widget _buildBannerContent({
    required bool isMobile,
    required models.BannerSettings? settings,
    required String? bannerTitle,
    required String? disclaimerText,
    required String footerText,
    required String actionButtonText,
    required Color parsedPrimaryColor,
    required String finalPrimaryColor,
    required BannerTheme theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: ModernBannerHeader(
              logoUrl: settings?.logoUrl ?? widget.logoUrl,
              orgName: widget.companyName,
              bannerTitle: bannerTitle,
              disclaimerText: disclaimerText,
              theme: theme,
              translate: _translate,
              selectedLanguage: widget.selectedLanguage,
              availableLanguages: widget.availableLanguages,
              languageLabels: widget.languageLabels,
              onLanguageChange: widget.onLanguageChange,
            ),
          ),

          // Purposes Section
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 16 : 20,
            ),
            child: _buildPurposesSection(isMobile, parsedPrimaryColor, theme),
          ),

          // Footer
          Container(
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 24,
                    vertical: isMobile ? 12 : 16,
                  ),
                  child: ModernBannerFooter(
                    footerText: footerText,
                    orgName: widget.companyName,
                    theme: theme,
                    translate: _translate,
                  ),
                ),
                _buildActions(
                  isMobile: isMobile,
                  actionButtonText: actionButtonText,
                  finalPrimaryColor: finalPrimaryColor,
                  theme: theme,
                  settings: settings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposesSection(bool isMobile, Color primaryColor, BannerTheme theme) {
    switch (_uiState.bannerCase) {
      case models.BannerCase.noticeOnly:
        return _buildNoticeOnlySection(isMobile, theme);
      case models.BannerCase.tabbed:
        return _buildTabbedSection(isMobile, primaryColor, theme);
      case models.BannerCase.normal:
        return _buildNormalSection(isMobile, theme);
    }
  }

  Widget _buildNoticeOnlySection(bool isMobile, BannerTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('Informational', 'informational'),
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: theme.textMuted,
            fontFamily: theme.fontFamily,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        ..._uiState.noticePurposes.map((p) => Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
              child: ModernPurposeCard(
                purpose: p,
                banner: widget.banner,
                onToggle: widget.onChangePurpose,
                readOnly: true,
                theme: theme,
                translate: _translate,
              ),
            )),
      ],
    );
  }

  Widget _buildTabbedSection(bool isMobile, Color primaryColor, BannerTheme theme) {
    // Tab(text:) renders through TabBar's own default label style, which
    // can't take a custom fontFamily — Tab(child:) is required to apply the
    // admin-configured font to the tab labels.
    Tab buildTab(String label) => Tab(
          child: Text(label, style: TextStyle(fontFamily: theme.fontFamily)),
        );
    final tabs = <Tab>[
      buildTab(_tr('Informational', 'informational')),
      buildTab(_tr('Consent', 'consent')),
      if (widget.banner.reconsentMode) buildTab(_tr('Re-consent')),
    ];

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          // Active tab's label and indicator use Primary Text Color
          // (theme.text), not Button Color (primaryColor) — Button Color is
          // picked for contrast against a button's own background, not the
          // banner's background, so a light banner with a bright Button
          // Color read as low-contrast here. theme.text is guaranteed
          // legible against the banner's own background by definition.
          labelColor: theme.text,
          unselectedLabelColor: theme.textMuted,
          indicatorColor: theme.text,
          tabs: tabs,
        ),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Informational tab
              SingleChildScrollView(
                padding: EdgeInsets.only(top: isMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _uiState.noticePurposes
                      .map((p) => Padding(
                            padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                            child: ModernPurposeCard(
                              purpose: p,
                              banner: widget.banner,
                              onToggle: widget.onChangePurpose,
                              readOnly: true,
                              theme: theme,
                              translate: _translate,
                            ),
                          ))
                      .toList(),
                ),
              ),
              // Consent tab
              SingleChildScrollView(
                padding: EdgeInsets.only(top: isMobile ? 12 : 16),
                child: _buildConsentPurposes(isMobile, theme),
              ),
              if (widget.banner.reconsentMode)
                SingleChildScrollView(
                  padding: EdgeInsets.only(top: isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr('Updated consent required'),
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: theme.textMuted,
                          fontFamily: theme.fontFamily,
                        ),
                      ),
                      ..._uiState.consentPurposes
                          .map((p) => Padding(
                                padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                                child: ModernPurposeCard(
                                  purpose: p,
                                  banner: widget.banner,
                                  onToggle: widget.onChangePurpose,
                                  theme: theme,
                                  translate: _translate,
                                ),
                              ))
                          .toList(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalSection(bool isMobile, BannerTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.banner.purposes.isNotEmpty)
          Text(
            _tr('Consent Preferences'),
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: theme.textMuted,
              fontFamily: theme.fontFamily,
            ),
          ),
        if (widget.banner.purposes.isNotEmpty) SizedBox(height: isMobile ? 12 : 16),
        _buildConsentPurposes(isMobile, theme),
      ],
    );
  }

  Widget _buildConsentPurposes(bool isMobile, BannerTheme theme) {
    // Split into three visual groups the same way truKIT-NPM's TabbedBannerUI
    // and truKIT-react-native's BannerUI do: a dynamic (profile-based)
    // purpose is shown under its own "Profile Based" heading regardless of
    // whether it's also mandatory, rather than being folded into "Necessary".
    // This is purely a rendering split of the full consent purpose list —
    // it does NOT touch uiState.mandatoryConsentPurposes/hasRequiredConsent,
    // which intentionally still consider all mandatory purposes (dynamic or
    // not) for H-Case detection.
    final all = _uiState.consentPurposes;
    final necessary = all.where((p) => p.isMandatory && !p.isDynamic).toList();
    final profileBased = all.where((p) => p.isDynamic).toList();
    final optional = all.where((p) => !p.isMandatory && !p.isDynamic).toList();

    Widget buildGroup(String label, List<models.Purpose> items, {required bool isFirst}) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFirst) SizedBox(height: isMobile ? 8 : 12),
          _buildGroupHeader(label, isMobile, theme),
          SizedBox(height: isMobile ? 8 : 10),
          ...items.map((p) => Padding(
                padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                child: ModernPurposeCard(
                  purpose: p,
                  banner: widget.banner,
                  onToggle: widget.onChangePurpose,
                  theme: theme,
                  translate: _translate,
                ),
              )),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildGroup('Necessary', necessary, isFirst: true),
        buildGroup('Profile Based', profileBased, isFirst: necessary.isEmpty),
        buildGroup('Optional', optional, isFirst: necessary.isEmpty && profileBased.isEmpty),
        // Fallback: show all purposes if none of the three groups matched (e.g., unclassified)
        if (necessary.isEmpty && profileBased.isEmpty && optional.isEmpty)
          ...widget.banner.purposes.map((p) => Padding(
                padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                child: ModernPurposeCard(
                  purpose: p,
                  banner: widget.banner,
                  onToggle: widget.onChangePurpose,
                  theme: theme,
                  translate: _translate,
                ),
              )),
      ],
    );
  }

  Widget _buildGroupHeader(String label, bool isMobile, BannerTheme theme) {
    final i18nKey = label == 'Necessary'
        ? 'necessary_group'
        : label == 'Optional'
            ? 'optional_group'
            : label == 'Profile Based'
                ? 'profile_based_group'
                : null;
    return Text(
      _tr(label, i18nKey),
      style: TextStyle(
        fontSize: isMobile ? 12 : 13,
        fontWeight: FontWeight.w700,
        color: theme.textMuted,
        fontFamily: theme.fontFamily,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildActions({
    required bool isMobile,
    required String actionButtonText,
    required String finalPrimaryColor,
    required BannerTheme theme,
    required models.BannerSettings? settings,
  }) {
    if (_uiState.bannerCase == models.BannerCase.noticeOnly) {
      // Notice-only: show "I Understand" button
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 12 : 16,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onNoticeShown,
            style: ElevatedButton.styleFrom(
              backgroundColor: _parseColor(finalPrimaryColor),
              foregroundColor: theme.buttonText,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'I Understand',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: theme.fontFamily,
              ),
            ),
          ),
        ),
      );
    }

    // Tabbed case: matches truKIT-NPM's TabbedBannerUI.jsx — the accept/reject/
    // only-necessary decision only belongs on the final tab (the actual Consent
    // tab). Every earlier tab (Informational, and Consent itself when a
    // Re-consent tab follows it) only ever advances via "Next".
    if (_uiState.bannerCase == models.BannerCase.tabbed &&
        _tabController.index != _tabController.length - 1) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 12 : 16,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _tabController.animateTo(_tabController.index + 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: _parseColor(finalPrimaryColor),
              foregroundColor: theme.buttonText,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              _tr('Next', 'next'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: theme.fontFamily,
              ),
            ),
          ),
        ),
      );
    }

    return ModernBannerActions(
      onRejectAll: widget.onRejectAll,
      onConsentAll: widget.onConsentAll,
      onAcceptSelected: widget.onAcceptSelected,
      onAcceptMandatory: widget.onAcceptMandatory,
      hasUserInteracted: widget.hasUserInteracted,
      isBottomReached: widget.isBottomReached,
      purposes: widget.banner.purposes,
      actionButtonText: actionButtonText,
      primaryColor: finalPrimaryColor,
      theme: theme,
      rejectAllColor: settings?.rejectAllColor,
      rejectAllText: settings?.rejectAllText,
      onlyNecessaryColor: settings?.onlyNecessaryColor,
      onlyNecessaryText: settings?.onlyNecessaryText,
      translate: _translate,
    );
  }

}

/// TruConsentModal - Main Flutter widget for displaying consent banner
import 'dart:math';
import 'package:flutter/material.dart' hide Banner;
import 'package:uuid/uuid.dart';
import '../models/banner.dart' as models;
import '../services/banner_service.dart'
    show
        fetchBanner,
        submitConsent,
        sendSuppressionUpdate,
        sendNoticeShown,
        defaultApiBaseUrl;
import '../services/consent_manager.dart';
import '../services/template_registry.dart';
import '../services/banner_theme.dart';
import '../services/translation_snapshot.dart';
import 'banner_ui.dart';
import 'cookie_banner_ui.dart';
import 'preferences_modal_ui.dart';
import 'notice_only_banner.dart';
import 'compact_list_ui.dart';
import 'split_pane_ui.dart';
import 'inline_single_row_ui.dart';
import 'h_case_warning_widget.dart';

/// Generates a session ID in the format: sess_{timestamp}_{random8chars}
String _generateSessionId() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random();
  final rand = List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  return 'sess_${ts}_$rand';
}

/// Main widget for displaying the TruConsent consent banner modal.
class TruConsentModal extends StatefulWidget {
  /// API key for TruConsent authentication. Either [apiKey] or a JWT bearer
  /// [token]/[authToken] must be provided.
  final String? apiKey;

  /// Organization ID for TruConsent
  final String organizationId;

  /// Banner/Collection Point ID to display
  final String bannerId;

  /// User ID for consent tracking
  final String userId;

  /// Asset ID for multi-asset scenarios
  final String? assetId;

  /// Optional base URL for the API. Defaults to production URL if not provided.
  final String? apiBaseUrl;

  /// Optional company logo URL to display in the banner
  final String? logoUrl;

  /// Company name to display in the banner.
  final String companyName;

  /// JWT bearer token used for authentication instead of [apiKey]. Takes
  /// precedence over [authToken] if both are provided.
  final String? token;

  /// Alternative name for a JWT bearer token (used if [token] is not set).
  final String? authToken;

  /// Callback function called when the modal closes with the user's consent action
  final Function(models.ConsentAction)? onClose;

  /// Optional custom submit handler; if provided, suppression API is skipped.
  final Function(List<models.Purpose>, models.ConsentAction)? onSubmit;

  const TruConsentModal({
    super.key,
    this.apiKey,
    required this.organizationId,
    required this.bannerId,
    required this.userId,
    this.assetId,
    this.apiBaseUrl,
    this.logoUrl,
    this.companyName = 'Mars Company',
    this.token,
    this.authToken,
    this.onClose,
    this.onSubmit,
  }) : assert(
          apiKey != null || token != null || authToken != null,
          'TruConsentModal requires either apiKey or token/authToken',
        );

  @override
  State<TruConsentModal> createState() => _TruConsentModalState();
}

class _TruConsentModalState extends State<TruConsentModal> {
  models.Banner? _banner;
  bool _isLoading = true;
  String? _error;
  bool _visible = true;
  bool _actionTaken = false;
  bool _actionRunning = false;
  late String _requestId;
  late String _sessionId;
  List<models.Purpose> _purposes = [];
  // Matches truKIT-NPM's `hasUserInteracted` — set once the user toggles any
  // purpose this session, so ModernBannerActions's dynamic third button
  // switches from "Accept All" to "Accept Selected" semantics even if the
  // toggle ends up leaving zero optional purposes accepted.
  bool _hasUserInteracted = false;

  // Performance timestamps (seconds)
  int? _bannerFetchedAt;
  int? _bannerDisplayedAt;

  // H-Case state
  bool _showHCase = false;
  String? _pendingHCaseAction;

  // Server-driven translation of dynamic content (purpose names/
  // descriptions, banner title/disclaimer/footer). The language list and
  // translated text both come from the banner's translation snapshot, not
  // a fixed built-in set of languages.
  String _selectedLanguage = 'en';

  // Re-consent
  bool _reconsentMode = false;

  // Matches truKIT-NPM's BannerUI.jsx `isBottomReached` — the user must
  // scroll through every purpose before "I Consent" (and Reject All/Only
  // Necessary) become clickable. Tracked on the SingleChildScrollView that
  // wraps the whole banner (header/purposes/footer/actions), since that's
  // the scrollable region in this SDK's layout — reaching its bottom means
  // every purpose card has been scrolled past.
  bool _isBottomReached = false;
  final ScrollController _bannerScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _requestId = const Uuid().v4();
    _sessionId = _generateSessionId();
    _loadBanner();
    _bannerScrollController.addListener(_handleBannerScroll);
  }

  @override
  void dispose() {
    _bannerScrollController.removeListener(_handleBannerScroll);
    _bannerScrollController.dispose();
    super.dispose();
  }

  void _handleBannerScroll() {
    if (_isBottomReached || !_bannerScrollController.hasClients) return;
    final position = _bannerScrollController.position;
    // 5px threshold for "bottom" — matches truKIT-NPM's BannerUI.jsx exactly.
    if (position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 5) {
      setState(() => _isBottomReached = true);
    }
  }

  Future<void> _loadBanner() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final fetchStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      final banner = await fetchBanner(
        bannerId: widget.bannerId,
        apiKey: widget.apiKey,
        organizationId: widget.organizationId,
        userId: widget.userId,
        assetId: widget.assetId,
        token: widget.token,
        authToken: widget.authToken,
        apiBaseUrl: widget.apiBaseUrl ?? defaultApiBaseUrl,
      );

      _bannerFetchedAt = fetchStart;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Auto-hide only when the CP has no purposes to show — not when
      // already consented. Matches truKIT-NPM's TruConsentModal.jsx exactly
      // (see its own comment there): users should always be able to reopen
      // the banner to view or update their preferences, so an
      // already-complete consentStatus must NOT auto-hide here. It
      // previously did — silently, with no `onClose` call at all — meaning
      // a user who had *already consented* on a prior visit saw the banner
      // vanish with the app never notified of any outcome, so whatever
      // `onClose` was supposed to trigger (e.g. submitting the application)
      // never ran. If a consuming app wants to skip showing the banner
      // again after a completed decision, that's its own responsibility to
      // cache — truKIT-NPM's own consuming demos do this themselves rather
      // than relying on the SDK to guess.
      if (!banner.reconsentMode && banner.purposes.isEmpty) {
        setState(() {
          _visible = false;
          _isLoading = false;
        });
        widget.onClose?.call(models.ConsentAction.noAction);
        return;
      }

      final normalizedPurposes = normalizePurposes(banner.purposes);

      setState(() {
        _banner = banner;
        _purposes = normalizedPurposes;
        _reconsentMode = banner.reconsentMode;
        _isLoading = false;
        _bannerDisplayedAt = now;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _resolvedApiBase => widget.apiBaseUrl ?? defaultApiBaseUrl;

  Future<void> _sendLogEvent(
    models.ConsentAction action,
    List<models.Purpose> purposesToSend, {
    String? buttonUsed,
    bool hCaseAcknowledged = false,
  }) async {
    if (_banner == null || _actionRunning) return;
    if (action != models.ConsentAction.noAction) {
      _actionTaken = true;
    }

    _actionRunning = true;
    try {
      if (widget.onSubmit != null) {
        widget.onSubmit!(purposesToSend, action);
      } else {
        // hCaseAcknowledged is expressed via buttonUsed='h_case_proceed' in the payload
        await submitConsent(
          collectionPointId: _banner!.collectionPoint,
          userId: widget.userId,
          purposes: purposesToSend,
          action: action,
          apiKey: widget.apiKey,
          organizationId: widget.organizationId,
          requestId: _requestId,
          assetId: widget.assetId ?? _banner!.asset?.id,
          sessionId: _sessionId,
          buttonUsed: hCaseAcknowledged ? 'h_case_proceed' : buttonUsed,
          reconsentCampaignId: _banner!.reconsentCampaignId,
          expiryReconsentRequestId: _banner!.expiryReconsentRequestId,
          bannerFetchedAt: _bannerFetchedAt,
          bannerDisplayedAt: _bannerDisplayedAt,
          token: widget.token,
          authToken: widget.authToken,
          apiBaseUrl: _resolvedApiBase,
        );
        // Suppression update if not custom handler
        if (action != models.ConsentAction.noticeShown) {
          final declined = purposesToSend
              .where((p) => p.consented == 'declined' && !p.isLegitimate)
              .map((p) => p.id)
              .toList();
          if (declined.isNotEmpty) {
            sendSuppressionUpdate(
              userId: widget.userId,
              declinedPurposeIds: declined,
              apiKey: widget.apiKey,
              organizationId: widget.organizationId,
              token: widget.token,
              authToken: widget.authToken,
              apiBaseUrl: _resolvedApiBase,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to log consent event: $e');
      rethrow;
    } finally {
      _actionRunning = false;
    }
  }

  void _close(models.ConsentAction type) {
    setState(() {
      _visible = false;
    });
    widget.onClose?.call(type);
  }

  // -------- Action Handlers --------

  Future<void> _handleAcceptAll() async {
    if (_banner == null) return;
    _clearError();
    try {
      final updated = _purposes.map((p) => p.copyWith(consented: 'accepted')).toList();
      await _sendLogEvent(models.ConsentAction.approved, updated, buttonUsed: 'accept_all');
      _close(models.ConsentAction.approved);
    } catch (_) {
      _setError();
    }
  }

  Future<void> _handleRejectAll() async {
    if (_banner == null) return;
    _clearError();

    // Check H-Case before declining
    if (checkHCaseIntercept(_purposes.map((p) => p.copyWith(consented: 'declined')).toList())) {
      setState(() {
        _showHCase = true;
        _pendingHCaseAction = 'reject_all';
      });
      return;
    }

    try {
      final updated = _purposes.map((p) {
        if (p.isLegitimate) return p.copyWith(consented: 'shown');
        return p.copyWith(consented: 'declined');
      }).toList();
      await _sendLogEvent(models.ConsentAction.declined, updated, buttonUsed: 'reject_all');
      _close(models.ConsentAction.declined);
    } catch (_) {
      _setError();
    }
  }

  Future<void> _handleOnlyNecessary() async {
    if (_banner == null) return;
    _clearError();
    try {
      final updated = _purposes.map((p) {
        if (p.isLegitimate) return p.copyWith(consented: 'shown');
        if (p.isMandatory) return p.copyWith(consented: 'accepted');
        return p.copyWith(consented: 'declined');
      }).toList();
      final hasOptional = _purposes.any((p) => !p.isMandatory && !p.isLegitimate);
      final action = hasOptional
          ? models.ConsentAction.partialConsent
          : models.ConsentAction.approved;
      await _sendLogEvent(action, updated, buttonUsed: 'only_necessary');
      _close(action);
    } catch (_) {
      _setError();
    }
  }

  Future<void> _handleSavePreferences() async {
    if (_banner == null) return;
    _clearError();

    // ModernBannerActions.dart's dynamic third button reuses this single
    // handler for two distinct modes, decided by the label the user just
    // saw: "Only Necessary" (no optional purpose currently accepted) or
    // "Accept Selected" (at least one is). Must be computed from the
    // *current* state before building the payload — the same check
    // ModernBannerActions.dart's own `hasOptionalAccepted` uses for the
    // label — so the two can never disagree about which mode is active.
    final anyOptionalAccepted =
        _purposes.any((p) => !p.isMandatory && !p.isLegitimate && p.consented == 'accepted');

    // "Only Necessary" mode: force every optional purpose to declined
    // regardless of its current toggle state — matches truKIT-NPM's
    // reference `onlyNecessary` handler and this file's own
    // _handleOnlyNecessary. Without this, an optional purpose that already
    // reads 'accepted' (e.g. a `defaultSelection` other than
    // 'mandatory_only', or a residual toggle) makes the submitted action
    // 'approved' even though the button visibly read "Only Necessary".
    final purposesForSubmit = anyOptionalAccepted
        ? _purposes
        : _purposes.map((p) {
            if (p.isLegitimate || p.isMandatory) return p;
            return p.copyWith(consented: 'declined');
          }).toList();

    // Check H-Case
    if (checkHCaseIntercept(purposesForSubmit)) {
      setState(() {
        _showHCase = true;
        _pendingHCaseAction = 'save_preferences';
      });
      return;
    }

    try {
      final consentPurposes = purposesForSubmit.where((p) => !p.isLegitimate).toList();
      final acceptedCount = consentPurposes.where((p) => p.consented == 'accepted').length;
      models.ConsentAction action;
      if (acceptedCount == 0) {
        action = models.ConsentAction.declined;
      } else if (acceptedCount == consentPurposes.length) {
        action = models.ConsentAction.approved;
      } else {
        action = models.ConsentAction.partialConsent;
      }
      await _sendLogEvent(action, purposesForSubmit, buttonUsed: 'save_preferences');
      _close(action);
    } catch (_) {
      _setError();
    }
  }

  Future<void> _handleNoticeShown() async {
    if (_banner == null) return;
    _clearError();
    try {
      if (widget.onSubmit != null) {
        widget.onSubmit!(_purposes, models.ConsentAction.noticeShown);
      } else {
        await sendNoticeShown(
          collectionPointId: _banner!.collectionPoint,
          userId: widget.userId,
          purposes: _purposes,
          apiKey: widget.apiKey,
          organizationId: widget.organizationId,
          requestId: _requestId,
          assetId: widget.assetId ?? _banner!.asset?.id,
          sessionId: _sessionId,
          bannerFetchedAt: _bannerFetchedAt,
          bannerDisplayedAt: _bannerDisplayedAt,
          reconsentCampaignId: _banner!.reconsentCampaignId,
          token: widget.token,
          authToken: widget.authToken,
          apiBaseUrl: _resolvedApiBase,
        );
      }
      _close(models.ConsentAction.noticeShown);
    } catch (_) {
      _setError();
    }
  }

  void _handleCloseClick() {
    if (!_actionTaken) {
      final noActionPurposes = _purposes.map((p) {
        if (p.isLegitimate) return p.copyWith(consented: 'shown');
        return p.copyWith(consented: 'declined');
      }).toList();
      _sendLogEvent(models.ConsentAction.noAction, noActionPurposes, buttonUsed: 'close');
      _actionTaken = true;
    }
    _close(models.ConsentAction.noAction);
  }

  void _handleHCaseProceed() {
    setState(() => _showHCase = false);
    final action = _pendingHCaseAction;
    _pendingHCaseAction = null;

    final updated = _purposes.map((p) {
      if (p.isLegitimate) return p.copyWith(consented: 'shown');
      if (action == 'reject_all') return p.copyWith(consented: 'declined');
      return p; // save_preferences: use current toggles
    }).toList();

    _sendLogEvent(
      models.ConsentAction.partialConsent,
      updated,
      buttonUsed: 'h_case_proceed',
      hCaseAcknowledged: true,
    ).then((_) => _close(models.ConsentAction.partialConsent)).catchError((_) => _setError());
  }

  void _handleHCaseBack() {
    setState(() {
      _showHCase = false;
      _pendingHCaseAction = null;
    });
  }

  void _updatePurpose(String purposeId, String newStatus) {
    setState(() {
      _hasUserInteracted = true;
      _purposes = updatePurposeStatus(_purposes, purposeId, newStatus);
    });
  }

  void _clearError() => setState(() => _error = null);
  void _setError() => setState(() => _error = 'Something went wrong. Please try again.');

  Color _parsePrimaryColor(String? colorString) {
    if (colorString == null) return const Color(0xFF3b82f6);
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF3b82f6);
    }
  }

  /// Resolves the configured banner template and builds its widget, wrapping
  /// it with the shared H-Case warning overlay for templates that don't
  /// already handle it internally (only [BannerUI] does, since it predates
  /// the template registry).
  Widget _buildTemplateBody(
    String companyName,
    String? logoUrl,
    models.BannerSettings? settings,
  ) {
    final templateKey = resolveTemplateKey(
      settings?.generalNoticeTemplate,
      consentType: _banner!.consentType,
    );

    final normalizedBanner = models.Banner(
      bannerId: _banner!.bannerId,
      collectionPoint: _banner!.collectionPoint,
      version: _banner!.version,
      title: _banner!.title,
      expiryType: _banner!.expiryType,
      asset: _banner!.asset,
      purposes: _purposes,
      dataElements: _banner!.dataElements,
      legalEntities: _banner!.legalEntities,
      tools: _banner!.tools,
      processingActivities: _banner!.processingActivities,
      consentType: _banner!.consentType,
      cookieConfig: _banner!.cookieConfig,
      bannerSettings: _banner!.bannerSettings,
      organization: _banner!.organization,
      organizationName: _banner!.organizationName,
      reconsentMode: _reconsentMode,
      reconsentCampaignId: _banner!.reconsentCampaignId,
      reconsentUiMode: _banner!.reconsentUiMode,
      versionDiff: _banner!.versionDiff,
      reconsentSource: _banner!.reconsentSource,
      expiryReconsentRequestId: _banner!.expiryReconsentRequestId,
      consentStatus: _banner!.consentStatus,
      translationsSnapshot: _banner!.translationsSnapshot,
    );

    // "Common Appearance" theme (background/text/button colors, font) from
    // the admin dashboard, applied throughout BannerUI and its children.
    final bannerTheme = BannerTheme.from(settings);

    // Server-driven translations for dynamic content and the language list
    // actually configured for this banner (not a fixed built-in set).
    final languageOptions = getAvailableLanguages(_banner!.translationsSnapshot);
    final translate = createTranslator(_banner!.translationsSnapshot, _selectedLanguage);

    switch (templateKey) {
      case BannerTemplateKey.floatingCard:
        return CookieBannerUI(
          banner: normalizedBanner,
          companyName: companyName,
          logoUrl: logoUrl,
          onRejectAll: _handleRejectAll,
          onConsentAll: _handleAcceptAll,
        );
      case BannerTemplateKey.preferencesModal:
        return _withHCaseOverlay(
          settings,
          PreferencesModalUI(
            banner: normalizedBanner,
            companyName: companyName,
            logoUrl: logoUrl,
            onChangePurpose: _updatePurpose,
            onAcceptMandatory: _handleOnlyNecessary,
            onAcceptSelected: _handleSavePreferences,
            onConsentAll: _handleAcceptAll,
            primaryColor: settings?.primaryColor,
          ),
        );
      case BannerTemplateKey.noticeOnly:
        return NoticeOnlyBanner(
          banner: normalizedBanner,
          companyName: companyName,
          logoUrl: logoUrl,
          onAcknowledge: _handleNoticeShown,
          primaryColor: settings?.primaryColor,
        );
      case BannerTemplateKey.generalCompactList:
        return _withHCaseOverlay(
          settings,
          CompactListUI(
            banner: normalizedBanner,
            companyName: companyName,
            logoUrl: logoUrl,
            onChangePurpose: _updatePurpose,
            onRejectAll: _handleRejectAll,
            onConsentAll: _handleAcceptAll,
            onAcceptSelected: _handleSavePreferences,
            onAcceptMandatory: _handleOnlyNecessary,
            hasUserInteracted: _hasUserInteracted,
            primaryColor: settings?.primaryColor,
          ),
        );
      case BannerTemplateKey.generalSplitPane:
        return _withHCaseOverlay(
          settings,
          SplitPaneUI(
            banner: normalizedBanner,
            companyName: companyName,
            logoUrl: logoUrl,
            onChangePurpose: _updatePurpose,
            onRejectAll: _handleRejectAll,
            onConsentAll: _handleAcceptAll,
            onAcceptSelected: _handleSavePreferences,
            onAcceptMandatory: _handleOnlyNecessary,
            hasUserInteracted: _hasUserInteracted,
            primaryColor: settings?.primaryColor,
          ),
        );
      case BannerTemplateKey.inlineSingleRow:
        return _withHCaseOverlay(
          settings,
          InlineSingleRowUI(
            banner: normalizedBanner,
            companyName: companyName,
            logoUrl: logoUrl,
            onChangePurpose: _updatePurpose,
            onRejectAll: _handleRejectAll,
            onConsentAll: _handleAcceptAll,
            onAcceptSelected: _handleSavePreferences,
            onAcceptMandatory: _handleOnlyNecessary,
            hasUserInteracted: _hasUserInteracted,
            primaryColor: settings?.primaryColor,
          ),
        );
      case BannerTemplateKey.tabbedBanner:
        return BannerUI(
          banner: normalizedBanner,
          companyName: companyName,
          logoUrl: logoUrl,
          theme: bannerTheme,
          translate: translate,
          selectedLanguage: _selectedLanguage,
          availableLanguages: languageOptions.availableLanguages,
          languageLabels: languageOptions.languageLabels,
          onLanguageChange: (lang) => setState(() => _selectedLanguage = lang),
          onChangePurpose: _updatePurpose,
          onRejectAll: _handleRejectAll,
          onConsentAll: _handleAcceptAll,
          onAcceptSelected: _handleSavePreferences,
          onAcceptMandatory: _handleOnlyNecessary,
          hasUserInteracted: _hasUserInteracted,
          isBottomReached: _isBottomReached,
          onNoticeShown: _handleNoticeShown,
          showHCaseWarning: _showHCase,
          hCaseStrategy: settings?.hCaseLoggingStrategy ?? 'soft_first',
          hCaseMessage: settings?.hCaseWarningMessage,
          hCaseProceedText: settings?.hCaseProceedButtonText,
          hCaseBackText: settings?.hCaseBackButtonText,
          onHCaseProceed: _handleHCaseProceed,
          onHCaseBack: _handleHCaseBack,
        );
    }
  }

  /// Wraps [content] with the H-Case warning overlay when [_showHCase] is
  /// active. Used by every template except [BannerUI], which manages its own
  /// overlay.
  Widget _withHCaseOverlay(models.BannerSettings? settings, Widget content) {
    if (!_showHCase) return content;
    final primaryColor = _parsePrimaryColor(settings?.primaryColor);
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
                strategy: settings?.hCaseLoggingStrategy ?? 'soft_first',
                message: settings?.hCaseWarningMessage ??
                    'Important: You have not provided consent for one or more required items. Please acknowledge this to continue.',
                proceedText: settings?.hCaseProceedButtonText,
                backText: settings?.hCaseBackButtonText,
                onProceed: _handleHCaseProceed,
                onBack: _handleHCaseBack,
                primaryColor: primaryColor,
                proceedColor: settings?.hCaseProceedButtonColor != null
                    ? _parsePrimaryColor(settings!.hCaseProceedButtonColor)
                    : null,
                backColor: settings?.hCaseBackButtonColor != null
                    ? _parsePrimaryColor(settings!.hCaseBackButtonColor)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    // The scroll listener only fires on an actual scroll gesture — if the
    // content already fits without scrolling, nothing ever fires it, so
    // check maxScrollExtent once per frame after layout too.
    if (_banner != null && !_isBottomReached) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleBannerScroll());
    }

    final resolvedCompanyName = _banner?.organizationName ??
        _banner?.organization?.name ??
        widget.companyName;
    final resolvedLogoUrl = _banner?.organization?.logoUrl ?? widget.logoUrl;

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    final settings = _banner?.bannerSettings;
    // "Common Appearance" theme for the modal's own chrome (outer card
    // background, close button) — BannerUI and its children compute their
    // own copy of this inside _buildTemplateBody, so this is intentionally
    // the same derivation, just also needed up here.
    final theme = BannerTheme.from(settings);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 20 : 28,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenSize.width * 0.96 : 720,
          maxHeight: isMobile ? screenSize.height - 80 : screenSize.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading banner...'),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.all(isMobile ? 20 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          border: Border.all(color: const Color(0xFFDC2626)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14),
                        ),
                      ),
                    if (_error == null && _banner == null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          border: Border.all(color: const Color(0xFFDC2626)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No banner data available',
                          style: TextStyle(color: Color(0xFFDC2626)),
                        ),
                      ),
                    if (_banner != null)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _bannerScrollController,
                          padding: const EdgeInsets.only(bottom: 32),
                          child: _buildTemplateBody(resolvedCompanyName, resolvedLogoUrl, settings),
                        ),
                      ),
                  ],
                ),
              ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                color: Colors.transparent,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 20),
                    color: theme.text,
                    onPressed: _handleCloseClick,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

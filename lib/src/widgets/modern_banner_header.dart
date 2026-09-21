/// ModernBannerHeader - Flutter banner header widget
import 'package:flutter/material.dart';
import '../utils/i18n.dart';
import '../services/banner_theme.dart';

class ModernBannerHeader extends StatefulWidget {
  final String? logoUrl;
  final String orgName;
  final String? bannerTitle;
  final String? disclaimerText;
  final BannerTheme? theme;
  /// Translates dynamic (server-supplied) text via the banner's translation
  /// snapshot. Identity function if omitted.
  final String Function(String)? translate;
  final String selectedLanguage;
  /// Server-driven list of configured language codes. Falls back to the
  /// static en/ta/hi set when empty (no snapshot available).
  final List<String> availableLanguages;
  final Map<String, String> languageLabels;
  final void Function(String)? onLanguageChange;

  const ModernBannerHeader({
    super.key,
    this.logoUrl,
    required this.orgName,
    this.bannerTitle,
    this.disclaimerText,
    this.theme,
    this.translate,
    this.selectedLanguage = 'en',
    this.availableLanguages = const [],
    this.languageLabels = const {},
    this.onLanguageChange,
  });

  @override
  State<ModernBannerHeader> createState() => _ModernBannerHeaderState();
}

class _ModernBannerHeaderState extends State<ModernBannerHeader> {
  String Function(String) get _translate => widget.translate ?? (t) => t;

  // Google Translate translates "[Organization Name]" into the target
  // language's own equivalent bracket phrase (e.g. Tamil:
  // "[நிறுவனத்தின் பெயர்]") — match any [...] bracket group, not just the
  // literal English phrase, so the placeholder still gets replaced after
  // translation. Matches truKIT-NPM's ModernBannerHeader.jsx exactly.
  static final _bracketPattern = RegExp(r'\[[^\]()]+\](?!\()');

  String _processPlaceholder(String? text) {
    return (text ?? '')
        .replaceAll(_bracketPattern, widget.orgName)
        .replaceAll('{{companyName}}', widget.orgName);
  }

  static const _defaultTitleEn = 'Consent by [Organization Name]';
  static const _defaultDisclaimerEn =
      'You have the right to decline consents which you feel are not required by [Organization Name]';

  String _normalizeForCompare(String s) => s
      .replaceAll(RegExp(r'\[[^\]()]+\]|\{\{companyName\}\}'), '{{X}}')
      .trim();

  /// [currentLanguage] as passed to [ModernBannerHeader] — needed so
  /// [I18n.t]'s `lang` override applies even in snapshot-driven mode, where
  /// [I18n.setLocale] is never called (see [_onSelectLanguage]).
  String get _effectiveLanguage =>
      _isSnapshotDriven ? widget.selectedLanguage : I18n.currentLocale.languageCode;

  /// When the admin never customized this field, [raw] is empty — but the
  /// server's translation snapshot still keys its entry by the backend's
  /// *literal default English sentence* (confirmed against a live banner:
  /// `disclaimerText` was `''`, yet `text_map` had a real Bengali/Kannada
  /// translation for "You have the right to decline consents which you feel
  /// are not required by [Organization Name]"). Translating an empty string
  /// always returns identity, so this must feed [defaultEn] to [_translate]
  /// instead of `raw` whenever `raw` is empty — otherwise the snapshot's
  /// translation is never even looked up, and only the static I18n bundle
  /// (which covers just hi/ta) gets a chance, silently showing English for
  /// every other configured language despite the snapshot having the
  /// answer.
  String _resolveWithDefaultFallback(String raw, String defaultEn, String i18nKey) {
    final sourceText = raw.isEmpty ? defaultEn : raw;
    final translated = _translate(sourceText);
    if (translated != sourceText) return _processPlaceholder(translated);
    if (raw.isEmpty || _normalizeForCompare(raw) == _normalizeForCompare(defaultEn)) {
      return I18n.t(i18nKey, params: {'companyName': widget.orgName}, lang: _effectiveLanguage);
    }
    return _processPlaceholder(translated);
  }

  String _getTitle() =>
      _resolveWithDefaultFallback(widget.bannerTitle ?? '', _defaultTitleEn, 'consent_by');

  String _getDisclaimer() =>
      _resolveWithDefaultFallback(widget.disclaimerText ?? '', _defaultDisclaimerEn, 'decline_rights');

  static const _staticLanguageLabels = {'en': 'English', 'ta': 'தமிழ்', 'hi': 'हिंदी'};

  bool get _isSnapshotDriven => widget.availableLanguages.isNotEmpty;

  List<String> get _languages =>
      _isSnapshotDriven ? widget.availableLanguages : const ['en', 'ta', 'hi'];

  String _labelFor(String code) {
    if (_isSnapshotDriven) {
      return widget.languageLabels[code] ?? code;
    }
    return _staticLanguageLabels[code] ?? code;
  }

  void _onSelectLanguage(String code) {
    if (_isSnapshotDriven) {
      widget.onLanguageChange?.call(code);
    } else {
      setState(() => I18n.setLocale(Locale(code)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: I18n.localeNotifier,
      builder: (context, locale, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = widget.theme ?? const BannerTheme(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      textMuted: Color(0xFF6B7280),
      button: Color(0xFF3B82F6),
      buttonText: Color(0xFFFFFFFF),
      border: Color(0xFFE5E7EB),
      fontSize: 16,
    );
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final headerPadding = isMobile ? 16.0 : 24.0;
    final logoSize = isMobile ? 28.0 : 32.0;
    final titleFontSize = isMobile ? 16.0 : 20.0;
    final disclaimerPadding = isMobile ? 12.0 : 16.0;
    final languages = _languages;
    final currentLanguage = _isSnapshotDriven
        ? widget.selectedLanguage
        : I18n.currentLocale.languageCode;

    return Padding(
      padding: EdgeInsets.all(headerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Logo and Language Selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (widget.logoUrl != null) ...[
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.background,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Image.network(
                              widget.logoUrl!,
                              height: logoSize,
                              width: logoSize,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          SizedBox(width: isMobile ? 12 : 16),
                        ],
                        Expanded(
                          child: Text(
                            _getTitle(),
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: theme.text,
                              fontFamily: theme.fontFamily,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (languages.length > 1) ...[
                    SizedBox(width: isMobile ? 8 : 12),
                    PopupMenuButton<String>(
                      onSelected: _onSelectLanguage,
                      itemBuilder: (context) => languages
                          .map((code) => PopupMenuItem(
                                value: code,
                                child: Text(
                                  _labelFor(code),
                                  style: TextStyle(fontFamily: theme.fontFamily),
                                ),
                              ))
                          .toList(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _labelFor(currentLanguage),
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 13,
                                fontWeight: FontWeight.w500,
                                color: theme.textMuted,
                                fontFamily: theme.fontFamily,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: isMobile ? 18 : 20,
                              color: theme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
            ],
          ),

          // Disclaimer Box with improved styling
          // Matches truKIT-NPM's var(--banner-info-bg/border/text) — this was
          // hardcoded blue, ignoring theme entirely.
          Container(
            padding: EdgeInsets.all(disclaimerPadding),
            decoration: BoxDecoration(
              color: theme.infoBg,
              border: Border.all(color: theme.infoBorder, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getDisclaimer(),
              style: TextStyle(
                color: theme.infoText,
                fontSize: isMobile ? 12 : 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
                fontFamily: theme.fontFamily,
              ),
            ),
          ),

          SizedBox(height: isMobile ? 12 : 16),
          Divider(
            height: 1,
            color: theme.border,
            thickness: 1,
          ),
        ],
      ),
    );
  }
}

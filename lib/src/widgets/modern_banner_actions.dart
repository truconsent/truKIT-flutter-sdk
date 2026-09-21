/// ModernBannerActions - Flutter banner actions widget
import 'package:flutter/material.dart';
import '../models/banner.dart';
import '../services/consent_manager.dart';
import '../services/banner_theme.dart';
import '../utils/i18n.dart';

class ModernBannerActions extends StatelessWidget {
  final VoidCallback onRejectAll;
  final VoidCallback onConsentAll;
  final VoidCallback onAcceptSelected;
  /// "Only Necessary" — accept mandatory, decline optional. Matches
  /// truKIT-NPM's ModernBannerActions.jsx, where this is always a distinct,
  /// persistently-rendered third button, never swapped in for
  /// [onAcceptSelected].
  final VoidCallback onAcceptMandatory;
  final List<Purpose> purposes;
  final String? actionButtonText;
  final String? primaryColor;
  final BannerTheme? theme;
  /// Per-notice "Global Settings" overrides for the Reject All button.
  final String? rejectAllColor;
  final String? rejectAllText;
  /// Per-notice "Global Settings" overrides for the Only Necessary button.
  final String? onlyNecessaryColor;
  final String? onlyNecessaryText;
  /// True once the user has toggled any purpose this session — matches
  /// truKIT-NPM's `hasUserInteracted`, which (together with
  /// `anyOptionalAccepted`) decides whether the dynamic third button submits
  /// via [onConsentAll] or [onAcceptSelected].
  final bool hasUserInteracted;
  /// Matches truKIT-NPM's `isBottomReached` — whether the user has scrolled
  /// through every purpose. Defaults to `true` (no gating) for callers that
  /// don't track scroll position, matching truKIT-NPM's simpler templates
  /// (CompactListUI/SplitPaneUI/InlineSingleRowUI), which always pass
  /// `isBottomReached={true}`.
  final bool isBottomReached;
  /// Translates dynamic (server-supplied) text via the banner's translation
  /// snapshot. Falls back to the static I18n bundle, then the original
  /// text, if the snapshot has no match — matches truKIT-NPM's
  /// ModernBannerActions.jsx, which wraps every button label in translate()
  /// (including custom admin-configured text like rejectAllText).
  final String Function(String)? translate;

  const ModernBannerActions({
    super.key,
    required this.onRejectAll,
    required this.onConsentAll,
    required this.onAcceptSelected,
    required this.onAcceptMandatory,
    required this.purposes,
    this.actionButtonText,
    this.primaryColor,
    this.theme,
    this.rejectAllColor,
    this.rejectAllText,
    this.onlyNecessaryColor,
    this.onlyNecessaryText,
    this.hasUserInteracted = false,
    this.isBottomReached = true,
    this.translate,
  });

  /// Admin-configurable button text (action_button_text/reject_all_text/
  /// only_necessary_text) must never be silently swapped for a *different*
  /// generic i18n-bundle string when there's no snapshot translation for it —
  /// matches truKIT-NPM's ModernBannerActions.jsx, which is just
  /// `translate(customText || defaultLiteral)`: snapshot-translate if there's
  /// a match, otherwise show the literal (including the admin's actual
  /// configured override) as-is. [_tr]'s i18nKey fallback is only for truly
  /// static microcopy that has no settings field at all (e.g. "Accept Selected").
  String _trConfigurable(String? customText, String defaultText) {
    final text = customText ?? defaultText;
    return translate != null ? translate!(text) : text;
  }

  Color _parseColor(String? colorString) {
    if (colorString == null) return const Color(0xFF3b82f6);
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF3b82f6);
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
    final resolvedTheme = theme ?? const BannerTheme(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF111827),
      textMuted: Color(0xFF6B7280),
      button: Color(0xFF3B82F6),
      buttonText: Color(0xFFFFFFFF),
      border: Color(0xFFE5E7EB),
      fontSize: 16,
    );
    final anyOptionalAccepted = hasOptionalAccepted(purposes);
    // Legitimate Interest purposes are never toggleable (no switch is even
    // rendered for them — see modern_purpose_card.dart) and can never be
    // "accepted" by the user, so they must not count toward "optional
    // purposes exist" — otherwise a banner with only Legitimate Interest +
    // mandatory purposes (no real optional consent purpose at all) would
    // permanently disable "I Consent", since anyOptionalAccepted can never
    // become true. Matches hasOptionalAccepted's own filter above.
    final optionalPurposes =
        purposes.where((p) => !p.isMandatory && !p.isLegitimate).toList();
    final hasOptional = optionalPurposes.isNotEmpty;
    // Matches truKIT-NPM's ModernBannerActions.jsx exactly: scrolling isn't
    // required when there's only a single optional purpose to review.
    final isSinglePurpose = optionalPurposes.length == 1;
    final scrollRequired = !isSinglePurpose;
    final showScrollWarning = scrollRequired && !isBottomReached;
    final isActionsEnabled = !scrollRequired || isBottomReached;
    // Matches truKIT-NPM's ModernBannerActions.jsx exactly: the third
    // button's *label* never changes ("I Consent"/actionButtonText, always)
    // — only its handler switches, once the user has an optional purpose
    // accepted or has interacted with a toggle this session.
    final isIConsentEnabled = isActionsEnabled && (hasOptional ? anyOptionalAccepted : true);
    final dynamicButtonLabel = _trConfigurable(actionButtonText, 'I Consent');

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 380;

    final primaryButtonColor = _parseColor(primaryColor);
    final resolvedRejectColor = rejectAllColor != null
        ? _parseColor(rejectAllColor)
        : const Color(0xFFDC2626); // NPM default: solid red
    final resolvedOnlyNecessaryColor = onlyNecessaryColor != null
        ? _parseColor(onlyNecessaryColor)
        : const Color(0xFFF97316); // NPM default: solid orange
    final fontFamily = resolvedTheme.fontFamily;

    void handleThirdButtonPress() {
      if (anyOptionalAccepted || hasUserInteracted) {
        onAcceptSelected();
      } else {
        onConsentAll();
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: resolvedTheme.background,
        border: Border(
          top: BorderSide(
            color: resolvedTheme.border,
            width: 1,
          ),
        ),
      ),
      child: isSmallMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showScrollWarning)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _trConfigurable(null, 'Please scroll to the bottom to enable actions'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: fontFamily),
                    ),
                  ),
                // Reject All Button — solid, matches truKIT-NPM's default.
                // `disabledBackgroundColor`/`disabledForegroundColor` must be
                // set explicitly: ElevatedButton.styleFrom otherwise ignores
                // `backgroundColor` entirely once `onPressed` is null and
                // substitutes Material's own near-transparent disabled
                // overlay, which renders as an invisible button on a dark
                // modal background.
                ElevatedButton(
                  onPressed: isActionsEnabled ? onRejectAll : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolvedRejectColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: resolvedRejectColor.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _trConfigurable(rejectAllText, 'Reject All'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Only Necessary Button — persistent, always rendered
                // (matches truKIT-NPM: never swapped out for a dynamic
                // "Accept Selected" state).
                ElevatedButton(
                  onPressed: isActionsEnabled ? onAcceptMandatory : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resolvedOnlyNecessaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: resolvedOnlyNecessaryColor.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _trConfigurable(onlyNecessaryText, 'Only Necessary'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamily,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                // Dynamic third button (I Consent / Accept Selected) — label
                // never changes, only the handler it calls.
                ElevatedButton(
                  onPressed: isIConsentEnabled ? handleThirdButtonPress : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButtonColor,
                    foregroundColor: resolvedTheme.buttonText,
                    disabledBackgroundColor: resolvedTheme.border,
                    disabledForegroundColor: resolvedTheme.buttonText.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    dynamicButtonLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showScrollWarning)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _trConfigurable(null, 'Please scroll to the bottom to enable actions'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: fontFamily),
                    ),
                  ),
                // Dynamic third button (I Consent / Accept Selected) —
                // Primary, Full Width.
                ElevatedButton(
                  onPressed: isIConsentEnabled ? handleThirdButtonPress : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButtonColor,
                    foregroundColor: resolvedTheme.buttonText,
                    disabledBackgroundColor: resolvedTheme.border,
                    disabledForegroundColor: resolvedTheme.buttonText.withValues(alpha: 0.7),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 28,
                      vertical: isMobile ? 13 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    dynamicButtonLabel,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 10 : 12),
                // Secondary buttons (Reject All & Only Necessary) — both
                // solid and persistent, matching truKIT-NPM.
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isActionsEnabled ? onRejectAll : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: resolvedRejectColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: resolvedRejectColor.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _trConfigurable(rejectAllText, 'Reject All'),
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isActionsEnabled ? onAcceptMandatory : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: resolvedOnlyNecessaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: resolvedOnlyNecessaryColor.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 12 : 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _trConfigurable(onlyNecessaryText, 'Only Necessary'),
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: fontFamily,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

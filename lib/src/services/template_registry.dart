/// Banner template registry — mirrors the NPM SDK's
/// `src/runtime/templateRegistry.js`, mapping a `bannerSettings
/// .generalNoticeTemplate` string to one of the SDK's selectable banner
/// layouts.
enum BannerTemplateKey {
  /// Header + tabbed (Informational/Consent/Re-consent) or grouped
  /// (Necessary/Optional) purpose list, depending on purpose composition.
  /// Also used for the (effectively legacy/unreachable in the NPM SDK too)
  /// `center_modal` key — the NPM SDK collapses `center_modal` into the same
  /// tabbed rendering by default, and this SDK mirrors that.
  tabbedBanner,

  /// Simple stacked purpose-card list + Only Necessary / Save Preferences /
  /// Accept All buttons (no Reject All).
  preferencesModal,

  /// The floating cookie-consent card layout (accordion sections for
  /// Purposes / Data Elements / Processing Activities).
  floatingCard,

  /// Read-only purpose cards + a single acknowledge button, regardless of
  /// purpose composition.
  noticeOnly,

  /// One row per purpose with all detail inline (no expand/collapse).
  inlineSingleRow,

  /// Accordion rows, one per purpose, collapsed by default.
  generalCompactList,

  /// A selectable purpose list alongside a detail pane for the active
  /// purpose.
  generalSplitPane,
}

/// Resolves a `bannerSettings.generalNoticeTemplate` string (or the banner's
/// `consentType`) to a [BannerTemplateKey]. Unrecognized or absent values
/// fall back to [BannerTemplateKey.tabbedBanner], matching
/// `templateRegistry.js`'s `getTemplate()` fallback to `center_modal`
/// (which itself resolves to the tabbed rendering).
BannerTemplateKey resolveTemplateKey(String? rawKey, {String? consentType}) {
  if (consentType == 'cookie_consent' &&
      (rawKey == null || rawKey.isEmpty)) {
    return BannerTemplateKey.floatingCard;
  }
  switch (rawKey) {
    case 'preferences_modal':
      return BannerTemplateKey.preferencesModal;
    case 'floating_card':
      return BannerTemplateKey.floatingCard;
    case 'notice_only':
      return BannerTemplateKey.noticeOnly;
    case 'inline_single_row':
      return BannerTemplateKey.inlineSingleRow;
    case 'general_compact_list':
      return BannerTemplateKey.generalCompactList;
    case 'general_split_pane':
      return BannerTemplateKey.generalSplitPane;
    case 'tabbed_banner':
    case 'center_modal':
    default:
      return BannerTemplateKey.tabbedBanner;
  }
}

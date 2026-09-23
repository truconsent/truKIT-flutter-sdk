# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.8] - 2026-09-23

### Fixed
- `I Consent` being disabled whenever every optional purpose was declined, requiring at least one optional acceptance on top of the normal scroll-gating — Reject All and Only Necessary never had this extra requirement. Optional purposes are the user's free choice to accept or decline; Only Necessary already exists as the dedicated "decline everything optional" action, so gating I Consent on an optional acceptance just made it redundant with Only Necessary and confusingly disabled in the all-declined state. Matches `@truconsent/consent-notice` 0.0.37 and truKIT-react-native

### Added
- A "Profile Based" purpose group on the Consent tab, matching `@truconsent/consent-notice` and truKIT-react-native — dynamic (`isDynamic`) purposes were previously silently folded into "Necessary" or "Optional" with no group of their own. Purely a rendering split of the existing purpose list (`Necessary → Profile Based → Optional`); does not touch `UIState.mandatoryConsentPurposes`/H-Case detection, which intentionally still consider all mandatory purposes regardless of `isDynamic`

## [0.1.7] - 2026-09-23

### Changed
- The Tabbed Banner's active tab label and indicator now use Primary Text Color (`theme.text`) instead of Button Color — Button Color is picked for contrast against a button's own background, not the banner's background, so a light banner paired with a bright accent Button Color read as low-contrast for the active tab. Primary Text Color is guaranteed legible against the banner's own background. Matches `@truconsent/consent-notice` 0.0.36 and truKIT-react-native

## [0.1.6] - 2026-09-21

Three-way parity audit against `@truconsent/consent-notice` (the reference web SDK) — Consent Notice, Rights Center, and their underlying logic, not just appearance.

### Fixed
- `ModernBannerActions`'s "Only Necessary" button disappearing once any optional purpose was toggled on, and its default colors not matching the reference (Reject All/Only Necessary are now always-visible, solid red/orange buttons; the third button dynamically submits "Accept All" or "Accept Selected" without ever changing its own label)
- "I Consent"/Reject All/Only Necessary being clickable immediately, without the user having scrolled through every purpose card first — they're now gated on scroll position (skipped only when there's a single optional purpose), matching the reference exactly, including the "Please scroll to the bottom to enable actions" warning text
- Legitimate Interest purposes (no toggle, no accept/decline concept) being counted as "optional purposes" in that same gating logic — a banner mixing Legitimate Interest + mandatory + exactly one real optional purpose could leave "I Consent" permanently disabled
- The disabled state of Reject All/Only Necessary/"I Consent" rendering as an invisible button on a dark theme — Flutter's `ElevatedButton.styleFrom` silently ignores `backgroundColor` once `onPressed` is null and substitutes Material's own near-transparent overlay unless `disabledBackgroundColor`/`disabledForegroundColor` are set explicitly
- The purpose toggle switch rendering a visibly larger thumb when on than when off (Material3's own Switch spec, not something `thumbColor` controls) — forced the classic Material2 Switch style so the thumb stays a constant size in both states, matching the reference SDK's plain CSS toggle
- The toggle switch thumb using the Primary Text Color instead of the Primary Button Text Color
- The Data Processors section splitting Legal Entities/Tools into two separately-labeled subsections instead of one flat combined list
- The consent notice's disclaimer box being hardcoded blue regardless of the configured theme — now derived the same way the reference SDK's fixed light/dark presets are, based on whether the configured background is light or dark
- The footer's inline links using the button color instead of the primary color
- The H-Case mandatory-purpose-declined intercept firing for Legitimate Interest purposes, which have no accept/decline concept to intercept
- Rights Center's Access/Delete request Cancel buttons (and Nominee edit form's Cancel) using a destructive red style — only the actual destructive action button should be red, not Cancel
- The Grievance chat's non-user message bubble using a hardcoded light-gray background instead of the configured theme
- The tab bar's inactive-tab text color and divider color not reading from the configured theme

### Added
- Grievance chat header Open/Resolved status pill (Rights Center)

## [0.1.5] - 2026-09-18

### Fixed
- "Common Appearance" theme colors (background, button, text) and font family not applying correctly to the consent notice
- Disclaimer/title and decline-rights text not translating in non-English languages
- Rights Center Nominee "Edit" button using a hardcoded purple instead of the configured button theme colors
- Data Elements/Data Processors/Tools pills not using the configured background and secondary text colors
- Font family not applied consistently across all consent notice text
- "Allow Only Necessary" incorrectly submitting/reporting `approved` instead of `partial_consent`
- Banner auto-hiding and firing a false `no_action`/rejection close on every subsequent app open after a user had already completed consent once
- Mandatory-purpose badge showing "Mandatory" instead of "Necessary"

### Added
- Bundled real font files for every "Font Type" option in the admin dashboard, registered in `pubspec.yaml`'s `fonts:` section (no consuming-app changes required)

### Changed
- Redesigned consent notice buttons and language picker for mobile-friendly, responsive layout

## [0.1.4] - 2026-05-13

### Fixed
- Native Rights Center (`NativeRightCenter`) no longer hardcoded its tab bar, active-tab indicator, headings, and buttons to fixed purple/dark colors — now driven by the fetched `RightsCenterSettings` (background, primary/secondary text, button colors)
- Removed a duplicate, unused `Scaffold`/`_parseColor` in `NativeRightCenter`/`BannerUI` left over from an earlier theming pass

### Changed
- `RightsCenterApi.getUserConsentsFlat` now calls `GET /api/v1/internal/consent/user/{userId}` (consent-scope only) instead of the two-step admin-scoped `GET /api/v1/internal/consent` + user-consent-status flow

## [0.1.3] - 2026-05-12

### Changed
- Version bump only, no functional changes

## [0.1.1] - 2025-02-03

### Fixed
- Removed unused fields and imports to fix linter warnings
- Replaced deprecated `withOpacity()` with `withValues(alpha:)` for Color
- Replaced deprecated `activeColor` with `activeThumbColor` for Switch
- Added comprehensive dartdoc comments to public API (20%+ coverage)

### Changed
- Improved code quality and static analysis scores

## [0.1.0] - 2025-02-03

### Added
- Initial release of TruConsent Flutter SDK
- Native Flutter widgets for consent banner display
- TruConsentModal widget for modal-based consent collection
- NativeRightCenter widget for Rights Center functionality
- Support for multiple languages (English, Hindi, Tamil)
- Consent management and tracking
- Integration with TruConsent API
- Support for GDPR and privacy compliance features

### Features
- Consent banner UI with customizable styling
- Purpose-based consent selection
- Cookie consent management
- Rights Center with tabs (Consent, Rights, Transparency, DPO, Nominee, Grievance)
- API integration for consent submission and retrieval
- Internationalization (i18n) support


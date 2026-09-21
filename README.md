# truconsent_consent_notice_flutter

Flutter SDK for TruConsent consent banner. This package provides native Flutter widgets for displaying and managing consent banners in Flutter applications.

## 📚 Documentation

**👉 [Complete Integration Guide](INTEGRATION_GUIDE.md)** - Step-by-step guide with real-world examples from the Mars Money Flutter app.

The integration guide includes:
- Detailed installation instructions
- Configuration setup
- Consent Modal integration patterns
- Rights Center implementation
- Complete code examples
- Troubleshooting guide
- Best practices

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  truconsent_consent_notice_flutter: ^0.1.5
```

Then run:

```bash
flutter pub get
```

## Usage

```dart
import 'package:truconsent_consent_notice_flutter/truconsent_consent_banner_flutter.dart';

TruConsentModal(
  apiKey: 'your-api-key',
  organizationId: 'your-org-id',
  bannerId: 'your-banner-id',
  userId: 'user-id',
  onClose: (action) {
    print('Consent action: $action');
  },
)
```

## API

### TruConsentModal

Main widget for displaying the consent banner modal.

#### Parameters

- `apiKey` (String, required): API key for authentication
- `organizationId` (String, required): Organization ID
- `bannerId` (String, required): Banner/Collection Point ID
- `userId` (String, required): User ID for consent tracking
- `apiBaseUrl` (String, optional): Base URL for API
- `logoUrl` (String, optional): Company logo URL
- `companyName` (String, optional): Company name
- `onClose` (Function, optional): Callback when modal closes

## Version History

### 0.1.6 (Latest)
- Three-way parity audit against `@truconsent/consent-notice` (the reference web SDK) — action buttons, scroll-gating, Legitimate Interest handling, Data Processors grouping, disclaimer box theming, toggle thumb color, Rights Center chat status pill, and more
- See [CHANGELOG.md](CHANGELOG.md) for full details

### 0.1.5
- Fixed theme colors, font family, and translation gaps in the consent notice
- Fixed Nominee Edit button and data pills not using configured theme colors
- Fixed "Allow Only Necessary" wrongly reporting `approved`
- Fixed false auto-hide rejection on repeat app opens
- Redesigned buttons/language picker for mobile
- Bundled fonts for every admin-configurable "Font Type"
- See [CHANGELOG.md](CHANGELOG.md) for full details

### 0.1.4
- `NativeRightCenter` now uses the fetched Rights Center theme colors instead of hardcoded purple/dark colors
- `RightsCenterApi.getUserConsentsFlat` switched to the consent-scoped `GET /api/v1/internal/consent/user/{userId}` endpoint

### 0.1.3
- Version bump only, no functional changes

### 0.1.2
- Comprehensive documentation improvements
- Added dartdoc comments to all public APIs (20%+ coverage)
- Fixed dangling library doc comments
- Enhanced widget, model, and service documentation
- Improved pub.dev analysis scores

### 0.1.1
- Fixed code warnings and linter issues
- Replaced deprecated `withOpacity()` with `withValues(alpha:)`
- Replaced deprecated `activeColor` with `activeThumbColor`
- Improved code quality and static analysis scores

### 0.1.0
- Initial release of TruConsent Flutter SDK
- Native Flutter widgets for consent banner display
- TruConsentModal widget for modal-based consent collection
- NativeRightCenter widget for Rights Center functionality
- Support for multiple languages (English, Hindi, Tamil)
- Consent management and tracking
- Integration with TruConsent API
- Support for GDPR and privacy compliance features

## Publishing

This package publishes to [pub.dev](https://pub.dev/packages/truconsent_consent_notice_flutter) under the `truconsent` publisher/organization. To ship a new version:

```bash
# 1. Log in (opens a browser for Google OAuth — must be an account with
#    publishing rights on the truconsent pub.dev organization)
dart pub login

# 2. Bump the version in pubspec.yaml, add a matching CHANGELOG.md entry and
#    README.md "Version History" line, then verify everything still passes
flutter analyze lib/
flutter test

# 3. Dry-run — validates the package (file list, size, pubspec fields) and
#    flags issues without actually publishing anything
dart pub publish --dry-run

# 4. Publish for real (irreversible — a published version can never be
#    deleted or overwritten, only marked "discontinued")
dart pub publish
```

## License

MIT


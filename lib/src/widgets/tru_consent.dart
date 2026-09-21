/// TruConsent - Auto-showing consent modal wrapper
///
/// Displays a modal popup immediately on mount with loading state.
/// The modal fetches banner data and shows consent UI.
///
/// This is a convenience wrapper around TruConsentModal that automatically
/// shows the modal when the widget is mounted.
import 'package:flutter/material.dart';
import 'tru_consent_modal.dart';
import '../models/banner.dart';

class TruConsent extends StatelessWidget {
  final String? apiKey;
  final String organizationId;
  final String bannerId;
  final String userId;
  final String? assetId;
  final String? apiBaseUrl;
  final String? logoUrl;
  final String companyName;
  final String? token;
  final String? authToken;
  final Function(ConsentAction)? onClose;
  final Function(List<Purpose>, ConsentAction)? onSubmit;

  const TruConsent({
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
          'TruConsent requires either apiKey or token/authToken',
        );

  @override
  Widget build(BuildContext context) {
    // Auto-show modal on mount - TruConsentModal handles loading state internally
    return TruConsentModal(
      apiKey: apiKey,
      organizationId: organizationId,
      bannerId: bannerId,
      userId: userId,
      assetId: assetId,
      apiBaseUrl: apiBaseUrl,
      logoUrl: logoUrl,
      companyName: companyName,
      token: token,
      authToken: authToken,
      onClose: onClose,
      onSubmit: onSubmit,
    );
  }
}

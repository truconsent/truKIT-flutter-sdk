import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/banner.dart';
import 'api_casing.dart';

/// Normalizes a raw banner API response so every field is readable under
/// either camelCase or snake_case, regardless of which convention the
/// backend serving this deployment actually uses. See api_casing.dart for
/// why this is necessary — trukit-dev.truconsent.io (this package's own
/// default API) returns pure camelCase at every level (banner,
/// bannerSettings, purposes, and purposes' nested dataElements/tools/
/// legalEntities/processingActivities).
Map<String, dynamic> _normalizeBannerJson(Map<String, dynamic> data) {
  final banner = withCasingAliases(data);

  final rawSettings = banner['banner_settings'] ?? banner['bannerSettings'];
  if (rawSettings is Map<String, dynamic>) {
    final settings = withCasingAliases(rawSettings);
    banner['banner_settings'] = settings;
    banner['bannerSettings'] = settings;
  }

  final rawTranslations = banner['translations_snapshot'] ?? banner['translationsSnapshot'];
  if (rawTranslations != null) {
    banner['translations_snapshot'] = rawTranslations;
    banner['translationsSnapshot'] = rawTranslations;
  }

  final rawPurposes = banner['purposes'];
  if (rawPurposes is List) {
    banner['purposes'] = rawPurposes.map((p) {
      if (p is! Map<String, dynamic>) return p;
      final purpose = withCasingAliases(p);
      for (final key in ['data_elements', 'tools', 'legal_entities', 'processing_activities']) {
        if (purpose[key] is List) {
          purpose[key] = withCasingAliasesList(purpose[key] as List);
        }
      }
      return purpose;
    }).toList();
  }

  final rawReconsentPurposes = banner['reconsent_purposes'] ?? banner['reconsentPurposes'];
  if (rawReconsentPurposes is List) {
    final normalized = withCasingAliasesList(rawReconsentPurposes);
    banner['reconsent_purposes'] = normalized;
    banner['reconsentPurposes'] = normalized;
  }

  return banner;
}

String _bodyPreview(String body, {int max = 240}) {
  if (body.length <= max) return body;
  return '${body.substring(0, max)}...';
}

/// Default base URL for the TruConsent API
const String defaultApiBaseUrl = 'https://trukit-dev.truconsent.io';

/// Builds the auth-related headers for a request: an `Authorization: Bearer`
/// header when a JWT [token]/[authToken] is available (preferred), otherwise
/// an `X-API-Key` header. Mirrors the NPM and React Native SDKs' auth
/// precedence (token/authToken takes priority over apiKey).
Map<String, String> _authHeaders({String? apiKey, String? token}) {
  if (token != null && token.isNotEmpty) {
    return {'Authorization': 'Bearer $token'};
  }
  if (apiKey != null && apiKey.isNotEmpty) {
    return {'X-API-Key': apiKey};
  }
  return {};
}

/// Fetches banner configuration from the TruConsent API.
///
/// URL: GET {apiUrl}/api/v1/internal/consent/{assetId}/{bannerId}?userId={userId}
/// or:  GET {apiUrl}/api/v1/internal/consent/{bannerId}?userId={userId}
///
/// Authenticates with either [apiKey] or a JWT bearer [token]/[authToken]
/// (one of the two is required); [token] takes precedence if both are set.
Future<Banner> fetchBanner({
  required String bannerId,
  String? apiKey,
  required String organizationId,
  String? userId,
  String? assetId,
  String? token,
  String? authToken,
  String apiBaseUrl = defaultApiBaseUrl,
}) async {
  if (bannerId.isEmpty) {
    throw Exception('Missing bannerId');
  }
  final effectiveToken = (token != null && token.isNotEmpty) ? token : authToken;
  if ((apiKey == null || apiKey.isEmpty) &&
      (effectiveToken == null || effectiveToken.isEmpty)) {
    throw Exception(
        'Missing apiKey/token - authentication is required (provide apiKey or token)');
  }
  if (organizationId.isEmpty) {
    throw Exception(
        'Missing organizationId - Organization ID is required for authentication');
  }

  final baseWithPath = assetId != null && assetId.isNotEmpty
      ? '$apiBaseUrl/api/v1/internal/consent/$assetId/$bannerId'
      : '$apiBaseUrl/api/v1/internal/consent/$bannerId';

  final queryParams = <String, String>{};
  if (userId != null && userId.isNotEmpty) {
    queryParams['userId'] = userId;
  }

  final uri = Uri.parse(baseWithPath).replace(queryParameters: queryParams.isEmpty ? null : queryParams);
  debugPrint('Fetching banner from: $uri');

  // Backend OriginEnforcementMiddleware blocks /api/v1/internal/consent* unless
  // the request looks like a browser (Sec-Fetch-Site or Mozilla User-Agent).
  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      ..._authHeaders(apiKey: apiKey, token: effectiveToken),
      'X-Org-Id': organizationId,
      if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      'Sec-Fetch-Site': 'cross-site',
      'User-Agent': 'Mozilla/5.0 TruConsent-Flutter-SDK/1.0',
      // Do NOT send Origin — backend defaults to COLLECTOR_BASE_URL which is always authorized.
    },
  );

  debugPrint('Banner API response status: ${response.statusCode}');

  if (response.statusCode == 401) {
    throw Exception('Unauthorized - Invalid or missing API key');
  }
  if (response.statusCode == 403) {
    throw Exception('Forbidden - This domain is not authorized');
  }
  if (response.statusCode == 429) {
    throw Exception('Rate limit exceeded');
  }
  if (response.statusCode == 404) {
    throw Exception(
        'Banner not found - Banner ID "$bannerId" does not exist or is not accessible');
  }

  final contentType = response.headers['content-type'] ?? '';
  final isJson = contentType.contains('application/json');
  final bodyTrimmed = response.body.trimLeft();
  final isHtml = bodyTrimmed.startsWith('<!DOCTYPE') ||
      bodyTrimmed.startsWith('<!doctype') ||
      bodyTrimmed.startsWith('<html') ||
      contentType.contains('text/html');

  if (response.statusCode != 200) {
    String errorMessage = 'Failed to load banner (${response.statusCode})';
    try {
      if (isJson) {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        errorMessage = errorData['message'] ?? errorData['error'] ?? errorMessage;
      } else if (isHtml) {
        final match = RegExp(r'<p>(.*?)</p>', caseSensitive: false)
            .firstMatch(response.body);
        if (match?.group(1) != null) {
          errorMessage = match!.group(1)!.trim();
        }
      }
    } catch (e) {
      debugPrint('Error parsing error response: $e');
    }
    debugPrint(
        'Banner fetch failed | status=${response.statusCode} | preview=${_bodyPreview(response.body)}');
    throw Exception(errorMessage);
  }

  if (isHtml) {
    String errorMessage =
        'Server returned an error page instead of banner data (status ${response.statusCode}).';
    try {
      final match = RegExp(r'<p>(.*?)</p>', caseSensitive: false)
          .firstMatch(response.body);
      if (match?.group(1) != null) {
        errorMessage = match!.group(1)!.trim();
      }
    } catch (e) {
      debugPrint('Error extracting error from HTML: $e');
    }
    throw Exception(errorMessage);
  }

  try {
    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    // Support both top-level and nested `data` envelope
    final bannerJson = jsonData.containsKey('data') && jsonData['data'] is Map
        ? (jsonData['data'] as Map<String, dynamic>)
        : jsonData;
    return Banner.fromJson(_normalizeBannerJson(bannerJson));
  } catch (e) {
    debugPrint('Error parsing JSON response: $e');
    throw Exception(
        'Failed to parse banner data. The server may have returned an error. Please check your API credentials and banner ID.');
  }
}

/// Submits user consent choices to the TruConsent API.
///
/// URL: POST {apiUrl}/api/v1/internal/consent/{collectionPointId}
Future<Map<String, dynamic>> submitConsent({
  required String collectionPointId,
  required String userId,
  required List<Purpose> purposes,
  required ConsentAction action,
  String? apiKey,
  required String organizationId,
  String? requestId,
  String? assetId,
  String? sessionId,
  String? buttonUsed,
  String? reconsentCampaignId,
  String? expiryReconsentRequestId,
  int? bannerFetchedAt,
  int? bannerDisplayedAt,
  int? userInteractionAt,
  String? token,
  String? authToken,
  String apiBaseUrl = defaultApiBaseUrl,
}) async {
  if (collectionPointId.isEmpty) {
    throw Exception('Missing collectionPointId');
  }
  final effectiveToken = (token != null && token.isNotEmpty) ? token : authToken;
  if ((apiKey == null || apiKey.isEmpty) &&
      (effectiveToken == null || effectiveToken.isEmpty)) {
    throw Exception('Missing apiKey/token - authentication is required (provide apiKey or token)');
  }
  if (organizationId.isEmpty) {
    throw Exception('Missing organizationId');
  }

  final url = Uri.parse('$apiBaseUrl/api/v1/internal/consent/$collectionPointId');
  debugPrint('Submitting consent to: $url');
  debugPrint('Action: ${action.value}');

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final body = <String, dynamic>{
    'userId': userId,
    'requestId': requestId,
    'assetId': assetId ?? '',
    'consentLanguage': 'en',
    'collectionPointId': collectionPointId,
    'collectionPointVersion': 'v1.0',
    'consentTimestamp': now,
    'source': 'flutter',
    'purposes': purposes.map((p) => p.toJson()).toList(),
    'action': action.value,
    'metadata': {
      'sessionId': sessionId,
      'button_used': buttonUsed,
      'collection_point_version': 'v1.0',
      'reconsent_campaign_id': reconsentCampaignId,
      'expiry_reconsent_request_id': expiryReconsentRequestId,
      'performance': {
        'banner_fetched_at': bannerFetchedAt,
        'banner_displayed_at': bannerDisplayedAt,
        'user_interaction_at': userInteractionAt ?? now,
        'notice_logged_at': action == ConsentAction.noticeShown ? now : null,
      },
    },
  };

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      ..._authHeaders(apiKey: apiKey, token: effectiveToken),
      'X-Org-Id': organizationId,
    },
    body: json.encode(body),
  );

  debugPrint('Consent API response status: ${response.statusCode}');

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to submit consent (${response.statusCode})');
  }

  try {
    return json.decode(response.body) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

/// Sends suppression update (fire-and-forget) after any action where purposes are declined.
///
/// URL: POST {apiUrl}/api/v1/internal/consent/suppression
Future<void> sendSuppressionUpdate({
  required String userId,
  required List<String> declinedPurposeIds,
  String? apiKey,
  required String organizationId,
  String? token,
  String? authToken,
  String apiBaseUrl = defaultApiBaseUrl,
}) async {
  if (declinedPurposeIds.isEmpty) return;

  final effectiveToken = (token != null && token.isNotEmpty) ? token : authToken;
  final url = Uri.parse('$apiBaseUrl/api/v1/internal/consent/suppression');
  try {
    await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders(apiKey: apiKey, token: effectiveToken),
        'X-Org-Id': organizationId,
      },
      body: json.encode({
        'userId': userId,
        'declinedPurposeIds': declinedPurposeIds,
      }),
    );
  } catch (e) {
    // fire-and-forget, swallow errors
    debugPrint('Suppression update failed (ignored): $e');
  }
}

/// Sends a notice_shown event for notice-only banners.
Future<Map<String, dynamic>> sendNoticeShown({
  required String collectionPointId,
  required String userId,
  required List<Purpose> purposes,
  String? apiKey,
  required String organizationId,
  String? requestId,
  String? assetId,
  String? sessionId,
  int? bannerFetchedAt,
  int? bannerDisplayedAt,
  String? reconsentCampaignId,
  String? token,
  String? authToken,
  String apiBaseUrl = defaultApiBaseUrl,
}) async {
  final noticePurposes = purposes.map((p) => p.copyWith(consented: 'shown')).toList();
  return submitConsent(
    collectionPointId: collectionPointId,
    userId: userId,
    purposes: noticePurposes,
    action: ConsentAction.noticeShown,
    apiKey: apiKey,
    organizationId: organizationId,
    requestId: requestId,
    assetId: assetId,
    sessionId: sessionId,
    buttonUsed: 'i_understand',
    bannerFetchedAt: bannerFetchedAt,
    bannerDisplayedAt: bannerDisplayedAt,
    token: token,
    authToken: authToken,
    apiBaseUrl: apiBaseUrl,
  );
}

/// Rights Center API Service
/// Handles all API calls for the Rights Center feature
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConsentGroup {
  final String collection_point;
  final String title;
  final List<Purpose> purposes;
  final List<DataElement>? data_elements;
  final bool? shown_to_principal;

  ConsentGroup({
    required this.collection_point,
    required this.title,
    required this.purposes,
    this.data_elements,
    this.shown_to_principal,
  });

  factory ConsentGroup.fromJson(Map<String, dynamic> json) {
    return ConsentGroup(
      collection_point: json['collection_point'] ?? '',
      title: json['title'] ?? '',
      purposes: (json['purposes'] as List<dynamic>?)
              ?.map((p) => Purpose.fromJson(p))
              .toList() ??
          [],
      data_elements: (json['data_elements'] as List<dynamic>?)
          ?.map((e) => DataElement.fromJson(e))
          .toList(),
      shown_to_principal: json['shown_to_principal'] as bool?,
    );
  }
}

class Purpose {
  final String id;
  final String name;
  final String description;
  final String expiry_period;
  final bool is_mandatory;
  final String consented; // 'accepted', 'declined', 'pending'
  final bool? isLegitimate;
  final List<DataElement>? dataElements;
  final List<String>? processingActivities;
  final String? type; // 'Mandatory' | 'Optional'
  final String? timestamp;

  Purpose({
    required this.id,
    required this.name,
    required this.description,
    required this.expiry_period,
    required this.is_mandatory,
    required this.consented,
    this.isLegitimate,
    this.dataElements,
    this.processingActivities,
    this.type,
    this.timestamp,
  });

  factory Purpose.fromJson(Map<String, dynamic> json) {
    return Purpose(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      expiry_period: json['expiry_period'] ?? '',
      is_mandatory: json['is_mandatory'] ?? false,
      consented: json['consented'] ?? 'pending',
      isLegitimate: json['isLegitimate'] as bool?,
      dataElements: (json['dataElements'] as List<dynamic>?)
          ?.map((e) => DataElement.fromJson(e))
          .toList(),
      processingActivities: (json['processingActivities'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      type: json['type'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'consented': consented,
    };
  }
}

class DataElement {
  final String name;
  final String description;

  DataElement({
    required this.name,
    required this.description,
  });

  factory DataElement.fromJson(Map<String, dynamic> json) {
    return DataElement(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class DPOInfo {
  final String? full_name;
  final String? email;
  final String? appointment_date;
  final String? qualifications;
  final String? responsibilities;
  final String? working_hours;
  final String? response_time;

  DPOInfo({
    this.full_name,
    this.email,
    this.appointment_date,
    this.qualifications,
    this.responsibilities,
    this.working_hours,
    this.response_time,
  });

  factory DPOInfo.fromJson(Map<String, dynamic> json) {
    return DPOInfo(
      full_name: json['full_name'],
      email: json['email'],
      appointment_date: json['appointment_date'],
      qualifications: json['qualifications'],
      responsibilities: json['responsibilities'],
      working_hours: json['working_hours'],
      response_time: json['response_time'],
    );
  }
}

class RightsCenterSettings {
  /// 'sso' (default; the host app already knows the user's id) or
  /// 'non_sso' (the Rights Center itself must authenticate the user via a
  /// phone + OTP flow before showing any tab content).
  final String accessMode;
  final String backgroundColor;
  final String primaryTextColor;
  final String secondaryTextColor;
  final String buttonColor;
  final String buttonTextColor;
  final String fontFamily;
  final bool showConsentsSection;
  final bool showRightsSection;
  final bool showNomineesSection;
  final bool showTransparencySection;
  final bool showDpoSection;
  final bool showGrievanceSection;
  final String grievanceMode; // 'truconsent' | 'external'
  final String grievanceExternalUrl;
  final String consentsSectionTitle;
  final String rightsSectionTitle;
  final String nomineesSectionTitle;
  final String transparencyDescription;
  final bool dpoQualificationsEnabled;
  final bool dpoResponsibilitiesEnabled;
  final bool dpoWorkingHoursEnabled;
  final bool dpoResponseTimeEnabled;

  const RightsCenterSettings({
    this.accessMode = 'sso',
    required this.backgroundColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.fontFamily,
    required this.showConsentsSection,
    required this.showRightsSection,
    required this.showNomineesSection,
    required this.showTransparencySection,
    required this.showDpoSection,
    required this.showGrievanceSection,
    required this.grievanceMode,
    required this.grievanceExternalUrl,
    required this.consentsSectionTitle,
    required this.rightsSectionTitle,
    required this.nomineesSectionTitle,
    required this.transparencyDescription,
    required this.dpoQualificationsEnabled,
    required this.dpoResponsibilitiesEnabled,
    required this.dpoWorkingHoursEnabled,
    required this.dpoResponseTimeEnabled,
  });

  static RightsCenterSettings get defaults => const RightsCenterSettings(
        accessMode: 'sso',
        backgroundColor: '#020617',
        primaryTextColor: '#e5e7eb',
        secondaryTextColor: '#9ca3af',
        buttonColor: '#65a30d',
        buttonTextColor: '#0b1120',
        fontFamily: 'sans-serif',
        showConsentsSection: true,
        showRightsSection: true,
        showNomineesSection: true,
        showTransparencySection: false,
        showDpoSection: false,
        showGrievanceSection: true,
        grievanceMode: 'truconsent',
        grievanceExternalUrl: '',
        consentsSectionTitle: 'Consents',
        rightsSectionTitle: 'Your Data Rights',
        nomineesSectionTitle: 'Nominees',
        transparencyDescription: '',
        dpoQualificationsEnabled: true,
        dpoResponsibilitiesEnabled: true,
        dpoWorkingHoursEnabled: true,
        dpoResponseTimeEnabled: true,
      );

  factory RightsCenterSettings.fromJson(Map<String, dynamic> json) {
    final d = defaults;
    return RightsCenterSettings(
      accessMode: json['access_mode'] ?? json['accessMode'] ?? d.accessMode,
      backgroundColor: json['background_color'] ?? json['backgroundColor'] ?? d.backgroundColor,
      primaryTextColor: json['primary_text_color'] ?? json['primaryTextColor'] ?? d.primaryTextColor,
      secondaryTextColor: json['secondary_text_color'] ?? json['secondaryTextColor'] ?? d.secondaryTextColor,
      buttonColor: json['button_color'] ?? json['buttonColor'] ?? d.buttonColor,
      buttonTextColor: json['button_text_color'] ?? json['buttonTextColor'] ?? d.buttonTextColor,
      fontFamily: json['font_family'] ?? json['fontFamily'] ?? d.fontFamily,
      showConsentsSection: json['show_consents_section'] ?? json['showConsentsSection'] ?? d.showConsentsSection,
      showRightsSection: json['show_rights_section'] ?? json['showRightsSection'] ?? d.showRightsSection,
      showNomineesSection: json['show_nominees_section'] ?? json['showNomineesSection'] ?? d.showNomineesSection,
      showTransparencySection: json['show_transparency_section'] ?? json['showTransparencySection'] ?? d.showTransparencySection,
      showDpoSection: json['show_dpo_section'] ?? json['showDpoSection'] ?? d.showDpoSection,
      showGrievanceSection: json['show_grievance_section'] ?? json['showGrievanceSection'] ?? d.showGrievanceSection,
      grievanceMode: json['grievance_mode'] ?? json['grievanceMode'] ?? d.grievanceMode,
      grievanceExternalUrl: json['grievance_external_url'] ?? json['grievanceExternalUrl'] ?? d.grievanceExternalUrl,
      consentsSectionTitle: json['consents_section_title'] ?? json['consentsSectionTitle'] ?? d.consentsSectionTitle,
      rightsSectionTitle: json['rights_section_title'] ?? json['rightsSectionTitle'] ?? d.rightsSectionTitle,
      nomineesSectionTitle: json['nominees_section_title'] ?? json['nomineesSectionTitle'] ?? d.nomineesSectionTitle,
      transparencyDescription: json['transparency_description'] ?? json['transparencyDescription'] ?? d.transparencyDescription,
      dpoQualificationsEnabled: json['dpo_qualifications_enabled'] ?? json['dpoQualificationsEnabled'] ?? d.dpoQualificationsEnabled,
      dpoResponsibilitiesEnabled: json['dpo_responsibilities_enabled'] ?? json['dpoResponsibilitiesEnabled'] ?? d.dpoResponsibilitiesEnabled,
      dpoWorkingHoursEnabled: json['dpo_working_hours_enabled'] ?? json['dpoWorkingHoursEnabled'] ?? d.dpoWorkingHoursEnabled,
      dpoResponseTimeEnabled: json['dpo_response_time_enabled'] ?? json['dpoResponseTimeEnabled'] ?? d.dpoResponseTimeEnabled,
    );
  }
}

class ConsentSavePayload {
  final String userId;
  final List<Map<String, dynamic>> purposes;
  final String action; // 'approved' | 'revoked'
  final String? assetId;
  final String source;
  final Map<String, dynamic>? metadata;

  ConsentSavePayload({
    required this.userId,
    required this.purposes,
    required this.action,
    this.assetId,
    this.source = 'right center flutter',
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'purposes': purposes,
      'action': action,
      if (assetId != null) 'assetId': assetId,
      'source': source,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Legacy payload kept for backward compatibility
class ConsentPayload {
  final String userId;
  final List<Map<String, dynamic>> purposes;
  final String action; // 'approved', 'revoked', 'declined'
  final List<String>? changedPurposes;

  ConsentPayload({
    required this.userId,
    required this.purposes,
    required this.action,
    this.changedPurposes,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'purposes': purposes,
      'action': action,
      if (changedPurposes != null) 'changedPurposes': changedPurposes,
    };
  }
}

class Nominee {
  final String? id;
  final String nominee_name;
  final String relationship;
  final String nominee_email;
  final String nominee_mobile;
  final String? purpose_of_appointment;
  final String? user_id;
  final String? client_user_id;

  Nominee({
    this.id,
    required this.nominee_name,
    required this.relationship,
    required this.nominee_email,
    required this.nominee_mobile,
    this.purpose_of_appointment,
    this.user_id,
    this.client_user_id,
  });

  factory Nominee.fromJson(Map<String, dynamic> json) {
    return Nominee(
      id: json['id'],
      nominee_name: json['nominee_name'] ?? '',
      relationship: json['relationship'] ?? '',
      nominee_email: json['nominee_email'] ?? '',
      nominee_mobile: json['nominee_mobile'] ?? '',
      purpose_of_appointment: json['purpose_of_appointment'],
      user_id: json['user_id'],
      client_user_id: json['client_user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nominee_name': nominee_name,
      'relationship': relationship,
      'nominee_email': nominee_email,
      'nominee_mobile': nominee_mobile,
      if (purpose_of_appointment != null)
        'purpose_of_appointment': purpose_of_appointment,
      if (user_id != null) 'user_id': user_id,
      if (client_user_id != null) 'client_user_id': client_user_id,
    };
  }
}

class GrievanceTicket {
  final String? id;
  final String subject;
  final String category;
  final String description;
  final String? status;
  final String? created_at;
  final String? client_user_id;
  final String? ticket_id;

  GrievanceTicket({
    this.id,
    required this.subject,
    required this.category,
    required this.description,
    this.status,
    this.created_at,
    this.client_user_id,
    this.ticket_id,
  });

  factory GrievanceTicket.fromJson(Map<String, dynamic> json) {
    return GrievanceTicket(
      id: json['id'],
      subject: json['subject'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      status: json['status'],
      created_at: json['created_at'],
      client_user_id: json['client_user_id'],
      ticket_id: json['ticket_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'subject': subject,
      'category': category,
      'description': description,
      if (status != null) 'status': status,
      if (created_at != null) 'created_at': created_at,
      if (client_user_id != null) 'client_user_id': client_user_id,
      if (ticket_id != null) 'ticket_id': ticket_id,
    };
  }
}

/// Result of a successful non-SSO OTP verification: the token to use for
/// subsequent authenticated Rights Center calls, and the data principal id
/// (equivalent to `userId` in the SSO flow) it resolves to.
class OtpVerifyResult {
  final String accessToken;
  final String dataPrincipalId;

  OtpVerifyResult({required this.accessToken, required this.dataPrincipalId});

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResult(
      accessToken: json['accessToken'] ?? json['access_token'] ?? '',
      dataPrincipalId: json['dataPrincipalId'] ?? json['data_principal_id'] ?? '',
    );
  }
}

/// A single message in a grievance ticket's chat thread.
class GrievanceMessage {
  final String id;
  final String sender; // 'user' | 'agent' | 'system'
  final String message;
  final DateTime? createdAt;
  final String? attachmentUrl;
  final String? attachmentName;

  GrievanceMessage({
    required this.id,
    required this.sender,
    required this.message,
    this.createdAt,
    this.attachmentUrl,
    this.attachmentName,
  });

  factory GrievanceMessage.fromJson(Map<String, dynamic> json) {
    return GrievanceMessage(
      id: (json['id'] ?? json['message_id'] ?? '').toString(),
      sender: json['sender'] ?? 'system',
      message: json['message'] ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      attachmentUrl: json['attachment_url'],
      attachmentName: json['attachment_name'],
    );
  }
}

/// SDK paths that are gated by OriginEnforcementMiddleware on the backend.
/// These require browser-spoofing headers (Sec-Fetch-Site + Mozilla User-Agent).
const _sdkPaths = [
  '/api/v1/internal/consent',
  '/api/v1/internal/banners',
  '/api/v1/internal/sdk',
];

class RightsCenterApi {
  final String apiUrl;
  final String apiKey;
  final String organizationId;

  /// Mutable so the non-SSO OTP flow can promote the verified
  /// `dataPrincipalId` to the active user id after authentication.
  String? userId;

  /// Bearer token acquired from [verifyOtp] in the non-SSO flow. When set,
  /// it's sent as `Authorization: Bearer <authToken>` alongside the API key.
  String? authToken;

  static const Duration _timeout = Duration(seconds: 30);

  RightsCenterApi({
    required this.apiUrl,
    required this.apiKey,
    required this.organizationId,
    this.userId,
    this.authToken,
  });

  /// Backward-compat: accept baseUrl as well
  factory RightsCenterApi.withBaseUrl({
    required String baseUrl,
    required String apiKey,
    required String organizationId,
    String? userId,
  }) {
    return RightsCenterApi(
      apiUrl: baseUrl,
      apiKey: apiKey,
      organizationId: organizationId,
      userId: userId,
    );
  }

  bool _isSdkEndpoint(String endpoint) {
    for (final path in _sdkPaths) {
      if (endpoint.startsWith(path)) return true;
    }
    return false;
  }

  Map<String, String> _getHeaders({bool isSdkPath = false}) {
    final key = apiKey;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (key.isNotEmpty) {
      headers['X-API-Key'] = key;
    }
    if (organizationId.isNotEmpty) {
      headers['X-Org-Id'] = organizationId;
    }
    if (userId != null && userId!.isNotEmpty) {
      headers['X-User-Id'] = userId!;
    }
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    // Backend OriginEnforcementMiddleware blocks /api/v1/internal/consent* and
    // /api/v1/internal/banners* unless the request looks like a browser.
    // Flutter http doesn't send these automatically, so we add them for SDK paths.
    if (isSdkPath) {
      headers['Sec-Fetch-Site'] = 'cross-site';
      headers['User-Agent'] = 'Mozilla/5.0 TruConsent-Flutter-SDK/1.0';
      // Do NOT send Origin — backend defaults to COLLECTOR_BASE_URL which is always authorized.
      // Sending the API URL as Origin causes 403 "Origin not authorized".
    }
    return headers;
  }

  Future<dynamic> _request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final cleanBase = apiUrl.replaceAll(RegExp(r'/$'), '');
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final url = Uri.parse('$cleanBase$cleanEndpoint');
    final isSdk = _isSdkEndpoint(endpoint);
    final headers = _getHeaders(isSdkPath: isSdk);

    try {
      debugPrint('[RightsCenterApi] $method $url');
      debugPrint('[RightsCenterApi] X-Org-Id: ${organizationId.isNotEmpty ? "✓ set" : "✗ MISSING"} X-API-Key: ${apiKey.isNotEmpty ? "✓ set" : "✗ MISSING"}');

      http.Response response;
      if (method == 'GET') {
        response = await http.get(url, headers: headers).timeout(_timeout);
      } else if (method == 'POST') {
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(_timeout);
      } else if (method == 'PUT') {
        response = await http.put(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ).timeout(_timeout);
      } else if (method == 'DELETE') {
        response = await http.delete(url, headers: headers).timeout(_timeout);
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      debugPrint('[RightsCenterApi] Response status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        try {
          return jsonDecode(response.body);
        } catch (e) {
          debugPrint('[RightsCenterApi] Failed to parse JSON: $e');
          throw Exception('Invalid response format: expected JSON');
        }
      } else {
        final errorText = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        debugPrint('[RightsCenterApi] Error response: $errorText');
        // 404 on user-scoped endpoints is expected (no data yet)
        if (response.statusCode == 404 &&
            (endpoint.contains('/user/') || endpoint.contains('/banners'))) {
          return null;
        }
        throw Exception(
          'API Error ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      debugPrint('[RightsCenterApi] Request failed: $e');
      if (e is Exception) rethrow;
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // ─── Settings ────────────────────────────────────────────────────────────────

  Future<RightsCenterSettings> getRightsCenterSettings({String? assetId}) async {
    try {
      final queryPart = assetId != null && assetId.isNotEmpty
          ? '?asset_id=${Uri.encodeComponent(assetId)}'
          : '';
      final response = await _request(
        '/api/v1/internal/rights-center/settings/global$queryPart',
      );
      if (response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          return RightsCenterSettings.fromJson(data);
        }
      }
      return RightsCenterSettings.defaults;
    } catch (e) {
      debugPrint('[RightsCenterApi] getRightsCenterSettings error (using defaults): $e');
      return RightsCenterSettings.defaults;
    }
  }

  // ─── Consent ─────────────────────────────────────────────────────────────────

  /// Fetch user's banners with consent status already merged.
  /// Uses GET /api/v1/internal/consent/user/{userId} — requires consent scope (not admin).
  Future<List<Map<String, dynamic>>> getUserConsentsFlat(
    String userId, {
    String? assetId,
  }) async {
    // Step 1 — GET /api/v1/internal/consent/user/{userId}
    // Returns banners with the user's consent status pre-merged. Requires consent scope only.
    dynamic bannersResp;
    try {
      bannersResp = await _request(
        '/api/v1/internal/consent/user/${Uri.encodeComponent(userId)}',
      );
    } catch (e) {
      debugPrint('[RightsCenterApi] Error fetching user consent banners: $e');
      bannersResp = null;
    }

    // Step 2 — user consent status (same as website)
    dynamic userStatusResp;
    try {
      userStatusResp = await _request(
        '/api/v1/internal/consent/user-consent-status?userId=${Uri.encodeComponent(userId)}',
      );
    } catch (e) {
      debugPrint('[RightsCenterApi] Error fetching user consent status (optional): $e');
      userStatusResp = null;
    }

    // Seed unique purpose map from template banners
    final uniquePurposesMap = <String, Map<String, dynamic>>{};
    final bannerList = _toList(bannersResp);
    for (final banner in bannerList) {
      if (banner is! Map<String, dynamic>) continue;
      final purposes = _toList(banner['purposes']);
      for (final p in purposes) {
        if (p is! Map<String, dynamic>) continue;
        final id = (p['id'] ?? '').toString();
        final statusStr = (p['status'] ?? '').toString().toLowerCase();
        if (id.isEmpty || (statusStr.isNotEmpty && statusStr != 'active')) continue;
        if (uniquePurposesMap.containsKey(id)) continue;

        final purposeType = (p['purpose_type'] ?? '').toString().toLowerCase();
        final isMandatory = p['isMandatory'] == true ||
            p['is_mandatory'] == true ||
            purposeType.contains('mandatory');
        final isLegitimate = p['isLegitimate'] == true || p['is_legitimate'] == true;
        uniquePurposesMap[id] = {
          'id': id,
          'name': p['name'] ?? p['title'] ?? '',
          'title': p['title'] ?? p['name'] ?? '',
          'description': p['description'] ?? '',
          'expiry_period': p['expiry_period'] ?? p['expiry_type'] ?? p['expiry'] ?? '',
          'is_mandatory': isMandatory,
          'consented': _normalizeConsentedFromBanner(p['consented']),
          'isLegitimate': isLegitimate,
          'dataElements': _toList(p['data_elements'] ?? p['dataElements']),
          'processingActivities': _toList(p['processing_activities'] ?? p['processingActivities']),
          'type': isMandatory ? 'Mandatory' : 'Optional',
          'timestamp': 0,
          'shownToPrincipal': false,
        };
      }
    }

    // Merge user consent status (same as website)
    final collectionPoints = userStatusResp is Map<String, dynamic>
        ? _toList(userStatusResp['collectionPoints'])
        : <dynamic>[];
    for (final cp in collectionPoints) {
      if (cp is! Map<String, dynamic>) continue;
      final latestConsent = cp['latest_consent'] ?? cp['latestConsent'];
      final pcList = _toList(
        latestConsent is Map ? latestConsent['purpose_consents'] ?? latestConsent['purposeConsents'] : null,
      );
      final logTimestamp = latestConsent is Map
          ? DateTime.tryParse(latestConsent['timestamp']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0
          : 0;
      // Any consent log (notice_shown, approved, declined, etc.) means the banner was shown.
      final bannerWasShown = logTimestamp > 0;

      for (final pc in pcList) {
        if (pc is! Map<String, dynamic>) continue;
        final pid = (pc['purpose_id'] ?? pc['id'] ?? pc['purposeId'] ?? '').toString();
        if (pid.isEmpty) continue;
        final existing = uniquePurposesMap[pid];
        if (existing == null) continue;
        final existingTs = (existing['timestamp'] as int?) ?? 0;
        // For Legitimate Interest: banner being shown = shownToPrincipal = true, regardless
        // of whether this particular log is newer than what we already have.
        final shownToPrincipal = (existing['shownToPrincipal'] == true) ||
            (existing['isLegitimate'] == true && bannerWasShown);
        if (logTimestamp > existingTs) {
          uniquePurposesMap[pid] = {
            ...existing,
            'consented': _normalizeStatus(pc['status'] ?? pc['consented']),
            'timestamp': logTimestamp,
            if (pc['data_elements'] != null || pc['dataElements'] != null)
              'dataElements': _toList(pc['data_elements'] ?? pc['dataElements']),
            if (pc['processing_activities'] != null || pc['processingActivities'] != null)
              'processingActivities': _toList(pc['processing_activities'] ?? pc['processingActivities']),
            if (pc['description'] != null) 'description': pc['description'],
            if (pc['name'] != null || pc['title'] != null)
              'name': pc['name'] ?? pc['title'] ?? existing['name'],
            'shownToPrincipal': shownToPrincipal,
          };
        } else if (shownToPrincipal != existing['shownToPrincipal']) {
          uniquePurposesMap[pid] = {...existing, 'shownToPrincipal': shownToPrincipal};
        }
      }
    }

    final result = uniquePurposesMap.values.toList();
    debugPrint('[RightsCenterApi] getUserConsentsFlat: ${result.length} purposes');
    return result;
  }

  /// Save consent changes from Rights Center.
  Future<void> saveConsentToRightsCenter(
    String userId,
    List<Map<String, dynamic>> changedPurposes, {
    String? assetId,
  }) async {
    final hasAnyAccepted = changedPurposes.any((p) => p['consented'] == 'accepted');
    final payload = ConsentSavePayload(
      userId: userId,
      purposes: changedPurposes,
      action: hasAnyAccepted ? 'approved' : 'revoked',
      assetId: assetId,
      source: 'right center flutter',
      metadata: {
        'button_used': 'save',
        'interaction_type': 'rights_center',
      },
    );
    await _request(
      '/api/v1/internal/consent/rights-center',
      method: 'POST',
      body: payload.toJson(),
    );
  }

  // ─── DPO ─────────────────────────────────────────────────────────────────────

  Future<DPOInfo> getDPOInfo() async {
    final response = await _request('/api/v1/internal/dpo');
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) return DPOInfo.fromJson(data);
    }
    return DPOInfo();
  }

  // ─── Nominee ──────────────────────────────────────────────────────────────────

  Future<List<Nominee>> getNominees(String userId) async {
    final response = await _request(
      '/api/v1/internal/nominee/user/${Uri.encodeComponent(userId)}',
    );
    return _toList(response).whereType<Map<String, dynamic>>().map(Nominee.fromJson).toList();
  }

  Future<Nominee> createNominee(Nominee nominee, String userId) async {
    final body = {
      'nominee_name': nominee.nominee_name,
      'relationship': nominee.relationship,
      'nominee_email': nominee.nominee_email,
      'nominee_mobile': nominee.nominee_mobile,
      'purpose_of_appointment': nominee.purpose_of_appointment ?? '',
      'client_user_id': userId,
    };
    final response = await _request(
      '/api/v1/internal/nominee',
      method: 'POST',
      body: body,
    );
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) return Nominee.fromJson(data);
    }
    throw Exception('Invalid response format');
  }

  Future<Nominee> updateNominee(String id, Nominee nominee) async {
    final response = await _request(
      '/api/v1/internal/nominee/${Uri.encodeComponent(id)}',
      method: 'PUT',
      body: nominee.toJson(),
    );
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) return Nominee.fromJson(data);
    }
    throw Exception('Invalid response format');
  }

  Future<void> deleteNominee(String id) async {
    await _request(
      '/api/v1/internal/nominee/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
  }

  // ─── Grievance ────────────────────────────────────────────────────────────────

  Future<List<GrievanceTicket>> getGrievanceTickets(String userId) async {
    final response = await _request(
      '/api/v1/internal/grievance/user/${Uri.encodeComponent(userId)}',
    );
    return _toList(response)
        .whereType<Map<String, dynamic>>()
        .map(GrievanceTicket.fromJson)
        .toList();
  }

  Future<GrievanceTicket> createGrievanceTicket(
    GrievanceTicket ticket,
    String userId,
  ) async {
    final body = {
      'client_user_id': userId,
      'subject': ticket.subject,
      'category': ticket.category,
      'description': ticket.description,
    };
    final response = await _request(
      '/api/v1/internal/grievance',
      method: 'POST',
      body: body,
    );
    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) return GrievanceTicket.fromJson(data);
    }
    // Merge submitted values so UI can render immediately
    return GrievanceTicket(
      subject: ticket.subject,
      category: ticket.category,
      description: ticket.description,
      status: ticket.status ?? 'open',
      client_user_id: userId,
    );
  }

  // ─── Rights Requests ──────────────────────────────────────────────────────────

  // Same payload as mars-money-website RightCenter.jsx
  Future<void> createAccessRequest(String userId, {String? assetId}) async {
    await _request(
      '/api/v1/internal/rights-requests/access-request',
      method: 'POST',
      body: {
        'user_id': userId,
        'subject': 'Data Access Request',
        'description': 'User requested access to personal data from Rights Center.',
        'metadata': {
          'asset_id': assetId,
          'source': 'Rights Center',
        },
      },
    );
  }

  // Same payload as mars-money-website RightCenter.jsx
  Future<void> createDeletionRequest(String userId, {String? assetId}) async {
    await _request(
      '/api/v1/internal/rights-requests/deletion-request',
      method: 'POST',
      body: {
        'user_id': userId,
        'reason': 'User requested data deletion from Rights Center',
        'metadata': {
          'asset_id': assetId,
          'requested_at': DateTime.now().toIso8601String(),
          'source': 'Rights Center',
        },
      },
    );
  }

  // ─── Non-SSO OTP authentication ───────────────────────────────────────────────

  /// Requests an OTP be sent to [phone] (with [countryCode], e.g. '+91').
  Future<void> sendOtp({
    required String phone,
    required String countryCode,
    String? assetId,
  }) async {
    await _request(
      '/api/v1/internal/rights-center-access/send-otp',
      method: 'POST',
      body: {
        'assetId': assetId,
        'phone': phone,
        'countryCode': countryCode,
      },
    );
  }

  /// Verifies [otp] for [phone]/[countryCode]. On success, returns an
  /// [OtpVerifyResult] with the access token and data principal id to use for
  /// all subsequent Rights Center calls; also updates this instance's
  /// [userId]/[authToken] so callers don't have to do it themselves.
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String countryCode,
    required String otp,
    String? assetId,
  }) async {
    final result = await _request(
      '/api/v1/internal/rights-center-access/verify-otp',
      method: 'POST',
      body: {
        'assetId': assetId,
        'phone': phone,
        'countryCode': countryCode,
        'otp': otp,
      },
    );
    final data = (result is Map && result['data'] is Map) ? result['data'] : result;
    final parsed = OtpVerifyResult.fromJson((data as Map?)?.cast<String, dynamic>() ?? {});
    userId = parsed.dataPrincipalId;
    authToken = parsed.accessToken;
    return parsed;
  }

  // ─── Grievance chat ───────────────────────────────────────────────────────────

  Future<List<GrievanceMessage>> getGrievanceMessages(String ticketId) async {
    final result = await _request('/api/v1/internal/grievance/$ticketId/messages');
    return _toList(result)
        .map((m) => GrievanceMessage.fromJson((m as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<GrievanceMessage> sendGrievanceMessage(
    String ticketId,
    String message,
  ) async {
    final result = await _request(
      '/api/v1/internal/grievance/$ticketId/messages',
      method: 'POST',
      body: {
        'sender': 'user',
        'message': message,
      },
    );
    final data = (result is Map && result['data'] is Map) ? result['data'] : result;
    if (data is Map) {
      return GrievanceMessage.fromJson(data.cast<String, dynamic>());
    }
    // Fall back to an optimistic local echo if the backend returns no body.
    return GrievanceMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      sender: 'user',
      message: message,
      createdAt: DateTime.now(),
    );
  }

  /// Builds the WebSocket URL for real-time grievance chat updates, per the
  /// NPM SDK: auth is passed as query params (`token`, `api_key`, `org_id`)
  /// rather than headers, since browsers can't set WS handshake headers —
  /// this SDK does the same for parity with the backend's expected auth
  /// shape (`_authenticate()` reads these query params unconditionally).
  Uri grievanceWebSocketUri(String ticketId) {
    final httpUri = Uri.parse(apiUrl);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: '/ws/grievance/$ticketId',
      queryParameters: {
        'token': authToken ?? '',
        'api_key': apiKey,
        'org_id': organizationId,
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  List<dynamic> _toList(dynamic value) {
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      final data = value['data'];
      if (data is List) return data;
      final items = value['items'];
      if (items is List) return items;
    }
    return [];
  }

  String _normalizeStatus(dynamic val) {
    if (val == 'accepted' || val == 'declined') return val as String;
    if (val == 'approved') return 'accepted';
    if (val == 'rejected') return 'declined';
    if (val is bool) return val ? 'accepted' : 'declined';
    if (val is String) {
      final v = val.toLowerCase();
      if (v == 'yes' || v == 'true') return 'accepted';
      if (v == 'no' || v == 'false') return 'declined';
    }
    return 'pending';
  }

  String _normalizeConsentedFromBanner(dynamic val) {
    if (val == true || val == 'accepted' || val == 'approved') return 'accepted';
    if (val == false || val == 'declined' || val == 'rejected') return 'declined';
    if (val is String) {
      final v = val.toLowerCase();
      if (v == 'accepted' || v == 'approved' || v == 'yes' || v == 'true') {
        return 'accepted';
      }
      if (v == 'declined' || v == 'rejected' || v == 'no' || v == 'false') {
        return 'declined';
      }
    }
    return 'declined';
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:truconsent_consent_notice_flutter/src/services/rights_center_api.dart';

void main() {
  group('RightsCenterSettings.accessMode', () {
    test('defaults to sso', () {
      expect(RightsCenterSettings.defaults.accessMode, 'sso');
    });

    test('parses access_mode from json (snake_case and camelCase)', () {
      expect(RightsCenterSettings.fromJson({'access_mode': 'non_sso'}).accessMode, 'non_sso');
      expect(RightsCenterSettings.fromJson({'accessMode': 'non_sso'}).accessMode, 'non_sso');
    });

    test('falls back to sso when absent', () {
      expect(RightsCenterSettings.fromJson({}).accessMode, 'sso');
    });
  });

  group('OtpVerifyResult.fromJson', () {
    test('parses camelCase fields', () {
      final result = OtpVerifyResult.fromJson({
        'accessToken': 'tok-123',
        'dataPrincipalId': 'dp-456',
      });
      expect(result.accessToken, 'tok-123');
      expect(result.dataPrincipalId, 'dp-456');
    });

    test('parses snake_case fields', () {
      final result = OtpVerifyResult.fromJson({
        'access_token': 'tok-abc',
        'data_principal_id': 'dp-def',
      });
      expect(result.accessToken, 'tok-abc');
      expect(result.dataPrincipalId, 'dp-def');
    });
  });

  group('GrievanceMessage.fromJson', () {
    test('parses a well-formed message', () {
      final message = GrievanceMessage.fromJson({
        'id': 'm1',
        'sender': 'agent',
        'message': 'Hello, how can we help?',
        'created_at': '2026-01-01T00:00:00.000Z',
      });
      expect(message.id, 'm1');
      expect(message.sender, 'agent');
      expect(message.message, 'Hello, how can we help?');
      expect(message.createdAt, isNotNull);
    });

    test('defaults sender to system and tolerates missing fields', () {
      final message = GrievanceMessage.fromJson({});
      expect(message.sender, 'system');
      expect(message.message, '');
      expect(message.createdAt, isNull);
    });
  });

  group('RightsCenterApi.grievanceWebSocketUri', () {
    test('converts https to wss and includes auth query params', () {
      final api = RightsCenterApi(
        apiUrl: 'https://trukit-dev.truconsent.io',
        apiKey: 'my-key',
        organizationId: 'my-org',
      );
      api.authToken = 'my-token';
      final uri = api.grievanceWebSocketUri('ticket-1');

      expect(uri.scheme, 'wss');
      expect(uri.host, 'trukit-dev.truconsent.io');
      expect(uri.path, '/ws/grievance/ticket-1');
      expect(uri.queryParameters['token'], 'my-token');
      expect(uri.queryParameters['api_key'], 'my-key');
      expect(uri.queryParameters['org_id'], 'my-org');
    });

    test('converts http to ws when the API URL is not secure', () {
      final api = RightsCenterApi(
        apiUrl: 'http://localhost:8080',
        apiKey: 'k',
        organizationId: 'o',
      );
      final uri = api.grievanceWebSocketUri('t1');
      expect(uri.scheme, 'ws');
      expect(uri.port, 8080);
    });

    test('sends an empty token when no authToken has been set', () {
      final api = RightsCenterApi(
        apiUrl: 'https://trukit-dev.truconsent.io',
        apiKey: 'k',
        organizationId: 'o',
      );
      final uri = api.grievanceWebSocketUri('t1');
      expect(uri.queryParameters['token'], '');
    });
  });

  group('RightsCenterApi mutable auth state', () {
    test('userId and authToken can be updated after construction (post-OTP)', () {
      final api = RightsCenterApi(
        apiUrl: 'https://trukit-dev.truconsent.io',
        apiKey: 'k',
        organizationId: 'o',
      );
      expect(api.userId, isNull);
      expect(api.authToken, isNull);

      api.userId = 'dp-123';
      api.authToken = 'tok-abc';

      expect(api.userId, 'dp-123');
      expect(api.authToken, 'tok-abc');
    });
  });
}

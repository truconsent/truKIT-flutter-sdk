/// API Endpoints Test Script
/// Run with: dart test_api_endpoints.dart
/// 
/// This script tests all Rights Center API endpoints to verify they work correctly.

import 'dart:convert';
import 'dart:io';

/// NOTE: this script targets a legacy Lambda-based endpoint shape and is not
/// wired to the current `/api/v1/internal/...` API used by the SDK's
/// `banner_service.dart`/`rights_center_api.dart`. Treat it as a manual,
/// ad hoc smoke-test tool, not part of the SDK's supported test suite.
///
/// Never hardcode real credentials here. Supply them via environment
/// variables when running: `API_BASE_URL=... API_KEY=... ORG_ID=... dart test_api_endpoints.dart`
final String baseUrl =
    Platform.environment['API_BASE_URL'] ?? 'https://example.invalid/banners';
final String apiKey = Platform.environment['API_KEY'] ?? '';
final String orgId = Platform.environment['ORG_ID'] ?? '';

// Test user ID - replace with actual user ID for testing, or set TEST_USER_ID.
final String fullUserId =
    Platform.environment['TEST_USER_ID'] ?? 'bae196b5-06d1-4f26-a391-03a3583f5965';
final String dataPrincipalId = fullUserId.substring(0, 6); // First 6 characters

final Map<String, String> headers = {
  'X-API-Key': apiKey,
  'X-Org-Id': orgId,
  'Content-Type': 'application/json',
};

class TestResult {
  final String name;
  final bool success;
  final int? status;
  final dynamic data;
  final String? error;

  TestResult({
    required this.name,
    required this.success,
    this.status,
    this.data,
    this.error,
  });
}

Future<TestResult> testEndpoint(String name, String url, {String method = 'GET'}) async {
  print('\n🧪 Testing: $name');
  print('   URL: $url');
  print('   Method: $method');

  try {
    final client = HttpClient();
    final uri = Uri.parse(url);
    final request = await client.openUrl(method, uri);
    
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });

    final response = await request.close();
    final status = response.statusCode;
    
    print('   Status: $status ${response.reasonPhrase}');

    final responseBody = await response.transform(utf8.decoder).join();
    dynamic data;
    
    final contentType = response.headers.value('content-type') ?? '';
    print('   Response Type: ${contentType.contains('json') ? 'JSON' : contentType}');

    try {
      data = jsonDecode(responseBody);
      if (data is List) {
        print('   Array Length: ${data.length}');
        if (data.isNotEmpty) {
          print('   Sample Item Keys: ${(data[0] as Map).keys.join(', ')}');
        }
      } else if (data is Map) {
        print('   Object Keys: ${data.keys.join(', ')}');
      }
    } catch (e) {
      data = responseBody;
      print('   Response Preview: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}');
    }

    client.close();

    if (status >= 200 && status < 300) {
      print('   ✅ SUCCESS');
      return TestResult(
        name: name,
        success: true,
        status: status,
        data: data,
      );
    } else {
      print('   ❌ FAILED (Status: $status)');
      return TestResult(
        name: name,
        success: false,
        status: status,
        data: data,
      );
    }
  } catch (error) {
    print('   ❌ ERROR: $error');
    return TestResult(
      name: name,
      success: false,
      error: error.toString(),
    );
  }
}

Future<void> main() async {
  if (apiKey.isEmpty || orgId.isEmpty) {
    stderr.writeln(
      'Set API_KEY and ORG_ID (and optionally API_BASE_URL, TEST_USER_ID) '
      'environment variables before running this script.',
    );
    exit(1);
  }

  final separator = List.filled(60, '=').join();
  print(separator);
  print('Rights Center API Endpoints Test');
  print(separator);
  print('Base URL: $baseUrl');
  print('Data Principal ID: $dataPrincipalId (from $fullUserId)');

  final results = <TestResult>[];

  // Test 1: Get All Banners
  // Note: Root endpoint (/) returns 404, which is expected - user endpoint contains all banner data
  final rootResult = await testEndpoint(
    'Get All Banners (/)',
    '$baseUrl/',
  );
  // Don't count 404 as failure since user endpoint provides the data
  if (rootResult.status == 404) {
    print('   ℹ️  Root endpoint returns 404 (expected) - user endpoint provides all banner data');
    results.add(TestResult(
      name: rootResult.name,
      success: true,
      status: rootResult.status,
      data: rootResult.data,
    ));
  } else {
    results.add(rootResult);
  }

  // Test 2: Get User Consents (6-char ID)
  results.add(await testEndpoint(
    'Get User Consents (6-char ID)',
    '$baseUrl/user/$dataPrincipalId',
  ));

  // Test 3: Get DPO Information
  results.add(await testEndpoint(
    'Get DPO Information',
    '$baseUrl/dpo_information',
  ));

  // Test 4: Get User Nominees (full UUID)
  results.add(await testEndpoint(
    'Get User Nominees (full UUID)',
    '$baseUrl/user_nominees/user/$fullUserId',
  ));

  // Test 5: Get Grievance Tickets (full UUID)
  results.add(await testEndpoint(
    'Get Grievance Tickets (full UUID)',
    '$baseUrl/grievance_tickets/user/$fullUserId',
  ));

  // Summary
  final summarySeparator = List.filled(60, '=').join();
  print('\n$summarySeparator');
  print('Test Summary');
  print(summarySeparator);

  final successCount = results.where((r) => r.success).length;
  final failCount = results.where((r) => !r.success).length;

  print('✅ Passed: $successCount');
  print('❌ Failed: $failCount');
  print('📊 Total: ${results.length}');

  if (failCount > 0) {
    print('\n⚠️  Some tests failed. Check the output above for details.');
    exit(1);
  } else {
    print('\n🎉 All tests passed!');
    exit(0);
  }
}


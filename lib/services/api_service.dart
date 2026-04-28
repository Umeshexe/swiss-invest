import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';

class ApiService {
  static const String _baseUrl = 'https://orishub.com';

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    debugPrint('[API] POST $_baseUrl/api/auth/login  email=$email');
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'email': email, 'password': password}),
    );

    debugPrint('[API] LOGIN  status=${response.statusCode}  body=${response.body}');

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = body['message']?.toString() ?? 'Login failed.';
      debugPrint('[API] LOGIN ERROR: $msg');
      throw Exception(msg);
    }

    final session = AuthSession.fromJson(body);
    debugPrint('[API] LOGIN OK — userId=${session.userId}');
    debugPrint('[API] ──────────────────────────────────────────');
    debugPrint('[API] ACCESS TOKEN (for Postman):');
    debugPrint('[API] ${session.accessToken}');
    debugPrint('[API] ──────────────────────────────────────────');
    return session;
  }

  /// Submits health data as multipart/form-data.
  ///
  /// The API expects:
  ///   POST /api/submissions
  ///   Authorization: Bearer <token>
  ///   Content-Type: multipart/form-data
  ///   Fields:
  ///     type      → "Health Connector Data"
  ///     device_id → "<platform>-<userId>"
  ///     payload   → JSON-encoded string of health data
  Future<Map<String, dynamic>> submitHealthPayload({
    required String accessToken,
    required int userId,
    required Map<String, dynamic> payload,
    required String deviceId,
  }) async {
    final payloadJson = jsonEncode(payload);
    debugPrint('[API] POST $_baseUrl/api/submissions');
    debugPrint('[API] SUBMIT  device_id=$deviceId');
    debugPrint('[API] SUBMIT  payload=$payloadJson');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/submissions'),
    );

    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });

    // payload must be sent as a JSON string field, NOT nested JSON body
    request.fields['type'] = 'Health Connector Data';
    request.fields['device_id'] = deviceId;
    request.fields['payload'] = payloadJson;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    debugPrint('[API] SUBMIT  status=${response.statusCode}  body=${response.body}');

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = body['message']?.toString() ?? 'Submission failed.';
      debugPrint('[API] SUBMIT ERROR: $msg');
      throw Exception(msg);
    }

    debugPrint('[API] SUBMIT OK — submission_id=${body['id']}');
    return body;
  }

  Future<Map<String, dynamic>> getSubmissions({
    required String accessToken,
    required int userId,
  }) async {
    debugPrint('[API] GET $_baseUrl/api/submissions/$userId');
    final response = await http.get(
      Uri.parse('$_baseUrl/api/submissions/$userId'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    debugPrint('[API] GET SUBMISSIONS  status=${response.statusCode}');

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = body['message']?.toString() ?? 'Fetch submissions failed.';
      debugPrint('[API] GET ERROR: $msg');
      throw Exception(msg);
    }

    return body;
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'data': decoded};
  }
}

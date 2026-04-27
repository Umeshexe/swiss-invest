import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';

class ApiService {
  static const String _baseUrl = 'https://orishub.com';

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'email': email, 'password': password}),
    );

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Login failed.');
    }

    return AuthSession.fromJson(body);
  }

  Future<Map<String, dynamic>> submitHealthPayload({
    required String accessToken,
    required int userId,
    required Map<String, dynamic> payload,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/submissions'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{
        'type': 'Health Connector Data',
        'device_id': deviceId,
        'user_id': userId,
        'payload': payload,
      }),
    );

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Submission failed.');
    }

    return body;
  }

  Future<Map<String, dynamic>> getSubmissions({
    required String accessToken,
    required int userId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/submissions/$userId'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['message']?.toString() ?? 'Fetch submissions failed.',
      );
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

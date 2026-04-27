import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/permission_snapshot.dart';

class StorageService {
  static const _sessionKey = 'session';
  static const _permissionStateKey = 'permission_snapshot';
  static const _lastSyncKey = 'last_sync_at';
  static const _lastHealthSyncKey = 'last_health_sync_at';
  static const _lastLocationSyncKey = 'last_location_sync_at';
  static const _permissionSetupKey = 'permission_setup_complete';
  static const _storage = FlutterSecureStorage();

  Future<void> writeSession(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return AuthSession.fromJson(decoded);
  }

  Future<void> writePermissionSnapshot(PermissionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_permissionStateKey, jsonEncode(snapshot.toJson()));
  }

  Future<PermissionSnapshot> readPermissionSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_permissionStateKey);
    if (raw == null || raw.isEmpty) {
      return PermissionSnapshot.empty();
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return PermissionSnapshot.empty();
    }

    return PermissionSnapshot.fromJson(decoded);
  }

  Future<void> writeLastSyncAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, timestamp.toUtc().toIso8601String());
  }

  Future<DateTime?> readLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> writeLastHealthSyncAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastHealthSyncKey,
      timestamp.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> readLastHealthSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastHealthSyncKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> writeLastLocationSyncAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastLocationSyncKey,
      timestamp.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> readLastLocationSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastLocationSyncKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> writePermissionSetupComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionSetupKey, complete);
  }

  Future<bool> readPermissionSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionSetupKey) ?? false;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await _storage.deleteAll();
    await prefs.remove(_permissionStateKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_lastHealthSyncKey);
    await prefs.remove(_lastLocationSyncKey);
    await prefs.remove(_permissionSetupKey);
  }
}

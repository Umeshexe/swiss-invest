import 'dart:io';

import '../models/auth_session.dart';
import '../models/permission_snapshot.dart';
import '../models/sync_result.dart';
import 'api_service.dart';
import 'device_data_service.dart';
import 'storage_service.dart';

class SyncService {
  SyncService({
    required StorageService storageService,
    required ApiService apiService,
    required DeviceDataService deviceDataService,
  }) : _storageService = storageService,
       _apiService = apiService,
       _deviceDataService = deviceDataService;

  final StorageService _storageService;
  final ApiService _apiService;
  final DeviceDataService _deviceDataService;

  Future<SyncResult> sync({
    required AuthSession session,
    required PermissionSnapshot permissions,
    String source = 'manual',
  }) async {
    final lastHealthSyncAt = await _storageService.readLastHealthSyncAt();
    final lastLocationSyncAt = await _storageService.readLastLocationSyncAt();
    final now = DateTime.now().toUtc();

    final payload = await _deviceDataService.collectSyncPayload(
      permissions: permissions,
      healthFrom: permissions.health == PermissionState.granted
          ? lastHealthSyncAt
          : null,
      locationFrom: permissions.location == PermissionState.granted
          ? lastLocationSyncAt
          : null,
      to: now,
    );

    if (payload.isEmpty) {
      return SyncResult(
        success: true,
        syncedAt: now,
        message:
            'No new approved records found for $source sync. Nothing was sent.',
        recordCount: 0,
      );
    }

    // Retry up to 3 times with exponential back-off (2 s, 4 s).
    await _submitWithRetry(session: session, payload: payload.toApiPayload());

    await _storageService.writeLastSyncAt(now);
    if (payload.steps.isNotEmpty ||
        payload.heartRate.isNotEmpty ||
        payload.calories.isNotEmpty ||
        payload.sleep.isNotEmpty ||
        payload.weight.isNotEmpty) {
      await _storageService.writeLastHealthSyncAt(now);
    }
    if (payload.locations.isNotEmpty) {
      await _storageService.writeLastLocationSyncAt(now);
    }

    return SyncResult(
      success: true,
      syncedAt: now,
      message:
          'Sync complete. Uploaded ${payload.totalRecordCount} new records via $source sync (${payload.summary}).',
      recordCount: payload.totalRecordCount,
    );
  }

  Future<void> _submitWithRetry({
    required AuthSession session,
    required Map<String, dynamic> payload,
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _apiService.submitHealthPayload(
          accessToken: session.accessToken,
          userId: session.userId,
          payload: payload,
          deviceId: '${Platform.operatingSystem}-${session.userId}',
        );
        return; // success — exit immediately
      } catch (error) {
        lastError = error;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }
    throw Exception(
      'Sync failed after $maxAttempts attempts. Last error: $lastError',
    );
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../models/permission_snapshot.dart';
import '../models/sync_payload.dart';
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
    debugPrint('[SYNC] ── Starting $source sync ──');
    debugPrint('[SYNC] Permissions: health=${permissions.health.name}  '
        'location=${permissions.location.name}  '
        'camera=${permissions.camera.name}  '
        'mic=${permissions.microphone.name}');

    final now = DateTime.now().toUtc();
    final lastHealthSyncAt = await _storageService.readLastHealthSyncAt();
    final lastLocationSyncAt = await _storageService.readLastLocationSyncAt();

    debugPrint('[SYNC] lastHealthSyncAt=$lastHealthSyncAt');
    debugPrint('[SYNC] lastLocationSyncAt=$lastLocationSyncAt');
    debugPrint('[SYNC] syncWindowEnd=$now');

    final payload = await _deviceDataService.collectSyncPayload(
      permissions: permissions,
      healthFrom: lastHealthSyncAt,      // null → DeviceDataService uses 7-day floor
      locationFrom: lastLocationSyncAt,  // null → DeviceDataService uses 1-day floor
      to: now,
    );

    // Retry manual sync if the key metrics (steps + calories) came back empty.
    // This can happen when lastHealthSyncAt was very recent and the incremental
    // window had no new records. Retrying with a wider window gives the user a
    // meaningful response instead of sending all-empty health arrays.
    final shouldRetryManualHealthWindow =
        source == 'manual' &&
        permissions.health == PermissionState.granted &&
        payload.steps.isEmpty &&
        payload.calories.isEmpty;

    final finalPayload = shouldRetryManualHealthWindow
        ? await _retryManualSyncWithExpandedHealthWindow(
            permissions: permissions,
            locationFrom: lastLocationSyncAt,
            to: now,
          )
        : payload;

    debugPrint('[SYNC] Collected payload:');
    debugPrint('[SYNC]   steps=${finalPayload.steps.length} records');
    debugPrint('[SYNC]   heartRate=${finalPayload.heartRate.length} records');
    debugPrint('[SYNC]   calories=${finalPayload.calories.length} records');
    debugPrint('[SYNC]   sleep=${finalPayload.sleep.length} records');
    debugPrint('[SYNC]   weight=${finalPayload.weight.length} records');
    debugPrint('[SYNC]   locations=${finalPayload.locations.length} records');
    debugPrint('[SYNC]   isEmpty=${finalPayload.isEmpty}');

    if (finalPayload.isEmpty) {
      debugPrint('[SYNC] Nothing to send — exiting early.');
      return SyncResult(
        success: true,
        syncedAt: now,
        message:
            'No new approved records found for $source sync. Nothing was sent.',
        recordCount: 0,
      );
    }

    debugPrint('[SYNC] Submitting to API (with retry)...');
    // Retry up to 3 times with exponential back-off (2 s, 4 s).
    await _submitWithRetry(
      session: session,
      payload: finalPayload.toApiPayload(),
    );

    await _storageService.writeLastSyncAt(now);
    if (finalPayload.steps.isNotEmpty ||
        finalPayload.heartRate.isNotEmpty ||
        finalPayload.calories.isNotEmpty ||
        finalPayload.sleep.isNotEmpty ||
        finalPayload.weight.isNotEmpty) {
      await _storageService.writeLastHealthSyncAt(now);
      debugPrint('[SYNC] Updated lastHealthSyncAt=$now');
    }
    if (finalPayload.locations.isNotEmpty) {
      await _storageService.writeLastLocationSyncAt(now);
      debugPrint('[SYNC] Updated lastLocationSyncAt=$now');
    }

    debugPrint(
      '[SYNC] ✅ Sync complete — ${finalPayload.totalRecordCount} records uploaded.',
    );
    return SyncResult(
      success: true,
      syncedAt: now,
      message:
          'Sync complete. Uploaded ${finalPayload.totalRecordCount} new records via $source sync (${finalPayload.summary}).',
      recordCount: finalPayload.totalRecordCount,
    );
  }

  Future<SyncPayload> _retryManualSyncWithExpandedHealthWindow({
    required PermissionSnapshot permissions,
    required DateTime? locationFrom,
    required DateTime to,
  }) async {
    debugPrint(
      '[SYNC] Manual sync found no incremental health records. Retrying with expanded health window.',
    );
    return _deviceDataService.collectSyncPayload(
      permissions: permissions,
      healthFrom: null,
      locationFrom: locationFrom,
      to: to,
    );
  }

  Future<void> _submitWithRetry({
    required AuthSession session,
    required Map<String, dynamic> payload,
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint('[SYNC] API attempt $attempt/$maxAttempts...');
      try {
        await _apiService.submitHealthPayload(
          accessToken: session.accessToken,
          userId: session.userId,
          payload: payload,
          deviceId: '${Platform.operatingSystem}-${session.userId}',
        );
        debugPrint('[SYNC] API attempt $attempt succeeded.');
        return; // success — exit immediately
      } catch (error) {
        lastError = error;
        debugPrint('[SYNC] API attempt $attempt FAILED: $error');
        if (attempt < maxAttempts) {
          final delay = Duration(seconds: 2 * attempt);
          debugPrint('[SYNC] Retrying in ${delay.inSeconds}s...');
          await Future<void>.delayed(delay);
        }
      }
    }
    throw Exception(
      'Sync failed after $maxAttempts attempts. Last error: $lastError',
    );
  }
}

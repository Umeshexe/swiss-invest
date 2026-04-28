import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../models/device_health_snapshot.dart';
import '../models/permission_snapshot.dart';
import '../models/sync_result.dart';
import '../services/api_service.dart';
import '../services/background_sync_service.dart';
import '../services/device_data_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    StorageService? storageService,
    ApiService? apiService,
    PermissionService? permissionService,
    DeviceDataService? deviceDataService,
    SyncService? syncService,
  }) : _storageService = storageService ?? StorageService(),
       _apiService = apiService ?? ApiService(),
       _permissionService = permissionService ?? PermissionService(),
       _deviceDataService = deviceDataService ?? DeviceDataService(),
       _syncService =
           syncService ??
           SyncService(
             storageService: storageService ?? StorageService(),
             apiService: apiService ?? ApiService(),
             deviceDataService: deviceDataService ?? DeviceDataService(),
           );

  final StorageService _storageService;
  final ApiService _apiService;
  final PermissionService _permissionService;
  final DeviceDataService _deviceDataService;
  final SyncService _syncService;

  AuthSession? session;
  PermissionSnapshot permissionSnapshot = PermissionSnapshot.empty();
  DeviceHealthSnapshot deviceHealthSnapshot = const DeviceHealthSnapshot(
    steps: null,
    calories: null,
    sleepDuration: null,
    heartRate: null,
    weight: null,
    hasAnyData: false,
  );
  DateTime? lastSyncAt;
  String? lastSyncMessage;
  bool isBusy = false;
  bool isSyncing = false;
  bool hasCompletedPermissionSetup = false;
  int? _cachedPendingRecords;
  DateTime? _pendingEstimateAt;
  Future<int>? _pendingEstimateFuture;

  Future<void> initialize() async {
    session = await _storageService.readSession();
    permissionSnapshot = await _storageService.readPermissionSnapshot();
    lastSyncAt = await _storageService.readLastSyncAt();
    hasCompletedPermissionSetup = await _storageService
        .readPermissionSetupComplete();

    if (session != null) {
      debugPrint('[APP] Session loaded — userId=${session!.userId}');
      debugPrint('[APP] ──────────────────────────────────────────');
      debugPrint('[APP] ACCESS TOKEN (for Postman):');
      debugPrint('[APP] ${session!.accessToken}');
      debugPrint('[APP] ──────────────────────────────────────────');
      await BackgroundSyncService.schedulePeriodicSync();
      await refreshDeviceHealthSnapshot();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    isBusy = true;
    lastSyncMessage = null;
    notifyListeners();

    try {
      session = await _apiService.login(email: email, password: password);
      await _storageService.writeSession(session!);
      await BackgroundSyncService.schedulePeriodicSync();
      await refreshDeviceHealthSnapshot();
      return true;
    } catch (error) {
      lastSyncMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    isBusy = true;
    notifyListeners();

    await BackgroundSyncService.cancelPeriodicSync();
    await _storageService.clearAll();

    session = null;
    permissionSnapshot = PermissionSnapshot.empty();
    lastSyncAt = null;
    lastSyncMessage = null;
    hasCompletedPermissionSetup = false;
    deviceHealthSnapshot = const DeviceHealthSnapshot(
      steps: null,
      calories: null,
      sleepDuration: null,
      heartRate: null,
      weight: null,
      hasAnyData: false,
    );
    isBusy = false;
    notifyListeners();
  }

  Future<void> refreshPermissionSnapshot() async {
    permissionSnapshot = await _permissionService.refreshPermissionSnapshot(
      existing: permissionSnapshot,
    );
    await _storageService.writePermissionSnapshot(permissionSnapshot);
    await refreshDeviceHealthSnapshot(notify: false);
    notifyListeners();
  }

  Future<PermissionState> requestHealthPermission() async {
    final result = await _permissionService.requestHealthPermission();
    if (result == PermissionState.granted) {
      permissionSnapshot = permissionSnapshot.copyWith(health: result);
    }
    await refreshPermissionSnapshot();
    return permissionSnapshot.health;
  }

  Future<PermissionState> requestLocationPermission() async {
    await _permissionService.requestLocationPermission();
    await refreshPermissionSnapshot();
    return permissionSnapshot.location;
  }

  Future<PermissionState> requestCameraPermission() async {
    await _permissionService.requestCameraPermission();
    await refreshPermissionSnapshot();
    return permissionSnapshot.camera;
  }

  Future<PermissionState> requestMicrophonePermission() async {
    await _permissionService.requestMicrophonePermission();
    await refreshPermissionSnapshot();
    return permissionSnapshot.microphone;
  }

  Future<void> completePermissionSetup() async {
    hasCompletedPermissionSetup = true;
    await _storageService.writePermissionSetupComplete(true);
    notifyListeners();
  }

  Future<SyncResult?> syncNow() async {
    if (session == null) {
      lastSyncMessage = 'Log in before starting sync.';
      notifyListeners();
      return null;
    }

    isSyncing = true;
    lastSyncMessage = null;
    notifyListeners();

    try {
      final snapshot = await _permissionService.refreshPermissionSnapshot(
        existing: permissionSnapshot,
      );
      permissionSnapshot = snapshot;
      await _storageService.writePermissionSnapshot(snapshot);

      final result = await _syncService.sync(
        session: session!,
        permissions: snapshot,
      );

      if (result.success) {
        lastSyncAt = result.syncedAt;
      }

      lastSyncMessage = result.message;
      await refreshDeviceHealthSnapshot(notify: false);
      notifyListeners();
      return result;
    } catch (error) {
      lastSyncMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<int> estimateRecordsReady({bool forceRefresh = false}) async {
    if (session == null) return 0;
    if (!forceRefresh &&
        _cachedPendingRecords != null &&
        _pendingEstimateAt != null &&
        DateTime.now().difference(_pendingEstimateAt!) <
            const Duration(minutes: 1)) {
      return _cachedPendingRecords!;
    }

    if (_pendingEstimateFuture != null) {
      return _pendingEstimateFuture!;
    }

    _pendingEstimateFuture = _estimateRecordsReadyInternal();
    final result = await _pendingEstimateFuture!;
    _pendingEstimateFuture = null;
    return result;
  }

  Future<int> _estimateRecordsReadyInternal() async {
    final snapshot = await _permissionService.refreshPermissionSnapshot(
      existing: permissionSnapshot,
    );
    permissionSnapshot = snapshot;
    await _storageService.writePermissionSnapshot(snapshot);

    // If we just synced very recently, show 0 pending to avoid UI confusion
    final lastSync = await _storageService.readLastHealthSyncAt();
    if (lastSync != null && DateTime.now().difference(lastSync).inMinutes < 5) {
      _cachedPendingRecords = 0;
      _pendingEstimateAt = DateTime.now();
      return 0;
    }

    final payload = await _deviceDataService.collectSyncPayload(
      permissions: snapshot,
      healthFrom: snapshot.health == PermissionState.granted
          ? await _storageService.readLastHealthSyncAt()
          : null,
      locationFrom: snapshot.location == PermissionState.granted
          ? await _storageService.readLastLocationSyncAt()
          : null,
      to: DateTime.now().toUtc(),
    );

    _cachedPendingRecords = payload.totalRecordCount;
    _pendingEstimateAt = DateTime.now();
    return payload.totalRecordCount;
  }

  Future<void> refreshDeviceHealthSnapshot({bool notify = true}) async {
    deviceHealthSnapshot = await _deviceDataService.collectDeviceHealthSnapshot(
      permissions: permissionSnapshot,
    );
    if (notify) {
      notifyListeners();
    }
  }
}

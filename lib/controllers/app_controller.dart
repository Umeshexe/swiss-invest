import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
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
      await BackgroundSyncService.schedulePeriodicSync();
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
    isBusy = false;
    notifyListeners();
  }

  Future<void> refreshPermissionSnapshot() async {
    permissionSnapshot = await _permissionService.refreshPermissionSnapshot(
      existing: permissionSnapshot,
    );
    await _storageService.writePermissionSnapshot(permissionSnapshot);
    notifyListeners();
  }

  Future<void> requestHealthPermission() async {
    final result = await _permissionService.requestHealthPermission();
    if (result == PermissionState.granted) {
      permissionSnapshot = permissionSnapshot.copyWith(health: result);
    }
    await refreshPermissionSnapshot();
  }

  Future<void> requestLocationPermission() async {
    await _permissionService.requestLocationPermission();
    await refreshPermissionSnapshot();
  }

  Future<void> requestCameraPermission() async {
    await _permissionService.requestCameraPermission();
    await refreshPermissionSnapshot();
  }

  Future<void> requestMicrophonePermission() async {
    await _permissionService.requestMicrophonePermission();
    await refreshPermissionSnapshot();
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
}

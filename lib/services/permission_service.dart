import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/permission_snapshot.dart';

class PermissionService {
  PermissionService() : _health = Health();

  final Health _health;

  Future<PermissionSnapshot> refreshPermissionSnapshot({
    required PermissionSnapshot existing,
  }) async {
    final healthPermission = await _readHealthPermission(existing.health);
    final locationStatus = await Permission.locationWhenInUse.status;
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    return PermissionSnapshot(
      health: healthPermission,
      location: _mapPermissionStatus(locationStatus),
      camera: _mapPermissionStatus(cameraStatus),
      microphone: _mapPermissionStatus(microphoneStatus),
    );
  }

  Future<PermissionState> requestHealthPermission() async {
    await _health.configure();
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
      final isAvailable = await _health.isHealthConnectAvailable();
      if (!isAvailable) {
        debugPrint(
          '[PERMISSIONS] Health Connect is not available. Redirecting to install flow.',
        );
        await _health.installHealthConnect();
        return PermissionState.unavailable;
      }
    }
    final healthTypes = _healthTypesForCurrentPlatform;
    debugPrint(
      '[PERMISSIONS] Requesting health for platform=${Platform.operatingSystem}  types=${healthTypes.map((t) => t.name).join(", ")}',
    );
    try {
      final granted = await _health.requestAuthorization(
        healthTypes,
        permissions: List<HealthDataAccess>.filled(
          healthTypes.length,
          HealthDataAccess.READ,
        ),
      );
      debugPrint(
        '[PERMISSIONS] Health result: ${granted ? "granted" : "denied"}',
      );
      return granted ? PermissionState.granted : PermissionState.denied;
    } catch (e) {
      debugPrint('[PERMISSIONS] Health request error: $e');
      return PermissionState.denied;
    }
  }

  Future<void> requestLocationPermission() async {
    debugPrint('[PERMISSIONS] Requesting location...');
    final status = await Permission.locationWhenInUse.request();
    debugPrint('[PERMISSIONS] Location result: ${status.name}');
  }

  Future<void> requestCameraPermission() async {
    debugPrint('[PERMISSIONS] Requesting camera...');
    final status = await Permission.camera.request();
    debugPrint('[PERMISSIONS] Camera result: ${status.name}');
  }

  Future<void> requestMicrophonePermission() async {
    debugPrint('[PERMISSIONS] Requesting microphone...');
    final status = await Permission.microphone.request();
    debugPrint('[PERMISSIONS] Microphone result: ${status.name}');
  }

  Future<PermissionState> _readHealthPermission(
    PermissionState fallback,
  ) async {
    try {
      await _health.configure();
      final healthTypes = _healthTypesForCurrentPlatform;
      final granted = await _health.hasPermissions(
        healthTypes,
        permissions: List<HealthDataAccess>.filled(
          healthTypes.length,
          HealthDataAccess.READ,
        ),
      );
      if (granted == true) {
        return PermissionState.granted;
      }
      if (granted == false) {
        return PermissionState.denied;
      }
      return fallback;
    } catch (_) {
      return PermissionState.unavailable;
    }
  }

  PermissionState _mapPermissionStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return PermissionState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionState.permanentlyDenied;
    }
    if (status.isDenied) {
      return PermissionState.denied;
    }
    return PermissionState.unavailable;
  }

  List<HealthDataType> get _healthTypesForCurrentPlatform =>
      Platform.isAndroid ? _androidHealthTypes : _sharedHealthTypes;

  // iOS uses SLEEP_IN_BED — SLEEP_SESSION is Android/Health Connect only.
  static const List<HealthDataType> _sharedHealthTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.WEIGHT,
  ];

  static const List<HealthDataType> _androidHealthTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_UNKNOWN,
    HealthDataType.WEIGHT,
  ];
}

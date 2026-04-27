import 'dart:io';

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
    }
    final healthTypes = _healthTypesForCurrentPlatform;
    final granted = await _health.requestAuthorization(
      healthTypes,
      permissions: List<HealthDataAccess>.filled(
        healthTypes.length,
        HealthDataAccess.READ,
      ),
    );
    return granted ? PermissionState.granted : PermissionState.denied;
  }

  Future<void> requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  Future<void> requestCameraPermission() async {
    await Permission.camera.request();
  }

  Future<void> requestMicrophonePermission() async {
    await Permission.microphone.request();
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
      return granted == true ? PermissionState.granted : fallback;
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

  static const List<HealthDataType> _sharedHealthTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
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

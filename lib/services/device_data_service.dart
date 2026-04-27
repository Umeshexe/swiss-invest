import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';

import '../models/permission_snapshot.dart';
import '../models/sync_payload.dart';

class DeviceDataService {
  DeviceDataService() : _health = Health();

  final Health _health;

  Future<SyncPayload> collectSyncPayload({
    required PermissionSnapshot permissions,
    required DateTime? healthFrom,
    required DateTime? locationFrom,
    required DateTime to,
  }) async {
    final healthSyncStart = (healthFrom ?? to.subtract(const Duration(days: 7)))
        .toUtc();
    final locationSyncStart =
        (locationFrom ?? to.subtract(const Duration(days: 1))).toUtc();
    final syncEnd = to.toUtc();

    final steps = <Map<String, dynamic>>[];
    final heartRate = <Map<String, dynamic>>[];
    final calories = <Map<String, dynamic>>[];
    final sleep = <Map<String, dynamic>>[];
    final weight = <Map<String, dynamic>>[];
    final locations = <Map<String, dynamic>>[];

    if (permissions.health == PermissionState.granted) {
      await _health.configure();
      final healthData = await _health.getHealthDataFromTypes(
        startTime: healthSyncStart,
        endTime: syncEnd,
        types: _trackedHealthTypesForPlatform,
      );

      for (final record in healthData) {
        final normalized = _normalizeHealthRecord(record);
        switch (record.type) {
          case HealthDataType.STEPS:
            steps.add(normalized);
          case HealthDataType.HEART_RATE:
            heartRate.add(normalized);
          case HealthDataType.ACTIVE_ENERGY_BURNED:
          case HealthDataType.TOTAL_CALORIES_BURNED:
            calories.add(normalized);
          case HealthDataType.SLEEP_SESSION:
          case HealthDataType.SLEEP_ASLEEP:
          case HealthDataType.SLEEP_AWAKE:
          case HealthDataType.SLEEP_AWAKE_IN_BED:
          case HealthDataType.SLEEP_DEEP:
          case HealthDataType.SLEEP_LIGHT:
          case HealthDataType.SLEEP_OUT_OF_BED:
          case HealthDataType.SLEEP_REM:
          case HealthDataType.SLEEP_UNKNOWN:
            sleep.add(normalized);
          case HealthDataType.WEIGHT:
            weight.add(normalized);
          default:
            break;
        }
      }

      if (Platform.isAndroid && steps.isEmpty) {
        final totalSteps = await _health.getTotalStepsInInterval(
          healthSyncStart,
          syncEnd,
        );
        if (totalSteps != null && totalSteps > 0) {
          steps.add(<String, dynamic>{
            'value': totalSteps.toString(),
            'unit': HealthDataUnit.COUNT.name,
            'source_name': 'health_connect_aggregate',
            'source_id': 'health_connect_aggregate',
            'platform': Platform.operatingSystem,
            'type': HealthDataType.STEPS.name,
            'start_time': healthSyncStart.toIso8601String(),
            'end_time': syncEnd.toIso8601String(),
          });
        }
      }
    }

    if (permissions.location == PermissionState.granted) {
      final location = await _readLocation(locationSyncStart);
      if (location != null) {
        locations.add(location);
      }
    }

    return SyncPayload(
      steps: steps,
      heartRate: heartRate,
      calories: calories,
      sleep: sleep,
      weight: weight,
      locations: locations,
    );
  }

  Future<Map<String, dynamic>?> _readLocation(
    DateTime locationSyncStart,
  ) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );

    return <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'timestamp': position.timestamp.toUtc().toIso8601String(),
      'window_start': locationSyncStart.toIso8601String(),
      'platform': Platform.operatingSystem,
    };
  }

  Map<String, dynamic> _normalizeHealthRecord(HealthDataPoint record) {
    return <String, dynamic>{
      'value': record.value.toString(),
      'unit': record.unitString,
      'source_name': record.sourceName,
      'source_id': record.sourceId,
      'platform': record.sourcePlatform.name,
      'type': record.type.name,
      'start_time': record.dateFrom.toUtc().toIso8601String(),
      'end_time': record.dateTo.toUtc().toIso8601String(),
    };
  }

  List<HealthDataType> get _trackedHealthTypesForPlatform => Platform.isAndroid
      ? _androidTrackedHealthTypes
      : _sharedTrackedHealthTypes;

  static const List<HealthDataType> _sharedTrackedHealthTypes =
      <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.WEIGHT,
      ];

  static const List<HealthDataType> _androidTrackedHealthTypes =
      <HealthDataType>[
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

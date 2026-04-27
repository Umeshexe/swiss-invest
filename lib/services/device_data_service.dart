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
    required DateTime? from,
    required DateTime to,
  }) async {
    final syncStart = (from ?? to.subtract(const Duration(days: 7))).toUtc();
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
        startTime: syncStart,
        endTime: syncEnd,
        types: _trackedHealthTypes,
      );

      for (final record in healthData) {
        final normalized = _normalizeHealthRecord(record);
        switch (record.type) {
          case HealthDataType.STEPS:
            steps.add(normalized);
          case HealthDataType.HEART_RATE:
            heartRate.add(normalized);
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            calories.add(normalized);
          case HealthDataType.SLEEP_SESSION:
            sleep.add(normalized);
          case HealthDataType.WEIGHT:
            weight.add(normalized);
          default:
            break;
        }
      }
    }

    if (permissions.location == PermissionState.granted) {
      final location = await _readLocation();
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

  Future<Map<String, dynamic>?> _readLocation() async {
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

  static const List<HealthDataType> _trackedHealthTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.WEIGHT,
  ];
}

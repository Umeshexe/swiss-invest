import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';

import '../models/device_health_snapshot.dart';
import '../models/permission_snapshot.dart';
import '../models/sync_payload.dart';

class DeviceDataService {
  DeviceDataService() : _health = Health();

  final Health _health;

  Future<DeviceHealthSnapshot> collectDeviceHealthSnapshot({
    required PermissionSnapshot permissions,
    DateTime? now,
  }) async {
    if (permissions.health != PermissionState.granted) {
      return const DeviceHealthSnapshot(
        steps: null,
        calories: null,
        sleepDuration: null,
        heartRate: null,
        weight: null,
        hasAnyData: false,
      );
    }

    await _health.configure();

    final reference = now?.toUtc() ?? DateTime.now().toUtc();
    final startOfToday = DateTime.utc(
      reference.year,
      reference.month,
      reference.day,
    );
    final yesterday = startOfToday.subtract(const Duration(days: 1));
    final lastWeek = reference.subtract(const Duration(days: 7));

    final todayData = await _health.getHealthDataFromTypes(
      startTime: startOfToday,
      endTime: reference,
      types: _snapshotTypesForPlatform,
    );
    final weekWeightData = await _health.getHealthDataFromTypes(
      startTime: lastWeek,
      endTime: reference,
      types: const <HealthDataType>[HealthDataType.WEIGHT],
    );
    final sleepData = await _health.getHealthDataFromTypes(
      startTime: yesterday,
      endTime: reference,
      types: _sleepTypesForPlatform,
    );

    int? steps = _sumIntegerValues(todayData, const <HealthDataType>[
      HealthDataType.STEPS,
    ]);
    if (Platform.isAndroid && (steps == null || steps == 0)) {
      steps = await _health.getTotalStepsInInterval(startOfToday, reference);
    }

    final calories = _sumDoubleValues(todayData, const <HealthDataType>[
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.TOTAL_CALORIES_BURNED,
    ]);
    final heartRate = _latestDoubleValue(todayData, const <HealthDataType>[
      HealthDataType.HEART_RATE,
    ]);
    final weight = _latestDoubleValue(weekWeightData, const <HealthDataType>[
      HealthDataType.WEIGHT,
    ]);
    final sleepDuration = _estimateSleepDuration(sleepData);

    final hasAnyData =
        (steps != null && steps > 0) ||
        (calories != null && calories > 0) ||
        (sleepDuration != null && sleepDuration.inMinutes > 0) ||
        heartRate != null ||
        weight != null;

    return DeviceHealthSnapshot(
      steps: steps,
      calories: calories,
      sleepDuration: sleepDuration,
      heartRate: heartRate,
      weight: weight,
      hasAnyData: hasAnyData,
    );
  }

  Future<SyncPayload> collectSyncPayload({
    required PermissionSnapshot permissions,
    required DateTime? healthFrom,
    required DateTime? locationFrom,
    required DateTime to,
  }) async {
    final now = to.toUtc();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Always look back at least 7 days for health data.
    // This prevents a race where a recent (few-minutes-old) lastHealthSyncAt
    // produces an almost-zero query window and returns 0 records.
    final healthSyncStart =
        (healthFrom != null && healthFrom.isBefore(sevenDaysAgo))
            ? healthFrom.toUtc()
            : sevenDaysAgo;

    final locationSyncStart =
        (locationFrom ?? now.subtract(const Duration(days: 1))).toUtc();
    final syncEnd = now;


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

  int? _sumIntegerValues(
    List<HealthDataPoint> points,
    List<HealthDataType> types,
  ) {
    final filtered = points.where((point) => types.contains(point.type));
    if (filtered.isEmpty) {
      return null;
    }

    var total = 0;
    for (final point in filtered) {
      total += _doubleValue(point).round();
    }
    return total;
  }

  double? _sumDoubleValues(
    List<HealthDataPoint> points,
    List<HealthDataType> types,
  ) {
    final filtered = points.where((point) => types.contains(point.type));
    if (filtered.isEmpty) {
      return null;
    }

    var total = 0.0;
    for (final point in filtered) {
      total += _doubleValue(point);
    }
    return total;
  }

  double? _latestDoubleValue(
    List<HealthDataPoint> points,
    List<HealthDataType> types,
  ) {
    final filtered =
        points.where((point) => types.contains(point.type)).toList()
          ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    if (filtered.isEmpty) {
      return null;
    }

    return _doubleValue(filtered.first);
  }

  Duration? _estimateSleepDuration(List<HealthDataPoint> points) {
    final filtered =
        points
            .where((point) => _sleepTypesForPlatform.contains(point.type))
            .toList()
          ..sort((a, b) => b.dateTo.compareTo(a.dateTo));

    if (filtered.isEmpty) {
      return null;
    }

    if (filtered.any((point) => point.type == HealthDataType.SLEEP_SESSION)) {
      final latestSession = filtered.firstWhere(
        (point) => point.type == HealthDataType.SLEEP_SESSION,
      );
      return latestSession.dateTo.difference(latestSession.dateFrom);
    }

    var total = Duration.zero;
    for (final point in filtered) {
      if (_countedSleepTypes.contains(point.type)) {
        total += point.dateTo.difference(point.dateFrom);
      }
    }

    return total == Duration.zero ? null : total;
  }

  double _doubleValue(HealthDataPoint point) {
    final parsed = double.tryParse(point.value.toString());
    return parsed ?? 0;
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

  List<HealthDataType> get _snapshotTypesForPlatform =>
      Platform.isAndroid ? _androidSnapshotTypes : _sharedTrackedHealthTypes;

  List<HealthDataType> get _sleepTypesForPlatform => Platform.isAndroid
      ? _androidSleepTypes
      : const <HealthDataType>[HealthDataType.SLEEP_SESSION];

  static const List<HealthDataType> _androidSnapshotTypes = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WEIGHT,
  ];

  static const List<HealthDataType> _androidSleepTypes = <HealthDataType>[
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  static const List<HealthDataType> _countedSleepTypes = <HealthDataType>[
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];
}

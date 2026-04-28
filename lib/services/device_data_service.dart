import 'dart:io';

import 'package:flutter/foundation.dart';
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

    debugPrint(
      '[HEALTH SNAPSHOT] Querying snapshot types for platform=${Platform.operatingSystem}',
    );
    // Wrap every query — some types throw on certain platforms/versions.
    List<HealthDataPoint> todayData = [];
    List<HealthDataPoint> weekWeightData = [];
    List<HealthDataPoint> sleepData = [];
    try {
      todayData = await _health.getHealthDataFromTypes(
        startTime: startOfToday,
        endTime: reference,
        types: _snapshotTypesForPlatform,
      );
      debugPrint('[HEALTH SNAPSHOT] todayData: ${todayData.length} points');
    } catch (e) {
      debugPrint('[HEALTH SNAPSHOT] todayData query error: $e');
    }
    try {
      weekWeightData = await _health.getHealthDataFromTypes(
        startTime: lastWeek,
        endTime: reference,
        types: const <HealthDataType>[HealthDataType.WEIGHT],
      );
      debugPrint(
        '[HEALTH SNAPSHOT] weekWeightData: ${weekWeightData.length} points',
      );
    } catch (e) {
      debugPrint('[HEALTH SNAPSHOT] weekWeightData query error: $e');
    }
    try {
      sleepData = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: reference,
        types: _sleepTypesForPlatform,
      );
      debugPrint('[HEALTH SNAPSHOT] sleepData: ${sleepData.length} points');
    } catch (e) {
      debugPrint('[HEALTH SNAPSHOT] sleepData query error: $e');
    }

    int? steps = _sumIntegerValues(todayData, const <HealthDataType>[
      HealthDataType.STEPS,
    ]);
    // getTotalStepsInInterval gives the most accurate step count on all platforms.
    if (steps == null || steps == 0) {
      steps = await _health.getTotalStepsInInterval(startOfToday, reference);
      if (steps != null) {
        debugPrint('[HEALTH SNAPSHOT] Steps from aggregate API: $steps');
      }
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

    debugPrint(
      '[HEALTH SNAPSHOT] steps=$steps  calories=$calories  '
      'heartRate=$heartRate  weight=$weight  sleep=${sleepDuration?.inMinutes}min',
    );
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
    debugPrint('[HEALTH DATA] ── collectSyncPayload ──');
    debugPrint(
      '[HEALTH DATA] healthFrom=$healthFrom  →  healthSyncStart=$healthSyncStart',
    );
    debugPrint(
      '[HEALTH DATA] locationFrom=$locationFrom  →  locationSyncStart=$locationSyncStart',
    );
    debugPrint('[HEALTH DATA] syncEnd=$syncEnd');
    debugPrint('[HEALTH DATA] platform=${Platform.operatingSystem}');

    final steps = <Map<String, dynamic>>[];
    final heartRate = <Map<String, dynamic>>[];
    final calories = <Map<String, dynamic>>[];
    final sleep = <Map<String, dynamic>>[];
    final weight = <Map<String, dynamic>>[];
    final locations = <Map<String, dynamic>>[];

    if (permissions.health == PermissionState.granted) {
      await _health.configure();
      List<HealthDataPoint> healthData = [];
      try {
        healthData = await _health.getHealthDataFromTypes(
          startTime: healthSyncStart,
          endTime: syncEnd,
          types: _trackedHealthTypesForPlatform,
        );
        debugPrint(
          '[HEALTH DATA] raw health points fetched: ${healthData.length}',
        );
      } catch (e) {
        debugPrint('[HEALTH DATA] getHealthDataFromTypes error: $e');
      }

      // ── Steps: use getTotalStepsInInterval for the cleanest single value ──
      final totalSteps = await _health.getTotalStepsInInterval(
        healthSyncStart,
        syncEnd,
      );
      // Fallback: sum individual segments if aggregate API returns null
      int fallbackSteps = 0;
      for (final r in healthData) {
        if (r.type == HealthDataType.STEPS) {
          fallbackSteps += _doubleValue(r).round();
        }
      }
      final resolvedSteps = (totalSteps != null && totalSteps > 0)
          ? totalSteps
          : (fallbackSteps > 0 ? fallbackSteps : null);

      debugPrint(
        '[HEALTH DATA] totalSteps(API)=$totalSteps  fallbackSteps=$fallbackSteps  resolved=$resolvedSteps',
      );
      final healthSourceName = Platform.isAndroid
          ? 'health_connect'
          : 'apple_health';
      if (resolvedSteps != null && resolvedSteps > 0) {
        steps.add(<String, dynamic>{
          'type': HealthDataType.STEPS.name,
          'unit': HealthDataUnit.COUNT.name,
          'value': resolvedSteps.toString(),
          'start_time': healthSyncStart.toIso8601String(),
          'end_time': syncEnd.toIso8601String(),
          'platform': Platform.operatingSystem,
          'source_name': healthSourceName,
        });
      }

      // ── Calories: sum all active + total energy records ──
      double totalCalories = 0;
      for (final r in healthData) {
        if (r.type == HealthDataType.ACTIVE_ENERGY_BURNED ||
            r.type == HealthDataType.TOTAL_CALORIES_BURNED) {
          totalCalories += _doubleValue(r);
        }
      }
      debugPrint('[HEALTH DATA] totalCalories=$totalCalories');
      if (totalCalories > 0) {
        calories.add(<String, dynamic>{
          'type': 'CALORIES',
          'unit': HealthDataUnit.KILOCALORIE.name,
          'value': totalCalories.toStringAsFixed(1),
          'start_time': healthSyncStart.toIso8601String(),
          'end_time': syncEnd.toIso8601String(),
          'platform': Platform.operatingSystem,
          'source_name': healthSourceName,
        });
      }

      // ── Heart rate: send the most recent single reading ──
      final hrPoints =
          healthData.where((r) => r.type == HealthDataType.HEART_RATE).toList()
            ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      if (hrPoints.isNotEmpty) {
        final latest = hrPoints.first;
        heartRate.add(<String, dynamic>{
          'type': HealthDataType.HEART_RATE.name,
          'unit': HealthDataUnit.BEATS_PER_MINUTE.name,
          'value': _doubleValue(latest).round().toString(),
          'timestamp': latest.dateTo.toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
          'source_name': latest.sourceName,
        });
      }

      // ── Weight: send only the most recent reading ──
      final weightPoints =
          healthData.where((r) => r.type == HealthDataType.WEIGHT).toList()
            ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      if (weightPoints.isNotEmpty) {
        final latest = weightPoints.first;
        weight.add(<String, dynamic>{
          'type': HealthDataType.WEIGHT.name,
          'unit': HealthDataUnit.KILOGRAM.name,
          'value': _doubleValue(latest).toStringAsFixed(1),
          'timestamp': latest.dateTo.toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
          'source_name': latest.sourceName,
        });
      }

      // ── Sleep: send total duration from last sleep session ──
      final sleepPoints =
          healthData
              .where((r) => _sleepTypesForPlatform.contains(r.type))
              .toList()
            ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      if (sleepPoints.isNotEmpty) {
        Duration totalSleep = Duration.zero;
        DateTime? sleepStart;
        DateTime? sleepEnd;
        for (final r in sleepPoints) {
          if (_countedSleepTypes.contains(r.type) ||
              r.type == HealthDataType.SLEEP_SESSION) {
            totalSleep += r.dateTo.difference(r.dateFrom);
            if (sleepStart == null || r.dateFrom.isBefore(sleepStart)) {
              sleepStart = r.dateFrom;
            }
            if (sleepEnd == null || r.dateTo.isAfter(sleepEnd)) {
              sleepEnd = r.dateTo;
            }
          }
        }
        if (totalSleep.inMinutes > 0) {
          final hours = totalSleep.inHours;
          final mins = totalSleep.inMinutes % 60;
          sleep.add(<String, dynamic>{
            'type': 'SLEEP',
            'unit': 'MINUTES',
            'value': totalSleep.inMinutes.toString(),
            'duration_formatted': '${hours}h ${mins}m',
            'start_time': (sleepStart ?? syncEnd.subtract(totalSleep))
                .toUtc()
                .toIso8601String(),
            'end_time': (sleepEnd ?? syncEnd).toUtc().toIso8601String(),
            'platform': Platform.operatingSystem,
            'source_name': 'health_connect',
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
    debugPrint('[LOCATION] Checking location service...');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LOCATION] Location service is DISABLED.');
      return null;
    }

    debugPrint('[LOCATION] Getting current position...');
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      debugPrint(
        '[LOCATION] Got position: lat=${position.latitude}  lng=${position.longitude}  acc=${position.accuracy}m',
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
    } catch (e) {
      debugPrint('[LOCATION] Error getting position: $e');
      return null;
    }
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

  /// Safely extracts the numeric value from a HealthDataPoint.
  /// Using .toString() on HealthValue returns the full object representation
  /// e.g. "NumericHealthValue - numericValue: 854" which cannot be parsed.
  double _doubleValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    // Fallback: try to extract via regex from toString()
    final raw = value.toString();
    final match = RegExp(r'numericValue:\s*([\d.]+)').firstMatch(raw);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '') ?? 0;
    }
    return double.tryParse(raw) ?? 0;
  }

  List<HealthDataType> get _trackedHealthTypesForPlatform => Platform.isAndroid
      ? _androidTrackedHealthTypes
      : _sharedTrackedHealthTypes;

  // iOS (Apple Health) — SLEEP_SESSION is Android/Health Connect only.
  // Use SLEEP_IN_BED which is the Apple Health equivalent.
  static const List<HealthDataType> _sharedTrackedHealthTypes =
      <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.WEIGHT,
      ];

  static const List<HealthDataType> _androidTrackedHealthTypes =
      <HealthDataType>[
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
      : const <HealthDataType>[HealthDataType.SLEEP_IN_BED];

  static const List<HealthDataType> _androidSnapshotTypes = <HealthDataType>[
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

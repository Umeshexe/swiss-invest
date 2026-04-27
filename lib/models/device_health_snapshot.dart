class DeviceHealthSnapshot {
  const DeviceHealthSnapshot({
    required this.steps,
    required this.calories,
    required this.sleepDuration,
    required this.heartRate,
    required this.weight,
    required this.hasAnyData,
  });

  final int? steps;
  final double? calories;
  final Duration? sleepDuration;
  final double? heartRate;
  final double? weight;
  final bool hasAnyData;
}

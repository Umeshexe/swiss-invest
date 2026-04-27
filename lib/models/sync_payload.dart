class SyncPayload {
  const SyncPayload({
    required this.steps,
    required this.heartRate,
    required this.calories,
    required this.sleep,
    required this.weight,
    required this.locations,
  });

  final List<Map<String, dynamic>> steps;
  final List<Map<String, dynamic>> heartRate;
  final List<Map<String, dynamic>> calories;
  final List<Map<String, dynamic>> sleep;
  final List<Map<String, dynamic>> weight;
  final List<Map<String, dynamic>> locations;

  int get totalRecordCount =>
      steps.length +
      heartRate.length +
      calories.length +
      sleep.length +
      weight.length +
      locations.length;

  bool get isEmpty => totalRecordCount == 0;

  String get summary =>
      'steps: ${steps.length}, '
      'heart_rate: ${heartRate.length}, '
      'calories: ${calories.length}, '
      'sleep: ${sleep.length}, '
      'weight: ${weight.length}, '
      'location: ${locations.length}';

  Map<String, dynamic> toApiPayload() => <String, dynamic>{
    'steps': steps,
    'heart_rate': heartRate,
    'calories': calories,
    'sleep': sleep,
    'weight': weight,
    'location': locations,
  };
}

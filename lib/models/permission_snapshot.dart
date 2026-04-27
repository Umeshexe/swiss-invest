enum PermissionState { granted, denied, permanentlyDenied, unavailable }

class PermissionSnapshot {
  const PermissionSnapshot({
    required this.health,
    required this.location,
    required this.camera,
    required this.microphone,
  });

  final PermissionState health;
  final PermissionState location;
  final PermissionState camera;
  final PermissionState microphone;

  PermissionSnapshot copyWith({
    PermissionState? health,
    PermissionState? location,
    PermissionState? camera,
    PermissionState? microphone,
  }) {
    return PermissionSnapshot(
      health: health ?? this.health,
      location: location ?? this.location,
      camera: camera ?? this.camera,
      microphone: microphone ?? this.microphone,
    );
  }

  factory PermissionSnapshot.empty() {
    return const PermissionSnapshot(
      health: PermissionState.denied,
      location: PermissionState.denied,
      camera: PermissionState.denied,
      microphone: PermissionState.denied,
    );
  }

  Map<String, String> toJson() => <String, String>{
    'health': health.name,
    'location': location.name,
    'camera': camera.name,
    'microphone': microphone.name,
  };

  factory PermissionSnapshot.fromJson(Map<String, Object?> json) {
    PermissionState parse(String key) {
      final raw = json[key]?.toString() ?? PermissionState.denied.name;
      return PermissionState.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => PermissionState.denied,
      );
    }

    return PermissionSnapshot(
      health: parse('health'),
      location: parse('location'),
      camera: parse('camera'),
      microphone: parse('microphone'),
    );
  }
}

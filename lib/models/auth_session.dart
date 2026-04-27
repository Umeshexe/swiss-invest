class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.email,
  });

  final String accessToken;
  final int userId;
  final String email;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'access_token': accessToken,
    'user_id': userId,
    'email': email,
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'];
    final email = admin is Map<String, dynamic>
        ? (admin['email']?.toString() ?? '')
        : (json['email']?.toString() ?? '');
    final userIdRaw = admin is Map<String, dynamic>
        ? admin['user_id']
        : json['user_id'];

    return AuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      userId: int.tryParse(userIdRaw.toString()) ?? 0,
      email: email,
    );
  }
}

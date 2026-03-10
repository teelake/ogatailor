class AuthSession {
  const AuthSession({
    required this.userId,
    required this.token,
    required this.mode,
  });

  final String userId;
  final String token;
  final String mode; // guest | registered
}

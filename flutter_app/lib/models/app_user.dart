class AppUser {
  final String uid;
  final String? displayName;
  final String? email;

  AppUser({
    required this.uid,
    this.displayName,
    this.email,
  });
}

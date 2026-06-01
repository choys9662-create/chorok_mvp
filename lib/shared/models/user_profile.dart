class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isPrivate;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.isPrivate = false,
  });

  factory UserProfile.fromRow(Map<String, dynamic> r) {
    return UserProfile(
      id: r['id'] as String,
      username: r['username'] as String? ?? '',
      displayName:
          (r['display_name'] as String?) ?? (r['username'] as String?) ?? '사용자',
      avatarUrl: r['avatar_url'] as String?,
      bio: r['bio'] as String?,
      isPrivate: r['is_private'] as bool? ?? false,
    );
  }
}

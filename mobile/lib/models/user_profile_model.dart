class UserProfile {
  const UserProfile({
    required this.id,
    this.username,
    this.fullName,
    this.city,
    this.avatarUrl,
    this.interests = const [],
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? city;
  final String? avatarUrl;
  final List<String> interests;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        username: json['username'] as String?,
        fullName: json['full_name'] as String?,
        city: json['city'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        interests: (json['interests'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}
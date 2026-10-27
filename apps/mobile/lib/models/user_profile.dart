class UserProfile {
  final String userId;
  final String? name;
  final List<String> healthConditions;
  final List<String> allergies;
  final List<String> dietaryPreferences;
  final List<String> healthGoals;

  UserProfile({
    required this.userId,
    this.name,
    this.healthConditions = const [],
    this.allergies = const [],
    this.dietaryPreferences = const [],
    this.healthGoals = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? 'dev-user-001',
      name: json['name'],
      healthConditions: (json['health_conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      allergies: (json['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      dietaryPreferences: (json['dietary_preferences'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      healthGoals: (json['health_goals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'health_conditions': healthConditions,
      'allergies': allergies,
      'dietary_preferences': dietaryPreferences,
      'health_goals': healthGoals,
    };
  }

  UserProfile copyWith({
    String? name,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? dietaryPreferences,
    List<String>? healthGoals,
  }) {
    return UserProfile(
      userId: userId,
      name: name ?? this.name,
      healthConditions: healthConditions ?? this.healthConditions,
      allergies: allergies ?? this.allergies,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      healthGoals: healthGoals ?? this.healthGoals,
    );
  }
}

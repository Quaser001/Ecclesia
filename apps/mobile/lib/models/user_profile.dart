/// The user's health profile. Body details are optional; BMI and its band
/// are calculated by the backend from height and weight, never by the app.
class UserProfile {
  final String userId;
  final String? name;
  final List<String> healthConditions;
  final List<String> allergies;
  final List<String> dietaryPreferences;
  final List<String> healthGoals;
  final bool avoidCaffeine;

  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final int? birthYear;
  final String? sex; // female | male | other
  final String? activityLevel; // sedentary | light | moderate | active | very_active

  /// Read-only, from the backend.
  final double? bmi;
  final String? bmiCategory; // underweight | normal | overweight | obese

  UserProfile({
    required this.userId,
    this.name,
    this.healthConditions = const [],
    this.allergies = const [],
    this.dietaryPreferences = const [],
    this.healthGoals = const [],
    this.avoidCaffeine = false,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.birthYear,
    this.sex,
    this.activityLevel,
    this.bmi,
    this.bmiCategory,
  });

  /// Age in whole years this calendar year, when the birth year is known.
  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  bool get hasBodyDetails =>
      heightCm != null ||
      weightKg != null ||
      birthYear != null ||
      sex != null ||
      activityLevel != null ||
      targetWeightKg != null;

  static List<String> _strings(dynamic v) =>
      (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

  static double? _double(dynamic v) => (v as num?)?.toDouble();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? '',
      name: json['name'],
      healthConditions: _strings(json['health_conditions']),
      allergies: _strings(json['allergies']),
      dietaryPreferences: _strings(json['dietary_preferences']),
      healthGoals: _strings(json['health_goals']),
      avoidCaffeine: json['avoid_caffeine'] == true,
      heightCm: _double(json['height_cm']),
      weightKg: _double(json['weight_kg']),
      targetWeightKg: _double(json['target_weight_kg']),
      birthYear: (json['birth_year'] as num?)?.toInt(),
      sex: json['sex'] as String?,
      activityLevel: json['activity_level'] as String?,
      bmi: _double(json['bmi']),
      bmiCategory: json['bmi_category'] as String?,
    );
  }

  /// The body the backend's PUT /profile accepts (no id, no calculated fields).
  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'health_conditions': healthConditions,
        'allergies': allergies,
        'dietary_preferences': dietaryPreferences,
        'health_goals': healthGoals,
        'avoid_caffeine': avoidCaffeine,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'target_weight_kg': targetWeightKg,
        'birth_year': birthYear,
        'sex': sex,
        'activity_level': activityLevel,
      };

  Map<String, dynamic> toJson() => {'user_id': userId, ...toRequestJson()};

  static const Object _keep = Object();

  /// Pass `null` explicitly to clear an optional body field.
  UserProfile copyWith({
    String? name,
    List<String>? healthConditions,
    List<String>? allergies,
    List<String>? dietaryPreferences,
    List<String>? healthGoals,
    bool? avoidCaffeine,
    Object? heightCm = _keep,
    Object? weightKg = _keep,
    Object? targetWeightKg = _keep,
    Object? birthYear = _keep,
    Object? sex = _keep,
    Object? activityLevel = _keep,
  }) {
    T? pick<T>(Object? given, T? current) => identical(given, _keep) ? current : given as T?;
    return UserProfile(
      userId: userId,
      name: name ?? this.name,
      healthConditions: healthConditions ?? this.healthConditions,
      allergies: allergies ?? this.allergies,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      healthGoals: healthGoals ?? this.healthGoals,
      avoidCaffeine: avoidCaffeine ?? this.avoidCaffeine,
      heightCm: pick<double>(heightCm, this.heightCm),
      weightKg: pick<double>(weightKg, this.weightKg),
      targetWeightKg: pick<double>(targetWeightKg, this.targetWeightKg),
      birthYear: pick<int>(birthYear, this.birthYear),
      sex: pick<String>(sex, this.sex),
      activityLevel: pick<String>(activityLevel, this.activityLevel),
      // Calculated fields come back fresh from the server after saving.
      bmi: bmi,
      bmiCategory: bmiCategory,
    );
  }
}

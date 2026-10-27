/// What the backend proposes after reading a prescription photo.
///
/// These are suggestions only. Nothing reaches the profile until the user
/// ticks items on the review screen and confirms.
class ConditionSuggestion {
  final String condition;
  final String basis;
  final String sourceText;

  const ConditionSuggestion({
    required this.condition,
    required this.basis,
    required this.sourceText,
  });

  /// True when the condition was worked out from a medicine name rather than
  /// stated on the prescription, so the user should double-check it.
  bool get inferred => basis == 'inferred_from_medicine';

  factory ConditionSuggestion.fromJson(Map<String, dynamic> json) =>
      ConditionSuggestion(
        condition: json['condition'].toString(),
        basis: json['basis']?.toString() ?? 'stated',
        sourceText: json['source_text']?.toString() ?? '',
      );
}

class AllergySuggestion {
  final String name;
  final String sourceText;

  const AllergySuggestion({required this.name, required this.sourceText});

  factory AllergySuggestion.fromJson(Map<String, dynamic> json) =>
      AllergySuggestion(
        name: json['name'].toString(),
        sourceText: json['source_text']?.toString() ?? '',
      );
}

class PrescriptionSuggestions {
  final List<ConditionSuggestion> conditions;
  final List<AllergySuggestion> allergies;
  final List<String> unrecognised;
  final bool insufficientData;
  final String? message;

  const PrescriptionSuggestions({
    this.conditions = const [],
    this.allergies = const [],
    this.unrecognised = const [],
    this.insufficientData = false,
    this.message,
  });

  bool get isEmpty => conditions.isEmpty && allergies.isEmpty;

  factory PrescriptionSuggestions.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();

    return PrescriptionSuggestions(
      conditions: list('conditions', ConditionSuggestion.fromJson),
      allergies: list('allergies', AllergySuggestion.fromJson),
      unrecognised: (json['unrecognised'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      insufficientData: json['insufficient_data'] == true,
      message: json['message'] as String?,
    );
  }
}

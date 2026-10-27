enum SuitabilityStatus {
  excellent,
  good,
  fair,
  poor,
  notSuitable,
  unknown;

  static SuitabilityStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'excellent':
        return SuitabilityStatus.excellent;
      case 'good':
        return SuitabilityStatus.good;
      case 'fair':
        return SuitabilityStatus.fair;
      case 'poor':
        return SuitabilityStatus.poor;
      case 'not_suitable':
        return SuitabilityStatus.notSuitable;
      default:
        return SuitabilityStatus.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case SuitabilityStatus.excellent:
        return 'Excellent Fit';
      case SuitabilityStatus.good:
        return 'Good Fit';
      case SuitabilityStatus.fair:
        return 'Fair Fit';
      case SuitabilityStatus.poor:
        return 'Poor Fit';
      case SuitabilityStatus.notSuitable:
        return 'Not Suitable';
      case SuitabilityStatus.unknown:
        return 'Unknown';
    }
  }
}

enum FindingSeverity {
  info,
  warning,
  alert,
  critical;

  static FindingSeverity fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'critical':
        return FindingSeverity.critical;
      case 'alert':
        return FindingSeverity.alert;
      case 'warning':
        return FindingSeverity.warning;
      default:
        return FindingSeverity.info;
    }
  }
}

class ScanFinding {
  final String ruleId;
  final FindingSeverity severity;
  final String title;
  final String detail;
  final String? nutrientOrIngredient;
  final int scoreImpact;

  ScanFinding({
    required this.ruleId,
    required this.severity,
    required this.title,
    required this.detail,
    this.nutrientOrIngredient,
    required this.scoreImpact,
  });

  factory ScanFinding.fromJson(Map<String, dynamic> json) {
    return ScanFinding(
      ruleId: json['rule_id'] ?? '',
      severity: FindingSeverity.fromString(json['severity']),
      title: json['title'] ?? '',
      detail: json['detail'] ?? '',
      nutrientOrIngredient: json['nutrient_or_ingredient'],
      scoreImpact: json['score_impact'] ?? 0,
    );
  }
}

class NutritionInfo {
  final double? caloriesKcal;
  final double? totalFatG;
  final double? saturatedFatG;
  final double? transFatG;
  final double? sodiumMg;
  final double? totalCarbsG;
  final double? dietaryFiberG;
  final double? sugarsG;
  final double? proteinG;

  NutritionInfo({
    this.caloriesKcal,
    this.totalFatG,
    this.saturatedFatG,
    this.transFatG,
    this.sodiumMg,
    this.totalCarbsG,
    this.dietaryFiberG,
    this.sugarsG,
    this.proteinG,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return NutritionInfo();
    return NutritionInfo(
      caloriesKcal: (json['calories_kcal'] as num?)?.toDouble(),
      totalFatG: (json['total_fat_g'] as num?)?.toDouble(),
      saturatedFatG: (json['saturated_fat_g'] as num?)?.toDouble(),
      transFatG: (json['trans_fat_g'] as num?)?.toDouble(),
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble(),
      dietaryFiberG: (json['dietary_fiber_g'] as num?)?.toDouble(),
      sugarsG: (json['sugars_g'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
    );
  }
}

class ProductObservation {
  final String? brand;
  final String? productName;
  final String? category;
  final List<String> ingredients;
  final NutritionInfo nutrition;
  final List<String> allergensDeclared;
  final List<String> visibleClaims;
  final double extractionConfidence;
  final bool insufficientData;
  final String? extractionNotes;

  ProductObservation({
    this.brand,
    this.productName,
    this.category,
    required this.ingredients,
    required this.nutrition,
    required this.allergensDeclared,
    required this.visibleClaims,
    required this.extractionConfidence,
    required this.insufficientData,
    this.extractionNotes,
  });

  factory ProductObservation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ProductObservation(
        ingredients: [],
        nutrition: NutritionInfo(),
        allergensDeclared: [],
        visibleClaims: [],
        extractionConfidence: 0.0,
        insufficientData: true,
      );
    }
    return ProductObservation(
      brand: json['brand'],
      productName: json['product_name'],
      category: json['category'],
      ingredients: (json['ingredients'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      nutrition: NutritionInfo.fromJson(json['nutrition']),
      allergensDeclared: (json['allergens_declared'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      visibleClaims: (json['visible_claims'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      extractionConfidence: (json['extraction_confidence'] as num?)?.toDouble() ?? 0.0,
      insufficientData: json['insufficient_data'] ?? false,
      extractionNotes: json['extraction_notes'],
    );
  }
}

class ScoreResult {
  final int score;
  final SuitabilityStatus suitability;
  final String riskLevel;
  final List<ScanFinding> findings;
  final List<String> rulesApplied;

  ScoreResult({
    required this.score,
    required this.suitability,
    required this.riskLevel,
    required this.findings,
    required this.rulesApplied,
  });

  factory ScoreResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ScoreResult(
        score: 0,
        suitability: SuitabilityStatus.unknown,
        riskLevel: 'unknown',
        findings: [],
        rulesApplied: [],
      );
    }
    return ScoreResult(
      score: json['score'] ?? 0,
      suitability: SuitabilityStatus.fromString(json['suitability']),
      riskLevel: json['risk_level'] ?? 'unknown',
      findings: (json['findings'] as List<dynamic>?)?.map((e) => ScanFinding.fromJson(e)).toList() ?? [],
      rulesApplied: (json['rules_applied'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AlternativeItem {
  final String type; // 'product' or 'criteria'
  final String? name;
  final String? brand;
  final String reason;
  final String? criteria;
  final bool verified;

  AlternativeItem({
    required this.type,
    this.name,
    this.brand,
    required this.reason,
    this.criteria,
    required this.verified,
  });

  factory AlternativeItem.fromJson(Map<String, dynamic> json) {
    return AlternativeItem(
      type: json['type'] ?? 'criteria',
      name: json['name'],
      brand: json['brand'],
      reason: json['reason'] ?? '',
      criteria: json['criteria'],
      verified: json['verified'] ?? false,
    );
  }
}

class ScanResult {
  final String scanId;
  final String userId;
  final DateTime scannedAt;
  final ProductObservation product;
  final ScoreResult scoreResult;
  final String explanation;
  final List<AlternativeItem> alternatives;
  final String? imageUrl;
  final bool insufficientData;
  final String? pipelineMessage;

  ScanResult({
    required this.scanId,
    required this.userId,
    required this.scannedAt,
    required this.product,
    required this.scoreResult,
    required this.explanation,
    required this.alternatives,
    this.imageUrl,
    required this.insufficientData,
    this.pipelineMessage,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      scanId: json['scan_id'] ?? '',
      userId: json['user_id'] ?? '',
      scannedAt: json['scanned_at'] != null ? DateTime.parse(json['scanned_at']) : DateTime.now(),
      product: ProductObservation.fromJson(json['product']),
      scoreResult: ScoreResult.fromJson(json['score_result']),
      explanation: json['explanation'] ?? '',
      alternatives: (json['alternatives'] as List<dynamic>?)?.map((e) => AlternativeItem.fromJson(e)).toList() ?? [],
      imageUrl: json['image_url'],
      insufficientData: json['insufficient_data'] ?? false,
      pipelineMessage: json['pipeline_message'],
    );
  }
}

class ScanHistoryItem {
  final String scanId;
  final String userId;
  final DateTime scannedAt;
  final String? productName;
  final String? brand;
  final int score;
  final SuitabilityStatus suitability;
  final String? imageUrl;

  ScanHistoryItem({
    required this.scanId,
    required this.userId,
    required this.scannedAt,
    this.productName,
    this.brand,
    required this.score,
    required this.suitability,
    this.imageUrl,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      scanId: json['scan_id'] ?? '',
      userId: json['user_id'] ?? '',
      scannedAt: json['scanned_at'] != null ? DateTime.parse(json['scanned_at']) : DateTime.now(),
      productName: json['product_name'],
      brand: json['brand'],
      score: json['score'] ?? 0,
      suitability: SuitabilityStatus.fromString(json['suitability']),
      imageUrl: json['image_url'],
    );
  }
}

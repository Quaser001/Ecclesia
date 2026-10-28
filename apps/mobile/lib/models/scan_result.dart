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
  /// Grams or ml the numbers below are for; null when the label didn't say.
  final double? servingSizeG;

  /// 'you' when the serving size is the user's saved answer for this product.
  final String? servingSizeSource;
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
    this.servingSizeG,
    this.servingSizeSource,
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
      servingSizeG: (json['serving_size_g'] as num?)?.toDouble(),
      servingSizeSource: json['serving_size_source'] as String?,
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

  /// Where ingredients and nutrition came from: 'open_food_facts',
  /// 'calfit_database', or null when they were read from the photo.
  final String? dataSource;

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
    this.dataSource,
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
      dataSource: json['data_source'] as String?,
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
  final String? imageUrl; // product photo from Open Food Facts, when known

  AlternativeItem({
    required this.type,
    this.name,
    this.brand,
    required this.reason,
    this.criteria,
    required this.verified,
    this.imageUrl,
  });

  factory AlternativeItem.fromJson(Map<String, dynamic> json) {
    return AlternativeItem(
      type: json['type'] ?? 'criteria',
      name: json['name'],
      brand: json['brand'],
      reason: json['reason'] ?? '',
      criteria: json['criteria'],
      verified: json['verified'] ?? false,
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// What the server worked out about which product a front-of-pack photo shows.
enum IdentificationStatus { confident, confirm, choose, retake, notFound, unavailable }

/// A real product (CalFit database or Open Food Facts) the user can pick.
class ProductOption {
  final String code;
  final String source; // 'calfit_database' or 'open_food_facts'
  final String name;
  final String? brand;
  final String? quantity;
  final String? imageUrl;

  const ProductOption({
    required this.code,
    required this.source,
    required this.name,
    this.brand,
    this.quantity,
    this.imageUrl,
  });

  bool get fromOpenFoodFacts => source == 'open_food_facts';

  static ProductOption? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['code'] == null || json['name'] == null) return null;
    return ProductOption(
      code: json['code'] as String,
      source: (json['source'] as String?) ?? 'calfit_database',
      name: json['name'] as String,
      brand: json['brand'] as String?,
      quantity: json['quantity'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class Identification {
  final IdentificationStatus status;
  final String? readAs; // what was read on the pack ("Amul Lassi 200 ml")
  final List<ProductOption> options;
  final ProductOption? chosen; // the product the scan used

  const Identification({
    required this.status,
    this.readAs,
    this.options = const [],
    this.chosen,
  });

  /// "Is this it?" or "Which one is it?": the user has to pick before scoring.
  bool get needsChoice =>
      (status == IdentificationStatus.confirm || status == IdentificationStatus.choose) &&
      options.isNotEmpty;

  static Identification? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final status = switch (json['status']) {
      'confident' => IdentificationStatus.confident,
      'confirm' => IdentificationStatus.confirm,
      'choose' => IdentificationStatus.choose,
      'retake' => IdentificationStatus.retake,
      'not_found' => IdentificationStatus.notFound,
      'unavailable' => IdentificationStatus.unavailable,
      _ => null,
    };
    if (status == null) return null;
    return Identification(
      status: status,
      readAs: json['read_as'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => ProductOption.fromJson(e as Map<String, dynamic>))
              .whereType<ProductOption>()
              .toList() ??
          const [],
      chosen: ProductOption.fromJson(json['chosen'] as Map<String, dynamic>?),
    );
  }
}

/// Low / medium / high for one nutrient per 100 g (or 100 ml for drinks).
/// Worked out on the server from the label; the same for everyone.
enum NutrientLevelBand { low, medium, high }

class NutrientLevel {
  final String nutrient; // fat, saturated_fat, sugars, salt
  final double per100;
  final String unit;
  final bool perMl;
  final NutrientLevelBand level;

  NutrientLevel({
    required this.nutrient,
    required this.per100,
    required this.unit,
    required this.perMl,
    required this.level,
  });

  static NutrientLevel? fromJson(Map<String, dynamic> json) {
    final level = switch (json['level']) {
      'low' => NutrientLevelBand.low,
      'medium' => NutrientLevelBand.medium,
      'high' => NutrientLevelBand.high,
      _ => null,
    };
    final per100 = (json['per_100'] as num?)?.toDouble();
    if (level == null || per100 == null || json['nutrient'] == null) return null;
    return NutrientLevel(
      nutrient: json['nutrient'] as String,
      per100: per100,
      unit: (json['unit'] as String?) ?? 'g',
      perMl: json['basis'] == '100ml',
      level: level,
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
  final List<NutrientLevel> nutrientLevels;
  final String? imageUrl;
  final bool insufficientData;
  final String? pipelineMessage;
  final Identification? identification;

  /// The label's numbers have no serving size: ask the user to check the pack.
  final bool servingSizeUnknown;

  ScanResult({
    required this.scanId,
    required this.userId,
    required this.scannedAt,
    required this.product,
    required this.scoreResult,
    required this.explanation,
    required this.alternatives,
    this.nutrientLevels = const [],
    this.identification,
    this.servingSizeUnknown = false,
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
      nutrientLevels: (json['nutrient_levels'] as List<dynamic>?)
              ?.map((e) => NutrientLevel.fromJson(e as Map<String, dynamic>))
              .whereType<NutrientLevel>()
              .toList() ??
          const [],
      identification: Identification.fromJson(json['identification'] as Map<String, dynamic>?),
      servingSizeUnknown: json['serving_size_unknown'] == true,
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

/// Totals across all of the user's scans.
class ScanStats {
  final int total;
  final int? average;
  final int? best;

  const ScanStats({required this.total, this.average, this.best});

  factory ScanStats.fromJson(Map<String, dynamic> json) => ScanStats(
        total: (json['total'] as num?)?.toInt() ?? 0,
        average: (json['average'] as num?)?.toInt(),
        best: (json['best'] as num?)?.toInt(),
      );
}

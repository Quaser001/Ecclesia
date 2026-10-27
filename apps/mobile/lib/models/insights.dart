import 'scan_result.dart';

/// Trends from the user's own scans, computed by the backend
/// (`GET /api/v1/insights`). Nothing here is estimated: a week with no scans
/// has no average.
class Insights {
  final int totalScans;
  final int? averageScore;
  final Map<SuitabilityStatus, int> suitabilityCounts;
  final List<WeeklyPoint> weekly;
  final List<FlagCount> topFlags;
  final List<ProductPick> best;
  final List<ProductPick> needsAttention;
  final List<GoalInsight> goals;

  const Insights({
    required this.totalScans,
    required this.averageScore,
    required this.suitabilityCounts,
    required this.weekly,
    required this.topFlags,
    required this.best,
    required this.needsAttention,
    this.goals = const [],
  });

  bool get isEmpty => totalScans == 0;

  factory Insights.fromJson(Map<String, dynamic> json) {
    final counts = <SuitabilityStatus, int>{};
    (json['suitability_counts'] as Map<String, dynamic>? ?? const {})
        .forEach((k, v) => counts[SuitabilityStatus.fromString(k)] = (v as num).toInt());
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return Insights(
      totalScans: (json['total_scans'] as num?)?.toInt() ?? 0,
      averageScore: (json['average_score'] as num?)?.toInt(),
      suitabilityCounts: counts,
      weekly: list('weekly', WeeklyPoint.fromJson),
      topFlags: list('top_flags', FlagCount.fromJson),
      best: list('best', ProductPick.fromJson),
      needsAttention: list('needs_attention', ProductPick.fromJson),
      goals: list('goals', GoalInsight.fromJson),
    );
  }
}

class WeeklyPoint {
  final DateTime weekStart;
  final int scans;
  final int? averageScore;

  const WeeklyPoint({required this.weekStart, required this.scans, this.averageScore});

  factory WeeklyPoint.fromJson(Map<String, dynamic> json) => WeeklyPoint(
        weekStart: DateTime.parse(json['week_start'] as String),
        scans: (json['scans'] as num?)?.toInt() ?? 0,
        averageScore: (json['average_score'] as num?)?.toInt(),
      );
}

class FlagCount {
  final String ruleId;
  final String title;
  final FindingSeverity severity;
  final int count;

  const FlagCount({
    required this.ruleId,
    required this.title,
    required this.severity,
    required this.count,
  });

  factory FlagCount.fromJson(Map<String, dynamic> json) => FlagCount(
        ruleId: json['rule_id'] as String,
        title: json['title'] as String? ?? '',
        severity: FindingSeverity.fromString(json['severity'] as String?),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class ProductPick {
  final String scanId;
  final String? productName;
  final String? brand;
  final int score;
  final SuitabilityStatus suitability;

  const ProductPick({
    required this.scanId,
    this.productName,
    this.brand,
    required this.score,
    required this.suitability,
  });

  factory ProductPick.fromJson(Map<String, dynamic> json) => ProductPick(
        scanId: json['scan_id'] as String,
        productName: json['product_name'] as String?,
        brand: json['brand'] as String?,
        score: (json['score'] as num?)?.toInt() ?? 0,
        suitability: SuitabilityStatus.fromString(json['suitability'] as String?),
      );
}

/// How the user's scans line up with one of their goals.
class GoalInsight {
  final String goal;
  final bool tracked;
  final String basis; // English, from the server
  final int checked;
  final int fits;
  final String? mainIssue; // English finding title, from the server

  const GoalInsight({
    required this.goal,
    required this.tracked,
    required this.basis,
    required this.checked,
    required this.fits,
    this.mainIssue,
  });

  factory GoalInsight.fromJson(Map<String, dynamic> json) => GoalInsight(
        goal: json['goal'] as String,
        tracked: json['tracked'] == true,
        basis: json['basis'] as String? ?? '',
        checked: (json['checked'] as num?)?.toInt() ?? 0,
        fits: (json['fits'] as num?)?.toInt() ?? 0,
        mainIssue: json['main_issue'] as String?,
      );
}

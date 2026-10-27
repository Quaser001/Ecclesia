import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/scan_row.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/status_view.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../models/insights.dart';
import '../../models/scan_result.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../scan/scan_detail_screen.dart';

/// Insights: trends from the user's own scans, and how they line up with
/// the user's goals.
///
/// Every number comes from `GET /api/v1/insights`, which counts and averages
/// stored scans. Weeks without scans show a gap, not a zero.
class InsightsScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback? onStartScan;

  const InsightsScreen({super.key, required this.apiService, this.onStartScan});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Insights? _insights;
  UserProfile? _profile;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final insights = await widget.apiService.getInsights();
      UserProfile? profile;
      try {
        profile = await widget.apiService.getProfile();
      } catch (_) {
        profile = null; // the target-weight line is optional
      }
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UserMessage.of(context, e);
        _loading = false;
      });
    }
  }

  void _open(String scanId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanDetailScreen(apiService: widget.apiService, scanId: scanId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.insightsTitle)),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    if (_loading) return const _InsightsSkeleton();
    if (_error != null) {
      return StatusView(
        icon: Icons.cloud_off_rounded,
        title: l.insightsErrorTitle,
        message: _error!,
        actionLabel: l.tryAgain,
        onAction: _load,
        isError: true,
      );
    }
    final data = _insights!;
    if (data.isEmpty) {
      return StatusView(
        icon: Icons.insights_rounded,
        title: l.insightsEmptyTitle,
        message: l.insightsEmptyBody,
        actionLabel: widget.onStartScan == null ? null : l.scanAProduct,
        onAction: widget.onStartScan,
      );
    }

    final theme = Theme.of(context);
    String subtitle(ProductPick p) =>
        '${p.brand ?? l.unknownBrand} · ${l.suitabilityLabel(p.suitability)}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          _SummaryCard(data: data),
          const SizedBox(height: 14),
          _WeeklyCard(weeks: data.weekly),
          const SizedBox(height: 28),
          Text(l.yourGoals, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(l.yourGoalsBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          _GoalsSection(goals: data.goals, profile: _profile),
          if (data.topFlags.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(l.flaggedMost, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(l.flaggedMostBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            _FlagList(flags: data.topFlags, totalScans: data.totalScans),
          ],
          if (data.best.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(l.bestPicks, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            for (final p in data.best) ...[
              ScanRow(
                score: p.score,
                productName: p.productName,
                subtitle: subtitle(p),
                onTap: () => _open(p.scanId),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (data.needsAttention.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(l.secondLook, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(l.secondLookBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final p in data.needsAttention) ...[
              ScanRow(
                score: p.score,
                productName: p.productName,
                subtitle: subtitle(p),
                onTap: () => _open(p.scanId),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 8),
          Text(l.basedOnScans(data.totalScans),
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Insights data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;
    final avg = data.averageScore ?? 0;
    const order = [
      SuitabilityStatus.excellent,
      SuitabilityStatus.good,
      SuitabilityStatus.fair,
      SuitabilityStatus.poor,
      SuitabilityStatus.notSuitable,
    ];
    Color tone(SuitabilityStatus s) => switch (s) {
          SuitabilityStatus.excellent => c.excellent,
          SuitabilityStatus.good => c.good,
          SuitabilityStatus.fair => c.fair,
          SuitabilityStatus.poor => c.poor,
          _ => c.notSuitable,
        };
    final present = order.where((s) => (data.suitabilityCounts[s] ?? 0) > 0).toList();

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$avg',
                  style: AppTheme.display(44, weight: FontWeight.w700, color: c.score(avg), height: 1)),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l.averageScore, style: theme.textTheme.bodyMedium),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l.scanCount(data.totalScans), style: theme.textTheme.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final s in present)
                    Expanded(flex: data.suitabilityCounts[s]!, child: Container(color: tone(s))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final s in present)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: tone(s), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('${l.suitabilityLabel(s)} ${data.suitabilityCounts[s]}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final List<WeeklyPoint> weeks;
  const _WeeklyCard({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;
    const chartHeight = 120.0;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.weekByWeek, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(l.weekByWeekBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          SizedBox(
            height: chartHeight + 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final w in weeks)
                  Expanded(
                    child: Semantics(
                      label: w.averageScore == null
                          ? l.weekNoScans(l.shortDate(w.weekStart))
                          : l.weekSummary(l.shortDate(w.weekStart), w.averageScore!, w.scans),
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(w.averageScore?.toString() ?? '',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: w.averageScore == null ? null : c.score(w.averageScore!))),
                          const SizedBox(height: 4),
                          Container(
                            width: 18,
                            height: w.averageScore == null
                                ? 4
                                : (chartHeight * (w.averageScore!.clamp(4, 100) / 100)),
                            decoration: BoxDecoration(
                              color: w.averageScore == null ? c.divider : c.score(w.averageScore!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.shortDate(w.weekStart).replaceFirst(' ', '\n'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One card per goal on the profile. Nothing is shown for goals the backend
/// can't check except an honest "not tracked yet".
class _GoalsSection extends StatelessWidget {
  final List<GoalInsight> goals;
  final UserProfile? profile;
  const _GoalsSection({required this.goals, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;

    final p = profile;
    final weightLine = (p?.weightKg != null && p?.targetWeightKg != null)
        ? _weightLine(l, p!.weightKg!, p.targetWeightKg!)
        : null;

    if (goals.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: c.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(l.addGoalsPrompt, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final g in goals) ...[
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, size: 20, color: c.brand),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.goalLabel(g.goal), style: theme.textTheme.titleMedium)),
                    if (g.tracked && g.checked > 0)
                      Text(l.countOfTotal(g.fits, g.checked),
                          style: AppTheme.ui(14, weight: FontWeight.w700,
                              color: c.score((g.fits * 100 / g.checked).round()))),
                  ],
                ),
                const SizedBox(height: 10),
                if (!g.tracked)
                  Text(l.goalNotTracked, style: theme.textTheme.bodySmall)
                else if (g.checked == 0)
                  Text(l.goalNoData, style: theme.textTheme.bodySmall)
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: g.fits / g.checked,
                      minHeight: 8,
                      color: c.score((g.fits * 100 / g.checked).round()),
                      backgroundColor: c.elevated,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.goalFits(g.fits, g.checked), style: theme.textTheme.bodyMedium),
                  if (g.mainIssue != null) ...[
                    const SizedBox(height: 2),
                    Text(l.goalMainIssue(g.mainIssue!), style: theme.textTheme.bodySmall),
                  ],
                ],
                if (weightLine != null &&
                    (g.goal == 'weight_loss' || g.goal == 'maintain_weight' ||
                        g.goal == 'muscle_gain')) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.monitor_weight_outlined, size: 18, color: c.accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(weightLine, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ],
                if (g.tracked && g.basis.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l.goalChecks(g.basis),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _weightLine(AppLocalizations l, double weight, double target) {
    final diff = weight - target;
    if (diff.abs() < 0.5) return l.atTarget;
    final kg = diff.abs().toStringAsFixed(diff.abs() < 10 ? 1 : 0);
    return diff > 0 ? l.toTargetLose(kg) : l.toTargetGain(kg);
  }
}

class _FlagList extends StatelessWidget {
  final List<FlagCount> flags;
  final int totalScans;
  const _FlagList({required this.flags, required this.totalScans});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (final (i, f) in flags.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    switch (f.severity) {
                      FindingSeverity.critical => Icons.block_rounded,
                      FindingSeverity.alert => Icons.warning_amber_rounded,
                      _ => Icons.info_outline_rounded,
                    },
                    size: 20,
                    color: switch (f.severity) {
                      FindingSeverity.critical => c.critical,
                      FindingSeverity.alert => c.accent,
                      _ => c.warning,
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(f.title, style: theme.textTheme.titleMedium)),
                  const SizedBox(width: 8),
                  Text(context.l10n.countOfTotal(f.count, totalScans),
                      style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: const [
        SurfaceCard(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 120, height: 40),
              SizedBox(height: 16),
              Skeleton(width: double.infinity, height: 10, borderRadius: 999),
            ],
          ),
        ),
        SizedBox(height: 14),
        SurfaceCard(
          padding: EdgeInsets.all(18),
          child: Skeleton(width: double.infinity, height: 150),
        ),
      ],
    );
  }
}

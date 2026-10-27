import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../app/theme_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/relative_time.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/scan_result.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';

/// Home screen.
///
/// The job is to answer two questions a returning user has:
///   1. What did I scan last?
///   2. What's on my plate for today (profile at a glance)?
///
/// We removed the generic "notifications" icon that led nowhere, dropped the
/// 🌿 emoji and the "Better food choices. A healthier you." tagline, and
/// stopped labelling the latest scan's score as "Your Health Score" — the
/// previous copy implied a running health rating the app doesn't actually
/// compute.
class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;
  final VoidCallback? onNavigateToHistory;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.userId,
    this.onNavigateToHistory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  UserProfile? _profile;
  List<ScanHistoryItem> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.apiService.getProfile(),
        widget.apiService.getScanHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _history = results[1] as List<ScanHistoryItem>;
        _history.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UserMessage.fromError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _error != null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.verdict,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 28),
                    _buildGreeting(context),
                    const SizedBox(height: 32),
                    _buildLatestScanCard(context),
                    if (!_isLoading && _history.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _StatsRow(history: _history),
                    ],
                    const SizedBox(height: 28),
                    _ProfileAtAGlance(profile: _profile, loading: _isLoading),
                    const SizedBox(height: 28),
                    _buildRecentScansHeader(context),
                    const SizedBox(height: 12),
                    _buildRecentScans(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 16),
            Text("We can't reach your dashboard",
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(_error ?? '',
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loadData,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdict,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try again'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6CF0B4), Color(0xFF1FB57A)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.verdict.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'C',
                style: AppTheme.display(18,
                    weight: FontWeight.w600, color: AppColors.bg),
              ),
            ),
            const SizedBox(width: 10),
            Text('CalFit',
                style: AppTheme.ui(16,
                    weight: FontWeight.w700,
                    color: theme.textTheme.titleLarge?.color)),
          ],
        ),
        IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            ThemeController.toggleTheme();
          },
          icon: ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) => Icon(
              mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: theme.textTheme.titleLarge?.color,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still up';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  Widget _buildGreeting(BuildContext context) {
    final name = _profile?.name;
    final displayName = (name == null || name.isEmpty) ? null : name;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _timeBasedGreeting(),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          displayName ?? 'Welcome back',
          style: theme.textTheme.displayMedium,
        ),
      ],
    );
  }

  Widget _buildLatestScanCard(BuildContext context) {
    if (_isLoading) {
      return SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Skeleton(width: 72, height: 72, borderRadius: 36),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 90, height: 12),
                  SizedBox(height: 10),
                  Skeleton(width: 180, height: 20),
                  SizedBox(height: 8),
                  Skeleton(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      final theme = Theme.of(context);
      return SurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No scans yet',
                style: AppTheme.display(22,
                    weight: FontWeight.w500,
                    color: theme.textTheme.displayMedium?.color)),
            const SizedBox(height: 6),
            Text(
              'Tap the scan button at the bottom. '
              'Point the camera at any food label and we\'ll tell you if it fits your profile.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final latest = _history.first;
    final color = AppColors.scoreColor(latest.score);
    final theme = Theme.of(context);

    return SurfaceCard(
      accent: color,
      padding: const EdgeInsets.all(20),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onNavigateToHistory?.call();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MiniScoreDot(score: latest.score),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latest scan · ${formatRelativeTime(latest.scannedAt)}',
                    style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(
                  latest.productName ?? 'Unnamed product',
                  style: AppTheme.display(22,
                      weight: FontWeight.w500,
                      color: theme.textTheme.displayMedium?.color,
                      height: 1.1),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  latest.suitability.displayName,
                  style: AppTheme.ui(13,
                      weight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScansHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Recent scans', style: theme.textTheme.headlineMedium),
        if (_history.length > 3)
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onNavigateToHistory?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('See all'),
          ),
      ],
    );
  }

  Widget _buildRecentScans(BuildContext context) {
    if (_isLoading) {
      return Column(
        children: List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Skeleton(width: 44, height: 44, borderRadius: 10),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 160, height: 14),
                        SizedBox(height: 8),
                        Skeleton(width: 90, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final items = _history.take(3).toList();

    return Column(
      children: [
        for (final item in items) ...[
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onNavigateToHistory?.call();
            },
            child: Row(
              children: [
                _ScoreBadge(score: item.score),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'Unnamed product',
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.brand ?? "Unknown brand"} · ${formatRelativeTime(item.scannedAt)}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.north_east_rounded,
                    size: 16, color: theme.textTheme.bodyMedium?.color),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ]
      ],
    );
  }
}

/// Three numbers derived from the user's own scan history — no invented
/// metrics: how many scans, their average score, and the best one.
class _StatsRow extends StatelessWidget {
  final List<ScanHistoryItem> history;
  const _StatsRow({required this.history});

  @override
  Widget build(BuildContext context) {
    final scores = history.map((h) => h.score).toList();
    final avg = (scores.reduce((a, b) => a + b) / scores.length).round();
    final best = scores.reduce((a, b) => a > b ? a : b);
    return Row(
      children: [
        Expanded(child: _Stat(label: 'Scans', value: '${history.length}', color: AppColors.verdict)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'Avg score', value: '$avg', color: AppColors.scoreColor(avg))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'Best', value: '$best', color: AppColors.scoreColor(best))),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.display(26, weight: FontWeight.w600, color: color)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Compact "coloured dot with number inside" badge used in the recent scans list.
class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: AppTheme.display(16, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Bigger coloured disc for the "latest scan" hero.
class _MiniScoreDot extends StatelessWidget {
  final int score;
  const _MiniScoreDot({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(score);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: AppTheme.display(26, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// A quiet row of chips summarising the user's profile ("Hypertension",
/// "Vegetarian", "Peanut allergy") — the thing that makes CalFit personal.
class _ProfileAtAGlance extends StatelessWidget {
  final UserProfile? profile;
  final bool loading;

  const _ProfileAtAGlance({required this.profile, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <_Chip>[];

    if (profile != null) {
      for (final c in profile!.healthConditions.take(2)) {
        chips.add(_Chip(label: _humanize(c), kind: _ChipKind.condition));
      }
      for (final g in profile!.healthGoals.take(2)) {
        chips.add(_Chip(label: _humanize(g), kind: _ChipKind.goal));
      }
      for (final a in profile!.allergies.take(2)) {
        chips.add(_Chip(label: '$a allergy', kind: _ChipKind.allergy));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your profile', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        if (loading)
          Row(
            children: const [
              Skeleton(width: 90, height: 28, borderRadius: 999),
              SizedBox(width: 8),
              Skeleton(width: 120, height: 28, borderRadius: 999),
            ],
          )
        else if (chips.isEmpty)
          Text(
            'Add conditions, goals, or allergies in Profile so scans know what fits you.',
            style: theme.textTheme.bodyMedium,
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  String _humanize(String raw) {
    return raw
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }
}

enum _ChipKind { condition, goal, allergy }

class _Chip extends StatelessWidget {
  final String label;
  final _ChipKind kind;

  const _Chip({required this.label, required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (kind) {
      _ChipKind.condition => AppColors.ember,
      _ChipKind.goal => theme.colorScheme.primary,
      _ChipKind.allergy => AppColors.critical,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTheme.ui(12,
              weight: FontWeight.w600, color: accent)),
    );
  }
}

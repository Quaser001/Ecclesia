import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../app/theme_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/profile_chips.dart';
import '../../core/widgets/profile_switcher.dart';
import '../../core/widgets/scan_row.dart';
import '../../core/widgets/score_badge.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/status_view.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../models/scan_result.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/profile_registry.dart';
import '../scan/scan_detail_screen.dart';
import '../../core/utils/score_format.dart';

/// Home: what did I scan last, how am I doing, and what's my profile.
///
/// Numbers here are counts and averages of the user's own scans; the app
/// does not compute a running "health score" and never implies one.
class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onStartScan;

  /// Bumped by the tab bar to refresh quietly when the tab is shown again.
  final int refreshTick;

  const HomeScreen({
    super.key,
    this.refreshTick = 0,
    required this.apiService,
    required this.userId,
    this.onNavigateToHistory,
    this.onNavigateToProfile,
    this.onStartScan,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  UserProfile? _profile;
  List<ScanHistoryItem> _history = [];
  ScanStats? _stats;
  String? _error;

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _loadData(silent: true);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// [silent]: refresh in the background, keeping what's on screen.
  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.apiService.getProfile(),
        widget.apiService.getScanHistory(limit: 4),
        widget.apiService.getScanStats(),
      ]);
      if (!mounted) return;
      final profile = await _syncName(results[0] as UserProfile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _history = results[1] as List<ScanHistoryItem>;
        _stats = results[2] as ScanStats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _profile != null) return; // keep what's on screen
      setState(() {
        _error = UserMessage.of(context, e);
        _isLoading = false;
      });
    }
  }

  /// A new family member's name was typed in the switcher: save it to their
  /// server profile once. Later edits on the Profile tab rename the switcher.
  Future<UserProfile> _syncName(UserProfile profile) async {
    final registry = ProfileRegistry.current;
    if (registry == null) return profile;
    final label = registry.active.label;
    final name = profile.name?.trim() ?? '';
    if (name.isEmpty && label.isNotEmpty) {
      try {
        return await widget.apiService.updateProfile(profile.copyWith(name: label));
      } catch (_) {
        return profile; // shown from the label; saved on the next visit
      }
    }
    if (name.isNotEmpty && name != label) await registry.rename(registry.activeId, name);
    return profile;
  }

  void _open(ScanHistoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanDetailScreen(apiService: widget.apiService, scanId: item.scanId),
      ),
    );
  }

  bool get _profileEmpty {
    final p = _profile;
    return p != null &&
        p.healthConditions.isEmpty &&
        p.healthGoals.isEmpty &&
        p.allergies.isEmpty &&
        p.dietaryPreferences.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: _error != null
                  ? StatusView(
                      icon: Icons.cloud_off_rounded,
                      title: context.l10n.homeErrorTitle,
                      message: _error!,
                      actionLabel: context.l10n.tryAgain,
                      onAction: _loadData,
                      isError: true,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        children: _content(context),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final theme = Theme.of(context);
    return [
      _Greeting(name: _profile?.name),
      const SizedBox(height: 20),
      if (_isLoading)
        const _LatestSkeleton()
      else if (_history.isEmpty)
        _FirstScanCard(onStartScan: widget.onStartScan)
      else ...[
        _LatestScanCard(item: _history.first, onTap: () => _open(_history.first)),
        const SizedBox(height: 12),
        if (_stats != null) _StatsRow(stats: _stats!),
      ],
      if (!_isLoading && _profileEmpty) ...[
        const SizedBox(height: 12),
        _SetUpProfileCard(onTap: widget.onNavigateToProfile),
      ],
      const SizedBox(height: 28),
      _ProfileAtAGlance(
        profile: _profile,
        loading: _isLoading,
        onEdit: widget.onNavigateToProfile,
      ),
      if (!_isLoading && _history.length > 1) ...[
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: Text(context.l10n.recentScans, style: theme.textTheme.headlineMedium)),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                widget.onNavigateToHistory?.call();
              },
              child: Text(context.l10n.seeAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in _history.skip(1).take(3)) ...[
          ScanRow(
            score: item.score,
            productName: item.productName,
            subtitle: '${item.brand ?? context.l10n.unknownBrand} · '
                '${context.l10n.relativeTime(item.scannedAt)}',
            imageUrl: item.imageUrl,
            onTap: () => _open(item),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          const BrandLockup(),
          const Spacer(),
          if (ProfileRegistry.current != null) const ProfileSwitcherButton(),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) => IconButton(
              tooltip: mode == ThemeMode.dark
                  ? context.l10n.switchToLight
                  : context.l10n.switchToDark,
              onPressed: () {
                HapticFeedback.selectionClick();
                ThemeController.toggleTheme();
              },
              icon: Icon(mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String? name;
  const _Greeting({required this.name});

  String _timeBasedGreeting(AppLocalizations l) {
    final hour = DateTime.now().hour;
    if (hour < 5) return l.greetingStillUp;
    if (hour < 12) return l.greetingMorning;
    if (hour < 17) return l.greetingAfternoon;
    if (hour < 21) return l.greetingEvening;
    return l.greetingNight;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasName = name != null && name!.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasName ? '${_timeBasedGreeting(context.l10n)},' : _timeBasedGreeting(context.l10n),
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(hasName ? name!.trim() : context.l10n.homeTitleNoName,
            style: theme.textTheme.displayMedium),
      ],
    );
  }
}

class _LatestScanCard extends StatelessWidget {
  final ScanHistoryItem item;
  final VoidCallback onTap;
  const _LatestScanCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.colors.score(item.score);
    return SurfaceCard(
      accent: color,
      padding: const EdgeInsets.all(18),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          ScoreBadge(score: item.score, size: 68),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.latestScan(context.l10n.relativeTime(item.scannedAt)),
                    style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  item.productName ?? context.l10n.unnamedProduct,
                  style: AppTheme.display(21, color: theme.colorScheme.onSurface, height: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(context.l10n.suitabilityLabel(item.suitability),
                    style: AppTheme.ui(14, weight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _FirstScanCard extends StatelessWidget {
  final VoidCallback? onStartScan;
  const _FirstScanCard({required this.onStartScan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return SurfaceCard(
      background: c.brandSoft,
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.qr_code_scanner_rounded, color: c.brand, size: 30),
          const SizedBox(height: 12),
          Text(context.l10n.firstScanTitle, style: theme.textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(
            context.l10n.firstScanBody,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
          ),
          if (onStartScan != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStartScan,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(context.l10n.scanAProduct),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetUpProfileCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _SetUpProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return SurfaceCard(
      accent: c.accent,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.tune_rounded, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.personaliseTitle, style: theme.textTheme.titleMedium),
                Text(context.l10n.personaliseBody, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _LatestSkeleton extends StatelessWidget {
  const _LatestSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      padding: EdgeInsets.all(18),
      child: Row(
        children: [
          Skeleton(width: 68, height: 68, borderRadius: 20),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 110, height: 12),
                SizedBox(height: 10),
                Skeleton(width: 180, height: 20),
                SizedBox(height: 8),
                Skeleton(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three numbers across all of the user's scans (from the server, not just
/// the page loaded here): how many, their average score, and the best.
class _StatsRow extends StatelessWidget {
  final ScanStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final avg = stats.average ?? 0;
    final best = stats.best ?? 0;
    return Row(
      children: [
        Expanded(child: _Stat(label: context.l10n.statScans, value: '${stats.total}', color: c.brand)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: context.l10n.statAverage, value: formatScore(avg), color: c.score(avg))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: context.l10n.statBest, value: formatScore(best), color: c.score(best))),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.display(26, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// The profile in a few chips — the thing that makes CalFit personal.
class _ProfileAtAGlance extends StatelessWidget {
  final UserProfile? profile;
  final bool loading;
  final VoidCallback? onEdit;

  const _ProfileAtAGlance({required this.profile, required this.loading, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final p = profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l.scoringForYou, style: theme.textTheme.headlineMedium)),
            if (onEdit != null && !loading)
              TextButton(onPressed: onEdit, child: Text(l.edit)),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          const Row(
            children: [
              Skeleton(width: 96, height: 32, borderRadius: 999),
              SizedBox(width: 8),
              Skeleton(width: 120, height: 32, borderRadius: 999),
            ],
          )
        else if (p == null || ProfileChips.isEmpty(p))
          Text(l.scoringEmpty, style: theme.textTheme.bodyMedium)
        else
          ProfileChips(profile: p),
      ],
    );
  }
}

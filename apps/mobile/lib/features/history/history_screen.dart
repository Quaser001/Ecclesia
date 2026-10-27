import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/relative_time.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/scan_result.dart';
import '../../services/api_service.dart';

/// History screen.
///
/// Grouped by day. Each row is tappable (and gives haptic feedback), ready
/// to open a full past scan once the backend has a GET /scans/:id endpoint.
class HistoryScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const HistoryScreen({
    super.key,
    required this.apiService,
    required this.userId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<ScanHistoryItem> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final history = await widget.apiService.getScanHistory();
      if (!mounted) return;
      setState(() {
        _history = history
          ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('History')),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError(theme)
              : _history.isEmpty
                  ? _buildEmpty(theme)
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: AppColors.verdict,
                      child: _buildList(),
                    ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Skeleton(width: 44, height: 44, borderRadius: 12),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 180, height: 14),
                  SizedBox(height: 8),
                  Skeleton(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final groups = _groupByDay(_history);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 0, 10),
            child: Text(
              entry.key,
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.6),
            ),
          ),
          for (final item in entry.value) ...[
            SurfaceCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              onTap: () {
                HapticFeedback.selectionClick();
                // When GET /scans/:id ships, push ScanResultScreen here.
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Scan detail is coming in the next release.'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
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
                          style:
                              theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.textTheme.bodyMedium?.color),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ]
      ],
    );
  }

  /// Groups "Today", "Yesterday", or "DD MMM YYYY".
  Map<String, List<ScanHistoryItem>> _groupByDay(List<ScanHistoryItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final map = <String, List<ScanHistoryItem>>{};
    for (final item in items) {
      final d = item.scannedAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      final key = day == today
          ? 'Today'
          : day == yesterday
              ? 'Yesterday'
              : '${d.day} ${months[d.month - 1]} ${d.year}';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 56, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 18),
            Text('Nothing here yet', style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Scan a product and it will show up here with the score and date.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 44, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 14),
            Text("We can't load your history",
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(_error!,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loadHistory,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdict,
                foregroundColor: AppColors.bg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }
}

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

import 'package:flutter/material.dart';

import '../../core/utils/user_message.dart';
import '../../core/widgets/scan_row.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/status_view.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../models/scan_result.dart';
import '../../services/api_service.dart';
import '../scan/scan_detail_screen.dart';

/// History: past scans grouped by day. Tap one to open its full result.
class HistoryScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;
  final VoidCallback? onStartScan;

  /// Bumped by the tab bar to refresh quietly when the tab is shown again.
  final int refreshTick;

  const HistoryScreen({
    super.key,
    this.refreshTick = 0,
    required this.apiService,
    required this.userId,
    this.onStartScan,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _pageSize = 20;

  bool _isLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  List<ScanHistoryItem> _history = [];
  String? _error;

  @override
  void didUpdateWidget(covariant HistoryScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _loadHistory(silent: true);
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// [silent]: refresh in the background, keeping what's on screen.
  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final history = await widget.apiService.getScanHistory(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _history = history;
        _hasMore = history.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _history.isNotEmpty) return; // keep what's on screen
      setState(() {
        _error = UserMessage.of(context, e);
        _isLoading = false;
      });
    }
  }

  /// Next page, older than the oldest scan shown. A failure only shows a
  /// message; what's already on screen stays.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _history.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.apiService.getScanHistory(
        limit: _pageSize,
        before: _history.last.scannedAt,
      );
      if (!mounted) return;
      setState(() {
        _history = [..._history, ...page];
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserMessage.of(context, e))));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _open(ScanHistoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanDetailScreen(
          apiService: widget.apiService,
          scanId: item.scanId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.historyTitle)),
      body: _isLoading
          ? _buildLoading()
          : _error != null
          ? StatusView(
              icon: Icons.cloud_off_rounded,
              title: context.l10n.historyErrorTitle,
              message: _error!,
              actionLabel: context.l10n.tryAgain,
              onAction: _loadHistory,
              isError: true,
            )
          : _history.isEmpty
          ? StatusView(
              icon: Icons.receipt_long_outlined,
              title: context.l10n.historyEmptyTitle,
              message: context.l10n.historyEmptyBody,
              actionLabel: widget.onStartScan == null
                  ? null
                  : context.l10n.scanAProduct,
              onAction: widget.onStartScan,
            )
          : RefreshIndicator(onRefresh: _loadHistory, child: _buildList()),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => const SurfaceCard(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Skeleton(width: 48, height: 48, borderRadius: 14),
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
    final theme = Theme.of(context);
    final groups = _groupByDay(_history, context.l10n);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _loadMore();
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 0, 10),
              child: Text(
                entry.key.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8),
              ),
            ),
            for (final item in entry.value) ...[
              ScanRow(
                score: item.score,
                productName: item.productName,
                subtitle:
                    '${item.brand ?? context.l10n.unknownBrand} · '
                    '${context.l10n.suitabilityLabel(item.suitability)} · '
                    '${context.l10n.relativeTime(item.scannedAt)}',
                imageUrl: item.imageUrl,
                onTap: () => _open(item),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  /// Groups "Today", "Yesterday", or a short date with the year.
  Map<String, List<ScanHistoryItem>> _groupByDay(
    List<ScanHistoryItem> items,
    AppLocalizations l,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final map = <String, List<ScanHistoryItem>>{};
    for (final item in items) {
      final d = item.scannedAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      final key = day == today
          ? l.today
          : day == yesterday
          ? l.yesterday
          : '${l.shortDate(d)} ${d.year}';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}

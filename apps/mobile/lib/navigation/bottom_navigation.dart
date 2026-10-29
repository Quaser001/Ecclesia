import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/medical_disclaimer.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/scan/scan_screen.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';

/// App shell: four tabs with the Scan button in the middle.
///
///   Home · History · [ Scan ] · Insights · Profile
///
/// The bar is five equal slots, the middle one left empty for the docked
/// Scan button, so two tabs sit on each side and the spacing is even by
/// construction (the old bar had one tab on the left and two on the right).
class BottomNavigation extends StatefulWidget {
  final ApiService apiService;

  const BottomNavigation({
    super.key,
    required this.apiService,
  });

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String Function(AppLocalizations) label;
  const _Tab(this.icon, this.activeIcon, this.label);
}

final _tabs = [
  _Tab(Icons.home_outlined, Icons.home_rounded, (l) => l.navHome),
  _Tab(Icons.history_rounded, Icons.history_rounded, (l) => l.navHistory),
  _Tab(Icons.insights_outlined, Icons.insights_rounded, (l) => l.navInsights),
  _Tab(Icons.person_outline_rounded, Icons.person_rounded, (l) => l.navProfile),
];

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;

  /// Per-tab counters: bumping one makes that tab refresh in the background,
  /// so switching tabs is instant and never flashes a loading state.
  final _refresh = [0, 0, 0, 0];

  /// Tabs are built the first time they're opened, then kept alive.
  final _opened = <int>{0};

  @override
  void initState() {
    super.initState();
    // Show the "not medical advice" dialog once, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MedicalDisclaimer.showOnFirstLaunch(context);
    });
  }

  void _select(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (!_opened.add(index)) _refresh[index]++; // already built: refresh quietly
      _currentIndex = index;
    });
  }

  Future<void> _startScan() async {
    HapticFeedback.mediumImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanScreen(apiService: widget.apiService),
      ),
    );
    // A new scan changes Home, History and Insights.
    if (mounted) {
      setState(() {
        for (final i in [0, 1, 2]) {
          _refresh[i]++;
        }
      });
    }
  }

  Widget _screen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          apiService: widget.apiService,
          refreshTick: _refresh[0],
          onNavigateToHistory: () => _select(1),
          onNavigateToProfile: () => _select(3),
          onStartScan: _startScan,
        );
      case 1:
        return HistoryScreen(
          apiService: widget.apiService,
          refreshTick: _refresh[1],
          onStartScan: _startScan,
        );
      case 2:
        return InsightsScreen(
            apiService: widget.apiService, onStartScan: _startScan, refreshTick: _refresh[2]);
      default:
        return ProfileScreen(
            apiService: widget.apiService, refreshTick: _refresh[3]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          for (final i in _opened)
            // Kept alive off-screen; only the current tab is visible,
            // interactive and announced to screen readers.
            AnimatedOpacity(
              key: ValueKey(i),
              opacity: i == _currentIndex ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: i != _currentIndex,
                child: ExcludeSemantics(
                  excluding: i != _currentIndex,
                  child: TickerMode(enabled: i == _currentIndex, child: _screen(i)),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox.square(
        dimension: 64,
        child: FloatingActionButton(
          onPressed: _startScan,
          tooltip: context.l10n.scanAProduct,
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          elevation: 2,
          highlightElevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.qr_code_scanner_rounded, size: 28),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.divider)),
          ),
          child: Row(
            children: [
              _slot(0),
              _slot(1),
              const Expanded(child: SizedBox()), // Scan button sits here
              _slot(2),
              _slot(3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(int index) => Expanded(
        child: _NavTab(
          tab: _tabs[index],
          active: _currentIndex == index,
          onTap: () => _select(index),
        ),
      );
}

class _NavTab extends StatelessWidget {
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.brand : c.muted;
    final label = tab.label(context.l10n);
    return Semantics(
      selected: active,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: active ? c.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(active ? tab.activeIcon : tab.icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.ui(12,
                  weight: active ? FontWeight.w700 : FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

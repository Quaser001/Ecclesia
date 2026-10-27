import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/app_backdrop.dart';
import '../core/widgets/medical_disclaimer.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/scan/scan_screen.dart';
import '../services/api_service.dart';

/// A deliberately quiet bottom bar. The scan button is the loud element —
/// everything else keeps still so the eye finds the primary action.
class BottomNavigation extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const BottomNavigation({
    super.key,
    required this.apiService,
    required this.userId,
  });

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // On first launch, show the "not medical advice" dialog once. We wait for
    // the first frame so there is always a BuildContext ready to host the
    // dialog on top of.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MedicalDisclaimer.showOnFirstLaunch(context);
    });
    _screens = [
      HomeScreen(
        apiService: widget.apiService,
        userId: widget.userId,
        onNavigateToHistory: () {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = 1);
        },
      ),
      HistoryScreen(apiService: widget.apiService, userId: widget.userId),
      ProfileScreen(apiService: widget.apiService, userId: widget.userId),
    ];
  }

  void _onTapIndex(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _screens[_currentIndex],
            ),
          ),
        ],
      ),
      floatingActionButton: _ScanFab(onPressed: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanScreen(
              apiService: widget.apiService,
              userId: widget.userId,
            ),
          ),
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavTab(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Home',
                active: _currentIndex == 0,
                onTap: () => _onTapIndex(0),
              ),
              const SizedBox(width: 56),
              _NavTab(
                icon: Icons.history_rounded,
                activeIcon: Icons.history_rounded,
                label: 'History',
                active: _currentIndex == 1,
                onTap: () => _onTapIndex(1),
              ),
              _NavTab(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                active: _currentIndex == 2,
                onTap: () => _onTapIndex(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _ScanFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6CF0B4), AppColors.verdict, Color(0xFF1FB57A)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.verdict.withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        shape: const CircleBorder(),
        tooltip: 'Scan a product',
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        child: const Icon(Icons.photo_camera_rounded, color: AppColors.bg, size: 27),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.textTheme.bodyMedium?.color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(active ? activeIcon : icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.ui(10,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }
}

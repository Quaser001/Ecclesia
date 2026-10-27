import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// A subtle shimmer skeleton for loading states that don't need a spinner.
/// We use skeletons on the home dashboard and history, and a stepped
/// status line on the scan screen (see `ScanProgressIndicator`).
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final base = theme.colorScheme.surfaceContainerHighest;
        final highlight = Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.08),
          base,
        );
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, t),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// A stepped status line for the scan screen. The server doesn't actually
/// stream progress, but a scan always takes ~3-6s — showing which stage
/// we're on makes the wait feel intentional instead of empty.
class ScanProgressIndicator extends StatefulWidget {
  const ScanProgressIndicator({super.key});

  @override
  State<ScanProgressIndicator> createState() => _ScanProgressIndicatorState();
}

class _ScanProgressIndicatorState extends State<ScanProgressIndicator> {
  static const _stepCount = 4;

  static String _step(AppLocalizations l, int i) => switch (i) {
        0 => l.stepReadingLabel,
        1 => l.stepCheckingProfile,
        2 => l.stepWeighing,
        _ => l.stepAlternatives,
      };

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    for (var i = 1; i < _stepCount; i++) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        '${_step(context.l10n, _index)}…',
        key: ValueKey(_index),
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}

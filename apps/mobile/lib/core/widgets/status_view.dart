import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Centred empty or error state: an icon in a soft circle, a title, a
/// friendly line of explanation and, optionally, one clear action.
///
/// Errors always use this with a retry, so a failed load never looks like
/// "you have no data".
class StatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final tone = isError ? c.critical : c.brand;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.tint(tone, theme.brightness),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: tone),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center, style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

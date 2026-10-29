import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../services/profile_registry.dart';
import '../constants/app_colors.dart';

/// The active person's initial, top right on Home. Tapping it lists everyone
/// on this phone and lets you switch or add a family member.
class ProfileSwitcherButton extends StatelessWidget {
  const ProfileSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = ProfileRegistry.current!;
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final label = registry.active.label;
        return IconButton(
          tooltip: context.l10n.switchProfile,
          onPressed: () {
            HapticFeedback.selectionClick();
            showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => _SwitcherSheet(registry: registry),
            );
          },
          icon: _Avatar(label: label.isEmpty ? context.l10n.profileMe : label, size: 32),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  final double size;
  const _Avatar({required this.label, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final initial = label.trim().isEmpty ? '?' : label.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.tint(c.brand, theme.brightness), shape: BoxShape.circle),
      child: Text(initial, style: AppTheme.ui(size * 0.45, weight: FontWeight.w700, color: c.brand)),
    );
  }
}

class _SwitcherSheet extends StatelessWidget {
  final ProfileRegistry registry;
  const _SwitcherSheet({required this.registry});

  Future<void> _add(BuildContext context) async {
    final name = await showDialog<String>(context: context, builder: (_) => const _AddMemberDialog());
    if (name == null || name.trim().isEmpty) return;
    if (context.mounted) Navigator.of(context).pop();
    await registry.add(name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(l.profilesTitle, style: theme.textTheme.titleLarge),
            ),
            for (final p in registry.profiles)
              ListTile(
                leading: _Avatar(label: p.label.isEmpty ? l.profileMe : p.label, size: 40),
                title: Text(p.label.isEmpty ? l.profileMe : p.label),
                trailing: p.id == registry.activeId
                    ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                    : null,
                selected: p.id == registry.activeId,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                  await registry.switchTo(p.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: Text(l.addFamilyMember),
              onTap: () => _add(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.addFamilyMember),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 80, // the server's limit for a profile name
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.memberNameLabel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text(l.familyAdultsNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_name.text.trim()),
          child: Text(l.add),
        ),
      ],
    );
  }
}

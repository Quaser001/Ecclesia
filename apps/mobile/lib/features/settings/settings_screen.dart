import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../app/app_theme.dart';
import '../../app/theme_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../services/api_service.dart';
import '../profile/prescription_consent.dart';
import 'privacy_policy_screen.dart';

/// Settings: appearance (theme, text size), language, privacy and data,
/// and about. Reached from the gear icon on the Profile screen.
class SettingsScreen extends StatefulWidget {
  final ApiService apiService;
  const SettingsScreen({super.key, required this.apiService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final l = context.l10n;
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: c.critical, size: 32),
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.critical,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.deleteConfirmButton),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.apiService.deleteMyData();
      await PrescriptionConsent.forget();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.dataDeleted)));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(UserMessage.of(context, e))));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _Header(l.appearance),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.theme, style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.themeMode,
                  builder: (context, mode, _) => SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(Icons.phone_android_rounded),
                            label: Text(l.themeSystem, maxLines: 1)),
                        ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(Icons.light_mode_outlined),
                            label: Text(l.themeLight, maxLines: 1)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode_outlined),
                            label: Text(l.themeDark, maxLines: 1)),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) {
                        HapticFeedback.selectionClick();
                        ThemeController.setThemeMode(s.first);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.textSize, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                ValueListenableBuilder<double>(
                  valueListenable: ThemeController.textScale,
                  builder: (context, scale, _) {
                    final labels = [
                      l.textSizeSmall, l.textSizeDefault, l.textSizeLarge, l.textSizeExtraLarge,
                    ];
                    final index = ThemeController.textScales.indexOf(scale).clamp(0, 3);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('A', style: AppTheme.ui(14, color: c.muted)),
                            Expanded(
                              child: Slider(
                                value: index.toDouble(),
                                min: 0,
                                max: 3,
                                divisions: 3,
                                label: labels[index],
                                onChanged: (v) {
                                  HapticFeedback.selectionClick();
                                  ThemeController.setTextScale(ThemeController.textScales[v.round()]);
                                },
                              ),
                            ),
                            Text('A', style: AppTheme.ui(22, weight: FontWeight.w700, color: c.muted)),
                          ],
                        ),
                        Text(labels[index], style: theme.textTheme.labelMedium),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.elevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(l.textSizePreview, style: theme.textTheme.bodyLarge),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _Header(l.language),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ValueListenableBuilder<Locale?>(
              valueListenable: ThemeController.locale,
              builder: (context, current, _) => Column(
                children: [
                  _LanguageTile(
                    label: l.languagePhone,
                    selected: current == null,
                    onTap: () => ThemeController.setLocale(null),
                  ),
                  for (final (locale, name) in supportedLanguages)
                    _LanguageTile(
                      label: name,
                      selected: current?.languageCode == locale.languageCode,
                      onTap: () => ThemeController.setLocale(locale),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(l.translationNote, style: theme.textTheme.bodySmall),
          ),
          _Header(l.privacyAndData),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.privacyPolicy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: c.divider),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: c.critical),
                  title: Text(l.deleteMyData, style: theme.textTheme.titleMedium?.copyWith(
                      color: c.critical)),
                  subtitle: Text(l.deleteMyDataBody),
                  trailing: _deleting
                      ? const SizedBox.square(
                          dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _deleting ? null : _confirmDelete,
                ),
              ],
            ),
          ),
          _Header(l.about),
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l.appName} · ${l.version(appVersion)}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                Text(l.dataSources, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(l.dataSourcesBody, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 14),
                Text(l.notMedicalAdviceTitle, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(l.disclaimerShort, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
      );
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: c.brand)
          : Icon(Icons.circle_outlined, color: c.divider),
      selected: selected,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}

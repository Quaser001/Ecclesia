import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_theme.dart';
import '../../app/theme_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../../l10n/l10n.dart';
import '../../services/api_service.dart';

/// First-run onboarding: what CalFit does (and the language), a quick
/// profile so the first scan is already personal, and the not-medical-advice
/// note. Finishing saves the picks and marks onboarding done.
class Onboarding {
  static const _doneKey = 'calfit.onboarded.v1';

  /// True for a fresh install. People who already accepted the old
  /// disclaimer dialog have used the app and skip onboarding.
  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_doneKey) == true) return false;
      return !await MedicalDisclaimer.isAcknowledged();
    } catch (_) {
      return false;
    }
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
    await MedicalDisclaimer.markAcknowledged();
  }
}

const _conditionChoices = [
  'diabetes_type_2',
  'prediabetes',
  'hypertension',
  'high_cholesterol',
  'lactose_intolerance',
  'celiac_disease',
];
const _allergyChoices = ['peanut', 'milk', 'gluten', 'soy', 'egg', 'tree_nuts'];
const _dietChoices = ['vegetarian', 'vegan', 'gluten_free', 'dairy_free'];

class OnboardingScreen extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onDone;
  const OnboardingScreen({
    super.key,
    required this.apiService,
    required this.onDone,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _saving = false;
  final _conditions = <String>{};
  final _allergies = <String>{};
  final _diets = <String>{};

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    HapticFeedback.selectionClick();
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    if (_conditions.isNotEmpty || _allergies.isNotEmpty || _diets.isNotEmpty) {
      try {
        final current = await widget.apiService.getProfile();
        await widget.apiService.updateProfile(
          current.copyWith(
            healthConditions: {
              ...current.healthConditions,
              ..._conditions,
            }.toList(),
            allergies: {
              ...current.allergies,
              ..._allergies.map((a) => a.replaceAll('_', ' ')),
            }.toList(),
            dietaryPreferences: {
              ...current.dietaryPreferences,
              ..._diets,
            }.toList(),
          ),
        );
      } catch (_) {
        // Not a blocker: the user can add these in Profile; don't trap them here.
      }
    }
    await Onboarding.markDone();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.colors;
    const total = 3;
    final last = _page == total - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.onbStep(_page + 1, total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (!last)
                    TextButton(
                      onPressed: () => _go(total - 1),
                      child: Text(l.onbSkip),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  const _WelcomePage(),
                  _ProfilePage(
                    conditions: _conditions,
                    allergies: _allergies,
                    diets: _diets,
                    onChanged: () => setState(() {}),
                  ),
                  const _SafetyPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  for (var i = 0; i < total; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? c.brand : c.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : (last ? _finish : () => _go(_page + 1)),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(last ? l.onbGetStarted : l.onbNext),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        const Center(child: BrandMark(size: 72)),
        const SizedBox(height: 20),
        Text(
          l.onbWelcomeTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium,
        ),
        const SizedBox(height: 10),
        Text(
          l.onbWelcomeBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        point(Icons.photo_camera_back_outlined, l.onbPointScan),
        point(Icons.tune_rounded, l.onbPointPersonal),
        point(Icons.swap_horiz_rounded, l.onbPointAlternatives),
        const SizedBox(height: 12),
        Text(l.onbChooseLanguage, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<Locale?>(
          valueListenable: ThemeController.locale,
          builder: (context, current, _) {
            final active =
                current?.languageCode ??
                Localizations.localeOf(context).languageCode;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (locale, name) in supportedLanguages)
                  ChoiceChip(
                    label: Text(name),
                    selected: active == locale.languageCode,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      ThemeController.setLocale(locale);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final Set<String> conditions;
  final Set<String> allergies;
  final Set<String> diets;
  final VoidCallback onChanged;

  const _ProfilePage({
    required this.conditions,
    required this.allergies,
    required this.diets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    String allergyLabel(String key) => switch (key) {
      'peanut' => l.allergy_peanut,
      'milk' => l.allergy_milk,
      'gluten' => l.allergy_gluten,
      'soy' => l.allergy_soy,
      'egg' => l.allergy_egg,
      _ => l.allergy_tree_nuts,
    };

    Widget group(
      String title,
      List<String> keys,
      Set<String> picked,
      String Function(String) label,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in keys)
                FilterChip(
                  label: Text(label(k)),
                  selected: picked.contains(k),
                  onSelected: (on) {
                    HapticFeedback.selectionClick();
                    on ? picked.add(k) : picked.remove(k);
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        Text(l.onbProfileTitle, style: theme.textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(l.onbProfileBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        group(l.onbAllergiesTitle, _allergyChoices, allergies, allergyLabel),
        group(
          l.onbConditionsTitle,
          _conditionChoices,
          conditions,
          l.conditionLabel,
        ),
        group(l.onbDietTitle, _dietChoices, diets, l.dietLabel),
      ],
    );
  }
}

class _SafetyPage extends StatelessWidget {
  const _SafetyPage();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: c.tint(c.warning, theme.brightness),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.health_and_safety_outlined,
            color: c.warning,
            size: 32,
          ),
        ),
        const SizedBox(height: 18),
        Text(l.onbSafetyTitle, style: theme.textTheme.displaySmall),
        const SizedBox(height: 12),
        Text(
          l.disclaimerBody,
          style: AppTheme.ui(
            16,
            height: 1.55,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

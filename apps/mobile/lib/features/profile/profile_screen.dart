import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/status_view.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../settings/settings_screen.dart';
import 'body_details_sheet.dart';
import 'prescription_card.dart';
import 'prescription_consent.dart';
import 'prescription_merge.dart';
import 'prescription_review_screen.dart';

/// Every condition the backend knows, so anything added (including from a
/// prescription) can also be seen and removed here. Labels come from the
/// app's translations; the English values here are for tests and logs.
const Map<String, String> kConditionOptions = {
  'diabetes_type_1': 'Type 1 Diabetes',
  'diabetes_type_2': 'Type 2 Diabetes',
  'prediabetes': 'Prediabetes',
  'hypertension': 'Hypertension',
  'high_cholesterol': 'High Cholesterol',
  'celiac_disease': 'Celiac Disease',
  'ibs': 'IBS',
  'kidney_disease': 'Kidney Disease',
  'heart_disease': 'Heart Disease',
  'obesity': 'Obesity',
  'lactose_intolerance': 'Lactose Intolerance',
  'anaemia': 'Anaemia',
};

const _dietKeys = [
  'vegetarian', 'vegan', 'gluten_free', 'dairy_free', 'halal', 'kosher',
  'low_carb', 'keto', 'paleo',
];

const _goalKeys = [
  'weight_loss', 'muscle_gain', 'maintain_weight', 'improve_energy',
  'improve_digestion', 'reduce_inflammation', 'manage_blood_sugar', 'heart_health',
];

/// Profile: who you are, your body details, and the four things scoring uses
/// (goals, conditions, diet, allergies). Settings sit behind the gear icon.
class ProfileScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  /// Bumped by the tab bar to refresh quietly when the tab is shown again.
  final int refreshTick;

  const ProfileScreen({
    super.key,
    this.refreshTick = 0,
    required this.apiService,
    required this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  UserProfile? _profile;
  String? _error;
  bool _readingPrescription = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void didUpdateWidget(covariant ProfileScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick != old.refreshTick) _loadProfile(silent: true);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// [silent]: refresh in the background, keeping what's on screen.
  Future<void> _loadProfile({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final profile = await widget.apiService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  void _openSettings() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(apiService: widget.apiService)),
    ).then((_) {
      // Data may have been deleted in Settings; show the fresh state.
      if (mounted) _loadProfile();
    });
  }

  /// Consent → capture → read → review → (only if confirmed) save.
  ///
  /// The photo is held in memory for the request and the picker's temporary
  /// copy is deleted afterwards. Nothing is added to the profile unless the
  /// user ticks it on the review screen.
  Future<void> _scanPrescription() async {
    final profile = _profile;
    if (profile == null) return;
    if (!await PrescriptionConsent.ensure(context)) return;
    if (!mounted) return;
    final l = context.l10n;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _readingPrescription = true);
      final suggestions = await widget.apiService.analyzePrescription(
        photoBytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() => _readingPrescription = false);

      final updated = await Navigator.push<UserProfile>(
        context,
        MaterialPageRoute(
          builder: (_) => PrescriptionReviewScreen(
              suggestions: suggestions, currentProfile: profile),
        ),
      );
      if (updated != null && mounted) {
        // Merge onto the profile as it is now, not the snapshot from before
        // the read, so edits made in the meantime are kept.
        await _updateProfileField(mergePrescriptionAdditions(
          current: _profile ?? profile,
          snapshot: profile,
          accepted: updated,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(UserMessage.of(context, e))));
    } finally {
      if (mounted) setState(() => _readingPrescription = false);
      if (file != null && !kIsWeb) {
        try {
          await File(file.path).delete();
        } catch (_) {
          // Best effort: the OS clears its cache directory anyway.
        }
      }
    }
  }

  Future<void> _updateProfileField(UserProfile updated) async {
    setState(() => _isLoading = true);
    try {
      final saved = await widget.apiService.updateProfile(updated);
      if (!mounted) return;
      setState(() {
        _profile = saved;
        _isLoading = false;
      });
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.saved),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UserMessage.of(context, e);
        _isLoading = false;
      });
    }
  }

  Future<void> _editBody() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await showBodyDetailsSheet(context, profile);
    if (updated != null && mounted) await _updateProfileField(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.profileTitle),
        actions: [
          IconButton(
            tooltip: l.settingsTooltip,
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? StatusView(
                  icon: Icons.cloud_off_rounded,
                  title: l.profileErrorTitle,
                  message: _error!,
                  actionLabel: l.tryAgain,
                  onAction: _loadProfile,
                  isError: true,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    _buildIdentity(context),
                    const SizedBox(height: 14),
                    _BodyCard(profile: _profile!, onEdit: _editBody),
                    const SizedBox(height: 14),
                    _buildSection(
                      context,
                      title: l.sectionGoals,
                      icon: Icons.flag_rounded,
                      accent: c.brand,
                      caption: l.goalsCaption,
                      items: _profile?.healthGoals ?? const [],
                      label: l.goalLabel,
                      onEdit: () async {
                        final result = await _showMultiSelectDialog(
                            l.sectionGoals, _goalKeys, l.goalLabel,
                            _profile?.healthGoals ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(_profile!.copyWith(healthGoals: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      context,
                      title: l.sectionConditions,
                      icon: Icons.monitor_heart_rounded,
                      accent: c.accent,
                      caption: l.conditionsCaption,
                      items: _profile?.healthConditions ?? const [],
                      label: l.conditionLabel,
                      onEdit: () async {
                        final result = await _showMultiSelectDialog(
                            l.sectionConditions, kConditionOptions.keys.toList(),
                            l.conditionLabel, _profile?.healthConditions ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(_profile!.copyWith(healthConditions: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      context,
                      title: l.sectionDiet,
                      icon: Icons.restaurant_menu_rounded,
                      accent: c.good,
                      caption: l.dietCaption,
                      items: _profile?.dietaryPreferences ?? const [],
                      label: l.dietLabel,
                      onEdit: () async {
                        final result = await _showMultiSelectDialog(
                            l.sectionDiet, _dietKeys, l.dietLabel,
                            _profile?.dietaryPreferences ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(_profile!.copyWith(dietaryPreferences: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      context,
                      title: l.sectionAllergies,
                      icon: Icons.warning_amber_rounded,
                      accent: c.critical,
                      caption: l.allergiesCaption,
                      items: _profile?.allergies ?? const [],
                      label: (a) => a.isEmpty ? a : '${a[0].toUpperCase()}${a.substring(1)}',
                      onEdit: () async {
                        final result = await _showAllergiesDialog(_profile?.allergies ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(_profile!.copyWith(allergies: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    PrescriptionCard(busy: _readingPrescription, onTap: _scanPrescription),
                    const SizedBox(height: 8),
                    Text(l.disclaimerShort,
                        textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ],
                ),
    );
  }

  /// How many of the four scoring sections have something in them.
  int get _filledSections {
    final p = _profile;
    if (p == null) return 0;
    return [
      p.healthGoals.isNotEmpty,
      p.healthConditions.isNotEmpty,
      p.dietaryPreferences.isNotEmpty,
      p.allergies.isNotEmpty,
    ].where((b) => b).length;
  }

  Widget _buildIdentity(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final c = context.colors;
    final name = _profile?.name ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    final filled = _filledSections;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft),
                alignment: Alignment.center,
                child: Text(initial,
                    style: AppTheme.display(28, weight: FontWeight.w700, color: c.brand)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? l.addYourName : name,
                        style: theme.textTheme.displaySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      name.isEmpty ? l.introduceYourself : l.signedInAnonymously,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showEditNameDialog,
                tooltip: l.editName,
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.profileSetup, style: theme.textTheme.labelMedium)),
                    Text(l.filledOf(filled, 4),
                        style: AppTheme.ui(13,
                            weight: FontWeight.w700, color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: filled / 4, minHeight: 6),
                ),
                if (filled < 4) ...[
                  const SizedBox(height: 8),
                  Text(l.moreAccurate, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color accent,
    required String caption,
    required List<String> items,
    required String Function(String) label,
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 18),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.tint(accent, theme.brightness),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(caption, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: accent),
                  const SizedBox(width: 4),
                  Text(context.l10n.add,
                      style: AppTheme.ui(13, weight: FontWeight.w700, color: accent)),
                ],
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colors.tint(accent, theme.brightness),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(label(item),
                        style: AppTheme.ui(13, weight: FontWeight.w600, color: accent)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    final nameController = TextEditingController(text: _profile?.name);
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.yourName),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l.nameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              Navigator.pop(context);
              if (newName.isNotEmpty && newName != _profile?.name && _profile != null) {
                _updateProfileField(_profile!.copyWith(name: newName));
              }
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<List<String>?> _showMultiSelectDialog(String title, List<String> keys,
      String Function(String) label, List<String> initial) {
    final selected = Set<String>.from(initial);
    final theme = Theme.of(context);
    final l = context.l10n;

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keys.map((key) {
                final isSelected = selected.contains(key);
                return FilterChip(
                  label: Text(label(key)),
                  selected: isSelected,
                  onSelected: (val) => setDialogState(() {
                    HapticFeedback.selectionClick();
                    val ? selected.add(key) : selected.remove(key);
                  }),
                  side: BorderSide(
                    color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                  ),
                  labelStyle: AppTheme.ui(14,
                      weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected.toList()),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _showAllergiesDialog(List<String> initial) {
    final allergies = List<String>.from(initial);
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final l = context.l10n;

    void addFrom(String raw, void Function(void Function()) setDialogState) {
      final text = raw.trim().toLowerCase();
      if (text.isNotEmpty && !allergies.contains(text)) {
        setDialogState(() {
          allergies.add(text);
          controller.clear();
        });
      }
    }

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l.sectionAllergies),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(hintText: l.allergiesHint),
                        onSubmitted: (val) => addFrom(val, setDialogState),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_rounded, color: theme.colorScheme.primary),
                      tooltip: l.addAllergy,
                      onPressed: () => addFrom(controller.text, setDialogState),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (allergies.isEmpty)
                  Text(l.noAllergies, style: theme.textTheme.bodyMedium)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allergies
                        .map((a) => Chip(
                              label: Text(a, style: theme.textTheme.bodyLarge),
                              deleteIcon:
                                  Icon(Icons.close, size: 16, color: context.colors.critical),
                              onDeleted: () => setDialogState(() => allergies.remove(a)),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(context, allergies),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// Height, weight, BMI (with its band), age, sex, activity and target weight.
class _BodyCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;
  const _BodyCard({required this.profile, required this.onEdit});

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final c = context.colors;
    final p = profile;
    final bandColor = switch (p.bmiCategory) {
      'normal' => c.excellent,
      'overweight' => c.fair,
      'obese' => c.poor,
      'underweight' => c.warning,
      _ => c.muted,
    };

    Widget fact(String label, String? value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value ?? '—', style: theme.textTheme.titleMedium),
            ],
          ),
        );

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.tint(c.accent, theme.brightness),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.accessibility_new_rounded, color: c.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.bodyTitle, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(l.bodyCaption, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 14),
          if (!p.hasBodyDetails)
            Text(l.addBodyDetails,
                style: AppTheme.ui(14, weight: FontWeight.w700, color: c.accent))
          else ...[
            Row(
              children: [
                fact(l.height, p.heightCm == null ? null : '${_num(p.heightCm!)} ${l.unitCm}'),
                fact(l.weight, p.weightKg == null ? null : '${_num(p.weightKg!)} ${l.unitKg}'),
                fact(l.age, p.age == null ? null : l.ageYears(p.age!)),
              ],
            ),
            const SizedBox(height: 12),
            if (p.bmi != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 6,
                children: [
                  Text('${l.bmi} ', style: theme.textTheme.labelMedium),
                  Text(p.bmi!.toStringAsFixed(1),
                      style: AppTheme.display(22, weight: FontWeight.w700, color: bandColor)),
                  const SizedBox(width: 8),
                  if (p.bmiCategory != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.tint(bandColor, theme.brightness),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(l.bmiCategoryLabel(p.bmiCategory!),
                          style: AppTheme.ui(13, weight: FontWeight.w700, color: bandColor)),
                    ),
                ],
              )
            else
              Text(l.bmiNeedsBoth, style: theme.textTheme.bodySmall),
            if (p.targetWeightKg != null || p.activityLevel != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  fact(l.targetWeight,
                      p.targetWeightKg == null ? null : '${_num(p.targetWeightKg!)} ${l.unitKg}'),
                  fact(l.activityLevel,
                      p.activityLevel == null ? null : l.activityLabel(p.activityLevel!)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

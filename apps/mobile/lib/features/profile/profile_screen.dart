import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/user_message.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import 'prescription_card.dart';
import 'prescription_consent.dart';
import 'prescription_merge.dart';
import 'prescription_review_screen.dart';

/// Every condition the backend knows, so anything added (including from a
/// prescription) can also be seen and removed here.
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

/// Profile screen.
///
/// Four sections — Goals, Conditions, Diet, Allergies — each editable by tap.
/// Snackbar confirmations use interface voice: "Saved" instead of
/// "Profile updated".
class ProfileScreen extends StatefulWidget {
  final ApiService apiService;
  final String userId;

  const ProfileScreen({
    super.key,
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

  Map<String, String> get _conditionOptions => kConditionOptions;

  final Map<String, String> _dietaryOptions = const {
    'vegetarian': 'Vegetarian',
    'vegan': 'Vegan',
    'gluten_free': 'Gluten-free',
    'dairy_free': 'Dairy-free',
    'halal': 'Halal',
    'kosher': 'Kosher',
    'low_carb': 'Low carb',
    'keto': 'Keto',
    'paleo': 'Paleo',
  };

  final Map<String, String> _goalOptions = const {
    'weight_loss': 'Weight loss',
    'muscle_gain': 'Muscle gain',
    'maintain_weight': 'Maintain weight',
    'improve_energy': 'More energy',
    'improve_digestion': 'Better digestion',
    'reduce_inflammation': 'Less inflammation',
    'manage_blood_sugar': 'Manage blood sugar',
    'heart_health': 'Heart health',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await widget.apiService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? file;
    try {
      file = await _picker.pickImage(
          source: source, maxWidth: 2000, imageQuality: 85);
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserMessage.fromError(e))));
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
        content: const Text('Saved'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
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
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.verdict))
          : _error != null
              ? _buildError(theme)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    _buildIdentity(context),
                    const SizedBox(height: 28),
                    _buildSection(
                      context,
                      title: 'Goals',
                      icon: Icons.flag_rounded,
                      accent: AppColors.verdict,
                      caption: 'What are you working toward?',
                      items: _profile?.healthGoals ?? const [],
                      onEdit: () async {
                        final result = await _showMultiSelectDialog(
                            'Goals', _goalOptions, _profile?.healthGoals ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(_profile!.copyWith(healthGoals: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      context,
                      title: 'Conditions',
                      icon: Icons.monitor_heart_rounded,
                      accent: AppColors.ember,
                      caption: 'We lower scores for products that aggravate these.',
                      items: _profile?.healthConditions ?? const [],
                      onEdit: () async {
                        final result = await _showMultiSelectDialog(
                            'Conditions',
                            _conditionOptions,
                            _profile?.healthConditions ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(
                              _profile!.copyWith(healthConditions: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      context,
                      title: 'Diet',
                      icon: Icons.restaurant_menu_rounded,
                      accent: const Color(0xFFBEE86E),
                      caption: 'We flag products that break these.',
                      items: _profile?.dietaryPreferences ?? const [],
                      onEdit: () async {
                        final result = await _showMultiSelectDialog(
                            'Diet',
                            _dietaryOptions,
                            _profile?.dietaryPreferences ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(
                              _profile!.copyWith(dietaryPreferences: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildSection(
                      context,
                      title: 'Allergies',
                      icon: Icons.warning_amber_rounded,
                      accent: AppColors.critical,
                      caption: 'Anything in these ingredients means we warn you.',
                      items: _profile?.allergies ?? const [],
                      onEdit: () async {
                        final result = await _showAllergiesDialog(
                            _profile?.allergies ?? const []);
                        if (result != null && _profile != null) {
                          _updateProfileField(_profile!.copyWith(allergies: result));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    PrescriptionCard(
                      busy: _readingPrescription,
                      onTap: _scanPrescription,
                    ),
                  ],
                ),
    );
  }

  /// How many of the four profile sections have something in them.
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
    final name = _profile?.name ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    final filled = _filledSections;

    return SurfaceCard(
      accent: AppColors.verdict,
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6CF0B4), Color(0xFF1FB57A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.verdict.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: AppTheme.display(28,
                        weight: FontWeight.w600, color: AppColors.bg)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Add your name' : name,
                        style: theme.textTheme.displaySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    // The anonymous device ID is not meaningful to the user;
                    // show a friendly subtitle instead of the raw id.
                    Text(
                      name.isEmpty
                          ? 'Tap the pencil to introduce yourself'
                          : 'Signed in anonymously on this device',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showEditNameDialog,
                tooltip: 'Edit name',
                icon: Icon(Icons.edit_outlined,
                    color: theme.colorScheme.primary, size: 20),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Profile setup', style: theme.textTheme.labelMedium),
                    Text('$filled of 4',
                        style: AppTheme.ui(12,
                            weight: FontWeight.w700,
                            color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: filled / 4,
                    minHeight: 6,
                    color: theme.colorScheme.primary,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.14),
                  ),
                ),
                if (filled < 4) ...[
                  const SizedBox(height: 8),
                  Text(
                    'The more you add, the more accurate your scores get.',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
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
    required List<dynamic> items,
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
                  color: accent.withValues(alpha: 0.14),
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
                    Text(caption,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: accent),
                  const SizedBox(width: 4),
                  Text('Add',
                      style: AppTheme.ui(12, weight: FontWeight.w700, color: accent)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _humanize(item.toString()),
                      style: AppTheme.ui(12, weight: FontWeight.w600, color: accent),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _humanize(String raw) {
    return raw
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
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
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadProfile,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdict,
                foregroundColor: AppColors.bg,
              ),
              child: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final nameController = TextEditingController(text: _profile?.name);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Your name', style: theme.textTheme.titleLarge),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'What should we call you?',
            hintStyle: theme.textTheme.bodyMedium,
            border: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.dividerColor)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.verdict)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () {
              final newName = nameController.text.trim();
              Navigator.pop(context);
              if (newName.isNotEmpty &&
                  newName != _profile?.name &&
                  _profile != null) {
                _updateProfileField(_profile!.copyWith(name: newName));
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.verdict,
              foregroundColor: AppColors.bg,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<List<String>?> _showMultiSelectDialog(
      String title, Map<String, String> options, List<dynamic> initial) {
    final selected =
        Set<String>.from(initial.map((e) => e.toString()));
    final theme = Theme.of(context);

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: theme.textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.entries.map((e) {
                final isSelected = selected.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: isSelected,
                  onSelected: (val) => setDialogState(() {
                    HapticFeedback.selectionClick();
                    val ? selected.add(e.key) : selected.remove(e.key);
                  }),
                  selectedColor: AppColors.verdict.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.verdict,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.verdict
                          : theme.dividerColor,
                    ),
                  ),
                  labelStyle: AppTheme.ui(13,
                      weight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.verdict
                          : theme.textTheme.titleLarge?.color),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdict,
                foregroundColor: AppColors.bg,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _showAllergiesDialog(List<dynamic> initial) {
    final allergies =
        List<String>.from(initial.map((e) => e.toString()));
    final controller = TextEditingController();
    final theme = Theme.of(context);

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Allergies', style: theme.textTheme.titleLarge),
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
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'e.g. peanut, soy',
                          hintStyle: theme.textTheme.bodyMedium,
                          border: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: theme.dividerColor)),
                          focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.verdict)),
                        ),
                        onSubmitted: (val) {
                          final text = val.trim().toLowerCase();
                          if (text.isNotEmpty && !allergies.contains(text)) {
                            setDialogState(() {
                              allergies.add(text);
                              controller.clear();
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.verdict),
                      onPressed: () {
                        final text = controller.text.trim().toLowerCase();
                        if (text.isNotEmpty && !allergies.contains(text)) {
                          setDialogState(() {
                            allergies.add(text);
                            controller.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (allergies.isEmpty)
                  Text('No allergies added.', style: theme.textTheme.bodyMedium)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allergies
                        .map((a) => Chip(
                              label: Text(a, style: theme.textTheme.bodyLarge),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              deleteIcon: const Icon(Icons.close,
                                  size: 16, color: AppColors.critical),
                              side: BorderSide(color: theme.dividerColor),
                              onDeleted: () =>
                                  setDialogState(() => allergies.remove(a)),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, allergies),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verdict,
                foregroundColor: AppColors.bg,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

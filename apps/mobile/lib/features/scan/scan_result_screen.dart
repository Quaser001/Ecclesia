import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/health_score_ring.dart';
import '../../core/widgets/medical_disclaimer.dart';
import '../../core/widgets/profile_chips.dart';
import '../../core/widgets/scan_photo.dart';
import '../../core/widgets/status_view.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../models/scan_result.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../core/utils/score_format.dart';

/// Scan result: the score reveal, what was found, the nutrient levels, what's
/// on the label, what to try instead, and "was this right?".
///
/// Also used for past scans opened from Home, History or Insights
/// ([isPastScan]). Alternatives are not stored with a scan, so that section
/// is left out for past scans rather than claiming none were needed.
class ScanResultScreen extends StatelessWidget {
  final ScanResult scanResult;
  final String? title;
  final bool isPastScan;

  /// Sends "was this right?" answers. Without it the question isn't shown.
  final ApiService? apiService;

  const ScanResultScreen({
    super.key,
    required this.scanResult,
    this.title,
    this.isPastScan = false,
    this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isPastScan ? Icons.arrow_back_rounded : Icons.close_rounded),
          tooltip: isPastScan ? context.l10n.back : context.l10n.close,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: Text(title ?? context.l10n.scanResultTitle),
      ),
      body: scanResult.insufficientData
          ? StatusView(
              icon: Icons.photo_camera_back_outlined,
              title: context.l10n.cantReadLabel,
              message: scanResult.pipelineMessage ?? context.l10n.cantReadLabelBody,
              actionLabel: context.l10n.tryAnotherPhoto,
              onAction: () => Navigator.of(context).pop(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _Hero(scanResult: scanResult, isPastScan: isPastScan),
                const SizedBox(height: 28),
                _ScoredFor(profile: scanResult.scoreResult.scoredFor, isPastScan: isPastScan),
                if (scanResult.identification?.chosen != null) ...[
                  _IdentifiedAs(
                    chosen: scanResult.identification!.chosen!,
                    scanId: scanResult.scanId,
                    apiService: isPastScan ? null : apiService,
                  ),
                  const SizedBox(height: 24),
                ],
                _Findings(findings: scanResult.scoreResult.findings),
                _NutrientLevels(levels: scanResult.nutrientLevels),
                if (scanResult.servingSizeUnknown &&
                    apiService != null &&
                    scanResult.scanId.isNotEmpty) ...[
                  _ServingNote(apiService: apiService!, scanId: scanResult.scanId),
                  const SizedBox(height: 24),
                ],
                _LabelFacts(scanResult: scanResult),
                if (!isPastScan) ...[
                  const SizedBox(height: 28),
                  _Alternatives(scanResult: scanResult),
                ],
                if (apiService != null && scanResult.scanId.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _FeedbackCard(apiService: apiService!, scanId: scanResult.scanId),
                ],
                const MedicalDisclaimerFooter(),
              ],
            ),
    );
  }
}

/// What this rating was for. Past ratings are history: they keep the profile
/// they were scored for, and editing the profile doesn't change them.
class _ScoredFor extends StatelessWidget {
  final UserProfile? profile;
  final bool isPastScan;
  const _ScoredFor({required this.profile, required this.isPastScan});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null && !isPastScan) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.scoredForTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (p != null && !ProfileChips.isEmpty(p)) ...[
            ProfileChips(profile: p),
            const SizedBox(height: 8),
          ] else if (p != null) ...[
            Text(l.scoredForNone, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
          ],
          if (isPastScan) Text(l.scoredForNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final ScanResult scanResult;
  final bool isPastScan;
  const _Hero({required this.scanResult, required this.isPastScan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final score = scanResult.scoreResult.score;
    final color = c.score(score);
    final brand = scanResult.product.brand;

    return Column(
      children: [
        if (brand != null && brand.isNotEmpty)
          Text(brand.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(
          scanResult.product.productName ?? context.l10n.unnamedProduct,
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium,
        ),
        if (isPastScan && scanResult.imageUrl != null) ...[
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: context.l10n.viewPhoto,
            child: ScanPhoto(
              url: scanResult.imageUrl!,
              size: 96,
              radius: 16,
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.black87,
                  pageBuilder: (context, a, b) => _PhotoViewer(url: scanResult.imageUrl!),
                  transitionsBuilder: (context, a, b, child) =>
                      FadeTransition(opacity: a, child: child),
                ),
              ),
            ),
          ),
        ],
        if (isPastScan) ...[
          const SizedBox(height: 6),
          Text(context.l10n.scannedWhen(context.l10n.relativeTime(scanResult.scannedAt)),
              style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
        HealthScoreRing(score: score, size: 188, strokeWidth: 12, animate: !isPastScan),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: c.tint(color, theme.brightness),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            context.l10n.suitabilityLabel(scanResult.scoreResult.suitability),
            style: AppTheme.ui(14, weight: FontWeight.w700, color: color),
          ),
        ),
        if (scanResult.explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            scanResult.explanation,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _Findings extends StatelessWidget {
  final List<ScanFinding> findings;
  const _Findings({required this.findings});

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.whatWeFound(findings.length),
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          for (final f in findings) ...[
            _FindingCard(finding: f),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Fat, saturated fat, sugars and salt per 100 g/ml as low / medium / high,
/// each with a word and an icon as well as a colour.
class _NutrientLevels extends StatelessWidget {
  final List<NutrientLevel> levels;
  const _NutrientLevels({required this.levels});

  static String _fmt(double v, String nutrient) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(nutrient == 'salt' ? 2 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;
    String name(String key) => switch (key) {
      'fat' => l.nutrientTotalFat,
      'saturated_fat' => l.nutrientSaturatedFat,
      'sugars' => l.nutrientSugars,
      _ => l.nutrientSalt,
    };

    Widget tile(NutrientLevel lv, double width) {
      final (tone, word, icon) = switch (lv.level) {
        NutrientLevelBand.low => (c.excellent, l.levelLow, Icons.check_circle_outline_rounded),
        NutrientLevelBand.medium => (c.warning, l.levelMedium, Icons.remove_circle_outline_rounded),
        NutrientLevelBand.high => (c.critical, l.levelHigh, Icons.error_outline_rounded),
      };
      final amount = '${_fmt(lv.per100, lv.nutrient)} ${lv.unit}';
      return Semantics(
        container: true,
        label: '${name(lv.nutrient)}: $word, $amount',
        excludeSemantics: true,
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: c.tint(tone, theme.brightness),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name(lv.nutrient), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, size: 16, color: tone),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(word,
                        style: AppTheme.ui(14, weight: FontWeight.w700, color: tone)),
                  ),
                ],
              ),
              Text(amount, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.atAGlance, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(levels.first.perMl ? l.levelsPer100ml : l.levelsPer100g,
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final width = (box.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final lv in levels) tile(lv, width)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LabelFacts extends StatelessWidget {
  final ScanResult scanResult;
  const _LabelFacts({required this.scanResult});

  static String _fmt(double? val) {
    if (val == null) return '—';
    if (val == val.toInt()) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  /// Whose numbers these are: the user's saved serving, a database's
  /// per-100 values, or the label's own per-serving column.
  String _basisNote(BuildContext context) {
    final l = context.l10n;
    final n = scanResult.product.nutrition;
    final source = scanResult.product.dataSource;
    if (n.servingSizeSource == 'you' && n.servingSizeG != null) {
      return l.labelNoteYourServing(_fmt(n.servingSizeG));
    }
    if (source != null && n.servingSizeG == 100) {
      return l.labelNotePer100(
          source == 'open_food_facts' ? l.sourceOpenFoodFacts : l.sourceCalfitDb);
    }
    return l.perServingNote;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nut = scanResult.product.nutrition;
    final ingredients = scanResult.product.ingredients;
    final l = context.l10n;
    final rows = <(String, String, String)>[
      (l.nutrientCalories, _fmt(nut.caloriesKcal), 'kcal'),
      (l.nutrientTotalFat, _fmt(nut.totalFatG), 'g'),
      (l.nutrientSaturatedFat, _fmt(nut.saturatedFatG), 'g'),
      (l.nutrientSodium, _fmt(nut.sodiumMg), 'mg'),
      (l.nutrientCarbs, _fmt(nut.totalCarbsG), 'g'),
      (l.nutrientSugars, _fmt(nut.sugarsG), 'g'),
      (l.nutrientProtein, _fmt(nut.proteinG), 'g'),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.onTheLabel, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(_basisNote(context), style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: context.colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(r.$1, style: theme.textTheme.bodyLarge)),
                  Text(r.$2, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 34,
                    child: Text(r.$3, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ],
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l.ingredients, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(ingredients.join(', '), style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Alternatives extends StatelessWidget {
  final ScanResult scanResult;
  const _Alternatives({required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;

    if (scanResult.alternatives.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: c.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.l10n.noAlternative, style: theme.textTheme.bodyLarge),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.tryInstead, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(context.l10n.tryInsteadBody, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final alt in scanResult.alternatives) ...[
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (alt.imageUrl != null) ...[
                      _ProductThumb(url: alt.imageUrl!),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(alt.name ?? alt.criteria ?? context.l10n.tryInstead,
                          style: theme.textTheme.titleLarge),
                    ),
                    if (alt.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.brandSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(context.l10n.inOurDatabase,
                            style: AppTheme.ui(12, weight: FontWeight.w700, color: c.brand)),
                      ),
                  ],
                ),
                if (alt.brand != null) ...[
                  const SizedBox(height: 2),
                  Text(alt.brand!, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 8),
                Text(alt.reason, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Which real product a front-of-pack scan used, and where its numbers came
/// from. "Not this product?" removes the scan so the user can retake it.
class _IdentifiedAs extends StatelessWidget {
  final ProductOption chosen;
  final String scanId;
  final ApiService? apiService; // null for past scans: nothing to retake
  const _IdentifiedAs({required this.chosen, required this.scanId, this.apiService});

  Future<void> _remove(BuildContext context) async {
    final l = context.l10n;
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: c.critical),
        title: Text(l.removeScanTitle),
        content: Text(l.removeScanBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.critical),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await apiService!.deleteScan(scanId);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.scanRemoved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.couldntRemove)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;
    final name = [chosen.name, chosen.quantity].whereType<String>().join(' · ');
    final source = chosen.fromOpenFoodFacts ? l.sourceOpenFoodFacts : l.sourceCalfitDb;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.fact_check_outlined, color: c.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.identifiedAs(name), style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(l.identifiedSource(source), style: theme.textTheme.bodySmall),
                if (apiService != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => _remove(context),
                      child: Text(l.notThisProduct),
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Serving size unknown, check the pack": the label's numbers have no
/// basis. The user's answer is remembered for this product and used on the
/// next scan of it; this scan's score is left as it is.
class _ServingNote extends StatefulWidget {
  final ApiService apiService;
  final String scanId;
  const _ServingNote({required this.apiService, required this.scanId});

  @override
  State<_ServingNote> createState() => _ServingNoteState();
}

class _ServingNoteState extends State<_ServingNote> {
  String? _saved;

  Future<void> _open() async {
    final amount = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ServingSheet(apiService: widget.apiService, scanId: widget.scanId),
    );
    if (amount != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() => _saved = amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;
    return SurfaceCard(
      background: Color.alphaBlend(
          c.tint(c.warning, theme.brightness).withValues(alpha: 0.08), theme.colorScheme.surface),
      padding: const EdgeInsets.all(16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten_rounded, color: c.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(l.servingUnknownTitle, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            if (_saved == null) ...[
              Text(l.servingUnknownBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l.addServingSize),
              ),
            ] else
              Semantics(
                liveRegion: true,
                child: Text(l.servingSaved(_saved!), style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServingSheet extends StatefulWidget {
  final ApiService apiService;
  final String scanId;
  const _ServingSheet({required this.apiService, required this.scanId});

  @override
  State<_ServingSheet> createState() => _ServingSheetState();
}

class _ServingSheetState extends State<_ServingSheet> {
  final _amount = TextEditingController();
  String _basis = 'per_100';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    return (v != null && v > 0 && v <= 5000) ? v : null;
  }

  Future<void> _save() async {
    final v = _value;
    if (v == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.saveServingSize(widget.scanId,
          servingSizeG: v, labelBasis: _basis);
      if (!mounted) return;
      Navigator.pop(context, v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.servingSaveFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.servingSheetTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: l.servingAmountLabel,
                  helperText: l.servingAmountHelp,
                  helperMaxLines: 3,
                  suffixText: 'g / ml',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Text(l.servingBasisLabel, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'per_100', label: Text(l.basisPer100)),
                  ButtonSegment(value: 'per_serving', label: Text(l.basisPerServing)),
                ],
                selected: {_basis},
                onSelectionChanged: (s) => setState(() => _basis = s.first),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTheme.ui(14, color: context.colors.critical)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _value == null || _saving ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Was this result right?" Yes is one tap; "Not quite" asks what was wrong
/// from a fixed list (no free text, so no health details are typed in).
/// The answers feed the accuracy numbers in docs/EVALS_AND_OBSERVABILITY.md.
class _FeedbackCard extends StatefulWidget {
  final ApiService apiService;
  final String scanId;
  const _FeedbackCard({required this.apiService, required this.scanId});

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

enum _FeedbackStage { ask, pickIssues, sending, done }

const _feedbackIssues = [
  'wrong_product',
  'wrong_nutrition',
  'wrong_ingredients',
  'missed_allergen',
  'score_unfair',
  'other',
];

class _FeedbackCardState extends State<_FeedbackCard> {
  var _stage = _FeedbackStage.ask;
  final _issues = <String>{};

  Future<void> _send({required bool accurate}) async {
    final back = accurate ? _FeedbackStage.ask : _FeedbackStage.pickIssues;
    setState(() => _stage = _FeedbackStage.sending);
    try {
      await widget.apiService.sendScanFeedback(
        widget.scanId,
        accurate: accurate,
        issues: _issues.toList(),
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _stage = _FeedbackStage.done);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = back);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.feedbackFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final l = context.l10n;

    String issueLabel(String key) => switch (key) {
      'wrong_product' => l.issueWrongProduct,
      'wrong_nutrition' => l.issueWrongNutrition,
      'wrong_ingredients' => l.issueWrongIngredients,
      'missed_allergen' => l.issueMissedAllergen,
      'score_unfair' => l.issueScoreUnfair,
      _ => l.issueOther,
    };

    final Widget body = switch (_stage) {
      _FeedbackStage.done => Row(
          key: const ValueKey('done'),
          children: [
            Icon(Icons.favorite_rounded, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(l.feedbackThanks, style: theme.textTheme.bodyLarge),
              ),
            ),
          ],
        ),
      _FeedbackStage.sending => const Center(
          key: ValueKey('sending'),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox.square(
                dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ),
      _FeedbackStage.pickIssues => Column(
          key: const ValueKey('issues'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.feedbackWhatWrong, style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in _feedbackIssues)
                  FilterChip(
                    label: Text(issueLabel(k)),
                    selected: _issues.contains(k),
                    onSelected: (on) {
                      HapticFeedback.selectionClick();
                      setState(() => on ? _issues.add(k) : _issues.remove(k));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _issues.clear();
                    _stage = _FeedbackStage.ask;
                  }),
                  child: Text(l.cancel),
                ),
                FilledButton(
                  onPressed: _issues.isEmpty ? null : () => _send(accurate: false),
                  child: Text(l.feedbackSend),
                ),
              ],
            ),
          ],
        ),
      _FeedbackStage.ask => Column(
          key: const ValueKey('ask'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.feedbackQuestion, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.feedbackWhy, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _send(accurate: true),
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                  label: Text(l.feedbackYes),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _stage = _FeedbackStage.pickIssues);
                  },
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                  label: Text(l.feedbackNo),
                ),
              ],
            ),
          ],
        ),
    };

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: body,
        ),
      ),
    );
  }
}

/// A scoring finding: severity pill (word + colour), title, detail, and the
/// points it cost.
class _FindingCard extends StatelessWidget {
  final ScanFinding finding;
  const _FindingCard({required this.finding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final (tone, label, icon) = switch (finding.severity) {
      FindingSeverity.critical => (c.critical, context.l10n.severityAvoid, Icons.block_rounded),
      FindingSeverity.alert => (c.accent, context.l10n.severityCaution, Icons.warning_amber_rounded),
      FindingSeverity.warning => (c.warning, context.l10n.severityHeadsUp, Icons.info_outline_rounded),
      FindingSeverity.info => (c.brand, context.l10n.severityGoodToKnow, Icons.lightbulb_outline_rounded),
    };

    return SurfaceCard(
      background: Color.alphaBlend(c.tint(tone, theme.brightness).withValues(alpha: 0.06),
          theme.colorScheme.surface),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: c.tint(tone, theme.brightness),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: tone),
                    const SizedBox(width: 4),
                    Text(label, style: AppTheme.ui(12, weight: FontWeight.w700, color: tone)),
                  ],
                ),
              ),
              const Spacer(),
              if (finding.scoreImpact > 0)
                Text(context.l10n.pointsLost(formatScore(finding.scoreImpact)),
                    style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          Text(finding.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(finding.detail, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Product photo from Open Food Facts for a suggested alternative. Falls back
/// to an icon when the image can't be loaded (offline, removed upstream).
class _ProductThumb extends StatelessWidget {
  final String url;
  const _ProductThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: c.elevated,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) =>
              Icon(Icons.image_not_supported_outlined, color: c.muted),
        ),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom view of a scan's photo.
class _PhotoViewer extends StatelessWidget {
  final String url;
  const _PhotoViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: context.l10n.close,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          ),
        ),
      ),
    );
  }
}

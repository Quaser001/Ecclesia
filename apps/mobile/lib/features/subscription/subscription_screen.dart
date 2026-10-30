import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/utils/user_message.dart';
import '../../core/widgets/surface_card.dart';
import '../../l10n/l10n.dart';
import '../../core/constants/app_colors.dart';
import 'subscription_plan.dart';
import 'subscription_service.dart';

/// The CalFit Premium page (paywall).
///
/// Hick's Law: one obvious main action. There is a single [FilledButton] (the
/// CTA); the plan cards are selectable surfaces, not competing buttons; and
/// "not now" is the app bar's back arrow, never a second equal-weight button.
///
/// Billing isn't wired yet, so [SubscriptionService] defaults to the honest
/// "coming soon" stub — the CTA never fakes a successful purchase (ADR-006).
class SubscriptionScreen extends StatefulWidget {
  final SubscriptionService service;

  const SubscriptionScreen({
    super.key,
    this.service = const ComingSoonSubscriptionService(),
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingPeriod _period = BillingPeriod.monthly;

  /// Default to the recommended plan so there is one obvious choice.
  String _selectedId = kSubscriptionPlans
      .firstWhere((p) => p.recommended, orElse: () => kSubscriptionPlans.last)
      .id;

  bool _busy = false;

  SubscriptionPlan get _selected =>
      kSubscriptionPlans.firstWhere((p) => p.id == _selectedId);

  Future<void> _start() async {
    final l = context.l10n;
    setState(() => _busy = true);
    bool unavailable = false;
    Object? error;
    try {
      await widget.service.startCheckout(_selected, _period);
      // The real implementation navigates to the provider's checkout here.
    } on SubscriptionUnavailable {
      unavailable = true;
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    // Drop the busy state before any dialog so the CTA spinner doesn't animate
    // behind it (and so a test can settle).
    setState(() => _busy = false);

    if (unavailable) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.subComingSoonTitle),
          content: Text(l.subComingSoon),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.done),
            ),
          ],
        ),
      );
    } else if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(UserMessage.of(context, error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.subTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(l.subTagline, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  _periodToggle(context),
                  const SizedBox(height: 16),
                  for (final plan in kSubscriptionPlans) ...[
                    _planCard(context, plan),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _periodToggle(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<BillingPeriod>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: BillingPeriod.monthly, label: Text(l.subPeriodMonthly)),
          ButtonSegment(value: BillingPeriod.annual, label: Text(l.subPeriodAnnual)),
        ],
        selected: {_period},
        onSelectionChanged: (s) {
          HapticFeedback.selectionClick();
          setState(() => _period = s.first);
        },
      ),
    );
  }

  Widget _planCard(BuildContext context, SubscriptionPlan plan) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;
    final selected = plan.purchasable && plan.id == _selectedId;
    final brand = c.brand;

    return SurfaceCard(
      accent: selected ? brand : null,
      onTap: plan.purchasable
          ? () {
              HapticFeedback.selectionClick();
              setState(() => _selectedId = plan.id);
            }
          : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (plan.purchasable)
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? brand : c.muted,
                  size: 22,
                )
              else
                Icon(Icons.check_circle_rounded, color: c.muted, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_planName(l, plan.id), style: theme.textTheme.titleLarge),
              ),
              const SizedBox(width: 8),
              if (plan.recommended) _badge(context, l.subRecommended, brand, c.onBrand)
              else if (!plan.purchasable)
                _badge(context, l.subCurrentPlan, c.elevated, c.muted),
            ],
          ),
          const SizedBox(height: 10),
          Text(_priceLabel(context, plan), style: theme.textTheme.displaySmall),
          const SizedBox(height: 2),
          Text(l.subScansPerDay(plan.scansPerDay), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          for (final perk in plan.perks) _perkRow(context, _perkLabel(l, perk)),
        ],
      ),
    );
  }

  Widget _perkRow(BuildContext context, String label) {
    final theme = Theme.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_rounded, size: 18, color: c.brand),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _start,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.subStart(_planName(l, _selectedId))),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.subFinePrint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _planName(AppLocalizations l, String id) => switch (id) {
        'free' => l.subPlanFree,
        'plus' => l.subPlanPlus,
        'pro' => l.subPlanPro,
        _ => id,
      };

  String _perkLabel(AppLocalizations l, PlanPerk perk) => switch (perk) {
        PlanPerk.personalScoring => l.subPerkPersonalScoring,
        PlanPerk.scanHistory => l.subPerkScanHistory,
        PlanPerk.advancedInsights => l.subPerkAdvancedInsights,
        PlanPerk.prescriptionReading => l.subPerkPrescription,
      };

  String _priceLabel(BuildContext context, SubscriptionPlan plan) {
    final l = context.l10n;
    final rupees = plan.rupeesFor(_period);
    if (rupees == null) return l.subPriceFree;
    final amount = '₹${NumberFormat('#,##0').format(rupees)}';
    return _period == BillingPeriod.monthly
        ? l.subPriceMonthly(amount)
        : l.subPriceAnnual(amount);
  }
}

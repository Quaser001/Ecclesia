/// The CalFit subscription plans, as plain data.
///
/// Only *facts* live here (ids, scans/day, prices, which perks apply). The
/// user-facing labels are localized in the screen via `context.l10n`, so this
/// file carries no translatable strings.
///
/// Prices are placeholders set by the founder on 2026-10-30 and are easy to
/// change here. When real billing is wired (Dodo, after Google sign-in — see
/// ADR-008 and the handoff), the live price should come from the billing
/// provider at checkout, which returns the amount already localized.
library;

/// Billed monthly or once a year.
enum BillingPeriod { monthly, annual }

/// A perk a plan includes. Labels are resolved in the screen.
enum PlanPerk {
  personalScoring,
  scanHistory,
  advancedInsights,
  prescriptionReading,
}

class SubscriptionPlan {
  /// Stable id used by the billing provider later ('free' | 'plus' | 'pro').
  final String id;

  /// Successful scans per UTC day this plan allows.
  final int scansPerDay;

  /// Price in whole rupees, or null for the free plan.
  final int? rupeesMonthly;
  final int? rupeesAnnual;

  final List<PlanPerk> perks;

  /// The one plan drawn as the obvious choice (Hick's Law).
  final bool recommended;

  /// Free isn't bought; it's what everyone has today.
  final bool purchasable;

  const SubscriptionPlan({
    required this.id,
    required this.scansPerDay,
    required this.rupeesMonthly,
    required this.rupeesAnnual,
    required this.perks,
    this.recommended = false,
    this.purchasable = true,
  });

  int? rupeesFor(BillingPeriod period) =>
      period == BillingPeriod.monthly ? rupeesMonthly : rupeesAnnual;
}

/// Plus and Pro add the same two paid perks on top of the free basics; Pro
/// simply raises the daily scan count.
const List<PlanPerk> _paidPerks = [
  PlanPerk.personalScoring,
  PlanPerk.scanHistory,
  PlanPerk.advancedInsights,
  PlanPerk.prescriptionReading,
];

/// The shipped plans. Annual = 10× monthly (two months free) — a placeholder
/// until the founder confirms the yearly price.
const List<SubscriptionPlan> kSubscriptionPlans = [
  SubscriptionPlan(
    id: 'free',
    scansPerDay: 4,
    rupeesMonthly: null,
    rupeesAnnual: null,
    purchasable: false,
    perks: [PlanPerk.personalScoring, PlanPerk.scanHistory],
  ),
  SubscriptionPlan(
    id: 'plus',
    scansPerDay: 10,
    rupeesMonthly: 199,
    rupeesAnnual: 1990,
    recommended: true,
    perks: _paidPerks,
  ),
  SubscriptionPlan(
    id: 'pro',
    scansPerDay: 20,
    rupeesMonthly: 249,
    rupeesAnnual: 2490,
    perks: _paidPerks,
  ),
];

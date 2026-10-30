import 'subscription_plan.dart';

/// Boundary for starting a subscription. Kept behind an interface so the real
/// billing backend (Dodo, via our API, after Google sign-in) can drop in later
/// without touching the screen. See agents.md §2 (provider abstraction).
abstract class SubscriptionService {
  /// Begin checkout for [plan] on [period].
  ///
  /// Must never pretend a purchase happened when it didn't (agents.md "no
  /// silent fake fallbacks", ADR-006). The stub below throws
  /// [SubscriptionUnavailable]; the real one will open the provider's checkout.
  Future<void> startCheckout(SubscriptionPlan plan, BillingPeriod period);
}

/// Thrown when billing isn't wired up yet. The screen turns it into an honest
/// "coming soon" message rather than a fake success.
class SubscriptionUnavailable implements Exception {
  const SubscriptionUnavailable();
}

/// The only implementation today: billing is not built. Payments wait on a
/// durable identity (Google sign-in, item 8), because a subscription tied to a
/// single profile's Keystore token would be lost with the phone and could not
/// cover family profiles (ADR-008).
class ComingSoonSubscriptionService implements SubscriptionService {
  const ComingSoonSubscriptionService();

  @override
  Future<void> startCheckout(SubscriptionPlan plan, BillingPeriod period) async {
    throw const SubscriptionUnavailable();
  }
}

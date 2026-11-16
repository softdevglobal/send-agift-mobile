import '../../../core/utils/money.dart';

/// SendAGift membership, the same packages the website sells: a price that
/// renews on its true interval, a percentage off gifts and the benefits the
/// package lists. The app never decides who can
/// join; it shows what the server says.

DateTime? _date(dynamic raw) =>
    raw is String && raw.isNotEmpty ? DateTime.tryParse(raw)?.toLocal() : null;

int _int(dynamic raw) => raw is num ? raw.toInt() : 0;

String? _text(dynamic raw) =>
    raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

/// 500 → "5%", 790 → "7.9%".
String formatBps(int bps) {
  final value = bps / 100;
  final text = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text%';
}

/// The server's answer to "can I do this here?", with what to do instead.
class MembershipDecision {
  const MembershipDecision({
    required this.allowed,
    required this.message,
    this.reasonCode,
    this.nextAction,
  });

  factory MembershipDecision.fromJson(Map<String, dynamic> json) =>
      MembershipDecision(
        allowed: json['allowed'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        reasonCode: _text(json['reason_code']),
        nextAction: _text(json['next_action']),
      );

  final bool allowed;
  final String message;
  final String? reasonCode;
  final String? nextAction;
}

/// One membership package on sale.
class PlanOffer {
  const PlanOffer({
    required this.id,
    this.tierCode = '',
    required this.name,
    required this.currency,
    required this.priceMinor,
    required this.billingLabel,
    required this.memberDiscountBps,
    required this.giftBenefits,
    required this.termsVersion,
    this.description,
    this.countryName,
  });

  factory PlanOffer.fromJson(Map<String, dynamic> json) {
    final benefits = json['gift_benefits'];
    return PlanOffer(
      id: json['id'] as String? ?? '',
      tierCode: json['tier_code'] as String? ?? '',
      name: json['name'] as String? ?? 'Membership',
      description: _text(json['description']),
      countryName: _text(json['country_name']),
      currency: json['currency'] as String? ?? 'USD',
      priceMinor: _int(json['price_minor']),
      billingLabel: json['billing_label'] as String? ?? '',
      memberDiscountBps: _int(json['member_discount_bps']),
      giftBenefits: benefits is List
          ? benefits.whereType<String>().toList(growable: false)
          : const [],
      termsVersion: json['terms_version'] as String? ?? '',
    );
  }

  final String id;

  /// The package; stays the same across its versions.
  final String tierCode;
  final String name;
  final String? description;
  final String? countryName;
  final String currency;
  final int priceMinor;

  /// The true interval: "every month", "every 28 days".
  final String billingLabel;
  final int memberDiscountBps;
  final List<String> giftBenefits;
  final String termsVersion;

  String get priceLabel => Money.format(priceMinor, currency);
}

/// What the membership page shows: whether joining is possible here, and the
/// packages on sale.
class MembershipOffers {
  const MembershipOffers({required this.decision, required this.offers});

  factory MembershipOffers.fromJson(Map<String, dynamic> json) {
    final raw = json['offers'];
    final decision = json['decision'];
    return MembershipOffers(
      decision: decision is Map<String, dynamic>
          ? MembershipDecision.fromJson(decision)
          : const MembershipDecision(allowed: false, message: ''),
      offers: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(PlanOffer.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final MembershipDecision decision;
  final List<PlanOffer> offers;
}

/// One period the customer has paid for.
class PaidPeriod {
  const PaidPeriod({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.amountMinor,
    required this.currency,
    required this.status,
  });

  factory PaidPeriod.fromJson(Map<String, dynamic> json) {
    return PaidPeriod(
      id: json['id'] as String? ?? '',
      periodStart: _date(json['period_start']) ?? DateTime.now(),
      periodEnd: _date(json['period_end']) ?? DateTime.now(),
      amountMinor: _int(json['amount_minor']),
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'paid',
    );
  }

  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int amountMinor;
  final String currency;

  /// paid, refunded, disputed or voided.
  final String status;

  String get amountLabel => Money.format(amountMinor, currency);
}

class MembershipSubscription {
  const MembershipSubscription({
    required this.status,
    required this.provider,
    required this.cancelAtPeriodEnd,
    this.currentPeriodEnd,
  });

  factory MembershipSubscription.fromJson(Map<String, dynamic> json) =>
      MembershipSubscription(
        status: json['status'] as String? ?? '',
        provider: json['provider'] as String? ?? 'stripe',
        cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
        currentPeriodEnd: _date(json['current_period_end']),
      );

  /// incomplete, active, past_due, cancelling, cancelled, expired, abandoned.
  final String status;

  /// stripe, or test in a sandbox.
  final String provider;
  final bool cancelAtPeriodEnd;
  final DateTime? currentPeriodEnd;

  /// Still running, but set to end at the period end: renewal can be turned
  /// back on.
  bool get canResume =>
      const {'active', 'cancelling'}.contains(status) && cancelAtPeriodEnd;

  /// A membership that is not over: another package can't be joined yet.
  bool get live =>
      const {'incomplete', 'active', 'past_due', 'cancelling'}.contains(status);

  bool get canCancel =>
      const {'active', 'past_due', 'incomplete'}.contains(status) &&
      !cancelAtPeriodEnd;
}

/// The customer's membership, as the server sees it now.
class MembershipStatus {
  const MembershipStatus({
    required this.state,
    required this.message,
    required this.periods,
    this.nextAction,
    this.subscription,
    this.offer,
    this.currentPeriod,
    this.nextChargeAt,
    this.nextChargeMinor,
  });

  factory MembershipStatus.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? map(String key) {
      final v = json[key];
      return v is Map<String, dynamic> ? v : null;
    }

    final periods = json['periods'];
    final sub = map('subscription');
    final offer = map('offer');
    final current = map('current_period');
    return MembershipStatus(
      state: json['state'] as String? ?? 'none',
      message: json['message'] as String? ?? '',
      nextAction: _text(json['next_action']),
      subscription: sub == null ? null : MembershipSubscription.fromJson(sub),
      offer: offer == null ? null : PlanOffer.fromJson(offer),
      currentPeriod: current == null ? null : PaidPeriod.fromJson(current),
      nextChargeAt: _date(json['next_charge_at']),
      nextChargeMinor: json['next_charge_minor'] is num
          ? (json['next_charge_minor'] as num).toInt()
          : null,
      periods: periods is List
          ? periods
                .whereType<Map<String, dynamic>>()
                .map(PaidPeriod.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  /// none, payment_pending, awaiting_gift, pending_completion,
  /// bonus_unlocked, bonus_reversed, past_due or not_currently_paid.
  final String state;
  final String message;
  final String? nextAction;
  final MembershipSubscription? subscription;
  final PlanOffer? offer;
  final PaidPeriod? currentPeriod;
  final DateTime? nextChargeAt;
  final int? nextChargeMinor;
  final List<PaidPeriod> periods;

  bool get isMember => currentPeriod != null;
  bool get paymentPending => state == 'payment_pending';
}

/// A started checkout: where to pay.
class MembershipCheckout {
  const MembershipCheckout({required this.checkoutUrl, required this.provider});

  factory MembershipCheckout.fromJson(Map<String, dynamic> json) =>
      MembershipCheckout(
        checkoutUrl: json['checkout_url'] as String? ?? '',
        provider: json['provider'] as String? ?? 'stripe',
      );

  final String checkoutUrl;
  final String provider;
}

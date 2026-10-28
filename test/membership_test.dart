import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/membership/data/membership_repository.dart';
import 'package:send_agift_mobile/features/membership/domain/membership.dart';

void main() {
  test('reads a paid membership as the server sends it', () {
    final s = MembershipStatus.fromJson({
      'state': 'bonus_unlocked',
      'message': 'Your member bonus of 1000 points is in your account.',
      'next_action': 'view_points',
      'subscription': {
        'status': 'active',
        'provider': 'stripe',
        'cancel_at_period_end': false,
        'current_period_end': '2026-11-27T09:48:31Z',
      },
      'offer': {
        'id': 'o1',
        'name': 'SendAgift Plus',
        'currency': 'LKR',
        'price_minor': 99900,
        'billing_label': 'every month',
        'member_bonus_points': 1000,
        'bonus_trigger': 'payment',
        'member_discount_bps': 500,
        'gift_benefits': ['Free delivery'],
        'terms_version': 'v1',
      },
      'current_period': {
        'id': 'p1',
        'period_start': '2026-10-27T09:48:31Z',
        'period_end': '2026-11-27T09:48:31Z',
        'amount_minor': 99900,
        'currency': 'LKR',
        'status': 'paid',
        'bonus_slot': {'bonus_points': 1000, 'status': 'awarded'},
      },
      'next_charge_at': '2026-11-27T09:48:31Z',
      'next_charge_minor': 99900,
      'periods': [],
    });
    expect(s.isMember, isTrue);
    expect(s.paymentPending, isFalse);
    expect(s.offer!.memberDiscountBps, 500);
    expect(s.offer!.giftBenefits, ['Free delivery']);
    expect(s.currentPeriod!.bonusSlot!.credited, isTrue);
    expect(s.subscription!.canCancel, isTrue);
    expect(s.nextChargeMinor, 99900);
  });

  test('a checkout not yet paid is not a membership', () {
    final s = MembershipStatus.fromJson({
      'state': 'payment_pending',
      'message': 'We are waiting for your payment to be confirmed.',
      'subscription': {'status': 'incomplete', 'provider': 'stripe'},
      'periods': [],
    });
    expect(s.isMember, isFalse);
    expect(s.paymentPending, isTrue);
  });

  test('member discount is worked out per line and rounded down', () {
    // 5% of 1999 is 99.95 and of 501 is 25.05: 99 + 25.
    expect(memberDiscountMinor([1999, 501], 500), 124);
    expect(memberDiscountMinor([1999], 0), 0);
  });

  test('basis points read as a percentage', () {
    expect(formatBps(500), '5%');
    expect(formatBps(790), '7.9%');
    expect(formatBps(1250), '12.5%');
  });
}

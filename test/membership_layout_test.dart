import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:send_agift_mobile/core/theme/app_theme.dart';
import 'package:send_agift_mobile/features/membership/data/membership_repository.dart';
import 'package:send_agift_mobile/features/membership/domain/membership.dart';
import 'package:send_agift_mobile/features/membership/presentation/screens/membership_screen.dart';
import 'package:send_agift_mobile/features/membership/presentation/screens/my_membership_screen.dart';

import 'support/fake_auth.dart';

const _offer = {
  'id': 'o1',
  'tier_code': 'plus',
  'name': 'SendAgift Plus',
  'description': 'SendAGift Plus for Sri Lanka',
  'country_name': 'Sri Lanka',
  'currency': 'LKR',
  'price_minor': 99900,
  'billing_label': 'every month',
  'member_bonus_points': 1000,
  'bonus_trigger': 'payment',
  'member_discount_bps': 500,
  'gift_benefits': ['Free delivery on birthday gifts'],
  'terms_version': 'v1',
};

final _offers = MembershipOffers.fromJson({
  'decision': {'allowed': true, 'message': ''},
  'offers': [
    _offer,
    {
      ..._offer,
      'id': 'o2',
      'tier_code': 'gold',
      'name': 'SendAgift Gold',
      'price_minor': 199900,
      'member_bonus_points': 2500,
      'member_discount_bps': 750,
    },
  ],
});

final _status = MembershipStatus.fromJson({
  'state': 'bonus_unlocked',
  'message':
      'Your member bonus of 1000 points for this period is in your '
      'account.',
  'next_action': 'view_points',
  'subscription': {
    'status': 'active',
    'provider': 'stripe',
    'cancel_at_period_end': false,
    'current_period_end': '2026-11-27T09:48:31Z',
  },
  'offer': _offer,
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
  'periods': [
    {
      'id': 'p1',
      'period_start': '2026-10-27T09:48:31Z',
      'period_end': '2026-11-27T09:48:31Z',
      'amount_minor': 99900,
      'currency': 'LKR',
      'status': 'paid',
      'bonus_slot': {'bonus_points': 1000, 'status': 'awarded'},
    },
  ],
});

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api/v1');
  });

  final screens = <(String, Widget Function())>[
    ('Membership offers', () => const MembershipScreen()),
    ('My membership', () => const MyMembershipScreen()),
  ];

  for (final (name, build) in screens) {
    testWidgets('$name lays out on small and large phones', (tester) async {
      // Already welcomed, so the popup does not cover the screen.
      SharedPreferences.setMockInitialValues({'membership-welcomed:p1': true});
      final problems = <String>[];
      final previous = FlutterError.onError;
      for (final size in const [Size(320, 568), Size(393, 852)]) {
        for (final scale in const [1.0, 1.4]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          FlutterError.onError = (details) {
            final text = details.exceptionAsString().split('\n').first;
            if (text.contains('overflow') ||
                text.contains('RenderFlex') ||
                text.contains('RenderBox') ||
                text.contains('constraints') ||
                text.contains('unbounded')) {
              final where = details
                  .toString()
                  .split('\n')
                  .where((l) => l.contains('membership') && l.contains('.dart'))
                  .take(1)
                  .join();
              problems.add('$name @ $size x$scale: $text $where');
            }
          };
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                fakeAuth(
                  customer: {
                    'id': 'c1',
                    'email': 'tester@example.com',
                    'display_name': 'Tester',
                  },
                ),
                membershipOffersProvider.overrideWith((ref) async => _offers),
                membershipStatusProvider.overrideWith((ref) async => _status),
              ],
              child: MaterialApp(theme: AppTheme.light, home: build()),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final shown = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
              .join(' | ');
          if (!shown.contains('SendAgift Plus') &&
              !shown.contains('SENDAGIFT PLUS')) {
            problems.add('$name @ $size x$scale: content missing: $shown');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }
      FlutterError.onError = previous;
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.reset();
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}

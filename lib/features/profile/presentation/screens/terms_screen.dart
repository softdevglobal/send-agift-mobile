import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import 'help_centre_screen.dart' show supportEmail;

/// When the text below last changed. Update it with every edit.
const _lastUpdated = '1 October 2026';

typedef _Section = (String heading, String body);

const _terms = <_Section>[
  (
    'Who we are',
    'SendAGift is a marketplace. Independent shops list gifts, set their '
        'prices and deliver them. SendAGift runs the app and website that '
        'connect you with those shops.',
  ),
  (
    'Your account',
    'You can browse, save gifts and fill a cart without an account. To '
        'place an order you need one. Keep your sign-in details private; you '
        'are responsible for what is done with your account.',
  ),
  (
    'Orders and prices',
    'An order is with the shop that sells the gift. Shops confirm each '
        'price when the order is created, so the order page shows the '
        'amount that applies. Delivery is priced by each shop from the '
        'distance to the address you choose.',
  ),
  (
    'Delivery',
    'Each shop delivers its own gifts and says how many days it needs. We '
        'pass on the arrival date you pick, but the shop is responsible for '
        'meeting it. Make sure the recipient\'s address and phone number are '
        'right.',
  ),
  (
    'Cancellations and refunds',
    'You can cancel an order from the app until the shop sends it out. '
        'Refunds after that are handled with the shop; message them from '
        'the order.',
  ),
  (
    'Points',
    'Points are a reward, not money. They cannot be exchanged for cash or '
        'transferred. Points earned on an order are paid when the gift is '
        'delivered and taken back if the order is cancelled or refunded. '
        'We may change how points are earned or spent.',
  ),
  (
    'Games and competitions',
    'Playing may cost points. Each competition shows its prize, rules and, '
        'for chance rounds, the odds. Scores made by cheating or automation '
        'are removed and may close the account.',
  ),
  (
    'Reviews and messages',
    'Reviews must be about a gift you received and be honest. Do not post '
        'anything unlawful, abusive or private about someone else. We may '
        'remove content that breaks these rules.',
  ),
  (
    'Changes',
    'We may update these terms. The date at the top shows the latest '
        'version; using SendAGift after a change means you accept it.',
  ),
];

const _privacy = <_Section>[
  (
    'What we collect',
    'Your name, email, phone and country when you register; the recipients '
        'and addresses you save; your orders, reviews, messages, points and '
        'game scores.',
  ),
  (
    'Why we use it',
    'To run your account, pass orders and delivery details to the shops '
        'that fulfil them, price delivery, pay and track points, and keep '
        'the service safe.',
  ),
  (
    'Who sees it',
    'A shop sees what it needs for your order: the gift, the recipient\'s '
        'name, address and phone, and your messages with it. Address search '
        'uses Google Maps. We do not sell your personal information.',
  ),
  (
    'Recipients',
    'When you save a recipient you share their details with us. Only add '
        'people who would expect to receive a gift from you.',
  ),
  (
    'On your device',
    'The app stores your sign-in, cart, saved gifts and last delivery '
        'search on your phone so they are there next time.',
  ),
  (
    'Your choices',
    'You can edit or delete recipients and addresses in the app at any '
        'time. To get a copy of your data or close your account, email '
        '$supportEmail.',
  ),
];

/// Terms of use and the privacy notice, one tab each.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Terms & privacy'),
          // The website's box tabs: a tinted track, the active tab inked.
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                4,
                AppTheme.gutter,
                8,
              ),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.boxTrack,
                  borderRadius: BorderRadius.circular(AppTheme.radiusBoxSm + 3),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'TERMS OF USE'),
                    Tab(text: 'PRIVACY'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _Document(title: 'Terms of use', sections: _terms),
              _Document(title: 'Privacy notice', sections: _privacy),
            ],
          ),
        ),
      ),
    );
  }
}

class _Document extends StatelessWidget {
  const _Document({required this.title, required this.sections});

  final String title;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        20,
        AppTheme.gutter,
        40,
      ),
      children: [
        Text(title, style: AppTypography.display(26)),
        const SizedBox(height: 6),
        Text('Last updated $_lastUpdated', style: theme.textTheme.bodySmall),
        const SizedBox(height: 18),
        for (var i = 0; i < sections.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 24,
                width: 24,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sections[i].$1, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      sections[i].$2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Questions? Email $supportEmail.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

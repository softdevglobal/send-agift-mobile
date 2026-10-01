import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/quantity_stepper.dart';

/// The same address the web footer lists.
const supportEmail = 'support@sendagift.com';

class _Topic {
  const _Topic(this.title, this.icon, this.color, this.questions);

  final String title;
  final IconData icon;
  final Color color;
  final List<(String, String)> questions;
}

/// Answers written from how the app actually behaves, so they stay true as
/// long as the rules they describe do.
const _topics = [
  _Topic('Orders', Icons.receipt_long_outlined, AppColors.primary, [
    (
      'Where can I see my orders?',
      'Account → My orders lists every order, newest first. Open one to see '
          'each gift\'s status, the delivery address and the date it should '
          'arrive.',
    ),
    (
      'Can I cancel an order?',
      'Yes, from the order page, until the shop sends it out — while it is '
          'awaiting payment, paid, accepted or being prepared. Once it is on '
          'its way it can no longer be cancelled.',
    ),
    (
      'Why might the final price differ from the cart?',
      'Shops confirm each line\'s price when the order is created, so the '
          'total on the order page is the one that counts.',
    ),
  ]),
  _Topic('Delivery', Icons.local_shipping_outlined, AppColors.teal, [
    (
      'Who delivers my gift?',
      'Each shop delivers its own gifts. A cart with gifts from two shops '
          'arrives as two deliveries, each priced by its own shop.',
    ),
    (
      'How is delivery priced?',
      'From the distance between the shop and the recipient\'s address. '
          'That is why an address has to be picked from the search list — '
          'it gives the exact spot on the map.',
    ),
    (
      'How do I choose when it arrives?',
      'Pick an arrival date at checkout. Every shop says how many days it '
          'needs, and checkout warns you when a date is too soon.',
    ),
    (
      'Can I search for gifts that reach a certain place?',
      'Yes. Enter where it is going and when on Home or All gifts, and only '
          'gifts that can get there are shown. Checkout then fills in that '
          'address for you.',
    ),
  ]),
  _Topic('Points', Icons.stars_rounded, AppColors.purple, [
    (
      'How do I earn points?',
      'Gifts that show "Earn points" pay them to you, the buyer, once that '
          'gift is delivered. You can see them coming on the order page.',
    ),
    (
      'What happens to points if an order is cancelled or refunded?',
      'Points that were not paid yet are never paid. Points already paid '
          'are taken back — a cancellation is refused if you have already '
          'spent them.',
    ),
    (
      'Where do I see my balance?',
      'Account → My points shows your balance and every point in and out.',
    ),
    (
      'What can I spend points on?',
      'Playing games and entering competitions for prizes.',
    ),
  ]),
  _Topic('Games & competitions', Icons.emoji_events_outlined, AppColors.star, [
    (
      'How do competitions work?',
      'Each round has a prize, a game and a points cost to play. Your best '
          'score counts on the leaderboard; chance rounds show their odds '
          'before you play.',
    ),
    (
      'Can I practise?',
      'Yes. Every game can be played outside a competition, with its own '
          'leaderboard. Some games cost points per play. Practice never '
          'counts towards a prize.',
    ),
  ]),
  _Topic('Account', Icons.person_outline_rounded, AppColors.accentForeground, [
    (
      'Do I need an account to shop?',
      'No. You can search, save gifts and fill a cart as a guest. You only '
          'sign in to check out, track orders and earn points.',
    ),
    (
      'How do I manage recipients?',
      'Account → Recipients. Add people with their address, change their '
          'details, give them more than one address and choose their '
          'default.',
    ),
    (
      'How do I review a gift?',
      'Once a gift is delivered, open the order and leave a rating. Your '
          'reviews are all under Account → My reviews.',
    ),
  ]),
];

/// Searchable answers grouped by topic, with ways to reach a person.
class HelpCentreScreen extends StatefulWidget {
  const HelpCentreScreen({super.key});

  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends State<HelpCentreScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _topic;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'Help with SendAGift'},
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email us at $supportEmail')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final topic in _topics)
        if (_topic == null || _topic == topic.title)
          (
            topic,
            topic.questions
                .where(
                  (item) =>
                      q.isEmpty ||
                      item.$1.toLowerCase().contains(q) ||
                      item.$2.toLowerCase().contains(q),
                )
                .toList(),
          ),
    ].where((entry) => entry.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Help centre')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            8,
            AppTheme.gutter,
            40,
          ),
          children: [
            Text('How can we help?', style: AppTypography.display(26)),
            const SizedBox(height: 14),
            TextField(
              key: const Key('help-search'),
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search orders, delivery, points…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('All', null),
                  for (final topic in _topics) _chip(topic.title, topic.title),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (visible.isEmpty)
              AppPanel(
                child: Text(
                  'Nothing matches "$_query". Try another word, or contact '
                  'us below.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final (topic, questions) in visible) ...[
              Row(
                children: [
                  Container(
                    height: 30,
                    width: 30,
                    decoration: BoxDecoration(
                      color: topic.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(topic.icon, size: 17, color: topic.color),
                  ),
                  const SizedBox(width: 10),
                  Text(topic.title, style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < questions.length; i++) ...[
                      Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: q.isNotEmpty,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          expandedAlignment: Alignment.centerLeft,
                          iconColor: AppColors.purple,
                          title: Text(
                            questions[i].$1,
                            style: theme.textTheme.titleSmall,
                          ),
                          children: [
                            Text(
                              questions[i].$2,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (i != questions.length - 1)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            Text('STILL NEED HELP?', style: AppTypography.eyebrow),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.teal,
              title: 'Message the shop',
              subtitle:
                  'Questions about a gift or an order go fastest to '
                  'the shop itself.',
              onTap: () => context.push(AppRoutes.messages),
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.mail_outline_rounded,
              color: AppColors.purple,
              title: 'Email SendAGift',
              subtitle: supportEmail,
              onTap: _email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _topic == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _topic = value),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

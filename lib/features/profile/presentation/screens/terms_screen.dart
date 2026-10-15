import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import 'help_centre_screen.dart' show supportEmail;

/// One policy. The full text lives on the website, at `/legal/<slug>`, so the
/// app and the site always show the same wording.
class PolicyLink {
  const PolicyLink({
    required this.slug,
    required this.docId,
    required this.title,
    required this.summary,
    this.forSellers = false,
  });

  final String slug;
  final String docId;
  final String title;
  final String summary;
  final bool forSellers;

  Uri get url => Uri.parse('${AppConfig.webBaseUrl}/legal/$slug');
}

/// The same policies, in the same order, as the website's Legal page.
const policyLinks = <PolicyLink>[
  PolicyLink(
    slug: 'privacy',
    docId: 'PRIV-01',
    title: 'Privacy Policy',
    summary:
        'What personal information we collect, why, who receives it and your '
        'choices.',
  ),
  PolicyLink(
    slug: 'customer-terms',
    docId: 'CUST-01',
    title: 'Marketplace Customer Terms',
    summary:
        'The terms for browsing, ordering, sending and receiving gifts on '
        'SendAGift.',
  ),
  PolicyLink(
    slug: 'delivery',
    docId: 'DEL-01',
    title: 'Delivery Policy',
    summary:
        'Preparation and delivery estimates, delivery charges, tracking and '
        'late or lost parcels.',
  ),
  PolicyLink(
    slug: 'returns',
    docId: 'REF-01',
    title: 'Returns, Refunds and Cancellations',
    summary:
        'How to cancel an order, report a problem, return an item and get a '
        'refund.',
  ),
  PolicyLink(
    slug: 'free-gift-terms',
    docId: 'GIFT-01',
    title: 'Free Gift Promotion Terms',
    summary:
        'Who can send and receive a free gift, what it costs, and how '
        'cancellations work.',
  ),
  PolicyLink(
    slug: 'prohibited-products',
    docId: 'SAFE-01',
    title: 'Prohibited Products and Reporting',
    summary: 'What may not be listed, and how to report a product or seller.',
  ),
  PolicyLink(
    slug: 'complaints',
    docId: 'HELP-01',
    title: 'Complaints and Support Procedure',
    summary: 'How to contact us, what happens next and how to escalate.',
  ),
  PolicyLink(
    slug: 'seller-agreement',
    docId: 'SELL-01',
    title: 'Seller Agreement',
    summary: 'What sellers agree to when they list on SendAGift.',
    forSellers: true,
  ),
  PolicyLink(
    slug: 'seller-budget',
    docId: 'BUDGET-01',
    title: 'Seller Marketing Budget Acceptance',
    summary: 'The authorization for a seller-funded free-gift budget.',
    forSellers: true,
  ),
];

/// Policies and terms. Each opens its page from the website inside the app.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  Future<void> _open(BuildContext context, PolicyLink policy) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = await launchUrl(policy.url, mode: LaunchMode.inAppBrowserView);
    // Some devices have no in-app browser; the regular browser still works.
    if (!opened) opened = await launchUrl(policy.url);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open ${policy.title}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = policyLinks.where((p) => !p.forSellers).toList();
    final seller = policyLinks.where((p) => p.forSellers).toList();

    Widget group(String label, List<PolicyLink> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.mutedForeground,
              letterSpacing: 1.4,
            ),
          ),
        ),
        for (final policy in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: InkWell(
                key: Key('policy-${policy.slug}'),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                onTap: () => _open(context, policy),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 20,
                          color: AppColors.tealForeground,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              policy.title,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              policy.summary,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Policies & terms')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            12,
            AppTheme.gutter,
            32,
          ),
          children: [
            Text('Policies and terms', style: AppTypography.display(26)),
            const SizedBox(height: 6),
            Text(
              'How SendAGift handles your information, orders, deliveries, '
              'refunds, free gifts and complaints.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            group('For customers', customer),
            const SizedBox(height: 14),
            group('For sellers', seller),
            const SizedBox(height: 8),
            Text(
              'Questions? Email $supportEmail.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

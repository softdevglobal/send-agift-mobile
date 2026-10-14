import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/checkout.dart';

/// Why a shop cannot deliver, in words a shopper understands.
class DeliveryProblemCopy {
  const DeliveryProblemCopy({
    required this.title,
    required this.body,
    required this.kind,
  });

  final String title;
  final String body;

  /// distance, address or shop: decides which fixes are offered.
  final String kind;

  /// The same wording as the web checkout. Codes come from the API; older
  /// answers fall back to the distances, then to the API's own reason.
  factory DeliveryProblemCopy.of(ShopDeliveryCheck shop) {
    final name = shop.shopName.trim().isEmpty
        ? 'This shop'
        : shop.shopName.trim();
    final code = shop.reasonCode;
    final far = shop.distanceKm;
    final limit = shop.farthestKm;
    if (code == 'OUTSIDE_ZONE' ||
        (code == null && far != null && limit != null)) {
      return DeliveryProblemCopy(
        kind: 'distance',
        title: '$name doesn’t deliver this far',
        body: far != null && limit != null
            ? 'This address is ${_km(far)} km from the shop. $name delivers up '
                  'to ${_km(limit)} km away.'
            : 'This address is outside the area $name delivers to.',
      );
    }
    if (code == 'ADDRESS_NO_LOCATION') {
      return const DeliveryProblemCopy(
        kind: 'address',
        title: 'This address isn’t on the map',
        body:
            'Shops price delivery by distance, and this address has no map '
            'pin. Edit the recipient and pick their address from the search so '
            'it can be measured.',
      );
    }
    if (code == 'NO_ZONES' || code == 'SHOP_NO_LOCATION') {
      return DeliveryProblemCopy(
        kind: 'shop',
        title: '$name isn’t delivering yet',
        body:
            '$name hasn’t finished setting up delivery, so it can’t take '
            'orders right now. Message the shop, or choose a gift from another '
            'shop.',
      );
    }
    final reason = shop.reason?.trim() ?? '';
    return DeliveryProblemCopy(
      kind: 'shop',
      title: '$name can’t deliver to this address',
      body: reason.isEmpty
          ? 'Try another recipient, or a gift from another shop.'
          : '${reason.replaceAll(RegExp(r'\.$'), '')}.',
    );
  }

  static String _km(double value) {
    if (value < 10) {
      final rounded = (value * 10).round() / 10;
      return rounded == rounded.roundToDouble()
          ? rounded.toStringAsFixed(0)
          : rounded.toStringAsFixed(1);
    }
    final digits = value.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// One shop that cannot deliver to the chosen address: what is wrong and the
/// buttons that fix it.
class DeliveryProblemCard extends StatelessWidget {
  const DeliveryProblemCard({
    super.key,
    required this.shop,
    this.onChangeRecipient,
    this.onEditAddress,
    this.onRemoveShopGifts,
    this.giftCount = 1,
  });

  final ShopDeliveryCheck shop;
  final VoidCallback? onChangeRecipient;
  final VoidCallback? onEditAddress;
  final VoidCallback? onRemoveShopGifts;

  /// How many of the cart's gifts come from this shop.
  final int giftCount;

  @override
  Widget build(BuildContext context) {
    final copy = DeliveryProblemCopy.of(shop);
    final theme = Theme.of(context);
    const ink = Color(0xFF451A03);

    Widget action(IconData icon, String label, VoidCallback onTap, Key key) {
      return OutlinedButton.icon(
        key: key,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: Color(0xFFFCD34D)),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }

    final shopName = shop.shopName.trim().isEmpty ? 'this shop' : shop.shopName;

    return Container(
      key: Key('delivery-problem-${shop.shopId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  copy.kind == 'shop'
                      ? Icons.storefront_rounded
                      : Icons.location_off_rounded,
                  size: 18,
                  color: ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.title,
                      style: theme.textTheme.titleSmall?.copyWith(color: ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      copy.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ink.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (copy.kind == 'address' && onEditAddress != null)
                action(
                  Icons.edit_location_alt_outlined,
                  'Edit address',
                  onEditAddress!,
                  const Key('delivery-problem-edit-address'),
                ),
              if (copy.kind != 'shop' && onChangeRecipient != null)
                action(
                  Icons.people_alt_outlined,
                  'Send to someone else',
                  onChangeRecipient!,
                  const Key('delivery-problem-change-recipient'),
                ),
              if (onRemoveShopGifts != null)
                action(
                  Icons.delete_outline_rounded,
                  giftCount > 1
                      ? 'Remove $giftCount gifts from $shopName'
                      : 'Remove this shop’s gift',
                  onRemoveShopGifts!,
                  const Key('delivery-problem-remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

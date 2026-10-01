import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/product_review.dart';
import 'star_rating.dart';

final _dateFormat = DateFormat.yMMMd();

/// One review: who wrote it, what they scored, their photos, and the seller's
/// reply underneath when there is one.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.onVote,
    this.onEdit,
    this.onDelete,
    this.header,
  });

  final ProductReview review;

  /// Tapping "Helpful". Omit for signed-out viewers — the count still shows,
  /// but the button would only earn a 401.
  final ValueChanged<ProductReview>? onVote;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Rendered above the review, e.g. which gift it is about.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = review.body?.trim();
    final title = review.title?.trim();
    final reply = review.sellerReply?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 12)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(review: review),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.authorName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Every review here came from a delivered order line;
                        // the API will not create one any other way.
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppColors.accentForeground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StarMeter(value: review.rating.toDouble(), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          _dateFormat.format(review.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
          ],
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
                height: 1.45,
              ),
            ),
          ],
          _SubScores(review: review),
          if (review.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MediaStrip(media: review.media),
          ],
          if (reply != null && reply.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SellerReply(review: review, reply: reply),
          ],
          const SizedBox(height: 12),
          // One line when it fits; on a narrow phone or with large text the
          // edit and delete buttons drop below instead of overflowing.
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              _HelpfulButton(review: review, onVote: onVote),
              if (onEdit != null || onDelete != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      TextButton(onPressed: onEdit, child: const Text('Edit')),
                    if (onDelete != null)
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.destructive,
                        ),
                        child: const Text('Delete'),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final image = review.isAnonymous ? null : review.author?.imageUrl?.trim();
    if (image != null && image.isNotEmpty) {
      return ClipOval(
        child: AppNetworkImage(url: image, width: 36, height: 36),
      );
    }
    final name = review.authorName;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cream,
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.purple,
        ),
      ),
    );
  }
}

/// The three sub-scores, shown only when they were actually given.
class _SubScores extends StatelessWidget {
  const _SubScores({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int)>[
      ('Quality', review.productQualityRating),
      ('Delivery', review.shippingRating),
      ('Service', review.sellerServiceRating),
    ].where((row) => row.$2 > 0).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final row in rows)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.$1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 5),
                StarMeter(value: row.$2.toDouble(), size: 11),
              ],
            ),
        ],
      ),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({required this.media});

  final List<ReviewMedia> media;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = media[index];
          final url = item.cdnUrl?.trim();
          if (url == null || url.isEmpty) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _openViewer(context, url, item.isVideo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  AppNetworkImage(url: url, width: 76, height: 76),
                  if (item.isVideo)
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      color: Colors.black26,
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Photos open full-bleed on black; a video still opens as its poster frame
  /// rather than pulling a player into a review list.
  void _openViewer(BuildContext context, String url, bool isVideo) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: AppNetworkImage(url: url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 48,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerReply extends StatelessWidget {
  const _SellerReply({required this.review, required this.reply});

  final ProductReview review;
  final String reply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: const Border(
          left: BorderSide(color: AppColors.purple, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 14,
                color: AppColors.purple,
              ),
              const SizedBox(width: 6),
              Text('Seller replied', style: theme.textTheme.labelLarge),
              if (review.sellerRepliedAt != null) ...[
                const SizedBox(width: 6),
                Text(
                  _dateFormat.format(review.sellerRepliedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reply,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpfulButton extends StatelessWidget {
  const _HelpfulButton({required this.review, required this.onVote});

  final ProductReview review;
  final ValueChanged<ProductReview>? onVote;

  @override
  Widget build(BuildContext context) {
    final voted = review.hasVoted;
    final label = review.helpfulCount > 0
        ? 'Helpful (${review.helpfulCount})'
        : 'Helpful';
    return TextButton.icon(
      onPressed: onVote == null ? null : () => onVote!(review),
      icon: Icon(
        voted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
        size: 16,
      ),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: voted ? AppColors.purple : AppColors.mutedForeground,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }
}

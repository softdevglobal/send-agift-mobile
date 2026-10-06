import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';

/// Customer quotes, carried over from the web home page.
class TestimonialCarousel extends StatelessWidget {
  const TestimonialCarousel({super.key});

  static const _testimonials =
      <({String name, String quote, String avatar})>[
    (
      name: 'Amelia R.',
      quote:
          'I sent a birthday hamper across cities and tracked every step. It '
              'felt personal, not like another marketplace order.',
      avatar:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=160&q=80',
    ),
    (
      name: 'Jordan K.',
      quote:
          'Country-ready gift filters saved me. The points balance and '
              'competition entry made the whole experience fun.',
      avatar:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=160&q=80',
    ),
    (
      name: 'Priya S.',
      quote:
          'Beautiful packaging, clear delivery updates, and support that '
              'actually resolved a date change quickly.',
      avatar:
          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=160&q=80',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.88),
        padEnds: false,
        itemCount: _testimonials.length,
        itemBuilder: (context, index) {
          final testimonial = _testimonials[index];
          // Solid tones cycle so the row reads as a set; the middle is ink.
          final onDark = index % 3 == 1;
          final fill = const [
            AppColors.cream,
            AppColors.foreground,
            AppColors.accent,
          ][index % 3];
          final ink = onDark ? Colors.white : AppColors.foreground;
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? AppTheme.gutter : 0,
              right: 12,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(
                            5,
                            (i) => const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: AppColors.star,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 26,
                        width: 26,
                        decoration: BoxDecoration(
                          color: onDark ? AppColors.teal : AppColors.purple,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.format_quote_rounded,
                          size: 14,
                          color: onDark ? AppColors.foreground : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      '“${testimonial.quote}”',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          height: 32,
                          width: 32,
                          child: AppNetworkImage(url: testimonial.avatar),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        testimonial.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: ink, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

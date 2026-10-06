import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/storefront_decor.dart';
import '../../../auth/data/auth_controller.dart';

/// One slide of the hero: a promise, a photo, and where tapping goes.
class _Slide {
  const _Slide({
    required this.eyebrow,
    required this.lead,
    required this.marker,
    required this.tail,
    required this.cta,
    required this.icon,
    required this.image,
    required this.background,
    required this.foreground,
    required this.markerColor,
    required this.markerText,
    required this.route,
    this.push = false,
  });

  final String eyebrow;

  /// Headline in three parts: the middle one sits on a marker block.
  final String lead;
  final String marker;
  final String tail;
  final String cta;
  final IconData icon;
  final String image;

  /// Every slide is one flat brand colour.
  final Color background;
  final Color foreground;
  final Color markerColor;
  final Color markerText;
  final String route;

  /// Pushed over the tabs rather than switching tab.
  final bool push;

  /// Guests are sent to sign in first.
  bool get needsAccount => route == AppRoutes.points;
}

const _slides = [
  _Slide(
    eyebrow: 'From moments to memories',
    lead: "LET'S SEND",
    marker: 'UNFORGETTABLE',
    tail: 'GIFTS.',
    cta: 'Shop now',
    icon: Icons.card_giftcard_rounded,
    image:
        'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?auto=format&fit=crop&w=600&q=80',
    background: AppColors.purple,
    foreground: Colors.white,
    markerColor: Colors.white,
    markerText: AppColors.foreground,
    route: AppRoutes.explore,
  ),
  _Slide(
    eyebrow: 'Earn as you gift',
    lead: 'EVERY GIFT',
    marker: 'PAYS YOU',
    tail: 'BACK.',
    cta: 'See my points',
    icon: Icons.stars_rounded,
    image:
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&w=600&q=80',
    background: AppColors.teal,
    foreground: AppColors.foreground,
    markerColor: AppColors.foreground,
    markerText: Colors.white,
    route: AppRoutes.points,
    push: true,
  ),
  _Slide(
    eyebrow: 'Play a game',
    lead: 'TAKE A',
    marker: 'QUICK',
    tail: 'GAME BREAK.',
    cta: 'Play now',
    icon: Icons.emoji_events_rounded,
    image:
        'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=600&q=80',
    background: AppColors.foreground,
    foreground: Colors.white,
    markerColor: AppColors.teal,
    markerText: AppColors.foreground,
    route: AppRoutes.games,
    push: true,
  ),
];

/// A swipeable carousel of the app's three promises. Gifts, points and
/// games. That moves on by itself every few seconds.
///
/// The games slide stays about skill, like the games teaser: no prizes or
/// "chance to win" in the storefront's own wording.
class HomeHero extends ConsumerStatefulWidget {
  const HomeHero({super.key});

  @override
  ConsumerState<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends ConsumerState<HomeHero> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _page = 0;

  static const _interval = Duration(seconds: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  /// Starts (or restarts) the auto-advance, so a swipe gets a full interval
  /// before the carousel moves again. Off when the phone asks for less
  /// motion.
  void _restart() {
    _timer?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _slides.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open(_Slide slide) {
    if (slide.needsAccount && !ref.read(authProvider).isSignedIn) {
      context.push(AppRoutes.login);
    } else if (slide.push) {
      context.push(slide.route);
    } else {
      context.go(slide.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          SizedBox(
            height: 236,
            child: NotificationListener<ScrollStartNotification>(
              // A finger on the carousel resets the clock.
              onNotification: (notification) {
                if (notification.dragDetails != null) _restart();
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                itemCount: _slides.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? AppTheme.gutter : 6,
                    right: index == _slides.length - 1 ? AppTheme.gutter : 6,
                  ),
                  child: _SlideCard(
                    slide: _slides[index],
                    onTap: () => _open(_slides[index]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: i == _page ? 22 : 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: i == _page ? AppColors.foreground : AppColors.mist,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide, required this.onTap});

  final _Slide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final headline = AppTypography.poster(27, color: slide.foreground);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        child: ColoredBox(
          color: slide.background,
          child: Stack(
            children: [
              Positioned(
                right: 122,
                bottom: 22,
                child: Sparkle(size: 16, color: slide.markerColor),
              ),
              Positioned(
                right: 12,
                bottom: 14,
                child: Sparkle(size: 22, color: slide.markerColor),
              ),
              // A tilted photo, like a print tucked into the card.
              Positioned(
                right: 16,
                top: 24,
                bottom: 40,
                child: Transform.rotate(
                  angle: 6 * math.pi / 180,
                  child: Container(
                    width: 98,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AppNetworkImage(url: slide.image),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 128, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.eyebrow.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tag(
                        color: slide.foreground.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(slide.lead, style: headline),
                            const SizedBox(height: 2),
                            Marker(
                              slide.marker,
                              style: headline,
                              color: slide.markerColor,
                              textColor: slide.markerText,
                            ),
                            const SizedBox(height: 2),
                            Text(slide.tail, style: headline),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: slide.markerColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusButton),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              slide.cta.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.tag(
                                size: 11,
                                color: slide.markerText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: slide.markerText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

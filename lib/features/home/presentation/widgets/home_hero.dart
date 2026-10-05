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
import '../../../auth/data/auth_controller.dart';

/// One slide of the hero: a promise, a photo, and where tapping goes.
class _Slide {
  const _Slide({
    required this.eyebrow,
    required this.title,
    required this.cta,
    required this.icon,
    required this.image,
    required this.colors,
    required this.route,
    this.push = false,
  });

  final String eyebrow;
  final String title;
  final String cta;
  final IconData icon;
  final String image;
  final List<Color> colors;
  final String route;

  /// Pushed over the tabs rather than switching tab.
  final bool push;

  /// Guests are sent to sign in first.
  bool get needsAccount => route == AppRoutes.points;
}

const _slides = [
  _Slide(
    eyebrow: 'FROM MOMENTS TO MEMORIES',
    title: 'The right gift, on the right day.',
    cta: 'Browse gifts',
    icon: Icons.card_giftcard_rounded,
    image:
        'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?auto=format&fit=crop&w=600&q=80',
    colors: AppColors.brandGradient,
    route: AppRoutes.explore,
  ),
  _Slide(
    eyebrow: 'EARN AS YOU GIFT',
    title: 'Every gift pays you back in points.',
    cta: 'See my points',
    icon: Icons.stars_rounded,
    image:
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&w=600&q=80',
    colors: [Color(0xFF6D28D9), Color(0xFF0EA5A4)],
    route: AppRoutes.points,
    push: true,
  ),
  _Slide(
    eyebrow: 'PLAY A GAME',
    title: 'Take a break with a quick game of skill.',
    cta: 'Play now',
    icon: Icons.emoji_events_rounded,
    image:
        'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=600&q=80',
    colors: [Color(0xFF0B6E68), Color(0xFF16225A)],
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
            height: 212,
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
                    color: i == _page ? AppColors.purple : AppColors.mist,
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
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: slide.colors,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -60,
                child: _Ring(size: 190, alpha: 0.10),
              ),
              Positioned(
                left: -40,
                bottom: -80,
                child: _Ring(size: 160, alpha: 0.07),
              ),
              // A tilted photo, like a print tucked into the card.
              Positioned(
                right: 14,
                top: 22,
                bottom: 22,
                child: Transform.rotate(
                  angle: 6 * math.pi / 180,
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppNetworkImage(url: slide.image),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 96,
                bottom: 18,
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x26000000), blurRadius: 10),
                    ],
                  ),
                  child: Icon(slide.icon, size: 20, color: slide.colors.last),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 140, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.eyebrow.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        slide.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(22, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              slide.cta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.primary,
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

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

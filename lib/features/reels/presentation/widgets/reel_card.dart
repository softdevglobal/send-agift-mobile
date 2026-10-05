import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../auth/data/auth_controller.dart';
import '../../../saved/data/saved_controller.dart';
import '../../data/reels_providers.dart';
import '../../domain/reel.dart';
import 'reel_comments_sheet.dart';
import 'reel_video.dart';

/// A single full-bleed reel: the seller's clip, who posted it, and the way
/// through to the gift it is showing.
class ReelCard extends ConsumerStatefulWidget {
  const ReelCard({
    super.key,
    required this.reel,
    required this.isActive,
    required this.onCompleted,
  });

  final Reel reel;

  /// True only for the reel filling the screen. Everything else is paused so
  /// off-screen pages are neither playing nor decoding.
  final bool isActive;

  /// Fired when the clip runs out, so the feed can advance.
  final VoidCallback onCompleted;

  @override
  ConsumerState<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends ConsumerState<ReelCard>
    with SingleTickerProviderStateMixin {
  /// How long a photo reel holds before the feed moves on. Video reels run for
  /// their own length instead.
  static const Duration _photoDuration = Duration(seconds: 7);

  late final AnimationController _photoTimer;
  double _videoProgress = 0;
  bool _paused = false;

  bool get _isVideo => widget.reel.hasVideo;
  bool get _playing => widget.isActive && !_paused;

  @override
  void initState() {
    super.initState();
    _photoTimer = AnimationController(vsync: this, duration: _photoDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onCompleted();
      });
    if (widget.isActive && !_isVideo) _photoTimer.forward();
  }

  @override
  void didUpdateWidget(covariant ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;

    if (widget.isActive) {
      // Coming back to a reel restarts it rather than resuming a clip the
      // viewer already half-watched.
      _paused = false;
      _videoProgress = 0;
      if (!_isVideo) _photoTimer.forward(from: 0);
    } else {
      _photoTimer.stop();
      _photoTimer.value = 0;
    }
  }

  @override
  void dispose() {
    _photoTimer.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() => _paused = !_paused);
    if (_isVideo) return;
    if (_paused) {
      _photoTimer.stop();
    } else {
      _photoTimer.forward();
    }
  }

  void _openGift(ReelProduct product) {
    context.push(AppRoutes.giftDetailPath(product.id));
  }

  /// Anyone can see the count; only a signed-in customer can add to it.
  Future<void> _toggleLike() async {
    if (!ref.read(authProvider).isSignedIn) {
      _promptSignIn('Sign in to like reels.');
      return;
    }
    HapticFeedback.lightImpact();
    try {
      await ref.read(reelFeedProvider.notifier).toggleLike(widget.reel.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _openComments() => showReelComments(context, widget.reel.id);

  void _promptSignIn(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Sign in',
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final product = reel.product;
    final saved = product != null &&
        ref.watch(savedGiftsProvider).contains(product.id);

    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideo)
            ReelVideo(
              url: reel.videoUrl!,
              posterUrl: reel.imageUrl,
              playing: _playing,
              onProgress: (value) {
                if (mounted) setState(() => _videoProgress = value);
              },
              onCompleted: widget.onCompleted,
            )
          else if (reel.photoUrls.isNotEmpty)
            _PhotoReel(urls: reel.photoUrls, progress: _photoTimer)
          else if (reel.imageUrl != null)
            _PhotoReel(urls: [reel.imageUrl!], progress: _photoTimer)
          else
            const ColoredBox(color: Colors.black),
          // Scrims top and bottom: the clip keeps its colour in the middle,
          // and the text on either end stays readable whatever it sits on.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.28, 0.55, 1],
                colors: [
                  Color(0x8C000000),
                  Color(0x1A000000),
                  Color(0x59000000),
                  Color(0xD9000000),
                ],
              ),
            ),
          ),
          _ProgressBar(
            value: _isVideo ? _videoProgress : null,
            photoTimer: _photoTimer,
          ),
          if (_paused) const _PausedGlyph(),
          Positioned(
            right: 12,
            bottom: 40,
            child: _ActionRail(
              liked: reel.likedByMe,
              likeCount: reel.likeCount,
              commentCount: reel.commentCount,
              onLike: _toggleLike,
              onComments: _openComments,
              saved: saved,
              canSave: product != null,
              viewCount: reel.viewCount,
              onSave: product == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      final nowSaved = ref
                          .read(savedGiftsProvider.notifier)
                          .toggle(product.id);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              nowSaved
                                  ? 'Saved to your list'
                                  : 'Removed from saved',
                            ),
                            duration: const Duration(milliseconds: 1400),
                          ),
                        );
                    },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ReelDetails(
              reel: reel,
              onSendGift: _openGift,
              onOpenComments: _openComments,
            ),
          ),
        ],
      ),
    );
  }
}

/// A photo reel: the still drifts slowly so it reads as footage rather than a
/// picture someone forgot to animate. A carousel. The API allows up to ten
/// images on one post. Is swiped sideways, with dots showing where you are.
class _PhotoReel extends StatefulWidget {
  const _PhotoReel({required this.urls, required this.progress});

  final List<String> urls;
  final Animation<double> progress;

  @override
  State<_PhotoReel> createState() => _PhotoReelState();
}

class _PhotoReelState extends State<_PhotoReel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: widget.progress,
          builder: (context, child) => Transform.scale(
            scale: 1.06 + (0.08 * widget.progress.value),
            child: child,
          ),
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) =>
                AppNetworkImage(url: widget.urls[index]),
          ),
        ),
        if (widget.urls.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.urls.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: i == _index ? 18 : 6,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thin clip timeline under the status bar. A video drives it by position; a
/// photo reel drives it by its hold timer.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.photoTimer});

  final double? value;
  final Animation<double> photoTimer;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: AnimatedBuilder(
          animation: photoTimer,
          builder: (context, _) => LinearProgressIndicator(
            value: value ?? photoTimer.value,
            minHeight: 2.5,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Play glyph shown while a reel is held, so tap-to-pause is unmistakable.
class _PausedGlyph extends StatelessWidget {
  const _PausedGlyph();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

/// Right-hand action column: like the clip, open its comments, save the gift,
/// see the view count.
class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.onComments,
    required this.saved,
    required this.canSave,
    required this.viewCount,
    required this.onSave,
  });

  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final bool saved;
  final bool canSave;
  final int viewCount;
  final VoidCallback? onSave;

  static const Color _likedRed = Color(0xFFFF3B5C);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RailButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: liked ? _likedRed : Colors.white,
          label: likeCount > 0 ? compactCount(likeCount) : 'Like',
          semanticLabel:
              '${liked ? 'Unlike' : 'Like'}, $likeCount ${likeCount == 1 ? 'like' : 'likes'}',
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _RailButton(
          icon: Icons.mode_comment_outlined,
          color: Colors.white,
          label: commentCount > 0 ? compactCount(commentCount) : 'Comment',
          semanticLabel:
              'Comments, $commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
          onTap: onComments,
        ),
        if (canSave && onSave != null) ...[
          const SizedBox(height: 18),
          _RailButton(
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: saved ? AppColors.teal : Colors.white,
            label: saved ? 'Saved' : 'Save',
            onTap: onSave!,
          ),
        ],
        if (viewCount > 0) ...[
          const SizedBox(height: 18),
          Column(
            children: [
              const Icon(
                Icons.visibility_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                compactCount(viewCount),
                style: const TextStyle(
                  fontFamily: AppTypography.sansFamily,
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  /// For when the visible label is only a count.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: PressableScale(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(icon, key: ValueKey(icon), color: color, size: 30),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.sansFamily,
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything the viewer needs to act on the clip: who posted it, what it
/// says, and. When a product is tagged. The price and the way to send it.
class _ReelDetails extends StatelessWidget {
  const _ReelDetails({
    required this.reel,
    required this.onSendGift,
    required this.onOpenComments,
  });

  final Reel reel;
  final ValueChanged<ReelProduct> onSendGift;
  final VoidCallback onOpenComments;

  @override
  Widget build(BuildContext context) {
    final product = reel.product;
    final caption = reel.caption;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 84, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: Colors.white54, width: 1.5),
                ),
                child: reel.shopImageUrl != null
                    ? AppNetworkImage(url: reel.shopImageUrl!)
                    : const Icon(
                        Icons.storefront_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  reel.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (product != null) ...[
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.display(24, color: Colors.white),
            ),
          ],
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.sansFamily,
                color: Colors.white70,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          if (reel.hashtags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reel.hashtagLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.sansFamily,
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (reel.likersLine case final likers?) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: Color(0xFFFF7A90),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    likers,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.sansFamily,
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (reel.commentCount > 0) ...[
            const SizedBox(height: 4),
            // Its own tap target, so it opens the comments rather than
            // pausing the clip underneath.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenComments,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  reel.commentCount == 1
                      ? 'View 1 comment'
                      : 'View all ${compactCount(reel.commentCount)} comments',
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (product != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  product.priceLabel,
                  style: const TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onSendGift(product),
                    icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Send as a gift'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/gift.dart';

/// Which photo or video of the gallery is showing, shared by the swipeable
/// main view and the thumbnail row under it.
class GiftGalleryController extends ValueNotifier<int> {
  GiftGalleryController() : super(0);

  final PageController pages = PageController();

  void show(int index) {
    if (value == index) return;
    value = index;
    if (pages.hasClients) {
      pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }
}

/// The big swipeable view: photos, and videos that play on their own,
/// muted and looping, with no player controls.
class GiftGalleryView extends StatelessWidget {
  const GiftGalleryView({
    super.key,
    required this.media,
    required this.controller,
    this.heroTag,
  });

  final List<GiftMedia> media;
  final GiftGalleryController controller;

  /// Wraps the first page, so the card the gift opened from flies into it.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: const Key('gift-gallery'),
          controller: controller.pages,
          itemCount: media.length,
          onPageChanged: (index) => controller.value = index,
          itemBuilder: (context, index) {
            final item = media[index];
            final page = item.isVideo
                ? ValueListenableBuilder<int>(
                    valueListenable: controller,
                    builder: (context, current, _) =>
                        GalleryVideo(url: item.url, playing: current == index),
                  )
                : AppNetworkImage(url: item.url);
            if (index == 0 && heroTag != null) {
              return Hero(tag: heroTag!, child: page);
            }
            return page;
          },
        ),
        if (media.length > 1)
          Positioned(
            right: 14,
            bottom: 14,
            child: ValueListenableBuilder<int>(
              valueListenable: controller,
              builder: (context, current, _) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${current + 1} / ${media.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Every photo and video in one row under the main view. Tapping one shows
/// it; videos are marked with a play triangle.
class GiftGalleryThumbnails extends StatelessWidget {
  const GiftGalleryThumbnails({
    super.key,
    required this.media,
    required this.controller,
  });

  final List<GiftMedia> media;
  final GiftGalleryController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ValueListenableBuilder<int>(
        valueListenable: controller,
        builder: (context, current, _) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gutter),
          itemCount: media.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = media[index];
            final active = index == current;
            return GestureDetector(
              key: Key('gift-thumb-$index'),
              onTap: () => controller.show(index),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: active ? 1 : 0.7,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: AppColors.cream),
                        if (item.isVideo)
                          // First frame as the thumbnail, never playing.
                          GalleryVideo(url: item.url, playing: false)
                        else
                          AppNetworkImage(url: item.url),
                        if (item.isVideo)
                          Center(
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                        // Drawn over the photo so the photo never hides it.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(
                              color: active
                                  ? AppColors.purple
                                  : AppColors.border,
                              width: active ? 2 : 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A gift video: muted and looping, playing only while [playing].
class GalleryVideo extends StatefulWidget {
  const GalleryVideo({super.key, required this.url, required this.playing});

  final String url;
  final bool playing;

  @override
  State<GalleryVideo> createState() => _GalleryVideoState();
}

class _GalleryVideoState extends State<GalleryVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant GalleryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _controller?.dispose();
      _ready = false;
      _open();
    } else if (widget.playing != oldWidget.playing) {
      _apply();
    }
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!mounted || _controller != controller) return;
      setState(() => _ready = true);
      _apply();
    } catch (_) {
      // A video that cannot load leaves the plain background, not an error.
    }
  }

  void _apply() {
    final controller = _controller;
    if (controller == null || !_ready) return;
    widget.playing ? controller.play() : controller.pause();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null) {
      return const ColoredBox(color: AppColors.cream);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

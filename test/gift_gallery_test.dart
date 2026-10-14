import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';
import 'package:send_agift_mobile/features/products/presentation/widgets/gift_gallery.dart';

Map<String, dynamic> _media(String url, String type, int position) => {
  'cdn_url': url,
  'asset_type': type,
  'mime_type': type == 'video' ? 'video/mp4' : 'image/png',
  'position': position,
};

void main() {
  test('every photo and video is kept, cover photo first, videos last', () {
    final gift = Gift.fromJson({
      'id': 'g1',
      'name': 'Boot',
      'price_amount': 62000,
      'currency': 'AUD',
      'media': [
        _media('https://cdn/clip.mp4', 'video', 0),
        _media('https://cdn/side.png', 'image', 1),
        _media('https://cdn/top.png', 'image', 2),
      ],
    });

    // No image_url: the first photo becomes the cover.
    expect(gift.image, 'https://cdn/side.png');
    expect(gift.gallery.map((m) => m.url), [
      'https://cdn/side.png',
      'https://cdn/top.png',
      'https://cdn/clip.mp4',
    ]);
    expect(gift.gallery.last.isVideo, isTrue);
  });

  test('a gift with no media still shows its one image', () {
    final gift = Gift.fromJson({
      'id': 'g2',
      'name': 'Card',
      'price_amount': 500,
      'currency': 'AUD',
      'image_url': 'https://cdn/card.png',
    });
    expect(gift.gallery.single.url, 'https://cdn/card.png');
  });

  testWidgets('tapping a thumbnail shows that photo', (tester) async {
    const media = [
      GiftMedia(url: 'https://cdn/a.png', isVideo: false),
      GiftMedia(url: 'https://cdn/b.png', isVideo: false),
      GiftMedia(url: 'https://cdn/c.png', isVideo: false),
    ];
    final controller = GiftGalleryController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 300,
                child: GiftGalleryView(media: media, controller: controller),
              ),
              GiftGalleryThumbnails(media: media, controller: controller),
            ],
          ),
        ),
      ),
    );
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byKey(const Key('gift-thumb-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('gift-thumb-2')));
    // Image placeholders animate forever, so pump past the page slide.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.value, 2);
    expect(find.text('3 / 3'), findsOneWidget);
  });
}

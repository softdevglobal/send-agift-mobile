import '../domain/gift.dart';

/// Placeholder shelf shown when no seller has published anything yet (or the
/// marketplace endpoint is unreachable). Mirrors the web's `bestSellingGifts`.
const List<Gift> sampleGifts = [
  Gift(
    id: 'sample-1',
    name: 'Handbound Memory Journal',
    priceAmount: 2800,
    compareAtAmount: 3600,
    currency: 'USD',
    rating: 4.9,
    reviewCount: 214,
    categoryId: 'keepsakes',
    shopName: 'Paper & Fern',
    description:
        'A linen-wrapped journal with thick cream pages, made for letters, '
        'sketches, and the moments worth keeping.',
    image:
        'https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&w=900&q=80',
  ),
  Gift(
    id: 'sample-2',
    name: 'Ceramic Pour-Over Set',
    priceAmount: 4200,
    compareAtAmount: 5500,
    currency: 'USD',
    rating: 4.8,
    reviewCount: 168,
    categoryId: 'hampers',
    shopName: 'Sunday Pour',
    description:
        'A handmade ceramic dripper, carafe, and filters. Ready to wrap as a '
        'slow-morning coffee ritual.',
    image:
        'https://images.unsplash.com/photo-1514228742587-6b1558fcca3d?auto=format&fit=crop&w=900&q=80',
  ),
  Gift(
    id: 'sample-3',
    name: 'Soft Linen Gift Hamper',
    priceAmount: 6400,
    compareAtAmount: 7900,
    currency: 'USD',
    rating: 4.9,
    reviewCount: 301,
    categoryId: 'hampers',
    shopName: 'Hearth & Ribbon',
    description:
        'A ready-to-send hamper of linen tea towels, candles, and pantry '
        'treats packed in a reusable gift crate.',
    image:
        'https://images.unsplash.com/photo-1513885535751-8b9238bd345a?auto=format&fit=crop&w=900&q=80',
  ),
  Gift(
    id: 'sample-4',
    name: 'Wireless Focus Earbuds',
    priceAmount: 8900,
    compareAtAmount: 11900,
    currency: 'USD',
    rating: 4.7,
    reviewCount: 452,
    categoryId: 'tech',
    shopName: 'North Signal',
    description:
        'Noise-isolating earbuds with a compact charge case. A practical gift '
        'for commutes, travel, and deep work.',
    image:
        'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=900&q=80',
  ),
  Gift(
    id: 'sample-5',
    name: 'Sunset Peony Bouquet',
    priceAmount: 4800,
    currency: 'USD',
    rating: 4.8,
    reviewCount: 126,
    categoryId: 'flowers',
    shopName: 'Bloom Atelier',
    description:
        'Seasonal peonies and garden roses arranged for same-week delivery, '
        'wrapped in kraft and silk ribbon.',
    image:
        'https://images.unsplash.com/photo-1490750967868-88aa4486c946?auto=format&fit=crop&w=900&q=80',
  ),
  Gift(
    id: 'sample-6',
    name: 'Dried Meadow Arrangement',
    priceAmount: 3600,
    currency: 'USD',
    rating: 4.6,
    reviewCount: 88,
    categoryId: 'flowers',
    shopName: 'Bloom Atelier',
    description:
        'A lasting dried bouquet of oats, ruscus, and strawflowers. No vase '
        'required, just unwrap and display.',
    image:
        'https://images.unsplash.com/photo-1487530811176-3780de880c2d?auto=format&fit=crop&w=900&q=80',
  ),
  Gift(
    id: 'sample-7',
    name: 'Birthday Balloon Gift Box',
    priceAmount: 3900,
    compareAtAmount: 4800,
    currency: 'USD',
    rating: 4.7,
    reviewCount: 193,
    categoryId: 'birthday',
    shopName: 'Party Post',
    description:
        'Confetti, mini cake candles, and a reusable balloon kit for birthdays '
        'that arrive already dressed to celebrate.',
    image:
        'https://images.unsplash.com/photo-1464349153735-7db50ed83c84?auto=format&fit=crop&w=900&q=80',
  ),
  Gift(
    id: 'sample-8',
    name: 'Calm Evening Spa Set',
    priceAmount: 5200,
    compareAtAmount: 6500,
    currency: 'USD',
    rating: 4.8,
    reviewCount: 174,
    categoryId: 'wellness',
    shopName: 'Still Hours',
    description:
        'Bath salts, a hinoki candle, and a linen eye pillow packed for a slow '
        'evening at home.',
    image:
        'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&w=900&q=80',
  ),
];

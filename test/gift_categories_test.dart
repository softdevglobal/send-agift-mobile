import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';

void main() {
  test('a gift filed under several categories shows under each', () {
    final gift = Gift.fromJson({
      'id': 'g1',
      'name': 'Peony and chocolate box',
      'price_amount': 4800,
      'currency': 'GBP',
      'occasion_tags': ['Birthday', 'flowers', 'hampers'],
    });

    expect(gift.categoryId, 'birthday');
    expect(gift.inCategory('birthday'), isTrue);
    expect(gift.inCategory('flowers'), isTrue);
    expect(gift.inCategory('hampers'), isTrue);
    expect(gift.inCategory('wellness'), isFalse);
  });
}

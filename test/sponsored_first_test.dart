import 'package:flutter_test/flutter_test.dart';
import 'package:send_agift_mobile/features/products/domain/gift.dart';

Gift _gift(String id, {bool sponsored = false, int entries = 0}) => Gift(
  id: id,
  name: id,
  priceAmount: 1000,
  currency: 'LKR',
  image: '',
  sponsored: sponsored,
  gameEntries: entries,
);

void main() {
  test('sponsored gifts lead, the higher priority level first', () {
    final ordered = sponsoredFirst([
      _gift('a'),
      _gift('low', sponsored: true, entries: 1),
      _gift('b'),
      _gift('top', sponsored: true, entries: 5),
      _gift('c'),
    ]);
    expect(ordered.map((g) => g.id), ['top', 'low', 'a', 'b', 'c']);
  });

  test('the rest keep the order they came in', () {
    final ordered = sponsoredFirst([
      for (var i = 0; i < 40; i++) _gift('g$i'),
      _gift('s', sponsored: true, entries: 2),
    ]);
    expect(ordered.first.id, 's');
    expect(ordered.skip(1).map((g) => g.id), [
      for (var i = 0; i < 40; i++) 'g$i',
    ]);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/cart_policy.dart';

void main() {
  test('quantity accepts available stock and rejects boundary cases', () {
    expect(validateQuantity(2, 2), isNull);
    expect(validateQuantity(0, 5), contains('1 đến 99'));
    expect(validateQuantity(100, 500), contains('1 đến 99'));
    expect(validateQuantity(4, 3), contains('vượt tồn kho'));
  });
}

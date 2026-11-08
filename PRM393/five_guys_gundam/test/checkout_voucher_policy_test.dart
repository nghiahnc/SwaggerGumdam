import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/voucher_policy.dart';

void main() {
  test('empty voucher code is allowed because voucher is optional', () {
    expect(validateVoucherCode(null), isNull);
    expect(validateVoucherCode(''), isNull);
    expect(validateVoucherCode('   '), isNull);
  });

  test('voucher code length follows backend MaxLength(64)', () {
    expect(validateVoucherCode('GUNDAM10'), isNull);
    expect(validateVoucherCode('A' * 64), isNull);
    expect(validateVoucherCode('  ${'A' * 64}  '), isNull);
    expect(validateVoucherCode('A' * 65), contains('tối đa 64'));
  });

  test('normalize trims, uppercases and turns blank into null', () {
    expect(normalizeVoucherCode('  gundam10 '), 'GUNDAM10');
    expect(normalizeVoucherCode('Sale 10'), 'SALE 10');
    expect(normalizeVoucherCode('   '), isNull);
    expect(normalizeVoucherCode(null), isNull);
  });
}

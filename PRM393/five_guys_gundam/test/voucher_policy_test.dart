import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/core/dates.dart';
import 'package:five_guys_gundam/core/models.dart';
import 'package:five_guys_gundam/core/voucher_policy.dart';

import 'support/fake_shop_api.dart';

void main() {
  group('voucher code', () {
    test('is trimmed and upper-cased like the API does', () {
      expect(VoucherPolicy.normalizeCode('  sale10 '), 'SALE10');
      expect(VoucherPolicy.code('  sale10 '), isNull);
    });

    test('refuses empty, too long, spaces and accents', () {
      expect(VoucherPolicy.code('   '), 'Nhập mã voucher');
      expect(VoucherPolicy.code('A' * 65), contains('64'));
      expect(VoucherPolicy.code('SALE 10'), contains('không dấu'));
      expect(VoucherPolicy.code('GIẢM10'), contains('không dấu'));
      expect(VoucherPolicy.code('-SALE'), contains('bắt đầu'));
      expect(VoucherPolicy.code('BLACK_FRIDAY-2026'), isNull);
    });
  });

  group('amounts and usage limit', () {
    test('discount must be a whole number from 1 to 1e9', () {
      expect(VoucherPolicy.discount('abc'), contains('số nguyên'));
      expect(VoucherPolicy.discount('0'), contains('lớn hơn 0'));
      expect(VoucherPolicy.discount('1000000001'), contains('tối đa'));
      expect(VoucherPolicy.discount(' 50000 '), isNull);
    });

    test('minimum order may be 0 but not negative', () {
      expect(VoucherPolicy.minSubtotal(''), contains('số nguyên'));
      expect(VoucherPolicy.minSubtotal('-1'), contains('âm'));
      expect(VoucherPolicy.minSubtotal('0'), isNull);
    });

    test('usage limit cannot drop below the uses already made', () {
      expect(VoucherPolicy.usageLimit('0'), contains('lớn hơn 0'));
      expect(
        VoucherPolicy.usageLimit('3', usedCount: 5),
        'Không được nhỏ hơn số lượt đã dùng (5)',
      );
      expect(VoucherPolicy.usageLimit('5', usedCount: 5), isNull);
      expect(VoucherPolicy.usageLimit('1000001'), contains('1.000.000'));
    });
  });

  group('period (ngày sai)', () {
    final now = DateTime(2026, 10, 10, 12);

    test('start must be before end', () {
      final start = DateTime(2026, 10, 20);
      expect(
        VoucherPolicy.period(start, DateTime(2026, 10, 19), now: now),
        'Thời gian bắt đầu phải trước thời gian kết thúc',
      );
      expect(
        VoucherPolicy.period(start, start, now: now),
        'Thời gian bắt đầu phải trước thời gian kết thúc',
      );
    });

    test('a period that has already ended is refused', () {
      expect(
        VoucherPolicy.period(
          DateTime(2026, 9, 1),
          DateTime(2026, 10, 1),
          now: now,
        ),
        'Thời gian kết thúc đã qua',
      );
      expect(
        VoucherPolicy.period(
          DateTime(2026, 9, 1),
          DateTime(2026, 11, 1),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('state, from the conditions checkout checks', () {
    final now = DateTime.utc(2026, 10, 10, 12);
    Voucher at({
      DateTime? starts,
      DateTime? ends,
      int used = 0,
      bool active = true,
    }) => Voucher.fromJson(
      voucherJson(
        startsAtUtc: starts ?? DateTime.utc(2026, 10, 1),
        endsAtUtc: ends ?? DateTime.utc(2026, 10, 20),
        usedCount: used,
        maxUses: 5,
        isActive: active,
      ),
    );

    test('active, scheduled, expired, used up, stopped', () {
      expect(VoucherPolicy.stateOf(at(), now), VoucherState.active);
      expect(
        VoucherPolicy.stateOf(at(starts: DateTime.utc(2026, 10, 11)), now),
        VoucherState.scheduled,
      );
      expect(
        VoucherPolicy.stateOf(at(ends: DateTime.utc(2026, 10, 9)), now),
        VoucherState.expired,
      );
      expect(VoucherPolicy.stateOf(at(used: 5), now), VoucherState.usedUp);
      expect(
        VoucherPolicy.stateOf(
          at(active: false, ends: DateTime.utc(2026, 10, 9)),
          now,
        ),
        VoucherState.stopped,
      );
    });

    test('boundaries match checkout: usable from start, not at end', () {
      expect(VoucherPolicy.stateOf(at(starts: now), now), VoucherState.active);
      expect(VoucherPolicy.stateOf(at(ends: now), now), VoucherState.expired);
    });
  });

  group('dates from the API', () {
    test('a date without zone suffix is read as UTC', () {
      final voucher = Voucher.fromJson({
        ...voucherJson(),
        'startsAtUtc': '2026-10-10T07:00:00',
        'endsAtUtc': '2026-10-20T07:00:00.1291081',
      });
      expect(voucher.startsAtUtc, DateTime.utc(2026, 10, 10, 7));
      expect(voucher.endsAtUtc.isUtc, isTrue);
      expect(voucher.endsAtUtc.hour, 7);
    });

    test('a date with "Z" or an offset keeps its meaning', () {
      expect(parseUtc('2026-10-10T07:00:00Z'), DateTime.utc(2026, 10, 10, 7));
      expect(
        parseUtc('2026-10-10T14:00:00+07:00'),
        DateTime.utc(2026, 10, 10, 7),
      );
    });

    test('dates are shown as dd/MM/yyyy HH:mm in device time', () {
      expect(formatLocal(DateTime(2026, 1, 5, 9, 7)), '05/01/2026 09:07');
    });
  });
}

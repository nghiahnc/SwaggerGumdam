import 'models.dart';

/// Where a voucher stands right now. Checkout accepts a voucher only when it
/// is active, started, not ended and has uses left (GundamShop.Bll/
/// ShoppingService.cs); when several of those fail, the label follows the
/// order in [VoucherPolicy.stateOf].
enum VoucherState {
  active('Đang áp dụng'),
  scheduled('Chưa bắt đầu'),
  expired('Hết hạn'),
  usedUp('Hết lượt'),
  stopped('Ngừng sử dụng');

  const VoucherState(this.label);
  final String label;
}

/// Rules for the admin voucher form (FL-13). Each check returns `null` when
/// the value is fine, otherwise the message shown under the field.
///
/// The API is still the authority and checks again (VoucherRequest in
/// GundamShop.Bll/Common.cs, PromotionService.Validate); these rules give the
/// reason next to the field before anything is sent.
abstract final class VoucherPolicy {
  /// `[MaxLength(64)]` on VoucherRequest.Code.
  static const codeMaxLength = 64;

  /// Business caps. The API accepts up to `long.MaxValue`, which cannot be
  /// typed safely on every platform and is never a real voucher.
  static const maxAmountVnd = 1000000000;
  static const maxUses = 1000000;

  /// App convention: customers type the code at checkout, so it stays plain
  /// (no spaces or accents). The API only limits the length.
  static final _codePattern = RegExp(r'^[A-Z0-9][A-Z0-9_-]*$');

  /// The API trims and upper-cases the code before saving and before its
  /// uniqueness check, so "sale10 " and "SALE10" are the same voucher.
  static String normalizeCode(String raw) => raw.trim().toUpperCase();

  static String? code(String? raw) {
    final value = normalizeCode(raw ?? '');
    if (value.isEmpty) return 'Nhập mã voucher';
    if (value.length > codeMaxLength) {
      return 'Mã voucher tối đa $codeMaxLength ký tự';
    }
    if (!_codePattern.hasMatch(value)) {
      return 'Chỉ dùng chữ không dấu, số, dấu - và _ (bắt đầu bằng chữ hoặc số)';
    }
    return null;
  }

  static String? discount(String? raw) {
    final value = int.tryParse(raw?.trim() ?? '');
    if (value == null) return 'Nhập số tiền giảm là số nguyên (VND)';
    if (value < 1) return 'Số tiền giảm phải lớn hơn 0';
    if (value > maxAmountVnd) return 'Số tiền giảm tối đa 1.000.000.000 ₫';
    return null;
  }

  static String? minSubtotal(String? raw) {
    final value = int.tryParse(raw?.trim() ?? '');
    if (value == null) return 'Nhập số tiền là số nguyên (VND), không có thì 0';
    if (value < 0) return 'Đơn tối thiểu không được âm';
    if (value > maxAmountVnd) return 'Đơn tối thiểu tối đa 1.000.000.000 ₫';
    return null;
  }

  /// [usedCount] is how many orders already used the voucher: the API refuses
  /// a limit below it ("MaxUses không thể nhỏ hơn số lượt đã dùng.").
  static String? usageLimit(String? raw, {int usedCount = 0}) {
    final value = int.tryParse(raw?.trim() ?? '');
    if (value == null) return 'Nhập số lượt là số nguyên';
    if (value < 1) return 'Số lượt phải lớn hơn 0';
    if (value < usedCount) {
      return 'Không được nhỏ hơn số lượt đã dùng ($usedCount)';
    }
    if (value > maxUses) return 'Tối đa 1.000.000 lượt';
    return null;
  }

  /// The API only requires start < end. A voucher that has already ended
  /// could never be used, so the form refuses that too.
  static String? period(
    DateTime starts,
    DateTime ends, {
    required DateTime now,
  }) {
    if (!starts.isBefore(ends)) {
      return 'Thời gian bắt đầu phải trước thời gian kết thúc';
    }
    if (!ends.isAfter(now)) return 'Thời gian kết thúc đã qua';
    return null;
  }

  static VoucherState stateOf(Voucher voucher, DateTime now) {
    if (!voucher.isActive) return VoucherState.stopped;
    if (!now.isBefore(voucher.endsAtUtc)) return VoucherState.expired;
    if (voucher.usedCount >= voucher.maxUses) return VoucherState.usedUp;
    if (now.isBefore(voucher.startsAtUtc)) return VoucherState.scheduled;
    return VoucherState.active;
  }
}

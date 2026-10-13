// Khớp VoucherRequest backend: Code [MaxLength(64)], lưu bằng Trim().ToUpperInvariant().
const voucherCodeMaxLength = 64;

String? validateVoucherCode(String? value) {
  final code = value?.trim() ?? '';
  if (code.isEmpty) return null; // Voucher không bắt buộc.
  if (code.length > voucherCodeMaxLength) {
    return 'Mã voucher tối đa $voucherCodeMaxLength ký tự.';
  }
  return null;
}

String? normalizeVoucherCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  return code.isEmpty ? null : code;
}

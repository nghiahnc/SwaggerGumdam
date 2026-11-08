/// Giới hạn của API cho một dòng giỏ: `[Range(1, 99)]` trong CartItemRequest.
const minCartQuantity = 1;
const maxCartQuantity = 99;

String? validateQuantity(int quantity, int stock) {
  if (quantity < minCartQuantity || quantity > maxCartQuantity) {
    return 'Số lượng phải từ $minCartQuantity đến $maxCartQuantity.';
  }
  if (quantity > stock) return 'Số lượng vượt tồn kho hiện tại.';
  return null;
}

/// Số lượng lớn nhất được chọn cho một SKU: không vượt tồn và không quá 99.
int maxQuantity(int stock) => stock.clamp(0, maxCartQuantity);

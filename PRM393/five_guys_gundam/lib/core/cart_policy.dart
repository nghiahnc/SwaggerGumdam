String? validateQuantity(int quantity, int stock) {
  if (quantity < 1 || quantity > 99) return 'Số lượng phải từ 1 đến 99.';
  if (quantity > stock) return 'Số lượng vượt tồn kho hiện tại.';
  return null;
}

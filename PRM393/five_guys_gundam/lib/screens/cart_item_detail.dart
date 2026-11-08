import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/error_text.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

/// Reads a cart item by ID instead of reusing the cart list's older values.
/// Ownership and missing-item checks remain with the authenticated API.
class CartItemDetailScreen extends StatefulWidget {
  const CartItemDetailScreen({required this.cartItemId, super.key});
  final String cartItemId;

  @override
  State<CartItemDetailScreen> createState() => _CartItemDetailScreenState();
}

class _CartItemDetailScreenState extends State<CartItemDetailScreen> {
  Future<CartLine>? future;
  String? userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUserId = context.watch<SessionController>().user?.id;
    if (currentUserId != userId) {
      userId = currentUserId;
      // Switching accounts must discard the previous account's item data.
      future = currentUserId == null ? null : readItem();
    }
  }

  Future<CartLine> readItem() =>
      readable(context.read<ShopRepository>().cartItem(widget.cartItemId));

  void reload() {
    if (!context.read<SessionController>().isSignedIn) return;
    final next = readItem();
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<SessionController>().isSignedIn;
    final current = future;
    return Scaffold(
      appBar: AppBar(
        title: const HudTitle(
          'Chi tiết món trong giỏ',
          tag: 'FiveGuys // Verified logistics',
        ),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Tải lại',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !signedIn
          ? const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Đăng nhập để xem món trong giỏ hàng.',
                ),
              ),
            )
          : current == null
          ? const Center(child: CircularProgressIndicator(color: Hud.red))
          : AsyncPanel<CartLine>(
              future: current,
              onRetry: reload,
              builder: (line) => Column(
                children: [
                  const _TelemetryBar(),
                  Expanded(
                    child: ListView(
                      key: const Key('cart-item-detail'),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        _ItemCard(line: line),
                        const SectionHeader(
                          'Thông tin kiện hàng',
                          tag: 'Cargo spec',
                        ),
                        HudCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: Column(
                            children: [
                              _DetailValue(
                                icon: Icons.qr_code_2,
                                label: 'SKU',
                                value: line.sku,
                                valueKey: const Key('cart-item-sku'),
                                mono: true,
                              ),
                              _DetailValue(
                                icon: Icons.sell_outlined,
                                label: 'Đơn giá',
                                value: money(line.unitPriceVnd),
                                valueKey: const Key('cart-item-unit-price'),
                              ),
                              _DetailValue(
                                icon: Icons.inventory_2_outlined,
                                label: 'Số lượng',
                                value: '${line.quantity}',
                                valueKey: const Key('cart-item-quantity'),
                                last: true,
                              ),
                            ],
                          ),
                        ),
                        const SectionHeader(
                          'Hạch toán món hàng',
                          tag: 'Manifest',
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(Hud.radius),
                            border: Border.all(color: Hud.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${money(line.unitPriceVnd)} × ${line.quantity}',
                                        style: const TextStyle(
                                          color: Hud.muted,
                                        ),
                                      ),
                                    ),
                                    const HudLabel('Giá lấy từ giỏ hiện tại'),
                                  ],
                                ),
                              ),
                              Container(
                                color: const Color(0xFFF1F3FF),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Thành tiền',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            'Giảm giá và tổng cuối được xác nhận khi đặt hàng',
                                            style: TextStyle(
                                              color: Hud.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          money(line.totalVnd),
                                          key: const Key('cart-item-total'),
                                          style: const TextStyle(
                                            color: Hud.red,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const InfoBanner(
                          tone: Tone.warning,
                          icon: Icons.verified_user_outlined,
                          tag: 'Quy chuẩn đóng gói Hangar',
                          message:
                              'Đổi số lượng hoặc xóa món ở màn Giỏ hàng; màn này '
                              'luôn đọc lại dữ liệu mới nhất từ máy chủ.',
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.keyboard_backspace),
                            label: const Text('Quay lại giỏ hàng'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TelemetryBar extends StatelessWidget {
  const _TelemetryBar();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFFE1E8FD),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: const Row(
      children: [
        Icon(Icons.circle, size: 8, color: Hud.red),
        SizedBox(width: 8),
        Expanded(
          child: HudLabel(
            'Payload manifest // cargo verification',
            color: Hud.red,
          ),
        ),
        HudLabel('Sec-04'),
      ],
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) => HudCard(
    margin: EdgeInsets.zero,
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProductArt(size: 96),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              const HudLabel('Kiện hàng trong giỏ', color: Hud.red),
              Text(
                line.productName,
                key: const Key('cart-item-name'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Hud.ink,
                  height: 1.25,
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusPill('${line.quantity} hộp', color: Hud.navySoft),
                  const StatusPill('Sẵn sàng đặt hàng', color: Hud.green),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueKey,
    this.mono = false,
    this.last = false,
  });
  final IconData icon;
  final String label, value;
  final Key valueKey;
  final bool mono, last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: Hud.line)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Hud.muted),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Hud.muted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontFamilyFallback: mono ? Hud.mono : null,
            ),
          ),
        ),
      ],
    ),
  );
}

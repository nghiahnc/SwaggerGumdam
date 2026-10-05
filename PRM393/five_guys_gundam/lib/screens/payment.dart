import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({required this.orderId, super.key});
  final String orderId;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Future<Json> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().paymentSession(widget.orderId);
  });

  Future<void> completeMock(bool succeeded) async {
    setState(() => busy = true);
    try {
      await context.read<ShopRepository>().completeMock(
        widget.orderId,
        succeeded,
      );
      if (mounted) {
        showSuccess(
          context,
          succeeded
              ? 'Đã mô phỏng thanh toán thành công'
              : 'Đã mô phỏng thanh toán thất bại; tồn kho được hoàn',
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thanh toán')),
    body: AsyncPanel<Json>(
      future: future,
      onRetry: reload,
      builder: (session) {
        final provider = session['provider'] as String;
        final checkoutUrl = session['checkoutUrl'] as String?;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.payments_outlined, size: 70),
            const SizedBox(height: 16),
            Text(
              'Phương thức: $provider',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (provider == 'Mock') ...[
              const Text(
                'Chế độ Development: chọn một kết quả để thử toàn bộ luồng đơn hàng.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : () => completeMock(true),
                child: const Text('Mô phỏng thành công'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => completeMock(false),
                child: const Text('Mô phỏng thất bại'),
              ),
            ] else if (checkoutUrl != null) ...[
              const Text(
                'Stripe xử lý trên trang thanh toán. Đơn chỉ cập nhật sau webhook.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  try {
                    if (!await launchUrl(
                      Uri.parse(checkoutUrl),
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw Exception('Không mở được Stripe Checkout.');
                    }
                  } catch (error) {
                    if (context.mounted) showError(context, error);
                  }
                },
                child: const Text('Mở Stripe Checkout'),
              ),
            ] else
              const Text(
                'Không cần chuyển trang. Hãy quay lại đơn và tải lại trạng thái.',
              ),
          ],
        );
      },
    ),
  );
}

import 'package:flutter/material.dart';

import 'hud.dart';

export 'hud.dart';

String money(int value) {
  final digits = value.toString();
  final reversed = digits.split('').reversed.toList();
  final groups = <String>[];
  for (var i = 0; i < reversed.length; i += 3) {
    groups.add(reversed.skip(i).take(3).toList().reversed.join());
  }
  return '${groups.reversed.join('.')} ₫';
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Không được để trống' : null;

String? positiveNumber(String? value) {
  final number = int.tryParse(value?.trim() ?? '');
  return number == null || number <= 0 ? 'Nhập số nguyên lớn hơn 0' : null;
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    ) ??
    false;

class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({
    required this.future,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'Chưa có dữ liệu',
    super.key,
  });
  final Future<T> future;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  final bool Function(T)? isEmpty;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Hud.red),
              SizedBox(height: 12),
              HudLabel('Đang đồng bộ dữ liệu…'),
            ],
          ),
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: SingleChildScrollView(
            child: EmptyState(
              icon: Icons.wifi_off_outlined,
              title: 'Không tải được dữ liệu',
              message: snapshot.error.toString(),
              actions: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      final data = snapshot.data as T;
      if (isEmpty?.call(data) ?? false) {
        return Center(
          child: SingleChildScrollView(child: EmptyState(title: emptyMessage)),
        );
      }
      return builder(data);
    },
  );
}

class ProductArt extends StatelessWidget {
  const ProductArt({this.url, this.size = 72, this.width, super.key});
  final String? url;
  final double size;
  final double? width;

  Widget _placeholder(IconData icon) => Container(
    width: width ?? size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Icon(
      icon,
      size: size * .45,
      color: Hud.navySoft.withValues(alpha: .45),
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: url == null || url!.isEmpty
        ? _placeholder(Icons.smart_toy_outlined)
        : Image.network(
            url!,
            width: width ?? size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                _placeholder(Icons.broken_image_outlined),
          ),
  );
}

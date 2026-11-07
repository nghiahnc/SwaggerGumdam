// Phụ trách: Nguyễn Hữu Tài (AgnesLorem) — CE190387
// Scaffold: nhóm, có AI hỗ trợ (nghiahnc, 60b4e16)
// UC: không có mã UC riêng (FL-08)
// Mục đích: trang Quản trị, lối vào các màn chỉ dành cho Admin

import 'package:flutter/material.dart';

import 'admin_catalog.dart';
import 'admin_categories.dart';
import 'admin_inventory.dart';
import 'vouchers.dart';

/// Tab Quản trị. `ShopShell` chỉ hiện tab này khi tài khoản là Admin.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị cửa hàng')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Danh mục'),
            subtitle: const Text('Xem, thêm, sửa và ngừng bán danh mục'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminCategoriesScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.view_in_ar_outlined),
            title: const Text('Sản phẩm'),
            subtitle: const Text('Thêm, sửa và ngừng bán sản phẩm'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminCatalogScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('SKU và tồn kho'),
            subtitle: const Text('Quản lý phiên bản, giá, điều chỉnh tồn'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminInventoryScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('Voucher'),
            subtitle: const Text('Thiết lập mã giảm giá và thời hạn'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VouchersScreen()),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Đơn hàng của mọi khách xuất hiện trong tab Đơn. '
            'Admin có thể chuyển Paid → Shipped → Delivered tại chi tiết đơn.',
          ),
        ),
      ],
    ),
  );
}

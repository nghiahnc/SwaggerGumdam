// Phụ trách: Nguyễn Hữu Tài (AgnesLorem) — CE190387
// Scaffold: nhóm, có AI hỗ trợ (nghiahnc, 60b4e16)
// UC: không có mã UC riêng (FL-08)
// Mục đích: trang Quản trị, lối vào các màn chỉ dành cho Admin

import 'package:flutter/material.dart';

import '../widgets/hud.dart';
import 'admin_catalog.dart';
import 'admin_categories.dart';
import 'admin_inventory.dart';
import 'vouchers.dart';

//// Tab Quản trị. `ShopShell` chỉ hiện tab này khi tài khoản là Admin.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const HudTitle('Quản trị cửa hàng', tag: 'Admin console'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const NavyPanel(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HudLabel('Hangar ops control', color: Color(0xFFF87171)),
              SizedBox(height: 6),
              Text(
                'Điều phối catalog, kho và khuyến mãi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Mọi thay đổi có hiệu lực ngay với khách hàng.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SectionHeader('Phân hệ quản lý', tag: 'Modules'),
        _ModuleTile(
          icon: Icons.category_outlined,
          color: Hud.blue,
          title: 'Danh mục',
          subtitle: 'Xem, thêm, sửa và ngừng bán danh mục',
          onTap: () => _open(context, const AdminCategoriesScreen()),
        ),
        _ModuleTile(
          icon: Icons.view_in_ar_outlined,
          color: Hud.green,
          title: 'Sản phẩm',
          subtitle: 'Thêm, sửa và ngừng bán sản phẩm',
          onTap: () => _open(context, const AdminCatalogScreen()),
        ),
        _ModuleTile(
          icon: Icons.inventory_2_outlined,
          color: Hud.purple,
          title: 'SKU và tồn kho',
          subtitle: 'Quản lý phiên bản, giá, điều chỉnh tồn',
          onTap: () => _open(context, const AdminInventoryScreen()),
        ),
        _ModuleTile(
          icon: Icons.local_offer_outlined,
          color: Hud.red,
          title: 'Voucher',
          subtitle: 'Thiết lập mã giảm giá và thời hạn',
          onTap: () => _open(context, const VouchersScreen()),
        ),
        const SizedBox(height: 8),
        const InfoBanner(
          tag: 'Order pipeline',
          message:
              'Đơn hàng của mọi khách xuất hiện trong tab Đơn. '
              'Admin có thể chuyển Paid → Shipped → Delivered tại chi tiết đơn.',
        ),
      ],
    ),
  );
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HudCard(
    onTap: onTap,
    accent: color,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: Hud.ink,
                ),
              ),
              Text(subtitle, style: const TextStyle(color: Hud.muted)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Hud.muted),
      ],
    ),
  );
}

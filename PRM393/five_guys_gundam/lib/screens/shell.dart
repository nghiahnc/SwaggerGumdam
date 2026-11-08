import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import 'account.dart';
import 'admin.dart';
import 'cart.dart';
import 'catalog.dart';
import 'orders.dart';

class ShopShell extends StatefulWidget {
  const ShopShell({super.key});
  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SessionController>().isAdmin;
    final pages = <Widget>[
      const CatalogScreen(),
      const CartScreen(),
      const OrdersScreen(),
      const AccountScreen(),
      if (isAdmin) const AdminHomeScreen(),
    ];
    if (index >= pages.length) index = 0;
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Cửa hàng',
            ),
            const NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Giỏ',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Đơn',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
            if (isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: Icon(Icons.admin_panel_settings),
                label: 'Quản trị',
              ),
          ],
        ),
      ),
    );
  }
}

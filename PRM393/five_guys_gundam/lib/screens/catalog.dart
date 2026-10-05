import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'product.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  String grade = '';
  int skip = 0;
  late Future<List<ProductSearchHit>> future;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().searchProducts(
      query: search.text,
      grade: grade,
      skip: skip,
    );
  });

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FiveGuysGundam')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                    labelText: 'Tìm tên mô hình',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () {
                        search.clear();
                        skip = 0;
                        reload();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                  onSubmitted: (_) {
                    skip = 0;
                    reload();
                  },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: grade,
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tất cả')),
                  DropdownMenuItem(value: 'HG', child: Text('HG')),
                  DropdownMenuItem(value: 'MG', child: Text('MG')),
                  DropdownMenuItem(value: 'RG', child: Text('RG')),
                  DropdownMenuItem(value: 'PG', child: Text('PG')),
                ],
                onChanged: (v) {
                  grade = v ?? '';
                  skip = 0;
                  reload();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncPanel<List<ProductSearchHit>>(
            future: future,
            onRetry: reload,
            isEmpty: (items) => items.isEmpty,
            emptyMessage: 'Không tìm thấy sản phẩm phù hợp.',
            builder: (items) => RefreshIndicator(
              onRefresh: () async => reload(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final item in items)
                    Card(
                      child: ListTile(
                        leading: const ProductArt(),
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.category} · ${item.grade} · ${item.scale}\n'
                          '${item.fromPriceVnd == null ? 'Chưa có giá' : 'Từ ${money(item.fromPriceVnd!)}'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductScreen(productId: item.id),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: skip == 0
                            ? null
                            : () {
                                skip -= 20;
                                reload();
                              },
                        child: const Text('Trang trước'),
                      ),
                      Text('Trang ${skip ~/ 20 + 1}'),
                      TextButton(
                        onPressed: items.length < 20
                            ? null
                            : () {
                                skip += 20;
                                reload();
                              },
                        child: const Text('Trang sau'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

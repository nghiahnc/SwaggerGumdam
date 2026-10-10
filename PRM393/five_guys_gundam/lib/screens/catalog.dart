import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/shop_repository.dart';
import '../widgets/common.dart';
import 'product.dart';

const catalogGrades = ['HG', 'MG', 'RG', 'PG'];

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final search = TextEditingController();
  // Từ khóa đã gửi đi; phân trang dùng giá trị này chứ không dùng chữ đang gõ.
  String query = '';
  String grade = '';
  int skip = 0;
  late Future<ProductSearchPage> future;

  bool get hasFilter => query.isNotEmpty || grade.isNotEmpty;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() {
    future = context.read<ShopRepository>().searchProducts(
      query: query,
      grade: grade,
      skip: skip,
    );
  });

  void applySearch() {
    query = search.text.trim();
    skip = 0;
    reload();
  }

  void clearFilters() {
    search.clear();
    query = '';
    grade = '';
    skip = 0;
    reload();
  }

  void goToPage(int newSkip) {
    skip = newSkip < 0 ? 0 : newSkip;
    reload();
  }

  Future<void> refresh() async {
    reload();
    // Lỗi đã được AsyncPanel hiển thị; chỉ chờ để vòng xoay biến mất đúng lúc.
    await future.then((_) {}, onError: (_) {});
  }

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
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Tìm tên mô hình',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Xóa từ khóa',
                      onPressed: () {
                        search.clear();
                        applySearch();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                  onSubmitted: (_) => applySearch(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: grade,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tất cả')),
                  for (final g in catalogGrades)
                    DropdownMenuItem(value: g, child: Text(g)),
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
          child: AsyncPanel<ProductSearchPage>(
            future: future,
            onRetry: reload,
            builder: (page) => RefreshIndicator(
              onRefresh: refresh,
              child: page.items.isEmpty
                  ? _EmptyResults(
                      page: page,
                      query: query,
                      hasFilter: hasFilter,
                      onClearFilters: clearFilters,
                      onFirstPage: () => goToPage(0),
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (page.totalCount != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: Text(
                              'Tìm thấy ${page.totalCount} sản phẩm',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        for (final item in page.items) _ProductTile(item),
                        _Pager(
                          page: page,
                          onPrevious: () => goToPage(skip - page.pageSize),
                          onNext: () => goToPage(skip + page.pageSize),
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

class _ProductTile extends StatelessWidget {
  const _ProductTile(this.item);
  final ProductSearchHit item;

  @override
  Widget build(BuildContext context) => Card(
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
        MaterialPageRoute(builder: (_) => ProductScreen(productId: item.id)),
      ),
    ),
  );
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.onPrevious,
    required this.onNext,
  });
  final ProductSearchPage page;
  final VoidCallback onPrevious, onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      TextButton(
        onPressed: page.hasPrevious ? onPrevious : null,
        child: const Text('Trang trước'),
      ),
      Text(
        page.pageCount == null
            ? 'Trang ${page.pageNumber}'
            : 'Trang ${page.pageNumber} / ${page.pageCount}',
      ),
      TextButton(
        onPressed: page.hasNext ? onNext : null,
        child: const Text('Trang sau'),
      ),
    ],
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.page,
    required this.query,
    required this.hasFilter,
    required this.onClearFilters,
    required this.onFirstPage,
  });
  final ProductSearchPage page;
  final String query;
  final bool hasFilter;
  final VoidCallback onClearFilters, onFirstPage;

  @override
  Widget build(BuildContext context) {
    // Trang sau bị rỗng (dữ liệu vừa thay đổi) khác với bộ lọc không có kết quả.
    final beyondLastPage = page.hasPrevious;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const Icon(Icons.search_off, size: 48),
        const SizedBox(height: 12),
        Text(
          beyondLastPage
              ? 'Trang này không còn sản phẩm.'
              : query.isNotEmpty
              ? 'Không tìm thấy sản phẩm cho “$query”.'
              : 'Không tìm thấy sản phẩm phù hợp.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (beyondLastPage)
          Center(
            child: OutlinedButton(
              onPressed: onFirstPage,
              child: const Text('Về trang đầu'),
            ),
          )
        else if (hasFilter)
          Center(
            child: OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Xóa bộ lọc'),
            ),
          ),
      ],
    );
  }
}

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
  // UC10: thứ tự sắp xếp; đổi thứ tự thì về trang đầu như khi đổi bộ lọc.
  CatalogSort sort = CatalogSort.nameAsc;
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
      sort: sort,
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

  void selectGrade(String value) {
    grade = value;
    skip = 0;
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

  Widget _header() {
    final none = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return NavyPanel(
      radius: 0,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: HudLabel('Hangar // Catalog', color: Color(0xFFF87171)),
              ),
              SizedBox(width: 8),
              HudLabel('Sync: online', color: Color(0xFF4ADE80)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tìm mô hình cho bộ sưu tập',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm tên mô hình',
              prefixIcon: const Icon(Icons.search, color: Hud.red),
              suffixIcon: IconButton(
                tooltip: 'Xóa từ khóa',
                onPressed: () {
                  search.clear();
                  applySearch();
                },
                icon: const Icon(Icons.clear),
              ),
              border: none,
              enabledBorder: none,
              focusedBorder: none,
            ),
            onSubmitted: (_) => applySearch(),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final g in ['', ...catalogGrades])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _GradePill(
                      label: g.isEmpty ? 'Tất cả' : g,
                      selected: grade == g,
                      onTap: () => selectGrade(g),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(ProductSearchPage page) => SingleChildScrollView(
    // Không dùng danh sách lười: trang chỉ có tối đa 20 sản phẩm và thanh
    // phân trang cuối trang luôn được dựng.
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (page.totalCount != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tìm thấy ${page.totalCount} sản phẩm',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Hud.ink,
                    ),
                  ),
                ),
                if (hasFilter)
                  const HudLabel('Bộ lọc đang bật', color: Hud.red),
              ],
            ),
          ),
        for (var i = 0; i < page.items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ProductTile(page.items[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < page.items.length
                      ? _ProductTile(page.items[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        _Pager(
          page: page,
          onPrevious: () => goToPage(skip - page.pageSize),
          onNext: () => goToPage(skip + page.pageSize),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const HudTitle('FiveGuysGundam', tag: 'Gunpla store'),
    ),
    body: Column(
      children: [
        _header(),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
          child: Row(
            children: [
              const Icon(Icons.sort, size: 20, color: Hud.red),
              const SizedBox(width: 8),
              const Text(
                'Sắp xếp',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CatalogSort>(
                    key: const Key('catalog-sort'),
                    isExpanded: true,
                    value: sort,
                    items: [
                      for (final s in CatalogSort.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v == null || v == sort) return;
                      sort = v;
                      skip = 0;
                      reload();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AsyncPanel<ProductSearchPage>(
            future: future,
            onRetry: reload,
            builder: (page) => RefreshIndicator(
              color: Hud.red,
              onRefresh: refresh,
              child: page.items.isEmpty
                  ? _EmptyResults(
                      page: page,
                      query: query,
                      hasFilter: hasFilter,
                      onClearFilters: clearFilters,
                      onFirstPage: () => goToPage(0),
                    )
                  : _grid(page),
            ),
          ),
        ),
      ],
    ),
  );
}

class _GradePill extends StatelessWidget {
  const _GradePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Hud.red : Colors.white.withValues(alpha: .08),
    shape: StadiumBorder(
      side: BorderSide(
        color: selected ? Hud.red : Colors.white.withValues(alpha: .22),
      ),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _ProductTile extends StatelessWidget {
  const _ProductTile(this.item);
  final ProductSearchHit item;

  @override
  Widget build(BuildContext context) => HudCard(
    margin: EdgeInsets.zero,
    padding: EdgeInsets.zero,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductScreen(productId: item.id)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            const SizedBox(
              height: 140,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: ProductArt(size: 140, width: 180),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: SpecBadge('${item.grade} ${item.scale}', dark: true),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HudLabel(item.category, color: gradeColor(item.grade), size: 9),
              const SizedBox(height: 4),
              SizedBox(
                height: 40,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Hud.ink,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.fromPriceVnd == null
                          ? 'Chưa có giá'
                          : 'Từ ${money(item.fromPriceVnd!)}',
                      style: TextStyle(
                        color: item.fromPriceVnd == null ? Hud.muted : Hud.red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Hud.muted),
                ],
              ),
            ],
          ),
        ),
      ],
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
  Widget build(BuildContext context) => HudCard(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Row(
      children: [
        Flexible(
          flex: 2,
          child: TextButton(
            onPressed: page.hasPrevious ? onPrevious : null,
            child: const Text('Trang trước', overflow: TextOverflow.ellipsis),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            page.pageCount == null
                ? 'Trang ${page.pageNumber}'
                : 'Trang ${page.pageNumber} / ${page.pageCount}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Flexible(
          flex: 2,
          child: TextButton(
            onPressed: page.hasNext ? onNext : null,
            child: const Text('Trang sau', overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    ),
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
      children: [
        EmptyState(
          icon: Icons.search_off,
          title: beyondLastPage
              ? 'Trang này không còn sản phẩm.'
              : query.isNotEmpty
              ? 'Không tìm thấy sản phẩm cho “$query”.'
              : 'Không tìm thấy sản phẩm phù hợp.',
          message: beyondLastPage
              ? 'Dữ liệu vừa thay đổi, hãy quay về trang đầu.'
              : 'Thử đổi từ khóa hoặc bỏ bớt bộ lọc grade.',
          actions: [
            if (beyondLastPage)
              OutlinedButton(
                onPressed: onFirstPage,
                child: const Text('Về trang đầu'),
              )
            else if (hasFilter)
              FilledButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Xóa bộ lọc'),
              ),
          ],
        ),
      ],
    );
  }
}

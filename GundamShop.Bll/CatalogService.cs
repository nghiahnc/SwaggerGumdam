using GundamShop.Dal;
using Microsoft.EntityFrameworkCore;

namespace GundamShop.Bll;

public class CatalogService(ShopDbContext db)
{
    public Task<Page<CategoryDto>> Categories(int page, int size, bool admin = false) => PageHelper.GetAsync(db.Categories.AsNoTracking()
        .Where(x => admin || x.IsActive).OrderBy(x => x.Name)
        .Select(x => new CategoryDto(x.Id, x.Name, x.Slug, x.Description, x.IsActive)), page, size);

    public async Task<CategoryDto> Category(Guid id, bool admin = false)
    {
        var x = ShopGuard.Found(await db.Categories.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id && (admin || x.IsActive)), "danh mục");
        return new(x.Id, x.Name, x.Slug, x.Description, x.IsActive);
    }

    public async Task<CategoryDto> AddCategory(CategoryRequest i)
    {
        var slug = i.Slug.Trim().ToLowerInvariant();
        ShopGuard.Require(!await db.Categories.AnyAsync(x => x.Slug == slug), "Slug danh mục đã tồn tại.", 409);
        var x = new Category { Name = i.Name.Trim(), Slug = slug, Description = i.Description?.Trim() };
        db.Categories.Add(x); await db.SaveChangesAsync();
        return new(x.Id, x.Name, x.Slug, x.Description, x.IsActive);
    }

    public async Task<CategoryDto> UpdateCategory(Guid id, CategoryRequest i)
    {
        var x = ShopGuard.Found(await db.Categories.FindAsync(id), "danh mục");
        var slug = i.Slug.Trim().ToLowerInvariant();
        ShopGuard.Require(!await db.Categories.AnyAsync(c => c.Id != id && c.Slug == slug), "Slug danh mục đã tồn tại.", 409);
        x.Name = i.Name.Trim(); x.Slug = slug; x.Description = i.Description?.Trim();
        await db.SaveChangesAsync(); return new(x.Id, x.Name, x.Slug, x.Description, x.IsActive);
    }

    public async Task DeleteCategory(Guid id)
    {
        var x = ShopGuard.Found(await db.Categories.FindAsync(id), "danh mục");
        ShopGuard.Require(!await db.Products.AnyAsync(p => p.CategoryId == id && p.IsActive), "Còn sản phẩm đang bán trong danh mục.", 409);
        x.IsActive = false; await db.SaveChangesAsync();
    }

    public Task<Page<ProductDto>> Products(int page, int size, bool admin = false) => PageHelper.GetAsync(db.Products.AsNoTracking()
        .Where(x => admin || (x.IsActive && x.Category.IsActive)).OrderBy(x => x.Name)
        .Select(x => new ProductDto(x.Id, x.CategoryId, x.Name, x.Slug, x.Grade, x.Scale, x.Description, x.ImageUrl, x.IsActive)), page, size);

    public async Task<ProductDto> Product(Guid id, bool admin = false)
    {
        var x = ShopGuard.Found(await db.Products.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id && (admin || (x.IsActive && x.Category.IsActive))), "sản phẩm");
        return ToDto(x);
    }

    public async Task<ProductDto> AddProduct(ProductRequest i)
    {
        ShopGuard.Require(await db.Categories.AnyAsync(x => x.Id == i.CategoryId && x.IsActive), "Danh mục không hợp lệ.");
        var slug = i.Slug.Trim().ToLowerInvariant();
        ShopGuard.Require(!await db.Products.AnyAsync(x => x.Slug == slug), "Slug sản phẩm đã tồn tại.", 409);
        var x = new Product { CategoryId = i.CategoryId }; Copy(i, x);
        db.Products.Add(x); await db.SaveChangesAsync(); return ToDto(x);
    }

    public async Task<ProductDto> UpdateProduct(Guid id, ProductRequest i)
    {
        var x = ShopGuard.Found(await db.Products.FindAsync(id), "sản phẩm");
        ShopGuard.Require(await db.Categories.AnyAsync(c => c.Id == i.CategoryId && c.IsActive), "Danh mục không hợp lệ.");
        var slug = i.Slug.Trim().ToLowerInvariant();
        ShopGuard.Require(!await db.Products.AnyAsync(p => p.Id != id && p.Slug == slug), "Slug sản phẩm đã tồn tại.", 409);
        x.CategoryId = i.CategoryId; Copy(i, x);
        await db.SaveChangesAsync(); return ToDto(x);
    }

    public async Task DeleteProduct(Guid id)
    {
        var x = ShopGuard.Found(await db.Products.FindAsync(id), "sản phẩm");
        x.IsActive = false;
        foreach (var variant in await db.Variants.Where(v => v.ProductId == id).ToListAsync()) variant.IsActive = false;
        await db.SaveChangesAsync();
    }

    public Task<Page<VariantDto>> Variants(Guid productId, int page, int size, bool admin = false) => PageHelper.GetAsync(db.Variants.AsNoTracking()
        .Where(x => x.ProductId == productId && (admin || (x.IsActive && x.Product.IsActive && x.Product.Category.IsActive)))
        .OrderBy(x => x.Sku).Select(x => new VariantDto(x.Id, x.ProductId, x.Sku, x.Label, x.PriceVnd, x.Stock, x.IsActive)), page, size);

    public async Task<VariantDto> Variant(Guid id, bool admin = false)
    {
        var x = ShopGuard.Found(await db.Variants.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id && (admin || (x.IsActive && x.Product.IsActive && x.Product.Category.IsActive))), "SKU");
        return ToDto(x);
    }

    public async Task<VariantDto> AddVariant(VariantRequest i)
    {
        ShopGuard.Require(await db.Products.AnyAsync(x => x.Id == i.ProductId && x.IsActive), "Sản phẩm không hợp lệ.");
        var sku = i.Sku.Trim().ToUpperInvariant();
        ShopGuard.Require(!await db.Variants.AnyAsync(x => x.Sku == sku), "SKU đã tồn tại.", 409);
        var x = new ProductVariant { ProductId = i.ProductId, Sku = sku, Label = i.Label.Trim(), PriceVnd = i.PriceVnd, Stock = i.InitialStock };
        db.Variants.Add(x); await db.SaveChangesAsync(); return ToDto(x);
    }

    public async Task<VariantDto> UpdateVariant(Guid id, VariantUpdateRequest i)
    {
        var x = ShopGuard.Found(await db.Variants.FindAsync(id), "SKU");
        ShopGuard.Require(!i.IsActive || await db.Products.AnyAsync(p => p.Id == x.ProductId && p.IsActive), "Sản phẩm đã ngừng bán.");
        x.Label = i.Label.Trim(); x.PriceVnd = i.PriceVnd; x.IsActive = i.IsActive;
        await db.SaveChangesAsync(); return ToDto(x);
    }

    public async Task DeleteVariant(Guid id)
    {
        var x = ShopGuard.Found(await db.Variants.FindAsync(id), "SKU");
        x.IsActive = false; await db.SaveChangesAsync();
    }

    public async Task<VariantDto> AdjustStock(Guid id, StockAdjustRequest i)
    {
        ShopGuard.Require(i.Delta != 0, "Delta phải khác 0.");
        var x = ShopGuard.Found(await db.Variants.FindAsync(id), "SKU");
        ShopGuard.Require((long)x.Stock + i.Delta >= 0 && (long)x.Stock + i.Delta <= int.MaxValue, "Tồn kho không hợp lệ.", 409);
        x.Stock += i.Delta; await db.SaveChangesAsync(); return ToDto(x);
    }

    public IQueryable<ProductODataDto> ODataProducts() => db.Products.AsNoTracking()
        .Where(x => x.IsActive && x.Category.IsActive)
        .Select(x => new ProductODataDto { Id = x.Id, Name = x.Name, Slug = x.Slug, Grade = x.Grade, Scale = x.Scale,
            Category = x.Category.Name, FromPriceVnd = db.Variants.Where(v => v.ProductId == x.Id && v.IsActive).Select(v => (long?)v.PriceVnd).Min() });

    private static void Copy(ProductRequest i, Product x)
    {
        x.Name = i.Name.Trim(); x.Slug = i.Slug.Trim().ToLowerInvariant(); x.Grade = i.Grade.Trim();
        x.Scale = i.Scale.Trim(); x.Description = i.Description?.Trim(); x.ImageUrl = i.ImageUrl?.Trim();
    }
    private static ProductDto ToDto(Product x) => new(x.Id, x.CategoryId, x.Name, x.Slug, x.Grade, x.Scale, x.Description, x.ImageUrl, x.IsActive);
    private static VariantDto ToDto(ProductVariant x) => new(x.Id, x.ProductId, x.Sku, x.Label, x.PriceVnd, x.Stock, x.IsActive);
}

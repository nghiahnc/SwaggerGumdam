using GundamShop.Bll;

namespace GundamShop.Api;

/// Product photos uploaded by an admin, stored on disk next to the API and served from /uploads.
public static class ProductImages
{
    public const long MaxBytes = 5 * 1024 * 1024;
    public const string RequestPath = "/uploads";

    public static string Folder(IWebHostEnvironment env) => Path.Combine(env.ContentRootPath, "uploads", "products");

    /// Saves the file under a new name and returns its path, e.g. /uploads/products/{guid}.jpg.
    public static async Task<string> Save(IFormFile file, IWebHostEnvironment env)
    {
        ShopGuard.Require(file.Length > 0, "Chưa chọn ảnh.", 400);
        ShopGuard.Require(file.Length <= MaxBytes, "Ảnh lớn hơn 5 MB.", 413);
        var header = new byte[12];
        await using (var input = file.OpenReadStream())
            await input.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false);
        // Trust the bytes, not the name or Content-Type the client sent. SVG is refused: it can carry script.
        var extension = Sniff(header);
        ShopGuard.Require(extension != null, "Chỉ nhận ảnh JPG, PNG hoặc WebP.", 415);

        var folder = Folder(env);
        Directory.CreateDirectory(folder);
        var name = $"{Guid.NewGuid():N}{extension}";
        await using (var output = File.Create(Path.Combine(folder, name)))
            await file.CopyToAsync(output);
        return $"{RequestPath}/products/{name}";
    }

    private static string? Sniff(byte[] h) =>
        h is [0xFF, 0xD8, 0xFF, ..] ? ".jpg"
        : h is [0x89, (byte)'P', (byte)'N', (byte)'G', ..] ? ".png"
        : h is [(byte)'R', (byte)'I', (byte)'F', (byte)'F', _, _, _, _, (byte)'W', (byte)'E', (byte)'B', (byte)'P'] ? ".webp"
        : null;
}

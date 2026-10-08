# FiveGuysGundam · Flutter + API demo

Repository này giữ cả backend ASP.NET Core Web API và [ứng dụng Flutter PRM393](PRM393/README.md) để chạy demo cùng nhau. Backend ở thư mục gốc, Flutter ở `PRM393/five_guys_gundam/`. Bản **API/Swagger độc lập cho môn PRN232** nằm tại [GundamShop-PRN232-API](https://github.com/nghiahnc/GundamShop-PRN232-API).

## Bắt đầu nhanh trên Windows

1. Cài .NET SDK 8 và SQL Server LocalDB (hoặc SQL Server Express/Developer). Máy này đã có cả hai.
2. Trong thư mục vừa clone có `GundamShop.slnx`, chạy:

   ```powershell
   dotnet restore GundamShop.slnx --configfile NuGet.Config
   dotnet ef database update --project GundamShop.Dal --startup-project GundamShop.Api
   $env:ASPNETCORE_ENVIRONMENT = 'Development'
   $env:Database__AutoMigrate = 'true'
   dotnet run --project GundamShop.Api --urls http://0.0.0.0:5288
   ```

3. Mở Swagger tại `http://127.0.0.1:5288/swagger`. Tài khoản demo chỉ được tạo trong Development: `admin@gundam.local` / `Admin123!`.
4. Đọc [hướng dẫn Flutter](PRM393/README.md) để chạy ứng dụng và [hướng dẫn dev API](docs/DEVELOPER_GUIDE.md) để hiểu kiến trúc, cách thử endpoint và Stripe.

Nếu mới clone dự án và muốn cài database **trong Visual Studio**, làm theo [hướng dẫn Visual Studio + SQL Server Object Explorer](VISUAL_STUDIO_DATABASE_SETUP.md).

File [phân công nhóm](outputs/01a0eab7-3c3c-79c1-9b9d-7651a6ec1cf4/GundamShop_PhanCong.xlsx) có sheet **Tổng kết** và **Chức năng thành viên**. Chạy `tests/smoke.ps1` khi API đang mở ở `http://127.0.0.1:5288` để kiểm thử luồng chính.

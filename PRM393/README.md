# PRM393 · FiveGuysGundam Flutter

Ứng dụng Flutter của môn PRM393 nằm trong [five_guys_gundam](five_guys_gundam/README.md). Bản API đi kèm để demo nằm ở thư mục gốc repository này; [repo API/Swagger độc lập cho PRN232](https://github.com/nghiahnc/GundamShop-PRN232-API) có thể chạy riêng.

Sau khi clone repository, mở hai terminal PowerShell ở thư mục gốc:

```powershell
# Terminal 1: API
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:Database__AutoMigrate = 'true'
dotnet run --project .\GundamShop.Api --urls http://0.0.0.0:5288
```

```powershell
# Terminal 2: Flutter trong Edge
cd .\PRM393\five_guys_gundam
flutter pub get
flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5288
```

Với Android Emulator, dùng `flutter devices` để xem ID và chạy `flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:5288`. Cách cài đặt và danh sách chức năng có trong [README Flutter](five_guys_gundam/README.md), [PROJECT_GUIDE](five_guys_gundam/PROJECT_GUIDE.md) và [CODE_MAP](five_guys_gundam/CODE_MAP.md).

# Local Setup

## 1) Backend

1. Copy `backend/.env.example` to `backend/.env`
2. Create database `oga_tailor`
3. Import `database/schema.sql`
4. Start API:

```powershell
php -S localhost:8000 -t c:\mobile-app-projects\oga-tailor\backend\public
```

Health check:

```powershell
curl.exe -s "http://localhost:8000/health"
```

## 2) Flutter SDK (Windows)

Install Flutter with one of these:

- Official installer: [https://docs.flutter.dev/get-started/install/windows/mobile](https://docs.flutter.dev/get-started/install/windows/mobile)
- Git clone (already used in this project):
  - `git clone https://github.com/flutter/flutter.git -b stable c:\mobile-app-projects\flutter --depth 1`

After install:

```powershell
& "c:\mobile-app-projects\flutter\bin\flutter.bat" doctor -v
```

If Flutter is added to PATH later, you can use `flutter` directly.
If SDK download fails, allow access to `storage.googleapis.com` on your network/firewall.

## 3) Preview on Laptop

- Web preview:

```powershell
& "c:\mobile-app-projects\flutter\bin\flutter.bat" run -d chrome
```

- Windows desktop preview:

```powershell
& "c:\mobile-app-projects\flutter\bin\flutter.bat" config --enable-windows-desktop
& "c:\mobile-app-projects\flutter\bin\flutter.bat" run -d windows
```

## 4) Android Device Testing

- Enable Developer Options
- Enable USB Debugging
- Connect phone to laptop
- Run:

```powershell
& "c:\mobile-app-projects\flutter\bin\flutter.bat" devices
```

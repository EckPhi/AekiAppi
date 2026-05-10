# AekiAppi

Flutter app for controlling your Äike T-scooter via Bluetooth Low Energy (BLE).

## Features

- **Scan** for nearby Äike scooters (AIKE, AIKE\_T, AIKE\_11)
- **Authenticate** using the SHA-1 challenge-response scheme documented in the
  reverse-engineering write-up by Rasmus Moorats
- **Lock / Unlock** the scooter
- **Open the battery tray**
- Toggle **Eco Mode**
- Toggle **Auto-brake**
- Set the **Auto-lock Timer** (0–60 min)
- Enable / disable **Transport Mode**
- Display live **battery level**, **battery voltage**, and **firmware version**
  from BLE notifications

## Architecture

```
lib/
├── main.dart                  # Entry point + Material theme + Provider setup
├── models/
│   └── scooter_state.dart     # Immutable state snapshot with copyWith
├── screens/
│   ├── scan_screen.dart       # BLE discovery UI
│   └── home_screen.dart       # Scooter control panel
└── services/
    └── scooter_service.dart   # BLE service: scan, auth, commands, notifications
```

## BLE Protocol

Authentication (runs once after connecting):
1. Read 20-byte challenge from characteristic `00002556-1212-efde-1523-785feabcd123`
2. Compute `SHA-1(challenge ‖ key)` where `key` = 20 × `0xFF` (default key)
3. Write 20-byte digest to `00002557-1212-efde-1523-785feabcd123`

Commands are 10-byte packets written to `0000155f-1212-efde-1523-785feabcd123`.
Status notifications arrive on `0000155e-1212-efde-1523-785feabcd123`.

See `lib/services/scooter_service.dart` for the full command and notification
registry reference.

## Getting Started

### Prerequisites

- Flutter 3.41.9 or later
- Dart 3.11.5 or later
- For Android: Android SDK with API 21+
- For iOS: Xcode 13+
- For Linux: GTK 3.0+
- For macOS: Xcode 13+
- For Windows: Visual Studio 2022 or Build Tools for Visual Studio

### Setup and Run

```bash
# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

### Supported Platforms

AekiAppi is built for multiple platforms:

| Platform | Status | Notes |
|---|---|---|
| **Android** | ✅ Ready | APK builds available, requires Bluetooth permissions |
| **iOS** | ✅ Ready | Requires Xcode and Apple Developer account for deployment |
| **Web** | ✅ Ready | Deployed automatically to GitHub Pages on push to main |
| **Linux** | ✅ Ready | Desktop application with full Bluetooth support |
| **macOS** | ✅ Ready | Native macOS app with Bluetooth support |
| **Windows** | ✅ Ready | Native Windows app (requires Windows SDK) |

#### Build Commands

```bash
# Android APK (debug)
flutter build apk --debug

# Android APK (release)
flutter build apk --release

# Web (release optimized)
flutter build web --release

# Linux (release)
flutter build linux --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# iOS App Bundle
flutter build ios
```

### Web Platform

The web version is automatically deployed to GitHub Pages at every push to `main`. Access it via:
- **URL**: `https://<username>.github.io/<repo>/` (once repository is configured for GitHub Pages)

To build the web version locally:

```bash
flutter build web --release
# Output is in build/web/
```

### Desktop Applications

Linux and Windows builds create standalone executables:

```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/

flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

## Continuous Integration and Deployment

### GitHub Actions Workflows

The project uses GitHub Actions for automated CI/CD:

- **`ci.yml`**: Runs on every push and pull request
  - Analyzes code with `flutter analyze`
  - Runs unit tests with coverage
  - Builds web, Android, and Linux versions
  
- **`deploy-web.yml`**: Deploys web app to GitHub Pages
  - Triggers on push to `main` (for code changes) or manually
  - Builds optimized web release
  - Deploys to GitHub Pages automatically
  
- **`release.yml`**: Creates release artifacts
  - Triggers on version tags (e.g., `v1.2.3`)
  - Builds all platforms (Android, Web, Linux, macOS, Windows)
  - Creates GitHub Release with all build artifacts

### Setting Up GitHub Pages

To enable web deployment:

1. Go to repository **Settings** → **Pages**
2. Under "Source", select **GitHub Actions**
3. Save settings
4. Push to `main` (or run the deploy workflow manually)
5. Web app will be available at `https://<username>.github.io/<repo>/`

### Triggering Deployments

#### Automatic
- **Web**: Automatically deployed on every push to `main` with code changes
- **Release builds**: Automatically created when pushing version tags

#### Manual
- **Web**: Go to **Actions** → **Deploy Web to GitHub Pages** → **Run workflow**

## Platform-Specific Notes

### Android

The app requests the following permissions at runtime:

| Permission | Purpose |
|---|---|
| `BLUETOOTH_SCAN` | Discover nearby scooters |
| `BLUETOOTH_CONNECT` | Connect to and communicate with the scooter |
| `ACCESS_FINE_LOCATION` | Required on Android < 12 for BLE scanning |

### iOS

`NSBluetoothAlwaysUsageDescription` is declared in `ios/Runner/Info.plist`.

### Web

- Uses `flutter_blue_plus` web plugin for Bluetooth connectivity
- Requires HTTPS or localhost (browser security policy)
- Performance optimized with `--web-renderer html`

### Linux & macOS

- Full Bluetooth support via native APIs
- Standalone executables included in release artifacts

## Testing

```bash
flutter test
```


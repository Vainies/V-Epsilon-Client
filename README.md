# V Epsilon Client

Flutter Android client for V Epsilon, a social platform with posts, messaging, voice comments, extensions, and more.

## Tech Stack

- **Framework:** Flutter 3.x
- **Language:** Dart
- **State:** Provider
- **Platform:** Android

## Features

- Social feed with posts, comments, likes, reposts
- Direct messaging with reactions
- Voice posts and comments
- User profiles with follow/mute/block
- QR code scanning for profile sharing
- Real-time WebSocket notifications
- In-app updates
- Extension system
- Admin panel (admin accounts only)
- Dark/light/custom themes

## Quick Start

### 1. Prerequisites

- Flutter SDK 3.8+
- Android SDK with build-tools
- A running V Epsilon server (see [V-Epsilon-Server](https://github.com/Vainies/V-Epsilon-Server))

### 2. Clone and Setup

```bash
git clone https://github.com/Vainies/V-Epsilon-Client.git
cd V-Epsilon-Client
flutter pub get
```

### 3. Configure Server URL

Edit `lib/api.dart` and set your server address:

```dart
static const builtinUrls = [
  'http://your-server-ip:6967',
];
static const defaultBaseUrl = 'http://your-server-ip:6967';
```

Or leave them empty and add the server URL through the app's settings screen.

### 4. Build

```bash
# Release APK
flutter build apk

# Debug APK (for development)
flutter build apk --debug
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

### 5. Install

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or transfer the APK to your Android device and install it.

## Project Structure

```
client/
  lib/
    main.dart           - App entry, theme, navigation
    api.dart            - HTTP/WebSocket client
    models.dart         - Data models
    theme.dart          - Theme system
    updater.dart        - In-app update checker
    crash_reporter.dart - Crash reporting
    extension_runtime.dart - Extension loading
    feature_config.dart - Feature flags
    screens/
      home.dart         - Main feed
      auth.dart         - Login/register
      profile.dart      - User profiles
      settings.dart     - Settings
      composer.dart     - Post composer
      search.dart       - Search
      extensions.dart   - Extensions browser
      admin_dashboard.dart - Admin panel
      versions.dart     - Version history
      activity.dart     - Activity feed
      comms.dart        - Direct messages
      qr_screen.dart    - QR code scanner
    widgets/
      post_card.dart    - Post display
      common.dart       - Shared widgets
      update_dialog.dart - Update prompt
    services/
      push_service.dart - Push notifications
      notif_bus.dart    - Notification routing
  assets/
    icons/              - App icons
    fonts/              - Inter, JetBrains Mono
  android/
    app/
      src/main/
        AndroidManifest.xml
        kotlin/         - Platform code
      build.gradle      - Build config
```

## Configuration

### Server Connection

The app tries to connect to servers in this order:
1. URLs in `builtinUrls` (hardcoded in `lib/api.dart`)
2. User-added URLs from settings
3. Previously saved URL from shared preferences

Set `builtinUrls` to your server address before building, or add it through the app settings.

### Android Permissions

The app requires:
- Internet access
- Camera (QR scanning)
- Microphone (voice comments)
- Storage (media picking)
- Notifications

### Signing

For release builds, create `android/key.properties`:

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=your-key-alias
storeFile=/path/to/your.keystore
```

Then place the keystore file at the specified path.

## Environment

No environment variables needed for the client. All configuration is done through:
- Code (server URL in `api.dart`)
- App settings screen
- Shared preferences (persisted)

## Building for Distribution

```bash
# Clean build
flutter clean
flutter pub get

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

## Development

```bash
# Run on connected device
flutter run

# Run with hot reload
flutter run --hot

# Run tests
flutter test

# Analyze code
flutter analyze
```

## License

MIT

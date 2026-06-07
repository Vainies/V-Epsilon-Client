# V Epsilon - Flutter Client

A Flutter-based Android social platform client.

## Features

- Social feed with posts, comments, likes, and reposts
- Direct messaging with reactions
- User profiles with follow/mute/block
- Admin panel (for admin users)
- Voice comments
- Real-time WebSocket notifications
- Extension support
- Dark/light theme support

## Requirements

- Flutter SDK 3.x+
- Android SDK

## Setup

1. Clone this repository
2. Run `flutter pub get` to install dependencies
3. Edit `lib/api.dart` and set your server URL in `builtinUrls` and `defaultBaseUrl`
4. Build the APK: `flutter build apk`

## Configuration

The app needs a V Epsilon server running. In `lib/api.dart`:

- `builtinUrls` - list of server URLs to probe on startup
- `defaultBaseUrl` - fallback server URL

Set these to your server's address (e.g., `http://your-server:6967`).

## Building

```bash
flutter build apk          # Release APK
flutter build apk --debug  # Debug APK
```

## License

See LICENSE file for details.
